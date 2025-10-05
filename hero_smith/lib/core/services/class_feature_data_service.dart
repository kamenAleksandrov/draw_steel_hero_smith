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
    required this.abilityDetailsById,
    required this.abilityIdByName,
  });

  final Map<String, dynamic>? classMetadata;
  final List<feature_model.Feature> features;
  final Map<String, Map<String, dynamic>> featureDetailsById;
  final Set<String> domainLinkedFeatureIds;
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
      throw Exception('Unable to resolve slug for class "${classData.classId}".');
    }

    Map<String, dynamic>? metadata;
    try {
      final rawMetadata =
          await rootBundle.loadString('data/classes_levels_and_stats/$slug.json');
      metadata = jsonDecode(rawMetadata) as Map<String, dynamic>;
    } catch (_) {
      metadata = null;
    }

    final allFeatures = await FeatureRepository.loadClassFeatures(slug);
    final filteredFeatures = allFeatures
        .where((feature) => feature.level <= level)
        .where((feature) {
          if (!feature.isSubclassFeature) return true;
          if (activeSubclassSlugs.isEmpty) return false;
          return matchesSelectedSubclass(feature.subclassName, activeSubclassSlugs);
        })
        .toList()
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
    final tokens =
        base.split('_').where((token) => token.isNotEmpty).toList(growable: false);
    if (tokens.isEmpty) return {base};

    final variants = <String>{base};

    final trimmedAll = tokens
        .where((token) => !_subclassStopWords.contains(token))
        .join('_');
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

  static String? _classSlugFromId(String? classId) {
    if (classId == null || classId.trim().isEmpty) return null;
    var slug = classId.trim().toLowerCase();
    if (slug.startsWith('class_')) {
      slug = slug.substring('class_'.length);
    }
    return slug.isEmpty ? null : slug;
  }

  Future<List<Map<String, dynamic>>> _loadClassAbilityMaps(String classSlug) async {
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
