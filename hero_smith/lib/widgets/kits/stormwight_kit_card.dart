import 'package:flutter/material.dart';
import 'package:hero_smith/core/models/component.dart';
import 'package:hero_smith/core/theme/kit_theme.dart';
import 'package:hero_smith/widgets/shared/expandable_card.dart';
import 'package:hero_smith/widgets/kits/kit_components.dart';

class StormwightKitCard extends StatelessWidget {
  final Component component;
  const StormwightKitCard({super.key, required this.component});

  @override
  Widget build(BuildContext context) {
    final d = component.data;
    const primaryColor = Colors.indigo;
    
    return ExpandableCard(
      title: component.name,
      borderColor: primaryColor.shade400,
      badge: KitComponents.themedChip(
        context: context,
        text: '${KitTheme.kitTypeEmojis['stormwight']} Stormwight Kit',
        primaryColor: primaryColor,
        isBold: true,
      ),
      expandedContent: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (d['stormwight_benefits'] != null)
            KitComponents.section(context: context, label: 'Stormwight Benefits', child: Text(d['stormwight_benefits'] as String), primaryColor: primaryColor),
          if (d['aspect_benefits'] != null)
            KitComponents.section(context: context, label: 'Aspect Benefits', child: Text(d['aspect_benefits'] as String), primaryColor: primaryColor),
          if (d['primordial_storm'] != null)
            KitComponents.section(context: context, label: 'Primordial Storm', child: _stormList(d['primordial_storm'] as List), primaryColor: primaryColor),
          if (d['equipment_description'] != null)
            KitComponents.section(context: context, label: 'Equipment', child: Text(d['equipment_description'] as String), primaryColor: primaryColor),
          if (d['equipment'] != null)
            KitComponents.section(context: context, label: 'Equipment Types', child: _equip(context, d['equipment'] as Map<String, dynamic>), primaryColor: primaryColor),
          if ((d['stamina_bonus'] != null && d['stamina_bonus'] > 0) || 
              (d['speed_bonus'] != null && d['speed_bonus'] > 0) || 
              (d['disengage_bonus'] != null && d['disengage_bonus'] > 0))
            KitComponents.chipRow(
              context: context,
              items: [
                if (d['stamina_bonus'] != null && d['stamina_bonus'] > 0) KitComponents.formatBonusWithEmoji('stamina', d['stamina_bonus']),
                if (d['speed_bonus'] != null && d['speed_bonus'] > 0) KitComponents.formatBonusWithEmoji('speed', d['speed_bonus']),
                if (d['disengage_bonus'] != null && d['disengage_bonus'] > 0) KitComponents.formatBonusWithEmoji('disengage', d['disengage_bonus']),
              ],
              primaryColor: primaryColor,
            ),
          if (d['melee_damage_bonus'] != null && _hasNonNullValues(d['melee_damage_bonus'] as Map<String, dynamic>))
            KitComponents.echelonBonusBox(
              context: context,
              title: 'Melee Damage Bonus',
              data: d['melee_damage_bonus'] as Map<String, dynamic>,
              primaryColor: primaryColor,
            ),
          if (d['ranged_damage_bonus'] != null && _hasNonNullValues(d['ranged_damage_bonus'] as Map<String, dynamic>))
            KitComponents.echelonBonusBox(
              context: context,
              title: 'Ranged Damage Bonus',
              data: d['ranged_damage_bonus'] as Map<String, dynamic>,
              primaryColor: primaryColor,
            ),
          if (d['signature_ability'] != null)
            KitComponents.section(context: context, label: 'Signature Ability', child: Text(d['signature_ability'] as String), primaryColor: primaryColor),
          if (d['feature'] != null)
            KitComponents.section(context: context, label: 'Feature', child: Text(d['feature'] as String), primaryColor: primaryColor),
        ],
      ),
    );
  }

  Widget _stormList(List list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: list
          .map((e) => e is Map<String, dynamic>
              ? Text(e.values.first.toString())
              : Text(e.toString()))
          .toList(),
    );
  }

  Widget _equip(BuildContext context, Map<String, dynamic> eq) {
    final armor = (eq['armor'] as Map?)?.cast<String, dynamic>() ?? {};
    final weapons = (eq['weapons'] as Map?)?.cast<String, dynamic>() ?? {};
    final chips = <Widget>[];
    chips.addAll(armor.entries.where((e) => e.value == true).map((e) => KitComponents.themedChip(
      context: context,
      text: 'Armor: ${_humanReadableEquipment(e.key)}',
      primaryColor: Colors.indigo,
    )));
    chips.addAll(weapons.entries.where((e) => e.value == true).map((e) => KitComponents.themedChip(
      context: context,
      text: 'Weapon: ${_humanReadableEquipment(e.key)}',
      primaryColor: Colors.indigo,
    )));
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



  bool _hasNonNullValues(Map<String, dynamic> map) {
    return map.values.any((v) => v != null);
  }
}
