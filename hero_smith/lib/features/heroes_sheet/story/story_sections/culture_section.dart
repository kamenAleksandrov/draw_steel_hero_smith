import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hero_smith/core/theme/text/heroes_sheet/story/sheet_story_culture_section_text.dart';

import '../../../../core/db/providers.dart';
import '../../../../core/models/component.dart' as model;
import '../../../../widgets/shared/story_display_widgets.dart';

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

/// Data class for culture selection.
class CultureSelectionData {
  const CultureSelectionData({
    this.environmentId,
    this.organisationId,
    this.upbringingId,
    this.environmentSkillId,
    this.organisationSkillId,
    this.upbringingSkillId,
  });

  final String? environmentId;
  final String? organisationId;
  final String? upbringingId;
  final String? environmentSkillId;
  final String? organisationSkillId;
  final String? upbringingSkillId;

  bool get hasAnySelection =>
      (environmentId != null && environmentId!.isNotEmpty) ||
      (organisationId != null && organisationId!.isNotEmpty) ||
      (upbringingId != null && upbringingId!.isNotEmpty);
}

/// Displays the culture section with environment, organization, and upbringing.
class CultureSection extends ConsumerWidget {
  const CultureSection({
    super.key,
    required this.culture,
  });

  final CultureSelectionData culture;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    if (!culture.hasAnySelection) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              SheetStoryCultureSectionText.sectionTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (culture.environmentId != null &&
                culture.environmentId!.isNotEmpty)
              _ComponentDisplay(
                label: SheetStoryCultureSectionText.environmentLabel,
                componentId: culture.environmentId!,
                icon: Icons.terrain,
              ),
            if (culture.organisationId != null &&
                culture.organisationId!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _ComponentDisplay(
                label: SheetStoryCultureSectionText.organizationLabel,
                componentId: culture.organisationId!,
                icon: Icons.groups,
              ),
            ],
            if (culture.upbringingId != null &&
                culture.upbringingId!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _ComponentDisplay(
                label: SheetStoryCultureSectionText.upbringingLabel,
                componentId: culture.upbringingId!,
                icon: Icons.home,
              ),
            ],
            if (culture.environmentSkillId != null ||
                culture.organisationSkillId != null ||
                culture.upbringingSkillId != null) ...[
              const SizedBox(height: 16),
              Text(
                SheetStoryCultureSectionText.cultureSkillsTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (culture.environmentSkillId != null)
                _ComponentDisplay(
                  label: SheetStoryCultureSectionText.environmentSkillLabel,
                  componentId: culture.environmentSkillId!,
                  icon: Icons.school,
                ),
              if (culture.organisationSkillId != null) ...[
                const SizedBox(height: 4),
                _ComponentDisplay(
                  label: SheetStoryCultureSectionText.organizationSkillLabel,
                  componentId: culture.organisationSkillId!,
                  icon: Icons.school,
                ),
              ],
              if (culture.upbringingSkillId != null) ...[
                const SizedBox(height: 4),
                _ComponentDisplay(
                  label: SheetStoryCultureSectionText.upbringingSkillLabel,
                  componentId: culture.upbringingSkillId!,
                  icon: Icons.school,
                ),
              ],
            ],
          ],
        ),
      ),
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
