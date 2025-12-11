import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart' as db;
import '../models/damage_resistance_model.dart';
import '../repositories/hero_entry_repository.dart';
import '../repositories/hero_repository.dart';
import 'hero_config_service.dart';
import 'kit_bonus_service.dart';

/// Normalizes hero_entries to ensure correct metadata and completeness.
/// 
/// This class is responsible for:
/// 1. Migrating legacy data from hero_values to hero_entries/hero_config
/// 2. Cleaning up invalid or duplicate entries
/// 3. Recomputing aggregate values (like resistances.damage)
/// 4. Ensuring idempotent operation (safe to run multiple times)
class HeroEntryNormalizer {
  HeroEntryNormalizer(this._db)
      : _entries = HeroEntryRepository(_db),
        _config = HeroConfigService(_db),
        _heroRepo = HeroRepository(_db);

  final db.AppDatabase _db;
  final HeroEntryRepository _entries;
  final HeroConfigService _config;
  final HeroRepository _heroRepo;

  /// Keys in hero_values that should be removed entirely.
  /// These prefixes represent legacy data that has been migrated to
  /// hero_entries or hero_config.
  /// 
  /// After migration, hero_values should contain ONLY:
  /// - numeric stats (stats.*, stamina.*, recoveries.*, etc.)
  /// - conditions/state (conditions.*, surges.*, heroic.*)
  /// - aggregate computed values (resistances.damage)
  /// - user-managed modifiers (mods.map)
  /// - score values (score.*)
  /// - potency values (potency.*)
  /// - project points (projects.*)
  static const List<String> _bannedValueKeysPrefixes = [
    // === BASICS (content identifiers → hero_entries) ===
    'basics.className',
    'basics.subclass',
    'basics.ancestry',
    'basics.career',
    'basics.kit',
    
    // === ANCESTRY legacy content ===
    'ancestry.granted_abilities',
    'ancestry.applied_bonuses',
    'ancestry.condition_immunities',
    'ancestry.stat_mods',
    'ancestry.selected_traits', // migrate to hero_entries as ancestry_trait
    
    // === PERK legacy content ===
    'perk_abilities.',
    'perk_grant.', // migrate to hero_config as perk.<perkId>.selections
    
    // === COMPLICATION legacy content ===
    'complication.applied_grants',
    'complication.abilities',
    'complication.skills',
    'complication.features',
    'complication.treasures',
    'complication.languages',
    'complication.damage_resistances',
    'complication.stat_mods',
    
    // === CLASS FEATURE legacy content ===
    'class_feature.',
    'class_feature_abilities',
    'class_feature_skills',
    'class_feature_stat_mods',
    'class_feature_resistances',
    
    // === KIT legacy content ===
    'kit_grants.',
    'kit.abilities',
    'kit.equipment',
    'kit.stat_bonuses',
    'kit.signature_ability',
    
    // === STRIFE legacy content (equipment bonuses only) ===
    'strife.equipment_bonuses',
    
    // === CAREER legacy content (content only, not config) ===
    'career.abilities',
    'career.skills_granted',
    'career.perks_granted',
    
    // === CULTURE legacy content (content only, not config) ===
    'culture.skills_granted',
    'culture.languages_granted',
    
    // === FAITH legacy content (move to hero_entries) ===
    'faith.deity',
    'faith.domain',
  ];

  /// Config keys that should be removed entirely from hero_config.
  /// These represent legacy storage patterns that have been migrated.
  static const List<String> _bannedConfigKeys = [
    // === COMPLICATION legacy content blob (now in hero_entries) ===
    'complication.applied_grants',
    'complication.stat_mods',
    
    // === SUBCLASS keys that belong in hero_entries, not config ===
    'class_feature.subclass_key',
    'strife.class_feature.subclass_key',
    
    // === ANCESTRY legacy stat mods (now in hero_entries) ===  
    'ancestry.stat_mods',
  ];

  /// Entry types that should not exist in hero_entries (computed, not stored).
  static const List<String> _bannedEntryTypes = [
    'combined_equipment_bonuses',
    'equipment_bonuses',
  ];

