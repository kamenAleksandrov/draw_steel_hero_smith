import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../../../core/models/class_data.dart';
import '../../../../core/models/component.dart';
import '../../../../core/models/perks_models.dart';
import '../../../../core/services/ability_data_service.dart';
import '../../../../core/services/perk_data_service.dart';
import '../../../../core/services/perks_service.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../widgets/abilities/ability_expandable_item.dart';
import '../../../../core/utils/selection_guard.dart';

typedef PerkSelectionChanged = void Function(StartingPerkSelectionResult result);

class StartingPerksWidget extends StatefulWidget {
  const StartingPerksWidget({
    super.key,
    required this.classData,
    required this.selectedLevel,
    this.selectedPerks = const <String, String?>{},
    this.reservedPerkIds = const <String>{},
    this.onSelectionChanged,
  });

  final ClassData classData;
  final int selectedLevel;
  final Map<String, String?> selectedPerks;
  final Set<String> reservedPerkIds;
  final PerkSelectionChanged? onSelectionChanged;

  @override
  State<StartingPerksWidget> createState() => _StartingPerksWidgetState();
}

class _StartingPerksWidgetState extends State<StartingPerksWidget> {
  final StartingPerksService _service = const StartingPerksService();
  final PerkDataService _perkDataService = PerkDataService();
  final AbilityDataService _abilityDataService = AbilityDataService();
  final MapEquality<String, String?> _mapEquality =
      const MapEquality<String, String?>();
  final SetEquality<String> _setEquality = const SetEquality<String>();

  bool _isExpanded = false;
  bool _isLoading = true;
  String? _error;

  List<PerkOption> _perkOptions = const <PerkOption>[];
  Map<String, PerkOption> _perkById = const <String, PerkOption>{};
  Map<String, String> _perkIdByName = const <String, String>{};
  AbilityLibrary? _abilityLibrary;

  StartingPerkPlan? _plan;
  final Map<String, List<String?>> _selections = {};

