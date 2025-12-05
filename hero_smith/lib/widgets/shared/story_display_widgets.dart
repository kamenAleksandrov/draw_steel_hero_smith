import 'package:flutter/material.dart';

/// A row displaying labeled information with an icon.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (label.isNotEmpty) ...[
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Displays an effect item (benefit, drawback, or mixed).
class EffectItemDisplay extends StatelessWidget {
  const EffectItemDisplay({
    super.key,
    required this.label,
    required this.text,
    required this.color,
    required this.icon,
  });

  final String label;
  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
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
}

/// Displays a grant item with icon and text.
class GrantItemDisplay extends StatelessWidget {
  const GrantItemDisplay({
    super.key,
    required this.text,
    required this.icon,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
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

/// Displays a reference to an ability.
class AbilityReferenceDisplay extends StatelessWidget {
  const AbilityReferenceDisplay({
    super.key,
    required this.ability,
  });

  final dynamic ability;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (ability == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.flash_on,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Ability: ${ability.toString()}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Displays a reference to a feature.
class FeatureReferenceDisplay extends StatelessWidget {
  const FeatureReferenceDisplay({
    super.key,
    required this.feature,
  });

  final dynamic feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (feature == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.secondary.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.stars,
            size: 16,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Feature: ${feature.toString()}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A card displaying a selected trait with name, description, cost, and optional ability.
class SelectedTraitCard extends StatelessWidget {
  const SelectedTraitCard({
    super.key,
    required this.trait,
  });

  final Map<String, dynamic> trait;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            trait['name']?.toString() ?? 'Unknown Trait',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (trait['description'] != null) ...[
            const SizedBox(height: 4),
            Text(
              trait['description'].toString(),
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (trait['cost'] != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Cost: ${trait['cost']} pt${trait['cost'] == 1 ? '' : 's'}',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
          if (trait['ability_name'] != null &&
              trait['ability_name'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            AbilityReferenceDisplay(ability: trait['ability_name']),
          ],
        ],
      ),
    );
  }
}

/// Displays an inciting incident with name and description.
class IncitingIncidentDisplay extends StatelessWidget {
  const IncitingIncidentDisplay({
    super.key,
    required this.careerData,
    required this.incidentName,
  });

  final Map<String, dynamic> careerData;
  final String incidentName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final incidents = careerData['inciting_incidents'] as List?;

    if (incidents == null) {
      return Text(incidentName);
    }

    final incident = incidents.cast<Map<String, dynamic>>().firstWhere(
          (i) => i['name']?.toString() == incidentName,
          orElse: () => <String, dynamic>{},
        );

    if (incident.isEmpty) {
      return Text(incidentName);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.flash_on,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  incident['name']?.toString() ?? incidentName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (incident['description'] != null) ...[
            const SizedBox(height: 8),
            Text(
              incident['description'].toString(),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}
