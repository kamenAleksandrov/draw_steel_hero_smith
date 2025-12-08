import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/providers.dart';
import '../../../../core/models/class_data.dart';
import '../../../../core/models/component.dart' as model;
import '../../../../core/models/perks_models.dart';
import '../../../../core/services/perks_service.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/selection_guard.dart';
import '../../../../widgets/abilities/ability_expandable_item.dart';
import '../../../../widgets/perks/perks_selection_widget.dart';

typedef PerkSelectionChanged = void Function(StartingPerkSelectionResult result);

/// Widget for selecting starting perks based on class levels.
/// Uses the shared PerksSelectionWidget components for consistent UI.
class StartingPerksWidget extends ConsumerStatefulWidget {
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
  ConsumerState<StartingPerksWidget> createState() => _StartingPerksWidgetState();
}

class _StartingPerksWidgetState extends ConsumerState<StartingPerksWidget> {
  final StartingPerksService _service = const StartingPerksService();
  final MapEquality<String, String?> _mapEquality =
      const MapEquality<String, String?>();
  final SetEquality<String> _setEquality = const SetEquality<String>();

  bool _isExpanded = false;

  StartingPerkPlan? _plan;
  final Map<String, List<String?>> _selections = {};

  Map<String, String?> _lastSelectionsSnapshot = const {};
  Set<String> _lastSelectedIdsSnapshot = const {};
  int _selectionCallbackVersion = 0;

  @override
  void initState() {
    super.initState();
    _rebuildPlan(
      preserveSelections: false,
      externalSelections: widget.selectedPerks,
    );
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
    if (classChanged || levelChanged) {
      _rebuildPlan(
        preserveSelections: !classChanged,
        externalSelections: classChanged ? const {} : widget.selectedPerks,
      );
    } else if (!_mapEquality.equals(
        oldWidget.selectedPerks, widget.selectedPerks)) {
      _applyExternalSelections(widget.selectedPerks);
    }
    if (reservedChanged) {
      final changed = _applyReservedPruning();
      if (changed) {
        _notifySelectionChanged();
      }
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
        updated[i] = value;
      }

      newSelections[allowance.id] = updated;
    }

