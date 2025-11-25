import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/providers.dart';
import '../../../../core/models/component.dart' as model;
import '../../../../core/theme/hero_theme.dart';

class StoryAncestrySection extends ConsumerWidget {
  const StoryAncestrySection({
    super.key,
    required this.selectedAncestryId,
    required this.selectedTraitIds,
    required this.onAncestryChanged,
  required this.onTraitSelectionChanged,
    required this.onDirty,
  });

  final String? selectedAncestryId;
  final Set<String> selectedTraitIds;
  final ValueChanged<String?> onAncestryChanged;
  final void Function(String traitId, bool isSelected) onTraitSelectionChanged;
  final VoidCallback onDirty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ancestriesAsync = ref.watch(componentsByTypeProvider('ancestry'));
    final ancestryTraitsAsync = ref.watch(componentsByTypeProvider('ancestry_trait'));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: HeroTheme.sectionCardElevation,
        shape: const RoundedRectangleBorder(borderRadius: HeroTheme.cardRadius),
        child: Column(
          children: [
            HeroTheme.buildSectionHeader(
              context,
              title: 'Ancestry',
              subtitle: 'Your hero\'s biological and cultural heritage',
              icon: Icons.family_restroom,
              color: HeroTheme.getStepColor('ancestry'),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ancestriesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: $e',
                        style: TextStyle(color: theme.colorScheme.error)),
                    data: (ancestries) => _buildAncestryDropdown(
                      context,
                      theme,
                      ancestries,
                      ancestryTraitsAsync,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAncestryDropdown(
    BuildContext context,
    ThemeData theme,
    List<model.Component> ancestries,
    AsyncValue<List<model.Component>> traitsAsync,
  ) {
    ancestries = List.of(ancestries)..sort((a, b) => a.name.compareTo(b.name));
    final selectedAncestry = ancestries.firstWhere(
      (a) => a.id == selectedAncestryId,
      orElse: () => ancestries.isNotEmpty
          ? ancestries.first
          : const model.Component(id: '', type: 'ancestry', name: 'Unknown'),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InputDecorator(
          decoration: InputDecoration(
            labelText: 'Choose Ancestry',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?> (
              value: selectedAncestryId,
              isExpanded: true,
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('— Choose ancestry —'),
                ),
                ...ancestries.map(
                  (a) => DropdownMenuItem<String?>(
                    value: a.id,
                    child: Text(a.name),
                  ),
                ),
              ],
              onChanged: (value) {
                onAncestryChanged(value);
                onDirty();
              },
            ),
          ),
        ),
        if (selectedAncestryId != null) ...[
          const SizedBox(height: 16),
          traitsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error loading ancestry traits: $e'),
            data: (traitsComps) {
              final traitsForSelected = traitsComps.firstWhere(
                (t) => t.data['ancestry_id'] == selectedAncestryId,
                orElse: () => traitsComps.firstWhere(
                  (t) => t.data['ancestry_id'] == selectedAncestry.id,
                  orElse: () => traitsComps.isNotEmpty
                      ? traitsComps.first
                      : const model.Component(
                          id: '', type: 'ancestry_trait', name: '—'),
                ),
              );
              return _AncestryDetails(
                ancestry: selectedAncestry,
                traitsComp: traitsForSelected,
                selectedTraitIds: selectedTraitIds,
                onTraitSelectionChanged: onTraitSelectionChanged,
                onDirty: onDirty,
              );
            },
          ),
        ],
      ],
    );
  }
}

class _AncestryDetails extends StatelessWidget {
  const _AncestryDetails({
    required this.ancestry,
    required this.traitsComp,
  required this.selectedTraitIds,
  required this.onTraitSelectionChanged,
    required this.onDirty,
  });

  final model.Component ancestry;
  final model.Component traitsComp;
  final Set<String> selectedTraitIds;
  final void Function(String traitId, bool isSelected) onTraitSelectionChanged;
  final VoidCallback onDirty;

  @override
  Widget build(BuildContext context) {
    final data = ancestry.data;
    final shortDesc = (data['short_description'] as String?) ?? '';
    final height = (data['height'] as Map?)?.cast<String, dynamic>();
    final weight = (data['weight'] as Map?)?.cast<String, dynamic>();
    final life = (data['life_expectancy'] as Map?)?.cast<String, dynamic>();
    final size = data['size'];
    final speed = data['speed'];
    final stability = data['stability'];

    final signature = (traitsComp.data['signature'] as Map?)?.cast<String, dynamic>();

    final points = (traitsComp.data['points'] as int?) ?? 0;
    final traitsList =
        (traitsComp.data['traits'] as List?)?.cast<Map>() ?? const <Map>[];

    final spent = selectedTraitIds.fold<int>(0, (sum, id) {
      final match = traitsList.firstWhere(
        (t) => (t['id'] ?? t['name']).toString() == id,
        orElse: () => const {},
      );
      return sum + (match.cast<String, dynamic>()['cost'] as int? ?? 0);
    });
    final remaining = points - spent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (shortDesc.isNotEmpty) ...[
          Text(shortDesc,
              style: TextStyle(color: Colors.grey.shade300, height: 1.3)),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (height != null)
              _chip('Height: ${height['min']}–${height['max']}', Colors.blue),
            if (weight != null)
              _chip('Weight: ${weight['min']}–${weight['max']}', Colors.green),
            if (life != null)
              _chip('Lifespan: ${life['min']}–${life['max']}', Colors.purple),
            if (size != null) _chip('Size: $size', Colors.orange),
            if (speed != null) _chip('Speed: $speed', Colors.teal),
            if (stability != null)
              _chip('Stability: $stability', Colors.redAccent),
          ],
        ),
        const SizedBox(height: 16),
        if (signature != null) ...[
          Text('Signature: ${signature['name'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          if ((signature['description'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(signature['description'] as String,
                style: const TextStyle(height: 1.3)),
          ],
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Chip(label: Text('Points: $points')),
            const SizedBox(width: 8),
            Chip(label: Text('Remaining: $remaining')),
          ],
        ),
        const SizedBox(height: 8),
        ...traitsList.map((t) {
          final id = (t['id'] ?? t['name']).toString();
          final name = (t['name'] ?? id).toString();
          final desc = (t['description'] ?? '').toString();
          final cost = (t['cost'] as int?) ?? 0;
          final selected = selectedTraitIds.contains(id);
          final canSelect = selected || remaining - cost >= 0;
          return CheckboxListTile(
            value: selected,
            onChanged: canSelect
                ? (value) {
                    if (value == null) return;
                    onTraitSelectionChanged(id, value);
                    onDirty();
                  }
                : null,
            title: Text(name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  desc,
                  softWrap: true,
                ),
              ],
            ),
            isThreeLine: true,
            secondary: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$cost'),
            ),
            contentPadding: EdgeInsets.zero,
          );
        }),
      ],
    );
  }

  Widget _chip(String text, Color color) => Chip(
        label: Text(text),
        backgroundColor: color.withOpacity(0.1),
        side: BorderSide(color: color.withOpacity(0.6), width: 1),
      );
}
