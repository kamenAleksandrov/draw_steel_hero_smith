import 'package:flutter/material.dart';
import '../../core/models/component.dart';
import 'ability_summary.dart';
import 'ability_full_view.dart';

class AbilityExpandableItem extends StatefulWidget {
  final Component component;
  const AbilityExpandableItem({super.key, required this.component});

  @override
  State<AbilityExpandableItem> createState() => _AbilityExpandableItemState();
}

class _AbilityExpandableItemState extends State<AbilityExpandableItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _expanded 
            ? scheme.primary.withOpacity(0.3)
            : scheme.outline.withOpacity(0.2),
          width: _expanded ? 2 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Material(
              color: _expanded 
                ? scheme.primaryContainer.withOpacity(0.3)
                : Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Row(
                  children: [
                    Expanded(child: AbilitySummary(component: widget.component)),
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: scheme.primary,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded)
              Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withOpacity(0.4),
                  border: Border(
                    top: BorderSide(
                      color: scheme.primary.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: AbilityFullView(component: widget.component),
              ),
          ],
        ),
      ),
    );
  }
}
