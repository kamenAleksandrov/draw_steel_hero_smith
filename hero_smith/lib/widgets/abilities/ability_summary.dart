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
    final meta = a.metaSummary();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(a.name, style: theme.textTheme.titleMedium),
              ),
              if (a.costString != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: scheme.primaryContainer,
                  ),
                  child: Text(
                    a.costString!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          if (meta.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                meta,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}
