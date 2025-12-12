import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart' as db;
import '../db/providers.dart';
import '../models/complication_grant_models.dart';
import '../models/damage_resistance_model.dart';
import '../models/dynamic_modifier_model.dart';
import '../models/stat_modification_model.dart';
import 'dynamic_modifiers_service.dart';
import '../repositories/hero_entry_repository.dart';

/// Service for managing complication grants.
/// Handles parsing complications, applying grants to heroes, and removing them when complications change.
class ComplicationGrantsService {
  ComplicationGrantsService(this._db)
      : _dynamicModifiers = DynamicModifiersService(_db),
        _entries = HeroEntryRepository(_db);

  final db.AppDatabase _db;
  final DynamicModifiersService _dynamicModifiers;
  final HeroEntryRepository _entries;

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
  /// 
  /// This clears all entries with sourceType='complication' from hero_entries,
  /// regardless of whether the grants config exists. This ensures orphaned
  /// entries are always cleaned up.
  Future<void> removeGrants(String heroId) async {
    print('[ComplicationGrantsService] removeGrants called for heroId: $heroId');
    
    // Debug: List ability entries BEFORE clearing
    final entriesBefore = await (_db.select(_db.heroEntries)
          ..where((t) => t.heroId.equals(heroId) & t.entryType.equals('ability')))
        .get();
    print('[ComplicationGrantsService] BEFORE _clearAbilityGrants: ${entriesBefore.map((e) => '${e.entryId} (source: ${e.sourceType})').toList()}');
    
    final currentGrants = await loadGrants(heroId);

    // Clear stat modifications from complication
    await _clearComplicationStatMods(heroId);

    // Clear damage resistance grants
    await _clearDamageResistanceGrants(heroId);

    // Clear token grants
    await _clearTokenGrants(heroId);

    // Clear ability grants - always clear even if config is null
    await _clearAbilityGrants(heroId);
    
    // Debug: List ability entries AFTER clearing
    final entriesAfter = await (_db.select(_db.heroEntries)
          ..where((t) => t.heroId.equals(heroId) & t.entryType.equals('ability')))
        .get();
    print('[ComplicationGrantsService] AFTER _clearAbilityGrants: ${entriesAfter.map((e) => '${e.entryId} (source: ${e.sourceType})').toList()}');

    // Clear skill grants - always clear even if config is null
    await _clearSkillGrants(heroId);

    // Clear recovery grants (legacy static storage)
    await _clearRecoveryGrants(heroId);

    // Clear dynamic modifiers from this complication (only if we know the ID)
    if (currentGrants != null) {
      await _dynamicModifiers.removeModifiersFromSource(
        heroId,
        'complication_${currentGrants.complicationId}',
      );
    }

    // Clear treasure grants - always clear even if config is null
    await _clearTreasureGrants(heroId);

    // Clear language grants - always clear even if config is null
    await _clearLanguageGrants(heroId);

    // Clear feature grants - always clear even if config is null
    await _clearFeatureGrants(heroId);

    // Clear stored grants config
    await _db.deleteHeroConfig(heroId, _kComplicationGrants);
  }

  /// Load currently applied grants for a hero.
  Future<AppliedComplicationGrants?> loadGrants(String heroId) async {
    final config = await _db.getHeroConfigValue(heroId, _kComplicationGrants);
    if (config == null) return null;
    try {
      return AppliedComplicationGrants.fromJsonString(jsonEncode(config));
    } catch (_) {
      return null;
    }
  }

  /// Save complication choices (user selections for skills, treasures, etc.)
  Future<void> saveComplicationChoices({
    required String heroId,
    required Map<String, String> choices,
  }) async {
    await _db.setHeroConfig(
      heroId: heroId,
      configKey: _kComplicationChoices,
      value: choices,
    );
  }

  /// Load complication choices for a hero.
  Future<Map<String, String>> loadComplicationChoices(String heroId) async {
    final config = await _db.getHeroConfigValue(heroId, _kComplicationChoices);
    if (config == null) return {};
    return config.map((k, v) => MapEntry(k.toString(), v.toString()));
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
    final entries =
        await _entries.listEntriesByType(heroId, 'ability');
    final map = <String, String>{};
    for (final e in entries.where((e) => e.sourceType == 'complication')) {
      map[e.entryId] = e.sourceId;
    }
    return map;
  }

  /// Load skills granted by complication.
  Future<List<String>> loadSkillGrants(String heroId) async {
    final entries =
        await _entries.listEntriesByType(heroId, 'skill');
    return entries
        .where((e) => e.sourceType == 'complication')
        .map((e) => e.entryId)
        .toList();
  }

