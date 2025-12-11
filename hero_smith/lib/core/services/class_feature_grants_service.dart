import 'package:collection/collection.dart';

import '../db/app_database.dart' as db;
import '../models/class_data.dart';
import '../models/feature.dart' as feature_model;
import '../models/subclass_models.dart';
import '../repositories/feature_repository.dart';
import '../repositories/hero_entry_repository.dart';
import 'class_feature_data_service.dart';
import 'hero_config_service.dart';

/// Service for applying class feature selections to a hero.
/// 
/// This service handles storing feature grants based on user selections
/// in the class feature UI. All grants are written to hero_entries with
/// source_type='class_feature' and source_id=<featureId>.
class ClassFeatureGrantsService {
  ClassFeatureGrantsService(this._db)
      : _entries = HeroEntryRepository(_db),
        _config = HeroConfigService(_db);

  final db.AppDatabase _db;
  final HeroEntryRepository _entries;
  final HeroConfigService _config;

  /// Config key for storing feature selections.
  static const _kFeatureSelections = 'class_feature.selections';
  
  /// Config key for storing subclass key.
  static const _kSubclassKey = 'class_feature.subclass_key';

  /// Apply class feature selections to a hero.
  /// 
  /// This stores the selected features and their grants into hero_entries.
  /// Selections are stored in hero_config.
  Future<void> applyClassFeatureSelections({
    required String heroId,
    required ClassData classData,
    required int level,
    required Map<String, Set<String>> selections,
    SubclassSelectionResult? subclassSelection,
  }) async {
    final classSlug = _classSlugFromId(classData.classId);
    if (classSlug == null) return;

    // Store selections in hero_config
    await _saveFeatureSelections(heroId, selections);
    
    // Store subclass key if present
    if (subclassSelection?.subclassKey != null) {
      await _config.setConfigValue(
        heroId: heroId,
        key: _kSubclassKey,
        value: {'key': subclassSelection!.subclassKey},
      );
    }

    // Load feature details to process grants
    final featureDetails = await _loadFeatureDetails(classSlug);
    final activeSubclassSlugs =
        ClassFeatureDataService.activeSubclassSlugs(subclassSelection);

    // Load all features for this class up to the hero's level
    final allFeatures = await FeatureRepository.loadClassFeatures(classSlug);
    final applicableFeatures = allFeatures
        .where((f) => f.level <= level)
        .where((f) {
          if (!f.isSubclassFeature) return true;
          if (activeSubclassSlugs.isEmpty) return true;
          return ClassFeatureDataService.matchesSelectedSubclass(
            f.subclassName,
            activeSubclassSlugs,
          );
        })
        .toList();

    // Remove existing class feature grants for this hero
    await _clearAllClassFeatureGrants(heroId);

    // Process each applicable feature
    for (final feature in applicableFeatures) {
      await _processFeatureGrants(
        heroId: heroId,
        feature: feature,
        featureDetails: featureDetails,
        selections: selections,
        activeSubclassSlugs: activeSubclassSlugs,
      );
    }
  }

  /// Remove all class feature grants for a hero.
  Future<void> removeClassFeatureGrants(String heroId) async {
    await _clearAllClassFeatureGrants(heroId);
    await _config.removeConfigKey(heroId, _kFeatureSelections);
    await _config.removeConfigKey(heroId, _kSubclassKey);
  }

  /// Remove grants for a specific feature.
  Future<void> removeFeatureGrants(String heroId, String featureId) async {
    await _entries.removeEntriesFromSource(
      heroId: heroId,
      sourceType: 'class_feature',
      sourceId: featureId,
    );
  }

  /// Load current feature selections from hero_config.
  Future<Map<String, Set<String>>> loadFeatureSelections(String heroId) async {
    final config = await _config.getConfigValue(heroId, _kFeatureSelections);
    if (config == null) return const {};
    
    final result = <String, Set<String>>{};
    config.forEach((key, value) {
      final normalizedKey = key.toString().trim();
      if (normalizedKey.isEmpty) return;
      if (value is List) {
        final set = value
            .whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet();
        if (set.isNotEmpty) result[normalizedKey] = set;
      } else if (value is String && value.trim().isNotEmpty) {
        result[normalizedKey] = {value.trim()};
      }
    });
    return result;
  }

