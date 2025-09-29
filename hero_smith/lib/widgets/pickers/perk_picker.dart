import 'package:flutter/material.dart';

import '../../core/models/component.dart';
import '../../core/theme/strife_theme.dart';

class PerkAllowance {
  const PerkAllowance({
    required this.level,
    required this.count,
    required this.groups,
    required this.label,
  });

  final int level;
  final int count;
  final Set<String> groups;
  final String label;

  bool allowsGroup(String? group) {
    if (groups.isEmpty) return true;
    final normalized = group?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return groups.contains('any');
    }
    return groups.contains(normalized);
  }
}

typedef PerkSelectionChanged = void Function(
  int allowanceIndex,
  int slotIndex,
  String? perkId,
);

class PerkPickerCard extends StatelessWidget {
  const PerkPickerCard({
    super.key,
    required this.allowances,
    required this.perkComponents,
    required this.selections,
    required this.onSelectionChanged,
  });

  final List<PerkAllowance> allowances;
  final List<Component> perkComponents;
  final Map<int, List<String?>> selections;
  final PerkSelectionChanged onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    if (allowances.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final totalAllowed = allowances.fold<int>(0, (sum, allowance) => sum + allowance.count);
    final selectedTotal = selections.values
        .expand((slots) => slots)
        .whereType<String>()
        .length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: StrifeTheme.cardElevation,
        shape: const RoundedRectangleBorder(borderRadius: StrifeTheme.cardRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StrifeTheme.sectionHeader(
              context,
              title: 'Perks',
              subtitle: 'Select perks based on class allowances.',
              icon: Icons.workspace_premium_outlined,
              accent: StrifeTheme.featuresAccent,
            ),
            Padding(
              padding: StrifeTheme.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$selectedTotal of $totalAllowed perk slots filled.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  for (var index = 0; index < allowances.length; index++) ...[
                    _PerkAllowanceTile(
                      allowanceIndex: index,
                      allowance: allowances[index],
                      perkComponents: perkComponents,
                      selections: selections[index] ?? List<String?>.filled(allowances[index].count, null),
                      allSelections: selections,
                      onSelectionChanged: onSelectionChanged,
                    ),
                    if (index < allowances.length - 1) const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PerkAllowanceTile extends StatelessWidget {
  const _PerkAllowanceTile({
    required this.allowanceIndex,
    required this.allowance,
    required this.perkComponents,
    required this.selections,
    required this.allSelections,
    required this.onSelectionChanged,
  });

  final int allowanceIndex;
  final PerkAllowance allowance;
  final List<Component> perkComponents;
  final List<String?> selections;
  final Map<int, List<String?>> allSelections;
  final PerkSelectionChanged onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedCount = selections.whereType<String>().length;
    final remaining = allowance.count - selectedCount;
    final helperText = remaining > 0
        ? '$remaining pick${remaining == 1 ? '' : 's'} remaining.'
        : 'All picks used.';

    return ExpansionTile(
      key: ValueKey('perk_allowance_$allowanceIndex'),
      title: Text(
        '${allowance.label} ($selectedCount of ${allowance.count})',
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(helperText, style: theme.textTheme.bodySmall),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      maintainState: true,
      children: [
        const SizedBox(height: 8),
        for (var slotIndex = 0; slotIndex < selections.length; slotIndex++) ...[
          _PerkSlotPicker(
            allowanceIndex: allowanceIndex,
            slotIndex: slotIndex,
            allowance: allowance,
            currentId: selections[slotIndex],
            perkComponents: perkComponents,
            allSelections: allSelections,
            onSelectionChanged: onSelectionChanged,
          ),
          if (slotIndex < selections.length - 1) const SizedBox(height: 8),
        ],
        const SizedBox(height: 4),
      ],
    );
  }
}

class _PerkSlotPicker extends StatelessWidget {
  const _PerkSlotPicker({
    required this.allowanceIndex,
    required this.slotIndex,
    required this.allowance,
    required this.currentId,
    required this.perkComponents,
    required this.allSelections,
    required this.onSelectionChanged,
  });

  final int allowanceIndex;
  final int slotIndex;
  final PerkAllowance allowance;
  final String? currentId;
  final List<Component> perkComponents;
  final Map<int, List<String?>> allSelections;
  final PerkSelectionChanged onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Map<String, Component> componentById = {
      for (final perk in perkComponents) perk.id: perk,
    };
    final selectedElsewhere = allSelections.entries
        .where((entry) => entry.key != allowanceIndex)
        .expand((entry) => entry.value)
        .whereType<String>()
        .toSet();

    final eligiblePerks = perkComponents
        .where((perk) => allowance.allowsGroup(
              perk.data['group']?.toString().trim().toLowerCase(),
            ))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final dropdownItems = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('— Choose perk —'),
      ),
    ];

    for (final perk in eligiblePerks) {
      final isTakenElsewhere =
          selectedElsewhere.contains(perk.id) && perk.id != currentId;
      if (isTakenElsewhere) continue;
      final group =
          perk.data['group']?.toString().trim().toLowerCase() ?? 'any';
      dropdownItems.add(
        DropdownMenuItem<String?>(
          value: perk.id,
          child: Text('${perk.name} (${_capitalize(group)})'),
        ),
      );
    }

    final selectedComponent =
        currentId != null ? componentById[currentId] : null;
    final summary = selectedComponent?.data['description']?.toString();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.15),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pick ${slotIndex + 1}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            value: currentId,
            items: dropdownItems,
            onChanged: eligiblePerks.isEmpty
                ? null
                : (value) => onSelectionChanged(allowanceIndex, slotIndex, value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.workspace_premium_outlined),
              labelText: 'Choose perk',
            ),
          ),
          if (summary != null && summary.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              summary,
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (currentId != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => onSelectionChanged(allowanceIndex, slotIndex, null),
                icon: const Icon(Icons.clear),
                label: const Text('Clear selection'),
              ),
            ),
          ],
          if (eligiblePerks.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'No perks available for the required groups yet.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

String _capitalize(String value) {
  if (value.isEmpty) return value;
  return value.substring(0, 1).toUpperCase() + value.substring(1);
}
