import 'package:flutter/material.dart';

import '../../../../core/models/downtime.dart';
import 'gear_utils.dart';

/// Card displaying an item enhancement with expandable details.
class EnhancementCard extends StatefulWidget {
  final DowntimeEntry enhancement;

  const EnhancementCard({super.key, required this.enhancement});

  @override
  State<EnhancementCard> createState() => _EnhancementCardState();
}

class _EnhancementCardState extends State<EnhancementCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
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

  String _getTypeDisplay(String enhancementType) {
    switch (enhancementType) {
      case 'armor_enhancement':
        return 'Armor';
      case 'weapon_enhancement':
        return 'Weapon';
      case 'implement_enhancement':
        return 'Implement';
      case 'shield_enhancement':
        return 'Shield';
      default:
        return enhancementType.replaceAll('_', ' ');
    }
  }

  IconData _getTypeIcon(String enhancementType) {
    switch (enhancementType) {
      case 'armor_enhancement':
        return Icons.shield;
      case 'weapon_enhancement':
        return Icons.sports_martial_arts;
      case 'implement_enhancement':
        return Icons.auto_awesome;
      case 'shield_enhancement':
        return Icons.security;
      default:
        return Icons.auto_fix_high;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enhancementType = widget.enhancement.raw['type'] as String? ?? '';
    final level = widget.enhancement.raw['level'] as int?;
    final description = widget.enhancement.raw['description'] as String? ?? '';
    final typeDisplay = _getTypeDisplay(enhancementType);
    final typeIcon = _getTypeIcon(enhancementType);

    // Use orange scheme matching treasure card styling exactly
    const primaryColor = Colors.orange;
    final cardBorderColor = theme.brightness == Brightness.dark
      ? primaryColor.shade600.withOpacity(0.3)
      : primaryColor.shade300.withOpacity(0.5);
    final cardBgColor = theme.brightness == Brightness.dark
      ? const Color.fromARGB(255, 37, 36, 36)
      : Colors.white;

    return Card(
      margin: EdgeInsets.zero,
      color: cardBgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: cardBorderColor,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: _toggleExpanded,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with name and expand icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.shade700,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      typeIcon,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.enhancement.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Type and level tags
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.shade700,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      typeDisplay.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (level != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: getLevelColor(level),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'LEVEL $level',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              // Expandable content
              SizeTransition(
                sizeFactor: _expandAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.dark
                            ? primaryColor.shade800.withOpacity(0.2)
                            : primaryColor.shade50.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.brightness == Brightness.dark
                              ? primaryColor.shade600.withOpacity(0.5)
                              : primaryColor.shade300.withOpacity(0.8),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.auto_fix_high,
                                  size: 14,
                                  color: primaryColor.shade400,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'EFFECT',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: primaryColor.shade400,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              description,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.5,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