  /// Load stored subclass key.
  Future<String?> loadSubclassKey(String heroId) async {
    final config = await _config.getConfigValue(heroId, _kSubclassKey);
    return config?['key']?.toString();
  }

  /// Get all abilities granted by class features.
  Future<List<String>> getGrantedAbilities(String heroId) async {
    final entries = await _entries.listEntriesByType(heroId, 'ability');
    return entries
        .where((e) => e.sourceType == 'class_feature')
        .map((e) => e.entryId)
        .toList();
  }

  /// Get all skills granted by class features.
  Future<List<String>> getGrantedSkills(String heroId) async {
    final entries = await _entries.listEntriesByType(heroId, 'skill');
    return entries
        .where((e) => e.sourceType == 'class_feature')
        .map((e) => e.entryId)
        .toList();
  }

  /// Get all features (class_feature entries) for a hero.
  Future<List<db.HeroEntry>> getClassFeatureEntries(String heroId) async {
    final entries = await _entries.listEntriesByType(heroId, 'class_feature');
    return entries.where((e) => e.sourceType == 'class_feature').toList();
  }

  // Private implementation

  Future<void> _saveFeatureSelections(
    String heroId,
    Map<String, Set<String>> selections,
  ) async {
    final jsonMap = <String, dynamic>{
      for (final entry in selections.entries)
        entry.key: entry.value.toList(),
    };
    await _config.setConfigValue(
      heroId: heroId,
      key: _kFeatureSelections,
      value: jsonMap,
    );
  }

  Future<void> _clearAllClassFeatureGrants(String heroId) async {
    await _entries.removeEntriesFromSource(
      heroId: heroId,
      sourceType: 'class_feature',
    );
  }

  Future<Map<String, Map<String, dynamic>>> _loadFeatureDetails(
      String classSlug) async {
    final featureMaps = await FeatureRepository.loadClassFeatureMaps(classSlug);
    final details = <String, Map<String, dynamic>>{};
    for (final entry in featureMaps) {
      final id = entry['id']?.toString();
      if (id == null || id.isEmpty) continue;
      details[id] = Map<String, dynamic>.from(entry);
    }
    return details;
  }

  Future<void> _processFeatureGrants({
    required String heroId,
    required feature_model.Feature feature,
    required Map<String, Map<String, dynamic>> featureDetails,
    required Map<String, Set<String>> selections,
    required Set<String> activeSubclassSlugs,
  }) async {
    final details = featureDetails[feature.id];
    
    // Always add the feature itself as a class_feature entry
    await _entries.addEntry(
      heroId: heroId,
      entryType: 'class_feature',
      entryId: feature.id,
      sourceType: 'class_feature',
      sourceId: feature.id,
      gainedBy: 'grant',
      payload: {
        'name': feature.name,
        'level': feature.level,
        'type': feature.type,
        'is_subclass_feature': feature.isSubclassFeature,
        if (feature.subclassName != null) 'subclass_name': feature.subclassName,
      },
    );

    if (details == null) return;

    // Process grants (auto-granted items)
    final isGrants = ClassFeatureDataService.hasGrants(details);
    final options = ClassFeatureDataService.extractOptionMaps(details);

    if (isGrants && options.isNotEmpty) {
      // Auto-grant all items that match the active subclass
      for (final option in options) {
        if (_optionMatchesSubclass(option, activeSubclassSlugs)) {
          await _applyOptionGrants(heroId, feature.id, option);
        }
      }
    } else if (options.isNotEmpty) {
      // Apply user-selected options
      final selectedKeys = selections[feature.id] ?? const <String>{};
      for (final optionKey in selectedKeys) {
        final option = options.firstWhereOrNull(
          (o) => ClassFeatureDataService.featureOptionKey(o) == optionKey,
        );
        if (option != null) {
          await _applyOptionGrants(heroId, feature.id, option);
        }
      }
    }

    // Process top-level ability grant (e.g., "ability": "Judgment")
    await _processTopLevelAbility(heroId, feature.id, details);

    // Process stat_mods if present
    await _processStatMods(heroId, feature.id, details);

    // Process resistance grants if present
    await _processResistanceGrants(heroId, feature.id, details);

    // Process title grants if present
    await _processTitleGrants(heroId, feature.id, details);
  }