  /// Main normalization entry point.
  /// Runs all migration and cleanup steps in a single transaction.
  /// This method is IDEMPOTENT - safe to run multiple times.
  Future<void> normalize(String heroId) async {
    await _db.transaction(() async {
      // === PHASE 1: Migrate legacy data to hero_entries/hero_config ===
      await _migrateBasicsToEntries(heroId);
      await _migrateFaithToEntries(heroId);
      await _migrateLegacyAncestryData(heroId);
      await _migrateLegacyClassFeatureGrants(heroId);
      await _migrateLegacyKitGrants(heroId);
      await _migrateLegacyPerkGrants(heroId);
      await _migrateClassFeatureSelections(heroId);
      await _migrateSubclassKeyToEntries(heroId);
      
      // === PHASE 2: Remove banned legacy keys from hero_values ===
      await _removeBannedValues(heroId);
      
      // === PHASE 3: Remove banned legacy keys from hero_config ===
      await _removeBannedConfigKeys(heroId);
      
      // === PHASE 4: Ensure hero_entries from hero_config selections ===
      await _ensureAncestrySelections(heroId);
      await _ensureCultureSelections(heroId);
      await _ensureCareerSelections(heroId);
      await _ensureStrifeSelections(heroId);
      await _ensureEquipment(heroId);
      
      // === PHASE 5: Cleanup and validation ===
      await _removeInvalidEntries(heroId);
      await _removeBannedEntryTypes(heroId);
      await _dedupe(heroId);
      await _dedupeConfig(heroId);
      
      // === PHASE 6: Recompute aggregate values ===
      await _recomputeResistances(heroId);
    });
  }

  // ===========================================================================
  // PHASE 1: LEGACY DATA MIGRATION
  // ===========================================================================

  /// Migrate basics.* identifiers from hero_values to hero_entries.
  /// These are content choices, not numeric state.
  Future<void> _migrateBasicsToEntries(String heroId) async {
    final rows = await _db.getHeroValues(heroId);
    String? text(String key) =>
        rows.firstWhereOrNull((v) => v.key == key)?.textValue;

    // Class → hero_entry (entry_type="class", source_type="manual_choice")
    final classId = text('basics.className');
    if (classId != null && classId.isNotEmpty) {
      await _entries.addEntry(
        heroId: heroId,
        entryType: 'class',
        entryId: classId,
        sourceType: 'manual_choice',
        sourceId: classId,
        gainedBy: 'choice',
      );
    }

    // Subclass → hero_entry
    final subclassId = text('basics.subclass');
    if (subclassId != null && subclassId.isNotEmpty) {
      await _entries.addEntry(
        heroId: heroId,
        entryType: 'subclass',
        entryId: subclassId,
        sourceType: 'manual_choice',
        sourceId: subclassId,
        gainedBy: 'choice',
      );
    }

    // Ancestry → hero_entry
    final ancestryId = text('basics.ancestry');
    if (ancestryId != null && ancestryId.isNotEmpty) {
      await _entries.addEntry(
        heroId: heroId,
        entryType: 'ancestry',
        entryId: ancestryId,
        sourceType: 'manual_choice',
        sourceId: ancestryId,
        gainedBy: 'choice',
      );
    }

    // Career → hero_entry
    final careerId = text('basics.career');
    if (careerId != null && careerId.isNotEmpty) {
      await _entries.addEntry(
        heroId: heroId,
        entryType: 'career',
        entryId: careerId,
        sourceType: 'manual_choice',
        sourceId: careerId,
        gainedBy: 'choice',
      );
    }

    // Kit → hero_entry
    final kitId = text('basics.kit');
    if (kitId != null && kitId.isNotEmpty) {
      await _entries.addEntry(
        heroId: heroId,
        entryType: 'kit',
        entryId: kitId,
        sourceType: 'manual_choice',
        sourceId: kitId,
        gainedBy: 'choice',
      );
    }
  }

  /// Migrate faith.* (deity/domain) from hero_values to hero_entries.
  Future<void> _migrateFaithToEntries(String heroId) async {
    final rows = await _db.getHeroValues(heroId);
    String? text(String key) =>
        rows.firstWhereOrNull((v) => v.key == key)?.textValue;

    final deityId = text('faith.deity');
    if (deityId != null && deityId.isNotEmpty) {
      await _entries.addEntry(
        heroId: heroId,
        entryType: 'deity',
        entryId: deityId,
        sourceType: 'manual_choice',
        sourceId: deityId,
        gainedBy: 'choice',
      );
    }

    final domainStr = text('faith.domain');
    if (domainStr != null && domainStr.isNotEmpty) {
      final domains = domainStr
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      for (final domain in domains) {
        await _entries.addEntry(
          heroId: heroId,
          entryType: 'domain',
          entryId: domain,
          sourceType: 'deity',
          sourceId: deityId ?? 'domain_choice',
          gainedBy: 'choice',
        );
      }
    }
  }

