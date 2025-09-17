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
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  Expanded(child: AbilitySummary(component: widget.component)),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
            if (_expanded)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: AbilityFullView(component: widget.component),
              ),
          ],
        ),
      ),
    );
  }
}
