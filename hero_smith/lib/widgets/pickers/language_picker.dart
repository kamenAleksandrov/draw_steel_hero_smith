import 'package:flutter/material.dart';

import '../../core/models/component.dart';
import '../../core/theme/strife_theme.dart';

class LanguageAllowance {
  const LanguageAllowance({
    required this.level,
    required this.count,
    required this.types,
    required this.label,
  });

  final int level;
  final int count;
  final Set<String> types;
  final String label;

  bool allowsType(String? type) {
    if (types.isEmpty) return true;
    final normalized = type?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return types.contains('any');
    }
    return types.contains(normalized);
  }
}

typedef LanguageSelectionChanged = void Function(
  int allowanceIndex,
  int slotIndex,
  String? languageId,
);

class LanguagePickerCard extends StatelessWidget {
  const LanguagePickerCard({
    super.key,
    required this.allowances,
    required this.languageComponents,
    required this.selections,
    required this.onSelectionChanged,
  });

  final List<LanguageAllowance> allowances;
  final List<Component> languageComponents;
  final Map<int, List<String?>> selections;
  final LanguageSelectionChanged onSelectionChanged;

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
              title: 'Languages',
              subtitle: 'Assign languages granted by your class progression.',
              icon: Icons.language_outlined,
              accent: StrifeTheme.levelAccent,
            ),
            Padding(
              padding: StrifeTheme.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$selectedTotal of $totalAllowed language slots filled.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  for (var index = 0; index < allowances.length; index++) ...[
                    _LanguageAllowanceTile(
                      allowanceIndex: index,
                      allowance: allowances[index],
                      languageComponents: languageComponents,
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

class _LanguageAllowanceTile extends StatelessWidget {
  const _LanguageAllowanceTile({
    required this.allowanceIndex,
    required this.allowance,
    required this.languageComponents,
    required this.selections,
    required this.allSelections,
    required this.onSelectionChanged,
  });

  final int allowanceIndex;
  final LanguageAllowance allowance;
  final List<Component> languageComponents;
  final List<String?> selections;
  final Map<int, List<String?>> allSelections;
  final LanguageSelectionChanged onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedCount = selections.whereType<String>().length;
    final remaining = allowance.count - selectedCount;
    final helperText = remaining > 0
        ? '$remaining pick${remaining == 1 ? '' : 's'} remaining.'
        : 'All picks used.';

    final restrictionLabel = allowance.types.isEmpty
        ? 'Any language'
        : allowance.types.map(_capitalize).join(', ');

    return ExpansionTile(
      key: ValueKey('language_allowance_$allowanceIndex'),
      title: Text(
        '${allowance.label} ($selectedCount of ${allowance.count})',
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
      subtitle: Text('$helperText · $restrictionLabel', style: theme.textTheme.bodySmall),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      maintainState: true,
      children: [
        const SizedBox(height: 8),
        for (var slotIndex = 0; slotIndex < selections.length; slotIndex++) ...[
          _LanguageSlotPicker(
            allowanceIndex: allowanceIndex,
            slotIndex: slotIndex,
            allowance: allowance,
            languageComponents: languageComponents,
            currentId: selections[slotIndex],
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

class _LanguageSlotPicker extends StatelessWidget {
  const _LanguageSlotPicker({
    required this.allowanceIndex,
    required this.slotIndex,
    required this.allowance,
    required this.languageComponents,
    required this.currentId,
    required this.allSelections,
    required this.onSelectionChanged,
  });

  final int allowanceIndex;
  final int slotIndex;
  final LanguageAllowance allowance;
  final List<Component> languageComponents;
  final String? currentId;
  final Map<int, List<String?>> allSelections;
  final LanguageSelectionChanged onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Map<String, Component> componentById = {
      for (final language in languageComponents) language.id: language,
    };

    final selectedElsewhere = allSelections.entries
        .where((entry) => entry.key != allowanceIndex)
        .expand((entry) => entry.value)
        .whereType<String>()
        .toSet();

    final eligibleLanguages = languageComponents
        .where((language) => allowance.allowsType(
              language.data['language_type']?.toString().trim().toLowerCase(),
            ))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final dropdownItems = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('— Choose language —'),
      ),
    ];

    for (final language in eligibleLanguages) {
      final isTakenElsewhere =
          selectedElsewhere.contains(language.id) && language.id != currentId;
      if (isTakenElsewhere) continue;
      final type = language.data['language_type']?.toString() ?? 'Unknown';
      dropdownItems.add(
        DropdownMenuItem<String?>(
          value: language.id,
          child: Text('${language.name} (${_capitalize(type)})'),
        ),
      );
    }

    final selectedComponent =
        currentId != null ? componentById[currentId] : null;
    final region = selectedComponent?.data['region']?.toString();
    final related = (selectedComponent?.data['related_languages'] as List?)
            ?.whereType<String>()
            .toList() ??
        const <String>[];

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
            onChanged: eligibleLanguages.isEmpty
                ? null
                : (value) => onSelectionChanged(allowanceIndex, slotIndex, value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.translate),
              labelText: 'Choose language',
            ),
          ),
          if (region != null && region.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.public, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Region: $region',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
          if (related.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.link, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Related: ${related.join(', ')}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
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
          if (eligibleLanguages.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'No languages available for the required types yet.',
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
