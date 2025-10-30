import 'package:flutter/material.dart';
import 'package:hero_smith/core/models/component.dart';
import 'package:hero_smith/widgets/shared/expandable_card.dart';
import 'package:hero_smith/core/theme/kit_theme.dart';
import 'package:hero_smith/widgets/kits/kit_components.dart';

class WardCard extends StatelessWidget {
  final Component component;
  const WardCard({super.key, required this.component});

  @override
  Widget build(BuildContext context) {
    final d = component.data;
    final colorScheme = KitTheme.getColorScheme('ward');
    
    return ExpandableCard(
      title: component.name,
      borderColor: colorScheme.borderColor,
      badge: KitComponents.kitBadge(kitType: 'ward', displayName: 'Ward'),
      expandedContent: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (d['characteristic_score'] != null)
            KitComponents.chipRow(
              context: context,
              items: [KitComponents.formatBonusWithEmoji('characteristic', d['characteristic_score'])],
              primaryColor: colorScheme.primary,
            ),
          if (d['description'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(d['description'] as String),
            ),
        ],
      ),
    );
  }
}
