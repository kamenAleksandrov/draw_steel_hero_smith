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

class _AbilityExpandableItemState extends State<AbilityExpandableItem>
    with AutomaticKeepAliveClientMixin {
  bool _expanded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final ability = AbilityData.fromComponent(widget.component);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Use action type color for border, fallback to primary if no action type
    final borderColor = ability.actionType != null
        ? ActionTokens.color(ability.actionType!)
        : scheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        // Use app background color (dark grey/bluish)
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
          width: _expanded ? 2.5 : 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: _expanded ? 0.35 : 0.25),
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
              mainAxisSize: MainAxisSize.min,
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
                ClipRect(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: _expanded
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
