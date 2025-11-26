import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/providers.dart';
import '../../../../core/models/complication_grant_models.dart';
import '../../../../core/models/component.dart' as model;
import '../../../../widgets/treasures/treasures.dart';

class _SearchOption<T> {
  const _SearchOption({
    required this.label,
    required this.value,
    this.subtitle,
  });

  final String label;
  final T? value;
  final String? subtitle;
}

class _PickerSelection<T> {
  const _PickerSelection({required this.value});

  final T? value;
}

Future<_PickerSelection<T>?> _showSearchablePicker<T>({
  required BuildContext context,
  required String title,
  required List<_SearchOption<T>> options,
  T? selected,
}) {
  return showDialog<_PickerSelection<T>>(
    context: context,
    builder: (dialogContext) {
      final controller = TextEditingController();
      var query = '';

      return StatefulBuilder(
        builder: (context, setState) {
          final normalizedQuery = query.trim().toLowerCase();
          final List<_SearchOption<T>> filtered = normalizedQuery.isEmpty
              ? options
              : options
                  .where(
                    (option) =>
                        option.label.toLowerCase().contains(normalizedQuery) ||
                        (option.subtitle?.toLowerCase().contains(
                              normalizedQuery,
                            ) ??
                            false),
                  )
                  .toList();

          return Dialog(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
                maxWidth: 500,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          query = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: filtered.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: Text('No matches found')),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final option = filtered[index];
                              final isSelected = option.value == selected ||
                                  (option.value == null && selected == null);
                              return ListTile(
                                title: Text(option.label),
                                subtitle: option.subtitle != null
                                    ? Text(option.subtitle!)
                                    : null,
                                trailing: isSelected
                                    ? const Icon(Icons.check)
                                    : null,
                                onTap: () => Navigator.of(context).pop(
                                  _PickerSelection<T>(value: option.value),
                                ),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
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

class StoryComplicationSection extends ConsumerStatefulWidget {
  const StoryComplicationSection({
    super.key,
    required this.selectedComplicationId,
    required this.complicationChoices,
    required this.onComplicationChanged,
    required this.onChoicesChanged,
    required this.onDirty,
  });

  final String? selectedComplicationId;
  final Map<String, String> complicationChoices;
  final ValueChanged<String?> onComplicationChanged;
  final ValueChanged<Map<String, String>> onChoicesChanged;
  final VoidCallback onDirty;

  @override
  ConsumerState<StoryComplicationSection> createState() =>
      _StoryComplicationSectionState();
}

class _StoryComplicationSectionState
    extends ConsumerState<StoryComplicationSection> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final complicationsAsync = ref.watch(componentsByTypeProvider('complication'));

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Complication',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a complication that adds depth to your character',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            complicationsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Failed to load complications: $error',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ),
              data: (complications) {
                if (complications.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No complications available'),
                  );
                }

                final sorted = [...complications];
                sorted.sort((a, b) => a.name.compareTo(b.name));

                final selectedComp = widget.selectedComplicationId != null
                    ? sorted.firstWhere(
                        (c) => c.id == widget.selectedComplicationId,
                        orElse: () => sorted.first,
                      )
                    : null;

                Future<void> openSearch() async {
                  final options = <_SearchOption<String?>>[
                    const _SearchOption<String?>(
                      label: 'None',
                      value: null,
                    ),
                    ...sorted.map(
                      (comp) => _SearchOption<String?>(
                        label: comp.name,
                        value: comp.id,
                      ),
                    ),
                  ];

                  final result = await _showSearchablePicker<String?>(
                    context: context,
                    title: 'Select Complication',
                    options: options,
                    selected: widget.selectedComplicationId,
                  );

                  if (result == null) return;
                  widget.onComplicationChanged(result.value);
                  widget.onDirty();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      onTap: openSearch,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Select Complication',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.search),
                        ),
                        child: Text(
                          selectedComp != null ? selectedComp.name : 'None',
                          style: TextStyle(
                            fontSize: 16,
                            color: selectedComp != null
                                ? theme.textTheme.bodyLarge?.color
                                : theme.hintColor,
                          ),
                        ),
                      ),
                    ),
                    if (selectedComp != null) ...[
                      const SizedBox(height: 24),
                      _ComplicationDetails(
                        complication: selectedComp,
                        choices: widget.complicationChoices,
                        onChoicesChanged: (choices) {
                          widget.onChoicesChanged(choices);
                          widget.onDirty();
                        },
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ComplicationDetails extends ConsumerWidget {
  const _ComplicationDetails({
    required this.complication,
    required this.choices,
    required this.onChoicesChanged,
  });

  final dynamic complication;
  final Map<String, String> choices;
  final ValueChanged<Map<String, String>> onChoicesChanged;

  void _updateChoice(String key, String? value) {
    final newChoices = Map<String, String>.from(choices);
    if (value == null || value.isEmpty) {
      newChoices.remove(key);
    } else {
      newChoices[key] = value;
    }
    onChoicesChanged(newChoices);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final data = complication.data;
    final complicationId = complication.id as String;

    // Parse grants
    final grantsData = data['grants'] as Map<String, dynamic>?;
    List<ComplicationGrant> grants = [];
    if (grantsData != null) {
      grants = ComplicationGrant.parseFromGrantsData(
        grantsData,
        complicationId,
        complication.name as String,
        choices,
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            complication.name,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (data['description'] != null) ...[
            Text(
              data['description'].toString(),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
          ],
          if (data['effects'] != null) ...[
            _buildEffects(context, data['effects']),
            const SizedBox(height: 12),
          ],
          if (grants.isNotEmpty) ...[
            _buildGrantsSection(context, ref, grants, complicationId),
          ],
        ],
      ),
    );
  }

  Widget _buildEffects(BuildContext context, dynamic effects) {
    final theme = Theme.of(context);
    final effectsData = effects as Map<String, dynamic>?;
    if (effectsData == null) return const SizedBox.shrink();

    final benefit = effectsData['benefit']?.toString();
    final drawback = effectsData['drawback']?.toString();
    final both = effectsData['both']?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Effects',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (benefit != null && benefit.isNotEmpty) ...[
          _buildEffectItem(
            context,
            'Benefit',
            benefit,
            theme.colorScheme.primary,
            Icons.add_circle_outline,
          ),
          const SizedBox(height: 8),
        ],
        if (drawback != null && drawback.isNotEmpty) ...[
          _buildEffectItem(
            context,
            'Drawback',
            drawback,
            theme.colorScheme.error,
            Icons.remove_circle_outline,
          ),
          const SizedBox(height: 8),
        ],
        if (both != null && both.isNotEmpty) ...[
          _buildEffectItem(
            context,
            'Mixed Effect',
            both,
            theme.colorScheme.tertiary,
            Icons.swap_horiz,
          ),
        ],
      ],
    );
  }

  Widget _buildEffectItem(
    BuildContext context,
    String label,
    String text,
    Color color,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrantsSection(
    BuildContext context,
    WidgetRef ref,
    List<ComplicationGrant> grants,
    String complicationId,
  ) {
    final theme = Theme.of(context);
    if (grants.isEmpty) return const SizedBox.shrink();

    final items = <Widget>[];

    for (final grant in grants) {
      final widget = _buildGrantWidget(context, ref, grant, complicationId);
      if (widget != null) {
        items.add(widget);
        items.add(const SizedBox(height: 8));
      }
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Grants',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...items,
      ],
    );
  }

  Widget? _buildGrantWidget(
    BuildContext context,
    WidgetRef ref,
    ComplicationGrant grant,
    String complicationId,
  ) {
    switch (grant) {
      case SkillGrant():
        return _buildGrantItem(context, 'Skill: ${grant.skillName}', Icons.psychology_outlined);
      
      case SkillFromGroupGrant():
        return _buildSkillFromGroupGrant(context, ref, grant, complicationId);
      
      case SkillFromOptionsGrant():
        return _buildSkillFromOptionsGrant(context, ref, grant, complicationId);
      
      case AbilityGrant():
        return _buildGrantItem(context, 'Ability: ${grant.abilityName}', Icons.auto_awesome_outlined);
      
      case TreasureGrant():
        if (grant.requiresChoice) {
          return _buildTreasureChoiceGrant(context, ref, grant, complicationId);
        }
        final echelonStr = grant.echelon != null ? ' (echelon ${grant.echelon})' : '';
        return _buildGrantItem(context, '${grant.treasureType.replaceAll('_', ' ')}$echelonStr', Icons.diamond_outlined);
      
      case LeveledTreasureGrant():
        return _buildLeveledTreasureGrant(context, ref, grant, complicationId);
      
      case TokenGrant():
        return _buildGrantItem(
          context,
          '${grant.count} ${grant.tokenType.replaceAll('_', ' ')} token${grant.count == 1 ? '' : 's'}',
          Icons.token_outlined,
        );
      
      case LanguageGrant():
        return _buildLanguageGrant(context, ref, grant, complicationId);
      
      case DeadLanguageGrant():
        return _buildGrantItem(
          context,
          '${grant.count} dead language${grant.count == 1 ? '' : 's'}',
          Icons.translate_outlined,
        );
      
      case IncreaseTotalGrant():
        final typeStr = grant.damageType != null ? ' (${grant.damageType})' : '';
        return _buildGrantItem(
          context,
          '+${grant.value} ${grant.stat.replaceAll('_', ' ')}$typeStr',
          Icons.trending_up_outlined,
        );
      
      case IncreaseTotalPerEchelonGrant():
        return _buildGrantItem(
          context,
          '+${grant.valuePerEchelon} ${grant.stat.replaceAll('_', ' ')} per echelon',
          Icons.trending_up_outlined,
        );
      
      case DecreaseTotalGrant():
        return _buildGrantItem(
          context,
          '-${grant.value} ${grant.stat.replaceAll('_', ' ')}',
          Icons.trending_down_outlined,
        );
      
      case SetBaseStatIfNotLowerGrant():
        return _buildGrantItem(
          context,
          'Sets ${grant.stat.replaceAll('_', ' ')} to ${grant.value} if lower',
          Icons.adjust_outlined,
        );
      
      case AncestryTraitsGrant():
        return _buildGrantItem(
          context,
          '${grant.ancestryPoints} ${grant.ancestry} ancestry trait point${grant.ancestryPoints == 1 ? '' : 's'}',
          Icons.person_outline,
        );
      
      case PickOneGrant():
        return _buildPickOneGrant(context, ref, grant, complicationId);
      
      case IncreaseRecoveryGrant():
        final valueStr = grant.value == 'highest_characteristic'
            ? 'by highest characteristic'
            : 'by ${grant.value}';
        return _buildGrantItem(context, 'Increase recovery $valueStr', Icons.healing_outlined);
      
      case FeatureGrant():
        final featureTypeDisplay = grant.featureType == 'mount' 
            ? '🐎' 
            : grant.featureType == 'follower' 
                ? '🧑' 
                : '✨';
        return _buildGrantItem(
          context,
          '$featureTypeDisplay ${grant.featureName} (${grant.featureType})',
          Icons.auto_awesome_outlined,
        );
    }
  }

  Widget _buildSkillFromGroupGrant(
    BuildContext context,
    WidgetRef ref,
    SkillFromGroupGrant grant,
    String complicationId,
  ) {
    final theme = Theme.of(context);
    final groupsStr = grant.groups.join(', ');
    
    // For now, just show what's needed - full skill picker can be added later
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_outlined, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Choose ${grant.count} skill${grant.count > 1 ? 's' : ''} from: $groupsStr',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (grant.selectedSkillIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: grant.selectedSkillIds.map((id) => Chip(
                label: Text(id),
                backgroundColor: theme.colorScheme.secondaryContainer,
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSkillFromOptionsGrant(
    BuildContext context,
    WidgetRef ref,
    SkillFromOptionsGrant grant,
    String complicationId,
  ) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_outlined, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Choose skill from: ${grant.options.join(', ')}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (grant.selectedSkillId != null) ...[
            const SizedBox(height: 8),
            Chip(
              label: Text(grant.selectedSkillId!),
              backgroundColor: theme.colorScheme.secondaryContainer,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTreasureChoiceGrant(
    BuildContext context,
    WidgetRef ref,
    TreasureGrant grant,
    String complicationId,
  ) {
    final theme = Theme.of(context);
    final componentsAsync = ref.watch(allComponentsProvider);
    
    // Determine the treasure type to filter by
    final treasureType = grant.treasureType.toLowerCase();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.diamond_outlined, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Choose ${treasureType.replaceAll('_', ' ')}${grant.echelon != null ? ' (echelon ${grant.echelon})' : ''}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          componentsAsync.when(
            loading: () => const SizedBox(
              height: 48,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Text('Error loading treasures: $e'),
            data: (components) {
              // Filter by treasure type
              final treasures = components.where((c) {
                if (c.type != treasureType) return false;
                // Filter by echelon if specified
                if (grant.echelon != null) {
                  final echelon = c.data['echelon'] as int?;
                  return echelon == grant.echelon;
                }
                return true;
              }).toList()
                ..sort((a, b) => a.name.compareTo(b.name));

              if (treasures.isEmpty) {
                return Text(
                  'No ${treasureType.replaceAll('_', ' ')}s available',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                );
              }

              // Find the choice key - we need to track the index of this treasure grant
              // For simplicity, use treasure_0 for the first one
              final choiceKey = '${complicationId}_treasure_0';
              final selectedId = grant.selectedTreasureId;
              final selectedTreasure = selectedId != null 
                  ? treasures.firstWhereOrNull((t) => t.id == selectedId)
                  : null;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () async {
                      final options = treasures.map((t) {
                        final subtitle = t.data['description'] as String?;
                        return _SearchOption<String>(
                          label: t.name,
                          value: t.id,
                          subtitle: subtitle,
                        );
                      }).toList();

                      final result = await _showSearchablePicker<String>(
                        context: context,
                        title: 'Select ${treasureType.replaceAll('_', ' ')}',
                        options: options,
                        selected: selectedId,
                      );

                      if (result != null) {
                        _updateChoice(choiceKey, result.value);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selectedTreasure != null 
                              ? theme.colorScheme.primary 
                              : theme.colorScheme.outline.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedTreasure != null ? Icons.check_circle : Icons.circle_outlined,
                            size: 20,
                            color: selectedTreasure != null 
                                ? theme.colorScheme.primary 
                                : theme.colorScheme.outline,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedTreasure?.name ?? 'Tap to select...',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: selectedTreasure != null 
                                    ? null 
                                    : theme.colorScheme.outline,
                                fontStyle: selectedTreasure != null 
                                    ? null 
                                    : FontStyle.italic,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: theme.colorScheme.outline,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Show treasure card preview when selected
                  if (selectedTreasure != null) ...[
                    const SizedBox(height: 12),
                    _buildTreasurePreview(context, selectedTreasure),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLeveledTreasureGrant(
    BuildContext context,
    WidgetRef ref,
    LeveledTreasureGrant grant,
    String complicationId,
  ) {
    final theme = Theme.of(context);
    final componentsAsync = ref.watch(allComponentsProvider);
    
    // The category to filter by (e.g., "weapon", "armor")
    final category = grant.category?.toLowerCase();
    final categoryLabel = category?.replaceAll('_', ' ') ?? 'treasure';
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.diamond_outlined, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Choose leveled $categoryLabel',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          componentsAsync.when(
            loading: () => const SizedBox(
              height: 48,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Text('Error loading treasures: $e'),
            data: (components) {
              // Filter for leveled treasures matching the category
              final treasures = components.where((c) {
                if (c.type != 'leveled_treasure') return false;
                // Filter by leveled_type if category is specified
                if (category != null) {
                  final leveledType = c.data['leveled_type'] as String?;
                  return leveledType?.toLowerCase() == category;
                }
                return true;
              }).toList()
                ..sort((a, b) => a.name.compareTo(b.name));

              if (treasures.isEmpty) {
                return Text(
                  'No leveled ${categoryLabel}s available',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                );
              }

              // Find the choice key - use leveled_treasure_0 for the first one
              final choiceKey = '${complicationId}_treasure_0';
              final selectedId = grant.selectedTreasureId;
              final selectedTreasure = selectedId != null 
                  ? treasures.firstWhereOrNull((t) => t.id == selectedId)
                  : null;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () async {
                      final options = treasures.map((t) {
                        final subtitle = t.data['description'] as String?;
                        return _SearchOption<String>(
                          label: t.name,
                          value: t.id,
                          subtitle: subtitle,
                        );
                      }).toList();

                      final result = await _showSearchablePicker<String>(
                        context: context,
                        title: 'Select leveled $categoryLabel',
                        options: options,
                        selected: selectedId,
                      );

                      if (result != null) {
                        _updateChoice(choiceKey, result.value);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selectedTreasure != null 
                              ? theme.colorScheme.primary 
                              : theme.colorScheme.outline.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedTreasure != null ? Icons.check_circle : Icons.circle_outlined,
                            size: 20,
                            color: selectedTreasure != null 
                                ? theme.colorScheme.primary 
                                : theme.colorScheme.outline,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedTreasure?.name ?? 'Tap to select...',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: selectedTreasure != null 
                                    ? null 
                                    : theme.colorScheme.outline,
                                fontStyle: selectedTreasure != null 
                                    ? null 
                                    : FontStyle.italic,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: theme.colorScheme.outline,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Show treasure card preview when selected
                  if (selectedTreasure != null) ...[
                    const SizedBox(height: 12),
                    _buildTreasurePreview(context, selectedTreasure),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageGrant(
    BuildContext context,
    WidgetRef ref,
    LanguageGrant grant,
    String complicationId,
  ) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.translate_outlined, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Choose ${grant.count} language${grant.count > 1 ? 's' : ''}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (grant.selectedLanguageIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: grant.selectedLanguageIds.map((id) => Chip(
                label: Text(id),
                backgroundColor: theme.colorScheme.secondaryContainer,
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPickOneGrant(
    BuildContext context,
    WidgetRef ref,
    PickOneGrant grant,
    String complicationId,
  ) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist_outlined, size: 18, color: theme.colorScheme.tertiary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Choose one:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(grant.options.length, (index) {
            final isSelected = grant.selectedIndex == index;
            final description = grant.getOptionDescription(index);
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: InkWell(
                onTap: () {
                  _updateChoice('${complicationId}_pick_one', index.toString());
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? theme.colorScheme.primaryContainer.withOpacity(0.5)
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected 
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline.withOpacity(0.3),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        size: 20,
                        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(description)),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGrantItem(BuildContext context, String text, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreasurePreview(BuildContext context, model.Component treasure) {
    // Use the appropriate treasure card based on type
    switch (treasure.type) {
      case 'artifact':
        return ArtifactTreasureCard(component: treasure);
      case 'trinket':
        return TrinketTreasureCard(component: treasure);
      case 'consumable':
        return ConsumableTreasureCard(component: treasure);
      case 'leveled_treasure':
        return LeveledTreasureCard(component: treasure);
      default:
        return BaseTreasureCard(
          component: treasure,
          children: const [],
        );
    }
  }
}
