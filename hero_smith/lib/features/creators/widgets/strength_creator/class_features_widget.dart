import 'package:flutter/material.dart';

import 'package:hero_smith/core/models/feature.dart';
import 'package:hero_smith/core/models/component.dart';
import 'package:hero_smith/core/models/heroic_resource_progression.dart';
import 'package:hero_smith/core/models/skills_models.dart';
import 'package:hero_smith/core/models/subclass_models.dart';
import 'package:hero_smith/core/repositories/feature_repository.dart';
import 'package:hero_smith/core/services/class_feature_data_service.dart';
import 'package:hero_smith/core/services/heroic_resource_progression_service.dart';
import 'package:hero_smith/core/services/skill_data_service.dart';
import 'package:hero_smith/core/theme/creator_theme.dart';
import 'package:hero_smith/core/theme/feature_tokens.dart';
import 'package:hero_smith/core/text/creators/widgets/strength_creator/class_feature_card_text.dart';
import 'package:hero_smith/core/text/creators/widgets/strength_creator/class_features_level_section_text.dart';
import 'package:hero_smith/core/text/creators/widgets/strength_creator/feature_content_text.dart';
import 'package:hero_smith/core/text/creators/widgets/strength_creator/feature_header_text.dart';
import 'package:hero_smith/core/text/creators/widgets/strength_creator/heroic_resource_progression_feature_text.dart';
import 'package:hero_smith/core/text/creators/widgets/strength_creator/options_section_text.dart';
import 'package:hero_smith/core/utils/selection_guard.dart';
import 'package:hero_smith/widgets/abilities/ability_expandable_item.dart';
import 'package:hero_smith/widgets/heroic resource stacking tables/heroic_resource_stacking_tables.dart';

part 'class_features_level_section.dart';
part 'class_feature_card.dart';
part 'heroic_resource_progression_feature.dart';
part 'feature_header.dart';
part 'feature_content.dart';
part 'options_section.dart';

typedef FeatureSelectionChanged = void Function(
  String featureId,
  Set<String> selections,
);

/// Callback for skill_group skill selection changes.
/// [featureId] is the feature ID, [grantKey] uniquely identifies the grant
/// within the feature (e.g., domain name), and [skillId] is the selected skill.
typedef SkillGroupSelectionChanged = void Function(
  String featureId,
  String grantKey,
  String? skillId,
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
    this.skillGroupSelections = const {},
    this.onSkillGroupSelectionChanged,
    this.reservedSkillIds = const {},
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
  
  /// skill_group skill selections: Map<featureId, Map<grantKey, skillId>>
  final Map<String, Map<String, String>> skillGroupSelections;
  
  /// Callback when a skill_group skill selection changes
  final SkillGroupSelectionChanged? onSkillGroupSelectionChanged;
  
  /// Set of skill IDs that are already selected elsewhere (for duplicate prevention)
  final Set<String> reservedSkillIds;

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
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: levels.length,
        itemBuilder: (context, index) {
          final levelNumber = levels[index];
          if (grouped[levelNumber]?.isEmpty ?? true) return const SizedBox.shrink();
          return _LevelSection(
            key: PageStorageKey<String>('class_features_level_$levelNumber'),
            levelNumber: levelNumber,
            currentLevel: level,
            features: grouped[levelNumber]!,
            widget: this,
          );
        },
      ),
    );
  }
}
