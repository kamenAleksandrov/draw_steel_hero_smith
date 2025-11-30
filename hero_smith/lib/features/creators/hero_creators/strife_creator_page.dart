import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/providers.dart';
import '../../../core/models/abilities_models.dart';
import '../../../core/models/class_data.dart';
import '../../../core/models/characteristics_models.dart';
import '../../../core/models/component.dart';
import '../../../core/models/perks_models.dart';
import '../../../core/models/skills_models.dart';
import '../../../core/models/subclass_models.dart';
import '../../../core/services/class_feature_data_service.dart';
import '../../../core/services/abilities_service.dart';
import '../../../core/services/ability_data_service.dart';
import '../../../core/services/class_data_service.dart';
import '../../../core/services/kit_bonus_service.dart';
import '../../../core/services/perk_data_service.dart';
import '../../../core/services/perks_service.dart';
import '../../../core/services/skill_data_service.dart';
import '../../../core/services/skills_service.dart';
import '../widgets/strife_creator/class_features_section.dart';
import '../widgets/strife_creator/choose_abilities_widget.dart';
import '../widgets/strife_creator/choose_equipment_widget.dart';
import '../widgets/strife_creator/choose_perks_widget.dart';
import '../widgets/strife_creator/choose_skills_widget.dart';
import '../widgets/strife_creator/choose_subclass_widget.dart';
import '../widgets/strife_creator/class_selector_widget.dart';
import '../widgets/strife_creator/level_selector_widget.dart';
import '../widgets/strife_creator/starting_characteristics_widget.dart';

/// Demo page for the new Strife Creator (Level, Class, and Starting Characteristics)
class StrifeCreatorPage extends ConsumerStatefulWidget {
  const StrifeCreatorPage({
    super.key,
    required this.heroId,
    this.onDirtyChanged,
    this.onSaveRequested,
  });

  final String heroId;
  final ValueChanged<bool>? onDirtyChanged;
  final VoidCallback? onSaveRequested;

  @override
  ConsumerState<StrifeCreatorPage> createState() => _StrifeCreatorPageState();
}

class _StrifeCreatorPageState extends ConsumerState<StrifeCreatorPage> {
  final ClassDataService _classDataService = ClassDataService();
  final StartingAbilitiesService _startingAbilitiesService =
      const StartingAbilitiesService();
  final AbilityDataService _abilityDataService = AbilityDataService();
  final StartingSkillsService _startingSkillsService =
      const StartingSkillsService();
  final SkillDataService _skillDataService = SkillDataService();
  final StartingPerksService _startingPerksService =
      const StartingPerksService();
  final PerkDataService _perkDataService = PerkDataService();

  static const Map<String, List<String>> _kitFeatureTypeMappings = {
    'kit': ['kit'],
    'psionic augmentation': ['psionic_augmentation'],
    'enchantment': ['enchantment'],
    'prayer': ['prayer'],
    'elementalist ward': ['ward'],
    'talent ward': ['ward'],
    'conduit ward': ['ward'],
    'ward': ['ward'],
  };

  static const List<String> _kitTypePriority = [
    'kit',
    'psionic_augmentation',
    'enchantment',
    'prayer',
    'ward',
    'stormwight_kit',
  ];

  bool _isLoading = true;
  String? _errorMessage;
  bool _isDirty = false;

  // State variables
  int _selectedLevel = 1;
  ClassData? _selectedClass;
  CharacteristicArray? _selectedArray;
  Map<String, int> _assignedCharacteristics = {};
// ignore: unused_field
  Map<String, int> _finalCharacteristics = {};
  Map<String, String?> _selectedSkills = {};
  Map<String, String?> _selectedAbilities = {};
  Map<String, String?> _selectedPerks = {};
  Set<String> _reservedSkillIds = {};
  Set<String> _reservedAbilityIds = {};
  Set<String> _reservedPerkIds = {};
  SubclassSelectionResult? _selectedSubclass;
  Map<String, Set<String>> _featureSelections = {};
  List<String?> _selectedKitIds = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      await _classDataService.initialize();
      if (!mounted) return;

