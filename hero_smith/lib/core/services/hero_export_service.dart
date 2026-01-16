import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'hero_export_codes.dart';
import 'hero_export_models.dart';
import 'ability_resolver_service.dart';

/// Version of the export format. Increment when making breaking changes.
const int kExportVersion = 1;

/// Options for hero export - controls what optional data is included.
class HeroExportOptions {
  const HeroExportOptions({
    this.includeRuntimeState = false,
    this.includeUserData = false,
    this.includeCustomItems = false,
  });

  /// Include runtime state: current stamina, conditions, heroic resources, etc.
  final bool includeRuntimeState;

  /// Include user-generated data: notes, downtime projects, followers
  final bool includeUserData;

  /// Include custom/user-created items
  final bool includeCustomItems;

  /// Default options - minimal export with just hero build picks
  static const minimal = HeroExportOptions();

  /// Full export with all optional data
  static const full = HeroExportOptions(
    includeRuntimeState: true,
    includeUserData: true,
    includeCustomItems: true,
  );
}

/// Service for exporting and importing heroes as shareable codes.
///
/// PICKS-ONLY format (P: prefix):
/// - Exports ONLY user picks/choices, not derived data
/// - App logic rebuilds everything from picks on import
/// - Format: P:NAME|picks;separated;by;semicolons
///
/// See hero_export_codes.dart for all pick codes.
class HeroExportService {
  HeroExportService(this._db);
  final AppDatabase _db;

  // ===========================================================================
  // EXPORT
  // ===========================================================================

  /// Export a hero to picks-only code string.
  ///
  /// Format: P:NAME|pick1;pick2;pick3...
  /// Optional sections added with flags: P:NAME|picks|runtime|userdata
  Future<String> exportHeroToCode(
    String heroId, {
    HeroExportOptions options = HeroExportOptions.minimal,
  }) async {
    final heroRow = await (_db.select(_db.heroes)
          ..where((t) => t.id.equals(heroId)))
        .getSingleOrNull();
    if (heroRow == null) {
      throw ArgumentError('Hero not found: $heroId');
    }

    // Gather all data
    final entries = await (_db.select(_db.heroEntries)
          ..where((t) => t.heroId.equals(heroId)))
        .get();
    final configs = await (_db.select(_db.heroConfig)
          ..where((t) => t.heroId.equals(heroId)))
        .get();
    final values = await _db.getHeroValues(heroId);

    // Build picks
    final picks = _buildPicks(entries, configs, values, options);

    // Build the code
    final name = _sanitizeName(heroRow.name);
    var code = 'P:$name|${picks.join(";")}';

    // Add optional sections
    if (options.includeRuntimeState) {
      final runtime = await _buildRuntimeSection(heroId, values);
      if (runtime.isNotEmpty) code += '|$runtime';
    }

    if (options.includeUserData) {
      final userData = await _buildUserDataSection(heroId);
      if (userData.isNotEmpty) code += '|$userData';
    }

    return code;
  }

