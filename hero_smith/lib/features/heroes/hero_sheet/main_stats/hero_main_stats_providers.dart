import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/app_database.dart' as db;
import '../../../../core/db/providers.dart';
import '../../../../core/models/damage_resistance_model.dart';
import '../../../../core/models/dynamic_modifier_model.dart';
import '../../../../core/models/hero_assembled_model.dart';
import '../../../../core/models/hero_mod_keys.dart';
import '../../../../core/models/heroic_resource_progression.dart';
import '../../../../core/models/stat_modification_model.dart';
import '../../../../core/repositories/hero_repository.dart';
import '../../../../core/services/ancestry_bonus_service.dart';
import '../../../../core/services/heroic_resource_progression_service.dart';
import '../../../../core/services/psi_boost_service.dart';

/// Provider that combines hero_values (base stats) with HeroAssembly (mods/bonuses)
/// to produce the complete HeroMainStats.
///
/// This is a pure combination of existing providers; Riverpod will recompute
/// whenever any dependency changes (values, assembly, equipment bonuses).
final heroMainStatsProvider =
    Provider.family<AsyncValue<HeroMainStats>, String>((ref, heroId) {
  final valuesAsync = ref.watch(heroValuesProvider(heroId));
  final assemblyAsync = ref.watch(heroAssemblyProvider(heroId));
  final equipmentBonusesAsync = ref.watch(heroEquipmentBonusesProvider(heroId));

  // Propagate loading/error states if any dependency is not ready
  if (valuesAsync.isLoading || assemblyAsync.isLoading || equipmentBonusesAsync.isLoading) {
    return const AsyncLoading();
  }

  // Errors: surface the first one encountered
  if (valuesAsync.hasError) {
    return AsyncError(valuesAsync.error!, valuesAsync.stackTrace ?? StackTrace.current);
  }
  if (assemblyAsync.hasError) {
    return AsyncError(assemblyAsync.error!, assemblyAsync.stackTrace ?? StackTrace.current);
  }
  if (equipmentBonusesAsync.hasError) {
    return AsyncError(
      equipmentBonusesAsync.error!,
      equipmentBonusesAsync.stackTrace ?? StackTrace.current,
    );
  }

  final values = valuesAsync.requireValue;
  final assembly = assemblyAsync.value; // may be null
  final equipmentBonuses = equipmentBonusesAsync.requireValue;

  final stats = _mapValuesAndAssemblyToMainStats(values, assembly, equipmentBonuses);
  return AsyncData(stats);
});

/// Pure function to combine hero_values and HeroAssembly into HeroMainStats.
HeroMainStats _mapValuesAndAssemblyToMainStats(
  List<db.HeroValue> values,
  HeroAssembly? assembly,
  Map<String, int> equipmentBonuses,
) {
  int readInt(String key, {int defaultValue = 0}) {
    final v = values.firstWhereOrNull((e) => e.key == key);
    if (v == null) return defaultValue;
    return v.value ?? int.tryParse(v.textValue ?? '') ?? defaultValue;
  }

  String? readText(String key) {
    final v = values.firstWhereOrNull((e) => e.key == key);
    return v?.textValue;
  }

  // User modifications from hero_values
  final userModifications = _extractUserModifications(values);

  // Choice modifications: stat mods from assembly + equipment bonuses
  final choiceModifications = _buildChoiceModifications(assembly, equipmentBonuses);

  // Combined modifications
  final modifications = _combineModificationMaps(choiceModifications, userModifications);

  // Class ID comes from assembly (hero_entries), fallback to legacy hero_values
  final classId = assembly?.classId ?? readText('basics.className');

  // Heroic resource name from hero_values
  final heroicResourceName = readText('heroic.resource');

  // Build dynamic modifiers from hero_values + feature stat bonuses stored in hero_values
  final baseDynamicMods = DynamicModifierList.fromJsonString(
    readText('dynamic_modifiers'),
  );

  final featureBonusMap = _parseFeatureStatBonusMap(values);
  var featureDynamicMods = _buildFeatureStatBonusDynamicModifiersFromMap(featureBonusMap);

  // Fallback to assembly-derived entries for backward compatibility
  if (featureDynamicMods.modifiers.isEmpty) {
    featureDynamicMods = _buildFeatureStatBonusDynamicModifiersFromAssembly(assembly);
  }

  final dynamicModifiers = baseDynamicMods.add(featureDynamicMods.modifiers);

  return HeroMainStats(
    victories: readInt('score.victories'),
    exp: readInt('score.exp'),
    level: assembly?.level ?? readInt('basics.level', defaultValue: 1),
    wealthBase: readInt('score.wealth'),
    renownBase: readInt('score.renown'),
    mightBase: readInt('stats.might'),
    agilityBase: readInt('stats.agility'),
    reasonBase: readInt('stats.reason'),
    intuitionBase: readInt('stats.intuition'),
    presenceBase: readInt('stats.presence'),
    sizeBase: readText('stats.size') ?? '1M',
    speedBase: readInt('stats.speed'),
    disengageBase: readInt('stats.disengage'),
    stabilityBase: readInt('stats.stability'),
    staminaCurrent: readInt('stamina.current'),
    staminaMaxBase: readInt('stamina.max'),
    staminaTemp: readInt('stamina.temp'),
    recoveriesCurrent: readInt('recoveries.current'),
    recoveriesMaxBase: readInt('recoveries.max'),
    recoveryValueBonus: readInt('complication.recovery_bonus'),
    surgesCurrent: readInt('surges.current'),
    classId: classId,
    heroicResourceName: heroicResourceName,
    heroicResourceCurrent: readInt('heroic.current'),
    modifications: modifications,
    userModifications: userModifications,
    choiceModifications: choiceModifications,
    equipmentBonuses: equipmentBonuses,
    dynamicModifiers: dynamicModifiers,
  );
}

