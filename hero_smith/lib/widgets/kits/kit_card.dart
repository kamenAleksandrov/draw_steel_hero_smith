import 'package:flutter/material.dart';
import 'package:hero_smith/core/models/component.dart';
import 'package:hero_smith/core/services/ability_data_service.dart';
import 'package:hero_smith/widgets/shared/expandable_card.dart';
import 'package:hero_smith/core/theme/kit_theme.dart';
import 'package:hero_smith/widgets/kits/kit_components.dart';
import 'package:hero_smith/widgets/abilities/ability_expandable_item.dart';

class KitCard extends StatefulWidget {
  final Component component;
  final bool initiallyExpanded;
  
  const KitCard({
    super.key, 
    required this.component,
    this.initiallyExpanded = false,
  });

  @override
  State<KitCard> createState() => _KitCardState();
}

class _KitCardState extends State<KitCard> {
  Component? _signatureAbility;
  bool _loadingAbility = false;

  @override
  void initState() {
    super.initState();
    _loadSignatureAbility();
  }

  Future<void> _loadSignatureAbility() async {
    final signatureAbilityName = widget.component.data['signature_ability'] as String?;
    if (signatureAbilityName == null || signatureAbilityName.isEmpty) return;

    setState(() => _loadingAbility = true);

    try {
      final abilityService = AbilityDataService();
      final library = await abilityService.loadLibrary();
      
      // Try to find the ability by name
      final ability = library.find(signatureAbilityName);
      
      if (mounted) {
        setState(() {
          _signatureAbility = ability;
          _loadingAbility = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingAbility = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.component.data;
    final equipment = data['equipment'] as Map<String, dynamic>?;
    final meleeDamage = data['melee_damage_bonus'] as Map<String, dynamic>?;
    final rangedDamage = data['ranged_damage_bonus'] as Map<String, dynamic>?;
    final stamina = data['stamina_bonus'] as int?;
    final speed = data['speed_bonus'] as int?;
    final disengageBonus = data['disengage_bonus'] as int?;
    final stability = data['stability_bonus'] as int?;
    final colorScheme = KitTheme.getColorScheme('kit');

    return ExpandableCard(
      title: widget.component.name,
      borderColor: colorScheme.borderColor,
      badge: KitComponents.kitBadge(kitType: 'kit', displayName: 'Kit'),
      initiallyExpanded: widget.initiallyExpanded,
      expandedContent: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compact stats row - stamina, speed, stability, disengage
          if (stamina != null || speed != null || stability != null || (disengageBonus != null && disengageBonus > 0))
            KitComponents.chipRow(
              context: context,
              items: [
                if (stamina != null && stamina > 0) KitComponents.formatBonusWithEmoji('stamina', stamina),
                if (speed != null && speed > 0) KitComponents.formatBonusWithEmoji('speed', speed),
                if (stability != null && stability > 0) KitComponents.formatBonusWithEmoji('stability', stability),
                if (disengageBonus != null && disengageBonus > 0) KitComponents.formatBonusWithEmoji('disengage', disengageBonus),
              ],
              primaryColor: colorScheme.primary,
            ),
          // Damage bonuses - using new tierBonusBox
          if (meleeDamage != null && _hasNonNullValues(meleeDamage))
            KitComponents.tierBonusBox(
              context: context,
              title: '⚔️ Melee Damage',
              data: meleeDamage,
              primaryColor: colorScheme.primary,
            ),
          if (rangedDamage != null && _hasNonNullValues(rangedDamage))
            KitComponents.tierBonusBox(
              context: context,
              title: '🏹 Ranged Damage',
              data: rangedDamage,
              primaryColor: colorScheme.primary,
            ),
          // Distance bonuses - using echelonBonusBox
          if (data['melee_distance_bonus'] != null && _hasNonNullValues(data['melee_distance_bonus'] as Map<String, dynamic>))
            KitComponents.echelonBonusBox(
              context: context,
              title: '📏 Melee Distance',
              data: data['melee_distance_bonus'] as Map<String, dynamic>,
              primaryColor: colorScheme.primary,
            ),
          if (data['ranged_distance_bonus'] != null && _hasNonNullValues(data['ranged_distance_bonus'] as Map<String, dynamic>))
            KitComponents.echelonBonusBox(
              context: context,
              title: '🎯 Ranged Distance',
              data: data['ranged_distance_bonus'] as Map<String, dynamic>,
              primaryColor: colorScheme.primary,
            ),
          // Description
          if (data['description'] != null)
            KitComponents.section(
              context: context,
              label: 'Description',
              child: Text(data['description'] as String),
              primaryColor: colorScheme.primary,
            ),
          // Equipment
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
          // Signature ability - display full ability if loaded
          if (_signatureAbility != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KitComponents.sectionHeader(
                    context: context,
                    label: '✨ Signature Ability',
                    primaryColor: colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  AbilityExpandableItem(component: _signatureAbility!),
                ],
              ),
            )
          else if (_loadingAbility)
            KitComponents.section(
              context: context,
              label: '✨ Signature Ability',
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              primaryColor: colorScheme.primary,
            )
          else if (data['signature_ability'] != null)
            KitComponents.section(
              context: context,
              label: '✨ Signature Ability',
              child: Text(
                data['signature_ability'] as String,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
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


