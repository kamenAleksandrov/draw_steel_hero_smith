import 'package:flutter/material.dart';

import '../../core/models/component.dart';
import '../../core/theme/semantic/semantic_tokens.dart';
import 'abilities_shared.dart';
import 'ability_full_view.dart';
import 'ability_summary.dart';

class AbilityExpandableItem extends StatefulWidget {
  const AbilityExpandableItem({super.key, required this.component});

  final Component component;

  @override
  State<AbilityExpandableItem> createState() => _AbilityExpandableItemState();
}

class _AbilityExpandableItemState extends State<AbilityExpandableItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ability = AbilityData(widget.component);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final resourceColor = ability.resourceType != null
        ? HeroicResourceTokens.color(ability.resourceType!)
        : scheme.primary;
    final borderColor =
        resourceColor.withValues(alpha: _expanded ? 0.75 : 0.45);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: resourceColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.22),
            blurRadius: _expanded ? 16 : 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AbilitySummary(
                        component: widget.component,
                        abilityData: ability,
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: borderColor,
                    ),
                  ],
                ),
                if (_expanded) ...[
                  const SizedBox(height: 16),
                  Divider(
                    color: borderColor.withValues(alpha: 0.5),
                    thickness: 1.1,
                    height: 1.1,
                  ),
                  const SizedBox(height: 16),
                  AbilityFullView(
                    component: widget.component,
                    abilityData: ability,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
