part of 'class_features_widget.dart';

/// Special widget to render progression features with the HeroicResourceGauge
class _HeroicResourceProgressionFeature extends StatefulWidget {
  const _HeroicResourceProgressionFeature({
    required this.feature,
    required this.featureStyle,
    required this.isExpanded,
    required this.onToggle,
    required this.widget,
  });

  final Feature feature;
  final _FeatureStyle featureStyle;
  final bool isExpanded;
  final VoidCallback onToggle;
  final ClassFeaturesWidget widget;

  @override
  State<_HeroicResourceProgressionFeature> createState() =>
      _HeroicResourceProgressionFeatureState();
}

class _HeroicResourceProgressionFeatureState
    extends State<_HeroicResourceProgressionFeature> {
  final HeroicResourceProgressionService _service =
      HeroicResourceProgressionService();
  HeroicResourceProgression? _progression;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProgression();
  }

  @override
  void didUpdateWidget(covariant _HeroicResourceProgressionFeature oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload if subclass or equipment changed
    if (oldWidget.widget.subclassSelection != widget.widget.subclassSelection ||
        oldWidget.widget.equipmentIds != widget.widget.equipmentIds) {
      _loadProgression();
    }
  }

  Future<void> _loadProgression() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final subclassName = widget.widget.subclassSelection?.subclassName;
      final className = widget.widget.className;
      
      // Find stormwight kit from equipment IDs
      String? kitId;
      for (final id in widget.widget.equipmentIds) {
        if (id != null) {
          final normalizedId = id.toLowerCase();
          if (normalizedId.contains('boren') ||
              normalizedId.contains('corven') ||
              normalizedId.contains('raden') ||
              normalizedId.contains('vulken') ||
              normalizedId.contains('vuken')) {
            kitId = id;
            break;
          }
        }
      }

      final progression = await _service.getProgression(
        className: className,
        subclassName: subclassName,
        kitId: kitId,
      );

      if (mounted) {
        setState(() {
          _progression = progression;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _progression = null;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final featureStyle = widget.featureStyle;
    final isStormwight = _service.isStormwightSubclass(
      widget.widget.subclassSelection?.subclassName,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: scheme.surfaceContainerLow,
        border: Border.all(
          color: featureStyle.borderColor.withValues(alpha: widget.isExpanded ? 0.6 : 0.3),
          width: widget.isExpanded ? 2 : 1.5,
        ),
        boxShadow: widget.isExpanded
            ? [
                BoxShadow(
                  color: featureStyle.borderColor.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          _buildHeader(context, theme, scheme, featureStyle),
          // Expandable content
          if (widget.isExpanded) ...[
            Divider(
              height: 1,
              color: featureStyle.borderColor.withValues(alpha: 0.2),
            ),
            _buildContent(context, theme, isStormwight),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme,
    _FeatureStyle featureStyle,
  ) {
    return InkWell(
      onTap: widget.onToggle,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: featureStyle.borderColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                featureStyle.icon,
                size: 16,
                color: featureStyle.borderColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.feature.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    HeroicResourceProgressionFeatureText.grantedFeatureLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: featureStyle.borderColor,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedRotation(
              turns: widget.isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme, bool isStormwight) {
    final description = widget.feature.description;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (description.isNotEmpty) ...[
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_progression != null)
            HeroicResourceGauge(
              progression: _progression!,
              currentResource: 0, // Show empty gauge in creator
              heroLevel: widget.widget.level,
              showCompact: false,
            )
          else if (isStormwight)
            _buildStormwightNotice(context, theme)
          else
            _buildNoProgressionNotice(context, theme),
        ],
      ),
    );
  }

  Widget _buildStormwightNotice(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.pets_rounded,
            size: 32,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            HeroicResourceProgressionFeatureText.stormwightTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            HeroicResourceProgressionFeatureText.stormwightSubtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoProgressionNotice(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              HeroicResourceProgressionFeatureText.noProgressionMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