  /// Build the picks list from hero data
  List<String> _buildPicks(
    List<HeroEntry> entries,
    List<HeroConfigData> configs,
    List<HeroValue> values,
    HeroExportOptions options,
  ) {
    final picks = <String>[];

    // Helpers
    Map<String, dynamic>? getConfig(String key) {
      final c = configs.firstWhereOrNull((c) => c.configKey == key);
      final json = c?.valueJson;
      if (json == null) return null;
      try {
        return jsonDecode(json) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }

    List<String> getEntryIds(String type) {
      return entries
          .where((e) => e.entryType == type)
          .map((e) => e.entryId)
          .toList();
    }

    String? getSingleEntry(String type) {
      final e = entries.firstWhereOrNull((e) => e.entryType == type);
      return e?.entryId;
    }

    // === STORY PICKS ===

    // Ancestry
    final ancestry = getSingleEntry('ancestry');
    if (ancestry != null) {
      picks.add(
          '${pickCodes['ancestry']}:${_toShort(ancestry, ancestryShorts)}');
    }

    // Ancestry traits
    final traits = getEntryIds('ancestry_trait');
    if (traits.isNotEmpty) {
      final traitShorts = traits.map((t) => _toShort(t, ancestryTraitsShorts));
      picks.add('${pickCodes['traits']}:${traitShorts.join(",")}');
    }

    // Trait inner choices
    final traitChoices = getConfig('ancestry.trait_choices');
    if (traitChoices != null && traitChoices.isNotEmpty) {
      for (final e in traitChoices.entries) {
        picks.add('${pickCodes['trait_choice']}${_stripId(e.key)}:${e.value}');
      }
    }

    // Culture elements
    final envs = getEntryIds('culture_environment');
    final orgs = getEntryIds('culture_organisation');
    final upbs = getEntryIds('culture_upbringing');
    if (envs.isNotEmpty) {
      picks.add(
          '${pickCodes['culture_environment']}:${_toShort(envs.first, cultureEnvironmentShorts)}');
    }
    if (orgs.isNotEmpty) {
      picks.add(
          '${pickCodes['culture_organisation']}:${_toShort(orgs.first, cultureOrganisationShorts)}');
    }
    if (upbs.isNotEmpty) {
      picks.add(
          '${pickCodes['culture_upbringing']}:${_toShort(upbs.first, cultureUpbringingShorts)}');
    }

    // Culture skill picks
    final envSkill = getConfig('culture.environment.skill')?['selection'];
    final orgSkill = getConfig('culture.organisation.skill')?['selection'];
    final upbSkill = getConfig('culture.upbringing.skill')?['selection'];
    final cultureSkills = <String>[];
    if (envSkill != null) {
      cultureSkills.add(_toShort(envSkill.toString(), skillShorts));
    }
    if (orgSkill != null) {
      cultureSkills.add(_toShort(orgSkill.toString(), skillShorts));
    }
    if (upbSkill != null) {
      cultureSkills.add(_toShort(upbSkill.toString(), skillShorts));
    }
    if (cultureSkills.isNotEmpty) {
      picks.add('${pickCodes['culture_skills']}:${cultureSkills.join(",")}');
    }

    // Career
    final career = getSingleEntry('career');
    if (career != null) {
      picks.add('${pickCodes['career']}:${_toShort(career, careerShorts)}');
    }

    // Career chosen skills
    final careerSkills = getConfig('career.chosen_skills')?['list'] as List?;
    if (careerSkills != null && careerSkills.isNotEmpty) {
      final skillIds = careerSkills
          .map((s) => _toShort(s.toString(), skillShorts))
          .join(',');
      picks.add('${pickCodes['career_skills']}:$skillIds');
    }

    // Career perk + perk selections
    final careerPerks = getConfig('career.chosen_perks')?['list'] as List?;
    if (careerPerks != null && careerPerks.isNotEmpty) {
      for (final perk in careerPerks) {
        final perkShort = _toShort(perk.toString(), perkShorts);
        picks.add('${pickCodes['career_perk']}:$perkShort');

        // Check for perk selections
        final perkSelections = getConfig('perk.$perk.selections');
        if (perkSelections != null && perkSelections.isNotEmpty) {
          for (final sel in perkSelections.entries) {
            final value = sel.value is List
                ? '[${(sel.value as List).join(", ")}]'
                : sel.value.toString();
            picks.add(
                '${pickCodes['career_perk_choice']}$perkShort.${sel.key}:$value');
          }
        }
      }
    }

    // Inciting incident - look up by name to get ID, then short
    final incident = getConfig('career.inciting_incident')?['name'];
    if (incident != null) {
      // Try to find matching short by incident name
      final incidentStr = incident.toString();
      final incidentId = incitingIncidentShorts.keys.firstWhere(
        (k) =>
            k.replaceAll('_', ' ').toLowerCase() ==
            incidentStr.toLowerCase().replaceAll(' ', '_').replaceAll("'", ''),
        orElse: () => incidentStr,
      );
      picks.add(
          '${pickCodes['inciting_incident']}:${_toShort(incidentId, incitingIncidentShorts)}');
    }

    // Complication
    final complication = getSingleEntry('complication');
    if (complication != null) {
      picks.add(
          '${pickCodes['complication']}:${_toShort(complication, complicationShorts)}');
    }

    // Languages (only user-picked from culture, not granted)
    final languages = entries
        .where((e) => e.entryType == 'language')
        .map((e) => _toShort(e.entryId, languageShorts))
        .toSet()
        .toList();
    if (languages.isNotEmpty) {
      picks.add('${pickCodes['languages']}:${languages.join(",")}');
    }

    // === STRIFE PICKS ===

    // Class
    final heroClass = getSingleEntry('class');
    if (heroClass != null) {
      picks.add('${pickCodes['class']}:${_toShort(heroClass, classShorts)}');
    }

    // Subclass
    final subclass = getSingleEntry('subclass');
    if (subclass != null) {
      picks.add('${pickCodes['subclass']}:${_toShort(subclass, subclassShorts)}');
    }

    // Characteristic array
    final charArray = getConfig('strife.characteristic_array');
    if (charArray != null) {
      final arrayName = charArray['name'];
      if (arrayName != null && arrayName.toString().isNotEmpty) {
        picks.add('${pickCodes['char_array']}:$arrayName');
      }
    }

    // Characteristic assignments
    final charAssign =
        getConfig('strife.characteristic_assignments')?['assignments'];
    if (charAssign != null && charAssign is Map && charAssign.isNotEmpty) {
      final parts = <String>[];
      for (final e in charAssign.entries) {
        final statCode = statCodes[e.key.toString().toLowerCase()];
        if (statCode != null) parts.add('$statCode>${e.value}');
      }
      if (parts.isNotEmpty) {
        picks.add('${pickCodes['char_map']}:${parts.join(",")}');
      }
    }

    // Level choice selections
    final levelChoices = getConfig('strife.level_choice_selections');
    if (levelChoices != null && levelChoices.isNotEmpty) {
      final parts = <String>[];
      for (final e in levelChoices.entries) {
        final statCode = statCodes[e.value.toString().toLowerCase()];
        if (statCode != null) parts.add('${e.key}>$statCode');
      }
      if (parts.isNotEmpty) {
        picks.add('${pickCodes['level_choices']}:${parts.join(",")}');
      }
    }

    // Class feature selections (use programmatic compression)
    final featureSel = getConfig('class_feature.selections') ??
        getConfig('strife.class_feature_selections');
    if (featureSel != null && featureSel.isNotEmpty) {
      for (final e in featureSel.entries) {
        final selections = e.value is List ? e.value as List : [e.value];
        if (selections.isNotEmpty) {
          final selStr =
              selections.map((s) => _compressId(s.toString())).join(',');
          picks.add(
              '${pickCodes['feature_selection']}:${_compressId(e.key)}>$selStr');
        }
      }
    }

    // === STRENGTH PICKS ===

    // Kit
    final kit = getSingleEntry('kit');
    if (kit != null) {
      picks.add('${pickCodes['kit']}:${_toShort(kit, kitShorts)}');
    } else {
      final equipmentIds = getEntryIds('equipment');
      final kitFromEquipment = equipmentIds.firstWhereOrNull((id) {
        if (kitShorts.containsKey(id)) return true;
        final withPrefix = id.startsWith('kit_') ? id : 'kit_$id';
        return kitShorts.containsKey(withPrefix);
      });
      if (kitFromEquipment != null) {
        final normalized = kitShorts.containsKey(kitFromEquipment)
            ? kitFromEquipment
            : kitFromEquipment.startsWith('kit_')
                ? kitFromEquipment
                : 'kit_$kitFromEquipment';
        picks.add('${pickCodes['kit']}:${_toShort(normalized, kitShorts)}');
      }
    }

    // Kit selections
    final kitSel = getConfig('kit.selections');
    if (kitSel != null) {
      final skillPick = kitSel['skill_pick'];
      if (skillPick != null) {
        picks.add(
            '${pickCodes['kit_skill']}:${_toShort(skillPick.toString(), skillShorts)}');
      }

      final eqPicks = kitSel['equipment_picks'];
      if (eqPicks is Map && eqPicks.isNotEmpty) {
        for (final ep in eqPicks.entries) {
          picks.add(
              '${pickCodes['kit_equipment']}:${ep.key}>${_stripId(ep.value.toString())}');
        }
      }
    }

    // Deity
    final deity = getSingleEntry('deity');
    if (deity != null) {
      picks.add('${pickCodes['deity']}:${_toShort(deity, deityShorts)}');
    }

    // Domains
    final domains = getEntryIds('domain');
    if (domains.isNotEmpty) {
      picks.add(
          '${pickCodes['domains']}:${domains.map((d) => _toShort(d, domainsShorts)).join(",")}');
    }

    // Title
    final title = getSingleEntry('title');
    if (title != null) {
      picks.add('${pickCodes['title']}:${_toShort(title, titleShorts)}');
    }

    // === MANUAL PICKS ===

    // All abilities
    final allAbilities = entries
      .where((e) => e.entryType == 'ability')
      .map((e) => _compressAbilityId(e.entryId))
      .toSet()
      .toList();
    if (allAbilities.isNotEmpty) {
      picks.add('${pickCodes['abilities']}:${allAbilities.join(",")}');
    }

    // All skills
    final allSkills = entries
        .where((e) => e.entryType == 'skill')
        .map((e) => _toShort(e.entryId, skillShorts))
        .toSet()
        .toList();
    if (allSkills.isNotEmpty) {
      picks.add('${pickCodes['all_skills']}:${allSkills.join(",")}');
    }

    // All perks
    final allPerks = entries
        .where((e) => e.entryType == 'perk')
        .map((e) => _toShort(e.entryId, perkShorts))
        .toSet()
        .toList();
    if (allPerks.isNotEmpty) {
      picks.add('${pickCodes['perks']}:${allPerks.join(",")}');
    }

    // All titles
    final allTitles = entries
        .where((e) => e.entryType == 'title')
        .map((e) => _toShort(e.entryId, titleShorts))
        .toSet()
        .toList();
    if (allTitles.isNotEmpty) {
      picks.add('${pickCodes['title']}:${allTitles.join(",")}');
    }

    // All equipment (kits, wards, prayers, etc.)
    final allEquipment = entries
      .where((e) => e.entryType == 'equipment')
      .map((e) => _toShortEquipment(e.entryId))
      .toSet()
      .toList();
    if (allEquipment.isNotEmpty) {
      picks.add('${pickCodes['equipment']}:${allEquipment.join(",")}');
    }

    // Level (only if > 1)
    final level =
        values.firstWhereOrNull((v) => v.key == 'basics.level')?.value ?? 1;
    if (level > 1) {
      picks.add('${pickCodes['level']}:$level');
    }

    return picks;
  }

  /// Build runtime state section
  Future<String> _buildRuntimeSection(
    String heroId,
    List<HeroValue> values,
  ) async {
    final parts = <String>[];

    for (final v in values) {
      final code = runtimeCodes[v.key];
      if (code == null) continue;

      if (v.value != null && v.value != 0) {
        parts.add('$code${v.value}');
        continue;
      }
      if (v.doubleValue != null && v.doubleValue != 0) {
        parts.add('$code${v.doubleValue}');
        continue;
      }
      final rawJson = v.jsonValue;
      if (rawJson != null && rawJson.isNotEmpty) {
        final encoded = base64Url.encode(utf8.encode(rawJson));
        parts.add('$code:$encoded');
        continue;
      }
      final rawText = v.textValue;
      if (rawText != null && rawText.isNotEmpty) {
        final encoded = base64Url.encode(utf8.encode(rawText));
        parts.add('$code:$encoded');
      }
    }

    // Downtime project progression (compact)
    final projects = await (_db.select(_db.heroDowntimeProjects)
          ..where((t) => t.heroId.equals(heroId)))
        .get();
    final progress = projects
        .where((p) => !p.isCompleted)
        .map((p) => {'id': p.id, 'c': p.currentPoints, 'g': p.projectGoal})
        .toList();
    if (progress.isNotEmpty) {
      final encoded = base64Url.encode(utf8.encode(jsonEncode(progress)));
      parts.add('dp:$encoded');
    }

    return parts.join(',');
  }

  /// Build user data section (compressed)
  Future<String> _buildUserDataSection(String heroId) async {
    final userData = <String, dynamic>{};

    // Projects (full)
    final projects = await (_db.select(_db.heroDowntimeProjects)
          ..where((t) => t.heroId.equals(heroId)))
        .get();
    if (projects.isNotEmpty) {
      userData['p'] = projects
          .map((p) => {
                'id': p.id,
                if (p.templateProjectId != null) 't': p.templateProjectId,
                'n': p.name,
                'd': p.description,
                'g': p.projectGoal,
                'c': p.currentPoints,
                'pq': p.prerequisitesJson,
                if (p.projectSource != null) 's': p.projectSource,
                if (p.sourceLanguage != null) 'sl': p.sourceLanguage,
                'gu': p.guidesJson,
                'rc': p.rollCharacteristicsJson,
                'ev': p.eventsJson,
                'no': p.notes,
                if (p.isCompleted) 'd': true,
                'cu': p.isCustom,
              })
          .toList();
    }

    // Followers (full)
    final followers = await (_db.select(_db.heroFollowers)
          ..where((t) => t.heroId.equals(heroId)))
        .get();
    if (followers.isNotEmpty) {
      userData['f'] =
          followers
              .map((f) => {
                    'id': f.id,
                    'n': f.name,
                    't': f.followerType,
                    'm': f.might,
                    'a': f.agility,
                    'r': f.reason,
                    'i': f.intuition,
                    'p': f.presence,
                    's': f.skillsJson,
                    'l': f.languagesJson,
                  })
              .toList();
    }

    // Notes (full)
    final notes = await (_db.select(_db.heroNotes)
          ..where((t) => t.heroId.equals(heroId)))
        .get();
    if (notes.isNotEmpty) {
      userData['n'] = notes
          .map((n) => {
                'id': n.id,
                't': n.title,
                'c': n.content,
                if (n.folderId != null) 'f': n.folderId,
                'if': n.isFolder,
                'o': n.sortOrder,
              })
          .toList();
    }

    // Sources
    final sources = await (_db.select(_db.heroProjectSources)
          ..where((t) => t.heroId.equals(heroId)))
        .get();
    if (sources.isNotEmpty) {
      userData['s'] = sources
          .map((s) => {
                'id': s.id,
                'n': s.name,
                't': s.type,
                if (s.language != null) 'l': s.language,
                if (s.description != null) 'd': s.description,
              })
          .toList();
    }

    // Inventory containers (gear inventory tab)
    final inventoryConfig =
        await _db.getHeroConfigValue(heroId, 'gear.inventory_containers');
    if (inventoryConfig != null && inventoryConfig['containers'] != null) {
      userData['i'] = inventoryConfig['containers'];
    }

    if (userData.isEmpty) return '';
    return base64Url.encode(utf8.encode(jsonEncode(userData)));
  }

  // ===========================================================================
  // IMPORT
  // ===========================================================================

  /// Parse a hero code and return the parsed picks for import.
  /// Does NOT create the hero - returns data to be used by hero creation flow.
  HeroParsedPicks? parseCode(String code) {
    if (!code.startsWith('P:')) return null;

    try {
      final payload = code.substring(2);
      final sections = payload.split('|');
      if (sections.length < 2) return null;

      final name = sections[0];
      final picksSection = sections[1];

      final picks = HeroParsedPicks(name: name);

      for (final pick in picksSection.split(';')) {
        if (pick.isEmpty) continue;
        final colonIdx = pick.indexOf(':');
        if (colonIdx < 0) continue;

        final code = pick.substring(0, colonIdx);
        final value = pick.substring(colonIdx + 1);

        _parsePick(picks, code, value);
      }

      // Parse optional runtime section
      if (sections.length > 2) {
        picks.runtimeState = sections[2];
      }

      // Parse optional user data section
      if (sections.length > 3) {
        picks.userDataBase64 = sections[3];
      }

      return picks;
    } catch (_) {
      return null;
    }
  }

  /// Parse a single pick and add to picks object
  void _parsePick(HeroParsedPicks picks, String code, String value) {
    switch (code) {
      // === STORY ===
      case 'a': // ancestry
        picks.ancestryId = _normalizeAncestryId(
          _fromShort(value, shortsToAncestry),
        );
        break;
      case 't': // traits
        picks.ancestryTraitIds = value
            .split(',')
            .map((v) => _fromShort(v, shortsToAncestryTrait))
            .toList();
        break;
      case 'ce': // culture environment
        picks.cultureEnvironmentId = _normalizeCultureId(
          _fromShort(value, shortsToCultureEnvironment),
          'environment',
        );
        break;
      case 'co': // culture organisation
        picks.cultureOrganisationId = _normalizeCultureId(
          _fromShort(value, shortsToCultureOrganisation),
          'organisation',
        );
        break;
      case 'cu': // culture upbringing
        picks.cultureUpbringingId = _normalizeCultureId(
          _fromShort(value, shortsToCultureUpbringing),
          'upbringing',
        );
        break;
      case 'cs': // culture skills
        picks.cultureSkillIds =
            value.split(',').map((v) => _fromShort(v, shortsToSkill)).toList();
        break;
      case 'r': // career
        picks.careerId = _fromShort(value, shortsToCareer);
        break;
      case 'rs': // career skills
        picks.careerSkillIds =
            value.split(',').map((v) => _fromShort(v, shortsToSkill)).toList();
        break;
      case 'rp': // career perk
        picks.careerPerkIds ??= [];
        picks.careerPerkIds!.add(_fromShort(value, shortsToPerk));
        break;
      case 'ri': // inciting incident
        picks.incitingIncidentId = _fromShort(value, shortsToIncitingIncident);
        break;
      case 'w': // complication
        picks.complicationId = _fromShort(value, shortsToComplication);
        break;
      case 'l': // languages
        picks.allLanguageIds = value
          .split(',')
          .map((v) => _fromShort(v, shortsToLanguage))
          .toList();
        break;

      // === STRIFE ===
      case 'c': // class
        picks.classId = _normalizeClassId(_fromShort(value, shortsToClass));
        break;
      case 's': // subclass
        picks.subclassId =
            _normalizeSubclassId(_fromShort(value, shortsToSubclass));
        break;
      case 'ca': // characteristic array
        picks.characteristicArrayName = value;
        break;
      case 'cm': // characteristic map
        picks.characteristicAssignments = _parseCharMap(value);
        break;
      case 'lv': // level choices
        if (value.contains('>')) {
          picks.levelChoices = _parseLevelChoices(value);
        }
        break;
      case 'lv#': // level number
        picks.level = int.tryParse(value) ?? 1;
        break;

      // === STRENGTH ===
      case 'k': // kit
        picks.kitId = _normalizeKitId(_fromShort(value, shortsToKit));
        break;
      case 'ks': // kit skill
        picks.kitSkillId = _fromShort(value, shortsToSkill);
        break;
      case 'ke': // kit equipment
        final gtIdx = value.indexOf('>');
        if (gtIdx > 0) {
          final slot = value.substring(0, gtIdx);
          final itemId = value.substring(gtIdx + 1);
          picks.kitEquipmentPicks ??= {};
          picks.kitEquipmentPicks![slot] = itemId;
        }
        break;
      case 'd': // deity
        picks.deityId = _fromShort(value, shortsToDeity);
        break;
      case 'o': // domains
        picks.domainIds = value
            .split(',')
            .map((v) => _normalizeDomainId(_fromShort(v, shortsToDomain)))
            .whereType<String>()
            .toList();
        break;
      case 'os': // domain skill
        picks.domainSkillId = _fromShort(value, shortsToSkill);
        break;
      case 'n': // title
        picks.allTitleIds = value
            .split(',')
            .map((v) => _fromShort(v, shortsToTitle))
            .toList();
        break;

      // === MANUAL ===
      case 'ab': // abilities
        picks.allAbilityIds = value
            .split(',')
            .map((v) => _decompressAbilityId(v))
            .toList();
        break;
      case 'sk': // all skills
        picks.allSkillIds =
            value.split(',').map((v) => _fromShort(v, shortsToSkill)).toList();
        break;
      case 'pk': // perks
        picks.allPerkIds =
            value.split(',').map((v) => _fromShort(v, shortsToPerk)).toList();
        break;
      case 'eq': // equipment
        picks.allEquipmentIds =
            value.split(',').map((v) => _fromShortEquipment(v)).toList();
        break;
    }

    // Handle prefix codes (t., rp., fs:)
    if (code.startsWith('t.')) {
      // Trait choice: t.traitId:choice
      final traitId = code.substring(2);
      picks.traitChoices ??= {};
      picks.traitChoices![traitId] = value;
    } else if (code.startsWith('rp.')) {
      // Perk choice: rp.perkId.key:value
      final parts = code.substring(3).split('.');
      if (parts.length >= 2) {
        final perkId = _fromShort(parts[0], shortsToPerk);
        final key = parts.sublist(1).join('.');
        picks.perkSelections ??= {};
        picks.perkSelections![perkId] ??= {};
        picks.perkSelections![perkId]![key] = value;
      }
    } else if (code == 'fs') {
      // Feature selection: fs:featureId>choice1,choice2
      final gtIdx = value.indexOf('>');
      if (gtIdx > 0) {
        final featureId = _decompressId(value.substring(0, gtIdx));
        final selections = value
            .substring(gtIdx + 1)
            .split(',')
            .map(_decompressId)
            .toList();
        picks.featureSelections ??= {};
        picks.featureSelections![featureId] = selections;
      }
    }
  }

  /// Parse characteristic map: m>2,a>1,r>0,i>1,p>0
  Map<String, int> _parseCharMap(String value) {
    final map = <String, int>{};
    for (final part in value.split(',')) {
      final gtIdx = part.indexOf('>');
      if (gtIdx > 0) {
        final statCode = part.substring(0, gtIdx);
        final statVal = int.tryParse(part.substring(gtIdx + 1)) ?? 0;
        final statName = codeToStat[statCode];
        if (statName != null) {
          map[statName] = statVal;
        }
      }
    }
    return map;
  }

  /// Parse level choices: 3>m,5>a
  Map<int, String> _parseLevelChoices(String value) {
    final map = <int, String>{};
    for (final part in value.split(',')) {
      final gtIdx = part.indexOf('>');
      if (gtIdx > 0) {
        final level = int.tryParse(part.substring(0, gtIdx));
        final statCode = part.substring(gtIdx + 1);
        final statName = codeToStat[statCode];
        if (level != null && statName != null) {
          map[level] = statName;
        }
      }
    }
    return map;
  }

  /// Import a hero from a shareable code string.
  /// Returns the new hero's ID on success.
  Future<String> importHeroFromCode(String code) async {
    final picks = parseCode(code);
    if (picks == null) {
      throw const FormatException('Invalid hero code format');
    }

    final heroId = await _db.createHero(name: picks.name);

    Future<void> addEntry(
      String entryType,
      String? entryId, {
      String sourceType = 'import',
      String sourceId = 'code',
      String gainedBy = 'choice',
    }) async {
      if (entryId == null || entryId.isEmpty) return;
      await _db.upsertHeroEntry(
        heroId: heroId,
        entryType: entryType,
        entryId: entryId,
        sourceType: sourceType,
        sourceId: sourceId,
        gainedBy: gainedBy,
      );
    }

    await _db.transaction(() async {
      // --- Story entries ---
      if (picks.ancestryId != null && picks.ancestryId!.isNotEmpty) {
        await _db.upsertHeroEntry(
          heroId: heroId,
          entryType: 'ancestry',
          entryId: picks.ancestryId!,
          sourceType: 'ancestry',
          sourceId: picks.ancestryId!,
          gainedBy: 'choice',
        );
      }
      if (picks.ancestryTraitIds != null) {
        for (final traitId in picks.ancestryTraitIds!) {
          if (traitId.isEmpty) continue;
          await _db.upsertHeroEntry(
            heroId: heroId,
            entryType: 'ancestry_trait',
            entryId: traitId,
            sourceType: 'ancestry',
            sourceId: picks.ancestryId ?? 'ancestry',
            gainedBy: 'choice',
          );
        }
      }

      if (picks.cultureEnvironmentId != null &&
          picks.cultureEnvironmentId!.isNotEmpty) {
        await _db.upsertHeroEntry(
          heroId: heroId,
          entryType: 'culture_environment',
          entryId: picks.cultureEnvironmentId!,
          sourceType: 'culture',
          sourceId: 'culture_environment',
          gainedBy: 'choice',
        );
      }
      if (picks.cultureOrganisationId != null &&
          picks.cultureOrganisationId!.isNotEmpty) {
        await _db.upsertHeroEntry(
          heroId: heroId,
          entryType: 'culture_organisation',
          entryId: picks.cultureOrganisationId!,
          sourceType: 'culture',
          sourceId: 'culture_organisation',
          gainedBy: 'choice',
        );
      }
      if (picks.cultureUpbringingId != null &&
          picks.cultureUpbringingId!.isNotEmpty) {
        await _db.upsertHeroEntry(
          heroId: heroId,
          entryType: 'culture_upbringing',
          entryId: picks.cultureUpbringingId!,
          sourceType: 'culture',
          sourceId: 'culture_upbringing',
          gainedBy: 'choice',
        );
      }

      await addEntry('career', picks.careerId);
      await addEntry('complication', picks.complicationId);

      if (picks.allLanguageIds != null) {
        for (final lang in picks.allLanguageIds!) {
          await addEntry('language', lang, sourceType: 'import');
        }
      }

      if (picks.allSkillIds != null) {
        for (final skill in picks.allSkillIds!) {
          await addEntry('skill', skill, sourceType: 'import');
        }
      } else if (picks.careerSkillIds != null) {
        for (final skill in picks.careerSkillIds!) {
          await addEntry('skill', skill, sourceType: 'career', sourceId: '');
        }
      }

      if (picks.allPerkIds != null) {
        for (final perk in picks.allPerkIds!) {
          await addEntry('perk', perk, sourceType: 'import');
        }
      } else if (picks.careerPerkIds != null) {
        for (final perk in picks.careerPerkIds!) {
          await addEntry('perk', perk, sourceType: 'career', sourceId: '');
        }
      }

      // --- Strife entries ---
      if (picks.classId != null && picks.classId!.isNotEmpty) {
        await _db.upsertHeroEntry(
          heroId: heroId,
          entryType: 'class',
          entryId: picks.classId!,
          sourceType: 'class',
          sourceId: picks.classId!,
          gainedBy: 'choice',
        );
      }
      if (picks.subclassId != null && picks.subclassId!.isNotEmpty) {
        await _db.upsertHeroEntry(
          heroId: heroId,
          entryType: 'subclass',
          entryId: picks.subclassId!,
          sourceType: 'subclass',
          sourceId: picks.subclassId!,
          gainedBy: 'choice',
        );
      }

      if (picks.subclassId != null && picks.subclassId!.isNotEmpty) {
        final subclassKey = _subclassKeyFromId(picks.subclassId!);
        if (subclassKey.isNotEmpty) {
          await _db.setHeroConfig(
            heroId: heroId,
            configKey: 'strife.subclass_key',
            value: {'key': subclassKey},
          );
        }
      }

      // Sync hero row classComponentId if present
      if (picks.classId != null && picks.classId!.isNotEmpty) {
        await (_db.update(_db.heroes)
              ..where((t) => t.id.equals(heroId)))
            .write(
          HeroesCompanion(
            classComponentId: Value(picks.classId),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }

      // --- Strength entries ---
      if (picks.kitId != null && picks.kitId!.isNotEmpty) {
        await _db.upsertHeroEntry(
          heroId: heroId,
          entryType: 'kit',
          entryId: picks.kitId!,
          sourceType: 'kit',
          sourceId: picks.kitId!,
          gainedBy: 'choice',
        );
      }
      if (picks.deityId != null && picks.deityId!.isNotEmpty) {
        await _db.upsertHeroEntry(
          heroId: heroId,
          entryType: 'deity',
          entryId: picks.deityId!,
          sourceType: 'deity',
          sourceId: picks.deityId!,
          gainedBy: 'choice',
        );
      }
      if (picks.allTitleIds != null) {
        for (final title in picks.allTitleIds!) {
          await addEntry('title', title, sourceType: 'import');
        }
      } else {
        await addEntry('title', picks.titleId);
      }

      if (picks.domainIds != null) {
        for (final domain in picks.domainIds!) {
          if (domain.isEmpty) continue;
          await _db.upsertHeroEntry(
            heroId: heroId,
            entryType: 'domain',
            entryId: domain,
            sourceType: 'domain',
            sourceId: 'domain_choice',
            gainedBy: 'choice',
          );
        }
      }

      // --- Manual picks ---
      if (picks.allAbilityIds != null) {
        for (final ability in picks.allAbilityIds!) {
          final resolved = await _resolveAbilityId(ability);
          await _db.upsertHeroEntry(
            heroId: heroId,
            entryType: 'ability',
            entryId: resolved,
            sourceType: 'import',
            sourceId: 'code',
            gainedBy: 'choice',
          );
        }
      }
      if (picks.allEquipmentIds != null) {
        for (final itemId in picks.allEquipmentIds!) {
          await addEntry('equipment', itemId, sourceType: 'import');
          final normalized = itemId.startsWith('kit_')
              ? itemId
              : kitShorts.containsKey(itemId)
                  ? itemId
                  : kitShorts.containsKey('kit_$itemId')
                      ? 'kit_$itemId'
                      : null;
          if (normalized != null) {
            await _db.upsertHeroEntry(
              heroId: heroId,
              entryType: 'kit',
              entryId: normalized,
              sourceType: 'kit',
              sourceId: normalized,
              gainedBy: 'choice',
            );
          }
        }
      }

      // --- Config values ---
      if (picks.traitChoices != null && picks.traitChoices!.isNotEmpty) {
        await _db.setHeroConfig(
          heroId: heroId,
          configKey: 'ancestry.trait_choices',
          value: picks.traitChoices!,
        );
      }

      if (picks.cultureSkillIds != null && picks.cultureSkillIds!.isNotEmpty) {
        if (picks.cultureSkillIds!.length > 0) {
          await _db.setHeroConfig(
            heroId: heroId,
            configKey: 'culture.environment.skill',
            value: {'selection': picks.cultureSkillIds![0]},
          );
        }
        if (picks.cultureSkillIds!.length > 1) {
          await _db.setHeroConfig(
            heroId: heroId,
            configKey: 'culture.organisation.skill',
            value: {'selection': picks.cultureSkillIds![1]},
          );
        }
        if (picks.cultureSkillIds!.length > 2) {
          await _db.setHeroConfig(
            heroId: heroId,
            configKey: 'culture.upbringing.skill',
            value: {'selection': picks.cultureSkillIds![2]},
          );
        }
      }

      if (picks.careerSkillIds != null) {
        await _db.setHeroConfig(
          heroId: heroId,
          configKey: 'career.chosen_skills',
          value: {'list': picks.careerSkillIds},
        );
      }
      if (picks.careerPerkIds != null) {
        await _db.setHeroConfig(
          heroId: heroId,
          configKey: 'career.chosen_perks',
          value: {'list': picks.careerPerkIds},
        );
      }
      if (picks.incitingIncidentId != null) {
        await _db.setHeroConfig(
          heroId: heroId,
          configKey: 'career.inciting_incident',
          value: {'name': picks.incitingIncidentId},
        );
      }

      if (picks.perkSelections != null) {
        for (final entry in picks.perkSelections!.entries) {
          await _db.setHeroConfig(
            heroId: heroId,
            configKey: 'perk.${entry.key}.selections',
            value: entry.value,
          );
        }
      }

      if (picks.characteristicArrayName != null) {
        await _db.setHeroConfig(
          heroId: heroId,
          configKey: 'strife.characteristic_array',
          value: {'name': picks.characteristicArrayName},
        );
      }
      if (picks.characteristicAssignments != null) {
        await _db.setHeroConfig(
          heroId: heroId,
          configKey: 'strife.characteristic_assignments',
          value: {'assignments': picks.characteristicAssignments},
        );
      }
      if (picks.levelChoices != null) {
        final levelChoiceMap = <String, dynamic>{
          for (final e in picks.levelChoices!.entries)
            e.key.toString(): e.value,
        };
        await _db.setHeroConfig(
          heroId: heroId,
          configKey: 'strife.level_choice_selections',
          value: levelChoiceMap,
        );
      }
      if (picks.featureSelections != null) {
        await _db.setHeroConfig(
          heroId: heroId,
          configKey: 'class_feature.selections',
          value: picks.featureSelections!,
        );
      }

      if (picks.kitSkillId != null || picks.kitEquipmentPicks != null) {
        final map = <String, dynamic>{};
        if (picks.kitSkillId != null) {
          map['skill_pick'] = picks.kitSkillId;
        }
        if (picks.kitEquipmentPicks != null &&
            picks.kitEquipmentPicks!.isNotEmpty) {
          map['equipment_picks'] = picks.kitEquipmentPicks;
        }
        await _db.setHeroConfig(
          heroId: heroId,
          configKey: 'kit.selections',
          value: map,
        );
      }

      if (picks.domainSkillId != null) {
        await _db.setHeroConfig(
          heroId: heroId,
          configKey: 'domain.skill',
          value: {'selection': picks.domainSkillId},
        );

        if (picks.domainIds != null && picks.domainIds!.isNotEmpty) {
          await _db.setHeroConfig(
            heroId: heroId,
            configKey: 'class_feature.skill_group_selections',
            value: {
              'feature_conduit_domain_feature_1': {
                picks.domainIds!.first: picks.domainSkillId,
              },
            },
          );
        }
      }

      // Level
      if (picks.level > 0) {
        await _db.upsertHeroValue(
          heroId: heroId,
          key: 'basics.level',
          value: picks.level,
        );
      }
    });

    return heroId;
  }

  /// Validate a hero code without importing.
  HeroImportPreview? validateCode(String code) {
    final picks = parseCode(code);
    if (picks == null) return null;

    return HeroImportPreview(
      name: picks.name,
      formatVersion: kExportVersion,
      isCompatible: true,
      className: picks.classId,
      ancestryName: picks.ancestryId,
    );
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  /// Strip common prefixes from IDs for compact export
  String _stripId(String id) {
    for (final prefix in idPrefixes) {
      if (id.startsWith(prefix)) {
        return id.substring(prefix.length);
      }
    }
    return id;
  }

  /// Convert ID to short code if available, else strip prefix
  String _toShort(String id, Map<String, String> shorts) {
    // Try exact match first
    final short = shorts[id];
    if (short != null) return short;
    // Try case-insensitive match
    final lower = id.toLowerCase();
    final lowerShort = shorts[lower];
    if (lowerShort != null) return lowerShort;
    // Strip prefix and try again
    final stripped = _stripId(lower);
    return shorts[stripped] ?? stripped;
  }

  /// Convert short code back to full ID
  String _fromShort(String short, Map<String, String> shortsToId) {
    return shortsToId[short] ?? short;
  }

  /// Programmatically compress an ID (for abilities/features with 500+ entries)
  /// Strategy: strip prefixes, abbreviate common patterns, shorten words
  String _compressId(String id) {
    var result = id.toLowerCase();

    // Remove leading ability/feature prefixes
    result = result.replaceFirst(RegExp(r'^(ability|feature)[_-]'), '');

    // Strip class prefixes first
    const classPrefixes = [
      'censor_',
      'conduit_',
      'elementalist_',
      'fury_',
      'null_',
      'shadow_',
      'tactician_',
      'talent_',
      'troubadour_',
    ];
    for (final prefix in classPrefixes) {
      if (result.startsWith(prefix)) {
        // Keep first 2 chars of class as marker
        result = '${prefix.substring(0, 2)}.${result.substring(prefix.length)}';
        break;
      }
    }

    // Strip common ability type prefixes
    result = result
        .replaceFirst('signature_', 'sg.')
        .replaceFirst('heroic_', 'hr.')
        .replaceFirst('wrath_', 'wr.')
        .replaceFirst('triumph_', 'tr.')
        .replaceFirst('piety_', 'pi.')
        .replaceFirst('focus_', 'fo.')
        .replaceFirst('insight_', 'in.')
        .replaceFirst('judgment_', 'ju.')
        .replaceFirst('clarity_', 'cl.')
        .replaceFirst('cost3_', '3.')
        .replaceFirst('cost5_', '5.')
        .replaceFirst('cost7_', '7.');

    // Compress level prefixes from features (supports class prefix like ce.)
    result = result.replaceAllMapped(
      RegExp(r'(^|\.)(\d+)[_-]level[_-]'),
      (m) => '${m.group(1)}${m.group(2)}l-'.toLowerCase(),
    );

    // Remove common filler words
    result = result
        .replaceAll('_the_', '_')
        .replaceAll('_and_', '_')
        .replaceAll('_of_', '_')
        .replaceAll('_a_', '_')
        .replaceAll('-the-', '-')
        .replaceAll('-and-', '-')
        .replaceAll('-of-', '-');

    // Token compression within dot-separated segments
    const tokenMap = {
      'domain': 'dm',
      'feature': 'ft',
      'order': 'or',
      'benefit': 'bn',
      'protective': 'pr',
      'circle': 'ci',
      'impervious': 'ip',
      'touch': 'to',
      'blessing': 'bl',
      'iron': 'ir',
      'read': 'rd',
      'person': 'ps',
      'judgment': 'jd',
      'every': 'ev',
      'step': 'st',
      'death': 'de',
      'gods': 'gd',
      'punish': 'pn',
      'defend': 'df',
      'purifying': 'pu',
      'fire': 'fi',
    };

    final parts = result.split('.');
    for (var i = 0; i < parts.length; i++) {
      var seg = parts[i].replaceAll('_', '-');
      final tokens = seg.split('-');
      for (var t = 0; t < tokens.length; t++) {
        final mapped = tokenMap[tokens[t]];
        if (mapped != null) tokens[t] = mapped;
      }
      parts[i] = tokens.join('-');
    }
    result = parts.join('.');

    return result;
  }

  /// Leave ability IDs uncompressed to ensure reversible import.
  String _compressAbilityId(String id) {
    return id;
  }

  String _decompressAbilityId(String id) {
    return id;
  }

  String _toShortEquipment(String id) {
    final lower = id.toLowerCase();
    const maps = [
      kitShorts,
      stormwightKitShorts,
      augmentationShorts,
      enchantmentShorts,
      prayerShorts,
      wardShorts,
      armorImbuement1stShorts,
      armorImbuement5thShorts,
      armorImbuement9thShorts,
      implementImbuement1stShorts,
      implementImbuement5thShorts,
      implementImbuement9thShorts,
      weaponImbuement1stShorts,
      weaponImbuement5thShorts,
      weaponImbuement9thShorts,
      artefactShorts,
      consumableShorts,
      leveledTreasureShorts,
      trinketShorts,
    ];
    for (final map in maps) {
      final short = map[id] ?? map[lower];
      if (short != null) return short;
    }
    return id;
  }

  String _fromShortEquipment(String short) {
    final maps = [
      shortsToKit,
      shortsToStormwightKit,
      shortsToAugmentation,
      shortsToEnchantment,
      shortsToPrayer,
      shortsToWard,
      shortsToArmorImbuement1st,
      shortsToArmorImbuement5th,
      shortsToArmorImbuement9th,
      shortsToImplementImbuement1st,
      shortsToImplementImbuement5th,
      shortsToImplementImbuement9th,
      shortsToWeaponImbuement1st,
      shortsToWeaponImbuement5th,
      shortsToWeaponImbuement9th,
      shortsToArtefact,
      shortsToConsumable,
      shortsToLeveledTreasure,
      shortsToTrinket,
    ];
    for (final map in maps) {
      final id = map[short];
      if (id != null) return id;
    }
    return short;
  }

  /// Decompress an ID back to searchable form
  String _decompressId(String compressed) {
    var result = compressed;

    // Restore class prefixes
    const classMarkers = {
      'ce.': 'censor_',
      'co.': 'conduit_',
      'el.': 'elementalist_',
      'fu.': 'fury_',
      'nu.': 'null_',
      'sh.': 'shadow_',
      'ta.': 'tactician_',
      'tl.': 'talent_',
      'tr.': 'troubadour_',
    };
    for (final e in classMarkers.entries) {
      if (result.startsWith(e.key)) {
        result = '${e.value}${result.substring(e.key.length)}';
        break;
      }
    }

    // Restore ability type prefixes
    result = result
        .replaceFirst('sg.', 'signature_')
        .replaceFirst('hr.', 'heroic_')
        .replaceFirst('wr.', 'wrath_')
        .replaceFirst('tr.', 'triumph_')
        .replaceFirst('pi.', 'piety_')
        .replaceFirst('fo.', 'focus_')
        .replaceFirst('in.', 'insight_')
        .replaceFirst('ju.', 'judgment_')
        .replaceFirst('cl.', 'clarity_')
        .replaceFirst('3.', 'cost3_')
        .replaceFirst('5.', 'cost5_')
        .replaceFirst('7.', 'cost7_');

    const reverseTokenMap = {
      'dm': 'domain',
      'ft': 'feature',
      'or': 'order',
      'bn': 'benefit',
      'pr': 'protective',
      'ci': 'circle',
      'ip': 'impervious',
      'to': 'touch',
      'bl': 'blessing',
      'ir': 'iron',
      'rd': 'read',
      'ps': 'person',
      'jd': 'judgment',
      'ev': 'every',
      'st': 'step',
      'de': 'death',
      'gd': 'gods',
      'pn': 'punish',
      'df': 'defend',
      'pu': 'purifying',
      'fi': 'fire',
    };

    // Normalize separators so token mapping works across prefixes
    result = result.replaceAll('_', '-');

    final parts = result.split('.');
    for (var i = 0; i < parts.length; i++) {
      final tokens = parts[i].split('-');
      for (var t = 0; t < tokens.length; t++) {
        final mapped = reverseTokenMap[tokens[t]];
        if (mapped != null) tokens[t] = mapped;
      }
      parts[i] = tokens.join('_');
    }
    result = parts.join('.');

    // Restore level prefixes (e.g., 1l -> 1_level)
    result = result.replaceAllMapped(
      RegExp(r'(^|_)(\d+)l(_|$)'),
      (m) => '${m.group(1)}${m.group(2)}_level${m.group(3)}',
    );

    return result;
  }

  String? _normalizeCultureId(String? id, String kind) {
    if (id == null || id.isEmpty) return id;
    if (id.startsWith('culture_')) return id;
    if (id.startsWith('${kind}_')) return 'culture_$id';
    return 'culture_${kind}_$id';
  }

  String? _normalizeAncestryId(String? id) {
    if (id == null || id.isEmpty) return id;
    if (id.startsWith('ancestry_')) return id;
    return 'ancestry_$id';
  }

  String? _normalizeClassId(String? id) {
    if (id == null || id.isEmpty) return id;
    if (id.startsWith('class_')) return id;
    return 'class_$id';
  }

  String? _normalizeSubclassId(String? id) {
    if (id == null || id.isEmpty) return id;
    if (id.startsWith('subclass_')) return id;
    return 'subclass_$id';
  }

  String? _normalizeDomainId(String? id) {
    if (id == null || id.isEmpty) return id;
    var normalized = id.trim();
    if (normalized.startsWith('domain_')) {
      normalized = normalized.substring('domain_'.length);
    }
    normalized = normalized.replaceAll('_', ' ').trim();
    if (normalized.isEmpty) return id;
    final parts = normalized.split(' ').where((p) => p.isNotEmpty);
    final titled = parts.map((p) {
      final lower = p.toLowerCase();
      return lower.length == 1
          ? lower.toUpperCase()
          : '${lower[0].toUpperCase()}${lower.substring(1)}';
    }).join(' ');
    return titled.isEmpty ? id : titled;
  }

  String? _normalizeKitId(String? id) {
    if (id == null || id.isEmpty) return id;
    if (id.startsWith('kit_')) return id;
    return 'kit_$id';
  }

  String _subclassKeyFromId(String id) {
    var key = id.trim();
    if (key.startsWith('subclass_')) {
      key = key.substring('subclass_'.length);
    }
    key = key
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return key;
  }

  Future<String> _resolveAbilityId(String raw) async {
    if (raw.isEmpty) return raw;
    final resolver = AbilityResolverService(_db);
    final candidates = <String>{raw};

    // Try alternate separators
    candidates.add(raw.replaceAll('_', '-'));
    candidates.add(raw.replaceAll('-', '_'));

    // Strip class/resource prefixes if present
    final classPrefixes = [
      'censor_',
      'conduit_',
      'elementalist_',
      'fury_',
      'null_',
      'shadow_',
      'tactician_',
      'talent_',
      'troubadour_',
    ];
    var stripped = raw;
    for (final prefix in classPrefixes) {
      if (stripped.startsWith(prefix)) {
        stripped = stripped.substring(prefix.length);
        break;
      }
    }
    final typePrefixes = [
      'signature_',
      'heroic_',
      'wrath_',
      'triumph_',
      'piety_',
      'focus_',
      'insight_',
      'judgment_',
      'clarity_',
      'cost3_',
      'cost5_',
      'cost7_',
    ];
    for (final prefix in typePrefixes) {
      if (stripped.startsWith(prefix)) {
        stripped = stripped.substring(prefix.length);
        break;
      }
    }
    candidates.add(stripped);
    candidates.add(stripped.replaceAll('_', '-'));

    for (final candidate in candidates) {
      final resolved = await resolver.resolveAbilityId(candidate);
      if (resolved.isEmpty) continue;
      final existing = await (_db.select(_db.components)
            ..where((t) => t.id.equals(resolved) & t.type.equals('ability')))
          .getSingleOrNull();
      if (existing != null) return existing.id;
    }

    return raw;
  }

  /// Sanitize hero name for embedding (no delimiters)
  String _sanitizeName(String name) {
    return name
        .replaceAll('|', '-')
        .replaceAll(';', ',')
        .replaceAll(':', ' ')
        .trim();
  }
}
