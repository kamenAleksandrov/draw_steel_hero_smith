import 'dart:convert';

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

const Set<String> _subclassStopWords = {'the', 'of'};

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

  // Class skill selection state
  int _classSkillPickCount = 0;
  List<String> _classSkillGroups = const [];
  final Set<String> _grantedClassSkillIds = <String>{};
  final Set<String> _classSkillCandidateIds = <String>{};
  final Set<String> _selectedClassSkillIds = <String>{};
  final Set<String> _baselineSkillIds = <String>{};
  List<Component> _classSkillComponents = const [];

  // Class ability selection state
  final Set<String> _classAbilityIds = <String>{};
  final Set<String> _selectedClassAbilityIds = <String>{};
  final Set<String> _baselineAbilityIds = <String>{};
  final Map<int, List<Map<String, dynamic>>> _abilitiesByCost =
      <int, List<Map<String, dynamic>>>{};
  List<Map<String, dynamic>> _signatureAbilities = const [];
  final Map<String, int?> _abilityCostIndex = <String, int?>{};
  final Map<String, Map<String, dynamic>> _abilityDetailsById =
    <String, Map<String, dynamic>>{};
  final Map<int, int> _abilityAllowancesByCost = <int, int>{};
  int _signatureAbilityAllowance = 0;

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
    final abilities = await _loadClassAbilities(slug);
    await _prepareSkillState(metadata);
    _prepareAbilityState(abilities, metadata);
    if (!mounted) return;
    setState(() {
      _classData = metadata;
      _classFeatures = features;
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
      if (decoded is List) {
        final abilities = decoded
            .whereType<Map>()
            .map((entry) => entry.cast<String, dynamic>())
            .where((ability) {
          final level = (ability['level'] as num?)?.toInt();
          if (level != null && level > _level) {
            return false;
          }
          final subclassRequirement = ability['subclass'];
          if (subclassRequirement == null ||
              subclassRequirement.toString().trim().isEmpty) {
            return true;
          }
          return _matchesSelectedSubclass(subclassRequirement.toString());
        }).toList()
          ..sort((a, b) {
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
      }
    } catch (_) {}
    return const [];
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

  List<Map<String, dynamic>> _levelsUpToCurrent() {
    return _levelsUpToCurrentFromMetadata(_classData);
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

  Map<String, int> _fixedCharacteristicBoosts() {
    final boosts = <String, int>{};
    for (final level in _levelsUpToCurrent()) {
      final fixed = level['fixed_starting_characteristics'];
      if (fixed is! Map) continue;
      fixed.forEach((key, value) {
        final amount = (value as num?)?.toInt();
        if (amount == null) return;
        final label = key.toString();
        boosts[label] = (boosts[label] ?? 0) + amount;
      });
    }
    return boosts;
  }

  List<Map<String, dynamic>> _currentCharacteristicArrays() {
    final levels = _levelsUpToCurrent().reversed;
    for (final level in levels) {
      final arrays = level['starting_characteristics_arrays'];
      if (arrays is! List || arrays.isEmpty) continue;
      final result = <Map<String, dynamic>>[];
      for (final entry in arrays) {
        if (entry is! Map) continue;
        result.add(entry.cast<String, dynamic>());
      }
      if (result.isNotEmpty) return result;
    }
    return const [];
  }

  void _resetClassDependentState() {
    final existingSkillIds = (_model?.skills ?? const <String>[]).toSet();
    final existingAbilityIds = (_model?.abilities ?? const <String>[]).toSet();

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

    _classAbilityIds.clear();
    _selectedClassAbilityIds.clear();
    _baselineAbilityIds
      ..clear()
      ..addAll(existingAbilityIds);
    _abilitiesByCost.clear();
    _signatureAbilities = const [];
    _abilityCostIndex.clear();
    _abilityDetailsById.clear();
    _abilityAllowancesByCost.clear();
    _signatureAbilityAllowance = 0;
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

    final groupCandidateIds = allSkillComponents
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
      _classSkillGroups = groupNames.toList()..sort();
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

  void _prepareAbilityState(
    List<Map<String, dynamic>> abilities,
    Map<String, dynamic>? metadata,
  ) {
    final allowances = _extractAbilityAllowances(metadata);
    var signatureAllowance = allowances[null] ?? 0;
    final costAllowances = <int, int>{}
      ..addEntries(allowances.entries
          .where((entry) => entry.key != null)
          .map((entry) => MapEntry(entry.key!, entry.value)));

    final abilityIds = <String>{};
    final costMap = <int, List<Map<String, dynamic>>>{};
    final signatureList = <Map<String, dynamic>>[];
    final abilityCostIndex = <String, int?>{};
    final abilityDetails = <String, Map<String, dynamic>>{};

    for (final ability in abilities) {
      final id = ability['id']?.toString() ?? ability['name']?.toString() ?? '';
      if (id.isEmpty) continue;
      abilityIds.add(id);
      final cost = _abilityCost(ability);
      abilityCostIndex[id] = cost;
      abilityDetails[id] = ability;
      if (cost != null && cost > 0) {
        final list = costMap.putIfAbsent(cost, () => <Map<String, dynamic>>[]);
        list.add(ability);
      } else {
        signatureList.add(ability);
      }
    }

    costMap.forEach((_, list) => list.sort((a, b) =>
        (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString())));
    signatureList.sort((a, b) =>
        (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));

    if (allowances.isEmpty) {
      signatureAllowance = signatureList.length;
      for (final entry in costMap.entries) {
        costAllowances[entry.key] = entry.value.length;
      }
    }

    final existingAbilities = (_model?.abilities ?? const <String>[]).toList();
    final baseline =
        existingAbilities.where((id) => !abilityIds.contains(id)).toSet();
    final selectedOrdered =
        existingAbilities.where((id) => abilityIds.contains(id)).toList();
    final trimmedSelected = _enforceAbilityAllowances(
      selectedOrdered,
      abilityCostIndex,
      signatureAllowance,
      costAllowances,
    );

    if (!mounted) return;
    setState(() {
      _classAbilityIds
        ..clear()
        ..addAll(abilityIds);
      _baselineAbilityIds
        ..clear()
        ..addAll(baseline);
      _selectedClassAbilityIds
        ..clear()
        ..addAll(trimmedSelected);
      _abilitiesByCost
        ..clear()
        ..addAll(costMap.map((key, value) =>
            MapEntry(key, List<Map<String, dynamic>>.from(value))));
      _signatureAbilities = List<Map<String, dynamic>>.from(signatureList);
      _abilityCostIndex
        ..clear()
        ..addAll(abilityCostIndex);
      _abilityDetailsById
        ..clear()
        ..addAll(abilityDetails);
      _abilityAllowancesByCost
        ..clear()
        ..addAll(costAllowances);
      _signatureAbilityAllowance = signatureAllowance;
    });
  }

  Map<int?, int> _extractAbilityAllowances(Map<String, dynamic>? metadata) {
    final allowances = <int?, int>{};
    final start = metadata?['starting_characteristics'];
    if (start is! Map<String, dynamic>) return allowances;
    final levels = start['levels'];
    if (levels is! List) return allowances;

    for (final entry in levels) {
      if (entry is! Map<String, dynamic>) continue;
      final levelNumber = (entry['level'] as num?)?.toInt();
      if (levelNumber == null || levelNumber > _level) continue;

      final newAbilities = entry['new_abilities'];
      if (newAbilities is Map) {
        _accumulateAbilityAllowances(
          allowances,
          newAbilities.cast<String, dynamic>(),
        );
      }

      final newSubclassAbilities = entry['new_subclass_abilities'];
      if (newSubclassAbilities != null) {
        _accumulateSubclassAbilityAllowances(allowances, newSubclassAbilities);
      }
    }

    return allowances;
  }

  void _accumulateAbilityAllowances(
    Map<int?, int> allowances,
    Map<String, dynamic> data,
  ) {
    for (final entry in data.entries) {
      final amount = (entry.value as num?)?.toInt() ?? 0;
      if (amount <= 0) continue;
      final key = entry.key.toLowerCase();
      if (key == 'signature') {
        allowances[null] = (allowances[null] ?? 0) + amount;
        continue;
      }
      final match = RegExp(r'(\d+)').firstMatch(key);
      if (match == null) continue;
      final cost = int.tryParse(match.group(1)!);
      if (cost == null) continue;
      allowances[cost] = (allowances[cost] ?? 0) + amount;
    }
  }

  void _accumulateSubclassAbilityAllowances(
    Map<int?, int> allowances,
    dynamic data,
  ) {
    if (data == null) return;
    final active = _activeSubclassSlugs;
    if (active.isEmpty) return;

    if (data is Map) {
      final entries = data.entries.toList();
      final isDirectAllowance = entries.every((entry) {
        final value = entry.value;
        if (value is num) return true;
        if (value is String) {
          return int.tryParse(value) != null;
        }
        return false;
      });

      if (isDirectAllowance) {
        _accumulateAbilityAllowances(
          allowances,
          data.cast<String, dynamic>(),
        );
        return;
      }

      for (final entry in entries) {
        final key = entry.key?.toString() ?? '';
        if (key.trim().isEmpty) continue;
        final variants = _slugVariants(key);
        if (variants.isEmpty || variants.intersection(active).isEmpty) {
          continue;
        }
        _accumulateSubclassAbilityAllowances(allowances, entry.value);
      }
      return;
    }

    if (data is List) {
      for (final item in data) {
        _accumulateSubclassAbilityAllowances(allowances, item);
      }
    }
  }

  Set<String> _enforceAbilityAllowances(
    List<String> orderedIds,
    Map<String, int?> costIndex,
    int signatureAllowance,
    Map<int, int> costAllowances,
  ) {
    var signatureRemaining = signatureAllowance;
    final remainingByCost = Map<int, int>.from(costAllowances);
    final selected = <String>{};

    for (final id in orderedIds) {
      final cost = costIndex[id];
      if (cost == null || cost <= 0) {
        if (signatureRemaining > 0) {
          selected.add(id);
          signatureRemaining -= 1;
        }
        continue;
      }

      final remaining = remainingByCost[cost] ?? 0;
      if (remaining > 0) {
        selected.add(id);
        remainingByCost[cost] = remaining - 1;
      }
    }

    return selected;
  }

  int _abilityAllowanceForCost(int? cost) {
    if (cost == null || cost <= 0) {
      return _signatureAbilityAllowance;
    }
    return _abilityAllowancesByCost[cost] ?? 0;
  }

  int _selectedAbilityCountForCost(int cost) {
    return _selectedClassAbilityIds.where((id) {
      final abilityCost = _abilityCostIndex[id];
      return abilityCost != null && abilityCost == cost;
    }).length;
  }

  int _selectedSignatureAbilityCount() {
    return _selectedClassAbilityIds.where((id) {
      final cost = _abilityCostIndex[id];
      return cost == null || cost <= 0;
    }).length;
  }

  String _abilityTypeLabel(int? cost) {
    if (cost == null || cost <= 0) {
      return 'signature';
    }
    return '$cost-cost';
  }

  String _abilityDisplayName(String abilityId) {
    final raw = _abilityDetailsById[abilityId]?['name']?.toString();
    if (raw == null || raw.trim().isEmpty) return 'This ability';
    return raw;
  }

  bool _isAbilityToggleEnabled(String abilityId, int? cost, bool isSelected) {
    if (isSelected) {
      // Always allow deselection, even if the allowance has since dropped.
      return true;
    }

    final allowance = _abilityAllowanceForCost(cost);
    if (allowance <= 0) {
      return false;
    }

    final current = cost == null || cost <= 0
        ? _selectedSignatureAbilityCount()
        : _selectedAbilityCountForCost(cost);
    return current < allowance;
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

  void _toggleAbilitySelection(String abilityId) {
    if (!_classAbilityIds.contains(abilityId)) return;
    final isSelected = _selectedClassAbilityIds.contains(abilityId);

    if (!isSelected) {
      final cost = _abilityCostIndex[abilityId];
      final allowance = _abilityAllowanceForCost(cost);
      if (allowance <= 0) {
        final label = _abilityTypeLabel(cost);
        final abilityName = _abilityDisplayName(abilityId);
        _showLimitSnack(
          '$abilityName can’t be added because no $label abilities are available at level $_level.',
        );
        return;
      }

      final current = cost == null || cost <= 0
          ? _selectedSignatureAbilityCount()
          : _selectedAbilityCountForCost(cost);
      if (current >= allowance) {
        final label = _abilityTypeLabel(cost);
        final plural = allowance == 1 ? '' : 's';
        final abilityName = _abilityDisplayName(abilityId);
        _showLimitSnack(
          '$abilityName can’t be added. You can select up to $allowance $label ability$plural at level $_level.',
        );
        return;
      }
    }

    setState(() {
      if (isSelected) {
        _selectedClassAbilityIds.remove(abilityId);
      } else {
        _selectedClassAbilityIds.add(abilityId);
      }
    });
    _setDirty(true);
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
        _model!.abilities, _baselineAbilityIds, _selectedClassAbilityIds);
    _model!
      ..skills = mergedSkills
      ..abilities = mergedAbilities;
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
    final isSignature = cost == null || cost <= 0;

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
  // }

  Widget _buildAbilitySection(
    String title,
    List<Map<String, dynamic>> abilities, {
    int? cost,
  }) {
    final tiles = abilities
        .map((ability) => _buildAbilityTile(ability))
        .whereType<Widget>()
        .toList();
    if (tiles.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final limit = _abilityAllowanceForCost(cost);
    final selectedCount = cost == null || cost <= 0
        ? _selectedSignatureAbilityCount()
        : _selectedAbilityCountForCost(cost);
    var displayTitle = title;
    String? helperText;

    if (limit > 0) {
      displayTitle = '$title ($selectedCount of $limit)';
      final remaining = limit - selectedCount;
      helperText = remaining > 0
          ? '$remaining pick${remaining == 1 ? '' : 's'} remaining.'
          : 'All picks used.';
    } else if (limit == 0) {
      helperText = 'Unlocks at a higher level.';
    }

    final selectedNames = abilities
        .where((ability) {
          final id = ability['id']?.toString() ?? ability['name']?.toString();
          return id != null && _selectedClassAbilityIds.contains(id);
        })
        .map((ability) => ability['name']?.toString())
        .whereType<String>()
        .where((name) => name.trim().isNotEmpty)
        .toList();

    String selectionSummary;
    if (selectedNames.isEmpty) {
      selectionSummary = 'No abilities selected yet.';
    } else if (selectedNames.length <= 3) {
      selectionSummary = selectedNames.join(', ');
    } else {
      final remaining = selectedNames.length - 3;
      selectionSummary = '${selectedNames.take(3).join(', ')} +$remaining more';
    }

    final subtitleWidgets = <Widget>[];
    if (helperText != null) {
      subtitleWidgets.add(Text(
        helperText,
        style: theme.textTheme.bodySmall,
      ));
    }
    subtitleWidgets.add(Text(
      'Selected: $selectionSummary',
      style: theme.textTheme.bodySmall,
    ));

    final children = tiles.isEmpty
        ? [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No abilities available yet.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ]
        : [
            const SizedBox(height: 8),
            ...tiles,
            const SizedBox(height: 4),
          ];

    return ExpansionTile(
      key: ValueKey('${title}_$cost'),
      title: Text(
        displayTitle,
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: subtitleWidgets,
      ),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      maintainState: true,
      children: children,
    );
  }

  Widget? _buildAbilityTile(Map<String, dynamic> ability) {
    final id = ability['id']?.toString() ?? ability['name']?.toString() ?? '';
    if (id.isEmpty) return null;
    final name = ability['name']?.toString() ?? 'Ability';
    final summary = _abilitySummary(ability);
    final selected = _selectedClassAbilityIds.contains(id);
    final cost = _abilityCostIndex[id] ?? _abilityCost(ability);
    final level = _toIntOrNull(ability['level']);
    final subclassName = ability['subclass']?.toString().trim();
    final enabled = _isAbilityToggleEnabled(id, cost, selected);
    final theme = Theme.of(context);
    final accent = StrifeTheme.abilitiesAccent;

    final actionType = ability['action_type']?.toString();
    final keywords = (ability['keywords'] as List?)
            ?.whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const [];

    final metaChips = <Widget>[];
    if (actionType != null && actionType.isNotEmpty) {
      metaChips.add(_buildAbilityMetaChip(
        theme,
        label: actionType,
        color: accent,
        icon: Icons.bolt,
      ));
    }
    for (final keyword in keywords.take(2)) {
      metaChips.add(_buildAbilityMetaChip(
        theme,
        label: keyword,
        color: theme.colorScheme.secondary,
        icon: Icons.local_offer,
      ));
    }
    if (keywords.length > 2) {
      metaChips.add(_buildAbilityMetaChip(
        theme,
        label: '+${keywords.length - 2} more',
        color: theme.colorScheme.outline,
      ));
    }
    if (level != null && level > 0) {
      metaChips.add(_buildAbilityMetaChip(
        theme,
        label: 'Level $level',
        color: accent,
        icon: Icons.trending_up,
      ));
    }
    if (subclassName != null && subclassName.isNotEmpty) {
      metaChips.add(_buildAbilityMetaChip(
        theme,
        label: subclassName,
        color: theme.colorScheme.tertiary,
        icon: Icons.auto_awesome,
      ));
    }

    final limitReachedNotice = !enabled && !selected
        ? Text(
            'Limit reached for this cost.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          )
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Opacity(
        opacity: enabled || selected ? 1 : 0.6,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled ? () => _toggleAbilitySelection(id) : null,
            onLongPress: () => _showAbilityDetails(ability),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: selected
                    ? accent.withValues(alpha: 0.14)
                    : theme.colorScheme.surface,
                border: Border.all(
                  color: selected
                      ? accent.withValues(alpha: 0.65)
                      : theme.colorScheme.outlineVariant,
                  width: selected ? 1.6 : 1.0,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Checkbox(
                      value: selected,
                      onChanged:
                          enabled ? (_) => _toggleAbilitySelection(id) : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildAbilityCostBadge(theme, cost),
                            IconButton(
                              tooltip: 'View details',
                              icon: const Icon(Icons.info_outline),
                              onPressed: () => _showAbilityDetails(ability),
                              splashRadius: 18,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        if (metaChips.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: metaChips,
                          ),
                        ],
                        if (summary != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            summary,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (limitReachedNotice != null) ...[
                          const SizedBox(height: 8),
                          limitReachedNotice,
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAbilityCostBadge(ThemeData theme, int? cost) {
    final isSignature = cost == null || cost <= 0;
    final accent = StrifeTheme.abilitiesAccent;
    final color = isSignature
        ? theme.colorScheme.primary
        : accent;
    final label = isSignature ? 'Signature' : 'Cost $cost';
    final icon = isSignature ? Icons.auto_awesome : Icons.flash_on;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
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
                                    '${entry.key.capitalize()}: +${entry.value}',
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
    final arrays = _currentCharacteristicArrays();
    if (arrays.isEmpty) return const SizedBox.shrink();

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
              subtitle:
                  'Pick one array per hero to assign their starting characteristics',
              icon: Icons.view_module,
              accent: StrifeTheme.classAccent,
            ),
            Padding(
              padding: StrifeTheme.cardPadding,
              child: Column(
                children: arrays.map((entry) {
                  final values = (entry['values'] as List?)
                          ?.whereType<num>()
                          .map((e) => e.toInt())
                          .map((e) => e >= 0 ? '+$e' : '$e')
                          .join(' · ') ??
                      'Custom array';
                  final description = entry['description']?.toString();
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: StrifeTheme.classAccent
                            .withValues(alpha: 0.08),
                        border: Border.all(
                          color: StrifeTheme.classAccent
                              .withValues(alpha: 0.24),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            values,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: StrifeTheme.classAccent,
                            ),
                          ),
                          if (description != null && description.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                description,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
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
                    Text('Eligible skill groups',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
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
    final sections = <Widget>[];
    if (_signatureAbilities.isNotEmpty) {
      sections.add(
        _buildAbilitySection('Signature abilities', _signatureAbilities),
      );
    }

    final sortedCosts = _abilitiesByCost.keys.toList()..sort();
    for (final cost in sortedCosts) {
      final abilities = _abilitiesByCost[cost] ?? const [];
      if (abilities.isEmpty) continue;
      final label = cost == 1
          ? '1-cost abilities'
          : '$cost-cost abilities';
      sections.add(_buildAbilitySection(label, abilities, cost: cost));
    }

    if (sections.isEmpty) {
      return const SizedBox.shrink();
    }

    final allowanceChips = <Widget>[
      _buildAbilityAllowancePill(
        theme,
        label: 'Signature',
        allowance: _signatureAbilityAllowance,
        selected: _selectedSignatureAbilityCount(),
      ),
      ...sortedCosts.map(
        (cost) => _buildAbilityAllowancePill(
          theme,
          label: 'Cost $cost',
          allowance: _abilityAllowanceForCost(cost),
          selected: _selectedAbilityCountForCost(cost),
        ),
      ),
    ];

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
              title: 'Class abilities',
              subtitle:
                  'Tap an ability card to toggle it on or off for this hero',
              icon: Icons.bolt,
              accent: StrifeTheme.abilitiesAccent,
            ),
            Padding(
              padding: StrifeTheme.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (allowanceChips.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: allowanceChips,
                    ),
                    const SizedBox(height: 12),
                  ],
                  ...sections.expand((section) sync* {
                    yield section;
                    yield const SizedBox(height: 12);
                  }).toList()
                    ..removeLast(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesCard(ThemeData theme) {
    if (_classFeatures.isEmpty) return const SizedBox.shrink();

    final featuresByLevel = <int, List<Feature>>{};
    for (final feature in _classFeatures) {
      featuresByLevel.putIfAbsent(feature.level, () => <Feature>[]).add(feature);
    }

    final entries = featuresByLevel.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final tiles = entries.map((entry) {
      final features = entry.value..sort((a, b) => a.name.compareTo(b.name));
      return Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey('feature_level_${entry.key}'),
          title: Text('Level ${entry.key}'),
          subtitle: Text(
            '${features.length} feature${features.length == 1 ? '' : 's'}',
          ),
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          maintainState: true,
          children: features
              .map((feature) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _buildFeatureTile(feature, theme),
                  ))
              .toList(),
        ),
      );
    }).toList();

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
              title: 'Level features',
              subtitle: 'What this hero gains at each level up to $_level',
              icon: Icons.military_tech,
              accent: StrifeTheme.featuresAccent,
            ),
            Padding(
              padding: StrifeTheme.cardPadding,
              child: tiles.isEmpty
                  ? Text(
                      'No class features available yet.',
                      style: theme.textTheme.bodyMedium,
                    )
                  : Column(
                      children: tiles,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureTile(Feature feature, ThemeData theme) {
    final accent = feature.isSubclassFeature
        ? theme.colorScheme.tertiary
        : StrifeTheme.featuresAccent;
    final subtitle = feature.isSubclassFeature && feature.subclassName != null
        ? 'Subclass: ${feature.subclassName}'
        : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: accent.withValues(alpha: 0.08),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  feature.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),
              if (feature.isSubclassFeature)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: accent.withValues(alpha: 0.16),
                    border: Border.all(color: accent.withValues(alpha: 0.32)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Subclass',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (feature.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              feature.description,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
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

  Widget _buildAbilityAllowancePill(
    ThemeData theme, {
    required String label,
    required int allowance,
    required int selected,
  }) {
    final accent = StrifeTheme.abilitiesAccent;
    final bool unlocksLater = allowance <= 0;
    final remaining = allowance - selected;
    final color = unlocksLater
        ? theme.colorScheme.onSurfaceVariant
        : remaining > 0
            ? accent
            : theme.colorScheme.primary;
    final status = unlocksLater
        ? 'Unlocks later'
        : remaining > 0
            ? '$selected of $allowance'
            : '$selected of $allowance · Maxed';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            unlocksLater
                ? Icons.lock_clock
                : remaining > 0
                    ? Icons.check_circle_outline
                    : Icons.verified,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $status',
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
}

extension _Capitalize on String {
  String capitalize() {
    if (isEmpty) return this;
    return substring(0, 1).toUpperCase() + substring(1);
  }
}
