import 'package:flutter/material.dart';
import 'package:hero_smith/core/models/component.dart';
import 'package:hero_smith/widgets/shared/expandable_card.dart';
import 'package:hero_smith/core/theme/kit_theme.dart';
import 'package:hero_smith/widgets/kits/kit_components.dart';

class ModifierCard extends StatelessWidget {
  final Component component;
  final String badgeLabel; // Augmentation / Enchantment / Prayer
  const ModifierCard({super.key, required this.component, required this.badgeLabel});

  @override
  Widget build(BuildContext context) {
    final d = component.data;
    final keywords = (d['keywords'] as List?)?.cast<String>();
    final colorScheme = KitTheme.getColorScheme('modifier');

    return ExpandableCard(
      title: component.name,
      borderColor: colorScheme.borderColor,
      badge: KitComponents.kitBadge(kitType: 'modifier', displayName: badgeLabel),
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
          if (keywords != null && keywords.isNotEmpty)
            KitComponents.section(
              context: context,
              label: 'Keywords',
              child: Wrap(
                spacing: 6,
                children: keywords.map((k) => KitComponents.themedChip(
                  context: context,
                  text: k,
                  primaryColor: colorScheme.primary,
                )).toList(),
              ),
              primaryColor: colorScheme.primary,
            ),
          // Generic bonuses if present - consolidated with emojis
          if (d.entries.any((entry) => _isBonusField(entry.key) && entry.value != null))
            KitComponents.chipRow(
              context: context,
              items: [
                for (final entry in d.entries)
                  if (_isBonusField(entry.key) && entry.value != null)
                    KitComponents.formatBonusWithEmoji(entry.key, entry.value),
              ],
              primaryColor: colorScheme.primary,
            ),
          // Echelon-based bonuses (only show if they have non-null values)
          if (d['melee_damage_bonus'] != null && _hasNonNullValues(d['melee_damage_bonus'] as Map<String, dynamic>))
            KitComponents.echelonBonusBox(
              context: context,
              title: 'Melee Damage Bonus',
              data: d['melee_damage_bonus'] as Map<String, dynamic>,
              primaryColor: colorScheme.primary,
            ),
          if (d['ranged_damage_bonus'] != null && _hasNonNullValues(d['ranged_damage_bonus'] as Map<String, dynamic>))
            KitComponents.echelonBonusBox(
              context: context,
              title: 'Ranged Damage Bonus',
              data: d['ranged_damage_bonus'] as Map<String, dynamic>,
              primaryColor: colorScheme.primary,
            ),
          if (d['melee_distance_bonus'] != null && _hasNonNullValues(d['melee_distance_bonus'] as Map<String, dynamic>))
            KitComponents.echelonBonusBox(
              context: context,
              title: 'Melee Distance Bonus',
              data: d['melee_distance_bonus'] as Map<String, dynamic>,
              primaryColor: colorScheme.primary,
            ),
          if (d['ranged_distance_bonus'] != null && _hasNonNullValues(d['ranged_distance_bonus'] as Map<String, dynamic>))
            KitComponents.echelonBonusBox(
              context: context,
              title: 'Ranged Distance Bonus',
              data: d['ranged_distance_bonus'] as Map<String, dynamic>,
              primaryColor: colorScheme.primary,
            ),
        ],
      ),
    );
  }

  bool _isBonusField(String k) => const {
        'stamina_bonus',
        'speed_bonus',
        'stability_bonus',
        'disengage_bonus',
        'damage_bonus',
        'bonus_damage',
        // 'ranged_distance_bonus',
        // 'melee_distance_bonus',
      }.contains(k);

  bool _hasNonNullValues(Map<String, dynamic> map) {
    return map.values.any((v) => v != null);
  }
}
