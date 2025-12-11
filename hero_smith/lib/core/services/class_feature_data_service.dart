import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/class_data.dart';
import '../models/feature.dart' as feature_model;
import '../models/subclass_models.dart';
import '../repositories/feature_repository.dart';
import 'ability_data_service.dart';

class ClassFeatureDataResult {
  const ClassFeatureDataResult({
    required this.classMetadata,
    required this.features,
    required this.featureDetailsById,
    required this.domainLinkedFeatureIds,
    required this.deityLinkedFeatureIds,
    required this.abilityDetailsById,
    required this.abilityIdByName,
  });

  final Map<String, dynamic>? classMetadata;
  final List<feature_model.Feature> features;
  final Map<String, Map<String, dynamic>> featureDetailsById;
  final Set<String> domainLinkedFeatureIds;
  final Set<String> deityLinkedFeatureIds;
  final Map<String, Map<String, dynamic>> abilityDetailsById;
  final Map<String, String> abilityIdByName;
}

class ClassFeatureDataService {
  ClassFeatureDataService._();

  static final ClassFeatureDataService _instance = ClassFeatureDataService._();

  factory ClassFeatureDataService() => _instance;

  final Map<String, dynamic> _additionalFeatureCache = {};

  Future<ClassFeatureDataResult> loadFeatures({
    required ClassData classData,
    required int level,
    required Set<String> activeSubclassSlugs,
  }) async {
    final slug = _classSlugFromId(classData.classId);
    if (slug == null) {
      throw Exception(
          'Unable to resolve slug for class "${classData.classId}".');
    }

    Map<String, dynamic>? metadata;
    try {
      final rawMetadata = await rootBundle
          .loadString('data/classes_levels_and_stats/$slug.json');
      metadata = jsonDecode(rawMetadata) as Map<String, dynamic>;
    } catch (_) {
      metadata = null;
    }

    final allFeatures = await FeatureRepository.loadClassFeatures(slug);
    final filteredFeatures =
        allFeatures.where((feature) => feature.level <= level).where((feature) {
      if (!feature.isSubclassFeature) return true;
      if (activeSubclassSlugs.isEmpty) return true;
      return matchesSelectedSubclass(feature.subclassName, activeSubclassSlugs);
    }).toList()
          ..sort((a, b) {
            final levelCompare = a.level.compareTo(b.level);
            if (levelCompare != 0) return levelCompare;
            return a.name.compareTo(b.name);
          });

    final featureMaps = await FeatureRepository.loadClassFeatureMaps(slug);
    final featureDetails = <String, Map<String, dynamic>>{};
    for (final entry in featureMaps) {
      final id = entry['id']?.toString();
      if (id == null || id.isEmpty) continue;
      featureDetails[id] = await _hydrateFeatureDetail(entry);
    }

    final domainLinked = identifyDomainLinkedFeatures(featureDetails);
    final deityLinked = identifyDeityLinkedFeatures(featureDetails);

    final abilityMaps = await _loadClassAbilityMaps(slug);
    final abilityDetails = <String, Map<String, dynamic>>{};
    final abilityNameIndex = <String, String>{};
    for (final ability in abilityMaps) {
      final rawId = ability['id']?.toString() ?? '';
      final rawName = ability['name']?.toString() ?? '';
      if (rawId.trim().isEmpty && rawName.trim().isEmpty) {
        continue;
      }
      final resolvedId =
          rawId.trim().isNotEmpty ? rawId.trim() : slugify(rawName.trim());
      final copy = Map<String, dynamic>.from(ability)
        ..['resolved_id'] = resolvedId;
      abilityDetails[resolvedId] = copy;
      if (rawName.trim().isNotEmpty) {
        abilityNameIndex[slugify(rawName)] = resolvedId;
      }
      final originalId = ability['original_id'];
      if (originalId is String && originalId.trim().isNotEmpty) {
        abilityNameIndex[slugify(originalId)] = resolvedId;
      }
      abilityNameIndex[slugify(resolvedId)] = resolvedId;
    }

    return ClassFeatureDataResult(
      classMetadata: metadata,
      features: filteredFeatures,
      featureDetailsById: featureDetails,
      domainLinkedFeatureIds: domainLinked,
      deityLinkedFeatureIds: deityLinked,
      abilityDetailsById: abilityDetails,
      abilityIdByName: abilityNameIndex,
    );
  }

