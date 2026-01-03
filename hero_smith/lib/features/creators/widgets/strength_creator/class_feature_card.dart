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
    
    // Check if this feature has options that require a user choice
    final hasOptionsRequiringChoice = _hasOptionsRequiringChoice(details);
    final featureStyle = _FeatureStyle.fromGrantType(
      grantType,
      feature.isSubclassFeature,
      hasOptionsRequiringChoice: hasOptionsRequiringChoice,
    );
    
    // Check if this is a progression feature (Growing Ferocity / Discipline Mastery)
    if (w._isProgressionFeature(feature)) {
      return _buildProgressionFeatureCard(context, theme, scheme, featureStyle);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF252525),
        border: Border.all(
          color: featureStyle.borderColor.withValues(alpha: _isExpanded ? 0.7 : 0.4),
          width: _isExpanded ? 2 : 1.5,
        ),
        boxShadow: _isExpanded
            ? [
                BoxShadow(
                  color: featureStyle.borderColor.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
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
                          color: featureStyle.borderColor.withValues(alpha: 0.3),
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
  
  /// Determines if this feature has options that require a user choice.
  /// Returns true if:
  /// - Feature has 'options' or 'options_X' with multiple entries
  /// - Feature doesn't use 'grants' (which are auto-applied)
  /// - No selection has been made yet
  bool _hasOptionsRequiringChoice(Map<String, dynamic>? details) {
    if (details == null) return false;
    
    // Check if it uses grants (auto-applied, no choice needed)
    final grants = details['grants'];
    if (grants is List && grants.isNotEmpty) return false;
    
    // Extract options using the service
    final options = ClassFeatureDataService.extractOptionMaps(details);
    if (options.isEmpty) return false;
    
    // If there's only one option, it's auto-applied (no choice needed)
    if (options.length <= 1) return false;
    
    // Check if user already made a selection
    final currentSelections = w.selectedOptions[feature.id] ?? const <String>{};
    final minimumRequired = ClassFeatureDataService.minimumSelections(details);
    final effectiveMinimum = minimumRequired <= 0 ? 1 : minimumRequired;
    
    return currentSelections.length < effectiveMinimum;
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

  factory _FeatureStyle.fromGrantType(
    String grantType,
    bool isSubclass, {
    bool hasOptionsRequiringChoice = false,
  }) {
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
        // If no explicit grantType but feature has options requiring choice
        if (hasOptionsRequiringChoice) {
          return _FeatureStyle(
            borderColor: Colors.orange.shade600,
            icon: Icons.touch_app_outlined,
            label: ClassFeatureCardText.choiceRequiredLabel,
          );
        }
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
