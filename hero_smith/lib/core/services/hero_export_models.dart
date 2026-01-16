/// Preview information for a hero import.
class HeroImportPreview {
  const HeroImportPreview({
    required this.name,
    required this.formatVersion,
    required this.isCompatible,
    this.className,
    this.ancestryName,
  });

  final String name;
  final int formatVersion;
  final bool isCompatible;
  final String? className;
  final String? ancestryName;
}

/// Parsed picks from an import code - all the user's choices.
/// This can be used to drive the hero creation flow.
class HeroParsedPicks {
  HeroParsedPicks({required this.name});

  final String name;

  // === STORY ===
  String? ancestryId;
  List<String>? ancestryTraitIds;
  Map<String, String>? traitChoices; // traitId -> choice value

  String? cultureEnvironmentId;
  String? cultureOrganisationId;
  String? cultureUpbringingId;
  List<String>? cultureSkillIds;

  String? careerId;
  List<String>? careerSkillIds;
  List<String>? careerPerkIds;
  Map<String, Map<String, String>>? perkSelections; // perkId -> key -> value
  String? incitingIncidentId;

  String? complicationId;
  List<String>? languageIds;

  // === STRIFE ===
  String? classId;
  String? subclassId;
  String? characteristicArrayName;
  Map<String, int>? characteristicAssignments; // stat name -> value
  Map<int, String>? levelChoices; // level -> stat name
  Map<String, List<String>>? featureSelections; // featureId -> choices
  int level = 1;

  // === STRENGTH ===
  String? kitId;
  String? kitSkillId;
  Map<String, String>? kitEquipmentPicks; // slot -> itemId
  String? deityId;
  List<String>? domainIds;
  String? domainSkillId;
  String? titleId;

  // === ALL ENTRIES ===
  List<String>? allAbilityIds;
  List<String>? allSkillIds;
  List<String>? allLanguageIds;
  List<String>? allPerkIds;
  List<String>? allTitleIds;
  List<String>? allEquipmentIds;

  // === OPTIONAL SECTIONS ===
  String? runtimeState; // Raw runtime section
  String? userDataBase64; // Encoded user data
}
