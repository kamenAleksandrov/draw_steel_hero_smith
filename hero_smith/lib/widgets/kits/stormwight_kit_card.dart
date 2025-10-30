import 'package:flutter/material.dart';
import 'package:hero_smith/core/models/component.dart';
import 'package:hero_smith/core/services/ability_data_service.dart';
import 'package:hero_smith/core/theme/kit_theme.dart';
import 'package:hero_smith/widgets/shared/expandable_card.dart';
import 'package:hero_smith/widgets/kits/kit_components.dart';
import 'package:hero_smith/widgets/abilities/ability_expandable_item.dart';

class StormwightKitCard extends StatefulWidget {
  final Component component;
  const StormwightKitCard({super.key, required this.component});

  @override
  State<StormwightKitCard> createState() => _StormwightKitCardState();
}

class _StormwightKitCardState extends State<StormwightKitCard> {
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
    final d = widget.component.data;
    const primaryColor = Colors.indigo;
    
    return ExpandableCard(
      title: widget.component.name,
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
          // Compact stats row
          if ((d['stamina_bonus'] != null && d['stamina_bonus'] > 0) || 
              (d['speed_bonus'] != null && d['speed_bonus'] > 0) ||
              (d['stability_bonus'] != null && d['stability_bonus'] > 0) ||
              (d['disengage_bonus'] != null && d['disengage_bonus'] > 0))
            KitComponents.chipRow(
              context: context,
              items: [
                if (d['stamina_bonus'] != null && d['stamina_bonus'] > 0) KitComponents.formatBonusWithEmoji('stamina', d['stamina_bonus']),
                if (d['speed_bonus'] != null && d['speed_bonus'] > 0) KitComponents.formatBonusWithEmoji('speed', d['speed_bonus']),
                if (d['stability_bonus'] != null && d['stability_bonus'] > 0) KitComponents.formatBonusWithEmoji('stability', d['stability_bonus']),
                if (d['disengage_bonus'] != null && d['disengage_bonus'] > 0) KitComponents.formatBonusWithEmoji('disengage', d['disengage_bonus']),
              ],
              primaryColor: primaryColor,
            ),
          // Damage bonuses - using new tierBonusBox
          if (d['melee_damage_bonus'] != null && _hasNonNullValues(d['melee_damage_bonus'] as Map<String, dynamic>))
            KitComponents.tierBonusBox(
              context: context,
              title: '⚔️ Melee Damage',
              data: d['melee_damage_bonus'] as Map<String, dynamic>,
              primaryColor: primaryColor,
            ),
          if (d['ranged_damage_bonus'] != null && _hasNonNullValues(d['ranged_damage_bonus'] as Map<String, dynamic>))
            KitComponents.tierBonusBox(
              context: context,
              title: '🏹 Ranged Damage',
              data: d['ranged_damage_bonus'] as Map<String, dynamic>,
              primaryColor: primaryColor,
            ),
          // Stormwight benefits
          if (d['stormwight_benefits'] != null)
            KitComponents.section(context: context, label: 'Stormwight Benefits', child: Text(d['stormwight_benefits'] as String), primaryColor: primaryColor),
          if (d['aspect_benefits'] != null)
            KitComponents.section(context: context, label: 'Aspect Benefits', child: Text(d['aspect_benefits'] as String), primaryColor: primaryColor),
          if (d['primordial_storm'] != null)
            KitComponents.section(context: context, label: 'Primordial Storm', child: _stormList(d['primordial_storm'] as List), primaryColor: primaryColor),
          // Equipment
          if (d['equipment_description'] != null)
            KitComponents.section(context: context, label: 'Equipment', child: Text(d['equipment_description'] as String), primaryColor: primaryColor),
          if (d['equipment'] != null)
            KitComponents.section(context: context, label: 'Equipment Types', child: _equip(context, d['equipment'] as Map<String, dynamic>), primaryColor: primaryColor),
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
                    primaryColor: primaryColor,
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
              primaryColor: primaryColor,
            )
          else if (d['signature_ability'] != null)
            KitComponents.section(context: context, label: '✨ Signature Ability', child: Text(d['signature_ability'] as String, style: const TextStyle(fontWeight: FontWeight.w600)), primaryColor: primaryColor),
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
