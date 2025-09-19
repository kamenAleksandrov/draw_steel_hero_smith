import 'package:flutter/material.dart';
import 'package:hero_smith/core/models/component.dart';
import 'package:hero_smith/widgets/shared/expandable_card.dart';
import 'package:hero_smith/core/theme/kit_theme.dart';
import 'package:hero_smith/widgets/shared/kit_components.dart';

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
      preview: KitComponents.previewChips(
        context: context,
        items: _buildPreviewItems(d),
        primaryColor: colorScheme.primary,
      ),
      expandedContent: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (d['description'] != null)
            KitComponents.section(
              context: context,
              label: 'Description',
              child: Text(d['description'] as String),
              primaryColor: colorScheme.primary,
            ),
          if (d['characteristic_score'] != null)
            KitComponents.section(
              context: context,
              label: 'Characteristic',
              child: Text(d['characteristic_score'] as String),
              primaryColor: colorScheme.primary,
            ),
        ],
      ),
    );
  }

  List<String> _buildPreviewItems(Map<String, dynamic> d) {
    List<String> items = [];
    
    if (d['characteristic_score'] != null) {
      items.add('${KitTheme.getBonusEmoji('characteristic')} ${d['characteristic_score']}');
    }
    
    return items;
  }


}
