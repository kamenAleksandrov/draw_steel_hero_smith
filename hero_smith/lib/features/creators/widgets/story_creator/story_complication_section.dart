import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/providers.dart';

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
    required this.onComplicationChanged,
    required this.onDirty,
  });

  final String? selectedComplicationId;
  final ValueChanged<String?> onComplicationChanged;
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
                      _ComplicationDetails(complication: selectedComp),
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

class _ComplicationDetails extends StatelessWidget {
  const _ComplicationDetails({required this.complication});

  final dynamic complication;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = complication.data;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
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
          if (data['grants'] != null) ...[
            _buildGrants(context, data['grants']),
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

  Widget _buildGrants(BuildContext context, dynamic grants) {
    final theme = Theme.of(context);
    final grantsData = grants as Map<String, dynamic>?;
    if (grantsData == null || grantsData.isEmpty) {
      return const SizedBox.shrink();
    }

    final items = <Widget>[];

    // Treasures
    if (grantsData['treasures'] is List) {
      final treasures = grantsData['treasures'] as List;
      for (final treasure in treasures) {
        if (treasure is Map) {
          final type = treasure['type']?.toString() ?? 'treasure';
          final echelon = treasure['echelon'];
          final choice = treasure['choice'] == true;
          
          final text = choice
              ? '${type.replaceAll('_', ' ')}${echelon != null ? ' (echelon $echelon)' : ''} of your choice'
              : '${type.replaceAll('_', ' ')}${echelon != null ? ' (echelon $echelon)' : ''}';
          
          items.add(_buildGrantItem(context, text, Icons.diamond_outlined));
        }
      }
    }

    // Tokens
    if (grantsData['tokens'] is Map) {
      final tokens = grantsData['tokens'] as Map;
      tokens.forEach((key, value) {
        items.add(_buildGrantItem(
          context,
          '$value ${key.toString().replaceAll('_', ' ')} token${value == 1 ? '' : 's'}',
          Icons.token_outlined,
        ));
      });
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
}
