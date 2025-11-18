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
import '../../../core/services/abilities_service.dart';
import '../../../core/services/ability_data_service.dart';
import '../../../core/services/class_data_service.dart';
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

      // Load class
      if (hero.className != null) {
        final classData = _classDataService.getAllClasses().firstWhere(
            (c) => c.classId == hero.className,
            orElse: () => _classDataService.getAllClasses().first);
        _selectedClass = classData;

        // Load characteristic array if available
        final values = await db.getHeroValues(widget.heroId);
        final arrayRow = values.firstWhere(
          (v) => v.key == 'strife.characteristic_array',
          orElse: () => values.first, // dummy value
        );

        if (arrayRow.textValue != null && arrayRow.textValue!.isNotEmpty) {
          // Try to find matching array in class data
          final arrayDesc = arrayRow.textValue!;
          final matchingArray = classData
              .startingCharacteristics.startingCharacteristicsArrays
              .cast<CharacteristicArray?>()
              .firstWhere(
                (arr) => arr?.description == arrayDesc,
                orElse: () => null,
              );
          if (matchingArray != null) {
            _selectedArray = matchingArray;
          }
        }
      }

      // Load subclass
      if (hero.subclass != null && hero.subclass!.isNotEmpty) {
        _selectedSubclass = SubclassSelectionResult(
          subclassName: hero.subclass,
          deityId: hero.deityId,
          domainNames: hero.domain != null
              ? hero.domain!.split(',').map((e) => e.trim()).toList()
              : [],
        );
      }

      // Load kit (legacy single kit support)
      if (_selectedClass != null) {
        final values = await db.getHeroValues(widget.heroId);
        final kitRow = values.firstWhere(
          (v) => v.key == 'basics.kit',
          orElse: () => values.first,
        );
        if (kitRow.textValue != null && kitRow.textValue!.isNotEmpty) {
          _selectedKitIds = [kitRow.textValue];
        }
      }

      // Load characteristics (assigned values)
      // Note: We can't fully restore the array selection and assignments
      // without storing that metadata, but we can at least show the values
      if (hero.might != 0 ||
          hero.agility != 0 ||
          hero.reason != 0 ||
          hero.intuition != 0 ||
          hero.presence != 0) {
        _assignedCharacteristics = {
          'Might': hero.might,
          'Agility': hero.agility,
          'Reason': hero.reason,
          'Intuition': hero.intuition,
          'Presence': hero.presence,
        };
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
        _selectedSkills = await _restoreSkillSelections(
          classData: _selectedClass!,
          selectedLevel: _selectedLevel,
          skillIds: skillIds,
        );
        _selectedPerks = await _restorePerkSelections(
          classData: _selectedClass!,
          selectedLevel: _selectedLevel,
          perkIds: perkIds,
        );
      } else {
        _selectedAbilities = const <String, String?>{};
        _selectedSkills = const <String, String?>{};
        _selectedPerks = const <String, String?>{};
      }
    } catch (e) {
      debugPrint('Failed to load hero data: $e');
      // Don't fail the whole initialization if hero data can't be loaded
    }
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
      _selectedSubclass = null;
      _featureSelections = {};
      _selectedKitIds = [];
    });
    _markDirty();
  }

  void _handleArrayChanged(CharacteristicArray? array) {
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

  Future<void> handleSave() async {
    await _handleSave();
  }

  Future<void> _handleSave() async {
    if (!_validateSelections()) return;

    final repo = ref.read(heroRepositoryProvider);
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

      // 3.5. Save kit (first non-null kit for now, legacy support)
      if (_selectedKitIds.isNotEmpty && _selectedKitIds.first != null) {
        updates.add(repo.updateKit(widget.heroId, _selectedKitIds.first));
      }

      // 4. Save selected characteristic array name
      if (_selectedArray != null) {
        updates.add(repo.updateCharacteristicArray(
          widget.heroId,
          _selectedArray!.description,
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

      // 4. Calculate and save Stamina
      final maxStamina = startingChars.baseStamina +
          (startingChars.staminaPerLevel * (_selectedLevel - 1));
      updates.add(repo.updateVitals(
        widget.heroId,
        staminaMax: maxStamina,
        staminaCurrent: maxStamina, // Start at full health
      ));

      // 5. Calculate winded and dying values (based on max stamina)
      final windedValue = maxStamina ~/ 2; // Half of max stamina
      final dyingValue = -(maxStamina ~/ 2); // Negative half of max stamina
      updates.add(repo.updateVitals(
        widget.heroId,
        windedValue: windedValue,
        dyingValue: dyingValue,
      ));

      // 6. Save Recoveries
      final recoveriesMax = startingChars.baseRecoveries;
      final recoveryValue =
          (maxStamina / 3).ceil(); // 1/3 of max HP, rounded up
      updates.add(repo.updateVitals(
        widget.heroId,
        recoveriesMax: recoveriesMax,
        recoveriesCurrent: recoveriesMax, // Start with all recoveries available
      ));
      updates.add(repo.updateRecoveryValue(widget.heroId, recoveryValue));

      // 7. Save fixed stats from class
      updates.add(repo.updateCoreStats(
        widget.heroId,
        speed: startingChars.baseSpeed,
        stability: startingChars.baseStability,
        disengage: startingChars.baseDisengage,
      ));

      // 8. Save Heroic Resource name
      updates.add(repo.updateHeroicResourceName(
        widget.heroId,
        startingChars.heroicResourceName,
      ));

      // 9. Calculate and save potencies based on class progression
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

      // 11. Save selected skills to database
      final selectedSkillIds = _selectedSkills.values
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();

      if (selectedSkillIds.isNotEmpty) {
        updates.add(
          ref.read(appDatabaseProvider).setHeroComponentIds(
                heroId: widget.heroId,
                category: 'skill',
                componentIds: selectedSkillIds,
              ),
        );
      }

      // 12. Save selected perks to database
      final selectedPerkIds = _selectedPerks.values
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();

      if (selectedPerkIds.isNotEmpty) {
        updates.add(
          ref.read(appDatabaseProvider).setHeroComponentIds(
                heroId: widget.heroId,
                category: 'perk',
                componentIds: selectedPerkIds,
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved: Level $_selectedLevel ${classData.name}\n'
            'Stamina: $maxStamina, Recoveries: $recoveriesMax ($recoveryValue)\n'
            'Speed: ${startingChars.baseSpeed}, Resource: ${startingChars.heroicResourceName}',
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
              onSelectionChanged: _handleAbilitySelectionsChanged,
            ),
            StartingSkillsWidget(
              classData: _selectedClass!,
              selectedLevel: _selectedLevel,
              selectedSkills: _selectedSkills,
              onSelectionChanged: _handleSkillSelectionsChanged,
            ),
            StartingPerksWidget(
              classData: _selectedClass!,
              selectedLevel: _selectedLevel,
              selectedPerks: _selectedPerks,
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