      // Load existing hero data from database
      await _loadHeroData();

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load class data: $e';
      });
    }
  }

  Future<void> _loadHeroData() async {
    try {
      final repo = ref.read(heroRepositoryProvider);
      final db = ref.read(appDatabaseProvider);
      final hero = await repo.load(widget.heroId);

      if (hero == null) return;

      // Load level
      _selectedLevel = hero.level;

      // Load characteristics (assigned values from stored assignments)
      final savedAssignments =
          await repo.getCharacteristicAssignments(widget.heroId);
      if (savedAssignments.isNotEmpty) {
        _assignedCharacteristics = savedAssignments;
      } else if (hero.might != 0 ||
          hero.agility != 0 ||
          hero.reason != 0 ||
          hero.intuition != 0 ||
          hero.presence != 0) {
        // Fallback: use hero base values if no assignments saved
        _assignedCharacteristics = {
          'Might': hero.might,
          'Agility': hero.agility,
          'Reason': hero.reason,
          'Intuition': hero.intuition,
          'Presence': hero.presence,
        };
      }

      // Load class
      if (hero.className != null) {
        final classData = _classDataService.getAllClasses().firstWhere(
            (c) => c.classId == hero.className,
            orElse: () => _classDataService.getAllClasses().first);
        _selectedClass = classData;

        // Load characteristic array if available
        final values = await db.getHeroValues(widget.heroId);
        String? arrayDescription;
        for (final value in values) {
          if (value.key == 'strife.characteristic_array') {
            arrayDescription = value.textValue;
            break;
          }
        }

        final savedArrayValues =
            await repo.getCharacteristicArrayValues(widget.heroId);

        final matchingArray = _findSavedArraySelection(
          classData: classData,
          savedDescription: arrayDescription,
          savedValues: savedArrayValues,
        );

        if (matchingArray != null) {
          _selectedArray = matchingArray;
        }

        // Load subclass / deity / domain selections
        final domainNames = hero.domain == null
            ? <String>[]
            : hero.domain!
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
        final savedSubclassKey = await repo.getSubclassKey(widget.heroId);
        final subclassName = hero.subclass?.trim();
        final subclassKey = savedSubclassKey ??
            (subclassName != null && subclassName.isNotEmpty
                ? ClassFeatureDataService.slugify(subclassName)
                : null);
        if ((subclassName?.isNotEmpty ?? false) ||
            (hero.deityId?.trim().isNotEmpty ?? false) ||
            domainNames.isNotEmpty) {
          _selectedSubclass = SubclassSelectionResult(
            subclassKey: subclassKey,
            subclassName: subclassName,
            deityId: hero.deityId?.trim().isNotEmpty == true
                ? hero.deityId!.trim()
                : null,
            deityName: hero.deityId?.trim().isNotEmpty == true
                ? hero.deityId!.trim()
                : null,
            domainNames: domainNames,
          );
        } else {
          _selectedSubclass = null;
        }

        // Load saved feature selections
        final savedFeatureSelections =
            await repo.getFeatureSelections(widget.heroId);
        if (savedFeatureSelections.isNotEmpty) {
          _featureSelections = savedFeatureSelections;
        } else {
          _featureSelections = {};
        }

        // Load equipment / modifications selections
        final equipmentIds = await repo.getEquipmentIds(widget.heroId);
        if (equipmentIds.isNotEmpty) {
          final matched = await _matchEquipmentToSlots(
            classData: classData,
            equipmentIds: equipmentIds,
            db: db,
          );
          _selectedKitIds = matched;
        } else {
          _selectedKitIds = <String?>[];
        }
      }

      // Load abilities
      if (_selectedClass != null) {
        final abilityIds =
            await db.getHeroComponentIds(widget.heroId, 'ability');
        final skillIds = await db.getHeroComponentIds(widget.heroId, 'skill');
        final perkIds = await db.getHeroComponentIds(widget.heroId, 'perk');

        _selectedAbilities = await _restoreAbilitySelections(
          classData: _selectedClass!,
          selectedLevel: _selectedLevel,
          abilityIds: abilityIds,
        );
        final assignedAbilityIds =
            _selectedAbilities.values.whereType<String>().toSet();
        _reservedAbilityIds = abilityIds.toSet();

        _selectedSkills = await _restoreSkillSelections(
          classData: _selectedClass!,
          selectedLevel: _selectedLevel,
          skillIds: skillIds,
        );
        final assignedSkillIds =
            _selectedSkills.values.whereType<String>().toSet();
        _reservedSkillIds = skillIds.toSet();

        _selectedPerks = await _restorePerkSelections(
          classData: _selectedClass!,
          selectedLevel: _selectedLevel,
          perkIds: perkIds,
        );
        final assignedPerkIds =
            _selectedPerks.values.whereType<String>().toSet();
        _reservedPerkIds = perkIds.toSet();
      } else {
        _selectedAbilities = const <String, String?>{};
        _selectedSkills = const <String, String?>{};
        _selectedPerks = const <String, String?>{};
        _reservedAbilityIds = {};
        _reservedSkillIds = {};
        _reservedPerkIds = {};
      }
    } catch (e) {
      debugPrint('Failed to load hero data: $e');
      // Don't fail the whole initialization if hero data can't be loaded
    }
  }

  CharacteristicArray? _findSavedArraySelection({
    required ClassData classData,
    String? savedDescription,
    required List<int> savedValues,
  }) {
    final arrays = classData.startingCharacteristics.startingCharacteristicsArrays;

    if (savedDescription != null && savedDescription.isNotEmpty) {
      final byDescription = arrays.firstWhereOrNull(
        (arr) => arr.description == savedDescription,
      );
      if (byDescription != null) {
        return byDescription;
      }
    }

    final valueCandidates = savedValues.isNotEmpty
        ? savedValues
        : _assignedCharacteristics.values.toList();

    if (valueCandidates.isEmpty) return null;

    final target = List<int>.from(valueCandidates)..sort();
    return arrays.firstWhereOrNull((arr) {
      final arrValues = List<int>.from(arr.values)..sort();
      if (arrValues.length != target.length) return false;
      for (var i = 0; i < arrValues.length; i++) {
        if (arrValues[i] != target[i]) return false;
      }
      return true;
    });
  }

  Future<Map<String, String?>> _restoreAbilitySelections({
    required ClassData classData,
    required int selectedLevel,
    required List<String> abilityIds,
  }) async {
    if (abilityIds.isEmpty) {
      return const <String, String?>{};
    }

    final plan = _startingAbilitiesService.buildPlan(
      classData: classData,
      selectedLevel: selectedLevel,
    );
    if (plan.allowances.isEmpty) {
      return const <String, String?>{};
    }

    final classSlug = _classSlug(classData.classId);
    final components = await _abilityDataService.loadClassAbilities(classSlug);
    final options = components.map(_mapComponentToAbilityOption).toList();
    final optionById = {
      for (final option in options) option.id: option,
    };

    final filledCounts = <String, int>{
      for (final allowance in plan.allowances) allowance.id: 0,
    };
    final selections = <String, String?>{};
    final unmatched = <AbilityOption>[];

    for (final abilityId in abilityIds) {
      final option = optionById[abilityId];
      if (option == null) {
        continue;
      }
      final assigned = _tryAssignAbility(
        allowanceList: plan.allowances,
        filledCounts: filledCounts,
        selections: selections,
        option: option,
        ignoreConstraints: false,
      );
      if (!assigned) {
        unmatched.add(option);
      }
    }

    for (final option in unmatched) {
      _tryAssignAbility(
        allowanceList: plan.allowances,
        filledCounts: filledCounts,
        selections: selections,
        option: option,
        ignoreConstraints: true,
      );
    }

    return selections.isEmpty ? const <String, String?>{} : selections;
  }

  Future<Map<String, String?>> _restoreSkillSelections({
    required ClassData classData,
    required int selectedLevel,
    required List<String> skillIds,
  }) async {
    if (skillIds.isEmpty) {
      return const <String, String?>{};
    }

    final plan = _startingSkillsService.buildPlan(
      classData: classData,
      selectedLevel: selectedLevel,
    );
    if (plan.allowances.isEmpty) {
      return const <String, String?>{};
    }

    final options = await _skillDataService.loadSkills();
    final optionById = {
      for (final option in options) option.id: option,
    };

    final filledCounts = <String, int>{
      for (final allowance in plan.allowances) allowance.id: 0,
    };
    final selections = <String, String?>{};

    for (final skillId in skillIds) {
      final option = optionById[skillId];
      if (option == null) {
        continue;
      }
      final assigned = _tryAssignSkill(
        allowanceList: plan.allowances,
        filledCounts: filledCounts,
        selections: selections,
        option: option,
        ignoreConstraints: false,
      );
      if (!assigned) {
        _tryAssignSkill(
          allowanceList: plan.allowances,
          filledCounts: filledCounts,
          selections: selections,
          option: option,
          ignoreConstraints: true,
        );
      }
    }

    return selections.isEmpty ? const <String, String?>{} : selections;
  }

  Future<Map<String, String?>> _restorePerkSelections({
    required ClassData classData,
    required int selectedLevel,
    required List<String> perkIds,
  }) async {
    if (perkIds.isEmpty) {
      return const <String, String?>{};
    }

    final plan = _startingPerksService.buildPlan(
      classData: classData,
      selectedLevel: selectedLevel,
    );
    if (plan.allowances.isEmpty) {
      return const <String, String?>{};
    }

    final options = await _perkDataService.loadPerks();
    final optionById = {
      for (final option in options) option.id: option,
    };

    final filledCounts = <String, int>{
      for (final allowance in plan.allowances) allowance.id: 0,
    };
    final selections = <String, String?>{};

    for (final perkId in perkIds) {
      final option = optionById[perkId];
      if (option == null) {
        continue;
      }
      final assigned = _tryAssignPerk(
        allowanceList: plan.allowances,
        filledCounts: filledCounts,
        selections: selections,
        option: option,
        ignoreConstraints: false,
      );
      if (!assigned) {
        _tryAssignPerk(
          allowanceList: plan.allowances,
          filledCounts: filledCounts,
          selections: selections,
          option: option,
          ignoreConstraints: true,
        );
      }
    }

    return selections.isEmpty ? const <String, String?>{} : selections;
  }

  bool _tryAssignAbility({
    required List<AbilityAllowance> allowanceList,
    required Map<String, int> filledCounts,
    required Map<String, String?> selections,
    required AbilityOption option,
    required bool ignoreConstraints,
  }) {
    for (final allowance in allowanceList) {
      final filled = filledCounts[allowance.id] ?? 0;
      if (filled >= allowance.pickCount) {
        continue;
      }
      if (ignoreConstraints ||
          _allowanceAcceptsAbility(allowance: allowance, option: option)) {
        final slotKey = '${allowance.id}#$filled';
        selections[slotKey] = option.id;
        filledCounts[allowance.id] = filled + 1;
        return true;
      }
    }
    return false;
  }

  bool _allowanceAcceptsAbility({
    required AbilityAllowance allowance,
    required AbilityOption option,
  }) {
    if (allowance.isSignature != option.isSignature) {
      return false;
    }
    if (allowance.costAmount != null &&
        allowance.costAmount != option.costAmount) {
      return false;
    }
    final hasSubclass = option.subclass != null && option.subclass!.isNotEmpty;
    if (allowance.requiresSubclass && !hasSubclass) {
      return false;
    }
    if (!allowance.requiresSubclass && hasSubclass) {
      return false;
    }
    if (allowance.includePreviousLevels) {
      if (option.level > allowance.level) {
        return false;
      }
    } else {
      if (option.level != 0 && option.level != allowance.level) {
        return false;
      }
    }
    return true;
  }

  bool _tryAssignSkill({
    required List<SkillAllowance> allowanceList,
    required Map<String, int> filledCounts,
    required Map<String, String?> selections,
    required SkillOption option,
    required bool ignoreConstraints,
  }) {
    for (final allowance in allowanceList) {
      final filled = filledCounts[allowance.id] ?? 0;
      if (filled >= allowance.pickCount) {
        continue;
      }
      if (ignoreConstraints ||
          _allowanceAcceptsSkill(allowance: allowance, option: option)) {
        final slotKey = '${allowance.id}#$filled';
        selections[slotKey] = option.id;
        filledCounts[allowance.id] = filled + 1;
        return true;
      }
    }
    return false;
  }

  bool _allowanceAcceptsSkill({
    required SkillAllowance allowance,
    required SkillOption option,
  }) {
    if (allowance.allowedGroups.isEmpty) {
      return true;
    }
    return allowance.allowedGroups.contains(option.group.toLowerCase());
  }

  bool _tryAssignPerk({
    required List<PerkAllowance> allowanceList,
    required Map<String, int> filledCounts,
    required Map<String, String?> selections,
    required PerkOption option,
    required bool ignoreConstraints,
  }) {
    for (final allowance in allowanceList) {
      final filled = filledCounts[allowance.id] ?? 0;
      if (filled >= allowance.pickCount) {
        continue;
      }
      if (ignoreConstraints ||
          _allowanceAcceptsPerk(allowance: allowance, option: option)) {
        final slotKey = '${allowance.id}#$filled';
        selections[slotKey] = option.id;
        filledCounts[allowance.id] = filled + 1;
        return true;
      }
    }
    return false;
  }

  bool _allowanceAcceptsPerk({
    required PerkAllowance allowance,
    required PerkOption option,
  }) {
    if (allowance.allowedGroups.isEmpty) {
      return true;
    }
    return allowance.allowedGroups.contains(option.group.toLowerCase());
  }

  AbilityOption _mapComponentToAbilityOption(Component component) {
    final data = component.data;
    final costsRaw = data['costs'];

    final bool isSignature;
    if (costsRaw is String) {
      isSignature = costsRaw.toLowerCase() == 'signature';
    } else if (costsRaw is Map) {
      isSignature = costsRaw['signature'] == true;
    } else {
      isSignature = false;
    }

    final int? costAmount;
    final String? resource;
    if (costsRaw is Map) {
      final amountRaw = costsRaw['amount'];
      costAmount = amountRaw is num ? amountRaw.toInt() : null;
      resource = costsRaw['resource']?.toString();
    } else {
      costAmount = null;
      resource = null;
    }

    final level = data['level'] is num
        ? (data['level'] as num).toInt()
        : CharacteristicUtils.toIntOrNull(data['level']) ?? 0;
    final subclassRaw = data['subclass']?.toString().trim();
    final subclass =
        subclassRaw == null || subclassRaw.isEmpty ? null : subclassRaw;

    return AbilityOption(
      id: component.id,
      name: component.name,
      component: component,
      level: level,
      isSignature: isSignature,
      costAmount: costAmount,
      resource: resource,
      subclass: subclass,
    );
  }

  String _classSlug(String classId) {
    final normalized = classId.trim().toLowerCase();
    if (normalized.startsWith('class_')) {
      return normalized.substring('class_'.length);
    }
    return normalized;
  }

  /// Parse JSON string to map, returns null on error
  Future<Map<String, dynamic>?> _parseJson(String jsonStr) async {
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  void _markDirty() {
    if (!_isDirty) {
      setState(() {
        _isDirty = true;
      });
      widget.onDirtyChanged?.call(true);
    }
  }

  void _handleLevelChanged(int level) {
    setState(() {
      _selectedLevel = level;
    });
    _markDirty();
  }

  void _handleClassChanged(ClassData classData) {
    setState(() {
      _selectedClass = classData;
      // Reset characteristic and skill selections when class changes
      _selectedArray = null;
      _assignedCharacteristics = {};
      _selectedSkills = {};
      _selectedAbilities = {};
      _selectedPerks = {};
      _reservedSkillIds = {};
      _reservedAbilityIds = {};
      _reservedPerkIds = {};
      _selectedSubclass = null;
      _featureSelections = {};
      _selectedKitIds = <String?>[];
    });
    _markDirty();
  }

  void _handleArrayChanged(CharacteristicArray? array) {
    if (_selectedArray == array) return;
    setState(() {
      _selectedArray = array;
      _assignedCharacteristics = {};
    });
    _markDirty();
  }

  void _handleAssignmentsChanged(Map<String, int> assignments) {
    setState(() {
      _assignedCharacteristics = assignments;
    });
    _markDirty();
  }

  void _handleFinalTotalsChanged(Map<String, int> totals) {
    setState(() {
      _finalCharacteristics = totals;
    });
    _markDirty();
  }

  void _handleSkillSelectionsChanged(StartingSkillSelectionResult result) {
    setState(() {
      _selectedSkills = result.selectionsBySlot;
    });
    _markDirty();
  }

  void _handlePerkSelectionsChanged(StartingPerkSelectionResult result) {
    setState(() {
      _selectedPerks = result.selectionsBySlot;
    });
    _markDirty();
  }

  void _handleAbilitySelectionsChanged(StartingAbilitySelectionResult result) {
    setState(() {
      _selectedAbilities = result.selectionsBySlot;
    });
    _markDirty();
  }

  void _handleSubclassSelectionChanged(SubclassSelectionResult result) {
    setState(() {
      _selectedSubclass = result;
    });
    _markDirty();
  }

  void _handleKitChangedAtSlot(int slotIndex, String? kitId) {
    setState(() {
      while (_selectedKitIds.length <= slotIndex) {
        _selectedKitIds.add(null);
      }
      _selectedKitIds[slotIndex] = kitId;
    });
    _markDirty();
  }

  List<Widget> _buildKitWidgets() {
    if (_selectedClass == null) return [];

    final slots = _determineKitSlots(_selectedClass!);
    if (slots.isEmpty) return [];

    final totalSlots = slots.fold<int>(0, (sum, slot) => sum + slot.count);
    while (_selectedKitIds.length < totalSlots) {
      _selectedKitIds.add(null);
    }

    final equipmentSlots = <EquipmentSlot>[];
    var kitIndex = 0;

    for (final slot in slots) {
      for (var i = 0; i < slot.count; i++) {
        final currentIndex = kitIndex;
        final label = _buildEquipmentSlotLabel(
          allowedTypes: slot.allowedTypes,
          groupCount: slot.count,
          indexWithinGroup: i,
          globalIndex: kitIndex,
        );
        final helperText = slot.allowedTypes.length > 1
            ? 'Allowed types: ${slot.allowedTypes.map(_formatKitTypeName).join(', ')}'
            : null;

        equipmentSlots.add(
          EquipmentSlot(
            label: label,
            allowedTypes: slot.allowedTypes,
            selectedItemId: currentIndex < _selectedKitIds.length
                ? _selectedKitIds[currentIndex]
                : null,
            onChanged: (kitId) => _handleKitChangedAtSlot(currentIndex, kitId),
            helperText: helperText,
          ),
        );
        kitIndex++;
      }
    }

    return [
      EquipmentAndModificationsWidget(slots: equipmentSlots),
    ];
  }

  String _buildEquipmentSlotLabel({
    required List<String> allowedTypes,
    required int groupCount,
    required int indexWithinGroup,
    required int globalIndex,
  }) {
    if (allowedTypes.length == 1) {
      final base = _formatKitTypeName(allowedTypes.first);
      if (groupCount > 1) {
        return '$base ${indexWithinGroup + 1}';
      }
      return base;
    }
    return 'Equipment ${globalIndex + 1}';
  }

  String _formatKitTypeName(String type) {
    switch (type) {
      case 'psionic_augmentation':
        return 'Psionic Augmentation';
      case 'stormwight_kit':
        return 'Stormwight Kit';
      default:
        return type[0].toUpperCase() + type.substring(1);
    }
  }

  /// Match loaded equipment IDs to the correct slots based on their types
  Future<List<String?>> _matchEquipmentToSlots({
    required ClassData classData,
    required List<String?> equipmentIds,
    required dynamic db,
  }) async {
    final slots = _determineKitSlots(classData);
    if (slots.isEmpty) return <String?>[];

    // Build flat list of slot allowed types
    final slotTypes = <List<String>>[];
    for (final slot in slots) {
      for (var i = 0; i < slot.count; i++) {
        slotTypes.add(slot.allowedTypes);
      }
    }

    // Initialize result with nulls
    final result = List<String?>.filled(slotTypes.length, null);
    final usedIds = <String>{};

    // Load equipment types for each ID
    final equipmentTypes = <String, String>{};
    for (final id in equipmentIds) {
      if (id == null || id.isEmpty) {
        continue;
      }
      final component = await db.getComponentById(id);
      if (component != null) {
        equipmentTypes[id] = component.type;
      }
    }

    // First pass: match equipment to slots where type exactly matches
    for (var slotIndex = 0; slotIndex < slotTypes.length; slotIndex++) {
      final allowedTypes = slotTypes[slotIndex];
      for (final id in equipmentIds) {
        if (id == null || id.isEmpty) continue;
        if (usedIds.contains(id)) continue;
        final type = equipmentTypes[id];
        if (type != null && allowedTypes.contains(type)) {
          result[slotIndex] = id;
          usedIds.add(id);
          break;
        }
      }
    }

    // Second pass: fill remaining slots with any remaining equipment
    for (var slotIndex = 0; slotIndex < result.length; slotIndex++) {
      if (result[slotIndex] != null) continue;
      for (final id in equipmentIds) {
        if (id == null || id.isEmpty) continue;
        if (usedIds.contains(id)) continue;
        result[slotIndex] = id;
        usedIds.add(id);
        break;
      }
    }

    return result;
  }

  /// Determines kit slots and allowed types for each slot
  /// Returns list of (count, [allowed types]) pairs
  List<({int count, List<String> allowedTypes})> _determineKitSlots(
    ClassData classData,
  ) {
    // Special case: Stormwight Fury - only stormwight kits
    final subclassName = _selectedSubclass?.subclassName?.toLowerCase() ?? '';
    if (classData.classId == 'class_fury' && subclassName == 'stormwight') {
      return [
        (count: 1, allowedTypes: ['stormwight_kit'])
      ];
    }

    final kitFeatures = <Map<String, dynamic>>[];
    final typesList = <String>[];

    // Collect all kit-related features
    for (final level in classData.levels) {
      for (final feature in level.features) {
        final name = feature.name.trim().toLowerCase();
        if (name == 'kit' || _kitFeatureTypeMappings.containsKey(name)) {
          kitFeatures.add({
            'name': name,
            'count': feature.count ?? 1,
          });

          final mapped = _kitFeatureTypeMappings[name];
          if (mapped != null) {
            typesList.addAll(mapped);
          } else if (name == 'kit') {
            typesList.add('kit');
          }
        }
      }
    }

    if (kitFeatures.isEmpty) {
      return [];
    }

    // Remove duplicates while preserving order
    final uniqueTypes = <String>[];
    final seen = <String>{};
    for (final type in typesList) {
      if (seen.add(type)) {
        uniqueTypes.add(type);
      }
    }

    // Calculate total count needed
    var totalCount = 0;
    for (final feature in kitFeatures) {
      totalCount += feature['count'] as int;
    }

    // If we have multiple types and count > 1, create one slot per type
    if (uniqueTypes.length > 1 && totalCount >= uniqueTypes.length) {
      return uniqueTypes
          .map((type) => (count: 1, allowedTypes: [type]))
          .toList();
    }

    // Otherwise, create slots of the same type
    final sortedTypes = _sortKitTypesByPriority(uniqueTypes);
    return [
      (count: totalCount, allowedTypes: sortedTypes),
    ];
  }

  List<String> _sortKitTypesByPriority(Iterable<String> types) {
    final seen = <String>{};
    final sorted = <String>[];

    for (final type in _kitTypePriority) {
      if (types.contains(type) && seen.add(type)) {
        sorted.add(type);
      }
    }

    for (final type in types) {
      if (seen.add(type)) {
        sorted.add(type);
      }
    }

    return sorted;
  }

  bool _validateSelections() {
    if (_selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a class')),
      );
      return false;
    }

    if (_selectedArray == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a characteristic array')),
      );
      return false;
    }

    if (_assignedCharacteristics.length != _selectedArray!.values.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please assign all characteristic values')),
      );
      return false;
    }

    return true;
  }

  Set<String> _findDuplicates(Iterable<String?> values) {
    final seen = <String>{};
    final dupes = <String>{};
    for (final value in values.whereType<String>()) {
      if (!seen.add(value)) {
        dupes.add(value);
      }
    }
    return dupes;
  }

  Map<String, Set<String>> _collectSelectionConflicts() {
    final issues = <String, Set<String>>{};

    final skillValues = _selectedSkills.values.whereType<String>();
    final skillIssues = {
      ..._findDuplicates(skillValues),
      ...skillValues.toSet().intersection(_reservedSkillIds),
    };
    if (skillIssues.isNotEmpty) {
      issues['skills'] = skillIssues;
    }

    final perkValues = _selectedPerks.values.whereType<String>();
    final perkIssues = {
      ..._findDuplicates(perkValues),
      ...perkValues.toSet().intersection(_reservedPerkIds),
    };
    if (perkIssues.isNotEmpty) {
      issues['perks'] = perkIssues;
    }

    final abilityValues = _selectedAbilities.values.whereType<String>();
    final abilityIssues = {
      ..._findDuplicates(abilityValues),
      ...abilityValues.toSet().intersection(_reservedAbilityIds),
    };
    if (abilityIssues.isNotEmpty) {
      issues['abilities'] = abilityIssues;
    }

    return issues;
  }

  Future<bool> _confirmSelectionConflicts() async {
    final issues = _collectSelectionConflicts();
    if (issues.isEmpty) return true;

    final categories = issues.keys.join(', ');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Duplicate selections'),
        content: Text(
          'Some $categories are already assigned to this hero. '
          'Do you want to keep these duplicates?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> handleSave() async {
    await _handleSave();
  }

  Future<void> _handleSave() async {
    if (!_validateSelections()) return;
    final allowDuplicates = await _confirmSelectionConflicts();
    if (!allowDuplicates) return;

    final repo = ref.read(heroRepositoryProvider);
    final db = ref.read(appDatabaseProvider);
    final classData = _selectedClass!;
    final startingChars = classData.startingCharacteristics;

    try {
      final updates = <Future>[];

      // 1. Save level
      updates.add(repo.updateMainStats(widget.heroId, level: _selectedLevel));

      // 2. Save class name
      updates.add(repo.updateClassName(widget.heroId, classData.classId));

      // 3. Save subclass
      if (_selectedSubclass != null) {
        updates.add(repo.updateSubclass(
          widget.heroId,
          _selectedSubclass!.subclassName,
        ));

        // Save subclass key for proper restoration
        if (_selectedSubclass!.subclassKey != null) {
          updates.add(repo.saveSubclassKey(
            widget.heroId,
            _selectedSubclass!.subclassKey,
          ));
        }

        // Save deity if selected
        if (_selectedSubclass!.deityId != null) {
          updates.add(repo.updateDeity(
            widget.heroId,
            _selectedSubclass!.deityId,
          ));
        }

        // Save domain if selected (join multiple domains with comma)
        if (_selectedSubclass!.domainNames.isNotEmpty) {
          updates.add(repo.updateDomain(
            widget.heroId,
            _selectedSubclass!.domainNames.join(', '),
          ));
        }
      }

      // 3.5. Calculate equipment bonuses from selected kits/augmentations/etc.
      final slotOrderedEquipmentIds = List<String?>.from(_selectedKitIds);
      final equippedIds = slotOrderedEquipmentIds
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toList();

      EquipmentBonuses equipmentBonuses = EquipmentBonuses.empty;
      if (equippedIds.isNotEmpty) {
        // Load equipment components
        final equipmentComponents = <Component>[];
        for (final equipmentId in equippedIds) {
          final component = await db.getComponentById(equipmentId);
          if (component != null) {
            final parsedData = component.dataJson.isNotEmpty
                ? await _parseJson(component.dataJson) ?? {}
                : <String, dynamic>{};
            equipmentComponents.add(Component(
              id: component.id,
              type: component.type,
              name: component.name,
              data: Map<String, dynamic>.from(parsedData),
            ));
          }
        }

        // Calculate bonuses
        const kitBonusService = KitBonusService();
        equipmentBonuses = kitBonusService.calculateBonuses(
          equipment: equipmentComponents,
          heroLevel: _selectedLevel,
        );
      }

      // Persist equipment selection (including empty slots) for other screens
      updates.add(repo.saveEquipmentIds(widget.heroId, slotOrderedEquipmentIds));
      updates.add(db.upsertHeroValue(
        heroId: widget.heroId,
        key: 'basics.equipment',
        jsonMap: {'ids': slotOrderedEquipmentIds},
      ));

      // Save equipment bonuses (or clear if empty)
      updates.add(repo.saveEquipmentBonuses(
        widget.heroId,
        staminaBonus: equipmentBonuses.staminaBonus,
        speedBonus: equipmentBonuses.speedBonus,
        stabilityBonus: equipmentBonuses.stabilityBonus,
        disengageBonus: equipmentBonuses.disengageBonus,
        meleeDamageBonus: equipmentBonuses.meleeDamageBonus,
        rangedDamageBonus: equipmentBonuses.rangedDamageBonus,
        meleeDistanceBonus: equipmentBonuses.meleeDistanceBonus,
        rangedDistanceBonus: equipmentBonuses.rangedDistanceBonus,
      ));

      // Save class feature selections (user picks + auto-applied)
      updates.add(
        repo.saveFeatureSelections(widget.heroId, _featureSelections),
      );

      // 4. Save selected characteristic array name
      if (_selectedArray != null) {
        updates.add(repo.updateCharacteristicArray(
          widget.heroId,
          arrayName: _selectedArray!.description,
          arrayValues: _selectedArray!.values,
        ));
      }

      // 4.5. Save characteristic assignments (the mapping of stat to value)
      if (_assignedCharacteristics.isNotEmpty) {
        updates.add(repo.saveCharacteristicAssignments(
          widget.heroId,
          _assignedCharacteristics,
        ));
      }

      // 5. Save characteristics (base values from assignments AND fixed values)
      // First, save assigned characteristics from arrays
      _assignedCharacteristics.forEach((characteristic, value) {
        final charLower = characteristic.toLowerCase();
        if (charLower == 'might' ||
            charLower == 'agility' ||
            charLower == 'reason' ||
            charLower == 'intuition' ||
            charLower == 'presence') {
          updates.add(
            repo.setCharacteristicBase(widget.heroId,
                characteristic: charLower, value: value),
          );
        }
      });

      // Then, save fixed starting characteristics from class
      startingChars.fixedStartingCharacteristics
          .forEach((characteristic, value) {
        updates.add(
          repo.setCharacteristicBase(widget.heroId,
              characteristic: characteristic, value: value),
        );
      });

      // 6. Calculate and save Stamina (class base + level scaling + equipment bonus)
      final baseMaxStamina = startingChars.baseStamina +
          (startingChars.staminaPerLevel * (_selectedLevel - 1));
      final effectiveMaxStamina =
          baseMaxStamina + equipmentBonuses.staminaBonus;
      updates.add(repo.updateVitals(
        widget.heroId,
        staminaMax: baseMaxStamina,
        staminaCurrent: effectiveMaxStamina, // Start at full health
      ));

      // 7. Calculate winded and dying values (based on effective max stamina)
      final windedValue = effectiveMaxStamina ~/ 2; // Half of max stamina
      final dyingValue = -(effectiveMaxStamina ~/ 2); // Negative half of max stamina
      updates.add(repo.updateVitals(
        widget.heroId,
        windedValue: windedValue,
        dyingValue: dyingValue,
      ));

      // 8. Save Recoveries
      final recoveriesMax = startingChars.baseRecoveries;
      final recoveryValue =
          (effectiveMaxStamina / 3).ceil(); // 1/3 of max HP, rounded up
      updates.add(repo.updateVitals(
        widget.heroId,
        recoveriesMax: recoveriesMax,
        recoveriesCurrent: recoveriesMax, // Start with all recoveries available
      ));
      updates.add(repo.updateRecoveryValue(widget.heroId, recoveryValue));

      // 9. Save stats from class (equipment bonuses are stored separately)
      updates.add(repo.updateCoreStats(
        widget.heroId,
        speed: startingChars.baseSpeed,
        stability: startingChars.baseStability,
        disengage: startingChars.baseDisengage,
      ));

      // 10. Save Heroic Resource name
      updates.add(repo.updateHeroicResourceName(
        widget.heroId,
        startingChars.heroicResourceName,
      ));

      // 11. Calculate and save potencies based on class progression
      final potencyChar = startingChars.potencyProgression.characteristic;
      final potencyModifiers = startingChars.potencyProgression.modifiers;

      // Get the characteristic value for potency calculation
      final potencyCharValue = _assignedCharacteristics[potencyChar] ??
          startingChars
              .fixedStartingCharacteristics[potencyChar.toLowerCase()] ??
          0;

      // Calculate potency values (characteristic + modifier)
      final strongPotency =
          potencyCharValue + (potencyModifiers['strong'] ?? 0);
      final averagePotency =
          potencyCharValue + (potencyModifiers['average'] ?? 0);
      final weakPotency = potencyCharValue + (potencyModifiers['weak'] ?? 0);

      updates.add(repo.updatePotencies(
        widget.heroId,
        strong: '$strongPotency',
        average: '$averagePotency',
        weak: '$weakPotency',
      ));

      // 10. Save selected abilities to database
      final selectedAbilityIds = _selectedAbilities.values
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();

      if (selectedAbilityIds.isNotEmpty) {
        updates.add(
          ref.read(appDatabaseProvider).setHeroComponentIds(
                heroId: widget.heroId,
                category: 'ability',
                componentIds: selectedAbilityIds,
              ),
        );
      }

      // 11. Save selected skills to database (merge with existing story skills)
      // Get existing skills from database
      final existingComponents = await db.getHeroComponents(widget.heroId);
      final existingSkillIds = existingComponents
          .where((c) => c['category'] == 'skill')
          .map((c) => c['componentId'] as String)
          .toSet();

      // Collect strife-selected skills
      final strifeSkillIds = _selectedSkills.values
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();

      // Add subclass skill if present
      if (_selectedSubclass?.skill != null &&
          _selectedSubclass!.skill!.isNotEmpty) {
        // The skill field contains the skill name, we need to find the skill ID
        final allComponents = await db.getAllComponents();
        final subclassSkillName = _selectedSubclass!.skill!;
        final subclassSkillComponent = allComponents.where(
          (c) =>
              c.type == 'skill' &&
              (c.name == subclassSkillName || c.id == subclassSkillName),
        ).firstOrNull;
        if (subclassSkillComponent != null) {
          strifeSkillIds.add(subclassSkillComponent.id);
        }
      }

      // Merge: keep existing story skills + new strife skills
      final mergedSkillIds = existingSkillIds.union(strifeSkillIds);

      if (mergedSkillIds.isNotEmpty) {
        updates.add(
          db.setHeroComponentIds(
            heroId: widget.heroId,
            category: 'skill',
            componentIds: mergedSkillIds.toList(),
          ),
        );
      }

      // 12. Save selected perks to database (merge with existing story perks)
      final existingPerkIds = existingComponents
          .where((c) => c['category'] == 'perk')
          .map((c) => c['componentId'] as String)
          .toSet();

      final strifePerkIds = _selectedPerks.values
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();

      final mergedPerkIds = existingPerkIds.union(strifePerkIds);

      if (mergedPerkIds.isNotEmpty) {
        updates.add(
          db.setHeroComponentIds(
            heroId: widget.heroId,
            category: 'perk',
            componentIds: mergedPerkIds.toList(),
          ),
        );
      }

      // Execute all updates
      await Future.wait(updates);

      if (!mounted) return;

      setState(() {
        _isDirty = false;
      });
      widget.onDirtyChanged?.call(false);
      widget.onSaveRequested?.call();

      // Calculate display values for snackbar
      final displayStamina = baseMaxStamina + equipmentBonuses.staminaBonus;
      final displaySpeed = startingChars.baseSpeed + equipmentBonuses.speedBonus;
      final displayStability = startingChars.baseStability + equipmentBonuses.stabilityBonus;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved: Level $_selectedLevel ${classData.name}\n'
            'Stamina: $displayStamina${equipmentBonuses.staminaBonus > 0 ? ' (+${equipmentBonuses.staminaBonus} kit)' : ''}, '
            'Speed: $displaySpeed${equipmentBonuses.speedBonus > 0 ? ' (+${equipmentBonuses.speedBonus})' : ''}, '
            'Stability: $displayStability${equipmentBonuses.stabilityBonus > 0 ? ' (+${equipmentBonuses.stabilityBonus})' : ''}',
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _initializeData();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: ListView(
        children: [
          // Level Selector
          LevelSelectorWidget(
            selectedLevel: _selectedLevel,
            onLevelChanged: _handleLevelChanged,
          ),

          // Class Selector
          ClassSelectorWidget(
            availableClasses: _classDataService.getAllClasses(),
            selectedClass: _selectedClass,
            selectedLevel: _selectedLevel,
            onClassChanged: _handleClassChanged,
          ),

          if (_selectedClass != null) ...[
            StartingCharacteristicsWidget(
              classData: _selectedClass!,
              selectedLevel: _selectedLevel,
              selectedArray: _selectedArray,
              assignedCharacteristics: _assignedCharacteristics,
              onArrayChanged: _handleArrayChanged,
              onAssignmentsChanged: _handleAssignmentsChanged,
              onFinalTotalsChanged: _handleFinalTotalsChanged,
            ),
            ChooseSubclassWidget(
              classData: _selectedClass!,
              selectedLevel: _selectedLevel,
              selectedSubclass: _selectedSubclass,
              onSelectionChanged: _handleSubclassSelectionChanged,
            ),
            ..._buildKitWidgets(),
            StartingAbilitiesWidget(
              classData: _selectedClass!,
              selectedLevel: _selectedLevel,
              selectedAbilities: _selectedAbilities,
              reservedAbilityIds: _reservedAbilityIds,
              onSelectionChanged: _handleAbilitySelectionsChanged,
            ),
            StartingSkillsWidget(
              classData: _selectedClass!,
              selectedLevel: _selectedLevel,
              selectedSkills: _selectedSkills,
              reservedSkillIds: _reservedSkillIds,
              onSelectionChanged: _handleSkillSelectionsChanged,
            ),
            StartingPerksWidget(
              classData: _selectedClass!,
              selectedLevel: _selectedLevel,
              selectedPerks: _selectedPerks,
              reservedPerkIds: _reservedPerkIds,
              onSelectionChanged: _handlePerkSelectionsChanged,
            ),
            ClassFeaturesSection(
              classData: _selectedClass!,
              selectedLevel: _selectedLevel,
              selectedSubclass: _selectedSubclass,
              initialSelections: _featureSelections,
              onSelectionsChanged: (value) {
                setState(() {
                  _featureSelections = value;
                });
              },
            ),
          ],

          // Bottom padding
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// Public type alias for accessing the internal state from parent widgets.
typedef StrifeCreatorPageState = _StrifeCreatorPageState;