/// Extract user modifications from hero_values (mods.map).
Map<String, int> _extractUserModifications(List<db.HeroValue> values) {
  final map = <String, int>{};
  final modsEntry = values.firstWhereOrNull((e) => e.key == 'mods.map');
  if (modsEntry != null) {
    final raw = modsEntry.jsonValue ?? modsEntry.textValue;
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = _jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            final parsed = _toInt(value);
            if (parsed != null && parsed != 0) {
              map[key.toString()] = parsed;
            }
          });
        }
      } catch (_) {}
    }
  }
  return map.isEmpty ? const {} : Map.unmodifiable(map);
}

/// Build choice modifications from assembly stat mods + equipment bonuses.
Map<String, int> _buildChoiceModifications(
  HeroAssembly? assembly,
  Map<String, int> equipmentBonuses,
) {
  final map = <String, int>{};

  // Add stat mods from assembly (ancestry, complication, perks, etc.)
  if (assembly != null) {
    for (final stat in ['might', 'agility', 'reason', 'intuition', 'presence', 
                        'speed', 'disengage', 'stability', 'size', 'stamina', 
                        'recoveries', 'surges', 'wealth', 'renown']) {
      final modTotal = assembly.statMods.getTotalForStat(stat);
      if (modTotal != 0) {
        final modKey = _statToModKey(stat);
        if (modKey != null) {
          map[modKey] = (map[modKey] ?? 0) + modTotal;
        }
      }
    }
  }

  // Add equipment bonuses
  if (equipmentBonuses.isNotEmpty) {
    _addEquipmentMods(map, equipmentBonuses);
  }

  return map.isEmpty ? const {} : Map.unmodifiable(map);
}

/// Map stat name to HeroModKeys.
String? _statToModKey(String stat) {
  return switch (stat.toLowerCase()) {
    'might' => HeroModKeys.might,
    'agility' => HeroModKeys.agility,
    'reason' => HeroModKeys.reason,
    'intuition' => HeroModKeys.intuition,
    'presence' => HeroModKeys.presence,
    'size' => HeroModKeys.size,
    'speed' => HeroModKeys.speed,
    'disengage' => HeroModKeys.disengage,
    'stability' => HeroModKeys.stability,
    'stamina' => HeroModKeys.staminaMax,
    'recoveries' => HeroModKeys.recoveriesMax,
    'surges' => HeroModKeys.surges,
    'wealth' => HeroModKeys.wealth,
    'renown' => HeroModKeys.renown,
    _ => null,
  };
}

/// Map bonus key from JSON to stat name
String? _bonusKeyToStat(String key) {
  return switch (key) {
    'speed_bonus' => 'speed',
    'disengage_bonus' => 'disengage',
    'stability_bonus' => 'stability',
    'stamina_increase' => 'stamina',
    'recoveries_bonus' => 'recoveries',
    _ => null,
  };
}