  /// Migrate legacy ancestry data (selected_traits, stat_mods, resistances).
  Future<void> _migrateLegacyAncestryData(String heroId) async {
    final rows = await _db.getHeroValues(heroId);

    // Migrate ancestry.selected_traits to hero_entries
    final traitValue = rows.firstWhereOrNull((v) => v.key == 'ancestry.selected_traits');
    if (traitValue != null) {
      final traits = _parseJsonList(traitValue);
      for (final traitId in traits) {
        await _entries.addEntry(
          heroId: heroId,
          entryType: 'ancestry_trait',
          entryId: traitId,
          sourceType: 'ancestry',
          sourceId: 'ancestry_trait_choice',
          gainedBy: 'choice',
        );
      }
    }

    // Migrate ancestry.granted_abilities
    final abilitiesRow = rows.firstWhereOrNull((v) => v.key == 'ancestry.granted_abilities');
    if (abilitiesRow != null) {
      final abilities = _parseJsonList(abilitiesRow);
      for (final ability in abilities) {
        await _entries.addEntry(
          heroId: heroId,
          entryType: 'ability',
          entryId: ability,
          sourceType: 'ancestry',
          sourceId: 'ancestry_grant',
          gainedBy: 'grant',
        );
      }
    }

    // Migrate ancestry.stat_mods
    final statModsRow = rows.firstWhereOrNull((v) => v.key == 'ancestry.stat_mods');
    if (statModsRow != null) {
      final mods = _parseJsonMap(statModsRow);
      if (mods.isNotEmpty) {
        await _entries.addEntry(
          heroId: heroId,
          entryType: 'stat_mod',
          entryId: 'ancestry_stat_mods',
          sourceType: 'ancestry',
          sourceId: 'ancestry_grant',
          gainedBy: 'grant',
          payload: {'mods': mods},
        );
      }
    }

    // Migrate ancestry.condition_immunities as resistance entries
    final immunitiesRow = rows.firstWhereOrNull((v) => v.key == 'ancestry.condition_immunities');
    if (immunitiesRow != null) {
      final immunities = _parseJsonList(immunitiesRow);
      for (final conditionType in immunities) {
        await _entries.addEntry(
          heroId: heroId,
          entryType: 'condition_immunity',
          entryId: conditionType,
          sourceType: 'ancestry',
          sourceId: 'ancestry_grant',
          gainedBy: 'grant',
        );
      }
    }
  }

  /// Migrate legacy perk_grant.* keys to hero_config as perk.<perkId>.selections.
  Future<void> _migrateLegacyPerkGrants(String heroId) async {
    final rows = await _db.getHeroValues(heroId);
    
    // Group all perk_grant.* keys by perkId
    final perkGrants = <String, Map<String, dynamic>>{};
    
    for (final row in rows) {
      if (!row.key.startsWith('perk_grant.')) continue;
      
      // Parse: perk_grant.<perkId>.<grantType>
      final parts = row.key.split('.');
      if (parts.length < 3) continue;
      
      final perkId = parts[1];
      final grantType = parts.sublist(2).join('.');
      
      perkGrants.putIfAbsent(perkId, () => {});
      
      final value = row.jsonValue ?? row.textValue;
      if (value != null && value.isNotEmpty) {
        try {
          final decoded = jsonDecode(value);
          if (decoded is Map && decoded['list'] is List) {
            perkGrants[perkId]![grantType] = decoded['list'];
          } else {
            perkGrants[perkId]![grantType] = decoded;
          }
        } catch (_) {
          perkGrants[perkId]![grantType] = value;
        }
      }
    }
    
    // Write each perk's selections to hero_config
    for (final entry in perkGrants.entries) {
      final perkId = entry.key;
      final selections = entry.value;
      
      if (selections.isNotEmpty) {
        await _config.setConfigValue(
          heroId: heroId,
          key: 'perk.$perkId.selections',
          value: selections,
        );
      }
    }
  }

