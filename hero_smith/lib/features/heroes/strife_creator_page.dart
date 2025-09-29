import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/providers.dart';
import '../../core/models/component.dart';
import '../../core/models/feature.dart';
import '../../core/models/hero_model.dart';
import '../../core/repositories/feature_repository.dart';
import '../../core/theme/strife_theme.dart';
import '../../widgets/abilities/ability_full_view.dart';
import '../../widgets/creators/class_abilities_widget.dart';
import '../../widgets/creators/class_features_widget.dart';
import '../../widgets/pickers/language_picker.dart';
import '../../widgets/pickers/perk_picker.dart';

const Set<String> _subclassStopWords = {'the', 'of'};

const List<String> _characteristicKeys = <String>[
  'might',
  'agility',
  'reason',
  'intuition',
  'presence',
];

const Map<String, String> _characteristicKeyAliases = <String, String>{
  'might': 'might',
  'agility': 'agility',
  'reason': 'reason',
  'intuition': 'intuition',
  'intuitition': 'intuition',
  'presence': 'presence',
};

class StrifeCreatorTab extends ConsumerStatefulWidget {
  const StrifeCreatorTab({
    super.key,
    required this.heroId,
    this.onDirtyChanged,
  });

  final String heroId;
  final ValueChanged<bool>? onDirtyChanged;

  @override
  StrifeCreatorTabState createState() => StrifeCreatorTabState();
}

class StrifeCreatorTabState extends ConsumerState<StrifeCreatorTab> {
  bool _loading = true;
  bool _dirty = false;
  HeroModel? _model;

  int _level = 1;
  String? _classComponentId;
  String? _classSlug;
  String? _subclassComponentId;

  Map<String, dynamic>? _classData;
  List<Feature> _classFeatures = const [];
  Map<String, Map<String, dynamic>> _classFeatureDetailsById =
      <String, Map<String, dynamic>>{};

  Map<String, int> _fixedStartingCharacteristics = <String, int>{};
  List<Map<String, dynamic>> _availableCharacteristicArrays = const [];
  int? _selectedCharacteristicArrayIndex;
  Map<String, int?> _characteristicArrayAssignments =
      <String, int?>{};

  // Class skill selection state
  int _classSkillPickCount = 0;
  List<String> _classSkillGroups = const [];
  final Set<String> _grantedClassSkillIds = <String>{};
  final Set<String> _classSkillCandidateIds = <String>{};
  final Set<String> _selectedClassSkillIds = <String>{};
  final Set<String> _baselineSkillIds = <String>{};
  List<Component> _classSkillComponents = const [];

  // Class ability selection state
  List<Map<String, dynamic>> _classAbilityData = const [];
  final Map<String, Map<String, dynamic>> _abilityDetailsById =
      <String, Map<String, dynamic>>{};
  final Map<String, String> _abilityIdByName = <String, String>{};
  final Set<String> _selectedAbilityIds = <String>{};
  final Set<String> _autoGrantedAbilityIds = <String>{};
  final Set<String> _baselineAbilityIds = <String>{};

  List<Component> _perkComponents = const [];
  List<PerkAllowance> _perkAllowances = const [];
  final Map<int, List<String?>> _perkSelections = <int, List<String?>>{};
  final Set<String> _selectedPerkIds = <String>{};
  final Set<String> _baselinePerkIds = <String>{};
  List<Component> _languageComponents = const [];
  List<LanguageAllowance> _languageAllowances = const [];
  final Map<int, List<String?>> _languageSelections = <int, List<String?>>{};
  final Set<String> _selectedLanguageIds = <String>{};
  final Set<String> _baselineLanguageIds = <String>{};
  final Map<String, Set<String>> _featureOptionSelections =
      <String, Set<String>>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(heroRepositoryProvider);
    final hero = await repo.load(widget.heroId);
    if (!mounted) return;

