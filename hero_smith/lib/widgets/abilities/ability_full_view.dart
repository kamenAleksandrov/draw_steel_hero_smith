import 'package:flutter/material.dart';
import '../../core/models/component.dart';
import '../../core/theme/semantic/semantic_tokens.dart';
import 'abilities_shared.dart';

class AbilityFullView extends StatelessWidget {
  final Component component;
  const AbilityFullView({super.key, required this.component});

  @override
  Widget build(BuildContext context) {
    final a = AbilityData(component);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: DefaultTextStyle(
        style: theme.textTheme.bodyMedium ?? const TextStyle(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title section with flavor text
            if (a.flavor != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: scheme.surfaceContainerHighest.withOpacity(0.5),
                  border: Border.all(
                    color: scheme.outline.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.format_quote,
                      color: scheme.onSurfaceVariant,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        a.flavor!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Keywords / Action
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (a.keywords.isNotEmpty)
                          ...a.keywords.map((keyword) {
                            final keywordColor = KeywordTokens.color(keyword);
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: keywordColor.withValues(alpha: 0.15),
                                border: Border.all(
                                    color: keywordColor.withValues(alpha: 0.6),
                                    width: 1.5),
                              ),
                              child: Text(
                                keyword,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: keywordColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                  if (a.actionType != null)
                    () {
                      final actionColor = ActionTokens.color(a.actionType!);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: [
                              actionColor.withValues(alpha: 0.4),
                              actionColor.withValues(alpha: 0.25),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                              color: actionColor.withValues(alpha: 0.8),
                              width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: actionColor.withValues(alpha: 0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          a.actionType!,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }(),
                ],
              ),
            ),

            // Chips row: area/range/targets
            if ([a.rangeArea, a.rangeDistance, a.targets].any((e) => e != null))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (a.rangeArea != null)
                      _chip(context, 'Area: ${a.rangeArea}'),
                    if (a.rangeDistance != null)
                      _chip(context, 'Range: ${a.rangeDistance}'),
                    if (a.targets != null)
                      _chip(context, 'Targets: ${a.targets}'),
                  ],
                ),
              ),

            // Power Roll section
            if (a.characteristics.isNotEmpty || a.tiers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (a.characteristics.isNotEmpty)
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Power Roll + ',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          ...a.characteristics.map((char) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: CharacteristicTokens.color(char)
                                      .withValues(alpha: 0.2),
                                  border: Border.all(
                                      color: CharacteristicTokens.color(char)
                                          .withValues(alpha: 0.6)),
                                ),
                                child: Text(
                                  char,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: CharacteristicTokens.color(char),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )),
                          Text(
                            ':',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
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
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                              color: scheme.onSurfaceVariant),
                                    ),
                                  ),
                                  Expanded(
                                      child: AbilityTextHighlighter
                                          .highlightGameMechanics(
                                              t.text, context)),
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
                    Text('Effect:',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    AbilityTextHighlighter.highlightGameMechanics(
                        a.effect!, context),
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
                    Text('Special:',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    AbilityTextHighlighter.highlightGameMechanics(
                        a.specialEffect!, context),
                  ],
                ),
              ),
          ],
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