  /// Migrate legacy class feature grants from hero_values to hero_entries.
  Future<void> _migrateLegacyClassFeatureGrants(String heroId) async {
    final rows = await _db.getHeroValues(heroId);
    
    // Migrate class_feature_abilities
    final abilitiesRow = rows.firstWhereOrNull(
      (v) => v.key == 'class_feature_abilities' || v.key.startsWith('class_feature.abilities'),
    );
    if (abilitiesRow != null) {
      final abilities = _parseJsonList(abilitiesRow);
      for (final ability in abilities) {
        await _entries.addEntry(
          heroId: heroId,
          entryType: 'ability',
          entryId: ability,
          sourceType: 'class_feature',
          sourceId: 'legacy_migration',
          gainedBy: 'grant',
        );
      }
    }
    
    // Migrate class_feature_skills
    final skillsRow = rows.firstWhereOrNull(
      (v) => v.key == 'class_feature_skills' || v.key.startsWith('class_feature.skills'),
    );
    if (skillsRow != null) {
      final skills = _parseJsonList(skillsRow);
      for (final skill in skills) {
        await _entries.addEntry(
          heroId: heroId,
          entryType: 'skill',
          entryId: skill,
          sourceType: 'class_feature',
          sourceId: 'legacy_migration',
          gainedBy: 'grant',
        );
      }
    }
    
    // Migrate class_feature_stat_mods
    final statModsRow = rows.firstWhereOrNull(
      (v) => v.key == 'class_feature_stat_mods' || v.key.startsWith('class_feature.stat_mods'),
    );
    if (statModsRow != null) {
      final mods = _parseJsonMap(statModsRow);
      if (mods.isNotEmpty) {
        await _entries.addEntry(
          heroId: heroId,
          entryType: 'stat_mod',
          entryId: 'legacy_class_feature_stat_mods',
          sourceType: 'class_feature',
          sourceId: 'legacy_migration',
          gainedBy: 'grant',
          payload: {'mods': mods},
        );
      }
    }
    
    // Migrate class_feature_resistances
    final resistancesRow = rows.firstWhereOrNull(
      (v) => v.key == 'class_feature_resistances' || v.key.startsWith('class_feature.resistances'),
    );
    if (resistancesRow != null) {
      final resistances = _parseJsonMap(resistancesRow);
      final immunities = resistances['immunities'];
      if (immunities != null) {
        await _entries.addEntry(
          heroId: heroId,
          entryType: 'immunity',
          entryId: 'legacy_class_feature_immunities',
          sourceType: 'class_feature',
          sourceId: 'legacy_migration',
          gainedBy: 'grant',
          payload: {'immunities': _normalizeToList(immunities)},
        );
      }
      final weaknesses = resistances['weaknesses'];
      if (weaknesses != null) {
        await _entries.addEntry(
          heroId: heroId,
          entryType: 'weakness',
          entryId: 'legacy_class_feature_weaknesses',
          sourceType: 'class_feature',
          sourceId: 'legacy_migration',
          gainedBy: 'grant',
          payload: {'weaknesses': _normalizeToList(weaknesses)},
        );
      }
    }
  }

  /// Migrate legacy kit grants from hero_values to hero_entries.
  Future<void> _migrateLegacyKitGrants(String heroId) async {
    final rows = await _db.getHeroValues(heroId);
    
    // Migrate kit.abilities or kit_grants.abilities
    final kitAbilitiesRow = rows.firstWhereOrNull(
      (v) => v.key == 'kit.abilities' || v.key.startsWith('kit_grants.abilities'),
    );
    if (kitAbilitiesRow != null) {
      final abilities = _parseJsonList(kitAbilitiesRow);
      for (final ability in abilities) {
        await _entries.addEntry(
          heroId: heroId,
          entryType: 'ability',
          entryId: ability,
          sourceType: 'kit',
          sourceId: 'legacy_migration',
          gainedBy: 'grant',
        );
      }
    }
    
    // Migrate kit.equipment
    final kitEquipmentRow = rows.firstWhereOrNull(
      (v) => v.key == 'kit.equipment' || v.key.startsWith('kit_grants.equipment'),
    );
    if (kitEquipmentRow != null) {
      final equipment = _parseJsonList(kitEquipmentRow);
      for (final item in equipment) {
        await _entries.addEntry(
          heroId: heroId,
          entryType: 'equipment',
          entryId: item,
          sourceType: 'kit',
          sourceId: 'legacy_migration',
          gainedBy: 'grant',
        );
      }
    }
    
    // Migrate kit.signature_ability
    final signatureRow = rows.firstWhereOrNull(
      (v) => v.key == 'kit.signature_ability' || v.key.startsWith('kit_grants.signature'),
    );
    if (signatureRow != null) {
      final signatureAbility = signatureRow.textValue;
      if (signatureAbility != null && signatureAbility.isNotEmpty) {
        await _entries.addEntry(
          heroId: heroId,
          entryType: 'ability',
          entryId: signatureAbility,
          sourceType: 'kit',
          sourceId: 'legacy_migration',
          gainedBy: 'grant',
          payload: {'source': 'kit_signature'},
        );
      }
    }
    
    // Migrate kit.stat_bonuses
    final kitStatBonusesRow = rows.firstWhereOrNull(
      (v) => v.key == 'kit.stat_bonuses' || v.key.startsWith('kit_grants.stat_bonuses'),
    );
    if (kitStatBonusesRow != null) {
      final bonuses = _parseJsonMap(kitStatBonusesRow);
      if (bonuses.isNotEmpty) {
        await _entries.addEntry(
          heroId: heroId,
          entryType: 'kit_stat_bonus',
          entryId: 'legacy_kit_stat_bonuses',
          sourceType: 'kit',
          sourceId: 'legacy_migration',
          gainedBy: 'grant',
          payload: bonuses,
        );
      }
    }
  }