  bool _optionMatchesSubclass(
    Map<String, dynamic> option,
    Set<String> activeSubclassSlugs,
  ) {
    if (activeSubclassSlugs.isEmpty) return true;

    // Check various subclass indicator keys
    for (final key in _subclassOptionKeys) {
      final value = option[key];
      if (value == null) continue;
      
      Set<String> optionSlugs;
      if (value is String) {
        optionSlugs = ClassFeatureDataService.slugVariants(value);
      } else if (value is List) {
        optionSlugs = value
            .whereType<String>()
            .expand((v) => ClassFeatureDataService.slugVariants(v))
            .toSet();
      } else {
        continue;
      }

      if (optionSlugs.isEmpty) continue;
      return optionSlugs.intersection(activeSubclassSlugs).isNotEmpty;
    }

    // No subclass restriction, so it matches
    return true;
  }

  Future<void> _applyOptionGrants(
    String heroId,
    String featureId,
    Map<String, dynamic> option,
  ) async {
    // Grant skill if specified
    final skill = option['skill']?.toString();
    if (skill != null && skill.isNotEmpty) {
      final skillId = await _resolveSkillId(skill);
      if (skillId != null) {
        await _entries.addEntry(
          heroId: heroId,
          entryType: 'skill',
          entryId: skillId,
          sourceType: 'class_feature',
          sourceId: featureId,
          gainedBy: 'grant',
        );
      }
    }

    // Grant ability if specified
    final ability = option['ability']?.toString();
    if (ability != null && ability.isNotEmpty) {
      final abilityId = await _resolveAbilityId(ability);
      await _entries.addEntry(
        heroId: heroId,
        entryType: 'ability',
        entryId: abilityId,
        sourceType: 'class_feature',
        sourceId: featureId,
        gainedBy: 'grant',
      );
    }

    // Grant abilities (plural) if specified
    final abilities = option['abilities'];
    if (abilities is List) {
      for (final ab in abilities) {
        final abilityName = ab?.toString();
        if (abilityName != null && abilityName.isNotEmpty) {
          final abilityId = await _resolveAbilityId(abilityName);
          await _entries.addEntry(
            heroId: heroId,
            entryType: 'ability',
            entryId: abilityId,
            sourceType: 'class_feature',
            sourceId: featureId,
            gainedBy: 'grant',
          );
        }
      }
    }

    // Grant feature benefits with stat_mods
    final statMods = option['stat_mods'] ?? option['statMods'];
    if (statMods is Map) {
      await _entries.addEntry(
        heroId: heroId,
        entryType: 'stat_mod',
        entryId: '${featureId}_option_stat_mod',
        sourceType: 'class_feature',
        sourceId: featureId,
        gainedBy: 'grant',
        payload: {'mods': statMods},
      );
    }

    // Grant resistances from option
    final immunities = option['immunities'] ?? option['immunity'];
    if (immunities != null) {
      await _entries.addEntry(
        heroId: heroId,
        entryType: 'immunity',
        entryId: '${featureId}_option_immunity',
        sourceType: 'class_feature',
        sourceId: featureId,
        gainedBy: 'grant',
        payload: {'immunities': _normalizeToList(immunities)},
      );
    }

    // Grant titles from option
    final title = option['title']?.toString();
    if (title != null && title.isNotEmpty) {
      final titleId = await _resolveTitleId(title);
      await _entries.addEntry(
        heroId: heroId,
        entryType: 'title',
        entryId: titleId,
        sourceType: 'class_feature',
        sourceId: featureId,
        gainedBy: 'grant',
      );
    }
  }

  Future<void> _processStatMods(
    String heroId,
    String featureId,
    Map<String, dynamic> details,
  ) async {
    final statMods = details['stat_mods'] ?? details['statMods'];
    if (statMods is! Map) return;

    await _entries.addEntry(
      heroId: heroId,
      entryType: 'stat_mod',
      entryId: '${featureId}_stat_mod',
      sourceType: 'class_feature',
      sourceId: featureId,
      gainedBy: 'grant',
      payload: {'mods': statMods},
    );
  }

