import 'dart:convert';

import 'package:collection/collection.dart';
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
import '../../widgets/pickers/deity_domain_picker.dart';

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

const List<String> _allSkillGroups = <String>[
  'crafting',
  'exploration',
  'interpersonal',
  'intrigue',
  'lore',
];

enum _CreatorSection {
  level,
  classSelection,
  subclass,
  basics,
  characteristics,
  skills,
  perks,
  abilities,
  languages,
  deityDomains,
  features,
}

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
  List<_CharacteristicValueToken> _characteristicTokens = const [];
  Map<String, _CharacteristicValueToken?> _characteristicArrayAssignments =
      <String, _CharacteristicValueToken?>{};

  // Class skill selection state
  int _classSkillPickCount = 0;

  final Set<String> _grantedClassSkillIds = <String>{};
  final Set<String> _classSkillCandidateIds = <String>{};
  final Set<String> _selectedClassSkillIds = <String>{};
  // Track skill selections per allowance level and pick index
  final Map<int, Map<int, String?>> _allowanceSkillSelections = {};
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
  List<Component> _deityComponents = const [];
  final Map<String, String> _domainNameBySlug = <String, String>{};
  final Map<String, Set<String>> _domainSlugsByDeityId =
      <String, Set<String>>{};
  Set<String> _availableDomainSlugs = const <String>{};
  final Set<String> _domainLinkedFeatureIds = <String>{};
  int _requiredDeityCount = 0;
  int _requiredDomainCount = 0;
  String? _selectedDeityId;
  Set<String> _selectedDomainSlugs = <String>{};
  Map<String, String> _selectedDomainSkills = <String, String>{};
  Map<String, List<String>> _skillsByGroup = <String, List<String>>{};
  Map<String, Map<String, dynamic>> _domainFeatureData =
      <String, Map<String, dynamic>>{};
  final Map<_CreatorSection, bool> _expandedSections = {
    for (final section in _CreatorSection.values) section: true,
  };

  List<_SkillAllowance> _skillAllowances = const [];

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
      final heroDeity = hero?.deityId?.trim();
      _selectedDeityId =
          (heroDeity == null || heroDeity.isEmpty) ? null : heroDeity;
      final heroDomain = hero?.domain?.trim();
      _selectedDomainSlugs = (heroDomain == null || heroDomain.isEmpty)
          ? <String>{}
          : {_slugify(heroDomain)};
      // TODO: Load domain skills from hero data when persistence is updated
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
    final deityDomainState = await _loadDeityDomainState(metadata, featureMaps);
    final abilities = await _loadClassAbilities(slug);
    await _prepareSkillState(metadata);
    _prepareCharacteristicState(metadata);
    _prepareAbilityData(abilities);
    await _preparePerkState(metadata);
    await _prepareLanguageState(metadata);
    await _prepareSkillsData();
    await _prepareDomainFeatureData(features);
    if (!mounted) return;
    final featureDetailsById = <String, Map<String, dynamic>>{};
    for (final entry in featureMaps) {
      final id = entry['id']?.toString();
      if (id == null || id.isEmpty) continue;
      featureDetailsById[id] = entry;
    }
    final domainLinkedFeatureIds =
        _identifyDomainLinkedFeatures(featureDetailsById);
    final filteredFeatureSelections = <String, Set<String>>{};
    for (final feature in features) {
      final existing = _featureOptionSelections[feature.id];
      if (existing != null && existing.isNotEmpty) {
        filteredFeatureSelections[feature.id] = existing.toSet();
      }
    }

    final validatedDeityId =
        _validateDeityId(_selectedDeityId, deityDomainState.deities);
    final validatedDomainSlugs = _validateDomainSlugs(
      _selectedDomainSlugs,
      validatedDeityId,
      deityDomainState.availableDomainSlugs,
      deityDomainState.domainSlugsByDeityId,
      _requiredDomainCount,
    );

    final nextFeatureSelections =
        Map<String, Set<String>>.from(filteredFeatureSelections);
    _applyDomainSelectionToFeatures(
      nextFeatureSelections,
      featureDetailsById,
      domainLinkedFeatureIds,
      validatedDomainSlugs,
    );

    setState(() {
      _classData = metadata;
      _classFeatures = features;
      _classFeatureDetailsById
        ..clear()
        ..addAll(featureDetailsById);
      _featureOptionSelections
        ..clear()
        ..addAll(nextFeatureSelections);
      _domainLinkedFeatureIds
        ..clear()
        ..addAll(domainLinkedFeatureIds);
      _deityComponents = deityDomainState.deities.toList(growable: false);
      _domainNameBySlug
        ..clear()
        ..addAll(deityDomainState.domainNameBySlug);
      _domainSlugsByDeityId
        ..clear()
        ..addAll({
          for (final entry in deityDomainState.domainSlugsByDeityId.entries)
            entry.key: entry.value.toSet(),
        });
      _availableDomainSlugs =
          Set<String>.from(deityDomainState.availableDomainSlugs);
      _requiredDeityCount = deityDomainState.deityPickCount;
      _requiredDomainCount = deityDomainState.domainPickCount;
      _selectedDeityId = validatedDeityId;
      _selectedDomainSlugs = validatedDomainSlugs;
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
        return (a['name'] ?? '')
            .toString()
            .compareTo((b['name'] ?? '').toString());
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
    final normalized =
        value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
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
    Map<String, dynamic>? metadata,
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

      final remaining = <int, int>{};
      for (final value in values) {
        remaining[value] = (remaining[value] ?? 0) + 1;
      }
      final currentAssignments = <String, int>{};

      bool search(int keyIndex) {
        if (keyIndex >= freeKeys.length) {
          final baseTotals = <String, int>{
            for (final key in _characteristicKeys) key: fixed[key] ?? 0,
          };
          currentAssignments.forEach((key, value) {
            baseTotals[key] = (baseTotals[key] ?? 0) + value;
          });
          final result = _applyLevelCharacteristicAdjustments(baseTotals,
              metadata: metadata);
          final totals = result.totals;
          for (final key in _characteristicKeys) {
            final statValue = heroStats[key];
            if (statValue == null || totals[key] != statValue) {
              return false;
            }
          }
          return true;
        }

        final key = freeKeys[keyIndex];
        final candidates = remaining.entries
            .where((entry) => entry.value > 0)
            .map((entry) => entry.key)
            .toList();
        for (final value in candidates) {
          final count = remaining[value] ?? 0;
          if (count <= 0) continue;
          remaining[value] = count - 1;
          currentAssignments[key] = value;
          final matched = search(keyIndex + 1);
          if (matched) {
            return true;
          }
          currentAssignments.remove(key);
          remaining[value] = count;
        }
        return false;
      }

      if (search(0)) {
        final resolved = <String, int?>{
          for (final key in _characteristicKeys) key: null,
        };
        currentAssignments.forEach((key, value) {
          resolved[key] = value;
        });
        return (arrayIndex: index, assignments: resolved);
      }
    }

    return null;
  }

  void _prepareCharacteristicState(Map<String, dynamic>? metadata) {
    final fixed = _extractFixedStartingCharacteristics(metadata);
    final arrays = _extractCharacteristicArraysFromMetadata(metadata);

    final inferredAssignments = <String, int?>{
      for (final key in _characteristicKeys) key: null,
    };

    int? selectedIndex;
    if (_model != null) {
      final inferred = _inferCharacteristicAssignmentsFromHero(
        _model!,
        fixed,
        arrays,
        metadata,
      );
      if (inferred != null) {
        selectedIndex = inferred.arrayIndex;
        inferredAssignments.addAll(inferred.assignments);
      }
    }

    if (selectedIndex == null && arrays.length == 1) {
      selectedIndex = 0;
    }

    var tokens = const <_CharacteristicValueToken>[];
    final assignments = <String, _CharacteristicValueToken?>{
      for (final key in _characteristicKeys) key: null,
    };

    if (selectedIndex != null &&
        selectedIndex >= 0 &&
        selectedIndex < arrays.length) {
      final values = _characteristicArrayValues(arrays[selectedIndex]);
      tokens = _buildTokensForValues(values);
      final availableTokens = tokens.toList(growable: true);
      for (final entry in inferredAssignments.entries) {
        final key = entry.key;
        final value = entry.value;
        if (value == null) continue;
        if (fixed.containsKey(key)) continue;
        final tokenIndex =
            availableTokens.indexWhere((token) => token.value == value);
        if (tokenIndex == -1) continue;
        final token = availableTokens.removeAt(tokenIndex);
        assignments[key] = token;
      }
    }

    if (!mounted) return;
    setState(() {
      _fixedStartingCharacteristics = fixed;
      _availableCharacteristicArrays = arrays;
      _selectedCharacteristicArrayIndex = selectedIndex;
      _characteristicTokens = tokens;
      _characteristicArrayAssignments = assignments;
    });
  }

  List<_CharacteristicValueToken> _buildTokensForValues(List<int> values) {
    final tokens = <_CharacteristicValueToken>[];
    for (var i = 0; i < values.length; i++) {
      tokens.add(_CharacteristicValueToken(id: i, value: values[i]));
    }
    return tokens;
  }

  void _selectCharacteristicArray(int index) {
    if (index < 0 || index >= _availableCharacteristicArrays.length) return;
    if (_selectedCharacteristicArrayIndex == index) return;
    final values = _characteristicArrayValues(
      _availableCharacteristicArrays[index],
    );
    final tokens = _buildTokensForValues(values);
    final assignments = <String, _CharacteristicValueToken?>{
      for (final key in _characteristicKeys) key: null,
    };
    setState(() {
      _selectedCharacteristicArrayIndex = index;
      _characteristicTokens = tokens;
      _characteristicArrayAssignments = assignments;
    });
    _setDirty(true);
  }

  List<_CharacteristicValueToken> get _unassignedCharacteristicTokens {
    final assignedIds = _characteristicArrayAssignments.values
        .whereType<_CharacteristicValueToken>()
        .map((token) => token.id)
        .toSet();
    return _characteristicTokens
        .where((token) => !assignedIds.contains(token.id))
        .toList(growable: false);
  }

  void _assignCharacteristicValue(
    String key,
    _CharacteristicValueToken token,
  ) {
    final normalizedKey = _normalizeCharacteristicKey(key) ?? key;
    if (_fixedStartingCharacteristics.containsKey(normalizedKey)) return;
    if (!_characteristicArrayAssignments.containsKey(normalizedKey)) return;
    final updated = Map<String, _CharacteristicValueToken?>.from(
        _characteristicArrayAssignments);
    var changed = false;
    for (final entry in updated.entries) {
      if (entry.value?.id == token.id) {
        if (entry.key == normalizedKey) {
          // Token already assigned to this slot; nothing to update.
          return;
        }
        updated[entry.key] = null;
        changed = true;
      }
    }
    if (updated[normalizedKey]?.id != token.id) {
      updated[normalizedKey] = token;
      changed = true;
    }
    if (!changed) return;
    setState(() {
      _characteristicArrayAssignments = updated;
    });
    _setDirty(true);
  }

  void _unassignCharacteristicValue(_CharacteristicValueToken token) {
    final updated = Map<String, _CharacteristicValueToken?>.from(
        _characteristicArrayAssignments);
    var changed = false;
    for (final entry in updated.entries) {
      if (entry.value?.id == token.id) {
        updated[entry.key] = null;
        changed = true;
      }
    }
    if (!changed) return;
    setState(() {
      _characteristicArrayAssignments = updated;
    });
    _setDirty(true);
  }

  void _clearCharacteristicAssignment(String key) {
    final normalizedKey = _normalizeCharacteristicKey(key) ?? key;
    if (!_characteristicArrayAssignments.containsKey(normalizedKey)) return;
    if (_characteristicArrayAssignments[normalizedKey] == null) return;
    final updated = Map<String, _CharacteristicValueToken?>.from(
        _characteristicArrayAssignments);
    updated[normalizedKey] = null;
    setState(() {
      _characteristicArrayAssignments = updated;
    });
    _setDirty(true);
  }

  Widget _buildAvailableTokensSection(
    ThemeData theme, {
    required List<_CharacteristicValueToken> tokens,
    required bool enabled,
    String? description,
  }) {
    final accent = StrifeTheme.classAccent;
    return DragTarget<_CharacteristicValueToken>(
      onWillAcceptWithDetails: (_) => enabled,
      onAcceptWithDetails: enabled
          ? (details) => _unassignCharacteristicValue(details.data)
          : null,
      builder: (context, candidate, rejected) {
        final isActive = candidate.isNotEmpty && enabled;
        final background = !enabled
            ? theme.colorScheme.surfaceVariant.withValues(alpha: 0.08)
            : isActive
                ? accent.withValues(alpha: 0.18)
                : theme.colorScheme.surfaceVariant.withValues(alpha: 0.12);
        final borderColor = !enabled
            ? theme.colorScheme.outline.withValues(alpha: 0.24)
            : accent.withValues(alpha: isActive ? 0.7 : 0.4);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.3),
            color: background,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available values',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: enabled ? accent : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              if (!enabled) ...[
                Text(
                  'Select an array above to unlock these values.',
                  style: theme.textTheme.bodySmall,
                ),
              ] else ...[
                if (description != null && description.isNotEmpty) ...[
                  Text(
                    description,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                ],
                if (tokens.isEmpty) ...[
                  Text(
                    'All values assigned. Drag a chip here to clear it.',
                    style: theme.textTheme.bodySmall,
                  ),
                ] else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tokens
                        .map((token) => _buildDraggableTokenChip(theme, token))
                        .toList(),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTokenChip(
    ThemeData theme,
    _CharacteristicValueToken token, {
    bool filled = false,
    bool isFeedback = false,
  }) {
    final accent = StrifeTheme.classAccent;
    final background = filled ? accent : accent.withValues(alpha: 0.12);
    final borderColor = accent.withValues(alpha: filled ? 0.9 : 0.45);
    final textColor = filled ? theme.colorScheme.onPrimary : accent;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: background,
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: isFeedback
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.35),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : const [],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          _formatSignedValue(token.value),
          style: theme.textTheme.labelLarge?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableTokenChip(
    ThemeData theme,
    _CharacteristicValueToken token,
  ) {
    final chip = _buildTokenChip(theme, token);
    return LongPressDraggable<_CharacteristicValueToken>(
      data: token,
      feedback: Material(
        color: Colors.transparent,
        child: _buildTokenChip(theme, token, filled: true, isFeedback: true),
      ),
      childWhenDragging: Opacity(
        opacity: 0.25,
        child: chip,
      ),
      child: chip,
    );
  }

  Widget _buildAssignedTokenChip(
    ThemeData theme,
    _CharacteristicValueToken token,
  ) {
    final chip = _buildTokenChip(theme, token, filled: true);
    return LongPressDraggable<_CharacteristicValueToken>(
      data: token,
      feedback: Material(
        color: Colors.transparent,
        child: _buildTokenChip(theme, token, filled: true, isFeedback: true),
      ),
      childWhenDragging: Opacity(
        opacity: 0.25,
        child: chip,
      ),
      child: chip,
    );
  }

  Widget _buildTokenPreviewChip(ThemeData theme, int value) {
    final accent = StrifeTheme.classAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: accent.withValues(alpha: 0.08),
        border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.1),
      ),
      child: Text(
        _formatSignedValue(value),
        style: theme.textTheme.labelMedium?.copyWith(
          color: accent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatSignedValue(int value) {
    return value >= 0 ? '+$value' : '$value';
  }

  bool _hasCompleteCharacteristicAssignments() {
    if (_availableCharacteristicArrays.isEmpty) {
      return true;
    }
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

  Map<String, int> _baseCharacteristicTotals() {
    final totals = <String, int>{};
    for (final key in _characteristicKeys) {
      final base = _fixedStartingCharacteristics[key] ?? 0;
      final assignment = _characteristicArrayAssignments[key]?.value ?? 0;
      totals[key] = base + assignment;
    }
    return totals;
  }

  int _applySingleCharacteristicAdjustment(int current, dynamic data) {
    if (data is Map) {
      final map = data.cast<String, dynamic>();
      var value = current;
      final increase = _toIntOrNull(map['increaseBy'] ?? map['increase_by']);
      if (increase != null) {
        value += increase;
      }
      final setTo = _toIntOrNull(map['setTo'] ?? map['set_to']);
      if (setTo != null && value < setTo) {
        value = setTo;
      }
      final maxValue = _toIntOrNull(map['max']);
      if (maxValue != null && value > maxValue) {
        value = maxValue;
      }
      return value;
    }
    if (data is num) {
      return current + data.toInt();
    }
    return current;
  }

  ({Map<String, int> totals, Map<String, int> bonuses})
      _applyLevelCharacteristicAdjustments(
    Map<String, int> baseTotals, {
    Map<String, dynamic>? metadata,
  }) {
    final totals = Map<String, int>.from(baseTotals);
    final bonuses = <String, int>{
      for (final key in _characteristicKeys) key: 0,
    };
    final sourceMetadata = metadata ?? _classData;
    for (final level in _levelsUpToCurrentFromMetadata(sourceMetadata)) {
      final adjustments = level['characteristics'];
      if (adjustments is! List) continue;
      for (final adjustment in adjustments) {
        if (adjustment is! Map) continue;
        for (final entry in adjustment.entries) {
          final normalizedKey =
              _normalizeCharacteristicKey(entry.key?.toString());
          if (normalizedKey == null) continue;
          final targets = normalizedKey == 'all'
              ? _characteristicKeys
              : <String>[normalizedKey];
          for (final target in targets) {
            final before = totals[target] ?? 0;
            final after =
                _applySingleCharacteristicAdjustment(before, entry.value);
            totals[target] = after;
            final delta = after - before;
            if (delta > 0) {
              bonuses[target] = (bonuses[target] ?? 0) + delta;
            }
          }
        }
      }
    }
    return (totals: totals, bonuses: bonuses);
  }

  Map<String, int> _finalCharacteristicScores() {
    final baseTotals = _baseCharacteristicTotals();
    final applied = _applyLevelCharacteristicAdjustments(baseTotals);
    return applied.totals;
  }

  List<Component> _eligiblePerksForAllowance(int allowanceIndex) {
    if (allowanceIndex < 0 || allowanceIndex >= _perkAllowances.length) {
      return const [];
    }
    final allowance = _perkAllowances[allowanceIndex];
    return _perkComponents.where((component) {
      final group = component.data['group']?.toString().trim().toLowerCase();
      return allowance.allowsGroup(group);
    }).toList();
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
    final resolvedId =
        normalizedId != null && eligibleIds.contains(normalizedId)
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
    final resolvedId =
        normalizedId != null && eligibleIds.contains(normalizedId)
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
          label: 'Level $levelNumber - $labelGroups',
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
            label: 'Level $levelNumber - any group',
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
          label: 'Level $levelNumber - $labelTypes',
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
            label: 'Level $levelNumber - any type',
          ));
        }
      }
    }
    return allowances;
  }

  _FaithRequirements _countFaithRequirements(Map<String, dynamic>? metadata) {
    var deityCount = 0;
    var domainCount = 0;
    for (final levelEntry in _levelsUpToCurrentFromMetadata(metadata)) {
      final features = levelEntry['features'];
      if (features is! List) continue;
      for (final entry in features) {
        if (entry is! Map<String, dynamic>) continue;
        final deityValue = _toIntOrNull(entry['deity']);
        if (deityValue != null && deityValue > 0) {
          deityCount += deityValue;
        }
        final domainValue = _toIntOrNull(entry['domain']);
        if (domainValue != null && domainValue > 0) {
          domainCount += domainValue;
        }
      }
    }
    return _FaithRequirements(deityCount: deityCount, domainCount: domainCount);
  }

  Future<_DeityDomainState> _loadDeityDomainState(
    Map<String, dynamic>? metadata,
    List<Map<String, dynamic>> featureMaps,
  ) async {
    final requirements = _countFaithRequirements(metadata);
    final domainNamesFromFeatures =
        _extractDomainNamesFromFeatureMaps(featureMaps);
    final needsFaith =
        requirements.hasRequirements || domainNamesFromFeatures.isNotEmpty;

    List<Component> deities = const [];
    if (needsFaith) {
      try {
        deities = await ref.read(componentsByTypeProvider('deity').future);
      } catch (_) {
        deities = const [];
      }
    }

    final sortedDeities = deities.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final domainNameBySlug = <String, String>{}
      ..addAll(domainNamesFromFeatures);
    final domainSlugsByDeityId = <String, Set<String>>{};

    for (final deity in sortedDeities) {
      final domains = (deity.data['domains'] as List?)
              ?.map((entry) => entry.toString())
              .toList() ??
          const <String>[];
      final slugSet = <String>{};
      for (final domain in domains) {
        final trimmed = domain.trim();
        if (trimmed.isEmpty) continue;
        final slug = _slugify(trimmed);
        slugSet.add(slug);
        domainNameBySlug.putIfAbsent(slug, () => trimmed);
      }
      domainSlugsByDeityId[deity.id] = slugSet;
      domainSlugsByDeityId[deity.id.toLowerCase()] = slugSet;
    }

    final allDeityDomainSlugs = domainSlugsByDeityId.values.fold<Set<String>>(
      <String>{},
      (acc, set) => acc..addAll(set),
    );

    Set<String> availableDomainSlugs;
    if (domainNamesFromFeatures.isNotEmpty) {
      availableDomainSlugs = allDeityDomainSlugs.isEmpty
          ? domainNamesFromFeatures.keys.toSet()
          : domainNamesFromFeatures.keys
              .where(allDeityDomainSlugs.contains)
              .toSet();
    } else {
      availableDomainSlugs = allDeityDomainSlugs;
    }

    return _DeityDomainState(
      deities: sortedDeities,
      domainNameBySlug: domainNameBySlug,
      domainSlugsByDeityId: domainSlugsByDeityId,
      availableDomainSlugs: availableDomainSlugs,
      deityPickCount: requirements.deityCount,
      domainPickCount: requirements.domainCount,
    );
  }

  Map<String, String> _extractDomainNamesFromFeatureMaps(
    List<Map<String, dynamic>> featureMaps,
  ) {
    final result = <String, String>{};
    for (final feature in featureMaps) {
      final options = feature['options'];
      if (options is! List) continue;
      for (final option in options) {
        if (option is! Map<String, dynamic>) continue;
        final domainName = option['domain']?.toString().trim();
        if (domainName == null || domainName.isEmpty) continue;
        final slug = _slugify(domainName);
        result.putIfAbsent(slug, () => domainName);
      }
    }
    return result;
  }

  Set<String> _identifyDomainLinkedFeatures(
    Map<String, Map<String, dynamic>> featureDetailsById,
  ) {
    final ids = <String>{};
    featureDetailsById.forEach((featureId, details) {
      final options = details['options'];
      if (options is! List) return;
      final hasDomain = options.any((option) {
        if (option is! Map<String, dynamic>) return false;
        final domainName = option['domain']?.toString().trim();
        return domainName != null && domainName.isNotEmpty;
      });
      if (hasDomain) ids.add(featureId);
    });
    return ids;
  }

  String? _validateDeityId(String? currentId, List<Component> deities) {
    if (currentId == null || currentId.trim().isEmpty) return null;
    if (deities.isEmpty) return currentId;
    for (final deity in deities) {
      if (deity.id == currentId) return deity.id;
      if (deity.id.toLowerCase() == currentId.toLowerCase()) {
        return deity.id;
      }
    }
    return null;
  }

  Set<String> _validateDomainSlugs(
    Set<String> currentSlugs,
    String? deityId,
    Set<String> availableSlugs,
    Map<String, Set<String>> domainSlugsByDeity,
    int requiredCount,
  ) {
    if (currentSlugs.isEmpty) return <String>{};

    final validSlugs = <String>{};
    for (final slug in currentSlugs) {
      if (availableSlugs.isNotEmpty && !availableSlugs.contains(slug)) {
        continue;
      }
      if (deityId != null) {
        final allowed = domainSlugsByDeity[deityId] ??
            domainSlugsByDeity[deityId.toLowerCase()];
        if (allowed != null && allowed.isNotEmpty && !allowed.contains(slug)) {
          continue;
        }
      }
      validSlugs.add(slug);
      if (validSlugs.length >= requiredCount && requiredCount > 0) {
        break;
      }
    }
    return validSlugs;
  }

  Set<String> _domainOptionKeysFor(
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
      final domainSlug = _slugify(domainName);
      if (domainSlugs.contains(domainSlug)) {
        keys.add(_featureOptionKey(option));
      }
    }
    return keys;
  }

  void _applyDomainSelectionToFeatures(
    Map<String, Set<String>> selections,
    Map<String, Map<String, dynamic>> featureDetailsById,
    Set<String> domainLinkedFeatureIds,
    Set<String> domainSlugs,
  ) {
    for (final featureId in domainLinkedFeatureIds) {
      if (domainSlugs.isEmpty) {
        selections.remove(featureId);
        continue;
      }
      final matchingKeys = _domainOptionKeysFor(
        featureDetailsById,
        featureId,
        domainSlugs,
      );

      if (matchingKeys.isNotEmpty) {
        // If only one domain selected, auto-select that domain's feature
        // If multiple domains, allow user to choose
        if (domainSlugs.length == 1) {
          selections[featureId] = matchingKeys;
        } else {
          // Keep existing selection if valid, otherwise clear
          final existing = selections[featureId] ?? <String>{};
          final validExisting = existing.intersection(matchingKeys);
          selections[featureId] =
              validExisting.isNotEmpty ? validExisting : <String>{};
        }
      } else {
        selections.remove(featureId);
      }
    }
  }

  String _featureOptionKey(Map<String, dynamic> option) =>
      _slugify(_featureOptionLabel(option));

  String _featureOptionLabel(Map<String, dynamic> option) {
    for (final key in ['name', 'title', 'domain']) {
      final value = option[key]?.toString();
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    if (option['skill'] != null) {
      final value = option['skill'].toString();
      if (value.trim().isNotEmpty) return value.trim();
    }
    if (option['benefit'] != null) {
      final value = option['benefit'].toString();
      if (value.trim().isNotEmpty) return value.trim();
    }
    return 'Option';
  }

  String _displayDomainName(String slug) {
    final mapped = _domainNameBySlug[slug];
    if (mapped != null && mapped.isNotEmpty) return mapped;
    return _titleCaseFromSlug(slug);
  }

  String? get _selectedDomainName {
    final slugs = _selectedDomainSlugs;
    if (slugs.isEmpty) return null;
    if (slugs.length == 1) {
      return _displayDomainName(slugs.first);
    }
    // Multiple domains selected
    final names = slugs.map(_displayDomainName).toList();
    names.sort();
    return names.join(', ');
  }

  String _titleCaseFromSlug(String slug) {
    final parts = slug
        .split('_')
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return slug;
    return parts.map((part) => part.capitalize()).join(' ');
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
    _characteristicTokens = const [];
    _characteristicArrayAssignments = {
      for (final key in _characteristicKeys) key: null,
    };

    _subclassComponentId = null;
    _classSkillPickCount = 0;
    _classSkillComponents = const [];
    _grantedClassSkillIds.clear();
    _classSkillCandidateIds.clear();
    _selectedClassSkillIds.clear();
    _allowanceSkillSelections.clear();
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
    _deityComponents = const [];
    _domainNameBySlug.clear();
    _domainSlugsByDeityId.clear();
    _availableDomainSlugs = const <String>{};
    _domainLinkedFeatureIds.clear();
    _requiredDeityCount = 0;
    _requiredDomainCount = 0;
    final heroDeity = _model?.deityId?.trim();
    _selectedDeityId =
        (heroDeity == null || heroDeity.isEmpty) ? null : heroDeity;
    final heroDomain = _model?.domain?.trim();
    _selectedDomainSlugs = (heroDomain == null || heroDomain.isEmpty)
        ? <String>{}
        : {_slugify(heroDomain)};
  }

  Future<void> _prepareSkillState(Map<String, dynamic>? metadata) async {
    if (!mounted) return;
    final start = metadata?['starting_characteristics'];
    if (start is! Map<String, dynamic>) {
      setState(() {
        _classSkillPickCount = 0;
        _classSkillComponents = const [];
        _grantedClassSkillIds.clear();
        _classSkillCandidateIds.clear();
        _selectedClassSkillIds.clear();
        _allowanceSkillSelections.clear();
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
        _classSkillComponents = const [];
        _grantedClassSkillIds.clear();
        _classSkillCandidateIds.clear();
        _selectedClassSkillIds.clear();
        _allowanceSkillSelections.clear();
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
    final allowances = <_SkillAllowance>[];

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

    final allowAllGroups = groupNames.isEmpty &&
        ((skillsInfo['skill_count'] as num?)?.toInt() ?? 0) > 0;

    final baseGroups = allowAllGroups
        ? const <String>['Any']
        : (groupNames.map((name) => name.capitalize()).toList()..sort());
    final baseGranted = grantedNames.isEmpty
        ? const <String>[]
        : (grantedNames.toList()..sort());
    if (pickCount > 0 || baseGranted.isNotEmpty) {
      allowances.add(_SkillAllowance(
        level: 1,
        source: 'Class start',
        pickCount: pickCount < 0 ? 0 : pickCount,
        groups: baseGroups,
        grantedSkillNames: baseGranted,
      ));
    }

    final allowanceAllowsAll = allowances.any((allowance) =>
        allowance.groups.isEmpty ||
        allowance.groups.any((group) => group.toLowerCase() == 'any'));

    final combinedGroupNames = <String>{...groupNames};
    for (final allowance in allowances) {
      for (final group in allowance.groups) {
        final normalized = group.trim().toLowerCase();
        if (normalized.isEmpty || normalized == 'any') continue;
        combinedGroupNames.add(normalized);
      }
    }
    if (allowanceAllowsAll) {
      combinedGroupNames
        ..clear()
        ..addAll(_allSkillGroups);
    }

    final effectiveAllowAllGroups = allowAllGroups || allowanceAllowsAll;

    final groupCandidateIds = effectiveAllowAllGroups
        ? allSkillComponents.map((component) => component.id).toSet()
        : allSkillComponents
            .where((component) {
              final group =
                  component.data['group']?.toString().trim().toLowerCase();
              return combinedGroupNames.isEmpty ||
                  (group != null && combinedGroupNames.contains(group));
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

    final levelEntries = _levelsUpToCurrentFromMetadata(metadata);
    for (final levelEntry in levelEntries) {
      final levelNumber = (levelEntry['level'] as num?)?.toInt() ?? 0;
      if (levelNumber <= 1) continue;
      void processSkillNode(dynamic node) {
        if (node is Map<String, dynamic>) {
          final allowance = _skillAllowanceFromLevelEntry(levelNumber, node);
          if (allowance != null) allowances.add(allowance);
        } else if (node is Map) {
          final allowance = _skillAllowanceFromLevelEntry(
              levelNumber, Map<String, dynamic>.from(node));
          if (allowance != null) allowances.add(allowance);
        } else if (node is List) {
          for (final item in node) {
            processSkillNode(item);
          }
        }
      }

      processSkillNode(levelEntry['skills']);
    }

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

    allowances.sort((a, b) => a.level.compareTo(b.level));

    setState(() {
      _classSkillPickCount = pickCount;
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
      _skillAllowances = allowances;
      _allowanceSkillSelections.clear();
    });
  }

  _SkillAllowance? _skillAllowanceFromLevelEntry(
    int level,
    Map<String, dynamic> entry,
  ) {
    final count = _toIntOrNull(entry['count'] ?? entry['skill_count']);
    final groups = <String>{};

    void addGroup(dynamic value) {
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) groups.add(trimmed.capitalize());
      } else if (value is List) {
        for (final item in value) {
          addGroup(item);
        }
      }
    }

    addGroup(entry['groups']);
    addGroup(entry['group']);
    addGroup(entry['skill_groups']);

    final grantedSkills = <String>{};

    void addSkill(dynamic value) {
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) grantedSkills.add(trimmed);
      } else if (value is List) {
        for (final item in value) {
          addSkill(item);
        }
      }
    }

    addSkill(entry['granted_skills']);
    addSkill(entry['grantedSkills']);
    addSkill(entry['granted']);
    addSkill(entry['specific_skills']);

    final sourceValue =
        entry['source'] ?? entry['name'] ?? entry['feature'] ?? entry['title'];
    final resolvedSource = sourceValue?.toString().trim();

    final normalizedCount = count ?? 0;
    if (normalizedCount <= 0 && grantedSkills.isEmpty) {
      return null;
    }

    final normalizedGroups = level > 1
        ? const <String>['Any']
        : (groups.isEmpty ? const <String>[] : (groups.toList()..sort()));

    return _SkillAllowance(
      level: level,
      source: resolvedSource == null || resolvedSource.isEmpty
          ? 'Bonus'
          : resolvedSource,
      pickCount: normalizedCount < 0 ? 0 : normalizedCount,
      groups: normalizedGroups,
      grantedSkillNames: grantedSkills.isEmpty
          ? const <String>[]
          : (grantedSkills.toList()..sort()),
    );
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
      final resolvedId =
          rawId.trim().isNotEmpty ? rawId.trim() : _slugify(rawName.trim());
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
    final normalized =
        selections.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
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
    if (_domainLinkedFeatureIds.contains(normalizedId)) {
      final current =
          _featureOptionSelections[normalizedId] ?? const <String>{};
      if (!setEquals(current, normalizedSelections)) {
        _showLimitSnack(
          'Domain feature choices are controlled by your selected domain. Update your domain selection above.',
        );
      }
      return;
    }
    final current = _featureOptionSelections[normalizedId] ?? const <String>{};
    if (setEquals(current, normalizedSelections)) return;
    setState(() {
      _featureOptionSelections[normalizedId] = normalizedSelections;
    });
    _setDirty(true);
  }

  void _updateDeitySelection(String? deityId) {
    final normalized = deityId?.trim();
    final resolved = (normalized == null || normalized.isEmpty)
        ? null
        : _validateDeityId(normalized, _deityComponents);

    final allowedDomains = resolved == null
        ? _availableDomainSlugs
        : _domainSlugsByDeityId[resolved] ??
            _domainSlugsByDeityId[resolved.toLowerCase()] ??
            _availableDomainSlugs;

    var nextDomains = Set<String>.from(_selectedDomainSlugs);
    nextDomains = nextDomains.intersection(allowedDomains);

    if (_selectedDeityId == resolved &&
        const SetEquality().equals(_selectedDomainSlugs, nextDomains)) {
      return;
    }

    setState(() {
      _selectedDeityId = resolved;
      _selectedDomainSlugs = nextDomains;
      final updated = Map<String, Set<String>>.from(_featureOptionSelections);
      _applyDomainSelectionToFeatures(
        updated,
        _classFeatureDetailsById,
        _domainLinkedFeatureIds,
        nextDomains,
      );
      _featureOptionSelections
        ..clear()
        ..addAll(updated);
    });
    _setDirty(true);
  }

  void _updateDomainSelection(Set<String> domainSlugs) {
    final currentDeity = _selectedDeityId;
    final maxAllowed = _requiredDomainCount > 0 ? _requiredDomainCount : 999;

    // Validate domain count
    if (domainSlugs.length > maxAllowed) {
      _showLimitSnack(
          'You can select at most $maxAllowed ${maxAllowed == 1 ? 'domain' : 'domains'}.');
      return;
    }

    // Validate domains are allowed for selected deity
    if (currentDeity != null) {
      final allowed = _domainSlugsByDeityId[currentDeity] ??
          _domainSlugsByDeityId[currentDeity.toLowerCase()];
      if (allowed != null && allowed.isNotEmpty) {
        final invalidDomains = domainSlugs.difference(allowed);
        if (invalidDomains.isNotEmpty) {
          _showLimitSnack(
              'Selected domains are not available for the selected deity.');
          return;
        }
      }
    }

    if (const SetEquality().equals(_selectedDomainSlugs, domainSlugs)) return;

    setState(() {
      _selectedDomainSlugs = domainSlugs;
      final updated = Map<String, Set<String>>.from(_featureOptionSelections);
      _applyDomainSelectionToFeatures(
        updated,
        _classFeatureDetailsById,
        _domainLinkedFeatureIds,
        domainSlugs,
      );
      _featureOptionSelections
        ..clear()
        ..addAll(updated);
    });
    _setDirty(true);
  }

  void _updateDomainSkill(String domainSlug, String skill) {
    if (_selectedDomainSkills[domainSlug] == skill) return;

    setState(() {
      _selectedDomainSkills[domainSlug] = skill;
    });
    _setDirty(true);
  }

  Future<void> _prepareSkillsData() async {
    try {
      final raw = await rootBundle.loadString('data/story/skills.json');
      final decoded = jsonDecode(raw) as List<dynamic>;
      final skills = decoded.cast<Map<String, dynamic>>();

      final skillsByGroup = <String, List<String>>{};
      for (final skill in skills) {
        final group = skill['group']?.toString();
        final name = skill['name']?.toString();
        if (group != null && name != null) {
          skillsByGroup.putIfAbsent(group, () => <String>[]).add(name);
        }
      }

      // Sort skill names within each group
      for (final list in skillsByGroup.values) {
        list.sort();
      }

      setState(() {
        _skillsByGroup = skillsByGroup;
      });
    } catch (_) {
      // If loading fails, use empty data
      setState(() {
        _skillsByGroup = <String, List<String>>{};
      });
    }
  }

  Future<void> _prepareDomainFeatureData(List<Feature> features) async {
    final domainFeatureData = <String, Map<String, dynamic>>{};

    for (final feature in features) {
      if (feature.id == 'feature_censor_domain_feature') {
        try {
          final featureMaps =
              await FeatureRepository.loadClassFeatureMaps(_classSlug ?? '');
          for (final featureMap in featureMaps) {
            if (featureMap['id'] == feature.id) {
              final options = featureMap['options'] as List<dynamic>?;
              if (options != null) {
                for (final option in options) {
                  if (option is Map<String, dynamic>) {
                    final domain = option['domain']?.toString();
                    if (domain != null) {
                      final domainSlug = _slugify(domain);
                      domainFeatureData[domainSlug] =
                          Map<String, dynamic>.from(option);
                    }
                  }
                }
              }
              break;
            }
          }
        } catch (_) {
          // If loading fails, continue without domain feature data
        }
        break;
      }
    }

    setState(() {
      _domainFeatureData = domainFeatureData;
    });
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
      final matches =
          allowances.any((allowance) => allowance.allowsGroup(group));
      if (matches) candidateIds.add(perk.id);
    }

    final existingPerks = (_model?.perks ?? const <String>[]).toList();
    final baseline =
        existingPerks.where((id) => !candidateIds.contains(id)).toSet();
    final selectable =
        existingPerks.where((id) => candidateIds.contains(id)).toList();

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
      allLanguages =
          await ref.read(componentsByTypeProvider('language').future);
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
      ..languages = mergedLanguages
      ..deityId = _selectedDeityId
      ..domain =
          _selectedDomainSlugs.isNotEmpty ? _selectedDomainSlugs.first : null;

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

  String? _getAllowanceSkillSelection(int allowanceIndex, int pickIndex) {
    return _allowanceSkillSelections[allowanceIndex]?[pickIndex];
  }

  void _setAllowanceSkillSelection(
      int allowanceIndex, int pickIndex, String? skillId) {
    setState(() {
      _allowanceSkillSelections.putIfAbsent(allowanceIndex, () => {});

      // Remove this skill from other selections in the same allowance to prevent duplicates
      if (skillId != null) {
        final allowanceMap = _allowanceSkillSelections[allowanceIndex]!;
        allowanceMap
            .removeWhere((key, value) => key != pickIndex && value == skillId);
      }

      _allowanceSkillSelections[allowanceIndex]![pickIndex] = skillId;

      // Update the selected class skills set
      _updateSelectedClassSkillsFromAllowances();
    });
    _setDirty(true);
  }

  void _updateSelectedClassSkillsFromAllowances() {
    final newSelections = <String>{};

    // Add granted skills
    newSelections.addAll(_grantedClassSkillIds);

    // Add skills selected through allowances
    for (final allowanceMap in _allowanceSkillSelections.values) {
      for (final skillId in allowanceMap.values) {
        if (skillId != null) {
          newSelections.add(skillId);
        }
      }
    }

    _selectedClassSkillIds
      ..clear()
      ..addAll(newSelections);
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

  Widget _buildSectionTileHeader(
    ThemeData theme, {
    required String title,
    String? subtitle,
    required IconData icon,
    required Color accent,
  }) {
    final textTheme = theme.textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: accent, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null && subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCollapsibleSection({
    required ThemeData theme,
    required _CreatorSection section,
    required String title,
    String? subtitle,
    required IconData icon,
    required Color accent,
    required Widget Function() buildContent,
  }) {
    final expanded = _expandedSections[section] ?? true;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: StrifeTheme.cardElevation,
        shape:
            const RoundedRectangleBorder(borderRadius: StrifeTheme.cardRadius),
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: PageStorageKey<_CreatorSection>(section),
            initiallyExpanded: expanded,
            onExpansionChanged: (value) {
              setState(() {
                _expandedSections[section] = value;
              });
            },
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            childrenPadding: StrifeTheme.cardPadding,
            maintainState: true,
            trailing: Icon(
              expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: accent,
            ),
            title: _buildSectionTileHeader(
              theme,
              title: title,
              subtitle: subtitle,
              icon: icon,
              accent: accent,
            ),
            children: [buildContent()],
          ),
        ),
      ),
    );
  }

  Widget _buildStrifeContent(ThemeData theme) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildLevelCard(theme)),
        SliverToBoxAdapter(child: _buildClassCard(theme)),
        if (_classSlug == null)
          SliverToBoxAdapter(child: _buildSelectClassNotice(theme))
        else if (_classData == null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                "We couldn't load this class data yet. Double-check that the seed files exist and try again.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          )
        else ...[
          SliverToBoxAdapter(child: _buildDeityDomainCard(theme)),
          SliverToBoxAdapter(child: _buildSubclassCard(theme)),
          SliverToBoxAdapter(child: _buildBasicsCard(theme)),
          SliverToBoxAdapter(child: _buildCharacteristicArraysCard(theme)),
          SliverToBoxAdapter(child: _buildSkillsCard(theme)),
          SliverToBoxAdapter(child: _buildPerksCard(theme)),
          SliverToBoxAdapter(child: _buildAbilitiesCard(theme)),
          SliverToBoxAdapter(child: _buildFeaturesCard(theme)),
          SliverToBoxAdapter(child: _buildLanguagesCard(theme)),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ],
    );
  }

  Widget _buildLevelCard(ThemeData theme) {
    return _buildCollapsibleSection(
      theme: theme,
      section: _CreatorSection.level,
      title: 'Level',
      subtitle: 'Choose the hero level for this class',
      icon: Icons.trending_up,
      accent: StrifeTheme.levelAccent,
      buildContent: () {
        return Row(
          children: [
            IconButton(
              onPressed: _level > 1 ? () => _updateLevel(_level - 1) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
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
              onPressed: _level < 10 ? () => _updateLevel(_level + 1) : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        );
      },
    );
  }

  Widget _buildClassCard(ThemeData theme) {
    final classesAsync = ref.watch(componentsByTypeProvider('class'));
    return _buildCollapsibleSection(
      theme: theme,
      section: _CreatorSection.classSelection,
      title: 'Class',
      subtitle: 'Select one class to determine Strife progression',
      icon: Icons.auto_stories,
      accent: StrifeTheme.classAccent,
      buildContent: () {
        return classesAsync.when(
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
            return DropdownButtonFormField<String?>(
              value: _classComponentId,
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('-- Choose class --'),
                ),
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
            );
          },
        );
      },
    );
  }

  Widget _buildSubclassCard(ThemeData theme) {
    final classSlug = _classSlug;
    if (classSlug == null || classSlug.isEmpty) {
      return const SizedBox.shrink();
    }

    final subclassesAsync = ref.watch(componentsByTypeProvider('subclass'));
    return _buildCollapsibleSection(
      theme: theme,
      section: _CreatorSection.subclass,
      title: 'Subclass',
      subtitle:
          'Choose a specialization to unlock extra skills, features, and abilities.',
      icon: Icons.auto_awesome,
      accent: StrifeTheme.featuresAccent,
      buildContent: () {
        return subclassesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, st) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to load subclasses: $e'),
          ),
          data: (subclasses) {
            final filtered = subclasses.where((component) {
              final parent =
                  component.data['parent_class']?.toString().toLowerCase();
              return parent == classSlug;
            }).toList()
              ..sort((a, b) => a.name.compareTo(b.name));

            if (filtered.isEmpty) {
              return const Text('This class does not define subclasses.');
            }

            final hasSelection = filtered
                .any((component) => component.id == _subclassComponentId);
            final dropdownValue = hasSelection ? _subclassComponentId : null;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String?>(
                  value: dropdownValue,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('-- Choose subclass --'),
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
            );
          },
        );
      },
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

  Widget _buildBasicsCard(ThemeData theme) {
    final start = _startingCharacteristics;
    if (start == null) return const SizedBox.shrink();
    final motto = start['motto']?.toString();
    final resourceName = start['heroicResourceName']?.toString();
    final resourceDescription = (start['heroicResourceDescription'] ??
            start['heroic_resource_description'])
        ?.toString();

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
    final progression = start['potency_progression'] as Map?;
    final potencyEntries = progression == null
        ? const <MapEntry<String, String>>[]
        : progression.entries
            .where((entry) => entry.value != null)
            .map((entry) => MapEntry(
                  entry.key.toString().capitalize(),
                  entry.value.toString(),
                ))
            .toList();

    return _buildCollapsibleSection(
      theme: theme,
      section: _CreatorSection.basics,
      title: 'Basics',
      subtitle: 'Identity, vital stats, and potency guidance',
      icon: Icons.layers_outlined,
      accent: StrifeTheme.resourceAccent,
      buildContent: () {
        final children = <Widget>[];
        if (motto != null && motto.isNotEmpty) {
          children.addAll([
            Text(
              motto,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: StrifeTheme.resourceAccent,
              ),
            ),
            const SizedBox(height: 16),
          ]);
        }
        if (resourceName != null && resourceName.isNotEmpty) {
          children.addAll([
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
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: StrifeTheme.resourceAccent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.bolt,
                      color: StrifeTheme.resourceAccent, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    resourceName,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ]);
          if (resourceDescription != null && resourceDescription.isNotEmpty) {
            children.addAll([
              const SizedBox(height: 6),
              Text(
                resourceDescription,
                style: theme.textTheme.bodySmall,
              ),
            ]);
          }
          children.add(const SizedBox(height: 16));
        }
        if (stats.isNotEmpty) {
          children.addAll([
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: stats
                  .where((entry) => entry.$2 != null)
                  .map((entry) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
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
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: StrifeTheme.resourceAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${entry.$2}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ]);
        }
        if (boosts.isNotEmpty) {
          children.addAll([
            Text(
              'Fixed characteristic boosts',
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
            const SizedBox(height: 16),
          ]);
        }
        if (potencyEntries.isNotEmpty) {
          children.addAll([
            Text(
              'Potency guidance',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: potencyEntries
                  .map((entry) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
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
                              entry.key,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: StrifeTheme.resourceAccent,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.value,
                              style: theme.textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ]);
        }
        if (children.isNotEmpty && children.last is SizedBox) {
          // keep trailing spacing consistent
        } else if (children.isNotEmpty) {
          children.add(const SizedBox(height: 4));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
      },
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
                                  style:
                                      theme.textTheme.headlineSmall?.copyWith(
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

  Widget _buildCharacteristicArraysCard(ThemeData theme) {
    final arrays = _availableCharacteristicArrays;
    if (arrays.isEmpty && _fixedStartingCharacteristics.isEmpty) {
      return const SizedBox.shrink();
    }

    final fixed = _fixedStartingCharacteristics;
    final selectedIndex = _selectedCharacteristicArrayIndex;
    final assignments = _characteristicArrayAssignments;
    final accent = StrifeTheme.classAccent;

    final baseTotals = _baseCharacteristicTotals();
    final applied = _applyLevelCharacteristicAdjustments(baseTotals);
    final finalTotals = applied.totals;
    final levelBonuses = applied.bonuses;

    final unassignedTokens = _unassignedCharacteristicTokens;
    final assignmentsComplete = _hasCompleteCharacteristicAssignments();
    final selectedDescription = (selectedIndex != null &&
            selectedIndex >= 0 &&
            selectedIndex < arrays.length)
        ? arrays[selectedIndex]['description']?.toString()
        : null;

    Widget buildArrayTile(int index) {
      final array = arrays[index];
      final values = _characteristicArrayValues(array);
      final isSelected = index == selectedIndex;
      return ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 160),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _selectCharacteristicArray(index),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? accent.withValues(alpha: 0.7)
                      : theme.colorScheme.outline.withValues(alpha: 0.3),
                  width: isSelected ? 1.6 : 1.2,
                ),
                color: isSelected
                    ? accent.withValues(alpha: 0.14)
                    : theme.colorScheme.surfaceVariant.withValues(alpha: 0.1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: accent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Array ${index + 1}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: values
                        .map((value) => _buildTokenPreviewChip(theme, value))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final arrayTiles = arrays.isEmpty
        ? <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.18),
              ),
              child: Text(
                'This class does not define characteristic arrays.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ]
        : List.generate(arrays.length, buildArrayTile);

    final characteristicRows = <Widget>[];
    for (final key in _characteristicKeys) {
      final displayName = _characteristicDisplayName(key);
      final fixedValue = fixed[key];
      final assignedToken = assignments[key];
      final assignedValue = assignedToken?.value;
      final baseValue = fixedValue ?? 0;
      final levelBonus = levelBonuses[key] ?? 0;
      final total =
          finalTotals[key] ?? (baseValue + (assignedValue ?? 0) + levelBonus);

      if (fixedValue != null) {
        characteristicRows.add(
          _buildFixedCharacteristicRow(
            theme,
            name: displayName,
            valueLabel: 'Fixed bonus ${_formatSignedValue(fixedValue)}',
            totalLabel: 'Total: ${_formatSignedValue(total)}',
            bonusLabel: levelBonus > 0
                ? 'Level bonus ${_formatSignedValue(levelBonus)}'
                : null,
            accent: accent,
          ),
        );
        continue;
      }

      final contributionChips = <Widget>[];
      if (assignedValue != null) {
        contributionChips.add(
          _buildAbilityMetaChip(
            theme,
            label: 'Array ${_formatSignedValue(assignedValue)}',
            color: accent,
            icon: Icons.view_module,
          ),
        );
      }
      if (levelBonus > 0) {
        contributionChips.add(
          _buildAbilityMetaChip(
            theme,
            label: 'Level ${_formatSignedValue(levelBonus)}',
            color: StrifeTheme.resourceAccent,
            icon: Icons.trending_up,
          ),
        );
      }

      characteristicRows.add(
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accent.withValues(alpha: 0.28),
              width: 1.2,
            ),
            color: theme.colorScheme.surface.withValues(alpha: 0.06),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    displayName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (assignedToken != null)
                    IconButton(
                      tooltip: 'Clear assignment',
                      onPressed: () => _clearCharacteristicAssignment(key),
                      icon: const Icon(Icons.close),
                      color: accent,
                      splashRadius: 18,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              DragTarget<_CharacteristicValueToken>(
                onWillAcceptWithDetails: (_) => selectedIndex != null,
                onAcceptWithDetails: selectedIndex != null
                    ? (details) => _assignCharacteristicValue(key, details.data)
                    : null,
                builder: (context, candidate, rejected) {
                  final isActive =
                      candidate.isNotEmpty && selectedIndex != null;
                  final borderColor = selectedIndex == null
                      ? theme.colorScheme.outline.withValues(alpha: 0.2)
                      : isActive
                          ? accent.withValues(alpha: 0.7)
                          : theme.colorScheme.outline.withValues(alpha: 0.35);
                  final background = selectedIndex == null
                      ? theme.colorScheme.surfaceVariant.withValues(alpha: 0.08)
                      : isActive
                          ? accent.withValues(alpha: 0.14)
                          : theme.colorScheme.surfaceVariant
                              .withValues(alpha: 0.08);
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: borderColor,
                        width: 1.4,
                      ),
                      color: background,
                    ),
                    child: assignedToken != null
                        ? _buildAssignedTokenChip(theme, assignedToken)
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  selectedIndex == null
                                      ? 'Select an array to enable assignments.'
                                      : 'Long-press a value chip and drag it here.',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.touch_app,
                                size: 18,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                  );
                },
              ),
              if (contributionChips.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: contributionChips,
                ),
              ],
              const SizedBox(height: 10),
              Text(
                'Final total: ${_formatSignedValue(total)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final summaryChips = assignmentsComplete
        ? finalTotals.entries.map((entry) {
            final total = entry.value;
            return _buildAbilityMetaChip(
              theme,
              label:
                  '${_characteristicDisplayName(entry.key)}: ${_formatSignedValue(total)}',
              color: accent,
              icon: Icons.check_circle_outline,
            );
          }).toList()
        : const <Widget>[];

    return _buildCollapsibleSection(
      theme: theme,
      section: _CreatorSection.characteristics,
      title: 'Characteristic arrays',
      subtitle: arrays.isEmpty
          ? 'Fixed bonuses only for this class.'
          : 'Choose an array and drag each value to a characteristic.',
      icon: Icons.view_module,
      accent: accent,
      buildContent: () {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (arrays.isEmpty)
              ...arrayTiles
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: arrayTiles,
              ),
            const SizedBox(height: 16),
            _buildAvailableTokensSection(
              theme,
              tokens: unassignedTokens,
              enabled: selectedIndex != null,
              description: selectedDescription,
            ),
            if (characteristicRows.isNotEmpty) ...[
              const SizedBox(height: 16),
              for (var i = 0; i < characteristicRows.length; i++) ...[
                characteristicRows[i],
                if (i < characteristicRows.length - 1)
                  const SizedBox(height: 12),
              ],
            ],
            const SizedBox(height: 12),
            Text(
              assignmentsComplete
                  ? 'All characteristic slots assigned.'
                  : arrays.isEmpty
                      ? 'All bonuses are fixed for this class.'
                      : 'Assign each value to finish setting up starting characteristics.',
              style: theme.textTheme.bodySmall,
            ),
            if (summaryChips.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: summaryChips,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSkillsCard(ThemeData theme) {
    final hasSkillOptions = _classSkillComponents.isNotEmpty ||
        _grantedClassSkillIds.isNotEmpty ||
        _classSkillPickCount > 0 ||
        _skillAllowances.isNotEmpty;
    if (!hasSkillOptions) {
      return const SizedBox.shrink();
    }

    final accent = StrifeTheme.skillsAccent;
    final grantedComponents = _classSkillComponents
        .where((component) => _grantedClassSkillIds.contains(component.id))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final dropdownItems = _classSkillComponents.map((component) {
      final group = component.data['group']?.toString().trim();
      final groupLabel =
          group == null || group.isEmpty ? 'Any' : group.capitalize();
      return DropdownMenuItem<String?>(
        value: component.id,
        child: Text('${component.name} ($groupLabel)'),
      );
    }).toList();

    return _buildCollapsibleSection(
      theme: theme,
      section: _CreatorSection.skills,
      title: 'Skills',
      subtitle:
          "Select skills granted or available for selection by your class.",
      icon: Icons.psychology_alt,
      accent: accent,
      buildContent: () {
        final children = <Widget>[];

        if (grantedComponents.isNotEmpty) {
          children.addAll([
            Text(
              'Granted skills',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: accent,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: grantedComponents
                  .map((component) => _buildSkillChip(context, component.name))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ]);
        }

        // Show skill selection dropdowns for each allowance
        for (var allowanceIndex = 0;
            allowanceIndex < _skillAllowances.length;
            allowanceIndex++) {
          final allowance = _skillAllowances[allowanceIndex];

          // Show dropdowns for skill picks
          if (allowance.pickCount > 0) {
            children.addAll([
              Text(
                'Level ${allowance.level} - ${allowance.source}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
              const SizedBox(height: 8),
            ]);

            final groupText = allowance.groups.isEmpty
                ? 'any group'
                : allowance.groups.any((group) => group.toLowerCase() == 'any')
                    ? 'any group'
                    : allowance.groups.join(', ');
            children.add(Text(
              'Choose ${allowance.pickCount} skill${allowance.pickCount == 1 ? '' : 's'} from $groupText',
              style: theme.textTheme.bodySmall,
            ));
            children.add(const SizedBox(height: 8));

            // Create dropdowns for each pick in this allowance
            for (var pickIndex = 0;
                pickIndex < allowance.pickCount;
                pickIndex++) {
              // Filter dropdown items based on allowance groups
              final filteredItems = allowance.groups.isEmpty ||
                      allowance.groups
                          .any((group) => group.toLowerCase() == 'any')
                  ? dropdownItems
                  : dropdownItems.where((item) {
                      final component = _classSkillComponents.firstWhereOrNull(
                        (c) => c.id == item.value,
                      );
                      if (component == null) return false;
                      final componentGroup =
                          component.data['group']?.toString().trim() ?? '';
                      return allowance.groups.any((allowedGroup) =>
                          allowedGroup.toLowerCase() ==
                          componentGroup.toLowerCase());
                    }).toList();

              children.addAll([
                DropdownButtonFormField<String?>(
                  value: _getAllowanceSkillSelection(allowanceIndex, pickIndex),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('-- Choose skill --'),
                    ),
                    ...filteredItems,
                  ],
                  onChanged: (value) {
                    _setAllowanceSkillSelection(
                        allowanceIndex, pickIndex, value);
                  },
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.psychology, color: accent),
                    labelText: 'Skill choice ${pickIndex + 1}',
                  ),
                ),
                const SizedBox(height: 12),
              ]);
            }
            children.add(const SizedBox(height: 8));
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
      },
    );
  }

  Widget _buildAbilitiesCard(ThemeData theme) {
    final hasAbilityData = _classAbilityData.isNotEmpty ||
        _autoGrantedAbilityIds.isNotEmpty ||
        _baselineAbilityIds.isNotEmpty;
    if (!hasAbilityData) {
      return const SizedBox.shrink();
    }

    return _buildCollapsibleSection(
      theme: theme,
      section: _CreatorSection.abilities,
      title: 'Abilities',
      subtitle: 'Assign abilities unlocked by your class progression.',
      icon: Icons.bolt,
      accent: StrifeTheme.abilitiesAccent,
      buildContent: () {
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
          wrapWithCard: false,
        );
      },
    );
  }

  Widget _buildFeaturesCard(ThemeData theme) {
    if (_classFeatures.isEmpty) return const SizedBox.shrink();

    return _buildCollapsibleSection(
      theme: theme,
      section: _CreatorSection.features,
      title: 'Level features',
      subtitle: 'Review class features unlocked up to level $_level.',
      icon: Icons.military_tech,
      accent: StrifeTheme.featuresAccent,
      buildContent: () {
        return ClassFeaturesWidget(
          level: _level,
          classMetadata: _classData,
          features: _classFeatures,
          featureDetailsById: _classFeatureDetailsById,
          selectedOptions: _featureOptionSelections,
          onSelectionChanged: _updateFeatureSelection,
          domainLinkedFeatureIds: _domainLinkedFeatureIds,
          selectedDomainSlugs: _selectedDomainSlugs,
          abilityDetailsById: _abilityDetailsById,
          abilityIdByName: _abilityIdByName,
          onAbilityPreviewRequested: _showAbilityDetails,
          activeSubclassSlugs: _activeSubclassSlugs,
          subclassLabel: _selectedSubclassDisplayName,
          wrapWithCard: false,
        );
      },
    );
  }

  Widget _buildPerksCard(ThemeData theme) {
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
          for (var slot = 0;
              slot < allowance.count && slot < existing.length;
              slot++) {
            slots[slot] = existing[slot];
          }
        }
        selections[index] = slots;
      }
    }

    return _buildCollapsibleSection(
      theme: theme,
      section: _CreatorSection.perks,
      title: 'Perks',
      subtitle: 'Select perks based on class allowances.',
      icon: Icons.workspace_premium_outlined,
      accent: StrifeTheme.featuresAccent,
      buildContent: () {
        return PerkPickerCard(
          allowances: _perkAllowances,
          perkComponents: _perkComponents,
          selections: selections,
          onSelectionChanged: _updatePerkSelection,
          wrapWithCard: false,
        );
      },
    );
  }

  Widget _buildLanguagesCard(ThemeData theme) {
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
          for (var slot = 0;
              slot < allowance.count && slot < existing.length;
              slot++) {
            slots[slot] = existing[slot];
          }
        }
        selections[index] = slots;
      }
    }

    return _buildCollapsibleSection(
      theme: theme,
      section: _CreatorSection.languages,
      title: 'Languages',
      subtitle: 'Assign languages granted by your class progression.',
      icon: Icons.language_outlined,
      accent: StrifeTheme.levelAccent,
      buildContent: () {
        return LanguagePickerCard(
          allowances: _languageAllowances,
          languageComponents: _languageComponents,
          selections: selections,
          onSelectionChanged: _updateLanguageSelection,
          wrapWithCard: false,
        );
      },
    );
  }

  Widget _buildDeityDomainCard(ThemeData theme) {
    final hasFaithContent = _requiredDeityCount > 0 ||
        _requiredDomainCount > 0 ||
        _deityComponents.isNotEmpty ||
        _selectedDeityId != null ||
        _selectedDomainSlugs.isNotEmpty;
    if (!hasFaithContent) {
      return const SizedBox.shrink();
    }

    return DeityDomainPickerCard(
      deities: _deityComponents,
      selectedDeityId: _selectedDeityId,
      selectedDomainSlugs: _selectedDomainSlugs,
      requiredDeityCount: _requiredDeityCount,
      requiredDomainCount: _requiredDomainCount,
      domainNameBySlug: _domainNameBySlug,
      domainSlugsByDeityId: _domainSlugsByDeityId,
      availableDomainSlugs: _availableDomainSlugs,
      selectedDomainName: _selectedDomainName,
      selectedDomainSkills: _selectedDomainSkills,
      onDeityChanged: _updateDeitySelection,
      onDomainChanged: _updateDomainSelection,
      onDomainSkillChanged: _updateDomainSkill,
      domainFeatureData: _domainFeatureData,
      skillsByGroup: _skillsByGroup,
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
      backgroundColor: theme.colorScheme.surfaceVariant.withValues(alpha: 0.4),
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
    String? bonusLabel,
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
                if (bonusLabel != null)
                  Text(
                    bonusLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
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

class _CharacteristicValueToken {
  const _CharacteristicValueToken({
    required this.id,
    required this.value,
  });

  final int id;
  final int value;
}

class _SkillAllowance {
  const _SkillAllowance({
    required this.level,
    required this.source,
    this.pickCount = 0,
    this.groups = const <String>[],
    this.grantedSkillNames = const <String>[],
  });

  final int level;
  final String source;
  final int pickCount;
  final List<String> groups;
  final List<String> grantedSkillNames;
}

class _FaithRequirements {
  const _FaithRequirements({
    required this.deityCount,
    required this.domainCount,
  });

  final int deityCount;
  final int domainCount;

  bool get hasRequirements => deityCount > 0 || domainCount > 0;
}

class _DeityDomainState {
  const _DeityDomainState({
    required this.deities,
    required this.domainNameBySlug,
    required this.domainSlugsByDeityId,
    required this.availableDomainSlugs,
    required this.deityPickCount,
    required this.domainPickCount,
  });

  final List<Component> deities;
  final Map<String, String> domainNameBySlug;
  final Map<String, Set<String>> domainSlugsByDeityId;
  final Set<String> availableDomainSlugs;
  final int deityPickCount;
  final int domainPickCount;
}

extension _Capitalize on String {
  String capitalize() {
    if (isEmpty) return this;
    return substring(0, 1).toUpperCase() + substring(1);
  }
}
