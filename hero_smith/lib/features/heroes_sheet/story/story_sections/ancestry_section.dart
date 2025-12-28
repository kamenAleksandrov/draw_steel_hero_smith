import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hero_smith/core/theme/heroes_sheet/story/sheet_story_ancestry_theme.dart';
import 'package:hero_smith/core/text/heroes_sheet/story/sheet_story_ancestry_section_text.dart';

import '../../../../core/db/providers.dart';
import '../../../../core/models/component.dart' as model;
import '../../../../widgets/shared/story_display_widgets.dart';

// Provider to fetch a single component by ID (same as in sheet_story.dart)
final _componentByIdProvider =
    FutureProvider.family<model.Component?, String>((ref, id) async {
  final allComponents = await ref.read(allComponentsProvider.future);
  return allComponents.firstWhere(
    (c) => c.id == id,
    orElse: () => model.Component(
      id: '',
      type: '',
      name: 'Not found',
      data: const {},
      source: '',
    ),
  );
});

/// Displays the ancestry section with signature ability and selected traits.
class AncestrySection extends ConsumerWidget {
  const AncestrySection({
    super.key,
    required this.ancestryId,
    required this.traitIds,
  });

  final String? ancestryId;
  final List<String> traitIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    if (ancestryId == null || ancestryId!.isEmpty) {
      return const SizedBox.shrink();
    }

    final ancestryAsync = ref.watch(_componentByIdProvider(ancestryId!));
    final traitsAsync = ref.watch(allComponentsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              SheetStoryAncestrySectionText.sectionTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ancestryAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text(
                '${SheetStoryAncestrySectionText.errorLoadingAncestryPrefix}$e',
              ),
              data: (ancestry) {
                if (ancestry == null) {
                  return const Text(
                      SheetStoryAncestrySectionText.ancestryNotFound);
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InfoRow(
                      label: SheetStoryAncestrySectionText.ancestryLabel,
                      value: ancestry.name,
                      icon: Icons.family_restroom,
                    ),
                    if (ancestry.data['description'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        ancestry.data['description'].toString(),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ],
                );
              },
            ),
            if (traitIds.isNotEmpty) ...[
              const SizedBox(height: 16),
              traitsAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Error loading traits: $e'),
                data: (allTraits) => _buildTraitsContent(context, allTraits),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTraitsContent(
    BuildContext context,
    List<model.Component> allTraits,
  ) {
    final theme = Theme.of(context);

    final ancestryTraitComponent = allTraits.cast<dynamic>().firstWhere(
          (t) => t.data['ancestry_id'] == ancestryId,
          orElse: () => null,
        );

    if (ancestryTraitComponent == null && allTraits.isNotEmpty) {
      return const Text(SheetStoryAncestrySectionText.noTraitDataAvailable);
    }

    if (ancestryTraitComponent == null) {
      return const Text(SheetStoryAncestrySectionText.noTraitsAvailable);
    }

    final signature =
        ancestryTraitComponent.data['signature'] as Map<String, dynamic>?;
    final traitsList = ancestryTraitComponent.data['traits'] as List?;

    final selectedTraits = traitsList
            ?.where((trait) =>
                trait is Map && traitIds.contains(trait['id']?.toString()))
            .toList() ??
        [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (signature != null) ...[
          Text(
            SheetStoryAncestrySectionText.signatureAbilityTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  SheetStoryAncestryTheme.signatureAccentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: SheetStoryAncestryTheme.signatureAccentColor
                    .withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  signature['name']?.toString() ??
                      SheetStoryAncestrySectionText.signatureUnknownName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade800,
                  ),
                ),
                if (signature['description'] != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    signature['description'].toString(),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (selectedTraits.isNotEmpty) ...[
          Text(
            SheetStoryAncestrySectionText.optionalTraitsTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...selectedTraits.map((trait) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SelectedTraitCard(trait: trait as Map<String, dynamic>),
            );
          }),
        ],
      ],
    );
  }
}
