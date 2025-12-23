part of 'class_features_widget.dart';

class _FeatureCard extends StatefulWidget {
  const _FeatureCard({super.key, required this.feature, required this.widget});

  final Feature feature;
  final ClassFeaturesWidget widget;

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard>
    with AutomaticKeepAliveClientMixin {
  bool _isExpanded = false;
  bool _initialized = false;

  @override
  bool get wantKeepAlive => true;

  Feature get feature => widget.feature;
  ClassFeaturesWidget get w => widget.widget;

  String get _storageKey => 'feature_card_expanded_${feature.id}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final bucket = PageStorage.of(context);
      final stored = bucket.readState(context, identifier: _storageKey);
      if (stored is bool) {
        _isExpanded = stored;
      }
    }
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      PageStorage.of(context).writeState(context, _isExpanded, identifier: _storageKey);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final details = w.featureDetailsById[feature.id];
    final grantType = _resolveGrantType();
    final featureStyle = _FeatureStyle.fromGrantType(grantType, feature.isSubclassFeature);
    
    // Check if this is a progression feature (Growing Ferocity / Discipline Mastery)
    if (w._isProgressionFeature(feature)) {
      return _buildProgressionFeatureCard(context, theme, scheme, featureStyle);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: scheme.surfaceContainerLow,
        border: Border.all(
          color: featureStyle.borderColor.withValues(alpha: _isExpanded ? 0.6 : 0.3),
          width: _isExpanded ? 2 : 1.5,
        ),
        boxShadow: _isExpanded
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header (always visible)
          _FeatureHeader(
            feature: feature,
            featureStyle: featureStyle,
            grantType: grantType,
            isExpanded: _isExpanded,
            onToggle: _toggleExpanded,
            widget: w,
          ),
          // Expandable content with animated size
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _isExpanded
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Divider(
                          height: 1,
                          color: featureStyle.borderColor.withValues(alpha: 0.2),
                        ),
                        _FeatureContent(
                          feature: feature,
                          details: details,
                          grantType: grantType,
                          widget: w,
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  String _resolveGrantType() {
    final featureKey = feature.name.toLowerCase().trim();
    return w.grantTypeByFeatureName[featureKey] ?? '';
  }
  
  /// Build a special card for progression features (Growing Ferocity / Discipline Mastery)
  Widget _buildProgressionFeatureCard(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme,
    _FeatureStyle featureStyle,
  ) {
    return _HeroicResourceProgressionFeature(
      feature: feature,
      featureStyle: featureStyle,
      isExpanded: _isExpanded,
      onToggle: () => setState(() => _isExpanded = !_isExpanded),
      widget: w,
    );
  }
}

class _FeatureStyle {
  final Color borderColor;
  final IconData icon;
  final String label;

  const _FeatureStyle({
    required this.borderColor,
    required this.icon,
    required this.label,
  });

  factory _FeatureStyle.fromGrantType(String grantType, bool isSubclass) {
    switch (grantType) {
      case 'granted':
        return _FeatureStyle(
          borderColor: Colors.green.shade600,
          icon: Icons.check_circle_outline,
          label: ClassFeatureCardText.grantedLabel,
        );
      case 'pick':
        return _FeatureStyle(
          borderColor: Colors.orange.shade600,
          icon: Icons.touch_app_outlined,
          label: ClassFeatureCardText.choiceRequiredLabel,
        );
      case 'ability':
        return _FeatureStyle(
          borderColor: Colors.blue.shade600,
          icon: Icons.auto_awesome_outlined,
          label: ClassFeatureCardText.abilityGrantedLabel,
        );
      default:
        if (isSubclass) {
          return _FeatureStyle(
            borderColor: Colors.purple.shade500,
            icon: Icons.star_outline_rounded,
            label: ClassFeatureCardText.subclassFeatureLabel,
          );
        }
        return _FeatureStyle(
          borderColor: Colors.blueGrey.shade400,
          icon: Icons.category_outlined,
          label: ClassFeatureCardText.classFeatureLabel,
        );
    }
  }
}
