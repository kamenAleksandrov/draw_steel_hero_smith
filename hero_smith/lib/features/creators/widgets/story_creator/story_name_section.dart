import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/providers.dart';
import '../../../../core/models/component.dart' as model;
import '../../../../core/theme/hero_theme.dart';

class StoryNameSection extends ConsumerWidget {
  const StoryNameSection({
    super.key,
    required this.nameController,
    required this.selectedAncestryId,
    required this.onDirty,
  });

  final TextEditingController nameController;
  final String? selectedAncestryId;
  final VoidCallback onDirty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: HeroTheme.sectionCardElevation,
        shape: const RoundedRectangleBorder(borderRadius: HeroTheme.cardRadius),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Hero Name',
                      hintText: 'Enter your hero\'s name...',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (_) => onDirty(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose an ancestry below for name suggestions!',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  if (selectedAncestryId != null) ...[
                    const SizedBox(height: 16),
                    _buildNameSuggestions(context, ref),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameSuggestions(BuildContext context, WidgetRef ref) {
    final ancestriesAsync = ref.watch(componentsByTypeProvider('ancestry'));
    return ancestriesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (ancestries) {
        final selected = ancestries.firstWhere(
          (a) => a.id == selectedAncestryId,
          orElse: () => const model.Component(id: '', type: 'ancestry', name: 'Unknown'),
        );
        if (selected.id.isEmpty) {
          return const SizedBox.shrink();
        }
        return _ExampleNameGroups(
          ancestry: selected,
          controller: nameController,
          onDirty: onDirty,
        );
      },
    );
  }
}

class _ExampleNameGroups extends StatelessWidget {
  const _ExampleNameGroups({
    required this.ancestry,
    required this.controller,
    required this.onDirty,
  });

  final model.Component ancestry;
  final TextEditingController controller;
  final VoidCallback onDirty;

  @override
  Widget build(BuildContext context) {
    final data = ancestry.data;
    final exampleNames = (data['exampleNames'] as Map?)?.cast<String, dynamic>();
    if (exampleNames == null || exampleNames.isEmpty) {
      return const SizedBox.shrink();
    }

    // Special handling for Revenant notes
    if (ancestry.name.toLowerCase() == 'revenant') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Text(
          'Revenants often keep their names from life; new names reflect their reasons or culture.',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    final exampleLists = <String, List<String>>{};
    const groupLabels = <String, String>{
      'examples': 'Examples',
      'feminine': 'Feminine',
      'masculine': 'Masculine',
      'genderNeutral': 'Gender Neutral',
      'epithets': 'Epithets',
      'surnames': 'Surnames',
    };

    for (final key in groupLabels.keys) {
      final list = (exampleNames[key] as List?)
              ?.map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .map((e) => e.trim())
              .toList() ??
          const <String>[];
      if (list.isNotEmpty) {
        exampleLists[key] = list.cast<String>();
      }
    }

    if (exampleLists.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Example names from ${ancestry.name}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...exampleLists.entries.map((entry) {
          final groupLabel = groupLabels[entry.key] ?? entry.key;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                groupLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final name in entry.value.take(8))
                    ActionChip(
                      label: Text(name),
                      onPressed: () => _applySuggestion(entry.key, name),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  void _applySuggestion(String groupKey, String suggestion) {
    final current = controller.text.trim();
    final isSurname = groupKey == 'surnames';
    final isTimeRaiderEpithet =
        ancestry.name.toLowerCase() == 'time raider' && groupKey == 'epithets';

    if ((isSurname || isTimeRaiderEpithet) && current.isNotEmpty) {
      controller.text = '$current $suggestion';
    } else {
      controller.text = suggestion;
    }
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );
    onDirty();
  }
}
