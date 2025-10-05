import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/class_data.dart';
import '../models/feature.dart' as feature_model;
import '../models/subclass_models.dart';
import '../repositories/feature_repository.dart';

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
      featureDetails[id] = Map<String, dynamic>.from(entry);
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

  static Set<String> extractOptionKeys(Map<String, dynamic>? details) {
    if (details == null) return const <String>{};
    final options = details['options'];
    if (options is! List) return const <String>{};
    final keys = <String>{};
    for (final option in options) {
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
      final options = details['options'];
      if (options is! List) return;
      final hasDomain = options.any((option) {
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
      final options = details['options'];
      if (options is! List) return;
      final hasDeity = options.any((option) {
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
    final options = details['options'];
    if (options is! List) return const <String>{};
    final keys = <String>{};
    for (final option in options) {
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
    final options = details['options'];
    if (options is! List) return const <String>{};

    final keys = <String>{};
    var hasTaggedOption = false;
    for (final option in options) {
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
    final options = details['options'];
    if (options is! List) return const <String>{};

    final keys = <String>{};
    var hasTaggedOption = false;
    for (final option in options) {
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
      final matchingKeys = domainOptionKeysFor(
        featureDetailsById,
        featureId,
        domainSlugs,
      );
      if (matchingKeys.isNotEmpty) {
        if (domainSlugs.length == 1) {
          selections[featureId] = matchingKeys;
        } else {
          final existing = selections[featureId] ?? const <String>{};
          final validExisting = existing.intersection(matchingKeys);
          selections[featureId] =
              validExisting.isNotEmpty ? validExisting : <String>{};
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
      if (details == null) {
        if (subclassSlugs.isEmpty) {
          selections.remove(feature.id);
        }
        continue;
      }

      final options = details['options'];
      if (options is! List) {
        if (subclassSlugs.isEmpty) {
          selections.remove(feature.id);
        }
        continue;
      }

      final matchingKeys = <String>{};
      var hasTaggedOption = false;

      for (final option in options) {
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

      if (matchingKeys.length == 1) {
        selections[feature.id] = matchingKeys;
      } else {
        final existing = selections[feature.id] ?? const <String>{};
        final validExisting = existing.intersection(matchingKeys);
        if (validExisting.isNotEmpty) {
          selections[feature.id] = validExisting;
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
      if (details == null) {
        if (deitySlugs.isEmpty) {
          selections.remove(featureId);
        }
        continue;
      }

      final options = details['options'];
      if (options is! List) {
        if (deitySlugs.isEmpty) {
          selections.remove(featureId);
        }
        continue;
      }

      final matchingKeys = <String>{};
      var hasTaggedOption = false;

      for (final option in options) {
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

      if (matchingKeys.length == 1) {
        selections[featureId] = matchingKeys;
      } else {
        final existing = selections[featureId] ?? const <String>{};
        final validExisting = existing.intersection(matchingKeys);
        if (validExisting.isNotEmpty) {
          selections[featureId] = validExisting;
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
    final path = 'data/abilities/class_abilities/${classSlug}_abilites.json';
    try {
      final raw = await rootBundle.loadString(path);
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((entry) => entry.cast<String, dynamic>())
            .toList(growable: false);
      }
    } catch (_) {
      // Ignore ability load failures; features can still render.
    }
    return const [];
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
