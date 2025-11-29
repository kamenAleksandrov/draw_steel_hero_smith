import 'package:flutter/material.dart';
import 'package:hero_smith/core/models/component.dart';
import 'package:hero_smith/core/theme/kit_theme.dart';

class ModifierCard extends StatefulWidget {
  final Component component;
  final String badgeLabel;
  final bool initiallyExpanded;
  
  const ModifierCard({
    super.key, 
    required this.component, 
    required this.badgeLabel,
    this.initiallyExpanded = false,
  });

  @override
  State<ModifierCard> createState() => _ModifierCardState();
}

class _ModifierCardState extends State<ModifierCard> with SingleTickerProviderStateMixin {
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

  String _getKitType() {
    final label = widget.badgeLabel.toLowerCase();
    if (label.contains('psionic') || label.contains('augmentation')) {
      return 'psionic_augmentation';
    } else if (label.contains('prayer')) {
      return 'prayer';
    } else if (label.contains('enchantment')) {
      return 'enchantment';
    }
    return 'modifier';
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.component.data;
    final kitType = _getKitType();
    final colorScheme = KitTheme.getColorScheme(kitType);
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
                        color: colorScheme.badgeBackground.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: colorScheme.borderColor.withOpacity(0.4),
                        ),
                      ),
                      child: Text(
                        widget.badgeLabel.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary.shade600,
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
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: colorScheme.primary.shade600,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          if (_hasQuickStats(data)) ...[
            const SizedBox(height: 14),
            _buildQuickStats(context, data, colorScheme, isDark),
          ],
        ],
      ),
    );
  }

  bool _hasQuickStats(Map<String, dynamic> data) {
    return data.entries.any((entry) => _isBonusField(entry.key) && entry.value != null);
  }

  Widget _buildQuickStats(BuildContext context, Map<String, dynamic> data, 
      KitColorScheme colorScheme, bool isDark) {
    final stats = <Widget>[];
    
    for (final entry in data.entries) {
      if (_isBonusField(entry.key) && entry.value != null) {
        stats.add(_buildStatPill(
          _getBonusAbbrev(entry.key),
          '+${entry.value}',
          _getBonusColor(entry.key),
          isDark,
        ));
      }
    }
    
    return Wrap(spacing: 8, runSpacing: 8, children: stats);
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

  Widget _buildExpandedContent(BuildContext context, Map<String, dynamic> data, 
      KitColorScheme colorScheme, bool isDark) {
    final keywords = (data['keywords'] as List?)?.cast<String>();
    final meleeDamage = data['melee_damage_bonus'] as Map<String, dynamic>?;
    final rangedDamage = data['ranged_damage_bonus'] as Map<String, dynamic>?;
    final meleeDistance = data['melee_distance_bonus'] as Map<String, dynamic>?;
    final rangedDistance = data['ranged_distance_bonus'] as Map<String, dynamic>?;

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
          
          if ((meleeDistance != null && _hasNonNullValues(meleeDistance)) ||
              (rangedDistance != null && _hasNonNullValues(rangedDistance)))
            _buildDistanceBonusSection(context, meleeDistance, rangedDistance, colorScheme, isDark),
          
          if (data['description'] != null)
            _buildSection(
              context: context,
              title: 'Description',
              child: Text(
                data['description'] as String,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ),
              colorScheme: colorScheme,
              isDark: isDark,
            ),
          
          if (keywords != null && keywords.isNotEmpty)
            _buildSection(
              context: context,
              title: 'Keywords',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: keywords.map((k) => _buildKeywordChip(k, colorScheme, isDark)).toList(),
              ),
              colorScheme: colorScheme,
              isDark: isDark,
            ),
        ],
      ),
    );
  }

  Widget _buildKeywordChip(String keyword, KitColorScheme colorScheme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.primary.withOpacity(isDark ? 0.25 : 0.15),
        ),
      ),
      child: Text(
        keyword,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isDark ? colorScheme.primary.shade300 : colorScheme.primary.shade700,
        ),
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
                    color: colorScheme.primary.shade500),
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

  Widget _buildDistanceBonusSection(BuildContext context, Map<String, dynamic>? melee,
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
                Icon(Icons.straighten_rounded, 
                    size: 18, 
                    color: colorScheme.primary.shade500),
                const SizedBox(width: 8),
                Text(
                  'DISTANCE BONUSES',
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
              _buildEchelonRow('Melee', melee, isDark),
            if (ranged != null && _hasNonNullValues(ranged)) ...[
              if (melee != null && _hasNonNullValues(melee))
                const SizedBox(height: 10),
              _buildEchelonRow('Ranged', ranged, isDark),
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

  Widget _buildEchelonRow(String label, Map<String, dynamic> data, bool isDark) {
    final e1 = data['1st_echelon'];
    final e2 = data['2nd_echelon'];
    final e3 = data['3rd_echelon'];

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
            if (e1 != null) _buildTierBox('1st', '+$e1', 'Echelon', isDark),
            if (e2 != null) _buildTierBox('2nd', '+$e2', 'Echelon', isDark),
            if (e3 != null) _buildTierBox('3rd', '+$e3', 'Echelon', isDark),
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

  bool _isBonusField(String k) => const {
    'stamina_bonus',
    'speed_bonus',
    'stability_bonus',
    'disengage_bonus',
    'damage_bonus',
    'bonus_damage',
  }.contains(k);

  String _getBonusAbbrev(String key) {
    switch (key) {
      case 'stamina_bonus': return 'STM';
      case 'speed_bonus': return 'SPD';
      case 'stability_bonus': return 'STB';
      case 'disengage_bonus': return 'DSG';
      case 'damage_bonus':
      case 'bonus_damage': return 'DMG';
      default: return key.substring(0, 3).toUpperCase();
    }
  }

  MaterialColor _getBonusColor(String key) {
    switch (key) {
      case 'stamina_bonus': return Colors.red;
      case 'speed_bonus': return Colors.blue;
      case 'stability_bonus': return Colors.green;
      case 'disengage_bonus': return Colors.orange;
      case 'damage_bonus':
      case 'bonus_damage': return Colors.purple;
      default: return Colors.grey;
    }
  }

  bool _hasNonNullValues(Map<String, dynamic> map) {
    return map.values.any((v) => v != null);
  }
}
