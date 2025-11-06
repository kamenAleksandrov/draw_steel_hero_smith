import 'package:flutter/material.dart';

import '../../core/models/component.dart';
import '../../core/theme/semantic/semantic_tokens.dart';
import 'abilities_shared.dart';

class AbilitySummary extends StatelessWidget {
  const AbilitySummary({
    super.key,
    required this.component,
    this.abilityData,
  });

  final Component component;
  final AbilityData? abilityData;

  @override
  Widget build(BuildContext context) {
    final ability = abilityData ?? AbilityData.fromComponent(component);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final resourceColor = ability.resourceType != null
        ? HeroicResourceTokens.color(ability.resourceType!)
        : scheme.primary;
    final metadataColor = scheme.onSurfaceVariant;
    final resourceLabel = ability.resourceLabel;
    final costAmount = ability.costAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      text: ability.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                      children: [
                        if (ability.costString != null && resourceLabel == null)
                          TextSpan(
                            text: ' (${ability.costString})',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: resourceColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (ability.flavor != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        ability.flavor!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: metadataColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (ability.level != null)
                  _buildBadge(
                    context,
                    'Level ${ability.level}',
                    scheme.secondary,
                    scheme.onSecondary,
                  ),
                if (resourceLabel != null)
                  Padding(
                    padding: EdgeInsets.only(top: ability.level != null ? 6 : 0),
                    child: _buildBadge(
                      context,
                      costAmount != null && costAmount > 0
                          ? '$resourceLabel $costAmount'
                          : resourceLabel,
                      resourceColor,
                      Colors.white,
                    ),
                  ),
                if (ability.actionType != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _buildBadge(
                      context,
                      ability.actionType!,
                      ActionTokens.color(ability.actionType!),
                      Colors.white,
                    ),
                  ),
              ],
            ),
          ],
        ),
        if (ability.keywords.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              ability.keywords.join(', '),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
        if (ability.triggerText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _buildInfoRow(
              context,
              Icons.bolt,
              'Trigger: ${ability.triggerText}',
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (ability.rangeSummary != null)
                _buildInfoRow(context, Icons.straighten, ability.rangeSummary!),
              if (ability.targets != null)
                _buildInfoRow(context, Icons.adjust, ability.targets!),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(
    BuildContext context,
    String label,
    Color background,
    Color foreground,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: background.withValues(alpha: 0.85),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