  static Set<String> selectedDomainSlugs(SubclassSelectionResult? selection) {
    if (selection == null || selection.domainNames.isEmpty) {
      return const <String>{};
    }
    return selection.domainNames
        .map(slugify)
        .where((slug) => slug.isNotEmpty)
        .toSet();
  }

  static Set<String> selectedDeitySlugs(SubclassSelectionResult? selection) {
    if (selection == null) return const <String>{};
    final slugs = <String>{};

    void addValue(String? value) {
      if (value == null || value.trim().isEmpty) return;
      slugs.addAll(slugVariants(value));
    }

    addValue(selection.deityName);
    addValue(selection.deityId);
    return slugs;
  }

  static Set<String> activeSubclassSlugs(SubclassSelectionResult? selection) {
    if (selection == null) return const <String>{};
    final result = <String>{};

    void addValue(String? value) {
      if (value == null || value.trim().isEmpty) return;
      result.addAll(slugVariants(value));
    }

    addValue(selection.subclassKey);
    addValue(selection.subclassName);
    for (final domain in selection.domainNames) {
      addValue(domain);
    }
    return result;
  }

  static String? subclassLabel(SubclassSelectionResult? selection) {
    return selection?.subclassName;
  }

  static Set<String> slugVariants(String value) {
    final base = slugify(value);
    if (base.isEmpty) return const <String>{};
    final tokens = base
        .split('_')
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) return {base};

    final variants = <String>{base};

    final trimmedAll =
        tokens.where((token) => !_subclassStopWords.contains(token)).join('_');
    if (trimmedAll.isNotEmpty) variants.add(trimmedAll);

    for (var i = 1; i < tokens.length; i++) {
      final suffix = tokens.sublist(i).join('_');
      if (suffix.isNotEmpty) variants.add(suffix);

      final trimmedSuffix = tokens
          .sublist(i)
          .where((token) => !_subclassStopWords.contains(token))
          .join('_');
      if (trimmedSuffix.isNotEmpty) variants.add(trimmedSuffix);
    }

