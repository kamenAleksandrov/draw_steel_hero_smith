import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart' as db;
import '../db/providers.dart';
import '../models/complication_grant_models.dart';
import '../models/damage_resistance_model.dart';
import '../models/dynamic_modifier_model.dart';
import '../models/stat_modification_model.dart';
import 'dynamic_modifiers_service.dart';

/// Service for managing complication grants.
/// Handles parsing complications, applying grants to heroes, and removing them when complications change.
class ComplicationGrantsService {
  ComplicationGrantsService(this._db) : _dynamicModifiers = DynamicModifiersService(_db);

  final db.AppDatabase _db;
  final DynamicModifiersService _dynamicModifiers;

  /// Parse all grants from a complication's data.
  Future<AppliedComplicationGrants> parseComplicationGrants({
    required String? complicationId,
    Map<String, String> choices = const {},
  }) async {
    if (complicationId == null || complicationId.isEmpty) {
      return AppliedComplicationGrants.empty;
    }

    final allComponents = await _db.getAllComponents();

    // Find the complication component
    final complicationComp = allComponents.firstWhereOrNull((c) {
      if (c.type != 'complication') return false;
      return c.id == complicationId;
    });

    if (complicationComp == null) {
      return AppliedComplicationGrants.empty;
    }

    final compData = jsonDecode(complicationComp.dataJson) as Map<String, dynamic>;
    final compName = (compData['name'] as String?) ?? complicationComp.name;
    
    // Get the grants section
    final grantsData = compData['grants'] as Map<String, dynamic>?;
    if (grantsData == null || grantsData.isEmpty) {
      return AppliedComplicationGrants(
        complicationId: complicationId,
        complicationName: compName,
        grants: [],
      );
    }

    final grants = ComplicationGrant.parseFromGrantsData(
      grantsData,
      complicationId,
      compName,
      choices,
    );

    return AppliedComplicationGrants(
      complicationId: complicationId,
      complicationName: compName,
      grants: grants,
    );
  }

  /// Apply complication grants to a hero.
  /// This updates the hero's stats, skills, abilities, etc.
  Future<void> applyGrants({
    required String heroId,
    required AppliedComplicationGrants grants,
    required int heroLevel,
  }) async {
    // Store the raw grants for later removal
    await _saveGrants(heroId, grants);

    // Apply stat modifications
    await _applyStatGrants(heroId, grants, heroLevel);

    // Apply damage resistances (immunity/weakness)
    await _applyDamageResistanceGrants(heroId, grants, heroLevel);

    // Apply token grants
    await _applyTokenGrants(heroId, grants);

    // Apply granted abilities
    await _applyAbilityGrants(heroId, grants);

    // Apply granted skills
    await _applySkillGrants(heroId, grants);

    // Apply recovery bonuses
    await _applyRecoveryGrants(heroId, grants);

    // Apply treasure grants
    await _applyTreasureGrants(heroId, grants);

    // Apply language grants
    await _applyLanguageGrants(heroId, grants);

    // Apply feature grants (mounts, retainers, etc.)
    await _applyFeatureGrants(heroId, grants);
  }

  /// Remove all complication grants from a hero.
  Future<void> removeGrants(String heroId) async {
    final currentGrants = await loadGrants(heroId);
    if (currentGrants == null) return;

    // Clear stat modifications from complication
    await _clearComplicationStatMods(heroId);

    // Clear damage resistance grants
    await _clearDamageResistanceGrants(heroId);

    // Clear token grants
    await _clearTokenGrants(heroId);

    // Clear ability grants
    await _clearAbilityGrants(heroId);

    // Clear skill grants
    await _clearSkillGrants(heroId);

    // Clear recovery grants (legacy static storage)
    await _clearRecoveryGrants(heroId);

    // Clear dynamic modifiers from this complication
    await _dynamicModifiers.removeModifiersFromSource(
      heroId,
      'complication_${currentGrants.complicationId}',
    );

    // Clear treasure grants
    await _clearTreasureGrants(heroId);

    // Clear language grants
    await _clearLanguageGrants(heroId);

    // Clear feature grants
    await _clearFeatureGrants(heroId);

    // Clear stored grants
    await _db.upsertHeroValue(
      heroId: heroId,
      key: _kComplicationGrants,
      textValue: null,
    );
  }

  /// Load currently applied grants for a hero.
  Future<AppliedComplicationGrants?> loadGrants(String heroId) async {
    final values = await _db.getHeroValues(heroId);
    final grantValue = values.firstWhereOrNull((v) => v.key == _kComplicationGrants);
    if (grantValue?.jsonValue == null && grantValue?.textValue == null) {
      return null;
    }
    try {
      final jsonStr = grantValue!.jsonValue ?? grantValue.textValue!;
      return AppliedComplicationGrants.fromJsonString(jsonStr);
    } catch (_) {
      return null;
    }
  }

