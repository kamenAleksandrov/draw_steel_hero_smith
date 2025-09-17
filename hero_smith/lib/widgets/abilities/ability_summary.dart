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
    final meta = a.metaSummary();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(a.name, style: theme.textTheme.titleMedium),
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