/// Normalize characteristic name for formula parameter
String? _normalizeCharacteristic(String value) {
  final lower = value.toLowerCase();
  return switch (lower) {
    'might' => 'might',
    'agility' => 'agility',
    'reason' => 'reason',
    'intuition' => 'intuition',
    'presence' => 'presence',
    _ => null,
  };
}

/// Parse feature stat bonuses stored in hero_values under strife.feature_stat_bonuses.
/// Returns a map keyed by featureId -> payload map.
Map<String, dynamic> _parseFeatureStatBonusMap(List<db.HeroValue> values) {
  final row = values.firstWhereOrNull((v) => v.key == 'strife.feature_stat_bonuses');
  final raw = row?.jsonValue ?? row?.textValue;
  if (raw == null || raw.isEmpty) return const {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
  } catch (_) {}
  return const {};
}

/// Build dynamic modifiers from a feature bonus map stored in hero_values.
DynamicModifierList _buildFeatureStatBonusDynamicModifiersFromMap(
    Map<String, dynamic> featureBonusMap) {
  if (featureBonusMap.isEmpty) return DynamicModifierList.empty();

  final modifiers = <DynamicModifier>[];

  for (final entry in featureBonusMap.entries) {
    final sourceId = entry.key;
    final payload = entry.value;
    if (payload is! Map) continue;

    final source = 'class_feature:$sourceId';

    for (final bonusEntry in payload.entries) {
      final key = bonusEntry.key.toString();
      final value = bonusEntry.value;

      final stat = _bonusKeyToStat(key);
      if (stat == null) continue;

      if (value is int) {
        modifiers.add(DynamicModifier(
          stat: stat,
          formulaType: FormulaType.fixed,
          formulaParam: value.toString(),
          source: source,
        ));
      } else if (value is String) {
        final characteristic = _normalizeCharacteristic(value);
        if (characteristic != null) {
          modifiers.add(DynamicModifier(
            stat: stat,
            formulaType: FormulaType.characteristic,
            formulaParam: characteristic,
            source: source,
          ));
        }
      }
    }
  }

  return DynamicModifierList(modifiers);
}

/// Legacy: build dynamic modifiers from assembly feature_stat_bonus hero_entries.
DynamicModifierList _buildFeatureStatBonusDynamicModifiersFromAssembly(
    HeroAssembly? assembly) {
  if (assembly == null) return DynamicModifierList.empty();
  final modifiers = <DynamicModifier>[];

  for (final entry in assembly.featureStatBonuses) {
    if (entry.payload == null) continue;

    try {
      final payload = jsonDecode(entry.payload!);
      if (payload is! Map) continue;

      final source = 'class_feature:${entry.sourceId}';

      for (final bonusEntry in payload.entries) {
        final key = bonusEntry.key.toString();
        final value = bonusEntry.value;

        final stat = _bonusKeyToStat(key);
        if (stat == null) continue;

        if (value is int) {
          modifiers.add(DynamicModifier(
            stat: stat,
            formulaType: FormulaType.fixed,
            formulaParam: value.toString(),
            source: source,
          ));
        } else if (value is String) {
          final characteristic = _normalizeCharacteristic(value);
          if (characteristic != null) {
            modifiers.add(DynamicModifier(
              stat: stat,
              formulaType: FormulaType.characteristic,
              formulaParam: characteristic,
              source: source,
            ));
          }
        }
      }
    } catch (_) {
      // Skip malformed entries
    }
  }

  return DynamicModifierList(modifiers);
}

/// Add equipment bonuses to the modifications map.
void _addEquipmentMods(Map<String, int> map, Map<String, int> bonuses) {
  void add(String key, int? value) {
    if (value == null || value == 0) return;
    map[key] = (map[key] ?? 0) + value;
  }

  add(HeroModKeys.staminaMax, bonuses['stamina']);
  add(HeroModKeys.speed, bonuses['speed']);
  add(HeroModKeys.stability, bonuses['stability']);
  add(HeroModKeys.disengage, bonuses['disengage']);
}

