import 'package:flutter/material.dart';
import 'package:hero_smith/core/models/component.dart';
import 'package:hero_smith/core/theme/kit_theme.dart';

class WardCard extends StatefulWidget {
  final Component component;
  final bool initiallyExpanded;
  
  const WardCard({
    super.key, 
    required this.component,
    this.initiallyExpanded = false,
  });

  @override
  State<WardCard> createState() => _WardCardState();
}

class _WardCardState extends State<WardCard> with SingleTickerProviderStateMixin {
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

  @override
  Widget build(BuildContext context) {
    final d = widget.component.data;
    final colorScheme = KitTheme.getColorScheme('ward');
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
    final characteristicScore = data['characteristic_score'];

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
                        'WARD',
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
          if (characteristicScore != null) ...[
            const SizedBox(height: 14),
            _buildCharacteristicPill(characteristicScore, colorScheme, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildCharacteristicPill(dynamic score, KitColorScheme colorScheme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.primary.withOpacity(isDark ? 0.3 : 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'CHAR',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? colorScheme.primary.shade300 : colorScheme.primary.shade600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$score',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? colorScheme.primary.shade300 : colorScheme.primary.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(BuildContext context, Map<String, dynamic> data, 
      KitColorScheme colorScheme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: colorScheme.borderColor.withOpacity(0.3), height: 1),
          const SizedBox(height: 16),
          
          if (data['description'] != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DESCRIPTION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  data['description'] as String,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