    return variants;
  }

  static String slugify(String value) {
    final normalized =
        value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final collapsed = normalized.replaceAll(RegExp(r'_+'), '_');
    return collapsed.replaceAll(RegExp(r'^_|_$'), '');
  }

  static bool matchesSelectedSubclass(
    String? value,
    Set<String> activeSubclassSlugs,
  ) {
    if (value == null || value.trim().isEmpty) {
      return true;
    }
    if (activeSubclassSlugs.isEmpty) {
      return false;
    }
    final required = slugVariants(value);
    if (required.isEmpty) {
      return true;
    }
    return required.intersection(activeSubclassSlugs).isNotEmpty;
  }

  /// Extracts the list of options or grants from feature details.
  /// Returns the list from 'grants' if present, otherwise from 'options' or 'options_X'.
  /// The 'options_X' pattern (e.g., options_2, options_3) indicates X choices allowed.
  static List<dynamic>? extractOptionsOrGrants(Map<String, dynamic>? details) {
    if (details == null) return null;
    final grants = details['grants'];
    if (grants is List && grants.isNotEmpty) return grants;
    final options = details['options'];
    if (options is List && options.isNotEmpty) return options;
    // Check for options_X pattern (options_2, options_3, etc.)
    final optionsXKey = _findOptionsXKey(details);
    if (optionsXKey != null) {
      final optionsX = details[optionsXKey];
      if (optionsX is List && optionsX.isNotEmpty) return optionsX;
    }
    return null;
  }

  /// Finds the first 'options_X' key in the details map where X is a number.
  /// Returns the key name (e.g., 'options_2') or null if not found.
  static String? _findOptionsXKey(Map<String, dynamic>? details) {
    if (details == null) return null;
    final pattern = RegExp(r'^options_(\d+)$');
    for (final key in details.keys) {
      if (pattern.hasMatch(key)) {
        final value = details[key];
        if (value is List && value.isNotEmpty) return key;
      }
    }
    return null;
  }

  /// Extracts the selection count from an 'options_X' key.
  /// Returns X from 'options_X' or null if the key doesn't match the pattern.
  static int? _extractOptionsXCount(String? key) {
    if (key == null) return null;
    final match = RegExp(r'^options_(\d+)$').firstMatch(key);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  /// Returns true if the feature uses 'grants' (auto-apply all matching)
  /// instead of 'options' (user picks one).
  static bool hasGrants(Map<String, dynamic>? details) {
    if (details == null) return false;
    final grants = details['grants'];
    return grants is List && grants.isNotEmpty;
  }

  /// Normalizes the raw options/grants list into a typed list of maps.
  static List<Map<String, dynamic>> extractOptionMaps(
    Map<String, dynamic>? details,
  ) {
    final raw = extractOptionsOrGrants(details);
    if (raw == null) return const [];

    final result = <Map<String, dynamic>>[];
    for (final entry in raw) {
      if (entry is Map<String, dynamic>) {
        result.add(entry);
      } else if (entry is Map) {
        result.add(entry.cast<String, dynamic>());
      }
    }
    return result;
  }

  /// Maximum number of selections allowed for a feature.
  /// Defaults to 1, uses X for `options_X` pattern, or respects explicit limits.
  static int selectionLimit(Map<String, dynamic>? details) {
    if (details == null) return 1;

    // Check for options_X pattern (options_2, options_3, etc.)
    final optionsXKey = _findOptionsXKey(details);
    final optionsXCount = _extractOptionsXCount(optionsXKey);
    if (optionsXCount != null && optionsXCount > 0) return optionsXCount;

    final maxSel = details['max_selections'] ?? details['select_count'];
    if (maxSel is num) {
      final value = maxSel.toInt();
      return value < 1 ? 1 : value;
    }

    final allowMultiple = details['allow_multiple'];
    if (allowMultiple is bool && allowMultiple) {
      final options = extractOptionMaps(details);
      if (options.isNotEmpty) return options.length;
      return 99; // generous upper bound when explicitly allowed
    }

    return 1;
  }

  /// Minimum number of selections expected for a feature.
  /// Defaults to 1 when options exist; `options_X` requires X selections.
  static int minimumSelections(Map<String, dynamic>? details) {
    if (details == null) return 0;

    final options = extractOptionMaps(details);
    if (options.isEmpty) return 0;

    // Check for options_X pattern (options_2, options_3, etc.)
    final optionsXKey = _findOptionsXKey(details);
    final optionsXCount = _extractOptionsXCount(optionsXKey);
    if (optionsXCount != null && optionsXCount > 0) {
      return options.length >= optionsXCount ? optionsXCount : options.length;
    }

    final minSel = details['min_selections'];
    if (minSel is num && minSel >= 0) {
      final limit = selectionLimit(details);
      final value = minSel.toInt();
      return value > limit ? limit : value;
    }

    return 1;
  }

  /// Applies the selection limit to the provided keys, preserving option order.
  static Set<String> clampSelectionKeys(
    Set<String> selectedKeys,
    Map<String, dynamic>? details,
  ) {
    final limit = selectionLimit(details);
    if (selectedKeys.length <= limit) return selectedKeys;

    final orderedKeys = <String>[];
    final options = extractOptionMaps(details);
    for (final option in options) {
      final key = featureOptionKey(option);
      if (selectedKeys.contains(key)) {
        orderedKeys.add(key);
      }
    }

    if (orderedKeys.length < selectedKeys.length) {
      final remaining = selectedKeys.difference(orderedKeys.toSet()).toList()
        ..sort();
      orderedKeys.addAll(remaining);
    }

    return orderedKeys.take(limit).toSet();
  }

  static Set<String> extractOptionKeys(Map<String, dynamic>? details) {
    if (details == null) return const <String>{};
    final items = extractOptionsOrGrants(details);
    if (items == null) return const <String>{};
    final keys = <String>{};
    for (final option in items) {
      if (option is! Map<String, dynamic>) continue;
      keys.add(featureOptionKey(option));
    }
    return keys;
  }

  static String featureOptionKey(Map<String, dynamic> option) =>
      slugify(featureOptionLabel(option));

  static String featureOptionLabel(Map<String, dynamic> option) {
    for (final key in ['name', 'title', 'domain']) {
      final value = option[key]?.toString();
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    final skill = option['skill']?.toString();
    if (skill != null && skill.trim().isNotEmpty) {
      return skill.trim();
    }
    final benefit = option['benefit']?.toString();
    if (benefit != null && benefit.trim().isNotEmpty) {
      return benefit.trim();
    }
    return 'Option';
  }

  static Set<String> identifyDomainLinkedFeatures(
    Map<String, Map<String, dynamic>> featureDetailsById,
  ) {
    final ids = <String>{};
    featureDetailsById.forEach((featureId, details) {
      final items = extractOptionsOrGrants(details);
      if (items == null) return;
      final hasDomain = items.any((option) {
        if (option is! Map<String, dynamic>) return false;
        final domain = option['domain']?.toString().trim();
        return domain != null && domain.isNotEmpty;
      });
      if (hasDomain) {
        ids.add(featureId);
      }
    });
    return ids;
  }

  static Set<String> identifyDeityLinkedFeatures(
    Map<String, Map<String, dynamic>> featureDetailsById,
  ) {
    final ids = <String>{};
    featureDetailsById.forEach((featureId, details) {
      final items = extractOptionsOrGrants(details);
      if (items == null) return;
      final hasDeity = items.any((option) {
        if (option is! Map) return false;
        final map = option is Map<String, dynamic>
            ? option
            : option.cast<String, dynamic>();
        return _extractDeitySlugs(map).isNotEmpty;
      });
      if (hasDeity) {
        ids.add(featureId);
      }
    });
    return ids;
  }

  static Set<String> domainOptionKeysFor(
    Map<String, Map<String, dynamic>> featureDetailsById,
    String featureId,
    Set<String> domainSlugs,
  ) {
    if (domainSlugs.isEmpty) return const <String>{};
    final details = featureDetailsById[featureId];
    if (details == null) return const <String>{};
    final items = extractOptionsOrGrants(details);
    if (items == null) return const <String>{};
    final keys = <String>{};
    for (final option in items) {
      if (option is! Map<String, dynamic>) continue;
      final domainName = option['domain']?.toString().trim();
      if (domainName == null || domainName.isEmpty) continue;
      final slug = slugify(domainName);
      if (domainSlugs.contains(slug)) {
        keys.add(featureOptionKey(option));
      }
    }
    return keys;
  }

  static Set<String> subclassOptionKeysFor(
    Map<String, Map<String, dynamic>> featureDetailsById,
    String featureId,
    Set<String> subclassSlugs,
  ) {
    final details = featureDetailsById[featureId];
    if (details == null) return const <String>{};
    final items = extractOptionsOrGrants(details);
    if (items == null) return const <String>{};

    final keys = <String>{};
    var hasTaggedOption = false;
    for (final option in items) {
      if (option is! Map) continue;
      final map = option is Map<String, dynamic>
          ? option
          : option.cast<String, dynamic>();
      final slugs = _extractSubclassSlugs(map);
      if (slugs.isEmpty) continue;
      hasTaggedOption = true;
      if (subclassSlugs.isEmpty) continue;
      if (slugs.intersection(subclassSlugs).isNotEmpty) {
        keys.add(featureOptionKey(map));
      }
    }

    if (!hasTaggedOption) {
      return const <String>{};
    }
    return keys;
  }

  static Set<String> deityOptionKeysFor(
    Map<String, Map<String, dynamic>> featureDetailsById,
    String featureId,
    Set<String> deitySlugs,
  ) {
    final details = featureDetailsById[featureId];
    if (details == null) return const <String>{};
    final items = extractOptionsOrGrants(details);
    if (items == null) return const <String>{};

    final keys = <String>{};
    var hasTaggedOption = false;
    for (final option in items) {
      if (option is! Map) continue;
      final map = option is Map<String, dynamic>
          ? option
          : option.cast<String, dynamic>();
      final slugs = _extractDeitySlugs(map);
      if (slugs.isEmpty) continue;
      hasTaggedOption = true;
      if (deitySlugs.isEmpty) continue;
      if (slugs.intersection(deitySlugs).isNotEmpty) {
        keys.add(featureOptionKey(map));
      }
    }

    if (!hasTaggedOption) {
      return const <String>{};
    }
    return keys;
  }

  static void applyDomainSelectionToFeatures({
    required Map<String, Set<String>> selections,
    required Map<String, Map<String, dynamic>> featureDetailsById,
    required Set<String> domainLinkedFeatureIds,
    required Set<String> domainSlugs,
  }) {
    for (final featureId in domainLinkedFeatureIds) {
      if (domainSlugs.isEmpty) {
        selections.remove(featureId);
        continue;
      }
      
      final details = featureDetailsById[featureId];
      final isGrants = hasGrants(details);
      
      final matchingKeys = domainOptionKeysFor(
        featureDetailsById,
        featureId,
        domainSlugs,
      );
      if (matchingKeys.isNotEmpty) {
        // For grants: auto-select ALL matching keys
        // For options with single domain: auto-select all matching
        // For options with multiple domains: preserve existing or require choice
        if (isGrants || domainSlugs.length == 1) {
          selections[featureId] = ClassFeatureDataService.clampSelectionKeys(
            matchingKeys,
            details,
          );
        } else {
          final existing = selections[featureId] ?? const <String>{};
          final validExisting = existing.intersection(matchingKeys);
          final chosen =
              validExisting.isNotEmpty ? validExisting : <String>{};
          selections[featureId] = ClassFeatureDataService.clampSelectionKeys(
            chosen,
            details,
          );
        }
      } else {
        selections.remove(featureId);
      }
    }
  }

  static void applySubclassSelectionToFeatures({
    required Map<String, Set<String>> selections,
    required List<feature_model.Feature> features,
    required Map<String, Map<String, dynamic>> featureDetailsById,
    required Set<String> subclassSlugs,
  }) {
    for (final feature in features) {
      if (!feature.isSubclassFeature) continue;
      final details = featureDetailsById[feature.id];
      final selectionLimit = ClassFeatureDataService.selectionLimit(details);
      if (details == null) {
        if (subclassSlugs.isEmpty) {
          selections.remove(feature.id);
        }
        continue;
      }

      final items = extractOptionsOrGrants(details);
      if (items == null) {
        if (subclassSlugs.isEmpty) {
          selections.remove(feature.id);
        }
        continue;
      }

      // Check if this feature uses grants (auto-apply all matching)
      final isGrants = hasGrants(details);

      final matchingKeys = <String>{};
      var hasTaggedOption = false;

      for (final option in items) {
        if (option is! Map) continue;
        final map = option is Map<String, dynamic>
            ? option
            : option.cast<String, dynamic>();
        final slugs = _extractSubclassSlugs(map);
        if (slugs.isEmpty) continue;
        hasTaggedOption = true;
        if (subclassSlugs.isEmpty) continue;
        if (slugs.intersection(subclassSlugs).isNotEmpty) {
          matchingKeys.add(featureOptionKey(map));
        }
      }

      if (!hasTaggedOption) {
        if (subclassSlugs.isEmpty) {
          selections.remove(feature.id);
        }
        continue;
      }

      if (subclassSlugs.isEmpty) {
        selections.remove(feature.id);
        continue;
      }

      if (matchingKeys.isEmpty) {
        selections.remove(feature.id);
        continue;
      }

      // For grants: auto-select ALL matching keys
      // For options: preserve existing selection or require user choice
      if (isGrants) {
        selections[feature.id] = ClassFeatureDataService.clampSelectionKeys(
          matchingKeys,
          details,
        );
      } else if (matchingKeys.length == 1 || selectionLimit == 1) {
        selections[feature.id] = ClassFeatureDataService.clampSelectionKeys(
          matchingKeys,
          details,
        );
      } else {
        final existing = selections[feature.id] ?? const <String>{};
        final validExisting = existing.intersection(matchingKeys);
        if (validExisting.isNotEmpty) {
          selections[feature.id] = ClassFeatureDataService.clampSelectionKeys(
            validExisting,
            details,
          );
        } else {
          selections.remove(feature.id);
        }
      }
    }
  }

  static void applyDeitySelectionToFeatures({
    required Map<String, Set<String>> selections,
    required Map<String, Map<String, dynamic>> featureDetailsById,
    required Set<String> deityLinkedFeatureIds,
    required Set<String> deitySlugs,
  }) {
    for (final featureId in deityLinkedFeatureIds) {
      final details = featureDetailsById[featureId];
      final selectionLimit = ClassFeatureDataService.selectionLimit(details);
      if (details == null) {
        if (deitySlugs.isEmpty) {
          selections.remove(featureId);
        }
        continue;
      }

      final items = extractOptionsOrGrants(details);
      if (items == null) {
        if (deitySlugs.isEmpty) {
          selections.remove(featureId);
        }
        continue;
      }

      // Check if this feature uses grants (auto-apply all matching)
      final isGrants = hasGrants(details);

      final matchingKeys = <String>{};
      var hasTaggedOption = false;

      for (final option in items) {
        if (option is! Map) continue;
        final map = option is Map<String, dynamic>
            ? option
            : option.cast<String, dynamic>();
        final slugs = _extractDeitySlugs(map);
        if (slugs.isEmpty) continue;
        hasTaggedOption = true;
        if (deitySlugs.isEmpty) continue;
        if (slugs.intersection(deitySlugs).isNotEmpty) {
          matchingKeys.add(featureOptionKey(map));
        }
      }

      if (!hasTaggedOption) {
        if (deitySlugs.isEmpty) {
          selections.remove(featureId);
        }
        continue;
      }

      if (deitySlugs.isEmpty) {
        selections.remove(featureId);
        continue;
      }

      if (matchingKeys.isEmpty) {
        selections.remove(featureId);
        continue;
      }

      // For grants: auto-select ALL matching keys
      // For options: preserve existing selection or require user choice
      if (isGrants) {
        selections[featureId] = ClassFeatureDataService.clampSelectionKeys(
          matchingKeys,
          details,
        );
      } else if (matchingKeys.length == 1 || selectionLimit == 1) {
        selections[featureId] = ClassFeatureDataService.clampSelectionKeys(
          matchingKeys,
          details,
        );
      } else {
        final existing = selections[featureId] ?? const <String>{};
        final validExisting = existing.intersection(matchingKeys);
        if (validExisting.isNotEmpty) {
          selections[featureId] = ClassFeatureDataService.clampSelectionKeys(
            validExisting,
            details,
          );
        } else {
          selections.remove(featureId);
        }
      }
    }
  }

  static String? _classSlugFromId(String? classId) {
    if (classId == null || classId.trim().isEmpty) return null;
    var slug = classId.trim().toLowerCase();
    if (slug.startsWith('class_')) {
      slug = slug.substring('class_'.length);
    }
    return slug.isEmpty ? null : slug;
  }

  Future<List<Map<String, dynamic>>> _loadClassAbilityMaps(
      String classSlug) async {
    try {
      final library = AbilityDataService();
      final components = await library.loadClassAbilities(classSlug);
      return components
          .map((component) => {
                'id': component.id,
                'name': component.name,
                ...component.data,
              })
          .toList(growable: false);
    } catch (_) {
      // Ignore ability load failures; features can still render.
    }
    return const [];
  }

  Future<Map<String, dynamic>> _hydrateFeatureDetail(
    Map<String, dynamic> raw,
  ) async {
    final normalized = Map<String, dynamic>.from(raw);

    final featureAdditional = await _resolveAdditionalFeatures(
        normalized['load_additional_features']);
    if (featureAdditional != null && featureAdditional.isNotEmpty) {
      normalized['loaded_additional_features'] = featureAdditional;
    }

    // Process options, options_X, and grants keys
    final optionKeys = <String>['options', 'grants'];
    // Find any options_X keys
    final optionsXPattern = RegExp(r'^options_\d+$');
    for (final key in normalized.keys) {
      if (optionsXPattern.hasMatch(key)) optionKeys.add(key);
    }
    for (final key in optionKeys) {
      final options = normalized[key];
      if (options is! List) continue;

      final processed = <Map<String, dynamic>>[];
      for (final option in options) {
        if (option is! Map) continue;
        final optionMap = option is Map<String, dynamic>
            ? Map<String, dynamic>.from(option)
            : option.cast<String, dynamic>();
        final optionAdditional = await _resolveAdditionalFeatures(
            optionMap['load_additional_features']);
        if (optionAdditional != null && optionAdditional.isNotEmpty) {
          optionMap['loaded_additional_features'] = optionAdditional;
        }
        processed.add(optionMap);
      }
      normalized[key] = processed;
    }

    return normalized;
  }

  Future<List<Map<String, dynamic>>?> _resolveAdditionalFeatures(
    dynamic spec,
  ) async {
    if (spec == null) return null;

    final specs = <Map<String, dynamic>>[];
    if (spec is Map) {
      specs.add(spec is Map<String, dynamic>
          ? Map<String, dynamic>.from(spec)
          : spec.cast<String, dynamic>());
    } else if (spec is List) {
      for (final entry in spec) {
        if (entry is Map) {
          specs.add(entry is Map<String, dynamic>
              ? Map<String, dynamic>.from(entry)
              : entry.cast<String, dynamic>());
        }
      }
    }

    if (specs.isEmpty) return null;

    final resolved = <Map<String, dynamic>>[];
    for (final entry in specs) {
      final rawName = entry['name']?.toString().trim();
      if (rawName == null || rawName.isEmpty) continue;
      final data = await _loadAdditionalFeatureData(rawName);
      if (data == null) continue;
      final type = entry['type']?.toString().trim();
      resolved.add({
        'type': type ?? 'table',
        'name': rawName,
        'title': entry['title']?.toString(),
        'data': data,
      });
    }

    return resolved.isEmpty ? null : resolved;
  }

  Future<dynamic> _loadAdditionalFeatureData(String name) async {
    if (_additionalFeatureCache.containsKey(name)) {
      return _additionalFeatureCache[name];
    }

    final candidates = <String>[
      name,
      'data/features/$name',
      'data/features/class_features/$name',
      'data/kits/$name',
      'data/$name',
    ];

    for (final candidate in candidates) {
      try {
        final raw = await rootBundle.loadString(candidate);
        final decoded = jsonDecode(raw);
        _additionalFeatureCache[name] = decoded;
        return decoded;
      } catch (_) {
        continue;
      }
    }

    _additionalFeatureCache[name] = null;
    return null;
  }
}

const Set<String> _subclassStopWords = {'the', 'of'};

const List<String> _subclassOptionKeys = [
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
  'name',
];

const List<String> _deityOptionKeys = [
  'deity',
  'deity_name',
  'patron',
  'pantheon',
  'god',
];

Set<String> _extractSubclassSlugs(Map<String, dynamic> option) {
  final slugs = <String>{};
  for (final key in _subclassOptionKeys) {
    final value = option[key];
    if (value == null) continue;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      slugs.addAll(ClassFeatureDataService.slugVariants(trimmed));
    } else if (value is List) {
      for (final entry in value.whereType<String>()) {
        final trimmed = entry.trim();
        if (trimmed.isEmpty) continue;
        slugs.addAll(ClassFeatureDataService.slugVariants(trimmed));
      }
    }
  }
  return slugs;
}

Set<String> _extractDeitySlugs(Map<String, dynamic> option) {
  final slugs = <String>{};
  for (final key in _deityOptionKeys) {
    final value = option[key];
    if (value == null) continue;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      slugs.addAll(ClassFeatureDataService.slugVariants(trimmed));
    } else if (value is List) {
      for (final entry in value.whereType<String>()) {
        final trimmed = entry.trim();
        if (trimmed.isEmpty) continue;
        slugs.addAll(ClassFeatureDataService.slugVariants(trimmed));
      }
    }
  }
  return slugs;
}
