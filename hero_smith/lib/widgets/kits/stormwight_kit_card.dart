import 'package:flutter/material.dart';
import 'package:hero_smith/core/models/component.dart';
import 'package:hero_smith/core/services/ability_data_service.dart';
import 'package:hero_smith/core/theme/kit_theme.dart';
import 'package:hero_smith/widgets/abilities/ability_expandable_item.dart';

class StormwightKitCard extends StatefulWidget {
  final Component component;
  final bool initiallyExpanded;
  
  const StormwightKitCard({
    super.key, 
    required this.component,
    this.initiallyExpanded = false,
  });

  @override
  State<StormwightKitCard> createState() => _StormwightKitCardState();
}

class _StormwightKitCardState extends State<StormwightKitCard> with SingleTickerProviderStateMixin {
  Component? _signatureAbility;
  bool _loadingAbility = false;
  late bool _isExpanded;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
      value: widget.initiallyExpanded ? 1.0 : 0.0,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _loadSignatureAbility();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  Future<void> _loadSignatureAbility() async {
    final signatureAbilityName = widget.component.data['signature_ability'] as String?;
    if (signatureAbilityName == null || signatureAbilityName.isEmpty) return;

    setState(() => _loadingAbility = true);

    try {
      final abilityService = AbilityDataService();
      final library = await abilityService.loadLibrary();
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
    final colorScheme = KitTheme.getColorScheme('stormwight');
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isExpanded 
              ? colorScheme.borderColor 
              : colorScheme.borderColor.withOpacity(0.5),
          width: _isExpanded ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.borderColor.withOpacity(_isExpanded ? 0.25 : 0.12),
            blurRadius: _isExpanded ? 16 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _toggleExpanded,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, d, colorScheme, isDark),
              SizeTransition(
                sizeFactor: _expandAnimation,
                child: _buildExpandedContent(context, d, colorScheme, isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Map<String, dynamic> data, 
      KitColorScheme colorScheme, bool isDark) {
    final stamina = data['stamina_bonus'] as int?;
    final speed = data['speed_bonus'] as int?;
    final stability = data['stability_bonus'] as int?;
    final disengage = data['disengage_bonus'] as int?;
    final equipment = data['equipment'] as Map<String, dynamic>?;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.component.name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.grey.shade900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: colorScheme.badgeBackground.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: colorScheme.borderColor.withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        'STORMWIGHT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary.shade400,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: _isExpanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 280),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: colorScheme.primary.shade400,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          if (stamina != null || speed != null || stability != null || 
              (disengage != null && disengage > 0)) ...[
            const SizedBox(height: 14),
            _buildQuickStats(context, stamina, speed, stability, disengage, colorScheme, isDark),
          ],
          if (!_isExpanded && equipment != null) ...[
            const SizedBox(height: 10),
            _buildEquipmentChips(equipment, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context, int? stamina, int? speed, 
      int? stability, int? disengage, KitColorScheme colorScheme, bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (stamina != null && stamina > 0)
          _buildStatPill('STM', '+$stamina', Colors.red, isDark),
        if (speed != null && speed > 0)
          _buildStatPill('SPD', '+$speed', Colors.blue, isDark),
        if (stability != null && stability > 0)
          _buildStatPill('STB', '+$stability', Colors.green, isDark),
        if (disengage != null && disengage > 0)
          _buildStatPill('DSG', '+$disengage', Colors.orange, isDark),
      ],
    );
  }

  Widget _buildStatPill(String label, String value, 
      MaterialColor color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.3 : 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? color.shade300 : color.shade600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? color.shade300 : color.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentChips(Map<String, dynamic> equipment, bool isDark) {
    final armor = (equipment['armor'] as Map?)?.cast<String, dynamic>() ?? {};
    final weapons = (equipment['weapons'] as Map?)?.cast<String, dynamic>() ?? {};
    
    final chips = <Widget>[];
    
    for (final entry in armor.entries) {
      if (entry.value == true) {
        chips.add(_buildEquipmentChip(_humanReadableEquipment(entry.key), Colors.blue, isDark));
      }
    }
    
    for (final entry in weapons.entries) {
      if (entry.value == true) {
        chips.add(_buildEquipmentChip(_humanReadableEquipment(entry.key), Colors.red, isDark));
      }
    }
    
    if (chips.isEmpty) return const SizedBox.shrink();
    
    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }

  Widget _buildEquipmentChip(String text, MaterialColor color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.25 : 0.15),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isDark ? color.shade300 : color.shade700,
        ),
      ),
    );
  }

  Widget _buildExpandedContent(BuildContext context, Map<String, dynamic> data, 
      KitColorScheme colorScheme, bool isDark) {
    final equipment = data['equipment'] as Map<String, dynamic>?;
    final meleeDamage = data['melee_damage_bonus'] as Map<String, dynamic>?;
    final rangedDamage = data['ranged_damage_bonus'] as Map<String, dynamic>?;
    final primordialStorm = data['primordial_storm'] as List?;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: colorScheme.borderColor.withOpacity(0.3), height: 1),
          const SizedBox(height: 16),
          
          if ((meleeDamage != null && _hasNonNullValues(meleeDamage)) ||
              (rangedDamage != null && _hasNonNullValues(rangedDamage)))
            _buildDamageBonusSection(context, meleeDamage, rangedDamage, colorScheme, isDark),
          
          if (data['stormwight_benefits'] != null)
            _buildSection(
              context: context,
              title: 'Stormwight Benefits',
              child: Text(
                data['stormwight_benefits'] as String,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ),
              colorScheme: colorScheme,
              isDark: isDark,
            ),
          
          if (data['aspect_benefits'] != null)
            _buildSection(
              context: context,
              title: 'Aspect Benefits',
              child: Text(
                data['aspect_benefits'] as String,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ),
              colorScheme: colorScheme,
              isDark: isDark,
            ),
          
          if (primordialStorm != null && primordialStorm.isNotEmpty)
            _buildSection(
              context: context,
              title: 'Primordial Storm',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: primordialStorm.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    e is Map<String, dynamic> ? e.values.first.toString() : e.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    ),
                  ),
                )).toList(),
              ),
              colorScheme: colorScheme,
              isDark: isDark,
            ),
          
          if (data['equipment_description'] != null || equipment != null)
            _buildEquipmentSection(context, data, equipment, colorScheme, isDark),
          
          if (data['feature'] != null)
            _buildSection(
              context: context,
              title: 'Feature',
              child: Text(
                data['feature'] as String,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ),
              colorScheme: colorScheme,
              isDark: isDark,
            ),
          
          _buildSignatureAbilitySection(context, data, colorScheme, isDark),
        ],
      ),
    );
  }

  Widget _buildEquipmentSection(BuildContext context, Map<String, dynamic> data,
      Map<String, dynamic>? equipment, KitColorScheme colorScheme, bool isDark) {
    final armor = (equipment?['armor'] as Map?)?.cast<String, dynamic>() ?? {};
    final weapons = (equipment?['weapons'] as Map?)?.cast<String, dynamic>() ?? {};
    
    final chips = <Widget>[];
    
    for (final entry in armor.entries) {
      if (entry.value == true) {
        chips.add(_buildEquipmentChip(_humanReadableEquipment(entry.key), Colors.blue, isDark));
      }
    }
    
    for (final entry in weapons.entries) {
      if (entry.value == true) {
        chips.add(_buildEquipmentChip(_humanReadableEquipment(entry.key), Colors.red, isDark));
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EQUIPMENT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          if (data['equipment_description'] != null) ...[
            Text(
              data['equipment_description'] as String,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
            if (chips.isNotEmpty) const SizedBox(height: 10),
          ],
          if (chips.isNotEmpty)
            Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      ),
    );
  }

  Widget _buildDamageBonusSection(BuildContext context, Map<String, dynamic>? melee,
      Map<String, dynamic>? ranged, KitColorScheme colorScheme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark 
              ? Colors.grey.shade900.withOpacity(0.5) 
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up_rounded, 
                    size: 18, 
                    color: colorScheme.primary.shade400),
                const SizedBox(width: 8),
                Text(
                  'DAMAGE BONUSES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (melee != null && _hasNonNullValues(melee))
              _buildTierRow('Melee', melee, isDark),
            if (ranged != null && _hasNonNullValues(ranged)) ...[
              if (melee != null && _hasNonNullValues(melee))
                const SizedBox(height: 10),
              _buildTierRow('Ranged', ranged, isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTierRow(String label, Map<String, dynamic> data, bool isDark) {
    final tier1 = data['1st_tier'];
    final tier2 = data['2nd_tier'];
    final tier3 = data['3rd_tier'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (tier1 != null) _buildTierBox('T1', '+$tier1', '\u226411', isDark),
            if (tier2 != null) _buildTierBox('T2', '+$tier2', '12-16', isDark),
            if (tier3 != null) _buildTierBox('T3', '+$tier3', '17+', isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildTierBox(String tier, String value, String subtitle, bool isDark) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade800 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required Widget child,
    required KitColorScheme colorScheme,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildSignatureAbilitySection(BuildContext context, Map<String, dynamic> data,
      KitColorScheme colorScheme, bool isDark) {
    if (_signatureAbility != null) {
      return SizedBox(
        width: double.infinity,
        child: AbilityExpandableItem(component: _signatureAbility!),
      );
    } else if (_loadingAbility) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.primary,
            ),
          ),
        ),
      );
    } else if (data['signature_ability'] != null) {
      return _buildSection(
        context: context,
        title: 'Signature Ability',
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(isDark ? 0.1 : 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.primary.withOpacity(0.2),
            ),
          ),
          child: Text(
            data['signature_ability'] as String,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? colorScheme.primary.shade300 : colorScheme.primary.shade700,
            ),
          ),
        ),
        colorScheme: colorScheme,
        isDark: isDark,
      );
    }
    return const SizedBox.shrink();
  }

  bool _hasNonNullValues(Map<String, dynamic> map) {
    return map.values.any((v) => v != null);
  }

  String _humanReadableEquipment(String key) {
    switch (key) {
      case 'ensnaring_weapon': return 'Ensnaring';
      case 'bow': return 'Bow';
      case 'light': return 'Light';
      case 'medium': return 'Medium';
      case 'heavy': return 'Heavy';
      case 'polearm': return 'Polearm';
      case 'unarmed_strikes': return 'Unarmed';
      case 'whip': return 'Whip';
      case 'none': return 'None';
      case 'shield': return 'Shield';
      default: return key.replaceAll('_', ' ').split(' ')
          .map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
    }
  }
}