    setState(() {
      _plan = plan;
      _selections
        ..clear()
        ..addAll(newSelections);
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
      if (slots[slotIndex] != value) {
        slots[slotIndex] = value;
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

  void _handlePerkSelection(
    PerkAllowance allowance,
    int slotIndex,
    String? value,
  ) {
    final slots = _selections[allowance.id];
    if (slots == null || slotIndex < 0 || slotIndex >= slots.length) {
      return;
    }
    if (slots[slotIndex] == value) return;

    setState(() {
      slots[slotIndex] = value;
      if (value != null) {
        _removeDuplicateSelections(
          perkId: value,
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
        selectionsBySlot[_slotKey(allowanceId, i)] = slots[i];
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
          selectionsBySlot: Map<String, String?>.from(selectionsSnapshot),
          selectedPerkIds: Set<String>.from(selectedIdsSnapshot),
        ),
      );
    });
  }

  String _slotKey(String allowanceId, int index) => '$allowanceId#$index';

  @override
  Widget build(BuildContext context) {
    final perksAsync = ref.watch(componentsByTypeProvider('perk'));

    return perksAsync.when(
      loading: () => _buildContainer(
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => _buildContainer(
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
                e.toString(),
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
      ),
      data: (perks) => _buildContent(context, perks),
    );
  }

  Widget _buildContent(BuildContext context, List<model.Component> perks) {
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

    final perkMap = {for (final perk in perks) perk.id: perk};

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
              children: plan.allowances
                  .map((allowance) => _buildAllowanceSection(
                        context,
                        allowance,
                        perks,
                        perkMap,
                      ))
                  .toList(),
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

  Widget _buildAllowanceSection(
    BuildContext context,
    PerkAllowance allowance,
    List<model.Component> allPerks,
    Map<String, model.Component> perkMap,
  ) {
    // Filter perks by allowance groups
    final options = allowance.allowedGroups.isEmpty
        ? allPerks
        : allPerks.where((perk) {
            final group = (perk.data['group'] ??
                    perk.data['perk_type'] ??
                    perk.data['perkType'])
                ?.toString()
                .toLowerCase()
                .trim();
            return group != null && allowance.allowedGroups.contains(group);
          }).toList();
    options.sort((a, b) => a.name.compareTo(b.name));

    final slots = _selections[allowance.id] ?? const [];

    final allowedGroupsText = allowance.allowedGroups.isEmpty
        ? 'Any perk'
        : allowance.allowedGroups
            .map((group) => group.isEmpty
                ? 'Any'
                : group[0].toUpperCase() + group.substring(1))
            .join(', ');

    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.tertiary;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: borderColor.withOpacity(0.6), width: 1.4),
    );

    // Group perks for searchable picker
    final grouped = <String, List<model.Component>>{};
    for (final perk in options) {
      final rawType = (perk.data['group'] ??
              perk.data['perk_type'] ??
              perk.data['perkType'])
          ?.toString();
      final key = _formatGroupLabel(rawType);
      grouped.putIfAbsent(key, () => []).add(perk);
    }
    final sortedGroupKeys = grouped.keys.toList()..sort();
    for (final list in grouped.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }

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
            final selectedPerk = current != null ? perkMap[current] : null;
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

            return Padding(
              padding:
                  EdgeInsets.only(bottom: index == slots.length - 1 ? 0 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => _openPerkPicker(
                      context,
                      allowance,
                      index,
                      current,
                      grouped,
                      sortedGroupKeys,
                      reservedIds,
                    ),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Choice ${index + 1}',
                        border: border,
                        enabledBorder: border,
                        suffixIcon: const Icon(Icons.search),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      child: Text(
                        current != null
                            ? (perkMap[current]?.name ?? 'Unknown')
                            : '— Choose perk —',
                        style: TextStyle(
                          fontSize: 16,
                          color: current != null
                              ? theme.textTheme.bodyLarge?.color
                              : theme.hintColor,
                        ),
                      ),
                    ),
                  ),
                  if (selectedPerk != null) ...[
                    const SizedBox(height: 8),
                    _buildPerkDetails(context, selectedPerk, borderColor),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _openPerkPicker(
    BuildContext context,
    PerkAllowance allowance,
    int slotIndex,
    String? currentValue,
    Map<String, List<model.Component>> grouped,
    List<String> sortedGroupKeys,
    Set<String> reservedIds,
  ) async {
    final options = <SearchOption<String?>>[
      const SearchOption<String?>(
        label: '— Choose perk —',
        value: null,
      ),
    ];

    for (final key in sortedGroupKeys) {
      for (final perk in grouped[key]!) {
        if (perk.id != currentValue && reservedIds.contains(perk.id)) {
          continue;
        }
        options.add(
          SearchOption<String?>(
            label: perk.name,
            value: perk.id,
            subtitle: key,
          ),
        );
      }
    }

    final result = await showSearchablePicker<String?>(
      context: context,
      title: 'Select Perk',
      options: options,
      selected: currentValue,
    );

    if (result == null) return;
    _handlePerkSelection(allowance, slotIndex, result.value);
  }

  Widget _buildPerkDetails(
    BuildContext context,
    model.Component perk,
    Color borderColor,
  ) {
    final theme = Theme.of(context);
    final group = (perk.data['group'] ??
            perk.data['perk_type'] ??
            perk.data['perkType'])
        ?.toString();
    final groupLabel = group == null || group.isEmpty
        ? 'Any group'
        : '${_formatGroupLabel(group)} group';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor.withOpacity(0.4)),
        color: borderColor.withOpacity(0.08),
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
            perk.data['description']?.toString() ?? 'No description available',
            style: AppTextStyles.body,
          ),
          _buildGrantedAbilities(context, perk, borderColor),
        ],
      ),
    );
  }

  Widget _buildGrantedAbilities(
    BuildContext context,
    model.Component perk,
    Color borderColor,
  ) {
    final grantsRaw = perk.data['grants'];
    if (grantsRaw == null) return const SizedBox.shrink();

    final grants = grantsRaw is List
        ? grantsRaw
        : (grantsRaw is Map ? [grantsRaw] : null);
    if (grants == null || grants.isEmpty) return const SizedBox.shrink();

    // Extract ability names from grants
    final abilityNames = <String>[];
    for (final grant in grants) {
      if (grant is Map && grant.containsKey('ability')) {
        final abilityName = grant['ability']?.toString();
        if (abilityName != null && abilityName.isNotEmpty) {
          abilityNames.add(abilityName);
        }
      }
    }

    if (abilityNames.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          abilityNames.length == 1 ? 'Grants ability:' : 'Grants abilities:',
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        ...abilityNames.map((name) => _AbilityGrantItem(abilityName: name)),
      ],
    );
  }

  String _formatGroupLabel(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) {
      return 'General';
    }
    return value
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split(RegExp(r'\s+'))
        .where((segment) => segment.isNotEmpty)
        .map((segment) =>
            '${segment[0].toUpperCase()}${segment.substring(1).toLowerCase()}')
        .join(' ');
  }
}

/// Widget that displays a granted ability by looking it up
class _AbilityGrantItem extends ConsumerWidget {
  const _AbilityGrantItem({required this.abilityName});

  final String abilityName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final abilityAsync = ref.watch(abilityByNameProvider(abilityName));

    return abilityAsync.when(
      data: (ability) {
        if (ability == null) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '• $abilityName',
              style: AppTextStyles.caption,
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AbilityExpandableItem(component: ability),
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
            const SizedBox(width: 8),
            Text('Loading $abilityName...', style: AppTextStyles.caption),
          ],
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text('• $abilityName', style: AppTextStyles.caption),
      ),
    );
  }
}
