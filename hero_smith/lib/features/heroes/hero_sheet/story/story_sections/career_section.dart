import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/db/providers.dart';
import '../../../../../core/models/component.dart' as model;
import '../../../../../widgets/perks/perk_card.dart';
import '../../../../../widgets/shared/story_display_widgets.dart';

// Provider to fetch a single component by ID
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

/// Data class for career selection.
class CareerSelectionData {
  const CareerSelectionData({
    this.careerId,
    this.incitingIncidentName,
    this.chosenSkillIds = const [],
    this.chosenPerkIds = const [],
  });

  final String? careerId;
  final String? incitingIncidentName;
  final List<String> chosenSkillIds;
  final List<String> chosenPerkIds;
}

/// Displays the career section with skills, perks, and inciting incident.
class CareerSection extends ConsumerWidget {
  const CareerSection({
    super.key,
    required this.career,
    required this.heroId,
  });

  final CareerSelectionData career;
  final String heroId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final careerId = career.careerId;

    if (careerId == null || careerId.isEmpty) {
      return const SizedBox.shrink();
    }

    final careerAsync = ref.watch(_componentByIdProvider(careerId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Career',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            careerAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Error loading career: $e'),
              data: (careerComp) {
                if (careerComp == null) return const Text('Career not found');

                return _CareerContent(
                  career: career,
                  careerComponent: careerComp,
                  heroId: heroId,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CareerContent extends ConsumerWidget {
  const _CareerContent({
    required this.career,
    required this.careerComponent,
    required this.heroId,
  });

  final CareerSelectionData career;
  final model.Component careerComponent;
  final String heroId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoRow(
          label: 'Career',
          value: careerComponent.name,
          icon: Icons.work,
        ),
        if (careerComponent.data['description'] != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text(
              careerComponent.data['description'].toString(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ),
        ],
        if (career.incitingIncidentName != null &&
            career.incitingIncidentName!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Inciting Incident',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          IncitingIncidentDisplay(
            careerData: careerComponent.data,
            incidentName: career.incitingIncidentName!,
          ),
        ],
        if (career.chosenSkillIds.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Career Skills',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...career.chosenSkillIds.map(
            (skillId) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _ComponentDisplay(
                label: '',
                componentId: skillId,
                icon: Icons.school,
              ),
            ),
          ),
        ],
        if (career.chosenPerkIds.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Career Perks',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...career.chosenPerkIds.map(
            (perkId) => _HeroPerkCard(perkId: perkId, heroId: heroId),
          ),
        ],
      ],
    );
  }
}

/// Internal widget to display a component by ID with async loading.
class _ComponentDisplay extends ConsumerWidget {
  const _ComponentDisplay({
    required this.label,
    required this.componentId,
    required this.icon,
  });

  final String label;
  final String componentId;
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final componentAsync = ref.watch(_componentByIdProvider(componentId));
    final theme = Theme.of(context);

    return componentAsync.when(
      loading: () => const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (e, _) =>
          Text('Error: $e', style: const TextStyle(color: Colors.red)),
      data: (component) {
        if (component == null) return Text('$label not found');

        final description = component.data['description']?.toString();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label.isEmpty)
              InfoRow(label: '', value: component.name, icon: icon)
            else
              InfoRow(label: label, value: component.name, icon: icon),
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Internal widget to display a perk card by ID.
class _HeroPerkCard extends ConsumerWidget {
  const _HeroPerkCard({
    required this.perkId,
    required this.heroId,
  });

  final String perkId;
  final String heroId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final componentAsync = ref.watch(_componentByIdProvider(perkId));

    return componentAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: SizedBox(
          height: 40,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child:
            Text('Error loading perk: $e', style: const TextStyle(color: Colors.red)),
      ),
      data: (component) {
        if (component == null || component.id.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Perk not found: $perkId'),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PerkCard(perk: component, heroId: heroId),
        );
      },
    );
  }
}
