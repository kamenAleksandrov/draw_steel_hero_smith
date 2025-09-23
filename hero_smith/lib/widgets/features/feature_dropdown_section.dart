import 'package:flutter/material.dart';
import '../../core/models/feature.dart';
import '../../core/theme/feature_tokens.dart';
import 'feature_card.dart';

class FeatureDropdownSection extends StatefulWidget {
  final String title;
  final List<Feature> features;
  final String className;
  final int level;

  const FeatureDropdownSection({
    super.key,
    required this.title,
    required this.features,
    required this.className,
    required this.level,
  });

  @override
  State<FeatureDropdownSection> createState() => _FeatureDropdownSectionState();
}

class _FeatureDropdownSectionState extends State<FeatureDropdownSection> 
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sectionColor = _getSectionColor(widget.title);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            sectionColor.withValues(alpha: 0.08),
            sectionColor.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: sectionColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: _toggleExpanded,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: sectionColor.withValues(alpha: 0.15),
                    ),
                    child: Icon(
                      _getSectionIcon(widget.title),
                      color: sectionColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: sectionColor,
                          ),
                        ),
                        Text(
                          '${widget.features.length} features',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: sectionColor.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: sectionColor,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expandable content
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: sectionColor.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: widget.features.map((feature) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FeatureCard(
                        feature: feature,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getSectionColor(String title) {
    switch (title.toLowerCase()) {
      case 'subclass features':
        return FeatureTokens.subclassFeature;
      case 'maneuvers':
        return FeatureTokens.getClassColor('tactician');
      case 'magical abilities':
        return FeatureTokens.getClassColor('elementalist');
      case 'passive features':
        return FeatureTokens.levelHigh;
      case 'core features':
      default:
        return FeatureTokens.coreFeature;
    }
  }

  IconData _getSectionIcon(String title) {
    switch (title.toLowerCase()) {
      case 'subclass features':
        return Icons.diamond;
      case 'maneuvers':
        return Icons.military_tech;
      case 'magical abilities':
        return Icons.auto_fix_high;
      case 'passive features':
        return Icons.shield;
      case 'core features':
      default:
        return Icons.star;
    }
  }
}