  Future<void> _processResistanceGrants(
    String heroId,
    String featureId,
    Map<String, dynamic> details,
  ) async {
    final immunities = details['immunities'] ?? details['immunity'];
    if (immunities != null) {
      await _entries.addEntry(
        heroId: heroId,
        entryType: 'immunity',
        entryId: '${featureId}_immunity',
        sourceType: 'class_feature',
        sourceId: featureId,
        gainedBy: 'grant',
        payload: {'immunities': _normalizeToList(immunities)},
      );
    }

    final weaknesses = details['weaknesses'] ?? details['weakness'];
    if (weaknesses != null) {
      await _entries.addEntry(
        heroId: heroId,
        entryType: 'weakness',
        entryId: '${featureId}_weakness',
        sourceType: 'class_feature',
        sourceId: featureId,
        gainedBy: 'grant',
        payload: {'weaknesses': _normalizeToList(weaknesses)},
      );
    }
  }

  Future<void> _processTitleGrants(
    String heroId,
    String featureId,
    Map<String, dynamic> details,
  ) async {
    final titles = details['titles'] ?? details['granted_titles'];
    if (titles == null) return;

    final titleList = _normalizeToList(titles);
    for (final title in titleList) {
      if (title.isEmpty) continue;
      final titleId = await _resolveTitleId(title);
      await _entries.addEntry(
        heroId: heroId,
        entryType: 'title',
        entryId: titleId,
        sourceType: 'class_feature',
        sourceId: featureId,
        gainedBy: 'grant',
      );
    }
  }

  /// Process top-level ability granted by a feature (e.g., "ability": "Judgment")
  Future<void> _processTopLevelAbility(
    String heroId,
    String featureId,
    Map<String, dynamic> details,
  ) async {
    final ability = details['ability']?.toString();
    if (ability == null || ability.isEmpty) return;

    final abilityId = await _resolveAbilityId(ability);
    await _entries.addEntry(
      heroId: heroId,
      entryType: 'ability',
      entryId: abilityId,
      sourceType: 'class_feature',
      sourceId: featureId,
      gainedBy: 'grant',
    );
  }

  List<String> _normalizeToList(dynamic value) {
    if (value == null) return const [];
    if (value is String) return [value];
    if (value is List) {
      return value.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  Future<String?> _resolveSkillId(String skillName) async {
    final components = await _db.getAllComponents();
    final match = components.firstWhereOrNull(
      (c) => c.type == 'skill' && c.name.toLowerCase() == skillName.toLowerCase(),
    );
    return match?.id ?? 'skill_${ClassFeatureDataService.slugify(skillName)}';
  }

  Future<String> _resolveAbilityId(String abilityName) async {
    final components = await _db.getAllComponents();
    final match = components.firstWhereOrNull(
      (c) => c.type == 'ability' && c.name.toLowerCase() == abilityName.toLowerCase(),
    );
    return match?.id ?? ClassFeatureDataService.slugify(abilityName);
  }

  Future<String> _resolveTitleId(String titleName) async {
    final components = await _db.getAllComponents();
    final match = components.firstWhereOrNull(
      (c) => c.type == 'title' && c.name.toLowerCase() == titleName.toLowerCase(),
    );
    return match?.id ?? 'title_${ClassFeatureDataService.slugify(titleName)}';
  }

  String? _classSlugFromId(String? classId) {
    if (classId == null || classId.trim().isEmpty) return null;
    var slug = classId.trim().toLowerCase();
    if (slug.startsWith('class_')) {
      slug = slug.substring('class_'.length);
    }
    return slug.isEmpty ? null : slug;
  }

  static const List<String> _subclassOptionKeys = [
    'subclass',
    'subclass_name',
    'tradition',
    'order',
    'doctrine',
    'mask',
    'path',
    'circle',
    'college',
    'element',
    'role',
    'discipline',
    'oath',
    'school',
    'guild',
    'domain',
    'aspect',
  ];
}
