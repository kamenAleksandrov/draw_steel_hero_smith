import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../../../core/models/class_data.dart';
import '../../../../core/models/component.dart';
import '../../../../core/models/abilities_models.dart';
import '../../../../core/models/characteristics_models.dart';
import '../../../../core/services/ability_data_service.dart';
import '../../../../core/services/abilities_service.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/selection_guard.dart';
import '../../../../widgets/abilities/ability_expandable_item.dart';
import '../../../../widgets/abilities/abilities_shared.dart';

typedef AbilitySelectionChanged = void Function(
    StartingAbilitySelectionResult result);

class StartingAbilitiesWidget extends StatefulWidget {
  const StartingAbilitiesWidget({
    super.key,
    required this.classData,
    required this.selectedLevel,
    this.selectedSubclassName,
    this.selectedAbilities = const <String, String?>{},
    this.reservedAbilityIds = const <String>{},
    this.onSelectionChanged,
  });

  final ClassData classData;
  final int selectedLevel;
  final String? selectedSubclassName;
  final Map<String, String?> selectedAbilities;
  final Set<String> reservedAbilityIds;
  final AbilitySelectionChanged? onSelectionChanged;

  @override
  State<StartingAbilitiesWidget> createState() =>
      _StartingAbilitiesWidgetState();
}

