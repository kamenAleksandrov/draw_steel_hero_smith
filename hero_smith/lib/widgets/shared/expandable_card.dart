import 'package:flutter/material.dart';
import '../../core/theme/ds_theme.dart';

class ExpandableCard extends StatefulWidget {
  final String title;
  final Widget? badge;
  final Widget expandedContent;
  final Color borderColor;
  final Widget? preview;

  const ExpandableCard({
    super.key,
    required this.title,
    this.badge,
    required this.expandedContent,
    required this.borderColor,
    this.preview,
  });

  @override
  State<ExpandableCard> createState() => _ExpandableCardState();
}

class _ExpandableCardState extends State<ExpandableCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
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
    final ds = DsTheme.of(context);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: widget.borderColor, width: 2),
      ),
      child: InkWell(
        onTap: _toggleExpanded,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Always visible header with title and badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: ds.cardTitleStyle,
                      maxLines: _isExpanded ? null : 2,
                      overflow: _isExpanded ? null : TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.badge != null) ...[
                    const SizedBox(width: 8),
                    widget.badge!,
                  ],
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      color: widget.borderColor.withOpacity(0.7),
                      size: 20,
                    ),
                  ),
                ],
              ),
              if (widget.preview != null) ...[
                const SizedBox(height: 8),
                widget.preview!,
              ],
              // Expandable content
              SizeTransition(
                sizeFactor: _expandAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    widget.expandedContent,
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