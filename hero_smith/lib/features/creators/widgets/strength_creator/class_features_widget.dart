import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:hero_smith/core/models/feature.dart';
import 'package:hero_smith/core/models/component.dart';
import 'package:hero_smith/core/models/heroic_resource_progression.dart';
import 'package:hero_smith/core/models/subclass_models.dart';
import 'package:hero_smith/core/repositories/feature_repository.dart';
import 'package:hero_smith/core/services/class_feature_data_service.dart';
import 'package:hero_smith/core/services/heroic_resource_progression_service.dart';
import 'package:hero_smith/core/theme/feature_tokens.dart';
import 'package:hero_smith/widgets/abilities/ability_expandable_item.dart';
import 'package:hero_smith/widgets/heroic resource stacking tables/heroic_resource_stacking_tables.dart';

typedef FeatureSelectionChanged = void Function(
  String featureId,
  Set<String> selections,
);

class ClassFeaturesWidget extends StatelessWidget {
  const ClassFeaturesWidget({
    super.key,
    required this.level,
    required this.features,
    required this.featureDetailsById,
    this.selectedOptions = const {},
    this.onSelectionChanged,
    this.domainLinkedFeatureIds = const {},
    this.deityLinkedFeatureIds = const {},
    this.selectedDomainSlugs = const {},
    this.selectedDeitySlugs = const {},
    this.abilityDetailsById = const {},
    this.abilityIdByName = const {},
    this.activeSubclassSlugs = const {},
    this.subclassLabel,
    this.subclassSelection,
    this.grantTypeByFeatureName = const {},
    this.className,
    this.equipmentIds = const [],
  });

  final int level;
  final List<Feature> features;
  final Map<String, Map<String, dynamic>> featureDetailsById;
  final Map<String, Set<String>> selectedOptions;
  final FeatureSelectionChanged? onSelectionChanged;
  final Set<String> domainLinkedFeatureIds;
  final Set<String> deityLinkedFeatureIds;
  final Set<String> selectedDomainSlugs;
  final Set<String> selectedDeitySlugs;
  final Map<String, Map<String, dynamic>> abilityDetailsById;
  final Map<String, String> abilityIdByName;
  final Set<String> activeSubclassSlugs;
  final String? subclassLabel;
  final SubclassSelectionResult? subclassSelection;
  final Map<String, String> grantTypeByFeatureName;
  
  /// Class name/id for determining heroic resource progression
  final String? className;
  
  /// Equipment IDs for determining kit (used for Stormwight progression)
  final List<String?> equipmentIds;

  static const List<String> _widgetSubclassOptionKeys = [
    'subclass', 'subclass_name', 'tradition', 'order', 'doctrine',
    'mask', 'path', 'circle', 'college', 'element', 'role',
    'discipline', 'oath', 'school', 'guild', 'domain', 'name',
  ];

  static const List<String> _widgetDeityOptionKeys = [
    'deity', 'deity_name', 'patron', 'pantheon', 'god',
  ];
  
  /// Feature IDs that should be rendered as heroic resource progression widgets
  static const Set<String> _progressionFeatureIds = {
    'feature_fury_growing_ferocity',
    'feature_null_discipline_mastery',
  };
  
  /// Check if a feature should be rendered as a progression widget
  bool _isProgressionFeature(Feature feature) {
    return _progressionFeatureIds.contains(feature.id);
  }