class _StartingAbilitiesWidgetState extends State<StartingAbilitiesWidget>
    with AutomaticKeepAliveClientMixin {
  final StartingAbilitiesService _service = const StartingAbilitiesService();
  final AbilityDataService _abilityDataService = AbilityDataService();
  final MapEquality<String, String?> _mapEquality =
      const MapEquality<String, String?>();
  final SetEquality<String> _setEquality = const SetEquality<String>();

  bool _isExpanded = false;

  @override
  bool get wantKeepAlive => true;
  bool _isLoading = true;
  String? _error;

  StartingAbilityPlan? _plan;
  final Map<String, List<String?>> _selections = {};
  Map<String, String?> _lastSelectionsSnapshot = const {};
  Set<String> _lastSelectedIdsSnapshot = const {};
  int _selectionCallbackVersion = 0;

  List<AbilityOption> _abilityOptions = const [];
  Map<String, AbilityOption> _abilityById = const {};

  @override
  void initState() {
    super.initState();
    _loadAbilities();
  }

  @override
  void didUpdateWidget(covariant StartingAbilitiesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final classChanged =
        oldWidget.classData.classId != widget.classData.classId;
    final levelChanged = oldWidget.selectedLevel != widget.selectedLevel;
    final subclassChanged =
        oldWidget.selectedSubclassName != widget.selectedSubclassName;
    final reservedChanged = !_setEquality.equals(
      oldWidget.reservedAbilityIds,
      widget.reservedAbilityIds,
    );
    if (classChanged) {
      _loadAbilities();
      return;
    }
    if ((levelChanged || subclassChanged) && !_isLoading && _error == null) {
      _rebuildPlan(
        preserveSelections: !subclassChanged,
        externalSelections: widget.selectedAbilities,
      );
    } else if (!_mapEquality.equals(
        oldWidget.selectedAbilities, widget.selectedAbilities)) {
      _applyExternalSelections(widget.selectedAbilities);
    }
    if (reservedChanged && !_isLoading && _error == null) {
      final changed = _applyReservedPruning();
      if (changed) {
        _notifySelectionChanged();
      }
    }
  }

  Future<void> _loadAbilities() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final classSlug = _classSlug(widget.classData.classId);
      final components =
          await _abilityDataService.loadClassAbilities(classSlug);
      if (!mounted) return;
      final options = components.map(_mapComponentToOption).toList();
      final byId = {
        for (final option in options) option.id: option,
      };
      _abilityOptions = options;
      _abilityById = byId;
      _rebuildPlan(
        preserveSelections: false,
        externalSelections: widget.selectedAbilities,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Failed to load abilities: $e';
      });
    }
  }

  AbilityOption _mapComponentToOption(Component component) {
    try {
      final data = component.data;
      final abilityData = AbilityData.fromComponent(component);

      final bool isSignature = abilityData.isSignature;
      final int? costAmount = abilityData.costAmount;
      final String? resource = abilityData.resourceLabel ?? abilityData.resourceType;

      final level = _resolveAbilityLevel(component);
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
    } catch (e, stackTrace) {
      debugPrint('Error mapping component to option:');
      debugPrint('Component ID: ${component.id}');
      debugPrint('Component Name: ${component.name}');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  void _rebuildPlan({
    required bool preserveSelections,
    Map<String, String?>? externalSelections,
  }) {
    final plan = _service.buildPlan(
      classData: widget.classData,
      selectedLevel: widget.selectedLevel,
    );

    final newSelections = <String, List<String?>>{};
    final external = externalSelections ?? widget.selectedAbilities;

    for (final allowance in plan.allowances) {
      final existing = preserveSelections
          ? (_selections[allowance.id] ?? const [])
          : const [];
      final updated = List<String?>.filled(allowance.pickCount, null);

      for (var i = 0; i < allowance.pickCount; i++) {
        String? value;
        if (i < existing.length) {
          value = existing[i];
        }
        final key = _slotKey(allowance.id, i);
        if (external.containsKey(key)) {
          value = external[key];
        }
        updated[i] = _resolveAbilityId(value);
      }

      newSelections[allowance.id] = updated;
    }

    setState(() {
      _plan = plan;
      _selections
        ..clear()
        ..addAll(newSelections);
      _isLoading = false;
      _error = null;
      _lastSelectionsSnapshot = const {};
      _lastSelectedIdsSnapshot = const {};
      _selectionCallbackVersion += 1;
    });

    _applyReservedPruning();
    _notifySelectionChanged();
  }

  void _applyExternalSelections(Map<String, String?> selections) {
    var changed = false;
    selections.forEach((key, value) {
      final parts = key.split('#');
      if (parts.length != 2) return;
      final allowanceId = parts.first;
      final slotIndex = int.tryParse(parts.last);
      if (slotIndex == null) return;
      final slots = _selections[allowanceId];
      if (slots == null || slotIndex < 0 || slotIndex >= slots.length) return;
      final resolved = _resolveAbilityId(value);
      if (slots[slotIndex] != resolved) {
        slots[slotIndex] = resolved;
        changed = true;
      }
    });
    if (changed) {
      setState(() {});
      _applyReservedPruning();
      _notifySelectionChanged();
    }
  }

  bool _applyReservedPruning() {
    if (widget.reservedAbilityIds.isEmpty) return false;
    final allowIds = _selections.values
        .expand((slots) => slots)
        .whereType<String>()
        .toSet();
    final changed = ComponentSelectionGuard.pruneBlockedSelections(
      _selections,
      widget.reservedAbilityIds,
      allowIds: allowIds,
    );
    if (changed) {
      setState(() {});
    }
    return changed;
  }

  String? _resolveAbilityId(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (_abilityById.containsKey(trimmed)) {
      return trimmed;
    }
    final lowered = trimmed.toLowerCase();
    try {
      return _abilityById.keys.firstWhere((id) => id.toLowerCase() == lowered);
    } catch (_) {
      return null;
    }
  }

  void _handleAbilitySelection(
    AbilityAllowance allowance,
    int slotIndex,
    String? value,
  ) {
    final resolved = _resolveAbilityId(value);
    final slots = _selections[allowance.id];
    if (slots == null || slotIndex < 0 || slotIndex >= slots.length) return;
    if (slots[slotIndex] == resolved) return;

    setState(() {
      slots[slotIndex] = resolved;
      if (resolved != null) {
        _removeDuplicateSelections(
          abilityId: resolved,
          exceptAllowanceId: allowance.id,
          exceptSlotIndex: slotIndex,
        );
      }
    });

    _notifySelectionChanged();
  }

  void _removeDuplicateSelections({
    required String abilityId,
    required String exceptAllowanceId,
    required int exceptSlotIndex,
  }) {
    for (final entry in _selections.entries) {
      final allowanceId = entry.key;
      final slots = entry.value;
      for (var i = 0; i < slots.length; i++) {
        if (allowanceId == exceptAllowanceId && i == exceptSlotIndex) {
          continue;
        }
        if (slots[i] == abilityId) {
          slots[i] = null;
        }
      }
    }
  }

  void _notifySelectionChanged() {
    if (widget.onSelectionChanged == null) return;
    final plan = _plan;
    if (plan == null) return;

    final selectionsBySlot = <String, String?>{};
    final selectedIds = <String>{};

    for (final entry in _selections.entries) {
      final allowanceId = entry.key;
      final slots = entry.value;
      for (var i = 0; i < slots.length; i++) {
        final value = slots[i];
        final key = _slotKey(allowanceId, i);
        final normalized =
            value != null && _abilityById.containsKey(value) ? value : null;
        selectionsBySlot[key] = normalized;
        if (normalized != null) {
          selectedIds.add(normalized);
        }
      }
    }

    if (_mapEquality.equals(_lastSelectionsSnapshot, selectionsBySlot) &&
        _setEquality.equals(_lastSelectedIdsSnapshot, selectedIds)) {
      return;
    }

    final selectionsSnapshot = Map<String, String?>.from(selectionsBySlot);
    final selectedIdsSnapshot = Set<String>.from(selectedIds);
    _lastSelectionsSnapshot = selectionsSnapshot;
    _lastSelectedIdsSnapshot = selectedIdsSnapshot;
    _selectionCallbackVersion += 1;
    final version = _selectionCallbackVersion;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || version != _selectionCallbackVersion) return;
      widget.onSelectionChanged?.call(
        StartingAbilitySelectionResult(
          selectionsBySlot: Map<String, String?>.from(selectionsSnapshot),
          selectedAbilityIds: Set<String>.from(selectedIdsSnapshot),
        ),
      );
    });
  }

  List<AbilityOption> _optionsForAllowance(AbilityAllowance allowance) {
    return _abilityOptions.where((option) {
      if (allowance.isSignature && !option.isSignature) return false;
      if (!allowance.isSignature && option.isSignature) return false;
      if (allowance.costAmount != null &&
          option.costAmount != allowance.costAmount) {
        return false;
      }
      if (allowance.requiresSubclass) {
        // Subclass abilities must have a subclass field
        if (option.subclass == null || option.subclass!.isEmpty) {
          return false;
        }
        // Only show abilities matching the hero's selected subclass
        final selectedSubclass = widget.selectedSubclassName;
        if (selectedSubclass == null || selectedSubclass.isEmpty) {
          // No subclass selected, don't show any subclass abilities
          return false;
        }
        // Case-insensitive comparison for subclass matching
        if (option.subclass!.toLowerCase() != selectedSubclass.toLowerCase()) {
          return false;
        }
      } else {
        if (option.subclass != null && option.subclass!.isNotEmpty) {
          return false;
        }
      }
      if (allowance.includePreviousLevels) {
        if (option.level > allowance.level) return false;
      } else {
        if (option.level != 0 && option.level != allowance.level) {
          return false;
        }
      }
      return true;
    }).toList()
      ..sort((a, b) {
        if (a.level != b.level) {
          return a.level.compareTo(b.level);
        }
        return a.name.compareTo(b.name);
      });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    if (_isLoading) {
      return _buildContainer(
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_error != null) {
      return _buildContainer(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Failed to load abilities',
                style: AppTextStyles.subtitle.copyWith(color: Colors.redAccent),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
      );
    }

    final plan = _plan;
    if (plan == null || plan.allowances.isEmpty) {
      return _buildContainer(
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'This class does not provide ability selections at this level.',
            style: AppTextStyles.caption,
          ),
        ),
      );
    }

    final totalSlots = plan.allowances.fold<int>(
      0,
      (prev, element) => prev + element.pickCount,
    );
    final selectedCount =
        _selections.values.expand((slots) => slots).whereType<String>().length;

    return _buildContainer(
      child: ExpansionTile(
        key: const PageStorageKey<String>('starting_abilities_expansion'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        initiallyExpanded: _isExpanded,
        maintainState: true,
        onExpansionChanged: (expanded) =>
            setState(() => _isExpanded = expanded),
        title: Text(
          'Abilities',
          style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Selected $selectedCount of $totalSlots options',
          style: AppTextStyles.caption,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: plan.allowances.map(_buildAllowanceSection).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContainer({required Widget child}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: child,
    );
  }

  Widget _buildAllowanceSection(AbilityAllowance allowance) {
    final options = _optionsForAllowance(allowance);
    final slots = _selections[allowance.id] ?? const [];
    final helper = _buildAllowanceHelperText(allowance);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            allowance.label,
            style: AppTextStyles.subtitle.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            helper,
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 8),
          if (options.isEmpty)
            Text(
              'No abilities available for this allowance.',
              style: AppTextStyles.caption,
            )
          else
            ...List.generate(slots.length, (index) {
              final current = slots[index];
              final otherSelected = slots
                  .asMap()
                  .entries
                  .where((entry) => entry.key != index)
                  .map((entry) => entry.value)
                  .whereType<String>()
                  .toSet();
              final reservedIds = <String>{
                ...widget.reservedAbilityIds,
                ...otherSelected,
              };
              final availableOptions = ComponentSelectionGuard.filterAllowed(
                options: options,
                reservedIds: reservedIds,
                idSelector: (option) => option.id,
                currentId: current,
              );
              final selectedOption =
                  current != null ? _abilityById[current] : null;
              return Padding(
                padding:
                    EdgeInsets.only(bottom: index == slots.length - 1 ? 0 : 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String?>(
                      initialValue: current,
                      decoration: InputDecoration(
                        labelText: 'Choice ${index + 1}',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Unassigned'),
                        ),
                        ...availableOptions.map(
                          (option) => DropdownMenuItem<String?>(
                            value: option.id,
                            child: Text(_abilityOptionLabel(option)),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          _handleAbilitySelection(allowance, index, value),
                    ),
                    if (selectedOption != null) ...[
                      const SizedBox(height: 8),
                      AbilityExpandableItem(
                          component: selectedOption.component),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  String _abilityOptionLabel(AbilityOption option) {
    final buffer = StringBuffer(option.name);
    if (option.isSignature) {
      buffer.write(' (Signature)');
    } else if (option.costAmount != null && option.costAmount! > 0) {
      final resource = option.resource;
      if (resource != null && resource.isNotEmpty) {
        buffer.write(' ($resource ${option.costAmount})');
      } else {
        buffer.write(' (Cost ${option.costAmount})');
      }
    } else if (option.resource != null && option.resource!.isNotEmpty) {
      buffer.write(' (${option.resource})');
    }
    if (option.subclass != null && option.subclass!.isNotEmpty) {
      buffer.write(' - ${option.subclass}');
    }
    return buffer.toString();
  }

  String _buildAllowanceHelperText(AbilityAllowance allowance) {
    final buffer = StringBuffer();
    buffer.write(
        'Pick ${allowance.pickCount} ability${allowance.pickCount == 1 ? '' : 'ies'}');
    if (allowance.isSignature) {
      buffer.write(' from the signature list.');
    } else if (allowance.costAmount != null) {
      buffer.write(' costing ${allowance.costAmount}');
      if (allowance.resource != null && allowance.resource!.isNotEmpty) {
        buffer.write(' ${allowance.resource}');
      }
      buffer.write('.');
    } else {
      buffer.write('.');
    }

    if (allowance.requiresSubclass) {
      buffer.write(' Includes subclass abilities.');
    }
    if (allowance.includePreviousLevels) {
      buffer.write(
          ' Unchosen abilities from previous levels are also available.');
    }
    return buffer.toString();
  }

  String _slotKey(String allowanceId, int index) => '$allowanceId#$index';

  String _classSlug(String classId) {
    final normalized = classId.trim().toLowerCase();
    if (normalized.startsWith('class_')) {
      return normalized.substring('class_'.length);
    }
    return normalized;
  }

  int _resolveAbilityLevel(Component component) {
    final data = component.data;
    final level = CharacteristicUtils.toIntOrNull(data['level']);
    if (level != null && level > 0) {
      return level;
    }

    final levelBand = data['level_band'];
    final levelFromBand = _parseLevel(dynamicValue: levelBand);
    if (levelFromBand != null) {
      return levelFromBand;
    }

    final path = data['ability_source_path'];
    final levelFromPath = _parseLevelFromPath(path);
    if (levelFromPath != null) {
      return levelFromPath;
    }

    return 0;
  }

  int? _parseLevel({dynamic dynamicValue}) {
    if (dynamicValue == null) return null;
    if (dynamicValue is num) {
      final numeric = dynamicValue.toInt();
      return numeric > 0 ? numeric : null;
    }
    final value = dynamicValue.toString().trim();
    if (value.isEmpty) return null;

    final normalized = value.toLowerCase();
    final levelMatch =
        RegExp(r'(?:level|lvl)[\s_:-]*([0-9]{1,2})').firstMatch(normalized);
    if (levelMatch != null) {
      return int.tryParse(levelMatch.group(1)!);
    }

    if (RegExp(r'^[0-9]{1,2}$').hasMatch(value)) {
      return int.tryParse(value);
    }

    return null;
  }

  int? _parseLevelFromPath(dynamic pathValue) {
    if (pathValue == null) return null;
    final path = pathValue.toString().trim();
    if (path.isEmpty) return null;

    final segments = path
        .replaceAll('\\', '/')
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();

    for (final segment in segments) {
      final normalizedSegment = segment.toLowerCase();
      if (normalizedSegment.contains('level') ||
          normalizedSegment.contains('lvl')) {
        final level = _parseLevel(dynamicValue: normalizedSegment);
        if (level != null) {
          return level;
        }
      }
    }

    return null;
  }
}