/// Combine modification maps.
Map<String, int> _combineModificationMaps(
  Map<String, int> choiceMods,
  Map<String, int> userMods,
) {
  if (choiceMods.isEmpty && userMods.isEmpty) return const {};
  final result = <String, int>{};
  void merge(Map<String, int> source) {
    source.forEach((key, value) {
      if (value == 0) return;
      result[key] = (result[key] ?? 0) + value;
    });
  }

  merge(choiceMods);
  merge(userMods);
  return Map.unmodifiable(result);
}

dynamic _jsonDecode(String raw) {
  try {
    return jsonDecode(raw);
  } catch (_) {
    return null;
  }
}

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

extension _ListExtension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

/// Provider to watch ancestry stat modifications with their sources.
/// Uses a stream so it auto-updates when ancestry bonuses change.
final heroAncestryStatModsProvider =
    StreamProvider.family<HeroStatModifications, String>((ref, heroId) {
  final service = ref.watch(ancestryBonusServiceProvider);
  return service.watchAncestryStatMods(heroId);
});

/// Provider to watch damage resistances - auto-updates when values change.
final heroDamageResistancesProvider =
    StreamProvider.family<HeroDamageResistances, String>((ref, heroId) {
  final service = ref.watch(ancestryBonusServiceProvider);
  return service.watchDamageResistances(heroId);
});

/// Provider to load equipment bonuses that have been applied to the hero.
final heroEquipmentBonusesProvider =
    FutureProvider.family<Map<String, int>, String>((ref, heroId) async {
  final repo = ref.read(heroRepositoryProvider);
  return repo.getEquipmentBonuses(heroId);
});

/// Data class for hero progression context
class HeroProgressionContext {
  const HeroProgressionContext({
    required this.className,
    required this.subclassName,
    this.kitId,
  });

  final String? className;
  final String? subclassName;
  final String? kitId;
}

/// Provider to load hero progression context (class, subclass, kit) from HeroAssembly
final heroProgressionContextProvider =
    FutureProvider.family<HeroProgressionContext, String>((ref, heroId) async {
  // Use assembly as the source of truth for class/subclass/kit
  final assembly = await ref.watch(heroAssemblyProvider(heroId).future);
  
  if (assembly == null) {
    return const HeroProgressionContext(className: null, subclassName: null);
  }

  String? normalizedClassName = assembly.classId;
  if (normalizedClassName != null) {
    normalizedClassName = normalizedClassName.trim();
    if (normalizedClassName.startsWith('class_')) {
      normalizedClassName = normalizedClassName.substring(6);
    }
  }

  // Get kit from assembly equipment
  String? kitId;
  for (final equipEntry in assembly.equipment) {
    final id = equipEntry.entryId;
    if (id.contains('kit_')) {
      // Check if it's a stormwight kit (boren, corven, raden, vulken)
      final normalizedId = id.toLowerCase();
      if (normalizedId.contains('boren') ||
          normalizedId.contains('corven') ||
          normalizedId.contains('raden') ||
          normalizedId.contains('vulken') ||
          normalizedId.contains('vuken')) {
        kitId = id;
        break;
      }
    }
  }

  return HeroProgressionContext(
    className: normalizedClassName,
    subclassName: assembly.subclassId,
    kitId: kitId,
  );
});

/// Provider to load the heroic resource progression for a hero
final heroResourceProgressionProvider =
    FutureProvider.family<HeroicResourceProgression?, String>((ref, heroId) async {
  final context = await ref.watch(heroProgressionContextProvider(heroId).future);
  final service = HeroicResourceProgressionService();

  return service.getProgression(
    className: context.className,
    subclassName: context.subclassName,
    kitId: context.kitId,
  );
});

/// Provider to check if a hero has the Psi Boost feature.
/// Returns true if the hero's class features include psi_boost (Talent level 6 or Null level 7).
final heroPsiBoostProvider =
    FutureProvider.family<bool, String>((ref, heroId) async {
  final assembly = await ref.watch(heroAssemblyProvider(heroId).future);
  if (assembly == null) return false;

  // Check if any class feature entry contains "psi_boost"
  for (final feature in assembly.classFeatures) {
    if (feature.entryId.contains('psi_boost')) {
      return true;
    }
  }
  return false;
});

/// Provider to load psi boost data (cached).
final psiBoostDataProvider = FutureProvider<PsiBoostData>((ref) async {
  final service = PsiBoostService();
  return service.loadPsiBoostData();
});