  Map<String, String?> _lastSelectionsSnapshot = const {};
  Set<String> _lastSelectedIdsSnapshot = const {};
  int _selectionCallbackVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadPerks();
  }

  @override
  void didUpdateWidget(covariant StartingPerksWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final classChanged =
        oldWidget.classData.classId != widget.classData.classId;
    final levelChanged = oldWidget.selectedLevel != widget.selectedLevel;
    final reservedChanged = !_setEquality.equals(
      oldWidget.reservedPerkIds,
      widget.reservedPerkIds,
    );
    if ((classChanged || levelChanged) && !_isLoading && _error == null) {
      _rebuildPlan(
        preserveSelections: !classChanged,
        externalSelections: classChanged ? const {} : widget.selectedPerks,
      );
    } else if (!_mapEquality.equals(
        oldWidget.selectedPerks, widget.selectedPerks)) {
      _applyExternalSelections(widget.selectedPerks);
    }
    if (reservedChanged && !_isLoading && _error == null) {
      final changed = _applyReservedPruning();
      if (changed) {
        _notifySelectionChanged();
      }
    }
  }

  Future<void> _loadPerks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final perksFuture = _perkDataService.loadPerks();
      final abilitiesFuture = _abilityDataService.loadLibrary();

      final perks = await perksFuture;
      final abilityLibrary = await abilitiesFuture;
      if (!mounted) return;
      _perkOptions = perks;
      _perkById = {
        for (final option in perks) option.id: option,
      };
      _perkIdByName = {
        for (final option in perks) option.name.toLowerCase(): option.id,
      };
      _abilityLibrary = abilityLibrary;
      _rebuildPlan(
        preserveSelections: false,
        externalSelections: widget.selectedPerks,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Failed to load perks or abilities: $e';
      });
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
    final external = externalSelections ?? widget.selectedPerks;

    for (final allowance in plan.allowances) {
      final existing =
          preserveSelections ? (_selections[allowance.id] ?? const []) : const [];
      final updated = List<String?>.filled(allowance.pickCount, null);

      for (var i = 0; i < allowance.pickCount; i++) {
        String? value;
        if (preserveSelections && i < existing.length) {
          value = existing[i];
        }
        final key = _slotKey(allowance.id, i);
        if (external.containsKey(key)) {
          value = external[key];
        }
        updated[i] = _resolvePerkId(value);
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
      final resolved = _resolvePerkId(value);
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
    if (widget.reservedPerkIds.isEmpty) return false;
    final allowIds = _selections.values
        .expand((slots) => slots)
        .whereType<String>()
        .toSet();
    final changed = ComponentSelectionGuard.pruneBlockedSelections(
      _selections,
      widget.reservedPerkIds,
      allowIds: allowIds,
    );
    if (changed) {
      setState(() {});
    }
    return changed;
  }

  String? _resolvePerkId(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (_perkById.containsKey(trimmed)) {
      return trimmed;
    }
    return _perkIdByName[trimmed.toLowerCase()];
  }

  void _handlePerkSelection(
    PerkAllowance allowance,
    int slotIndex,
    String? value,
  ) {
    final resolved = _resolvePerkId(value);
    final slots = _selections[allowance.id];
    if (slots == null || slotIndex < 0 || slotIndex >= slots.length) {
      return;
    }
    if (slots[slotIndex] == resolved) return;

    setState(() {
      slots[slotIndex] = resolved;
      if (resolved != null) {
        _removeDuplicateSelections(
          perkId: resolved,
          exceptAllowanceId: allowance.id,
          exceptSlotIndex: slotIndex,
        );
      }
    });

    _notifySelectionChanged();
  }
  void _removeDuplicateSelections({
    required String perkId,
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
        if (slots[i] == perkId) {
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
    for (final entry in _selections.entries) {
      final allowanceId = entry.key;
      final slots = entry.value;
      for (var i = 0; i < slots.length; i++) {
        final value = slots[i];
        final normalized =
            value != null && _perkById.containsKey(value) ? value : null;
        selectionsBySlot[_slotKey(allowanceId, i)] = normalized;
      }
    }

    final selectedIds = selectionsBySlot.values.whereType<String>().toSet();

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
        StartingPerkSelectionResult(
          selectionsBySlot:
              Map<String, String?>.from(selectionsSnapshot),
          selectedPerkIds: Set<String>.from(selectedIdsSnapshot),
        ),
      );
    });
  }

  List<PerkOption> _optionsForAllowance(PerkAllowance allowance) {
    if (allowance.allowedGroups.isEmpty) {
      return _perkOptions;
    }
    return _perkOptions
        .where((option) => allowance.allowedGroups.contains(option.group))
        .toList();
  }

  String _slotKey(String allowanceId, int index) => '$allowanceId#$index';

  @override
  Widget build(BuildContext context) {
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
                'Failed to load perks',
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
            'This class does not grant additional perk picks.',
            style: AppTextStyles.caption,
          ),
        ),
      );
    }

    final totalSlots = plan.allowances.fold<int>(
      0,
      (prev, allowance) => prev + allowance.pickCount,
    );
    final assigned =
        _selections.values.expand((slots) => slots).whereType<String>().length;

    return _buildContainer(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        initiallyExpanded: _isExpanded,
        onExpansionChanged: (expanded) =>
            setState(() => _isExpanded = expanded),
        title: Text(
          'Perks',
          style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Selected $assigned of $totalSlots options',
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

  Widget _buildAllowanceSection(PerkAllowance allowance) {
    final options = _optionsForAllowance(allowance);
    final slots = _selections[allowance.id] ?? const [];

    final allowedGroupsText = allowance.allowedGroups.isEmpty
        ? 'Any perk'
        : allowance.allowedGroups
            .map((group) => group.isEmpty
                ? 'Any'
                : group[0].toUpperCase() + group.substring(1))
            .join(', ');

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
            'Pick ${allowance.pickCount} perk${allowance.pickCount == 1 ? '' : 's'} from: $allowedGroupsText',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 8),
          ...List.generate(slots.length, (index) {
            final current = slots[index];
            final selectedPerk = current != null ? _perkById[current] : null;
            final otherSelected = slots
                .asMap()
                .entries
                .where((entry) => entry.key != index)
                .map((entry) => entry.value)
                .whereType<String>()
                .toSet();
            final reservedIds = <String>{
              ...widget.reservedPerkIds,
              ...otherSelected,
            };
            final availableOptions = ComponentSelectionGuard.filterAllowed(
              options: options,
              reservedIds: reservedIds,
              idSelector: (option) => option.id,
              currentId: current,
            );
            return Padding(
              padding:
                  EdgeInsets.only(bottom: index == slots.length - 1 ? 0 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String?>(
                    value: current,
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
                          child: Text(
                            option.group.isEmpty
                                ? option.name
                                : '${option.name} (${_formatGroup(option.group)})',
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        _handlePerkSelection(allowance, index, value),
                  ),
                  if (selectedPerk != null) ...[
                    const SizedBox(height: 8),
                    _buildPerkDetails(context, selectedPerk),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPerkDetails(BuildContext context, PerkOption perk) {
    final theme = Theme.of(context);
    final borderColor = theme.dividerColor.withOpacity(0.4);
    final background = theme.colorScheme.surfaceVariant.withOpacity(0.2);
    final groupLabel = perk.group.isEmpty
        ? 'Any group'
        : '${_formatGroup(perk.group)} group';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
        color: background,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            groupLabel,
            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            perk.description,
            style: AppTextStyles.body,
          ),
          if (perk.grantedAbilities.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              perk.grantedAbilities.length == 1
                  ? 'Grants ability:'
                  : 'Grants abilities:',
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            ...List.generate(perk.grantedAbilities.length, (index) {
              final abilityLabel = perk.grantedAbilities[index];
              final component = _resolveAbilityComponent(abilityLabel);
              final isLast = index == perk.grantedAbilities.length - 1;
              if (component != null) {
                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                  child: AbilityExpandableItem(component: component),
                );
              }
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 4),
                child: Text(
                  '• $abilityLabel',
                  style: AppTextStyles.caption,
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  static String _formatGroup(String value) {
    if (value.isEmpty) return value;
    final parts = value
        .split(RegExp(r'[_\s]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1));
    return parts.join(' ');
  }

  Component? _resolveAbilityComponent(String reference) {
    final library = _abilityLibrary;
    if (library == null) return null;
    final primary = library.find(reference);
    if (primary != null) return primary;

    final trimmed = reference.trim();
    if (trimmed.isEmpty) return null;

    final withoutParen = trimmed.replaceAll(RegExp(r'\s*\([^)]*\)'), '');
    if (withoutParen != trimmed) {
      final fallback = library.find(withoutParen);
      if (fallback != null) return fallback;
    }

    final beforeColon = trimmed.split(':').first;
    if (beforeColon != trimmed) {
      return library.find(beforeColon);
    }
    return null;
  }
}
