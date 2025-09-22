import 'package:flutter/material.dart';
import '../../core/models/component.dart';
import 'abilities_shared.dart';

class AbilitySummary extends StatelessWidget {
  final Component component;
  const AbilitySummary({super.key, required this.component});

  @override
  Widget build(BuildContext context) {
    final a = AbilityData(component);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and cost row
          Row(
            children: [
              Expanded(
                child: Text(
                  a.name, 
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              if (a.costString != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: scheme.primaryContainer.withOpacity(0.8),
                    border: Border.all(
                      color: scheme.primary.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    a.costString!,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          
          // Compact info chips
          if (a.actionType != null || a.keywords.isNotEmpty || a.characteristicSummary != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (a.actionType != null)
                    _buildInfoChip(context, a.actionType!, scheme.tertiary),
                  if (a.characteristicSummary != null)
                    _buildInfoChip(context, a.characteristicSummary!, scheme.secondary),
                  ...a.keywords.take(2).map((keyword) => 
                    _buildInfoChip(context, keyword, scheme.outline)),
                  if (a.keywords.length > 2)
                    _buildInfoChip(context, '+${a.keywords.length - 2} more', scheme.outline),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(BuildContext context, String text, Color color) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withOpacity(0.1),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
      ),
    );
  }
}