  /// Ensure that any previously granted skills are synced into the hero's skill list.
  Future<void> syncSkillGrants(String heroId) async {
    final storedValues = await loadSkillGrants(heroId);
    if (storedValues.isEmpty) return;

    await _entries.addEntriesFromSource(
      heroId: heroId,
      sourceType: 'complication',
      sourceId: 'complication_sync',
      entryType: 'skill',
      entryIds: storedValues,
      gainedBy: 'grant',
    );
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

  /// Watch complication stat modifications - automatically updates when values change.
  Stream<HeroStatModifications> watchComplicationStatMods(String heroId) {
    return _db.watchHeroValues(heroId).map((values) {
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
    });
  }

  /// Load recovery bonus from complication.
  Future<int> loadRecoveryBonus(String heroId) async {
    final values = await _db.getHeroValues(heroId);
    final value = values.firstWhereOrNull((v) => v.key == _kComplicationRecoveryBonus);
    return value?.value ?? 0;
  }

  /// Load damage resistances for a hero.
  Future<HeroDamageResistances> loadDamageResistances(String heroId) async {
    final values = await _db.getHeroValues(heroId);
    final value = values.firstWhereOrNull((v) => v.key == _kDamageResistances);
    if (value?.jsonValue == null && value?.textValue == null) {
      return HeroDamageResistances.empty;
    }
    try {
      final jsonStr = value!.jsonValue ?? value.textValue!;
      return HeroDamageResistances.fromJsonString(jsonStr);
    } catch (_) {
      return HeroDamageResistances.empty;
    }
  }

  /// Save damage resistances for a hero.
  Future<void> saveDamageResistances(
    String heroId,
    HeroDamageResistances resistances,
  ) async {
    await _db.upsertHeroValue(
      heroId: heroId,
      key: _kDamageResistances,
      textValue: resistances.toJsonString(),
    );
  }

  // Private implementation methods

  Future<void> _saveGrants(String heroId, AppliedComplicationGrants grants) async {
    await _db.setHeroConfig(
      heroId: heroId,
      configKey: _kComplicationGrants,
      value: grants.toJson(),
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
    await _setComplicationStatMods(heroId, statMods);
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

    final comps = await _db.getAllComponents();
    final nameToId = {
      for (final c in comps.where((c) => c.type == 'ability'))
        c.name.toLowerCase(): c.id
    };
    final abilityIds = <String>[];
    abilities.forEach((name, _) {
      final id = nameToId[name.toLowerCase()] ?? name;
      abilityIds.add(id);
    });

    await _entries.addEntriesFromSource(
      heroId: heroId,
      sourceType: 'complication',
      sourceId: grants.complicationId,
      entryType: 'ability',
      entryIds: abilityIds,
      gainedBy: 'grant',
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

    await _entries.addEntriesFromSource(
      heroId: heroId,
      sourceType: 'complication',
      sourceId: grants.complicationId,
      entryType: 'skill',
      entryIds: skillIds,
      gainedBy: 'grant',
    );
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
    print('[ComplicationGrantsService] _clearAbilityGrants: Deleting where heroId=$heroId, entryType=ability, sourceType=complication');
    final deleted = await (_db.delete(_db.heroEntries)
          ..where((t) =>
              t.heroId.equals(heroId) &
              t.entryType.equals('ability') &
              t.sourceType.equals('complication')))
        .go();
    print('[ComplicationGrantsService] _clearAbilityGrants: Deleted $deleted rows');
  }

  Future<void> _clearSkillGrants(String heroId) async {
    await (_db.delete(_db.heroEntries)
          ..where((t) =>
              t.heroId.equals(heroId) &
              t.entryType.equals('skill') &
              t.sourceType.equals('complication')))
        .go();
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
    // Clear old complication resistance entries first
    await _clearDamageResistanceGrants(heroId);

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

    // Store each resistance bonus in hero_entries for tracking
    for (final entry in resistanceBonuses.entries) {
      final type = entry.key;
      final bonus = entry.value;
      await _entries.addEntry(
        heroId: heroId,
        entryType: 'resistance',
        entryId: type,
        sourceType: 'complication',
        sourceId: grants.complicationId,
        gainedBy: 'grant',
        payload: {
          'immunity': bonus.immunity,
          'weakness': bonus.weakness,
          'sources': bonus.sources,
        },
      );
    }

    await _rebuildDamageResistances(heroId);
  }

  Future<void> _clearDamageResistanceGrants(String heroId) async {
    await (_db.delete(_db.heroEntries)
          ..where((t) =>
              t.heroId.equals(heroId) &
              t.entryType.equals('resistance') &
              t.sourceType.equals('complication')))
        .go();
    await _rebuildDamageResistances(heroId);
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

    await _entries.addEntriesFromSource(
      heroId: heroId,
      sourceType: 'complication',
      sourceId: grants.complicationId,
      entryType: 'language',
      entryIds: languageIds,
      gainedBy: 'grant',
    );
  }

  /// Rebuild damage resistances from hero_entries, combining all sources.
  /// 
  /// This method reads ALL resistance entries from hero_entries (both ancestry
  /// and complication sourced) and combines them into the final resistances.damage.
  Future<void> _rebuildDamageResistances(String heroId) async {
    // Load existing resistances to preserve base values
    final current = await loadDamageResistances(heroId);
    
    // Collect ALL resistance entries from hero_entries (ancestry + complication)
    final entries = await _entries.listEntriesByType(heroId, 'resistance');
    final combinedBonuses = <String, DamageResistanceBonus>{};
    
    for (final e in entries) {
      int immunity = 0, weakness = 0;
      final sources = <String>[];
      if (e.payload != null) {
        try {
          final decoded = jsonDecode(e.payload!);
          if (decoded is Map) {
            immunity = (decoded['immunity'] as num?)?.toInt() ?? 0;
            weakness = (decoded['weakness'] as num?)?.toInt() ?? 0;
            if (decoded['sources'] is List) {
              sources.addAll(
                  (decoded['sources'] as List).map((s) => s.toString()));
            }
          }
        } catch (_) {}
      }
      
      final key = e.entryId.toLowerCase();
      combinedBonuses[key] ??= DamageResistanceBonus(damageType: e.entryId);
      final source = sources.isNotEmpty ? sources.first : e.sourceType;
      combinedBonuses[key]!.addImmunity(immunity, source);
      combinedBonuses[key]!.addWeakness(weakness, source);
    }
    
    // Apply all combined bonuses (this replaces bonus values with the totals from all sources)
    final updated = current.applyBonuses(combinedBonuses);
    await saveDamageResistances(heroId, updated);
  }

  Future<void> _clearLanguageGrants(String heroId) async {
    await (_db.delete(_db.heroEntries)
          ..where((t) =>
              t.heroId.equals(heroId) &
              t.entryType.equals('language') &
              t.sourceType.equals('complication')))
        .go();
  }

  // ignore: unused_element
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

  // ignore: unused_element
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
    final entries =
        await _entries.listEntriesByType(heroId, 'language');
    return entries
        .where((e) => e.sourceType == 'complication')
        .map((e) => e.entryId)
        .toList();
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

    final comps = await _db.getAllComponents();
    final nameToId = {
      for (final c in comps) c.name.toLowerCase(): c.id,
    };
    final ids = features
        .map((f) => nameToId[f['name']!.toString().toLowerCase()] ??
            f['name']!.toString())
        .toList();

    await _entries.addEntriesFromSource(
      heroId: heroId,
      sourceType: 'complication',
      sourceId: grants.complicationId,
      entryType: 'feature',
      entryIds: ids,
      gainedBy: 'grant',
    );
  }

  Future<void> _clearFeatureGrants(String heroId) async {
    await (_db.delete(_db.heroEntries)
          ..where((t) =>
              t.heroId.equals(heroId) &
              t.entryType.equals('feature') &
              t.sourceType.equals('complication')))
        .go();
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
    if (treasureIds.isEmpty) return;

    await _entries.addEntriesFromSource(
      heroId: heroId,
      sourceType: 'complication',
      sourceId: grants.complicationId,
      entryType: 'treasure',
      entryIds: treasureIds,
      gainedBy: 'grant',
    );
  }

  Future<void> _clearTreasureGrants(String heroId) async {
    await (_db.delete(_db.heroEntries)
          ..where((t) =>
              t.heroId.equals(heroId) &
              t.entryType.equals('treasure') &
              t.sourceType.equals('complication')))
        .go();
  }

  /// Load treasures granted by complication.
  Future<List<String>> loadTreasureGrants(String heroId) async {
    final entries = await _entries.listEntriesByType(heroId, 'treasure');
    return entries
        .where((e) => e.sourceType == 'complication')
        .map((e) => e.entryId)
        .toList();
  }

  Future<void> _setComplicationStatMods(
    String heroId,
    Map<String, List<StatModification>> statMods,
  ) async {
    if (statMods.isEmpty) return;

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
  // ignore: unused_field
  static const _kComplicationAbilities = 'complication.abilities';
  // ignore: unused_field
  static const _kComplicationSkills = 'complication.skills';
  static const _kComplicationRecoveryBonus = 'complication.recovery_bonus';
  // ignore: unused_field
  static const _kComplicationTreasures = 'complication.treasures';
  // ignore: unused_field
  static const _kComplicationDamageResistances = 'complication.damage_resistances';
  // ignore: unused_field
  static const _kComplicationLanguages = 'complication.languages';
  static const _kComplicationFeatures = 'complication.features';
  static const _kDamageResistances = 'resistances.damage';
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