    final initialLevel = (hero?.level ?? 1).clamp(1, 10);
    final classId = hero?.className;
    setState(() {
      _model = hero;
      _level = initialLevel;
      _classComponentId = classId;
      _classSlug = _slugForClass(classId);
      _subclassComponentId = hero?.subclass;
    });
    _setDirty(false);
    await _refreshClassData();
  }

  Future<void> _refreshClassData() async {
    final slug = _classSlug;
    if (slug == null || slug.isEmpty) {
      setState(() {
        _classData = null;
        _classFeatures = const [];
        _loading = false;
        _resetClassDependentState();
      });
      return;
    }

    setState(() => _loading = true);
    final metadata = await _loadClassMetadata(slug);
    final features = await _loadClassFeatures(slug);
    List<Map<String, dynamic>> featureMaps = const [];
    try {
      featureMaps = await FeatureRepository.loadClassFeatureMaps(slug);
    } catch (_) {
      featureMaps = const [];
    }
    final abilities = await _loadClassAbilities(slug);
    await _prepareSkillState(metadata);
    _prepareCharacteristicState(metadata);
    _prepareAbilityData(abilities);
    await _preparePerkState(metadata);
    await _prepareLanguageState(metadata);
    if (!mounted) return;
    final featureDetailsById = <String, Map<String, dynamic>>{};
    for (final entry in featureMaps) {
      final id = entry['id']?.toString();
      if (id == null || id.isEmpty) continue;
      featureDetailsById[id] = entry;
    }
    final filteredFeatureSelections = <String, Set<String>>{};
    for (final feature in features) {
      final existing = _featureOptionSelections[feature.id];
      if (existing != null && existing.isNotEmpty) {
        filteredFeatureSelections[feature.id] = existing.toSet();
      }
    }

    setState(() {
      _classData = metadata;
      _classFeatures = features;
      _classFeatureDetailsById
        ..clear()
        ..addAll(featureDetailsById);
      _featureOptionSelections
        ..clear()
        ..addAll(filteredFeatureSelections);
      _loading = false;
    });
  }

  Future<Map<String, dynamic>?> _loadClassMetadata(String slug) async {
    final path = 'data/classes_levels_and_stats/$slug.json';
    try {
      final raw = await rootBundle.loadString(path);
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<List<Feature>> _loadClassFeatures(String slug) async {
    try {
      final features = await FeatureRepository.loadClassFeatures(slug);
      final filtered = features
          .where((feature) => feature.level <= _level)
          .where((feature) =>
              !feature.isSubclassFeature ||
              _matchesSelectedSubclass(feature.subclassName))
          .toList()
        ..sort((a, b) => a.level.compareTo(b.level));
      return filtered;
    } catch (_) {
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadClassAbilities(String slug) async {
    final path = 'data/abilities/class_abilities/${slug}_abilites.json';
    try {
      final raw = await rootBundle.loadString(path);
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final abilities = decoded
          .whereType<Map>()
          .map((entry) => entry.cast<String, dynamic>())
          .toList(growable: false);
      abilities.sort((a, b) {
        final levelA = (a['level'] as num?)?.toInt() ?? 0;
        final levelB = (b['level'] as num?)?.toInt() ?? 0;
        if (levelA != levelB) {
          return levelA.compareTo(levelB);
        }
        return (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
      });
      return abilities;
    } catch (_) {
      return const [];
    }
  }

  void _setDirty(bool value) {
    if (_dirty == value) return;
    if (mounted) {
      setState(() {
        _dirty = value;
      });
    } else {
      _dirty = value;
    }
    widget.onDirtyChanged?.call(value);
  }

  String? _slugForClass(String? componentId) {
    if (componentId == null || componentId.trim().isEmpty) return null;
    final normalized = componentId.trim().toLowerCase();
    if (normalized.startsWith('class_')) {
      return normalized.substring(6);
    }
    return normalized;
  }

  String _slugify(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final collapsed = normalized.replaceAll(RegExp(r'_+'), '_');
    return collapsed.replaceAll(RegExp(r'^_|_$'), '');
  }

  String? get _selectedSubclassSlug {
    final id = _subclassComponentId?.trim().toLowerCase();
    if (id == null || id.isEmpty) return null;
    var slug = id;
    if (slug.startsWith('subclass_')) {
      slug = slug.substring('subclass_'.length);
    }
    final parts = slug.split('_').where((part) => part.isNotEmpty).toList();
    if (parts.length <= 1) {
      return slug;
    }
    return parts.sublist(1).join('_');
  }

  String? get _selectedSubclassDisplayName {
    final slug = _selectedSubclassSlug;
    if (slug == null || slug.isEmpty) return null;
    final parts = slug.split('_').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    return parts
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.length > 1 ? part.substring(1) : ''}')
        .join(' ');
  }

  Set<String> _slugVariants(String? value) {
    if (value == null || value.trim().isEmpty) {
      return const <String>{};
    }
    final base = _slugify(value);
    if (base.isEmpty) return const <String>{};
    final tokens =
        base.split('_').where((token) => token.isNotEmpty).toList(growable: false);
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

  Set<String> get _activeSubclassSlugs {
    final slug = _selectedSubclassSlug;
    if (slug == null) return const <String>{};
    return _slugVariants(slug);
  }

  bool _matchesSelectedSubclass(String? value) {
    if (value == null || value.toString().trim().isEmpty) {
      return true;
    }
    final active = _activeSubclassSlugs;
    if (active.isEmpty) return false;
    final required = _slugVariants(value);
    if (required.isEmpty) return true;
    return required.intersection(active).isNotEmpty;
  }

  Map<String, dynamic>? get _startingCharacteristics {
    final start = _classData?['starting_characteristics'];
    if (start is Map<String, dynamic>) {
      return start;
    }
    return null;
  }

  List<Map<String, dynamic>> _levelsUpToCurrentFromMetadata(
    Map<String, dynamic>? metadata,
  ) {
    final result = <Map<String, dynamic>>[];
    final start = metadata?['starting_characteristics'];
    final levels = start is Map<String, dynamic> ? start['levels'] : null;
    if (levels is! List) return result;
    for (final entry in levels) {
      if (entry is! Map) continue;
      final casted = entry.cast<String, dynamic>();
      final levelNumber = (casted['level'] as num?)?.toInt();
      if (levelNumber == null || levelNumber > _level) continue;
      result.add(casted);
    }
    result.sort((a, b) {
      final aLevel = (a['level'] as num?)?.toInt() ?? 0;
      final bLevel = (b['level'] as num?)?.toInt() ?? 0;
      return aLevel.compareTo(bLevel);
    });
    return result;
  }

  String? _normalizeCharacteristicKey(String? key) {
    if (key == null) return null;
    final normalized = key.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    if (_characteristicKeyAliases.containsKey(normalized)) {
      return _characteristicKeyAliases[normalized];
    }
    return normalized;
  }

  String _characteristicDisplayName(String key) {
    final normalized = _normalizeCharacteristicKey(key) ?? key;
    return normalized.capitalize();
  }

  Map<String, int> _extractFixedStartingCharacteristics(
    Map<String, dynamic>? metadata,
  ) {
    final result = <String, int>{};
    final start = metadata?['starting_characteristics'];
    if (start is Map<String, dynamic>) {
      final fixed = start['fixed_starting_characteristics'];
      if (fixed is Map) {
        fixed.forEach((key, value) {
          final normalized = _normalizeCharacteristicKey(key?.toString());
          final amount = _toIntOrNull(value);
          if (normalized != null && amount != null) {
            result[normalized] = (result[normalized] ?? 0) + amount;
          }
        });
      }
    }

    for (final level in _levelsUpToCurrentFromMetadata(metadata)) {
      final fixed = level['fixed_starting_characteristics'];
      if (fixed is Map) {
        fixed.forEach((key, value) {
          final normalized = _normalizeCharacteristicKey(key?.toString());
          final amount = _toIntOrNull(value);
          if (normalized != null && amount != null) {
            result[normalized] = (result[normalized] ?? 0) + amount;
          }
        });
      }
    }

    return result;
  }

  List<Map<String, dynamic>> _extractCharacteristicArraysFromMetadata(
    Map<String, dynamic>? metadata,
  ) {
    final collected = <Map<String, dynamic>>[];
    final start = metadata?['starting_characteristics'];
    final primary = start is Map<String, dynamic>
        ? start['starting_characteristics_arrays']
        : null;
    if (primary is List) {
      for (final entry in primary) {
        if (entry is Map) {
          collected.add(entry.cast<String, dynamic>());
        }
      }
    }
    if (collected.isNotEmpty) return collected;

    final levels = _levelsUpToCurrentFromMetadata(metadata).reversed;
    for (final level in levels) {
      final arrays = level['starting_characteristics_arrays'];
      if (arrays is List && arrays.isNotEmpty) {
        for (final entry in arrays) {
          if (entry is Map) {
            collected.add(entry.cast<String, dynamic>());
          }
        }
        if (collected.isNotEmpty) break;
      }
    }
    return collected;
  }

  List<int> _characteristicArrayValues(Map<String, dynamic> arrayEntry) {
    final raw = arrayEntry['values'];
    if (raw is List) {
      return raw
          .whereType<num>()
          .map((value) => value.toInt())
          .toList(growable: false);
    }
    return const <int>[];
  }

  ({int arrayIndex, Map<String, int?> assignments})?
      _inferCharacteristicAssignmentsFromHero(
    HeroModel hero,
    Map<String, int> fixed,
    List<Map<String, dynamic>> arrays,
  ) {
    if (arrays.isEmpty) return null;
    final freeKeys =
        _characteristicKeys.where((key) => !fixed.containsKey(key)).toList();
    if (freeKeys.isEmpty) return null;

    final heroStats = <String, int>{
      'might': hero.might,
      'agility': hero.agility,
      'reason': hero.reason,
      'intuition': hero.intuition,
      'presence': hero.presence,
    };

    for (var index = 0; index < arrays.length; index++) {
      final values = _characteristicArrayValues(arrays[index]);
      if (values.length < freeKeys.length) continue;

      final available = <int, int>{};
      for (final value in values) {
        available[value] = (available[value] ?? 0) + 1;
      }

      final assignments = <String, int?>{};
      var matches = true;
      final remaining = Map<int, int>.from(available);

      for (final key in freeKeys) {
        final statValue = heroStats[key];
        if (statValue == null) {
          matches = false;
          break;
        }
        final diff = statValue - (fixed[key] ?? 0);
        final count = remaining[diff] ?? 0;
        if (count <= 0) {
          matches = false;
          break;
        }
        remaining[diff] = count - 1;
        assignments[key] = diff;
      }

      if (matches) {
        for (final key in _characteristicKeys) {
          assignments.putIfAbsent(key, () => null);
        }
        return (arrayIndex: index, assignments: assignments);
      }
    }

    return null;
  }

  Map<String, int?> _defaultCharacteristicAssignmentsForArray(
    List<int> values,
    Map<String, int> fixed,
  ) {
    final assignments = <String, int?>{
      for (final key in _characteristicKeys) key: null,
    };

    final freeKeys =
        _characteristicKeys.where((key) => !fixed.containsKey(key)).toList();
    for (var i = 0; i < freeKeys.length && i < values.length; i++) {
      assignments[freeKeys[i]] = values[i];
    }
    return assignments;
  }

  void _prepareCharacteristicState(Map<String, dynamic>? metadata) {
    final fixed = _extractFixedStartingCharacteristics(metadata);
    final arrays = _extractCharacteristicArraysFromMetadata(metadata);
    final assignments = <String, int?>{
      for (final key in _characteristicKeys) key: null,
    };

    int? selectedIndex;
    if (_model != null) {
      final inferred = _inferCharacteristicAssignmentsFromHero(
        _model!,
        fixed,
        arrays,
      );
      if (inferred != null) {
        selectedIndex = inferred.arrayIndex;
        assignments.addAll(inferred.assignments);
      }
    }

    if (selectedIndex == null && arrays.length == 1) {
      selectedIndex = 0;
      assignments.addAll(_defaultCharacteristicAssignmentsForArray(
        _characteristicArrayValues(arrays.first),
        fixed,
      ));
    }

    if (!mounted) return;
    setState(() {
      _fixedStartingCharacteristics = fixed;
      _availableCharacteristicArrays = arrays;
      _selectedCharacteristicArrayIndex = selectedIndex;
      _characteristicArrayAssignments = assignments;
    });
  }

  void _selectCharacteristicArray(int index) {
    if (index < 0 || index >= _availableCharacteristicArrays.length) return;
    final fixed = Map<String, int>.from(_fixedStartingCharacteristics);
    final values = _characteristicArrayValues(
      _availableCharacteristicArrays[index],
    );
    final assignments = _defaultCharacteristicAssignmentsForArray(values, fixed);
    setState(() {
      _selectedCharacteristicArrayIndex = index;
      _characteristicArrayAssignments = assignments;
    });
    _setDirty(true);
  }

  List<int> _availableValuesForCharacteristic(String key) {
    if (_selectedCharacteristicArrayIndex == null) {
      return const <int>[];
    }
    final array =
        _availableCharacteristicArrays[_selectedCharacteristicArrayIndex!];
    final values = _characteristicArrayValues(array);
    if (values.isEmpty) return const <int>[];

    final counts = <int, int>{};
    for (final value in values) {
      counts[value] = (counts[value] ?? 0) + 1;
    }

    final normalizedKey = _normalizeCharacteristicKey(key) ?? key;
    final currentValue = _characteristicArrayAssignments[normalizedKey];

    for (final entry in _characteristicArrayAssignments.entries) {
      if (entry.key == normalizedKey) continue;
      final assignedValue = entry.value;
      if (assignedValue == null) continue;
      final remaining = (counts[assignedValue] ?? 0) - 1;
      counts[assignedValue] = remaining;
    }

    if (currentValue != null) {
      counts[currentValue] = (counts[currentValue] ?? 0) + 1;
    }

    final available = counts.entries
        .where((entry) => entry.value > 0)
        .map((entry) => entry.key)
        .toList();
    available.sort((a, b) => b.compareTo(a));
    return available;
  }

  void _updateCharacteristicAssignment(String key, int? value) {
    final normalizedKey = _normalizeCharacteristicKey(key) ?? key;
    if (!_characteristicArrayAssignments.containsKey(normalizedKey)) return;
    final updated = Map<String, int?>.from(_characteristicArrayAssignments);
    updated[normalizedKey] = value;
    setState(() {
      _characteristicArrayAssignments = updated;
    });
    _setDirty(true);
  }

  bool _hasCompleteCharacteristicAssignments() {
    if (_selectedCharacteristicArrayIndex == null) return false;
    final fixedKeys = _fixedStartingCharacteristics.keys.toSet();
    for (final key in _characteristicKeys) {
      if (fixedKeys.contains(key)) continue;
      if (_characteristicArrayAssignments[key] == null) {
        return false;
      }
    }
    return true;
  }

  Map<String, int> _finalCharacteristicScores() {
    final result = <String, int>{};
    for (final key in _characteristicKeys) {
      final base = _fixedStartingCharacteristics[key] ?? 0;
      final bonus = _characteristicArrayAssignments[key] ?? 0;
      result[key] = base + bonus;
    }
    return result;
  }

  List<Component> _eligiblePerksForAllowance(int allowanceIndex) {
    if (allowanceIndex < 0 || allowanceIndex >= _perkAllowances.length) {
      return const [];
    }
    final allowance = _perkAllowances[allowanceIndex];
    return _perkComponents
        .where((component) {
          final group =
              component.data['group']?.toString().trim().toLowerCase();
          return allowance.allowsGroup(group);
        })
        .toList();
  }

  Set<String> _currentSelectedPerkIds() {
    final selected = <String>{};
    for (final entry in _perkSelections.values) {
      for (final id in entry) {
        if (id != null) selected.add(id);
      }
    }
    return selected;
  }

  void _updatePerkSelection(
    int allowanceIndex,
    int slotIndex,
    String? perkId,
  ) {
    final existingSlots = _perkSelections[allowanceIndex];
    if (existingSlots == null ||
        slotIndex < 0 ||
        slotIndex >= existingSlots.length) {
      return;
    }

    final eligibleIds = _eligiblePerksForAllowance(allowanceIndex)
        .map((component) => component.id)
        .toSet();
    final normalizedId = perkId?.trim();
    final resolvedId = normalizedId != null && eligibleIds.contains(normalizedId)
        ? normalizedId
        : null;

    final currentId = existingSlots[slotIndex];
    if (currentId == resolvedId) return;

    final updatedSelections = <int, List<String?>>{};
    for (final entry in _perkSelections.entries) {
      updatedSelections[entry.key] = List<String?>.from(entry.value);
    }

    if (currentId != null) {
      updatedSelections[allowanceIndex]![slotIndex] = null;
    }

    if (resolvedId != null) {
      for (final entry in updatedSelections.entries) {
        final list = entry.value;
        for (var i = 0; i < list.length; i++) {
          if (list[i] == resolvedId) list[i] = null;
        }
      }
      updatedSelections[allowanceIndex]![slotIndex] = resolvedId;
    }

    final newSelected = <String>{};
    for (final list in updatedSelections.values) {
      for (final id in list) {
        if (id != null) newSelected.add(id);
      }
    }

    setState(() {
      _perkSelections
        ..clear()
        ..addAll(updatedSelections);
      _selectedPerkIds
        ..clear()
        ..addAll(newSelected);
    });
    _setDirty(true);
  }

  Set<String> _currentSelectedLanguageIds() {
    final selected = <String>{};
    for (final entry in _languageSelections.values) {
      for (final id in entry) {
        if (id != null) selected.add(id);
      }
    }
    return selected;
  }

  void _updateLanguageSelection(
    int allowanceIndex,
    int slotIndex,
    String? languageId,
  ) {
    final existingSlots = _languageSelections[allowanceIndex];
    if (existingSlots == null ||
        slotIndex < 0 ||
        slotIndex >= existingSlots.length) {
      return;
    }

    final allowance =
        allowanceIndex >= 0 && allowanceIndex < _languageAllowances.length
            ? _languageAllowances[allowanceIndex]
            : null;
    if (allowance == null) return;

    final eligibleIds = _languageComponents
        .where((component) {
          final type =
              component.data['language_type']?.toString().trim().toLowerCase();
          return allowance.allowsType(type);
        })
        .map((component) => component.id)
        .toSet();

    final normalizedId = languageId?.trim();
    final resolvedId = normalizedId != null && eligibleIds.contains(normalizedId)
        ? normalizedId
        : null;

    final currentId = existingSlots[slotIndex];
    if (currentId == resolvedId) return;

    final updatedSelections = <int, List<String?>>{};
    for (final entry in _languageSelections.entries) {
      updatedSelections[entry.key] = List<String?>.from(entry.value);
    }

    if (currentId != null) {
      updatedSelections[allowanceIndex]![slotIndex] = null;
    }

    if (resolvedId != null) {
      for (final entry in updatedSelections.entries) {
        final list = entry.value;
        for (var i = 0; i < list.length; i++) {
          if (list[i] == resolvedId) list[i] = null;
        }
      }
      updatedSelections[allowanceIndex]![slotIndex] = resolvedId;
    }

    final newSelected = <String>{};
    for (final list in updatedSelections.values) {
      for (final id in list) {
        if (id != null) newSelected.add(id);
      }
    }

    setState(() {
      _languageSelections
        ..clear()
        ..addAll(updatedSelections);
      _selectedLanguageIds
        ..clear()
        ..addAll(newSelected);
    });
    _setDirty(true);
  }

  List<PerkAllowance> _extractPerkAllowances(
    Map<String, dynamic>? metadata,
  ) {
    final allowances = <PerkAllowance>[];
    final levels = _levelsUpToCurrentFromMetadata(metadata);
    for (final levelData in levels) {
      final levelNumber = (levelData['level'] as num?)?.toInt() ?? _level;
      final rawPerks = levelData['perks'];
      if (rawPerks == null) continue;

      void addAllowance(Map<dynamic, dynamic> source) {
        final count = (source['count'] as num?)?.toInt() ?? 0;
        if (count <= 0) return;
        final groupsRaw =
            source['perk_groups'] ?? source['groups'] ?? source['group'];
        final groups = <String>{};
        if (groupsRaw is Iterable) {
          for (final entry in groupsRaw) {
            final normalized = entry?.toString().trim().toLowerCase();
            if (normalized != null && normalized.isNotEmpty) {
              groups.add(normalized);
            }
          }
        } else if (groupsRaw is String) {
          final normalized = groupsRaw.trim().toLowerCase();
          if (normalized.isNotEmpty) groups.add(normalized);
        }

        final labelGroups = groups.isEmpty
            ? 'any group'
            : groups.map((g) => g.capitalize()).join(', ');
        allowances.add(PerkAllowance(
          level: levelNumber,
          count: count,
          groups: groups,
          label: 'Level $levelNumber · $labelGroups',
        ));
      }

      if (rawPerks is Map) {
        addAllowance(rawPerks);
      } else if (rawPerks is Iterable) {
        for (final entry in rawPerks) {
          if (entry is Map) addAllowance(entry);
        }
      } else if (rawPerks is num) {
        final count = rawPerks.toInt();
        if (count > 0) {
          allowances.add(PerkAllowance(
            level: levelNumber,
            count: count,
            groups: const <String>{},
            label: 'Level $levelNumber · any group',
          ));
        }
      }
    }
    return allowances;
  }

  List<LanguageAllowance> _extractLanguageAllowances(
    Map<String, dynamic>? metadata,
  ) {
    final allowances = <LanguageAllowance>[];
    final levels = _levelsUpToCurrentFromMetadata(metadata);
    for (final levelData in levels) {
      final levelNumber = (levelData['level'] as num?)?.toInt() ?? _level;
      final rawLanguages = levelData['languages'];
      if (rawLanguages == null) continue;

      void addAllowance(Map<dynamic, dynamic> source) {
        final count = (source['count'] as num?)?.toInt() ?? 0;
        if (count <= 0) return;
        final typesRaw =
            source['language_types'] ?? source['types'] ?? source['type'];
        final types = <String>{};
        if (typesRaw is Iterable) {
          for (final entry in typesRaw) {
            final normalized = entry?.toString().trim().toLowerCase();
            if (normalized != null && normalized.isNotEmpty) {
              if (normalized == 'any') {
                types.clear();
                break;
              }
              types.add(normalized);
            }
          }
        } else if (typesRaw is String) {
          final normalized = typesRaw.trim().toLowerCase();
          if (normalized.isNotEmpty && normalized != 'any') {
            types.add(normalized);
          }
        }

        final labelTypes = types.isEmpty
            ? 'any type'
            : types.map((t) => t.capitalize()).join(', ');
        allowances.add(LanguageAllowance(
          level: levelNumber,
          count: count,
          types: types,
          label: 'Level $levelNumber · $labelTypes',
        ));
      }

      if (rawLanguages is Map) {
        addAllowance(rawLanguages);
      } else if (rawLanguages is Iterable) {
        for (final entry in rawLanguages) {
          if (entry is Map) addAllowance(entry);
        }
      } else if (rawLanguages is num) {
        final count = rawLanguages.toInt();
        if (count > 0) {
          allowances.add(LanguageAllowance(
            level: levelNumber,
            count: count,
            types: const <String>{},
            label: 'Level $levelNumber · any type',
          ));
        }
      }
    }
    return allowances;
  }

  Map<String, int> _fixedCharacteristicBoosts() {
    return Map<String, int>.from(_fixedStartingCharacteristics);
  }

  void _resetClassDependentState() {
    final existingSkillIds = (_model?.skills ?? const <String>[]).toSet();
    final existingAbilityIds = (_model?.abilities ?? const <String>[]).toSet();

    _fixedStartingCharacteristics = <String, int>{};
    _availableCharacteristicArrays = const [];
    _selectedCharacteristicArrayIndex = null;
    _characteristicArrayAssignments = {
      for (final key in _characteristicKeys) key: null,
    };

    _subclassComponentId = null;
    _classSkillPickCount = 0;
    _classSkillGroups = const [];
    _classSkillComponents = const [];
    _grantedClassSkillIds.clear();
    _classSkillCandidateIds.clear();
    _selectedClassSkillIds.clear();
    _baselineSkillIds
      ..clear()
      ..addAll(existingSkillIds);

    _classAbilityData = const [];
    _abilityDetailsById.clear();
    _abilityIdByName.clear();
    _selectedAbilityIds.clear();
    _autoGrantedAbilityIds.clear();
    _baselineAbilityIds
      ..clear()
      ..addAll(existingAbilityIds);
    _featureOptionSelections.clear();

    _perkComponents = const [];
    _perkAllowances = const [];
    _perkSelections.clear();
    _selectedPerkIds.clear();
    _baselinePerkIds
      ..clear()
      ..addAll((_model?.perks ?? const <String>[]));
    _languageComponents = const [];
    _languageAllowances = const [];
    _languageSelections.clear();
    _selectedLanguageIds.clear();
    _baselineLanguageIds
      ..clear()
      ..addAll((_model?.languages ?? const <String>[]));
  }

  Future<void> _prepareSkillState(Map<String, dynamic>? metadata) async {
    if (!mounted) return;
    final start = metadata?['starting_characteristics'];
    if (start is! Map<String, dynamic>) {
      setState(() {
        _classSkillPickCount = 0;
        _classSkillGroups = const [];
        _classSkillComponents = const [];
        _grantedClassSkillIds.clear();
        _classSkillCandidateIds.clear();
        _selectedClassSkillIds.clear();
        _baselineSkillIds
          ..clear()
          ..addAll((_model?.skills ?? const <String>[]));
      });
      return;
    }

    final skillsInfo = start['starting_skills'];
    if (skillsInfo is! Map<String, dynamic>) {
      setState(() {
        _classSkillPickCount = 0;
        _classSkillGroups = const [];
        _classSkillComponents = const [];
        _grantedClassSkillIds.clear();
        _classSkillCandidateIds.clear();
        _selectedClassSkillIds.clear();
        _baselineSkillIds
          ..clear()
          ..addAll((_model?.skills ?? const <String>[]));
      });
      return;
    }

    List<Component> allSkillComponents = const [];
    try {
      allSkillComponents =
          await ref.read(componentsByTypeProvider('skill').future);
    } catch (_) {
      allSkillComponents = const [];
    }
    if (!mounted) return;

  final groupNames = ((skillsInfo['skill_groups'] as List?) ?? const [])
        .map((e) => e.toString().trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    final specificNames = ((skillsInfo['specific_skills'] as List?) ?? const [])
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toSet();
    final grantedNames = ((skillsInfo['granted_skills'] as List?) ?? const [])
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toSet();

    final subclassSlugSet = _activeSubclassSlugs;
    final subclassSkillNames = <String>{};

    void collectSubclassSkills(dynamic source) {
      if (source is Map) {
        for (final entry in source.entries) {
          final key = entry.key?.toString() ?? '';
          if (key.trim().isEmpty) continue;
          final variants = _slugVariants(key);
          if (variants.isEmpty ||
              variants.intersection(subclassSlugSet).isEmpty) {
            continue;
          }
          final value = entry.value;
          if (value is List) {
            for (final item in value) {
              final name = item?.toString().trim();
              if (name != null && name.isNotEmpty) {
                subclassSkillNames.add(name);
              }
            }
          } else {
            final name = value?.toString().trim();
            if (name != null && name.isNotEmpty) {
              subclassSkillNames.add(name);
            }
          }
        }
      }
    }

    if (subclassSlugSet.isNotEmpty) {
      final levels = _levelsUpToCurrentFromMetadata(metadata);
      for (final level in levels) {
        final subclassEntries = level['subclass_features'];
        if (subclassEntries is List) {
          for (final entry in subclassEntries) {
            collectSubclassSkills(entry);
          }
        } else {
          collectSubclassSkills(subclassEntries);
        }
      }
    }

    grantedNames.addAll(subclassSkillNames);

    final pickCount =
        (skillsInfo['skill_count'] as num?)?.toInt() ?? groupNames.length;

    final grantedIds = grantedNames
        .map((name) => _resolveSkillComponentId(allSkillComponents, name))
        .whereType<String>()
        .toSet();
    final specificIds = specificNames
        .map((name) => _resolveSkillComponentId(allSkillComponents, name))
        .whereType<String>()
        .toSet();

    final allowAllGroups =
        groupNames.isEmpty && ((skillsInfo['skill_count'] as num?)?.toInt() ?? 0) > 0;

    final groupCandidateIds = allowAllGroups
        ? allSkillComponents.map((component) => component.id).toSet()
        : allSkillComponents
            .where((component) {
              final group =
                  component.data['group']?.toString().trim().toLowerCase();
              return group != null && groupNames.contains(group);
            })
            .map((component) => component.id)
            .toSet();

    final candidateIds = <String>{
      ...grantedIds,
      ...specificIds,
      ...groupCandidateIds,
    };

    final eligibleComponents = allSkillComponents
        .where((component) => candidateIds.contains(component.id))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final existingSkills = (_model?.skills ?? const <String>[]).toList();
    final baseline =
        existingSkills.where((id) => !candidateIds.contains(id)).toSet();
    final existingSelectedCandidates =
        existingSkills.where((id) => candidateIds.contains(id)).toList();

    final optionalOrdered = existingSelectedCandidates
        .where((id) => !grantedIds.contains(id))
        .toList();
    final trimmedOptional = optionalOrdered.take(pickCount).toSet();
    final selectedIds = <String>{
      ...grantedIds,
      ...trimmedOptional,
    };

    setState(() {
      _classSkillPickCount = pickCount;
      _classSkillGroups = allowAllGroups
          ? const ['Any']
          : (groupNames.toList()..sort());
      _classSkillComponents = eligibleComponents;
      _grantedClassSkillIds
        ..clear()
        ..addAll(grantedIds);
      _classSkillCandidateIds
        ..clear()
        ..addAll(candidateIds);
      _baselineSkillIds
        ..clear()
        ..addAll(baseline);
      _selectedClassSkillIds
        ..clear()
        ..addAll(selectedIds);
    });
  }

  String? _resolveSkillComponentId(List<Component> skills, String name) {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final skill in skills) {
      if (skill.id.toLowerCase() == normalized ||
          skill.name.toLowerCase() == normalized) {
        return skill.id;
      }
    }
    return null;
  }

  void _prepareAbilityData(List<Map<String, dynamic>> abilities) {
    final previousSelections = _selectedAbilityIds.toSet();
    final previousAuto = _autoGrantedAbilityIds.toSet();

    final abilityDetails = <String, Map<String, dynamic>>{};
    final abilityNameIndex = <String, String>{};
    final processedAbilities = <Map<String, dynamic>>[];

    for (final ability in abilities) {
      final rawId = ability['id']?.toString() ?? '';
      final rawName = ability['name']?.toString() ?? '';
      if (rawId.trim().isEmpty && rawName.trim().isEmpty) {
        continue;
      }
      final resolvedId = rawId.trim().isNotEmpty
          ? rawId.trim()
          : _slugify(rawName.trim());
      final abilityCopy = Map<String, dynamic>.from(ability)
        ..['resolved_id'] = resolvedId;
      processedAbilities.add(abilityCopy);
      abilityDetails[resolvedId] = abilityCopy;
      if (rawName.trim().isNotEmpty) {
        abilityNameIndex[_normalizeAbilityName(rawName)] = resolvedId;
      }
      abilityNameIndex[_normalizeAbilityName(resolvedId)] = resolvedId;
    }

    final recognizedIds = abilityDetails.keys.toSet();
    final heroAbilityIds = (_model?.abilities ?? const <String>[]) 
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    final baselineIds = heroAbilityIds.difference(recognizedIds);
    final restoredSelections = <String>{
      ...previousSelections.intersection(recognizedIds),
      ...heroAbilityIds.intersection(recognizedIds),
    };

    if (!mounted) return;
    setState(() {
      _classAbilityData = processedAbilities;
      _abilityDetailsById
        ..clear()
        ..addAll(abilityDetails);
      _abilityIdByName
        ..clear()
        ..addAll(abilityNameIndex);
      _baselineAbilityIds
        ..clear()
        ..addAll(baselineIds);
      _selectedAbilityIds
        ..clear()
        ..addAll(restoredSelections.difference(previousAuto));
      _autoGrantedAbilityIds
        ..clear()
        ..addAll(previousAuto.intersection(recognizedIds));
    });
  }

  void _updateAbilitySelections(Set<String> selections) {
    final normalized = selections
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (setEquals(normalized, _selectedAbilityIds)) return;
    setState(() {
      _selectedAbilityIds
        ..clear()
        ..addAll(normalized);
    });
    _setDirty(true);
  }

  void _updateFeatureSelection(String featureId, Set<String> selections) {
    final normalizedId = featureId.trim();
    if (normalizedId.isEmpty) return;
    final normalizedSelections = selections
        .map((option) => option.trim())
        .where((option) => option.isNotEmpty)
        .toSet();
    final current = _featureOptionSelections[normalizedId] ?? const <String>{};
    if (setEquals(current, normalizedSelections)) return;
    setState(() {
      _featureOptionSelections[normalizedId] = normalizedSelections;
    });
    _setDirty(true);
  }

  Future<void> _preparePerkState(Map<String, dynamic>? metadata) async {
    final allowances = _extractPerkAllowances(metadata);
    if (allowances.isEmpty) {
      if (!mounted) return;
      setState(() {
        _perkComponents = const [];
        _perkAllowances = const [];
        _perkSelections.clear();
        _selectedPerkIds.clear();
        _baselinePerkIds
          ..clear()
          ..addAll((_model?.perks ?? const <String>[]));
      });
      return;
    }

    List<Component> allPerks = const [];
    try {
      allPerks = await ref.read(componentsByTypeProvider('perk').future);
    } catch (_) {
      allPerks = const [];
    }

    if (!mounted) return;

    final sortedPerks = allPerks.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final componentById = {
      for (final perk in sortedPerks) perk.id.toLowerCase(): perk,
    };

    final candidateIds = <String>{};
    for (final perk in sortedPerks) {
      final group = perk.data['group']?.toString().trim().toLowerCase();
      final matches = allowances.any((allowance) => allowance.allowsGroup(group));
      if (matches) candidateIds.add(perk.id);
    }

    final existingPerks = (_model?.perks ?? const <String>[]).toList();
    final baseline = existingPerks
        .where((id) => !candidateIds.contains(id))
        .toSet();
    final selectable = existingPerks
        .where((id) => candidateIds.contains(id))
        .toList();

    final selections = <int, List<String?>>{};
    for (var index = 0; index < allowances.length; index++) {
      selections[index] = List<String?>.filled(allowances[index].count, null);
    }

    final applied = <String>{};

    for (final perkId in selectable) {
      final component = componentById[perkId.toLowerCase()];
      if (component == null) continue;
      final group = component.data['group']?.toString().trim().toLowerCase();

      for (var index = 0; index < allowances.length; index++) {
        final allowance = allowances[index];
        if (!allowance.allowsGroup(group)) continue;
        final slots = selections[index]!;
        final slotIndex = slots.indexWhere((value) => value == null);
        if (slotIndex == -1) continue;
        slots[slotIndex] = perkId;
        applied.add(perkId);
        break;
      }
    }

    setState(() {
      _perkComponents = sortedPerks;
      _perkAllowances = allowances;
      _perkSelections
        ..clear()
        ..addAll(selections);
      _selectedPerkIds
        ..clear()
        ..addAll(applied);
      _baselinePerkIds
        ..clear()
        ..addAll(baseline);
    });
  }

  Future<void> _prepareLanguageState(Map<String, dynamic>? metadata) async {
    final allowances = _extractLanguageAllowances(metadata);
    if (allowances.isEmpty) {
      if (!mounted) return;
      setState(() {
        _languageComponents = const [];
        _languageAllowances = const [];
        _languageSelections.clear();
        _selectedLanguageIds.clear();
        _baselineLanguageIds
          ..clear()
          ..addAll((_model?.languages ?? const <String>[]));
      });
      return;
    }

    List<Component> allLanguages = const [];
    try {
      allLanguages = await ref.read(componentsByTypeProvider('language').future);
    } catch (_) {
      allLanguages = const [];
    }

    if (!mounted) return;

    final sortedLanguages = allLanguages.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final candidateIdsByAllowance = <int, Set<String>>{};
    final globalCandidateIds = <String>{};
    for (var index = 0; index < allowances.length; index++) {
      final allowance = allowances[index];
      final candidates = sortedLanguages
          .where((language) {
            final type =
                language.data['language_type']?.toString().trim().toLowerCase();
            return allowance.allowsType(type);
          })
          .map((language) => language.id)
          .toSet();
      candidateIdsByAllowance[index] = candidates;
      globalCandidateIds.addAll(candidates);
    }

    final existingLanguages = (_model?.languages ?? const <String>[]).toList();
    final baseline = existingLanguages
        .where((id) => !globalCandidateIds.contains(id))
        .toSet();
    final selectable = existingLanguages
        .where((id) => globalCandidateIds.contains(id))
        .toList();

    final selections = <int, List<String?>>{};
    for (var index = 0; index < allowances.length; index++) {
      selections[index] = List<String?>.filled(allowances[index].count, null);
    }

    final applied = <String>{};
    final componentById = {
      for (final language in sortedLanguages) language.id: language,
    };

    for (final languageId in selectable) {
      final component = componentById[languageId];
      final type =
          component?.data['language_type']?.toString().trim().toLowerCase();
      for (var index = 0; index < allowances.length; index++) {
        final allowance = allowances[index];
        if (!allowance.allowsType(type)) continue;
        final slots = selections[index]!;
        final slotIndex = slots.indexWhere((value) => value == null);
        if (slotIndex == -1) continue;
        slots[slotIndex] = languageId;
        applied.add(languageId);
        break;
      }
    }

    setState(() {
      _languageComponents = sortedLanguages;
      _languageAllowances = allowances;
      _languageSelections
        ..clear()
        ..addAll(selections);
      _selectedLanguageIds
        ..clear()
        ..addAll(applied);
      _baselineLanguageIds
        ..clear()
        ..addAll(baseline);
    });
  }

  String _normalizeAbilityName(String value) => _slugify(value.trim());

  bool _isSignatureAbility(Map<String, dynamic>? ability) {
    if (ability == null) return false;
    final costs = ability['costs'];
    if (costs is Map<String, dynamic>) {
      final signature = costs['signature'];
      if (signature is bool) return signature;
      if (signature is num) return signature != 0;
      if (signature is String) {
        final normalized = signature.trim().toLowerCase();
        if (normalized == 'true') return true;
        if (normalized == 'false') return false;
        return normalized == '1';
      }
    }
    return false;
  }

  int? _abilityCost(Map<String, dynamic> ability) {
    final direct = _toIntOrNull(ability['cost']);
    if (direct != null) return direct;
    final costs = ability['costs'];
    if (costs is Map<String, dynamic>) {
      final amount = _toIntOrNull(costs['amount']);
      if (amount != null) return amount;
    }
    return null;
  }

  int? _toIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      final digits = RegExp(r'^-?\d+').stringMatch(value.trim());
      if (digits != null) {
        return int.tryParse(digits);
      }
    }
    return null;
  }

  void _showLimitSnack(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void _toggleSkillSelection(String skillId) {
    if (_grantedClassSkillIds.contains(skillId)) return;
    final isSelected = _selectedClassSkillIds.contains(skillId);
    String? replacedSkillName;

    setState(() {
      if (isSelected) {
        _selectedClassSkillIds.remove(skillId);
      } else {
        if (_classSkillPickCount > 0) {
          final optionalIds = _selectedClassSkillIds
              .where((id) => !_grantedClassSkillIds.contains(id))
              .toList();
          if (optionalIds.length >= _classSkillPickCount) {
            final removedId = optionalIds.first;
            _selectedClassSkillIds.remove(removedId);
            replacedSkillName = _skillNameById(removedId);
          }
        }
        _selectedClassSkillIds.add(skillId);
      }
      _selectedClassSkillIds.addAll(_grantedClassSkillIds);
    });

    if (!isSelected && replacedSkillName != null) {
      final addedName = _skillNameById(skillId) ?? 'new skill';
      _showLimitSnack('Replaced $replacedSkillName with $addedName.');
    }
    _setDirty(true);
  }

  String? _skillNameById(String skillId) {
    for (final component in _classSkillComponents) {
      if (component.id == skillId) {
        return component.name;
      }
    }
    return null;
  }

  int _selectedOptionalSkillCount() {
    final optional =
        _selectedClassSkillIds.length - _grantedClassSkillIds.length;
    return optional < 0 ? 0 : optional;
  }

  int _remainingSkillChoices() {
    if (_classSkillPickCount <= 0) return 0;
    final remaining = _classSkillPickCount - _selectedOptionalSkillCount();
    return remaining < 0 ? 0 : remaining;
  }

  void _applyQuickBuildSelection(List<String> quickBuild) {
    if (quickBuild.isEmpty || _classSkillComponents.isEmpty) return;

    final orderedSelection = <String>[];
    orderedSelection.addAll(_grantedClassSkillIds);

    final selectedOptional = <String>[];
    for (final name in quickBuild) {
      final id = _resolveSkillComponentId(_classSkillComponents, name);
      if (id == null) continue;
      if (_grantedClassSkillIds.contains(id)) {
        if (!orderedSelection.contains(id)) orderedSelection.add(id);
        continue;
      }
      if (!selectedOptional.contains(id)) selectedOptional.add(id);
    }

    if (_classSkillPickCount > 0 &&
        selectedOptional.length > _classSkillPickCount) {
      selectedOptional.removeRange(
        _classSkillPickCount,
        selectedOptional.length,
      );
    }

    if (_classSkillPickCount > 0 &&
        selectedOptional.length < _classSkillPickCount) {
      final remainingNeeded = _classSkillPickCount - selectedOptional.length;
      final existingOptional = _selectedClassSkillIds
          .where((id) =>
              !_grantedClassSkillIds.contains(id) &&
              !selectedOptional.contains(id))
          .take(remainingNeeded);
      selectedOptional.addAll(existingOptional);
    } else if (_classSkillPickCount <= 0) {
      final existingOptional = _selectedClassSkillIds.where((id) =>
          !_grantedClassSkillIds.contains(id) &&
          !selectedOptional.contains(id));
      selectedOptional.addAll(existingOptional);
    }

    orderedSelection.addAll(selectedOptional);

    setState(() {
      _selectedClassSkillIds
        ..clear()
        ..addAll(orderedSelection)
        ..addAll(_grantedClassSkillIds);
    });

    final appliedNames = orderedSelection
        .where((id) => !_grantedClassSkillIds.contains(id))
        .map(_skillNameById)
        .whereType<String>()
        .toList();
    if (appliedNames.isEmpty) {
      _showLimitSnack('Quick build applied.');
    } else {
      _showLimitSnack('Quick build applied: ${appliedNames.join(', ')}');
    }

    _setDirty(true);
  }

  Widget _buildQuickBuildSection(ThemeData theme, List<String> quickBuild) {
    final accent = StrifeTheme.skillsAccent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
        color: accent.withValues(alpha: 0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick build suggestion',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Apply the recommended skills instantly.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: quickBuild
                .map((skill) => _buildSkillChip(context, skill))
                .toList(),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => _applyQuickBuildSelection(quickBuild),
              icon: const Icon(Icons.flash_on),
              label: const Text('Apply quick build'),
            ),
          ),
        ],
      ),
    );
  }


  String? _abilitySummary(Map<String, dynamic> ability) {
    final parts = <String>[];
    final level = _toIntOrNull(ability['level']);
    if (level != null && level > 0) {
      parts.add('Level $level');
    }
    final action = ability['action_type']?.toString();
    if (action != null && action.isNotEmpty) parts.add(action);
    final cost = _abilityCost(ability);
    if (cost != null && cost > 0) parts.add('Cost: $cost');
    final subclassName = ability['subclass']?.toString();
    if (subclassName != null && subclassName.trim().isNotEmpty) {
      parts.add('Subclass: ${subclassName.trim()}');
    }
    final keywords =
        (ability['keywords'] as List?)?.whereType<String>().toList() ??
            const [];
    if (keywords.isNotEmpty) parts.add('Keywords: ${keywords.join(', ')}');
    final story = ability['story_text']?.toString();
    final summary = parts.join(' • ');
    if ((story ?? '').isEmpty) {
      return summary.isEmpty ? null : summary;
    }
    return summary.isEmpty ? story : '$summary\n$story';
  }

  void _applySelectionsToModel() {
    if (_model == null) return;
    final mergedSkills = _mergeSelections(
        _model!.skills, _baselineSkillIds, _selectedClassSkillIds);
    final mergedAbilities = _mergeSelections(
      _model!.abilities,
      _baselineAbilityIds.union(_autoGrantedAbilityIds),
      _selectedAbilityIds.union(_autoGrantedAbilityIds),
    );
    final mergedPerks = _mergeSelections(
        _model!.perks, _baselinePerkIds, _currentSelectedPerkIds());
    final mergedLanguages = _mergeSelections(
        _model!.languages, _baselineLanguageIds, _currentSelectedLanguageIds());
    _model!
      ..skills = mergedSkills
      ..abilities = mergedAbilities
      ..perks = mergedPerks
      ..languages = mergedLanguages;

    Map<String, int>? finalCharacteristics;
    if (_availableCharacteristicArrays.isEmpty &&
        _fixedStartingCharacteristics.isNotEmpty) {
      finalCharacteristics = Map<String, int>.from(
        _fixedStartingCharacteristics,
      );
    } else if (_hasCompleteCharacteristicAssignments()) {
      finalCharacteristics = _finalCharacteristicScores();
    }

    if (finalCharacteristics != null) {
      _model!
        ..might = finalCharacteristics['might'] ?? _model!.might
        ..agility = finalCharacteristics['agility'] ?? _model!.agility
        ..reason = finalCharacteristics['reason'] ?? _model!.reason
        ..intuition = finalCharacteristics['intuition'] ?? _model!.intuition
        ..presence = finalCharacteristics['presence'] ?? _model!.presence;
    }
  }

  List<String> _mergeSelections(
    List<String> originalOrder,
    Set<String> baseline,
    Set<String> selected,
  ) {
    final result = <String>[];
    final remaining = {...baseline, ...selected};

    for (final id in originalOrder) {
      if (remaining.remove(id)) {
        result.add(id);
      }
    }

    for (final id in selected) {
      if (!result.contains(id)) result.add(id);
    }
    for (final id in baseline) {
      if (!result.contains(id)) result.add(id);
    }
    return result;
  }

  Future<void> _updateLevel(int newLevel) async {
    final level = newLevel.clamp(1, 10);
    if (level == _level) return;
    setState(() {
      _level = level;
    });
    _setDirty(true);
    await _refreshClassData();
  }

  Future<void> _updateClass(String? componentId) async {
    if (componentId == _classComponentId) return;
    setState(() {
      _classComponentId = componentId;
      _classSlug = _slugForClass(componentId);
      _subclassComponentId = null;
    });
    _setDirty(true);
    await _refreshClassData();
  }

  Future<void> _updateSubclass(String? componentId) async {
    if (componentId == _subclassComponentId) return;
    setState(() {
      _subclassComponentId = componentId;
    });
    _setDirty(true);
    await _refreshClassData();
  }

  bool get isDirty => _dirty;

  Future<void> _save() async {
    if (_model == null) return;
    final repo = ref.read(heroRepositoryProvider);
    _model!
      ..level = _level
      ..className = _classComponentId
      ..subclass = _subclassComponentId;
    _applySelectionsToModel();
    await repo.save(_model!);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Strife saved')));
    _setDirty(false);
  }

  Future<void> save() => _save();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return _buildStrifeContent(theme);
  }

  Widget _buildStrifeContent(ThemeData theme) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildLevelCard(theme)),
        SliverToBoxAdapter(child: _buildClassCard(theme)),
        SliverToBoxAdapter(child: _buildSubclassCard(theme)),
        if (_classSlug == null)
          SliverToBoxAdapter(child: _buildSelectClassNotice(theme))
        else if (_classData == null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'We couldn’t load this class’ data yet. Double-check that the seed files exist and try again.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          )
        else ...[
          SliverToBoxAdapter(child: _buildClassIdentityCard(theme)),
          SliverToBoxAdapter(child: _buildStartingStatsCard(theme)),
          SliverToBoxAdapter(child: _buildCharacteristicArraysCard(theme)),
          SliverToBoxAdapter(child: _buildPotencyCard(theme)),
          SliverToBoxAdapter(child: _buildSkillsCard(theme)),
          SliverToBoxAdapter(child: _buildAbilitiesCard(theme)),
          SliverToBoxAdapter(child: _buildPerksCard()),
          SliverToBoxAdapter(child: _buildLanguagesCard()),
          SliverToBoxAdapter(child: _buildFeaturesCard(theme)),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ],
    );
  }

  Widget _buildLevelCard(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        shape:
            const RoundedRectangleBorder(borderRadius: StrifeTheme.cardRadius),
        elevation: StrifeTheme.cardElevation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StrifeTheme.sectionHeader(
              context,
              title: 'Level',
              subtitle: 'Choose the hero level for this class',
              icon: Icons.trending_up,
              accent: StrifeTheme.levelAccent,
            ),
            Padding(
              padding: StrifeTheme.cardPadding,
              child: Row(
                children: [
                  IconButton(
                    onPressed:
                        _level > 1 ? () => _updateLevel(_level - 1) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Level $_level',
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: StrifeTheme.levelAccent,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Slider(
                          value: _level.toDouble(),
                          min: 1,
                          max: 10,
                          divisions: 9,
                          label: '$_level',
                          onChanged: (value) => _updateLevel(value.round()),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed:
                        _level < 10 ? () => _updateLevel(_level + 1) : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassCard(ThemeData theme) {
    final classesAsync = ref.watch(componentsByTypeProvider('class'));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        shape:
            const RoundedRectangleBorder(borderRadius: StrifeTheme.cardRadius),
        elevation: StrifeTheme.cardElevation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StrifeTheme.sectionHeader(
              context,
              title: 'Class',
              subtitle: 'Select one class to determine Strife progression',
              icon: Icons.auto_stories,
              accent: StrifeTheme.classAccent,
            ),
            classesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, st) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to load classes: $e'),
              ),
              data: (classes) {
                final sorted = classes.toList()
                  ..sort((a, b) => a.name.compareTo(b.name));
                return Padding(
                  padding: StrifeTheme.cardPadding,
                  child: DropdownButtonFormField<String?>(
                    value: _classComponentId,
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('— Choose class —')),
                      ...sorted.map(
                        (c) => DropdownMenuItem<String?>(
                          value: c.id,
                          child: Text(c.name),
                        ),
                      ),
                    ],
                    onChanged: _updateClass,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.school_outlined),
                      labelText: 'Class',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubclassCard(ThemeData theme) {
    final classSlug = _classSlug;
    if (classSlug == null || classSlug.isEmpty) {
      return const SizedBox.shrink();
    }

    final subclassesAsync = ref.watch(componentsByTypeProvider('subclass'));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        shape:
            const RoundedRectangleBorder(borderRadius: StrifeTheme.cardRadius),
        elevation: StrifeTheme.cardElevation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StrifeTheme.sectionHeader(
              context,
              title: 'Subclass',
              subtitle:
                  'Choose a specialization to unlock extra skills, features, and abilities.',
              icon: Icons.auto_awesome,
              accent: StrifeTheme.featuresAccent,
            ),
            subclassesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, st) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to load subclasses: $e'),
              ),
              data: (subclasses) {
                final filtered = subclasses
                    .where((component) {
                      final parent = component.data['parent_class']
                          ?.toString()
                          .toLowerCase();
                      return parent == classSlug;
                    })
                    .toList()
                  ..sort((a, b) => a.name.compareTo(b.name));

                if (filtered.isEmpty) {
                  return const SizedBox.shrink();
                }

                final hasSelection = filtered
                    .any((component) => component.id == _subclassComponentId);
                final dropdownValue = hasSelection ? _subclassComponentId : null;

                return Padding(
                  padding: StrifeTheme.cardPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String?>(
                        value: dropdownValue,
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('— Choose subclass —'),
                          ),
                          ...filtered.map(
                            (component) => DropdownMenuItem<String?>(
                              value: component.id,
                              child: Text(component.name),
                            ),
                          ),
                        ],
                        onChanged: _updateSubclass,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.category_outlined),
                          labelText: 'Subclass',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Subclass choices add unique granted skills and unlock extra ability picks as you level up.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectClassNotice(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: StrifeTheme.cardDecoration(context,
            accent: theme.colorScheme.primary),
        child: Column(
          children: [
            Icon(Icons.flash_on, color: theme.colorScheme.primary, size: 40),
            const SizedBox(height: 16),
            Text(
              'Select a class to continue',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Choosing a class unlocks motto, heroic resource, potency guidance, skills, abilities, and level-based features.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassIdentityCard(ThemeData theme) {
    final start = _startingCharacteristics;
    if (start == null) return const SizedBox.shrink();
    final motto = start['motto']?.toString();
    final resourceName = start['heroicResourceName']?.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: StrifeTheme.cardElevation,
        shape:
            const RoundedRectangleBorder(borderRadius: StrifeTheme.cardRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StrifeTheme.sectionHeader(
              context,
              title: 'Class Identity',
              subtitle: 'Narrative hook and signature resource',
              icon: Icons.spa_outlined,
              accent: StrifeTheme.resourceAccent,
            ),
            Padding(
              padding: StrifeTheme.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (motto != null && motto.isNotEmpty) ...[
                    Text(
                      motto,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        color: StrifeTheme.resourceAccent,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (resourceName != null && resourceName.isNotEmpty) ...[
                    Text(
                      'Heroic Resource',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: StrifeTheme.resourceAccent,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.bolt, size: 18),
                        const SizedBox(width: 6),
                        Text(resourceName, style: theme.textTheme.bodyLarge),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Component _abilityAsComponent(Map<String, dynamic> ability) {
    final data = Map<String, dynamic>.from(ability);
    final id = data.remove('id')?.toString() ??
        ability['name']?.toString() ??
        'ability_${data.hashCode}';
    final name = data.remove('name')?.toString() ?? id;
    final type = data.remove('type')?.toString() ?? 'ability';
    return Component(
      id: id,
      type: type,
      name: name,
      data: data,
      source: 'seed',
    );
  }

  void _showAbilityDetails(Map<String, dynamic> ability) {
    final component = _abilityAsComponent(ability);
    final abilityName = component.name;
    final level = _toIntOrNull(ability['level']);
    final subclassName = ability['subclass']?.toString().trim();
    final cost = _abilityCost(ability);
    final isSignature = _isSignatureAbility(ability);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final accent = StrifeTheme.abilitiesAccent;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, controller) {
            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 18, 8, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  abilityName,
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    if (level != null)
                                      _buildAbilityMetaChip(
                                        theme,
                                        label: 'Level $level',
                                        color: accent,
                                        icon: Icons.trending_up,
                                      ),
                                    if (subclassName != null &&
                                        subclassName.isNotEmpty)
                                      _buildAbilityMetaChip(
                                        theme,
                                        label: subclassName,
                                        color: theme.colorScheme.tertiary,
                                        icon: Icons.auto_awesome,
                                      ),
                                    _buildAbilityMetaChip(
                                      theme,
                                      label: isSignature
                                          ? 'Signature'
                                          : 'Cost $cost',
                                      color: isSignature
                                          ? theme.colorScheme.primary
                                          : accent,
                                      icon: isSignature
                                          ? Icons.auto_fix_high
                                          : Icons.flash_on,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: controller,
                        padding: EdgeInsets.zero,
                        child: AbilityFullView(component: component),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStartingStatsCard(ThemeData theme) {
    final start = _startingCharacteristics;
    if (start == null) return const SizedBox.shrink();

    int? readStat(String camel, [String? snake]) {
      if (start.containsKey(camel)) {
        return _toIntOrNull(start[camel]);
      }
      if (snake != null && start.containsKey(snake)) {
        return _toIntOrNull(start[snake]);
      }
      return null;
    }

    final stats = <(String, int?)?>[
      ('Base stamina', readStat('baseStamina', 'base_stamina')),
      ('Stamina per level', readStat('stamina_per_level')),
      ('Base recoveries', readStat('baseRecoveries', 'base_recoveries')),
      ('Base speed', readStat('baseSpeed', 'base_speed')),
      ('Base stability', readStat('baseStability', 'base_stability')),
      ('Base disengage', readStat('baseDisengage', 'base_disengage')),
    ].whereType<(String, int?)>().toList();

    final boosts = _fixedCharacteristicBoosts();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: StrifeTheme.cardElevation,
        shape:
            const RoundedRectangleBorder(borderRadius: StrifeTheme.cardRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StrifeTheme.sectionHeader(
              context,
              title: 'Starting stats',
              subtitle: 'Baseline stamina, defenses, and automatic boosts',
              icon: Icons.favorite_outline,
              accent: StrifeTheme.resourceAccent,
            ),
            Padding(
              padding: StrifeTheme.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: stats
                        .where((entry) => entry.$2 != null)
                        .map((entry) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: StrifeTheme.resourceAccent
                                    .withValues(alpha: 0.08),
                                border: Border.all(
                                  color: StrifeTheme.resourceAccent
                                      .withValues(alpha: 0.28),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    entry.$1,
                                    style:
                                        theme.textTheme.labelSmall?.copyWith(
                                      color: StrifeTheme.resourceAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${entry.$2}',
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                  if (boosts.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Fixed characteristic boosts to apply at level $_level',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: boosts.entries
                          .map((entry) => _buildAbilityMetaChip(
                                theme,
                label:
                  '${_characteristicDisplayName(entry.key)}: +${entry.value}',
                                color: StrifeTheme.resourceAccent,
                                icon: Icons.trending_up,
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacteristicArraysCard(ThemeData theme) {
    final arrays = _availableCharacteristicArrays;
    if (arrays.isEmpty && _fixedStartingCharacteristics.isEmpty) {
      return const SizedBox.shrink();
    }

    final fixed = _fixedStartingCharacteristics;
    final selectedIndex = _selectedCharacteristicArrayIndex;
    final assignments = _characteristicArrayAssignments;
    final accent = StrifeTheme.classAccent;

    final arrayOptions = arrays.isEmpty
        ? <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: theme.colorScheme.surfaceVariant
                    .withValues(alpha: 0.18),
              ),
              child: Text(
                'This class does not define characteristic arrays.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ]
        : arrays.asMap().entries.map((entry) {
            final index = entry.key;
            final array = entry.value;
            final valueLabels = _characteristicArrayValues(array)
                .map((value) => value >= 0 ? '+$value' : '$value')
                .toList();
            final description = array['description']?.toString();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: RadioListTile<int>(
                value: index,
                groupValue: selectedIndex,
                onChanged: (arrays.isEmpty)
                    ? null
                    : (value) {
                        if (value != null) {
                          _selectCharacteristicArray(value);
                        }
                      },
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: accent,
                title: Text(
                  valueLabels.isEmpty
                      ? 'Custom array ${index + 1}'
                      : valueLabels.join(' · '),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
                subtitle: description == null || description.isEmpty
                    ? null
                    : Text(
                        description,
                        style: theme.textTheme.bodySmall,
                      ),
              ),
            );
          }).toList();

    final characteristicRows = <Widget>[];
    for (final key in _characteristicKeys) {
      final displayName = _characteristicDisplayName(key);
      final fixedValue = fixed[key];
      final assignedValue = assignments[key];
      final total = (fixedValue ?? 0) + (assignedValue ?? 0);
      final isFixed = fixedValue != null;
      final availableValues = _availableValuesForCharacteristic(key);

      if (isFixed) {
  final fixedLabel = fixedValue >= 0 ? '+$fixedValue' : '$fixedValue';
        final totalLabel = total >= 0 ? '+$total' : '$total';
        characteristicRows.add(
          _buildFixedCharacteristicRow(
            theme,
            name: displayName,
            valueLabel: 'Fixed bonus $fixedLabel',
            totalLabel: 'Total: $totalLabel',
            accent: accent,
          ),
        );
        continue;
      }

      characteristicRows.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayName,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<int?>(
              value: assignedValue,
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('— Choose value —'),
                ),
                ...availableValues.map(
                  (value) => DropdownMenuItem<int?>(
                    value: value,
                    child: Text(value >= 0 ? '+$value' : '$value'),
                  ),
                ),
              ],
              onChanged: (selectedIndex == null)
                  ? null
                  : (value) => _updateCharacteristicAssignment(key, value),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.tune),
                labelText: 'Assign value',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Total: ${total >= 0 ? '+$total' : '$total'}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    final assignmentsComplete = _hasCompleteCharacteristicAssignments();
    final summaryChips = assignmentsComplete
        ? _finalCharacteristicScores().entries.map((entry) {
            final total = entry.value;
            return _buildAbilityMetaChip(
              theme,
              label:
                  '${_characteristicDisplayName(entry.key)}: ${total >= 0 ? '+$total' : '$total'}',
              color: accent,
              icon: Icons.check_circle_outline,
            );
          }).toList()
        : const <Widget>[];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: StrifeTheme.cardElevation,
        shape:
            const RoundedRectangleBorder(borderRadius: StrifeTheme.cardRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StrifeTheme.sectionHeader(
              context,
              title: 'Characteristic arrays',
              subtitle: arrays.isEmpty
                  ? 'Fixed bonuses only for this class.'
                  : 'Choose an array and assign each value to a free characteristic.',
              icon: Icons.view_module,
              accent: accent,
            ),
            Padding(
              padding: StrifeTheme.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...arrayOptions,
                  const SizedBox(height: 16),
                  if (arrays.isNotEmpty)
                    Text(
                      'Assignments',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (arrays.isEmpty)
                    Text(
                      'All characteristics are fixed by this class.',
                      style: theme.textTheme.bodyMedium,
                    )
                  else ...[
                    const SizedBox(height: 12),
                    if (selectedIndex == null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Select an array above to start assigning values.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    for (var i = 0; i < characteristicRows.length; i++) ...[
                      characteristicRows[i],
                      if (i < characteristicRows.length - 1)
                        const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      assignmentsComplete
                          ? 'All characteristic slots assigned.'
                          : 'Assign each value to finish setting up starting characteristics.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (summaryChips.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: summaryChips,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPotencyCard(ThemeData theme) {
    final progression =
        _startingCharacteristics?['potency_progression'] as Map?;
    if (progression == null || progression.isEmpty) {
      return const SizedBox.shrink();
    }

    final entries = progression.entries
        .where((entry) => entry.value != null)
        .map((entry) => MapEntry(
            entry.key.toString().capitalize(), entry.value.toString()))
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: StrifeTheme.cardElevation,
        shape:
            const RoundedRectangleBorder(borderRadius: StrifeTheme.cardRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StrifeTheme.sectionHeader(
              context,
              title: 'Potency guidance',
              subtitle: 'Recommended characteristic scores for power rolls',
              icon: Icons.auto_graph,
              accent: StrifeTheme.potencyAccent,
            ),
            Padding(
              padding: StrifeTheme.cardPadding,
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: entries
                    .map(
                      (entry) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: StrifeTheme.potencyAccent
                              .withValues(alpha: 0.08),
                          border: Border.all(
                            color: StrifeTheme.potencyAccent
                                .withValues(alpha: 0.28),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              entry.key,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: StrifeTheme.potencyAccent,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              entry.value,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillsCard(ThemeData theme) {
    if (_classSkillComponents.isEmpty &&
        _grantedClassSkillIds.isEmpty &&
        _classSkillPickCount == 0) {
      return const SizedBox.shrink();
    }

    final start = _startingCharacteristics;
    final skillsInfo = start?['starting_skills'];
    List<String> quickBuild = const [];
    if (skillsInfo is Map<String, dynamic>) {
      final raw = skillsInfo['quick_build'] ?? skillsInfo['quickBuild'];
      if (raw is List) {
        quickBuild = raw
            .whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
      }
    }

    final groups = _classSkillGroups;
    final remaining = _remainingSkillChoices();
    final optionalSelected = _selectedOptionalSkillCount();
    final grantedNames = _classSkillComponents
        .where((component) => _grantedClassSkillIds.contains(component.id))
        .map((component) => component.name)
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: StrifeTheme.cardElevation,
        shape:
            const RoundedRectangleBorder(borderRadius: StrifeTheme.cardRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StrifeTheme.sectionHeader(
              context,
              title: 'Starting skills',
              subtitle: _classSkillPickCount <= 0
                  ? 'Automatically granted based on class'
                  : 'Select $_classSkillPickCount skill${_classSkillPickCount == 1 ? '' : 's'} from the class list',
              icon: Icons.psychology_alt,
              accent: StrifeTheme.skillsAccent,
            ),
            Padding(
              padding: StrifeTheme.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle,
                          size: 18, color: StrifeTheme.skillsAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _classSkillPickCount <= 0
                              ? 'All listed skills are granted automatically.'
                              : '$optionalSelected of $_classSkillPickCount optional picks selected. ${remaining > 0 ? '$remaining remaining.' : 'All picks used.'}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  if (groups.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    if (groups.length == 1 &&
                        groups.first.toLowerCase() == 'any')
                      Text(
                        'You can choose skills from any group.',
                        style: theme.textTheme.bodyMedium,
                      )
                    else ...[
                      Text(
                        'Eligible skill groups',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: groups
                            .map((group) => Chip(
                                  label: Text(group.capitalize()),
                                  avatar: const Icon(Icons.folder_shared,
                                      size: 16),
                                  backgroundColor: StrifeTheme.skillsAccent
                                      .withValues(alpha: 0.1),
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                  if (quickBuild.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildQuickBuildSection(theme, quickBuild),
                  ],
                  const SizedBox(height: 16),
                  if (_classSkillComponents.isEmpty)
                    Text(
                      'No selectable skills found for this class yet.',
                      style: theme.textTheme.bodyMedium,
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 12,
                      children: _classSkillComponents.map((component) {
                        final selected =
                            _selectedClassSkillIds.contains(component.id);
                        final locked =
                            _grantedClassSkillIds.contains(component.id);
                        return _buildSkillChip(
                          context,
                          component.name,
                          selected: selected,
                          locked: locked,
                          onTap: () => _toggleSkillSelection(component.id),
                        );
                      }).toList(),
                    ),
                  if (grantedNames.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lock, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Granted automatically: ${grantedNames.join(', ')}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAbilitiesCard(ThemeData theme) {
    final hasAbilityData = _classAbilityData.isNotEmpty ||
        _autoGrantedAbilityIds.isNotEmpty ||
        _baselineAbilityIds.isNotEmpty;
    if (!hasAbilityData) {
      return const SizedBox.shrink();
    }

    return ClassAbilitiesWidget(
      level: _level,
      classMetadata: _classData,
      abilities: _classAbilityData,
      abilityDetailsById: _abilityDetailsById,
      selectedAbilityIds: _selectedAbilityIds,
      autoGrantedAbilityIds: _autoGrantedAbilityIds,
      baselineAbilityIds: _baselineAbilityIds,
      activeSubclassSlugs: _activeSubclassSlugs,
      subclassLabel: _selectedSubclassDisplayName,
      onSelectionChanged: _updateAbilitySelections,
      abilitySummaryBuilder: _abilitySummary,
      onAbilityPreviewRequested: _showAbilityDetails,
    );
  }

  Widget _buildFeaturesCard(ThemeData theme) {
    if (_classFeatures.isEmpty) return const SizedBox.shrink();

    return ClassFeaturesWidget(
      level: _level,
      classMetadata: _classData,
      features: _classFeatures,
      featureDetailsById: _classFeatureDetailsById,
      selectedOptions: _featureOptionSelections,
      onSelectionChanged: _updateFeatureSelection,
      abilityDetailsById: _abilityDetailsById,
      abilityIdByName: _abilityIdByName,
      onAbilityPreviewRequested: _showAbilityDetails,
      activeSubclassSlugs: _activeSubclassSlugs,
      subclassLabel: _selectedSubclassDisplayName,
    );
  }

  Widget _buildPerksCard() {
    if (_perkAllowances.isEmpty) return const SizedBox.shrink();

    final selections = <int, List<String?>>{};
    for (var index = 0; index < _perkAllowances.length; index++) {
      final allowance = _perkAllowances[index];
      final existing = _perkSelections[index];
      if (existing != null && existing.length == allowance.count) {
        selections[index] = List<String?>.from(existing);
      } else {
        final slots = List<String?>.filled(allowance.count, null);
        if (existing != null) {
          for (var slot = 0; slot < allowance.count && slot < existing.length; slot++) {
            slots[slot] = existing[slot];
          }
        }
        selections[index] = slots;
      }
    }

    return PerkPickerCard(
      allowances: _perkAllowances,
      perkComponents: _perkComponents,
      selections: selections,
      onSelectionChanged: _updatePerkSelection,
    );
  }

  Widget _buildLanguagesCard() {
    if (_languageAllowances.isEmpty) return const SizedBox.shrink();

    final selections = <int, List<String?>>{};
    for (var index = 0; index < _languageAllowances.length; index++) {
      final allowance = _languageAllowances[index];
      final existing = _languageSelections[index];
      if (existing != null && existing.length == allowance.count) {
        selections[index] = List<String?>.from(existing);
      } else {
        final slots = List<String?>.filled(allowance.count, null);
        if (existing != null) {
          for (var slot = 0; slot < allowance.count && slot < existing.length; slot++) {
            slots[slot] = existing[slot];
          }
        }
        selections[index] = slots;
      }
    }

    return LanguagePickerCard(
      allowances: _languageAllowances,
      languageComponents: _languageComponents,
      selections: selections,
      onSelectionChanged: _updateLanguageSelection,
    );
  }

  Widget _buildSkillChip(
    BuildContext context,
    String label, {
    bool selected = false,
    bool locked = false,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final accent = StrifeTheme.skillsAccent;
    final enabled = onTap != null && !locked;

    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: enabled ? (_) => onTap() : null,
      avatar: locked
          ? Icon(Icons.lock, size: 16, color: accent.withValues(alpha: 0.8))
          : null,
      showCheckmark: selected,
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        color: enabled
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSurfaceVariant,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      backgroundColor:
          theme.colorScheme.surfaceVariant.withValues(alpha: 0.4),
      selectedColor: accent.withValues(alpha: 0.35),
      disabledColor: theme.colorScheme.surfaceVariant.withValues(alpha: 0.1),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildAbilityMetaChip(
    ThemeData theme, {
    required String label,
    required Color color,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFixedCharacteristicRow(
    ThemeData theme, {
    required String name,
    required String valueLabel,
    required String totalLabel,
    required Color accent,
    IconData icon = Icons.lock,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: accent.withValues(alpha: 0.08),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  valueLabel,
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  totalLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension _Capitalize on String {
  String capitalize() {
    if (isEmpty) return this;
    return substring(0, 1).toUpperCase() + substring(1);
  }
}
