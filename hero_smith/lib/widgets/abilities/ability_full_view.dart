import 'package:flutter/material.dart';

import '../../core/models/component.dart';
import '../../core/theme/semantic/semantic_tokens.dart';
import 'abilities_shared.dart';

class AbilityFullView extends StatelessWidget {
  const AbilityFullView({
    super.key,
    required this.component,
    this.abilityData,
  });

  final Component component;
  final AbilityData? abilityData;

  @override
  Widget build(BuildContext context) {
    final ability = abilityData ?? AbilityData(component);
    final sections = <Widget>[];

    if (ability.hasPowerRoll) {
      sections.add(_buildPowerRollSection(context, ability));
    }

    if (ability.effect != null) {
      sections.add(_buildLabeledText(context, 'Effect', ability.effect!));
    }

    if (ability.specialEffect != null) {
      sections
          .add(_buildLabeledText(context, 'Special', ability.specialEffect!));
    }

    if (sections.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          sections[i],
        ],
      ],
    );
  }

  Widget _buildPowerRollSection(BuildContext context, AbilityData ability) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final scheme = theme.colorScheme;

    final headerChildren = <Widget>[
      Text(
        ability.powerRollLabel ?? 'Power roll',
        style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    ];

    if (ability.characteristics.isNotEmpty) {
      headerChildren.add(const SizedBox(width: 8));
      headerChildren.add(Text(
        '+',
        style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ));
      headerChildren.add(const SizedBox(width: 6));
      headerChildren.add(Wrap(
        spacing: 6,
        runSpacing: 4,
        children: ability.characteristics
            .map((char) => _buildCharacteristicChip(context, char))
            .toList(),
      ));
    } else if (ability.characteristicSummary != null) {
      headerChildren.add(const SizedBox(width: 8));
      headerChildren.add(Text(
        '+ ${ability.characteristicSummary}',
        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ));
    }

    final rows = ability.tiers
        .map((tier) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: scheme.surfaceVariant.withOpacity(0.85),
                    ),
                    child: Text(
                      tier.label,
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AbilityTextHighlighter.highlightGameMechanics(
                          tier.primaryText,
                          context,
                          baseStyle: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        if (tier.secondaryText != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child:
                                AbilityTextHighlighter.highlightGameMechanics(
                              tier.secondaryText!,
                              context,
                              baseStyle: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: headerChildren,
        ),
        if (rows.isNotEmpty) ...[
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rows,
          ),
        ],
      ],
    );
  }

  Widget _buildCharacteristicChip(BuildContext context, String label) {
    final theme = Theme.of(context);
    final color = CharacteristicTokens.color(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildLabeledText(
    BuildContext context,
    String label,
    String text,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label:',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        AbilityTextHighlighter.highlightGameMechanics(
          text,
          context,
          baseStyle: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}