  @override
  Widget build(BuildContext context) {
    if (features.isEmpty) return const SizedBox.shrink();

    final grouped = FeatureRepository.groupFeaturesByLevel(features);
    final levels = FeatureRepository.getSortedLevels(grouped);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final levelNumber in levels)
            if (grouped[levelNumber]?.isNotEmpty ?? false)
              _LevelSection(
                levelNumber: levelNumber,
                currentLevel: level,
                features: grouped[levelNumber]!,
                widget: this,
              ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// LEVEL SECTION
// ══════════════════════════════════════════════════════════════════════════════

class _LevelSection extends StatelessWidget {
  const _LevelSection({
    required this.levelNumber,
    required this.currentLevel,
    required this.features,
    required this.widget,
  });

  final int levelNumber;
  final int currentLevel;
  final List<Feature> features;
  final ClassFeaturesWidget widget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final levelColor = FeatureTokens.getLevelColor(levelNumber);
    final isUnlocked = levelNumber <= currentLevel;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked
              ? levelColor.withValues(alpha: 0.4)
              : scheme.outlineVariant.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: PageStorageKey<String>('level_$levelNumber'),
            initiallyExpanded: isUnlocked,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            backgroundColor: scheme.surface,
            collapsedBackgroundColor: scheme.surface,
            leading: _LevelBadge(level: levelNumber, isUnlocked: isUnlocked),
            title: Text(
              'Level $levelNumber Features',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isUnlocked
                    ? scheme.onSurface
                    : scheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            subtitle: Text(
              '${features.length} feature${features.length == 1 ? '' : 's'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            children: [
              Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    for (var i = 0; i < features.length; i++) ...[
                      _FeatureCard(feature: features[i], widget: widget),
                      if (i < features.length - 1) const SizedBox(height: 12),
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

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level, required this.isUnlocked});

  final int level;
  final bool isUnlocked;

  @override
  Widget build(BuildContext context) {
    final levelColor = FeatureTokens.getLevelColor(level);
    final effectiveColor = isUnlocked ? levelColor : Colors.grey;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            effectiveColor.withValues(alpha: 0.3),
            effectiveColor.withValues(alpha: 0.15),
          ],
        ),
        border: Border.all(
          color: effectiveColor.withValues(alpha: 0.6),
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          '$level',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: effectiveColor,
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FEATURE CARD
// ══════════════════════════════════════════════════════════════════════════════

class _FeatureCard extends StatefulWidget {
  const _FeatureCard({required this.feature, required this.widget});

  final Feature feature;
  final ClassFeaturesWidget widget;

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _isExpanded = true;

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
                    'Granted Feature',
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
          if (description != null && description.isNotEmpty) ...[
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
            'Select a Stormwight Kit',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose a Stormwight kit in the Strife tab to view your Growing Ferocity progression.',
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
              'Select a subclass in the Strife tab to view progression benefits.',
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

// ══════════════════════════════════════════════════════════════════════════════
// FEATURE HEADER
// ══════════════════════════════════════════════════════════════════════════════

class _FeatureHeader extends StatelessWidget {
  const _FeatureHeader({
    required this.feature,
    required this.featureStyle,
    required this.grantType,
    required this.isExpanded,
    required this.onToggle,
    required this.widget,
  });

  final Feature feature;
  final _FeatureStyle featureStyle;
  final String grantType;
  final bool isExpanded;
  final VoidCallback onToggle;
  final ClassFeaturesWidget widget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDomainLinked = widget.domainLinkedFeatureIds.contains(feature.id);
    final isDeityLinked = widget.deityLinkedFeatureIds.contains(feature.id);

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.vertical(
        top: const Radius.circular(14),
        bottom: isExpanded ? Radius.zero : const Radius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                // Grant type icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: featureStyle.borderColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    featureStyle.icon,
                    size: 20,
                    color: featureStyle.borderColor,
                  ),
                ),
                const SizedBox(width: 12),
                // Name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feature.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        featureStyle.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: featureStyle.borderColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Expand icon
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            // Tags row
            if (feature.isSubclassFeature || isDomainLinked || isDeityLinked) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (feature.isSubclassFeature)
                    _SmallTag(
                      icon: Icons.star_rounded,
                      label: widget.subclassLabel?.isNotEmpty == true
                          ? widget.subclassLabel!
                          : 'Subclass',
                      color: Colors.purple,
                    ),
                  if (isDomainLinked)
                    _SmallTag(
                      icon: Icons.account_tree_rounded,
                      label: 'Domain',
                      color: Colors.teal,
                    ),
                  if (isDeityLinked)
                    _SmallTag(
                      icon: Icons.auto_awesome,
                      label: 'Deity',
                      color: Colors.amber.shade700,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SmallTag extends StatelessWidget {
  const _SmallTag({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FEATURE CONTENT
// ══════════════════════════════════════════════════════════════════════════════

class _FeatureContent extends StatelessWidget {
  const _FeatureContent({
    required this.feature,
    required this.details,
    required this.grantType,
    required this.widget,
  });

  final Feature feature;
  final Map<String, dynamic>? details;
  final String grantType;
  final ClassFeaturesWidget widget;

  @override
  Widget build(BuildContext context) {
    final description = _coalesceDescription();
    final allOptions = _extractOptions();
    final originalSelections = widget.selectedOptions[feature.id] ?? const <String>{};

    final optionsContext = _prepareFeatureOptions(allOptions, originalSelections);
    final isAbilityFeature = grantType == 'ability';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description
          if (description?.isNotEmpty ?? false)
            _DescriptionSection(description: description!),

          // Ability card for ability features
          if (isAbilityFeature) ...[
            const SizedBox(height: 16),
            _buildAbilitySection(context),
          ],

          // Detail sections
          ..._buildDetailSections(context),

          // Options section
          if (allOptions.isNotEmpty || optionsContext.messages.isNotEmpty) ...[
            const SizedBox(height: 16),
            _OptionsSection(
              feature: feature,
              details: details,
              optionsContext: optionsContext,
              originalSelections: originalSelections,
              widget: widget,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAbilitySection(BuildContext context) {
    final ability = _resolveAbilityForFeature();
    if (ability == null) return const SizedBox.shrink();

    final component = _abilityMapToComponent(ability);
    return AbilityExpandableItem(component: component);
  }

  Map<String, dynamic>? _resolveAbilityForFeature() {
    if (details != null) {
      final abilityRef = details!['ability'];
      if (abilityRef is String && abilityRef.trim().isNotEmpty) {
        final ability = _resolveAbilityByName(abilityRef);
        if (ability != null) return ability;
      }
      final abilityId = details!['ability_id'];
      if (abilityId is String && abilityId.trim().isNotEmpty) {
        final ability = widget.abilityDetailsById[abilityId];
        if (ability != null) return ability;
      }
    }
    return _resolveAbilityByName(feature.name);
  }

  Map<String, dynamic>? _resolveAbilityByName(String name) {
    final slug = ClassFeatureDataService.slugify(name);
    final resolvedId = widget.abilityIdByName[slug] ?? slug;
    return widget.abilityDetailsById[resolvedId];
  }

  Component _abilityMapToComponent(Map<String, dynamic> abilityData) {
    final id = abilityData['id']?.toString() ??
        abilityData['resolved_id']?.toString() ??
        '';
    final name = abilityData['name']?.toString() ?? '';
    final type = abilityData['type']?.toString() ?? 'ability';

    return Component(
      id: id,
      type: type,
      name: name,
      data: abilityData,
      source: 'seed',
    );
  }

  String? _coalesceDescription() {
    final detailDescription = details?['description'];
    final fromDetails = _normalizeText(detailDescription);
    if (fromDetails?.isNotEmpty ?? false) return fromDetails;
    return _normalizeText(feature.description);
  }

  String? _normalizeText(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is List) {
      final parts = value
          .whereType<String>()
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();
      return parts.isEmpty ? null : parts.join('\n\n');
    }
    return value.toString();
  }

  List<Map<String, dynamic>> _extractOptions() {
    final raw = details?['options'];
    if (raw is! List) return const [];
    final options = <Map<String, dynamic>>[];
    for (final entry in raw) {
      if (entry is Map<String, dynamic>) {
        options.add(entry);
      } else if (entry is Map) {
        options.add(entry.cast<String, dynamic>());
      }
    }
    return options;
  }

  _FeatureOptionsContext _prepareFeatureOptions(
    List<Map<String, dynamic>> allOptions,
    Set<String> currentSelections,
  ) {
    var filteredOptions = List<Map<String, dynamic>>.from(allOptions);
    var allowEditing = true;
    final messages = <String>[];
    var requiresExternalSelection = false;

    void applyFilter(_OptionFilterResult result) {
      filteredOptions = result.options;
      allowEditing = allowEditing && result.allowEditing;
      messages.addAll(result.messages);
      requiresExternalSelection =
          requiresExternalSelection || result.requiresExternalSelection;
    }

    if (widget.domainLinkedFeatureIds.contains(feature.id)) {
      final result = _applyDomainFilter(filteredOptions);
      applyFilter(result);
      if (filteredOptions.isEmpty && result.requiresExternalSelection) {
        return _FeatureOptionsContext(
          options: filteredOptions,
          selectedKeys: const <String>{},
          allowEditing: false,
          messages: messages,
          requiresExternalSelection: true,
        );
      }
    }

    if (widget.deityLinkedFeatureIds.contains(feature.id)) {
      final result = _applyDeityFilter(filteredOptions);
      applyFilter(result);
      if (filteredOptions.isEmpty && result.requiresExternalSelection) {
        return _FeatureOptionsContext(
          options: filteredOptions,
          selectedKeys: const <String>{},
          allowEditing: false,
          messages: messages,
          requiresExternalSelection: true,
        );
      }
    }

    if (feature.isSubclassFeature) {
      final result = _applySubclassFilter(filteredOptions);
      applyFilter(result);
    }

    final filteredKeys = filteredOptions
        .map((o) => ClassFeatureDataService.featureOptionKey(o))
        .toSet();

    final selectedKeys = currentSelections.where(filteredKeys.contains).toSet();

    return _FeatureOptionsContext(
      options: filteredOptions,
      selectedKeys: selectedKeys,
      allowEditing: allowEditing,
      messages: messages,
      requiresExternalSelection: requiresExternalSelection,
    );
  }

  _OptionFilterResult _applyDomainFilter(List<Map<String, dynamic>> currentOptions) {
    if (widget.selectedDomainSlugs.isEmpty) {
      return const _OptionFilterResult(
        options: [],
        allowEditing: false,
        messages: ['Choose domains above to unlock this feature.'],
        requiresExternalSelection: true,
      );
    }

    final allowedKeys = ClassFeatureDataService.domainOptionKeysFor(
      widget.featureDetailsById,
      feature.id,
      widget.selectedDomainSlugs,
    );

    if (allowedKeys.isEmpty) {
      return const _OptionFilterResult(
        options: [],
        allowEditing: false,
        messages: ['No options match your selected domains.'],
      );
    }

    final filtered = currentOptions
        .where((o) => allowedKeys.contains(ClassFeatureDataService.featureOptionKey(o)))
        .toList();

    if (filtered.isEmpty) {
      return const _OptionFilterResult(
        options: [],
        allowEditing: false,
        messages: ['No options match your selected domains.'],
      );
    }

    final allowEditing = widget.selectedDomainSlugs.length > 1 && filtered.length > 1;
    return _OptionFilterResult(
      options: filtered,
      allowEditing: allowEditing,
      messages: allowEditing
          ? ['Pick the option that fits your chosen domains.']
          : ['Automatically applied for your domain.'],
    );
  }

  _OptionFilterResult _applyDeityFilter(List<Map<String, dynamic>> currentOptions) {
    if (widget.selectedDeitySlugs.isEmpty) {
      return const _OptionFilterResult(
        options: [],
        allowEditing: false,
        messages: ['Choose a deity above to unlock this feature.'],
        requiresExternalSelection: true,
      );
    }

    final filtered = <Map<String, dynamic>>[];
    var hasTaggedOption = false;
    for (final option in currentOptions) {
      final slugs = _optionDeitySlugs(option);
      if (slugs.isEmpty) continue;
      hasTaggedOption = true;
      if (slugs.intersection(widget.selectedDeitySlugs).isNotEmpty) {
        filtered.add(option);
      }
    }

    if (!hasTaggedOption) {
      return _OptionFilterResult(options: currentOptions, allowEditing: true);
    }

    if (filtered.isEmpty) {
      return const _OptionFilterResult(
        options: [],
        allowEditing: false,
        messages: ['No options match your chosen deity.'],
      );
    }

    final allowEditing = filtered.length > 1;
    final deityName = widget.subclassSelection?.deityName?.trim();
    final message = allowEditing
        ? 'Pick the option that matches your deity.'
        : (deityName?.isEmpty ?? true
            ? 'Automatically applied for your deity.'
            : 'Automatically applied for $deityName.');

    return _OptionFilterResult(
      options: filtered,
      allowEditing: allowEditing,
      messages: [message],
    );
  }

  _OptionFilterResult _applySubclassFilter(List<Map<String, dynamic>> currentOptions) {
    if (widget.activeSubclassSlugs.isEmpty) {
      return const _OptionFilterResult(
        options: [],
        allowEditing: false,
        messages: ['Choose a subclass above to unlock this feature.'],
        requiresExternalSelection: true,
      );
    }

    final filtered = <Map<String, dynamic>>[];
    var hasTaggedOption = false;
    for (final option in currentOptions) {
      final slugs = _optionSubclassSlugs(option);
      if (slugs.isEmpty) continue;
      hasTaggedOption = true;
      if (slugs.intersection(widget.activeSubclassSlugs).isNotEmpty) {
        filtered.add(option);
      }
    }

    if (!hasTaggedOption) {
      return _OptionFilterResult(options: currentOptions, allowEditing: true);
    }

    if (filtered.isEmpty) {
      return const _OptionFilterResult(
        options: [],
        allowEditing: false,
        messages: ['No options match your selected subclass.'],
      );
    }

    final allowEditing = filtered.length > 1;
    final subclassName = widget.subclassSelection?.subclassName?.trim();
    final message = allowEditing
        ? 'Pick the option that fits your subclass.'
        : (subclassName?.isEmpty ?? true
            ? 'Automatically applied for your subclass.'
            : 'Automatically applied for $subclassName.');

    return _OptionFilterResult(
      options: filtered,
      allowEditing: allowEditing,
      messages: [message],
    );
  }

  Set<String> _optionSubclassSlugs(Map<String, dynamic> option) {
    return _extractOptionSlugs(option, ClassFeaturesWidget._widgetSubclassOptionKeys);
  }

  Set<String> _optionDeitySlugs(Map<String, dynamic> option) {
    return _extractOptionSlugs(option, ClassFeaturesWidget._widgetDeityOptionKeys);
  }

  Set<String> _extractOptionSlugs(Map<String, dynamic> option, List<String> keys) {
    final slugs = <String>{};
    for (final key in keys) {
      final value = option[key];
      if (value == null) continue;
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) continue;
        slugs.addAll(ClassFeatureDataService.slugVariants(trimmed));
      } else if (value is List) {
        for (final entry in value.whereType<String>()) {
          final trimmed = entry.trim();
          if (trimmed.isEmpty) continue;
          slugs.addAll(ClassFeatureDataService.slugVariants(trimmed));
        }
      }
    }
    return slugs;
  }

  List<Widget> _buildDetailSections(BuildContext context) {
    if (details == null || details!.isEmpty) return const [];

    final sections = <Widget>[];
    void addSection(String title, IconData icon, dynamic value) {
      if (value == null) return;
      String? content;
      if (value is String) {
        content = value.trim();
      } else if (value is Map<String, dynamic>) {
        final name = value['name']?.toString().trim();
        final description = value['description']?.toString().trim();
        final pieces = <String>[];
        if (name?.isNotEmpty ?? false) pieces.add(name!);
        if (description?.isNotEmpty ?? false) pieces.add(description!);
        content = pieces.join('\n\n');
      }
      if (content?.isEmpty ?? true) return;
      sections.add(const SizedBox(height: 12));
      sections.add(_DetailBlock(title: title, icon: icon, content: content!));
    }

    addSection('In Combat', Icons.sports_kabaddi, details!['in_combat']);
    addSection('Out of Combat', Icons.explore, details!['out_of_combat']);
    addSection('Special', Icons.auto_awesome, details!['special']);
    addSection('Notes', Icons.sticky_note_2, details!['notes']);

    return sections;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DESCRIPTION SECTION
// ══════════════════════════════════════════════════════════════════════════════

class _DescriptionSection extends StatelessWidget {
  const _DescriptionSection({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Text(
      description,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
        height: 1.5,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DETAIL BLOCK
// ══════════════════════════════════════════════════════════════════════════════

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({
    required this.title,
    required this.icon,
    required this.content,
  });

  final String title;
  final IconData icon;
  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// OPTIONS SECTION
// ══════════════════════════════════════════════════════════════════════════════

class _OptionsSection extends StatelessWidget {
  const _OptionsSection({
    required this.feature,
    required this.details,
    required this.optionsContext,
    required this.originalSelections,
    required this.widget,
  });

  final Feature feature;
  final Map<String, dynamic>? details;
  final _FeatureOptionsContext optionsContext;
  final Set<String> originalSelections;
  final ClassFeaturesWidget widget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final allowMultiple = _inferAllowMultiple();
    final effectiveSelections = optionsContext.selectedKeys;
    final canEdit = widget.onSelectionChanged != null && optionsContext.allowEditing;
    final isAutoApplied = _isAutoAppliedSelection();

    final grantType = widget.grantTypeByFeatureName[feature.name.toLowerCase().trim()] ?? '';
    final isPickFeature = grantType == 'pick';
    final hasOptions = optionsContext.options.isNotEmpty;
    final needsSelection = isPickFeature && hasOptions && effectiveSelections.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selection prompt for pick features
        if (needsSelection && !isAutoApplied)
          _SelectionPrompt(allowMultiple: allowMultiple),

        // Info messages
        for (final message in optionsContext.messages)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _InfoMessage(message: message),
          ),

        // Options
        if (isAutoApplied && optionsContext.options.isNotEmpty)
          _AutoAppliedContent(option: optionsContext.options.first, widget: widget)
        else if (optionsContext.options.isNotEmpty) ...[
          Text(
            allowMultiple ? 'Select Options' : 'Choose One',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          ...optionsContext.options.map((option) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _OptionTile(
                  option: option,
                  feature: feature,
                  isSelected: effectiveSelections
                      .contains(ClassFeatureDataService.featureOptionKey(option)),
                  isRecommended: _optionMatchesActiveSubclass(option),
                  allowMultiple: allowMultiple,
                  canEdit: canEdit,
                  needsSelection: needsSelection,
                  onChanged: (selected) => _handleOptionChanged(option, selected),
                  widget: widget,
                ),
              )),
        ],
      ],
    );
  }

  bool _inferAllowMultiple() {
    if (widget.domainLinkedFeatureIds.contains(feature.id)) return true;
    if (originalSelections.length > 1) return true;
    final allowMultiple = details?['allow_multiple'];
    if (allowMultiple is bool) return allowMultiple;
    final maxSel = details?['max_selections'] ?? details?['select_count'];
    if (maxSel is num) return maxSel > 1;
    return false;
  }

  bool _isAutoAppliedSelection() {
    if (optionsContext.allowEditing) return false;
    if (optionsContext.requiresExternalSelection) return false;
    if (optionsContext.options.length != 1) return false;
    return true;
  }

  bool _optionMatchesActiveSubclass(Map<String, dynamic> option) {
    if (widget.activeSubclassSlugs.isEmpty) return false;
    for (final key in ClassFeaturesWidget._widgetSubclassOptionKeys) {
      final value = option[key]?.toString().trim();
      if (value == null || value.isEmpty) continue;
      final variants = ClassFeatureDataService.slugVariants(value);
      if (variants.intersection(widget.activeSubclassSlugs).isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  void _handleOptionChanged(Map<String, dynamic> option, bool selected) {
    if (widget.onSelectionChanged == null) return;
    final key = ClassFeatureDataService.featureOptionKey(option);
    final updated = Set<String>.from(optionsContext.selectedKeys);

    if (_inferAllowMultiple()) {
      if (selected) {
        updated.add(key);
      } else {
        updated.remove(key);
      }
    } else {
      updated.clear();
      if (selected) updated.add(key);
    }

    widget.onSelectionChanged!(feature.id, updated);
  }
}

class _SelectionPrompt extends StatelessWidget {
  const _SelectionPrompt({required this.allowMultiple});

  final bool allowMultiple;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.touch_app_rounded, color: Colors.orange, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selection Required',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  allowMultiple
                      ? 'Choose one or more options below'
                      : 'Choose one option below',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoMessage extends StatelessWidget {
  const _InfoMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AutoAppliedContent extends StatelessWidget {
  const _AutoAppliedContent({required this.option, required this.widget});

  final Map<String, dynamic> option;
  final ClassFeaturesWidget widget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final description = option['description']?.toString().trim();
    final ability = _resolveAbility();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, size: 18, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                'Automatically Applied',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          if (description?.isNotEmpty ?? false) ...[
            const SizedBox(height: 10),
            Text(
              description!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (ability != null) ...[
            const SizedBox(height: 12),
            AbilityExpandableItem(
              component: _abilityMapToComponent(ability),
            ),
          ],
        ],
      ),
    );
  }

  Map<String, dynamic>? _resolveAbility() {
    String? id = option['ability_id']?.toString().trim();
    if (id != null && id.isNotEmpty) {
      final ability = widget.abilityDetailsById[id];
      if (ability != null) return ability;
      final slugId = ClassFeatureDataService.slugify(id);
      final slugAbility = widget.abilityDetailsById[slugId];
      if (slugAbility != null) return slugAbility;
    }

    final abilityName = option['ability']?.toString().trim();
    if (abilityName != null && abilityName.isNotEmpty) {
      final slug = ClassFeatureDataService.slugify(abilityName);
      final resolvedId = widget.abilityIdByName[slug] ?? slug;
      return widget.abilityDetailsById[resolvedId];
    }
    return null;
  }

  Component _abilityMapToComponent(Map<String, dynamic> abilityData) {
    return Component(
      id: abilityData['id']?.toString() ?? abilityData['resolved_id']?.toString() ?? '',
      type: abilityData['type']?.toString() ?? 'ability',
      name: abilityData['name']?.toString() ?? '',
      data: abilityData,
      source: 'seed',
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// OPTION TILE
// ══════════════════════════════════════════════════════════════════════════════

class _OptionTile extends StatefulWidget {
  const _OptionTile({
    required this.option,
    required this.feature,
    required this.isSelected,
    required this.isRecommended,
    required this.allowMultiple,
    required this.canEdit,
    required this.needsSelection,
    required this.onChanged,
    required this.widget,
  });

  final Map<String, dynamic> option;
  final Feature feature;
  final bool isSelected;
  final bool isRecommended;
  final bool allowMultiple;
  final bool canEdit;
  final bool needsSelection;
  final ValueChanged<bool> onChanged;
  final ClassFeaturesWidget widget;

  @override
  State<_OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<_OptionTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = ClassFeatureDataService.featureOptionLabel(widget.option);
    final description = widget.option['description']?.toString().trim();
    final ability = _resolveAbility();
    final hasDetails = (description?.isNotEmpty ?? false) || ability != null;

    Color borderColor;
    Color bgColor;
    if (widget.isSelected) {
      borderColor = scheme.primary;
      bgColor = scheme.primary.withValues(alpha: 0.08);
    } else if (widget.needsSelection) {
      borderColor = Colors.orange.withValues(alpha: 0.5);
      bgColor = Colors.orange.withValues(alpha: 0.04);
    } else if (widget.isRecommended) {
      borderColor = scheme.secondary.withValues(alpha: 0.5);
      bgColor = scheme.secondary.withValues(alpha: 0.05);
    } else {
      borderColor = scheme.outlineVariant.withValues(alpha: 0.5);
      bgColor = scheme.surfaceContainerLow;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: bgColor,
        border: Border.all(
          color: borderColor,
          width: widget.isSelected ? 2 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Main tile
          InkWell(
            onTap: widget.canEdit ? () => widget.onChanged(!widget.isSelected) : null,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(12),
              bottom: _isExpanded ? Radius.zero : const Radius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Selection indicator
                  if (widget.allowMultiple)
                    _buildCheckbox(context)
                  else
                    _buildRadio(context),
                  const SizedBox(width: 14),
                  // Label
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: widget.isSelected
                                ? scheme.primary
                                : scheme.onSurface,
                          ),
                        ),
                        if (widget.isRecommended && !widget.isSelected)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Matches your subclass',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.secondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Expand button
                  if (hasDetails)
                    IconButton(
                      icon: AnimatedRotation(
                        turns: _isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      onPressed: () => setState(() => _isExpanded = !_isExpanded),
                      visualDensity: VisualDensity.compact,
                      tooltip: _isExpanded ? 'Collapse' : 'Expand',
                    ),
                ],
              ),
            ),
          ),
          // Expanded details
          if (_isExpanded && hasDetails) ...[
            Divider(height: 1, color: borderColor.withValues(alpha: 0.3)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (description?.isNotEmpty ?? false) ...[
                    Text(
                      description!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    if (ability != null) const SizedBox(height: 12),
                  ],
                  if (ability != null)
                    AbilityExpandableItem(
                      component: _abilityMapToComponent(ability),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCheckbox(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: widget.isSelected
            ? scheme.primary
            : Colors.transparent,
        border: Border.all(
          color: widget.isSelected
              ? scheme.primary
              : scheme.outline.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: widget.isSelected
          ? const Icon(Icons.check, size: 18, color: Colors.white)
          : null,
    );
  }

  Widget _buildRadio(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.transparent,
        border: Border.all(
          color: widget.isSelected
              ? scheme.primary
              : scheme.outline.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: widget.isSelected
          ? Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary,
                ),
              ),
            )
          : null,
    );
  }

  Map<String, dynamic>? _resolveAbility() {
    String? id = widget.option['ability_id']?.toString().trim();
    if (id != null && id.isNotEmpty) {
      final ability = widget.widget.abilityDetailsById[id];
      if (ability != null) return ability;
      final slugId = ClassFeatureDataService.slugify(id);
      final slugAbility = widget.widget.abilityDetailsById[slugId];
      if (slugAbility != null) return slugAbility;
    }

    final abilityName = widget.option['ability']?.toString().trim();
    if (abilityName != null && abilityName.isNotEmpty) {
      final slug = ClassFeatureDataService.slugify(abilityName);
      final resolvedId = widget.widget.abilityIdByName[slug] ?? slug;
      return widget.widget.abilityDetailsById[resolvedId];
    }
    return null;
  }

  Component _abilityMapToComponent(Map<String, dynamic> abilityData) {
    return Component(
      id: abilityData['id']?.toString() ?? abilityData['resolved_id']?.toString() ?? '',
      type: abilityData['type']?.toString() ?? 'ability',
      name: abilityData['name']?.toString() ?? '',
      data: abilityData,
      source: 'seed',
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HELPER CLASSES
// ══════════════════════════════════════════════════════════════════════════════

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

class _FeatureOptionsContext {
  const _FeatureOptionsContext({
    required this.options,
    required this.selectedKeys,
    required this.allowEditing,
    required this.messages,
    required this.requiresExternalSelection,
  });

  final List<Map<String, dynamic>> options;
  final Set<String> selectedKeys;
  final bool allowEditing;
  final List<String> messages;
  final bool requiresExternalSelection;
}

class _OptionFilterResult {
  const _OptionFilterResult({
    required this.options,
    required this.allowEditing,
    this.messages = const [],
    this.requiresExternalSelection = false,
  });

  final List<Map<String, dynamic>> options;
  final bool allowEditing;
  final List<String> messages;
  final bool requiresExternalSelection;
}
