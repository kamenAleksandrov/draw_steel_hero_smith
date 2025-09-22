import 'package:flutter/material.dart';
import 'package:hero_smith/core/models/component.dart';
import 'package:hero_smith/widgets/shared/expandable_card.dart';
import 'package:hero_smith/core/theme/kit_theme.dart';
import 'package:hero_smith/widgets/kits/kit_components.dart';

class KitCard extends StatelessWidget {
  final Component component;
  const KitCard({super.key, required this.component});

  @override
  Widget build(BuildContext context) {
    final data = component.data;
    final equipment = data['equipment'] as Map<String, dynamic>?;
    final meleeDamage = data['melee_damage_bonus'] as Map<String, dynamic>?;
    final rangedDamage = data['ranged_damage_bonus'] as Map<String, dynamic>?;
    final stamina = data['stamina_bonus'] as int?;
    final speed = data['speed_bonus'] as int?;
    final disengageBonus = data['disengage_bonus'] as int?;
    final colorScheme = KitTheme.getColorScheme('kit');

    return ExpandableCard(
      title: component.name,
      borderColor: colorScheme.borderColor,
      badge: KitComponents.kitBadge(kitType: 'kit', displayName: 'Kit'),
      // preview: KitComponents.previewChips(
      //   context: context,
      //   items: [
      //     if (stamina != null && stamina > 0) KitComponents.formatBonusWithEmoji('stamina', stamina),
      //     if (speed != null && speed > 0) KitComponents.formatBonusWithEmoji('speed', speed),
      //     if (disengageBonus != null && disengageBonus > 0) KitComponents.formatBonusWithEmoji('disengage', disengageBonus),
      //   ],
      //   primaryColor: colorScheme.primary,
      // ),
      expandedContent: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data['description'] != null)
            KitComponents.section(
              context: context,
              label: 'Description',
              child: Text(data['description'] as String),
              primaryColor: colorScheme.primary,
            ),
          if (data['equipment_description'] != null)
            KitComponents.section(
              context: context,
              label: 'Equipment',
              child: Text(data['equipment_description'] as String),
              primaryColor: colorScheme.primary,
            ),
          if (equipment != null)
            KitComponents.section(
              context: context,
              label: 'Equipment Types',
              child: _EquipmentGrid(equipment: equipment, primaryColor: colorScheme.primary),
              primaryColor: colorScheme.primary,
            ),
          if (stamina != null || speed != null || (disengageBonus != null && disengageBonus > 0))
            KitComponents.chipRow(
              context: context,
              items: [
                if (stamina != null && stamina > 0) KitComponents.formatBonusWithEmoji('stamina', stamina),
                if (speed != null && speed > 0) KitComponents.formatBonusWithEmoji('speed', speed),
                if (disengageBonus != null && disengageBonus > 0) KitComponents.formatBonusWithEmoji('disengage', disengageBonus),
              ],
              primaryColor: colorScheme.primary,
            ),
          if (meleeDamage != null && _hasNonNullValues(meleeDamage))
            KitComponents.echelonBonusBox(
              context: context,
              title: 'Melee Damage Bonus',
              data: meleeDamage,
              primaryColor: colorScheme.primary,
            ),
          if (rangedDamage != null && _hasNonNullValues(rangedDamage))
            KitComponents.echelonBonusBox(
              context: context,
              title: 'Ranged Damage Bonus',
              data: rangedDamage,
              primaryColor: colorScheme.primary,
            ),
          if (data['melee_distance_bonus'] != null && _hasNonNullValues(data['melee_distance_bonus'] as Map<String, dynamic>))
            KitComponents.echelonBonusBox(
              context: context,
              title: 'Melee Distance Bonus',
              data: data['melee_distance_bonus'] as Map<String, dynamic>,
              primaryColor: colorScheme.primary,
            ),
          if (data['ranged_distance_bonus'] != null && _hasNonNullValues(data['ranged_distance_bonus'] as Map<String, dynamic>))
            KitComponents.echelonBonusBox(
              context: context,
              title: 'Ranged Distance Bonus',
              data: data['ranged_distance_bonus'] as Map<String, dynamic>,
              primaryColor: colorScheme.primary,
            ),
          if (data['signature_ability'] != null)
            KitComponents.section(
              context: context,
              label: 'Signature Ability',
              child: Text(data['signature_ability'] as String),
              primaryColor: colorScheme.primary,
            ),
        ],
      ),
    );
  }

  bool _hasNonNullValues(Map<String, dynamic> map) {
    return map.values.any((v) => v != null);
  }

}



class _EquipmentGrid extends StatelessWidget {
  final Map<String, dynamic> equipment;
  final MaterialColor primaryColor;
  
  const _EquipmentGrid({
    required this.equipment, 
    required this.primaryColor,
  });
  
  @override
  Widget build(BuildContext context) {
    final armor = (equipment['armor'] as Map?)?.cast<String, dynamic>() ?? {};
    final weapons = (equipment['weapons'] as Map?)?.cast<String, dynamic>() ?? {};
    List<Widget> chips = [];
    
    if (armor.isNotEmpty) {
      chips.addAll(armor.entries
          .where((e) => e.value == true)
          .map((e) => KitComponents.themedChip(
                context: context,
                text: 'Armor: ${_humanReadableEquipment(e.key)}',
                primaryColor: primaryColor,
              )));
    }
    
    if (weapons.isNotEmpty) {
      chips.addAll(weapons.entries
          .where((e) => e.value == true)
          .map((e) => KitComponents.themedChip(
                context: context,
                text: 'Weapon: ${_humanReadableEquipment(e.key)}',
                primaryColor: primaryColor,
              )));
    }
    
    if (chips.isEmpty) return const Text('None');
    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }

  String _humanReadableEquipment(String key) {
    switch (key) {
      case 'ensnaring_weapon': return 'Ensnaring Weapon';
      case 'bow': return 'Bow';
      case 'light': return 'Light Weapon';
      case 'medium': return 'Medium Weapon';
      case 'heavy': return 'Heavy Weapon';
      case 'polearm': return 'Polearm';
      case 'unarmed_strikes': return 'Unarmed Strikes';
      case 'whip': return 'Whip';
      case 'none': return 'No Armor';
      case 'shield': return 'Shield';
      default: return key.replaceAll('_', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
    }
  }
}


