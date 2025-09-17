import 'package:flutter/material.dart';
import '../../core/models/component.dart';
import 'abilities_shared.dart';

class AbilityFullView extends StatelessWidget {
  final Component component;
  const AbilityFullView({super.key, required this.component});

  @override
  Widget build(BuildContext context) {
    final a = AbilityData(component);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget chips() {
      final chips = <Widget>[];
      if (a.rangeArea != null) chips.add(_chip(context, a.rangeArea!));
      if (a.rangeDistance != null) chips.add(_chip(context, a.rangeDistance!));
      if (a.targets != null) chips.add(_chip(context, a.targets!));
      return Wrap(spacing: 6, runSpacing: -6, children: chips);
    }

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DefaultTextStyle(
          style: theme.textTheme.bodyMedium ?? const TextStyle(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + flavor
              Text(a.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              if (a.flavor != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    a.flavor!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),

              // Keywords / Cost / Action
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: -6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (a.keywords.isNotEmpty)
                            Text(
                              a.keywords.join(', '),
                              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
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
                                style: theme.textTheme.labelSmall?.copyWith(color: scheme.onPrimaryContainer),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (a.actionType != null)
                      Text(
                        a.actionType!,
                        style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),

              // Chips row: area/range/targets
              if ([a.rangeArea, a.rangeDistance, a.targets].any((e) => e != null))
                Padding(padding: const EdgeInsets.only(top: 8), child: chips()),

              // Power Roll section
              if (a.characteristicSummary != null || a.tiers.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (a.characteristicSummary != null)
                        Text(
                          'Power Roll + ${a.characteristicSummary}:',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      if (a.tiers.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: a.tiers.map((t) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 56,
                                      child: Text(
                                        t.label,
                                        style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                                      ),
                                    ),
                                    Expanded(child: Text(t.text)),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),

              // Effect
              if (a.effect != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Effect:', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(a.effect!),
                    ],
                  ),
                ),

              // Special
              if (a.specialEffect != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Special:', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(a.specialEffect!),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
