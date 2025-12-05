part of 'class_features_widget.dart';

class _FeatureCard extends StatefulWidget {
  const _FeatureCard({required this.feature, required this.widget});

  final Feature feature;
  final ClassFeaturesWidget widget;

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _isExpanded = false;

  Feature get feature => widget.feature;
  ClassFeaturesWidget get w => widget.widget;

  @override
  Widget build(BuildContext context) {
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
        children: [
          // Header (always visible)
          _FeatureHeader(
            feature: feature,
            featureStyle: featureStyle,
            grantType: grantType,
            isExpanded: _isExpanded,
            onToggle: () => setState(() => _isExpanded = !_isExpanded),
            widget: w,
          ),
          // Expandable content
          if (_isExpanded) ...[
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
          label: 'Granted Feature',
        );
      case 'pick':
        return _FeatureStyle(
          borderColor: Colors.orange.shade600,
          icon: Icons.touch_app_outlined,
          label: 'Choice Required',
        );
      case 'ability':
        return _FeatureStyle(
          borderColor: Colors.blue.shade600,
          icon: Icons.auto_awesome_outlined,
          label: 'Ability Granted',
        );
      default:
        if (isSubclass) {
          return _FeatureStyle(
            borderColor: Colors.purple.shade500,
            icon: Icons.star_outline_rounded,
            label: 'Subclass Feature',
          );
        }
        return _FeatureStyle(
          borderColor: Colors.blueGrey.shade400,
          icon: Icons.category_outlined,
          label: 'Class Feature',
        );
    }
  }
}