  /// Save complication choices (user selections for skills, treasures, etc.)
  Future<void> saveComplicationChoices({
    required String heroId,
    required Map<String, String> choices,
  }) async {
    await _db.upsertHeroValue(
      heroId: heroId,
      key: _kComplicationChoices,
      textValue: jsonEncode(choices),
    );
  }

  /// Load complication choices for a hero.
  Future<Map<String, String>> loadComplicationChoices(String heroId) async {
    final values = await _db.getHeroValues(heroId);
    final value = values.firstWhereOrNull((v) => v.key == _kComplicationChoices);
    if (value?.textValue == null && value?.jsonValue == null) {
      return {};
    }
    try {
      final json = jsonDecode(value!.jsonValue ?? value.textValue!);
      if (json is Map) {
        return json.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {}
    return {};
  }

  /// Load tokens granted by complication.
  Future<Map<String, int>> loadTokenGrants(String heroId) async {
    final values = await _db.getHeroValues(heroId);
    final value = values.firstWhereOrNull((v) => v.key == _kComplicationTokens);
    if (value?.textValue == null && value?.jsonValue == null) {
      return {};
    }
    try {
      final json = jsonDecode(value!.jsonValue ?? value.textValue!);
      if (json is Map) {
        return json.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
      }
    } catch (_) {}
    return {};
  }

  /// Load abilities granted by complication.
  Future<Map<String, String>> loadAbilityGrants(String heroId) async {
    final values = await _db.getHeroValues(heroId);
    final value = values.firstWhereOrNull((v) => v.key == _kComplicationAbilities);
    if (value?.textValue == null && value?.jsonValue == null) {
      return {};
    }
    try {
      final json = jsonDecode(value!.jsonValue ?? value.textValue!);
      if (json is Map) {
        return json.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {}
    return {};
  }

  /// Load skills granted by complication.
  Future<List<String>> loadSkillGrants(String heroId) async {
    final values = await _db.getHeroValues(heroId);
    final value = values.firstWhereOrNull((v) => v.key == _kComplicationSkills);
    if (value?.textValue == null && value?.jsonValue == null) {
      return [];
    }
    try {
      final json = jsonDecode(value!.jsonValue ?? value.textValue!);
      if (json is List) {
        return json.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Ensure that any previously granted skills are synced into the hero's skill list.
  Future<void> syncSkillGrants(String heroId) async {
    final storedValues = await loadSkillGrants(heroId);
    if (storedValues.isEmpty) return;

    final lookup = await _loadSkillLookup();
    final resolvedSkillIds = _resolveSkillIdentifiers(storedValues, lookup);
    if (resolvedSkillIds.isEmpty) return;

    if (!const ListEquality<String>().equals(resolvedSkillIds, storedValues)) {
      await _db.upsertHeroValue(
        heroId: heroId,
        key: _kComplicationSkills,
        textValue: jsonEncode(resolvedSkillIds),
      );
    }

    await _ensureHeroHasSkillComponents(heroId, resolvedSkillIds);
  }

  /// Load complication stat modifications.
  Future<HeroStatModifications> loadComplicationStatMods(String heroId) async {
    final values = await _db.getHeroValues(heroId);
    final modsValue = values.firstWhereOrNull((v) => v.key == _kComplicationStatMods);

    if (modsValue?.jsonValue == null && modsValue?.textValue == null) {
      return const HeroStatModifications.empty();
    }

    try {
      final jsonStr = modsValue!.jsonValue ?? modsValue.textValue!;
      return HeroStatModifications.fromJsonString(jsonStr);
    } catch (_) {
      return const HeroStatModifications.empty();
    }
  }

  /// Load recovery bonus from complication.
  Future<int> loadRecoveryBonus(String heroId) async {
    final values = await _db.getHeroValues(heroId);
    final value = values.firstWhereOrNull((v) => v.key == _kComplicationRecoveryBonus);
    return value?.value ?? 0;
  }

  // Private implementation methods

  Future<void> _saveGrants(String heroId, AppliedComplicationGrants grants) async {
    await _db.upsertHeroValue(
      heroId: heroId,
      key: _kComplicationGrants,
      textValue: grants.toJsonString(),
    );
  }

  Future<void> _applyStatGrants(
    String heroId,
    AppliedComplicationGrants grants,
    int heroLevel,
  ) async {
    // Track stat modifications with their sources
    final statMods = <String, List<StatModification>>{};

    void addMod(String stat, int value, String source) {
      final key = stat.toLowerCase();
      statMods.putIfAbsent(key, () => []);
      statMods[key]!.add(StatModification(value: value, source: source));
    }

    final values = await _db.getHeroValues(heroId);

    for (final grant in grants.grants) {
      switch (grant) {
        case SetBaseStatIfNotLowerGrant():
          // Handle setting base stat if not already lower
          final currentValue = _getStatValue(values, grant.stat);
          if (currentValue > grant.value) {
            await _setBaseStat(heroId, grant.stat, grant.value);
          }

        case IncreaseTotalGrant():
          // Skip immunity/weakness - handled by _applyDamageResistanceGrants
          final stat = grant.stat.toLowerCase();
          if (stat == 'immunity' || stat == 'weakness') continue;
          addMod(grant.stat, grant.value, grant.sourceComplicationName);

        case IncreaseTotalPerEchelonGrant():
          // Skip immunity/weakness - handled by _applyDamageResistanceGrants
          final stat = grant.stat.toLowerCase();
          if (stat == 'immunity' || stat == 'weakness') continue;
          final echelon = ((heroLevel - 1) ~/ 3) + 1;
          final value = grant.valuePerEchelon * echelon;
          addMod(grant.stat, value, grant.sourceComplicationName);

        case DecreaseTotalGrant():
          addMod(grant.stat, -grant.value, grant.sourceComplicationName);

        default:
          // Other grant types handled elsewhere
          break;
      }
    }

    // Apply stat modifications with sources
    if (statMods.isNotEmpty) {
      await _setComplicationStatMods(heroId, statMods);
    }
  }

  Future<void> _applyTokenGrants(
    String heroId,
    AppliedComplicationGrants grants,
  ) async {
    final tokens = <String, int>{};

    for (final grant in grants.grants) {
      if (grant is TokenGrant) {
        tokens[grant.tokenType] = (tokens[grant.tokenType] ?? 0) + grant.count;
      }
    }

    if (tokens.isEmpty) return;

    await _db.upsertHeroValue(
      heroId: heroId,
      key: _kComplicationTokens,
      textValue: jsonEncode(tokens),
    );
  }

  Future<void> _applyAbilityGrants(
    String heroId,
    AppliedComplicationGrants grants,
  ) async {
    final abilities = <String, String>{}; // name -> source

    for (final grant in grants.grants) {
      if (grant is AbilityGrant) {
        abilities[grant.abilityName] = grant.sourceComplicationName;
      }
    }

    if (abilities.isEmpty) return;

    await _db.upsertHeroValue(
      heroId: heroId,
      key: _kComplicationAbilities,
      textValue: jsonEncode(abilities),
    );
  }

  Future<void> _applySkillGrants(
    String heroId,
    AppliedComplicationGrants grants,
  ) async {
    final lookup = await _loadSkillLookup();
    final collectedSkillIds = <String>[];

    for (final grant in grants.grants) {
      switch (grant) {
        case SkillGrant():
          final skillId = lookup.nameToId[grant.skillName.toLowerCase()];
          if (skillId != null) {
            collectedSkillIds.add(skillId);
          }
        case SkillFromGroupGrant():
          collectedSkillIds.addAll(grant.selectedSkillIds);
        case SkillFromOptionsGrant():
          if (grant.selectedSkillId != null) {
            collectedSkillIds.add(grant.selectedSkillId!);
          }
        default:
          break;
      }
    }

    final skillIds = _dedupeSkillIds(collectedSkillIds);
    if (skillIds.isEmpty) return;

    await _db.upsertHeroValue(
      heroId: heroId,
      key: _kComplicationSkills,
      textValue: jsonEncode(skillIds),
    );

    await _ensureHeroHasSkillComponents(heroId, skillIds);
  }

  Future<void> _applyRecoveryGrants(
    String heroId,
    AppliedComplicationGrants grants,
  ) async {
    final dynamicMods = <DynamicModifier>[];

    for (final grant in grants.grants) {
      if (grant is IncreaseRecoveryGrant) {
        final formula = _parseFormulaType(grant.value);
        dynamicMods.add(DynamicModifier(
          stat: DynamicModifierStats.recoveryValue,
          formulaType: formula.type,
          formulaParam: formula.param,
          operation: ModifierOperation.add,
          source: 'complication_${grants.complicationId}',
        ));
      }
    }

    if (dynamicMods.isEmpty) return;

    // Store as dynamic modifiers for automatic recalculation
    await _dynamicModifiers.addModifiers(
      heroId,
      'complication_${grants.complicationId}',
      dynamicMods,
    );
  }

  /// Parse a value string into a FormulaType
  ({FormulaType type, String? param}) _parseFormulaType(String value) {
    switch (value.toLowerCase()) {
      case 'highest_characteristic':
        return (type: FormulaType.highestCharacteristic, param: null);
      case 'level':
        return (type: FormulaType.level, param: null);
      case 'half_level':
        return (type: FormulaType.halfLevel, param: null);
      case 'might':
      case 'agility':
      case 'reason':
      case 'intuition':
      case 'presence':
        return (type: FormulaType.characteristic, param: value.toLowerCase());
      default:
        // Assume it's a fixed number
        return (type: FormulaType.fixed, param: value);
    }
  }

  Future<void> _clearComplicationStatMods(String heroId) async {
    await _db.upsertHeroValue(
      heroId: heroId,
      key: _kComplicationStatMods,
      textValue: null,
    );
  }

  Future<void> _clearTokenGrants(String heroId) async {
    await _db.upsertHeroValue(
      heroId: heroId,
      key: _kComplicationTokens,
      textValue: null,
    );
  }

  Future<void> _clearAbilityGrants(String heroId) async {
    await _db.upsertHeroValue(
      heroId: heroId,
      key: _kComplicationAbilities,
      textValue: null,
    );
  }

  Future<void> _clearSkillGrants(String heroId) async {
    // First, get the skills that were granted by the complication
    final values = await _db.getHeroValues(heroId);
    final value = values.firstWhereOrNull((v) => v.key == _kComplicationSkills);

    if (value?.textValue != null || value?.jsonValue != null) {
      try {
        final json = jsonDecode(value!.jsonValue ?? value.textValue!);
        if (json is List) {
          final rawValues = json.map((e) => e.toString()).toList();
          if (rawValues.isNotEmpty) {
            final lookup = await _loadSkillLookup();
            final skillIds = _resolveSkillIdentifiers(rawValues, lookup).toSet();

            if (skillIds.isNotEmpty) {
              final currentSkills = await _db.getHeroComponentIds(heroId, 'skill');
              final updatedSkills = currentSkills
                  .where((id) => !skillIds.contains(id))
                  .toList();
              await _db.setHeroComponentIds(
                heroId: heroId,
                category: 'skill',
                componentIds: updatedSkills,
              );
            }
          }
        }
      } catch (_) {}
    }

    // Clear the tracking key
    await _db.upsertHeroValue(
      heroId: heroId,
      key: _kComplicationSkills,
      textValue: null,
    );
  }

  Future<void> _clearRecoveryGrants(String heroId) async {
    await _db.upsertHeroValue(
      heroId: heroId,
      key: _kComplicationRecoveryBonus,
      value: null,
    );
  }

  // All known damage types - "damage" type applies to all these
  static const _allDamageTypes = [
    'acid',
    'cold',
    'corruption',
    'fire',
    'holy',
    'lightning',
    'poison',
    'psychic',
    'sonic',
    'untyped',
  ];

  Future<void> _applyDamageResistanceGrants(
    String heroId,
    AppliedComplicationGrants grants,
    int heroLevel,
  ) async {
    // Collect all resistance bonuses
    final resistanceBonuses = <String, DamageResistanceBonus>{};

    void addResistance(String stat, String damageType, int value, String sourceName) {
      // "damage" type applies to all damage types
      final typesToApply = damageType.toLowerCase() == 'damage' 
          ? _allDamageTypes 
          : [damageType.toLowerCase()];
      
      for (final type in typesToApply) {
        resistanceBonuses[type] ??= DamageResistanceBonus(damageType: type);
        if (stat == 'immunity') {
          resistanceBonuses[type]!.addImmunity(value, sourceName);
        } else {
          resistanceBonuses[type]!.addWeakness(value, sourceName);
        }
      }
    }

    for (final grant in grants.grants) {
      if (grant is IncreaseTotalGrant) {
        final stat = grant.stat.toLowerCase();
        if (stat == 'immunity' || stat == 'weakness') {
          final damageType = grant.damageType ?? 'untyped';
          final value = grant.dynamicValue == 'level' ? heroLevel : grant.value;
          addResistance(stat, damageType, value, grant.sourceComplicationName);
        }
      } else if (grant is IncreaseTotalPerEchelonGrant) {
        final stat = grant.stat.toLowerCase();
        if (stat == 'immunity' || stat == 'weakness') {
          final echelon = ((heroLevel - 1) ~/ 3) + 1;
          final value = grant.valuePerEchelon * echelon;
          final damageType = grant.damageType ?? 'untyped';
          addResistance(stat, damageType, value, grant.sourceComplicationName);
        }
      }
    }

    if (resistanceBonuses.isEmpty) return;

    // Store the complication damage resistances for tracking
    await _db.upsertHeroValue(
      heroId: heroId,
      key: _kComplicationDamageResistances,
      textValue: jsonEncode(resistanceBonuses.map((k, v) => MapEntry(k, {
        'immunity': v.immunity,
        'weakness': v.weakness,
        'sources': v.sources,
      }))),
    );

    // Load existing resistances and apply bonuses
    final existingJson = await _loadDamageResistancesJson(heroId);
    final updated = _applyResistanceBonuses(existingJson, resistanceBonuses);
    await _saveDamageResistancesJson(heroId, updated);
  }

  Future<void> _clearDamageResistanceGrants(String heroId) async {
    // Load what we stored when applying
    final values = await _db.getHeroValues(heroId);
    final stored = values.firstWhereOrNull((v) => v.key == _kComplicationDamageResistances);
    
    if (stored?.textValue != null || stored?.jsonValue != null) {
      try {
        final json = jsonDecode(stored!.jsonValue ?? stored.textValue!);
        if (json is Map) {
          // Remove these bonuses from the hero's damage resistances
          final currentJson = await _loadDamageResistancesJson(heroId);
          final cleared = _removeResistanceBonuses(currentJson, json.cast<String, dynamic>());
          await _saveDamageResistancesJson(heroId, cleared);
        }
      } catch (_) {}
    }

    await _db.upsertHeroValue(
      heroId: heroId,
      key: _kComplicationDamageResistances,
      textValue: null,
    );
  }

  Future<Map<String, dynamic>> _loadDamageResistancesJson(String heroId) async {
    final values = await _db.getHeroValues(heroId);
    final value = values.firstWhereOrNull((v) => v.key == 'resistances.damage');
    if (value?.jsonValue == null && value?.textValue == null) {
      return {'resistances': []};
    }
    try {
      return jsonDecode(value!.jsonValue ?? value.textValue!) as Map<String, dynamic>;
    } catch (_) {
      return {'resistances': []};
    }
  }

  Future<void> _saveDamageResistancesJson(String heroId, Map<String, dynamic> json) async {
    await _db.upsertHeroValue(
      heroId: heroId,
      key: 'resistances.damage',
      textValue: jsonEncode(json),
    );
  }

  Map<String, dynamic> _applyResistanceBonuses(
    Map<String, dynamic> current,
    Map<String, DamageResistanceBonus> bonuses,
  ) {
    final resistances = List<Map<String, dynamic>>.from(
      (current['resistances'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? [],
    );

    for (final entry in bonuses.entries) {
      final type = entry.key;
      final bonus = entry.value;
      
      final existingIndex = resistances.indexWhere(
        (r) => (r['damageType'] as String?)?.toLowerCase() == type.toLowerCase(),
      );

      if (existingIndex >= 0) {
        // Update existing resistance
        final existing = resistances[existingIndex];
        existing['bonusImmunity'] = ((existing['bonusImmunity'] as num?) ?? 0).toInt() + bonus.immunity;
        existing['bonusWeakness'] = ((existing['bonusWeakness'] as num?) ?? 0).toInt() + bonus.weakness;
        final sources = List<String>.from(existing['sources'] as List? ?? []);
        for (final s in bonus.sources) {
          if (!sources.contains(s)) sources.add(s);
        }
        existing['sources'] = sources;
      } else {
        // Add new resistance
        resistances.add({
          'damageType': bonus.damageType,
          'baseImmunity': 0,
          'baseWeakness': 0,
          'bonusImmunity': bonus.immunity,
          'bonusWeakness': bonus.weakness,
          'sources': bonus.sources,
        });
      }
    }

    return {'resistances': resistances};
  }

  Map<String, dynamic> _removeResistanceBonuses(
    Map<String, dynamic> current,
    Map<String, dynamic> bonusesToRemove,
  ) {
    final resistances = List<Map<String, dynamic>>.from(
      (current['resistances'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? [],
    );

    for (final entry in bonusesToRemove.entries) {
      final type = entry.key;
      final bonus = entry.value as Map<String, dynamic>;
      
      final existingIndex = resistances.indexWhere(
        (r) => (r['damageType'] as String?)?.toLowerCase() == type.toLowerCase(),
      );

      if (existingIndex >= 0) {
        final existing = resistances[existingIndex];
        existing['bonusImmunity'] = ((existing['bonusImmunity'] as num?) ?? 0).toInt() - ((bonus['immunity'] as num?) ?? 0).toInt();
        existing['bonusWeakness'] = ((existing['bonusWeakness'] as num?) ?? 0).toInt() - ((bonus['weakness'] as num?) ?? 0).toInt();
        
        // Remove sources
        final sources = List<String>.from(existing['sources'] as List? ?? []);
        final bonusSources = List<String>.from(bonus['sources'] as List? ?? []);
        sources.removeWhere((s) => bonusSources.contains(s));
        existing['sources'] = sources;

        // Remove entry if no values remain
        if ((existing['baseImmunity'] as num?) == 0 &&
            (existing['baseWeakness'] as num?) == 0 &&
            (existing['bonusImmunity'] as num?) == 0 &&
            (existing['bonusWeakness'] as num?) == 0) {
          resistances.removeAt(existingIndex);
        }
      }
    }

    return {'resistances': resistances};
  }

  Future<void> _applyLanguageGrants(
    String heroId,
    AppliedComplicationGrants grants,
  ) async {
    final languageIds = <String>[];

    for (final grant in grants.grants) {
      if (grant is LanguageGrant) {
        languageIds.addAll(grant.selectedLanguageIds);
      } else if (grant is DeadLanguageGrant) {
        languageIds.addAll(grant.selectedLanguageIds);
      }
    }

    if (languageIds.isEmpty) return;

    await _db.upsertHeroValue(
      heroId: heroId,
      key: _kComplicationLanguages,
      textValue: jsonEncode(languageIds),
    );

    // Also add to hero's language collection
    final currentLanguages = await _db.getHeroComponentIds(heroId, 'language');
    final updatedLanguages = {...currentLanguages, ...languageIds}.toList();
    await _db.setHeroComponentIds(
      heroId: heroId,
      category: 'language',
      componentIds: updatedLanguages,
    );
  }

  Future<void> _clearLanguageGrants(String heroId) async {
    final values = await _db.getHeroValues(heroId);
    final value = values.firstWhereOrNull((v) => v.key == _kComplicationLanguages);
    
    if (value?.textValue != null || value?.jsonValue != null) {
      try {
        final json = jsonDecode(value!.jsonValue ?? value.textValue!);
        if (json is List) {
          final languageIds = json.map((e) => e.toString()).toSet();
          
          // Remove from hero's language collection
          final currentLanguages = await _db.getHeroComponentIds(heroId, 'language');
          final updatedLanguages = currentLanguages.where((id) => !languageIds.contains(id)).toList();
          await _db.setHeroComponentIds(
            heroId: heroId,
            category: 'language',
            componentIds: updatedLanguages,
          );
        }
      } catch (_) {}
    }

    await _db.upsertHeroValue(
      heroId: heroId,
      key: _kComplicationLanguages,
      textValue: null,
    );
  }

  Future<void> _ensureHeroHasSkillComponents(
    String heroId,
    List<String> skillIds,
  ) async {
    if (skillIds.isEmpty) return;

    final currentSkills = await _db.getHeroComponentIds(heroId, 'skill');
    final missing = skillIds.where((id) => !currentSkills.contains(id)).toList();
    if (missing.isEmpty) return;

    final updatedSkills = {...currentSkills, ...skillIds}.toList();
    await _db.setHeroComponentIds(
      heroId: heroId,
      category: 'skill',
      componentIds: updatedSkills,
    );
  }

  Future<_SkillLookup> _loadSkillLookup() async {
    final allComponents = await _db.getAllComponents();
    final skillComponents = allComponents.where((c) => c.type == 'skill');

    final skillIds = <String>{};
    final nameToId = <String, String>{};

    for (final skill in skillComponents) {
      skillIds.add(skill.id);

      try {
        final data = jsonDecode(skill.dataJson) as Map<String, dynamic>;
        final name = (data['name'] as String?) ?? skill.name;
        if (name.isNotEmpty) {
          nameToId[name.toLowerCase()] = skill.id;
        }
      } catch (_) {
        if (skill.name.isNotEmpty) {
          nameToId[skill.name.toLowerCase()] = skill.id;
        }
      }
    }

    return _SkillLookup(skillIds: skillIds, nameToId: nameToId);
  }

  List<String> _resolveSkillIdentifiers(
    Iterable<String> rawIdentifiers,
    _SkillLookup lookup,
  ) {
    final seen = <String>{};
    final resolved = <String>[];

    for (final raw in rawIdentifiers) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      String? id;
      if (lookup.skillIds.contains(trimmed)) {
        id = trimmed;
      } else {
        id = lookup.nameToId[trimmed.toLowerCase()];
      }

      if (id != null && seen.add(id)) {
        resolved.add(id);
      }
    }

    return resolved;
  }

  List<String> _dedupeSkillIds(Iterable<String> skillIds) {
    final seen = <String>{};
    final result = <String>[];
    for (final id in skillIds) {
      if (id.isEmpty) continue;
      if (seen.add(id)) {
        result.add(id);
      }
    }
    return result;
  }
  /// Load languages granted by complication.
  Future<List<String>> loadLanguageGrants(String heroId) async {
    final values = await _db.getHeroValues(heroId);
    final value = values.firstWhereOrNull((v) => v.key == _kComplicationLanguages);
    if (value?.textValue == null && value?.jsonValue == null) {
      return [];
    }
    try {
      final json = jsonDecode(value!.jsonValue ?? value.textValue!);
      if (json is List) {
        return json.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _applyFeatureGrants(
    String heroId,
    AppliedComplicationGrants grants,
  ) async {
    final features = <Map<String, dynamic>>[];

    for (final grant in grants.grants) {
      if (grant is FeatureGrant) {
        features.add({
          'name': grant.featureName,
          'type': grant.featureType,
          'source': grant.sourceComplicationName,
        });
      }
    }

    if (features.isEmpty) return;

    await _db.upsertHeroValue(
      heroId: heroId,
      key: _kComplicationFeatures,
      textValue: jsonEncode(features),
    );
  }

  Future<void> _clearFeatureGrants(String heroId) async {
    await _db.upsertHeroValue(
      heroId: heroId,
      key: _kComplicationFeatures,
      textValue: null,
    );
  }

  /// Load features granted by complication.
  Future<List<Map<String, dynamic>>> loadFeatureGrants(String heroId) async {
    final values = await _db.getHeroValues(heroId);
    final value = values.firstWhereOrNull((v) => v.key == _kComplicationFeatures);
    if (value?.textValue == null && value?.jsonValue == null) {
      return [];
    }
    try {
      final json = jsonDecode(value!.jsonValue ?? value.textValue!);
      if (json is List) {
        return json.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _applyTreasureGrants(
    String heroId,
    AppliedComplicationGrants grants,
  ) async {
    final treasureIds = <String>[];

    for (final grant in grants.grants) {
      if (grant is TreasureGrant && grant.selectedTreasureId != null) {
        treasureIds.add(grant.selectedTreasureId!);
      } else if (grant is LeveledTreasureGrant && grant.selectedTreasureId != null) {
        treasureIds.add(grant.selectedTreasureId!);
      }
    }

    if (treasureIds.isEmpty) return;

    // Store the complication-granted treasure IDs
    await _db.upsertHeroValue(
      heroId: heroId,
      key: _kComplicationTreasures,
      textValue: jsonEncode(treasureIds),
    );

    // Also add them to the hero's treasure collection
    final currentTreasures = await _db.getHeroComponentIds(heroId, 'treasure');
    final updatedTreasures = {...currentTreasures, ...treasureIds}.toList();
    await _db.setHeroComponentIds(
      heroId: heroId,
      category: 'treasure',
      componentIds: updatedTreasures,
    );
  }

  Future<void> _clearTreasureGrants(String heroId) async {
    // Load the complication-granted treasures
    final values = await _db.getHeroValues(heroId);
    final treasureValue = values.firstWhereOrNull((v) => v.key == _kComplicationTreasures);
    
    if (treasureValue?.textValue != null || treasureValue?.jsonValue != null) {
      try {
        final json = jsonDecode(treasureValue!.jsonValue ?? treasureValue.textValue!);
        if (json is List) {
          final treasureIds = json.map((e) => e.toString()).toSet();
          
          // Remove these treasures from the hero's collection
          final currentTreasures = await _db.getHeroComponentIds(heroId, 'treasure');
          final updatedTreasures = currentTreasures.where((id) => !treasureIds.contains(id)).toList();
          await _db.setHeroComponentIds(
            heroId: heroId,
            category: 'treasure',
            componentIds: updatedTreasures,
          );
        }
      } catch (_) {}
    }

    // Clear the stored complication treasures
    await _db.upsertHeroValue(
      heroId: heroId,
      key: _kComplicationTreasures,
      textValue: null,
    );
  }

  /// Load treasures granted by complication.
  Future<List<String>> loadTreasureGrants(String heroId) async {
    final values = await _db.getHeroValues(heroId);
    final value = values.firstWhereOrNull((v) => v.key == _kComplicationTreasures);
    if (value?.textValue == null && value?.jsonValue == null) {
      return [];
    }
    try {
      final json = jsonDecode(value!.jsonValue ?? value.textValue!);
      if (json is List) {
        return json.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _setComplicationStatMods(
    String heroId,
    Map<String, List<StatModification>> statMods,
  ) async {
    final modsModel = HeroStatModifications(modifications: statMods);

    await _db.upsertHeroValue(
      heroId: heroId,
      key: _kComplicationStatMods,
      textValue: modsModel.toJsonString(),
    );
  }

  Future<void> _setBaseStat(String heroId, String stat, int value) async {
    final key = _statToKey(stat);
    if (key == null) return;

    await _db.upsertHeroValue(
      heroId: heroId,
      key: key,
      value: value,
    );
  }

  int _getStatValue(List<db.HeroValue> values, String stat) {
    final key = _statToKey(stat);
    if (key == null) return 0;

    final value = values.firstWhereOrNull((v) => v.key == key);
    return value?.value ?? 0;
  }

  String? _statToKey(String stat) {
    final normalized = stat.toLowerCase().replaceAll(' ', '_');
    return switch (normalized) {
      'might' => 'stats.might',
      'agility' => 'stats.agility',
      'reason' => 'stats.reason',
      'intuition' => 'stats.intuition',
      'presence' => 'stats.presence',
      'size' => 'stats.size',
      'speed' => 'stats.speed',
      'disengage' => 'stats.disengage',
      'stability' => 'stats.stability',
      'stamina' => 'stamina.max',
      'recoveries' => 'recoveries.max',
      'renown' => 'stats.renown',
      'wealth' => 'stats.wealth',
      'project_points' => 'stats.project_points',
      'saving_throw' || 'save' => 'conditions.save_ends',
      _ => null,
    };
  }

  // ============================================================
  // Token Tracking (current values during play)
  // ============================================================

  /// Load current token values (how many the hero currently has).
  /// These can be different from max values (grant values) during play.
  Future<Map<String, int>> loadCurrentTokenValues(String heroId) async {
    final values = await _db.getHeroValues(heroId);
    final value = values.firstWhereOrNull((v) => v.key == _kComplicationTokensCurrent);
    if (value?.textValue == null && value?.jsonValue == null) {
      // If no current values saved, return the max values (grant values)
      return loadTokenGrants(heroId);
    }
    try {
      final json = jsonDecode(value!.jsonValue ?? value.textValue!);
      if (json is Map) {
        return json.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
      }
    } catch (_) {}
    return loadTokenGrants(heroId);
  }

  /// Save current token values.
  Future<void> saveCurrentTokenValues(String heroId, Map<String, int> tokens) async {
    await _db.upsertHeroValue(
      heroId: heroId,
      key: _kComplicationTokensCurrent,
      textValue: jsonEncode(tokens),
    );
  }

  /// Update a single token's current value.
  Future<void> updateTokenValue(String heroId, String tokenType, int newValue) async {
    final current = await loadCurrentTokenValues(heroId);
    current[tokenType] = newValue;
    await saveCurrentTokenValues(heroId, current);
  }

  /// Reset all tokens to their max values.
  Future<void> resetTokensToMax(String heroId) async {
    final maxValues = await loadTokenGrants(heroId);
    await saveCurrentTokenValues(heroId, maxValues);
  }

  // Storage keys
  static const _kComplicationGrants = 'complication.applied_grants';
  static const _kComplicationChoices = 'complication.choices';
  static const _kComplicationStatMods = 'complication.stat_mods';
  static const _kComplicationTokens = 'complication.tokens';
  static const _kComplicationTokensCurrent = 'complication.tokens_current';
  static const _kComplicationAbilities = 'complication.abilities';
  static const _kComplicationSkills = 'complication.skills';
  static const _kComplicationRecoveryBonus = 'complication.recovery_bonus';
  static const _kComplicationTreasures = 'complication.treasures';
  static const _kComplicationDamageResistances = 'complication.damage_resistances';
  static const _kComplicationLanguages = 'complication.languages';
  static const _kComplicationFeatures = 'complication.features';
}

  class _SkillLookup {
    const _SkillLookup({
      required this.skillIds,
      required this.nameToId,
    });

    final Set<String> skillIds;
    final Map<String, String> nameToId;
  }

/// Provider for the complication grants service.
final complicationGrantsServiceProvider = Provider<ComplicationGrantsService>((ref) {
  final database = ref.read(appDatabaseProvider);
  return ComplicationGrantsService(database);
});
