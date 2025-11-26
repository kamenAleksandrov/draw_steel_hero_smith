import 'package:collection/collection.dart';

import 'hero_model.dart';
import '../repositories/hero_repository.dart' show CareerSelection, CultureSelection;

class StoryCreatorLoadResult {
  const StoryCreatorLoadResult({
    required this.hero,
    required this.cultureSelection,
    required this.careerSelection,
    required this.ancestryTraitIds,
    this.ancestryTraitChoices = const {},
    this.complicationId,
  });

  final HeroModel? hero;
  final CultureSelection cultureSelection;
  final CareerSelection careerSelection;
  final List<String> ancestryTraitIds;
  final Map<String, String> ancestryTraitChoices;
  final String? complicationId;

  StoryCreatorLoadResult copyWith({
    HeroModel? hero,
    CultureSelection? cultureSelection,
    CareerSelection? careerSelection,
    List<String>? ancestryTraitIds,
    Map<String, String>? ancestryTraitChoices,
    String? complicationId,
  }) {
    return StoryCreatorLoadResult(
      hero: hero ?? this.hero,
      cultureSelection: cultureSelection ?? this.cultureSelection,
      careerSelection: careerSelection ?? this.careerSelection,
      ancestryTraitIds: ancestryTraitIds ?? this.ancestryTraitIds,
      ancestryTraitChoices: ancestryTraitChoices ?? this.ancestryTraitChoices,
      complicationId: complicationId ?? this.complicationId,
    );
  }

  bool get hasHero => hero != null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StoryCreatorLoadResult &&
        other.hero == hero &&
        other.cultureSelection == cultureSelection &&
        other.careerSelection == careerSelection &&
        const ListEquality<String>().equals(other.ancestryTraitIds, ancestryTraitIds) &&
        const MapEquality<String, String>().equals(other.ancestryTraitChoices, ancestryTraitChoices) &&
        other.complicationId == complicationId;
  }

  @override
  int get hashCode => Object.hash(hero, cultureSelection, careerSelection,
      const ListEquality<String>().hash(ancestryTraitIds), 
      const MapEquality<String, String>().hash(ancestryTraitChoices),
      complicationId);
}

class StoryCultureSuggestion {
  const StoryCultureSuggestion({
    this.language,
    this.environment,
    this.organization,
    this.upbringing,
  });

  final String? language;
  final String? environment;
  final String? organization;
  final String? upbringing;

  bool get isEmpty =>
      language == null && environment == null && organization == null && upbringing == null;
}

class StoryCreatorSavePayload {
  const StoryCreatorSavePayload({
    required this.heroId,
    required this.name,
    this.ancestryId,
    this.ancestryTraitIds = const <String>{},
    this.ancestryTraitChoices = const <String, String>{},
    this.environmentId,
    this.organisationId,
    this.upbringingId,
    this.environmentSkillId,
    this.organisationSkillId,
    this.upbringingSkillId,
    this.languageIds = const <String>{},
    this.careerId,
    this.careerSkillIds = const <String>{},
    this.careerPerkIds = const <String>{},
    this.careerIncidentName,
    this.complicationId,
  });

  final String heroId;
  final String name;
  final String? ancestryId;
  final Set<String> ancestryTraitIds;
  /// Map of trait ID to chosen value (e.g., immunity type or ability name)
  final Map<String, String> ancestryTraitChoices;
  final String? environmentId;
  final String? organisationId;
  final String? upbringingId;
  final String? environmentSkillId;
  final String? organisationSkillId;
  final String? upbringingSkillId;
  final Set<String> languageIds;
  final String? careerId;
  final Set<String> careerSkillIds;
  final Set<String> careerPerkIds;
  final String? careerIncidentName;
  final String? complicationId;
}