  /// Migrate class feature selections from hero_values to hero_config.
  Future<void> _migrateClassFeatureSelections(String heroId) async {
    final rows = await _db.getHeroValues(heroId);
    
    // Check for legacy class feature selections in hero_values
    final selectionsRow = rows.firstWhereOrNull(
      (v) => v.key == 'strife.class_feature_selections',
    );
    if (selectionsRow != null) {
      final raw = selectionsRow.jsonValue ?? selectionsRow.textValue;
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            // Already stored in hero_config via normal flow, but ensure
            // we migrate to the new config key if needed
            await _config.setConfigValue(
              heroId: heroId,
              key: 'class_feature.selections',
              value: Map<String, dynamic>.from(decoded),
            );
          }
        } catch (_) {
          // Ignore parse errors
        }
      }
    }
  }

  /// Migrate subclass_key from hero_config to hero_entries.
  /// These keys belong in hero_entries as entry_type='subclass', not config.
  Future<void> _migrateSubclassKeyToEntries(String heroId) async {
    // Check for subclass keys in config that should be in entries
    final configKeys = [
      'class_feature.subclass_key',
      'strife.class_feature.subclass_key',
      'strife.subclass_key',
    ];
    
    for (final configKey in configKeys) {
      final config = await _config.getConfigValue(heroId, configKey);
      if (config == null) continue;
      
      final subclassKey = config['key']?.toString();
      if (subclassKey == null || subclassKey.isEmpty) continue;
      
      // Check if we already have a subclass entry
      final existingSubclass = await _db.getSingleHeroEntryId(heroId, 'subclass');
      if (existingSubclass == null) {
        // Migrate to hero_entries
        await _db.upsertHeroEntry(
          heroId: heroId,
          entryType: 'subclass',
          entryId: subclassKey,
          sourceType: 'manual_choice',
          sourceId: '',
          gainedBy: 'choice',
        );
      }
      
      // Note: We don't delete strife.subclass_key here as it's still valid for the strife creator
      // Only class_feature.* and strife.class_feature.* are banned
    }
  }

  // ===========================================================================
  // PHASE 3: CLEANUP BANNED CONFIG KEYS
  // ===========================================================================

  /// Remove legacy config keys that should not exist in hero_config.
  Future<void> _removeBannedConfigKeys(String heroId) async {
    for (final key in _bannedConfigKeys) {
      await _config.removeConfigKey(heroId, key);
    }
  }

  // ===========================================================================
  // PHASE 5: CLEANUP BANNED ENTRY TYPES
  // ===========================================================================

  /// Remove entry types that should not exist in hero_entries (computed values).
  Future<void> _removeBannedEntryTypes(String heroId) async {
    for (final entryType in _bannedEntryTypes) {
      await (_db.delete(_db.heroEntries)
            ..where((t) => 
                t.heroId.equals(heroId) & t.entryType.equals(entryType)))
          .go();
    }
  }

  List<String> _parseJsonList(db.HeroValue row) {
    final raw = row.jsonValue ?? row.textValue;
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
      }
      if (decoded is Map && decoded['list'] is List) {
        return (decoded['list'] as List)
            .map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  Map<String, dynamic> _parseJsonMap(db.HeroValue row) {
    final raw = row.jsonValue ?? row.textValue;
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return const {};
  }

  List<String> _normalizeToList(dynamic value) {
    if (value == null) return const [];
    if (value is String) return [value];
    if (value is List) {
      return value.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  Future<void> _removeBannedValues(String heroId) async {
    final rows = await _db.getHeroValues(heroId);
    // Migrate legacy equipment bonuses into hero_entries before deletion.
    final equipmentRow = rows
        .firstWhereOrNull((v) => v.key == 'strife.equipment_bonuses');
    if (equipmentRow != null) {
      final bonuses = _parseLegacyEquipmentBonuses(equipmentRow);
      if (bonuses != null) {
        await _heroRepo.saveEquipmentBonuses(
          heroId,
          staminaBonus: bonuses.staminaBonus,
          speedBonus: bonuses.speedBonus,
          stabilityBonus: bonuses.stabilityBonus,
          disengageBonus: bonuses.disengageBonus,
          meleeDamageBonus: bonuses.meleeDamageBonus,
          rangedDamageBonus: bonuses.rangedDamageBonus,
          meleeDistanceBonus: bonuses.meleeDistanceBonus,
          rangedDistanceBonus: bonuses.rangedDistanceBonus,
        );
      }
    }
    final toDelete = rows
        .where((v) =>
            _bannedValueKeysPrefixes
                .any((p) => v.key.startsWith(p)))
        .map((v) => v.id)
        .toList();
    if (toDelete.isNotEmpty) {
      await (_db.delete(_db.heroValues)
            ..where((t) => t.id.isIn(toDelete)))
          .go();
    }
  }

  // _ensureBasics is now handled by _migrateBasicsToEntries and _migrateFaithToEntries

  Future<void> _ensureAncestrySelections(String heroId) async {
    // Selected traits (legacy hero_values)
    final values = await _db.getHeroValues(heroId);
    final traitValue = values
        .firstWhereOrNull((v) => v.key == 'ancestry.selected_traits');
    final selectedTraits = <String>[];
    if (traitValue != null) {
      final raw = traitValue.jsonValue ?? traitValue.textValue;
      if (raw != null) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            selectedTraits.addAll(decoded.map((e) => e.toString()));
          } else if (decoded is Map && decoded['list'] is List) {
            selectedTraits
                .addAll((decoded['list'] as List).map((e) => e.toString()));
          }
        } catch (_) {}
      }
    }
    if (selectedTraits.isNotEmpty) {
      await _entries.addEntriesFromSource(
        heroId: heroId,
        sourceType: 'ancestry',
        sourceId: 'ancestry',
        entryType: 'ancestry_trait',
        entryIds: selectedTraits,
        gainedBy: 'choice',
      );
    }
  }

  Future<void> _ensureCultureSelections(String heroId) async {
    final config = await _config.getConfigMap(heroId);
    final envSkill = config['culture.environment.skill']?['selection'];
    final orgSkill = config['culture.organisation.skill']?['selection'];
    final upSkill = config['culture.upbringing.skill']?['selection'];

    Future<void> addSkill(String? id, String sourceId) async {
      if (id == null || id.isEmpty) return;
      await _entries.addEntry(
        heroId: heroId,
        entryType: 'skill',
        entryId: id,
        sourceType: 'culture',
        sourceId: sourceId,
        gainedBy: 'choice',
      );
    }

    await addSkill(envSkill?.toString(), 'culture_environment');
    await addSkill(orgSkill?.toString(), 'culture_organisation');
    await addSkill(upSkill?.toString(), 'culture_upbringing');
  }

  Future<void> _ensureCareerSelections(String heroId) async {
    final config = await _config.getConfigMap(heroId);
    final chosenSkills =
        (config['career.chosen_skills']?['list'] as List?) ?? const [];
    final chosenPerks =
        (config['career.chosen_perks']?['list'] as List?) ?? const [];
    if (chosenSkills.isNotEmpty) {
      await _entries.addEntriesFromSource(
        heroId: heroId,
        sourceType: 'career',
        sourceId: 'career_choice',
        entryType: 'skill',
        entryIds: chosenSkills.map((e) => e.toString()),
        gainedBy: 'choice',
      );
    }
    if (chosenPerks.isNotEmpty) {
      await _entries.addEntriesFromSource(
        heroId: heroId,
        sourceType: 'career',
        sourceId: 'career_choice',
        entryType: 'perk',
        entryIds: chosenPerks.map((e) => e.toString()),
        gainedBy: 'choice',
      );
    }
  }

  Future<void> _ensureStrifeSelections(String heroId) async {
    final config = await _config.getConfigMap(heroId);
    Future<void> addSelections(
      String key,
      String entryType,
    ) async {
      final map = config[key];
      if (map == null) return;
      final ids = map.values
          .map((v) => v?.toString())
          .whereNotNull()
          .where((e) => e.isNotEmpty)
          .toList();
      if (ids.isEmpty) return;
      await _entries.addEntriesFromSource(
        heroId: heroId,
        sourceType: 'class',
        sourceId: 'strife_creator',
        entryType: entryType,
        entryIds: ids,
        gainedBy: 'choice',
      );
    }

    await addSelections('strife.ability_selections', 'ability');
    await addSelections('strife.skill_selections', 'skill');
    await addSelections('strife.perk_selections', 'perk');
  }

  Future<void> _ensureEquipment(String heroId) async {
    final config = await _config.getConfigMap(heroId);
    final slots = config['equipment.slots']?['ids'];
    if (slots is! List) return;
    final ids = slots.map((e) => e?.toString()).whereNotNull().toList();
    if (ids.isEmpty) return;
    await _entries.addEntriesFromSource(
      heroId: heroId,
      sourceType: 'equipment',
      sourceId: 'equipment_slots',
      entryType: 'equipment',
      entryIds: ids,
      gainedBy: 'choice',
    );
  }

  Future<void> _dedupe(String heroId) async {
    final rows = await _entries.listAllEntriesForHero(heroId);
    final seen = <String>{};
    final dupIds = <int>[];
    for (final r in rows) {
      final key =
          '${r.entryType}|${r.entryId}|${r.sourceType}|${r.sourceId}|${r.gainedBy}';
      if (!seen.add(key)) dupIds.add(r.id);
    }
    if (dupIds.isNotEmpty) {
      await (_db.delete(_db.heroEntries)..where((t) => t.id.isIn(dupIds))).go();
    }
  }

  // ===========================================================================
  // PHASE 4: VALIDATION AND CLEANUP
  // ===========================================================================

  /// Remove invalid hero_entries that have missing or invalid data.
  /// An entry is invalid if:
  /// - entry_type is null or empty
  /// - entry_id is null or empty
  Future<void> _removeInvalidEntries(String heroId) async {
    final rows = await _entries.listAllEntriesForHero(heroId);
    final invalidIds = <int>[];
    
    for (final entry in rows) {
      // Check for missing entry_type
      if (entry.entryType.isEmpty) {
        invalidIds.add(entry.id);
        continue;
      }
      
      // Check for missing entry_id
      if (entry.entryId.isEmpty) {
        invalidIds.add(entry.id);
        continue;
      }
      
      // Check for obviously invalid IDs (just whitespace, special chars only)
      final trimmedId = entry.entryId.trim();
      if (trimmedId.isEmpty || trimmedId == 'null' || trimmedId == 'undefined') {
        invalidIds.add(entry.id);
        continue;
      }
    }
    
    if (invalidIds.isNotEmpty) {
      await (_db.delete(_db.heroEntries)..where((t) => t.id.isIn(invalidIds))).go();
    }
  }

  /// Deduplicate hero_config rows - ensure only one row per config_key.
  /// Keeps the most recently updated row when duplicates exist.
  Future<void> _dedupeConfig(String heroId) async {
    final rows = await (_db.select(_db.heroConfig)
          ..where((t) => t.heroId.equals(heroId))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    
    final seen = <String>{};
    final dupIds = <int>[];
    
    for (final row in rows) {
      if (!seen.add(row.configKey)) {
        // This is a duplicate - mark for deletion
        dupIds.add(row.id);
      }
    }
    
    if (dupIds.isNotEmpty) {
      await (_db.delete(_db.heroConfig)..where((t) => t.id.isIn(dupIds))).go();
    }
  }

  // ===========================================================================
  // PHASE 5: AGGREGATE RECOMPUTATION
  // ===========================================================================

  /// Recompute resistances.damage aggregate from hero_entries.
  /// 
  /// Collects all resistance entries (immunity/weakness) from hero_entries
  /// and writes the aggregate to hero_values as resistances.damage.
  /// 
  /// This is the SOURCE OF TRUTH for damage resistances:
  /// - hero_entries stores individual grants with source metadata
  /// - hero_values stores the computed aggregate for runtime use
  Future<void> _recomputeResistances(String heroId) async {
    // Collect all resistance entries from hero_entries
    final allEntries = await _entries.listAllEntriesForHero(heroId);
    
    // Aggregate resistances by damage type
    final resistanceMap = <String, _ResistanceAggregate>{};
    
    for (final entry in allEntries) {
      // Handle resistance entry type
      if (entry.entryType == 'resistance') {
        final damageType = entry.entryId.toLowerCase();
        resistanceMap.putIfAbsent(damageType, () => _ResistanceAggregate(damageType));
        
        // Parse payload for immunity/weakness values
        if (entry.payload != null) {
          try {
            final payload = jsonDecode(entry.payload!);
            if (payload is Map) {
              final immunity = (payload['immunity'] as num?)?.toInt() ?? 0;
              final weakness = (payload['weakness'] as num?)?.toInt() ?? 0;
              final source = '${entry.sourceType}:${entry.sourceId}';
              resistanceMap[damageType]!.addBonus(immunity, weakness, source);
            }
          } catch (_) {}
        }
      }
      
      // Handle legacy immunity entry type
      if (entry.entryType == 'immunity') {
        if (entry.payload != null) {
          try {
            final payload = jsonDecode(entry.payload!);
            final immunities = payload['immunities'];
            if (immunities is List) {
              for (final type in immunities) {
                final damageType = type.toString().toLowerCase();
                resistanceMap.putIfAbsent(damageType, () => _ResistanceAggregate(damageType));
                final source = '${entry.sourceType}:${entry.sourceId}';
                resistanceMap[damageType]!.addBonus(1, 0, source);
              }
            }
          } catch (_) {}
        }
      }
      
      // Handle legacy weakness entry type
      if (entry.entryType == 'weakness') {
        if (entry.payload != null) {
          try {
            final payload = jsonDecode(entry.payload!);
            final weaknesses = payload['weaknesses'];
            if (weaknesses is List) {
              for (final type in weaknesses) {
                final damageType = type.toString().toLowerCase();
                resistanceMap.putIfAbsent(damageType, () => _ResistanceAggregate(damageType));
                final source = '${entry.sourceType}:${entry.sourceId}';
                resistanceMap[damageType]!.addBonus(0, 1, source);
              }
            }
          } catch (_) {}
        }
      }
    }
    
    // Load current resistances to preserve base values (user-editable)
    final currentResistances = await _loadCurrentResistances(heroId);
    
    // Build the final resistance list
    final finalResistances = <DamageResistance>[];
    
    // Process all damage types (from both current and computed)
    final allDamageTypes = <String>{
      ...resistanceMap.keys,
      ...currentResistances.resistances.map((r) => r.damageType.toLowerCase()),
    };
    
    for (final damageType in allDamageTypes) {
      final current = currentResistances.forType(damageType);
      final computed = resistanceMap[damageType];
      
      finalResistances.add(DamageResistance(
        damageType: damageType,
        baseImmunity: current?.baseImmunity ?? 0,
        baseWeakness: current?.baseWeakness ?? 0,
        bonusImmunity: computed?.totalImmunity ?? 0,
        bonusWeakness: computed?.totalWeakness ?? 0,
        sources: computed?.sources ?? const [],
      ));
    }
    
    // Write aggregate to hero_values
    final resistancesModel = HeroDamageResistances(resistances: finalResistances);
    await _db.upsertHeroValue(
      heroId: heroId,
      key: 'resistances.damage',
      textValue: resistancesModel.toJsonString(),
    );
  }

  /// Load current resistances from hero_values.
  Future<HeroDamageResistances> _loadCurrentResistances(String heroId) async {
    final values = await _db.getHeroValues(heroId);
    final value = values.firstWhereOrNull((v) => v.key == 'resistances.damage');
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

  EquipmentBonuses? _parseLegacyEquipmentBonuses(db.HeroValue row) {
    final raw = row.jsonValue ?? row.textValue;
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return EquipmentBonuses(
        staminaBonus: (decoded['stamina'] as num?)?.toInt() ?? 0,
        speedBonus: (decoded['speed'] as num?)?.toInt() ?? 0,
        stabilityBonus: (decoded['stability'] as num?)?.toInt() ?? 0,
        disengageBonus: (decoded['disengage'] as num?)?.toInt() ?? 0,
        meleeDamageBonus: (decoded['melee_damage'] as num?)?.toInt() ?? 0,
        rangedDamageBonus: (decoded['ranged_damage'] as num?)?.toInt() ?? 0,
        meleeDistanceBonus:
            (decoded['melee_distance'] as num?)?.toInt() ?? 0,
        rangedDistanceBonus:
            (decoded['ranged_distance'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Helper class to aggregate resistance values from multiple sources.
class _ResistanceAggregate {
  _ResistanceAggregate(this.damageType);
  
  final String damageType;
  int totalImmunity = 0;
  int totalWeakness = 0;
  final List<String> sources = [];
  
  void addBonus(int immunity, int weakness, String source) {
    totalImmunity += immunity;
    totalWeakness += weakness;
    if (source.isNotEmpty && !sources.contains(source)) {
      sources.add(source);
    }
  }
}
