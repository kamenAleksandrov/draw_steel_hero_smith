import 'dart:convert';

import 'package:collection/collection.dart';

import '../db/app_database.dart' as db;
import '../models/hero_model.dart';
import '../models/hero_mod_keys.dart';

class HeroSummary {
  final String id;
  final String name;
  final String? className;
  final int level;
  final String? ancestryName;
  final String? careerName;
  final String? complicationName;

  const HeroSummary({
    required this.id,
    required this.name,
    required this.className,
    required this.level,
    required this.ancestryName,
    required this.careerName,
    required this.complicationName,
  });
}

class HeroMainStats {
  final int victories;
  final int exp;
  final int level;

  final int wealthBase;
  final int renownBase;

  final int mightBase;
  final int agilityBase;
  final int reasonBase;
  final int intuitionBase;
  final int presenceBase;

  final int sizeBase;
  final int speedBase;
  final int disengageBase;
  final int stabilityBase;

  final int staminaCurrent;
  final int staminaMaxBase;
  final int staminaTemp;

  final int recoveriesCurrent;
  final int recoveriesMaxBase;

  final int surgesCurrent;

  final String? classId;
  final String? heroicResourceName;
  final int heroicResourceCurrent;

  final Map<String, int> modifications;

  const HeroMainStats({
    required this.victories,
    required this.exp,
    required this.level,
    required this.wealthBase,
    required this.renownBase,
    required this.mightBase,
    required this.agilityBase,
    required this.reasonBase,
    required this.intuitionBase,
    required this.presenceBase,
    required this.sizeBase,
    required this.speedBase,
    required this.disengageBase,
    required this.stabilityBase,
    required this.staminaCurrent,
    required this.staminaMaxBase,
    required this.staminaTemp,
    required this.recoveriesCurrent,
    required this.recoveriesMaxBase,
    required this.surgesCurrent,
    required this.classId,
    required this.heroicResourceName,
    required this.heroicResourceCurrent,
    required this.modifications,
  });

  int modValue(String key) => modifications[key] ?? 0;

  int get wealthTotal => wealthBase + modValue(HeroModKeys.wealth);
  int get renownTotal => renownBase + modValue(HeroModKeys.renown);

  int get mightTotal => mightBase + modValue(HeroModKeys.might);
  int get agilityTotal => agilityBase + modValue(HeroModKeys.agility);
  int get reasonTotal => reasonBase + modValue(HeroModKeys.reason);
  int get intuitionTotal => intuitionBase + modValue(HeroModKeys.intuition);
  int get presenceTotal => presenceBase + modValue(HeroModKeys.presence);

  int get sizeTotal => sizeBase + modValue(HeroModKeys.size);
  int get speedTotal => speedBase + modValue(HeroModKeys.speed);
  int get disengageTotal => disengageBase + modValue(HeroModKeys.disengage);
  int get stabilityTotal => stabilityBase + modValue(HeroModKeys.stability);

  int get staminaMaxEffective =>
      staminaMaxBase + modValue(HeroModKeys.staminaMax);
  int get recoveriesMaxEffective =>
      recoveriesMaxBase + modValue(HeroModKeys.recoveriesMax);
  int get surgesTotal => surgesCurrent + modValue(HeroModKeys.surges);
}

class HeroRepository {
  HeroRepository(this._db);
  final db.AppDatabase _db;

  // Keys mapping for HeroValues
  static const _k = _HeroKeys._();

  Future<String> createHero({required String name}) =>
      _db.createHero(name: name);

  Stream<List<db.Heroe>> watchAllHeroes() => _db.watchAllHeroes();
  Future<List<db.Heroe>> getAllHeroes() => _db.getAllHeroes();

  Future<void> deleteHero(String heroId) => _db.deleteHero(heroId);

  Stream<HeroMainStats> watchMainStats(String heroId) async* {
    yield await fetchMainStats(heroId);
    yield* _db.watchHeroValues(heroId).map(_mapValuesToMainStats);
  }

  Future<HeroMainStats> fetchMainStats(String heroId) async {
    final values = await _db.getHeroValues(heroId);
    return _mapValuesToMainStats(values);
  }

  Future<void> updateMainStats(
    String heroId, {
    int? victories,
    int? exp,
    int? level,
    int? wealth,
    int? renown,
  }) async {
    Future<void> setInt(String key, int? value) async {
      if (value == null) return;
      await _db.upsertHeroValue(heroId: heroId, key: key, value: value);
    }

    await Future.wait([
      setInt(_k.victories, victories),
      setInt(_k.exp, exp),
      setInt(_k.level, level),
      setInt(_k.wealth, wealth),
      setInt(_k.renown, renown),
    ]);
  }

  Future<void> setModification(
    String heroId, {
    required String key,
    required int value,
  }) async {
    final values = await _db.getHeroValues(heroId);
    final current = Map<String, int>.from(_extractModifications(values));
    if (value == 0) {
      current.remove(key);
    } else {
      current[key] = value;
    }
    await _db.upsertHeroValue(
      heroId: heroId,
      key: _k.modifications,
      jsonMap: current,
    );
  }

  Future<void> updateVitals(
    String heroId, {
    int? staminaCurrent,
    int? staminaMax,
    int? staminaTemp,
    int? windedValue,
    int? dyingValue,
    int? recoveriesCurrent,
    int? recoveriesMax,
    int? surgesCurrent,
    int? heroicResourceCurrent,
  }) async {
    Future<void> setInt(String key, int? value) async {
      if (value == null) return;
      await _db.upsertHeroValue(heroId: heroId, key: key, value: value);
    }

    await Future.wait([
      setInt(_k.staminaCurrent, staminaCurrent),
      setInt(_k.staminaMax, staminaMax),
      setInt(_k.staminaTemp, staminaTemp),
      setInt(_k.windedValue, windedValue),
      setInt(_k.dyingValue, dyingValue),
      setInt(_k.recoveriesCurrent, recoveriesCurrent),
      setInt(_k.recoveriesMax, recoveriesMax),
      setInt(_k.surgesCurrent, surgesCurrent),
      setInt(_k.heroicResourceCurrent, heroicResourceCurrent),
    ]);
  }

  Future<void> updateHeroicResourceName(String heroId, String? name) async {
    await _db.upsertHeroValue(
      heroId: heroId,
      key: _k.heroicResource,
      textValue: name,
    );
  }

  Future<void> setCharacteristicBase(
    String heroId, {
    required String characteristic,
    required int value,
  }) async {
    String key;
    switch (characteristic.toLowerCase()) {
      case 'might':
        key = _k.might;
        break;
      case 'agility':
        key = _k.agility;
        break;
      case 'reason':
        key = _k.reason;
        break;
      case 'intuition':
        key = _k.intuition;
        break;
      case 'presence':
        key = _k.presence;
        break;
      default:
        throw ArgumentError('Unknown characteristic: $characteristic');
    }
    
    await _db.upsertHeroValue(
      heroId: heroId,
      key: key,
      value: value,
    );
  }

  HeroMainStats _mapValuesToMainStats(List<db.HeroValue> values) {
    int readInt(String key, {int defaultValue = 0}) {
      final v = values.firstWhereOrNull((e) => e.key == key);
      if (v == null) return defaultValue;
      return v.value ?? int.tryParse(v.textValue ?? '') ?? defaultValue;
    }

    String? readText(String key) {
      final v = values.firstWhereOrNull((e) => e.key == key);
      return v?.textValue;
    }

    final modifications = _extractModifications(values);

    final classId = readText(_k.className);

    return HeroMainStats(
      victories: readInt(_k.victories),
      exp: readInt(_k.exp),
      level: readInt(_k.level, defaultValue: 1),
      wealthBase: readInt(_k.wealth),
      renownBase: readInt(_k.renown),
      mightBase: readInt(_k.might),
      agilityBase: readInt(_k.agility),
      reasonBase: readInt(_k.reason),
      intuitionBase: readInt(_k.intuition),
      presenceBase: readInt(_k.presence),
      sizeBase: readInt(_k.size),
      speedBase: readInt(_k.speed),
      disengageBase: readInt(_k.disengage),
      stabilityBase: readInt(_k.stability),
      staminaCurrent: readInt(_k.staminaCurrent),
      staminaMaxBase: readInt(_k.staminaMax),
      staminaTemp: readInt(_k.staminaTemp),
      recoveriesCurrent: readInt(_k.recoveriesCurrent),
      recoveriesMaxBase: readInt(_k.recoveriesMax),
      surgesCurrent: readInt(_k.surgesCurrent),
      classId: classId,
      heroicResourceName: readText(_k.heroicResource),
      heroicResourceCurrent: readInt(_k.heroicResourceCurrent),
      modifications: modifications,
    );
  }

  Map<String, int> _extractModifications(List<db.HeroValue> values) {
    final entry = values.firstWhereOrNull((e) => e.key == _k.modifications);
    if (entry == null) return const {};
    final raw = entry.jsonValue ?? entry.textValue;
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final map = <String, int>{};
        decoded.forEach((key, value) {
          map[key.toString()] = _toInt(value) ?? 0;
        });
        return Map.unmodifiable(map);
      }
    } catch (_) {}
    return const {};
  }

  int? _toInt(dynamic value) {
    return switch (value) {
      int v => v,
      double d => d.round(),
      String s => int.tryParse(s),
      _ => null,
    };
  }

  // Lightweight projection for list screens
  Stream<List<HeroSummary>> watchSummaries() async* {
    await for (final heroes in _db.watchAllHeroes()) {
      final summaries = <HeroSummary>[];
      for (final h in heroes) {
        final values = await _db.getHeroValues(h.id);
        final comps = await _db.getHeroComponents(h.id);
        String? getText(String key) =>
            values.firstWhereOrNull((v) => v.key == key)?.textValue;
        int? getInt(String key) =>
            values.firstWhereOrNull((v) => v.key == key)?.value;
        final allComps = await _db.getAllComponents();
        String? nameForId(String? compId) => compId == null
            ? null
            : allComps.firstWhereOrNull((c) => c.id == compId)?.name ?? compId;
        String? nameForCategory(String category) {
          final compId = comps
              .firstWhereOrNull((c) => c.category == category)
              ?.componentId;
          return nameForId(compId);
        }

        final classId = getText(_k.className);
        final ancestryId = getText(_k.ancestry);
        final careerId = getText(_k.career);

        summaries.add(HeroSummary(
          id: h.id,
          name: h.name,
          className: nameForId(classId),
          level: getInt(_k.level) ?? 1,
          ancestryName: nameForId(ancestryId),
          careerName: nameForId(careerId),
          complicationName: nameForCategory('complication'),
        ));
      }
      yield summaries;
    }
  }

  // --- Ancestry selections (traits) ---
  Future<void> saveAncestryTraits({
    required String heroId,
    required String? ancestryId,
    required List<String> selectedTraitIds,
  }) async {
    // Persist ancestry id
    await _db.upsertHeroValue(
        heroId: heroId, key: _k.ancestry, textValue: ancestryId);
    // Persist selected trait ids as a json list
    await _db.upsertHeroValue(
        heroId: heroId,
        key: _k.ancestrySelectedTraits,
        jsonMap: {
          'list': selectedTraitIds,
        });
    // Persist signature trait name for convenience (redundant but requested)
    String? signatureName;
    if (ancestryId != null) {
      final all = await _db.getAllComponents();
      final traitsComp = all.firstWhereOrNull((c) {
        if (c.type != 'ancestry_trait') return false;
        try {
          final map = jsonDecode(c.dataJson) as Map<String, dynamic>;
          return map['ancestry_id'] == ancestryId;
        } catch (_) {
          return false;
        }
      });
      if (traitsComp != null) {
        try {
          final map = jsonDecode(traitsComp.dataJson) as Map<String, dynamic>;
          final sig = map['signature'];
          if (sig is Map && sig['name'] is String)
            signatureName = sig['name'] as String;
        } catch (_) {}
      }
    }
    await _db.upsertHeroValue(
        heroId: heroId, key: _k.ancestrySignature, textValue: signatureName);
  }

  Future<List<String>> getSelectedAncestryTraits(String heroId) async {
    final values = await _db.getHeroValues(heroId);
    final v =
        values.firstWhereOrNull((e) => e.key == _k.ancestrySelectedTraits);
    if (v == null) return <String>[];
    try {
      final raw = v.jsonValue ?? v.textValue;
      if (raw == null) return <String>[];
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['list'] is List) {
        return (decoded['list'] as List).map((e) => e.toString()).toList();
      }
      if (decoded is List) return decoded.map((e) => e.toString()).toList();
    } catch (_) {}
    return <String>[];
  }

  // --- Culture selections (environment, organisation, upbringing, languages) ---
  Future<void> saveCultureSelection({
    required String heroId,
    String? environmentId,
    String? organisationId,
    String? upbringingId,
    List<String> languageIds = const <String>[],
    String? environmentSkillId,
    String? organisationSkillId,
    String? upbringingSkillId,
  }) async {
    if (environmentId != null) {
      await _db.setHeroComponents(
          heroId: heroId,
          category: 'culture_environment',
          componentIds: [environmentId]);
    }
    if (organisationId != null) {
      await _db.setHeroComponents(
          heroId: heroId,
          category: 'culture_organisation',
          componentIds: [organisationId]);
    }
    if (upbringingId != null) {
      await _db.setHeroComponents(
          heroId: heroId,
          category: 'culture_upbringing',
          componentIds: [upbringingId]);
    }
    // Union provided language ids with existing to avoid removing languages granted elsewhere
    final currentComps = await _db.getHeroComponents(heroId);
    final existingLangs = currentComps
        .where((c) => c.category == 'language')
        .map((c) => c.componentId)
        .toSet();
    final langUnion = existingLangs.union(languageIds.toSet()).toList();
    await _db.setHeroComponents(
        heroId: heroId, category: 'language', componentIds: langUnion);

    // Persist chosen skill ids as HeroValues for traceability
    await _db.upsertHeroValue(
        heroId: heroId,
        key: _k.cultureEnvironmentSkill,
        textValue: environmentSkillId);
    await _db.upsertHeroValue(
        heroId: heroId,
        key: _k.cultureOrganisationSkill,
        textValue: organisationSkillId);
    await _db.upsertHeroValue(
        heroId: heroId,
        key: _k.cultureUpbringingSkill,
        textValue: upbringingSkillId);

    // Ensure selected skills are present among HeroComponents('skill') without removing others
    final currentSkillComps = await _db.getHeroComponents(heroId);
    final existingSkillIds = currentSkillComps
        .where((c) => c.category == 'skill')
        .map((c) => c.componentId)
        .toSet();
    final toAdd = <String>{};
    if (environmentSkillId != null && environmentSkillId.isNotEmpty)
      toAdd.add(environmentSkillId);
    if (organisationSkillId != null && organisationSkillId.isNotEmpty)
      toAdd.add(organisationSkillId);
    if (upbringingSkillId != null && upbringingSkillId.isNotEmpty)
      toAdd.add(upbringingSkillId);
    if (toAdd.isNotEmpty) {
      final union = [...existingSkillIds.union(toAdd)];
      await _db.setHeroComponents(
          heroId: heroId, category: 'skill', componentIds: union);
    }
  }

  Future<CultureSelection> loadCultureSelection(String heroId) async {
    final comps = await _db.getHeroComponents(heroId);
    String? idFor(String category) =>
        comps.firstWhereOrNull((c) => c.category == category)?.componentId;
    final values = await _db.getHeroValues(heroId);
    String? val(String key) =>
        values.firstWhereOrNull((v) => v.key == key)?.textValue;
    return CultureSelection(
      environmentId: idFor('culture_environment'),
      organisationId: idFor('culture_organisation'),
      upbringingId: idFor('culture_upbringing'),
      environmentSkillId: val(_k.cultureEnvironmentSkill),
      organisationSkillId: val(_k.cultureOrganisationSkill),
      upbringingSkillId: val(_k.cultureUpbringingSkill),
    );
  }

  // --- Career selections (career id, chosen skills/perks, incident) ---
  Future<void> saveCareerSelection({
    required String heroId,
    required String? careerId,
    List<String> chosenSkillIds = const <String>[],
    List<String> chosenPerkIds = const <String>[],
    String? incitingIncidentName,
  }) async {
    // Detect previous career to apply numeric grants only on change
    final values = await _db.getHeroValues(heroId);
    final previousCareerId =
        values.firstWhereOrNull((v) => v.key == _k.career)?.textValue;

    await _db.upsertHeroValue(
        heroId: heroId, key: _k.career, textValue: careerId);

    final allComps = await _db.getAllComponents();
    // Resolve granted skills from career definition by name
    final careerComp = allComps.firstWhereOrNull((c) => c.id == careerId);
    final grantedSkillNames = <String>{};
    int renownGrant = 0, wealthGrant = 0, ppGrant = 0;
    if (careerComp != null) {
      try {
        final data = jsonDecode(careerComp.dataJson) as Map<String, dynamic>;
        for (final s
            in (data['granted_skills'] as List?) ?? const <dynamic>[]) {
          grantedSkillNames.add(s.toString());
        }
        renownGrant = (data['renown'] as int?) ?? 0;
        wealthGrant = (data['wealth'] as int?) ?? 0;
        ppGrant = (data['project_points'] as int?) ?? 0;
      } catch (_) {}
    }
    final grantedSkillIds = allComps
        .where((c) =>
            c.type == 'skill' &&
            (grantedSkillNames.contains(c.name) ||
                grantedSkillNames.contains(c.id)))
        .map((c) => c.id)
        .toSet();

    // Merge skills and perks into HeroComponents, preserving existing
    final currentComps = await _db.getHeroComponents(heroId);
    final existingSkillIds = currentComps
        .where((c) => c.category == 'skill')
        .map((c) => c.componentId)
        .toSet();
    final existingPerkIds = currentComps
        .where((c) => c.category == 'perk')
        .map((c) => c.componentId)
        .toSet();
    final newSkillSet =
        existingSkillIds.union(chosenSkillIds.toSet()).union(grantedSkillIds);
    final newPerkSet = existingPerkIds.union(chosenPerkIds.toSet());
    await _db.setHeroComponents(
        heroId: heroId, category: 'skill', componentIds: newSkillSet.toList());
    await _db.setHeroComponents(
        heroId: heroId, category: 'perk', componentIds: newPerkSet.toList());

    // Persist chosen lists for preloading UI
    await _db.upsertHeroValue(
        heroId: heroId,
        key: _k.careerChosenSkills,
        jsonMap: {'list': chosenSkillIds});
    await _db.upsertHeroValue(
        heroId: heroId,
        key: _k.careerChosenPerks,
        jsonMap: {'list': chosenPerkIds});
    await _db.upsertHeroValue(
        heroId: heroId,
        key: _k.careerIncitingIncident,
        textValue: incitingIncidentName);

    // Apply numeric grants only when career changed
    if (careerId != null &&
        careerId.isNotEmpty &&
        previousCareerId != careerId) {
      int getInt(String key) =>
          values.firstWhereOrNull((v) => v.key == key)?.value ?? 0;
      final newRenown = getInt(_k.renown) + renownGrant;
      final newWealth = getInt(_k.wealth) + wealthGrant;
      final newPP = getInt(_k.projectPoints) + ppGrant;
      await _db.upsertHeroValue(
          heroId: heroId, key: _k.renown, value: newRenown);
      await _db.upsertHeroValue(
          heroId: heroId, key: _k.wealth, value: newWealth);
      await _db.upsertHeroValue(
          heroId: heroId, key: _k.projectPoints, value: newPP);
    }
  }

  Future<CareerSelection> loadCareerSelection(String heroId) async {
    final values = await _db.getHeroValues(heroId);
    final comps = await _db.getHeroComponents(heroId);
    String? getText(String key) =>
        values.firstWhereOrNull((v) => v.key == key)?.textValue;
    List<String> getList(String key) {
      final v = values.firstWhereOrNull((e) => e.key == key);
      if (v?.jsonValue == null && v?.textValue == null) return <String>[];
      try {
        final raw = v!.jsonValue ?? v.textValue!;
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
        if (decoded is Map && decoded['list'] is List) {
          return (decoded['list'] as List).map((e) => e.toString()).toList();
        }
      } catch (_) {}
      return <String>[];
    }

    String? idForCategory(String category) =>
        comps.firstWhereOrNull((e) => e.category == category)?.componentId;

    return CareerSelection(
      careerId: getText(_k.career) ?? idForCategory('career'),
      chosenSkillIds: getList(_k.careerChosenSkills),
      chosenPerkIds: getList(_k.careerChosenPerks),
      incitingIncidentName: getText(_k.careerIncitingIncident),
    );
  }

  /// Load a HeroModel by id from DB aggregating values and components.
  Future<HeroModel?> load(String heroId) async {
    final row = await (_db.select(_db.heroes)
          ..where((t) => t.id.equals(heroId)))
        .getSingleOrNull();
    if (row == null) return null;
    final values = await _db.getHeroValues(heroId);
    final comps = await _db.getHeroComponents(heroId);

    int getInt(String key, int def) {
      final v = values.firstWhereOrNull((e) => e.key == key);
      if (v == null) return def;
      return v.value ?? int.tryParse(v.textValue ?? '') ?? def;
    }

    String? getString(String key) {
      final v = values.firstWhereOrNull((e) => e.key == key);
      return v?.textValue;
    }

    List<String> jsonList(String key) {
      final v = values.firstWhereOrNull((e) => e.key == key);
      if (v?.jsonValue == null && v?.textValue == null) return <String>[];
      try {
        final raw = v!.jsonValue ?? v.textValue!;
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
        if (decoded is Map && decoded['list'] is List) {
          return (decoded['list'] as List).map((e) => e.toString()).toList();
        }
        return <String>[];
      } catch (_) {
        return <String>[];
      }
    }

    Map<String, int> jsonMapInt(String key) {
      final v = values.firstWhereOrNull((e) => e.key == key);
      if (v?.jsonValue == null) return <String, int>{};
      try {
        final map = jsonDecode(v!.jsonValue!) as Map<String, dynamic>;
        return map.map((k, v) =>
            MapEntry(k, (v is int) ? v : int.tryParse(v.toString()) ?? 0));
      } catch (_) {
        return <String, int>{};
      }
    }

    // Collect components by category
    List<String> compsBy(String category) => comps
        .where((e) => e.category == category)
        .map((e) => e.componentId)
        .toList();

    return HeroModel(
      id: row.id,
      name: row.name,
      className: getString(_k.className),
      subclass: getString(_k.subclass),
      level: getInt(_k.level, 1),
      ancestry: getString(_k.ancestry),
      career: getString(_k.career),
      deityId: getString(_k.deity),
      domain: getString(_k.domain),
      victories: getInt(_k.victories, 0),
      exp: getInt(_k.exp, 0),
      wealth: getInt(_k.wealth, 0),
      renown: getInt(_k.renown, 0),
      might: getInt(_k.might, 0),
      agility: getInt(_k.agility, 0),
      reason: getInt(_k.reason, 0),
      intuition: getInt(_k.intuition, 0),
      presence: getInt(_k.presence, 0),
      size: getInt(_k.size, 0),
      speed: getInt(_k.speed, 0),
      disengage: getInt(_k.disengage, 0),
      stability: getInt(_k.stability, 0),
      staminaCurrent: getInt(_k.staminaCurrent, 0),
      staminaMax: getInt(_k.staminaMax, 0),
      staminaTemp: getInt(_k.staminaTemp, 0),
      windedValue: getInt(_k.windedValue, 0),
      dyingValue: getInt(_k.dyingValue, 0),
      recoveriesCurrent: getInt(_k.recoveriesCurrent, 0),
      recoveriesValue: getInt(_k.recoveriesValue, 0),
      recoveriesMax: getInt(_k.recoveriesMax, 0),
      heroicResource: getString(_k.heroicResource),
      heroicResourceCurrent: getInt(_k.heroicResourceCurrent, 0),
      surgesCurrent: getInt(_k.surgesCurrent, 0),
      immunities: jsonList(_k.immunities),
      weaknesses: jsonList(_k.weaknesses),
      potencyStrong: getString(_k.potencyStrong),
      potencyAverage: getString(_k.potencyAverage),
      potencyWeak: getString(_k.potencyWeak),
      conditions: jsonList(_k.conditions),
      classFeatures: compsBy('class_feature'),
      ancestryTraits: compsBy('ancestry_trait'),
      languages: compsBy('language'),
      skills: compsBy('skill'),
      perks: compsBy('perk'),
      projects: compsBy('project'),
      projectPoints: getInt(_k.projectPoints, 0),
      titles: compsBy('title'),
      abilities: compsBy('ability'),
      modifications: jsonMapInt(_k.modifications),
    );
  }

  /// Persist editable properties of a HeroModel back to DB.
  Future<void> save(HeroModel hero) async {
    await _db.renameHero(hero.id, hero.name);

    // Values (simple keys)
    Future<void> setInt(String key, int value) =>
        _db.upsertHeroValue(heroId: hero.id, key: key, value: value);
    Future<void> setText(String key, String? value) =>
        _db.upsertHeroValue(heroId: hero.id, key: key, textValue: value);
    Future<void> setJsonMap(String key, Map<String, dynamic>? map) =>
        _db.upsertHeroValue(heroId: hero.id, key: key, jsonMap: map);

    await Future.wait([
      // basics
      setText(_k.className, hero.className),
      setText(_k.subclass, hero.subclass),
      setInt(_k.level, hero.level),
      setText(_k.ancestry, hero.ancestry),
      setText(_k.career, hero.career),
      setText(_k.deity, hero.deityId),
      setText(_k.domain, hero.domain),
      // victories & exp
      setInt(_k.victories, hero.victories),
      setInt(_k.exp, hero.exp),
      setInt(_k.wealth, hero.wealth),
      setInt(_k.renown, hero.renown),
      // stats
      setInt(_k.might, hero.might),
      setInt(_k.agility, hero.agility),
      setInt(_k.reason, hero.reason),
      setInt(_k.intuition, hero.intuition),
      setInt(_k.presence, hero.presence),
      setInt(_k.size, hero.size),
      setInt(_k.speed, hero.speed),
      setInt(_k.disengage, hero.disengage),
      setInt(_k.stability, hero.stability),
      // stamina
      setInt(_k.staminaCurrent, hero.staminaCurrent),
      setInt(_k.staminaMax, hero.staminaMax),
      setInt(_k.staminaTemp, hero.staminaTemp),
      setInt(_k.windedValue, hero.windedValue),
      setInt(_k.dyingValue, hero.dyingValue),
      setInt(_k.recoveriesCurrent, hero.recoveriesCurrent),
      setInt(_k.recoveriesValue, hero.recoveriesValue),
      setInt(_k.recoveriesMax, hero.recoveriesMax),
      // hero resource
      setText(_k.heroicResource, hero.heroicResource),
      setInt(_k.heroicResourceCurrent, hero.heroicResourceCurrent),
      // surges
      setInt(_k.surgesCurrent, hero.surgesCurrent),
      // arrays
      setJsonMap(_k.immunities, {'list': hero.immunities}),
      setJsonMap(_k.weaknesses, {'list': hero.weaknesses}),
      setJsonMap(_k.conditions, {'list': hero.conditions}),
      // potencies
      setText(_k.potencyStrong, hero.potencyStrong),
      setText(_k.potencyAverage, hero.potencyAverage),
      setText(_k.potencyWeak, hero.potencyWeak),
      // projects meta
      setInt(_k.projectPoints, hero.projectPoints),
      // modifications map
      setJsonMap(
          _k.modifications, hero.modifications.map((k, v) => MapEntry(k, v))),
    ]);

    // Components by category
    await _db.setHeroComponents(
        heroId: hero.id,
        category: 'class_feature',
        componentIds: hero.classFeatures);
    await _db.setHeroComponents(
        heroId: hero.id,
        category: 'ancestry_trait',
        componentIds: hero.ancestryTraits);
    await _db.setHeroComponents(
        heroId: hero.id, category: 'language', componentIds: hero.languages);
    await _db.setHeroComponents(
        heroId: hero.id, category: 'skill', componentIds: hero.skills);
    await _db.setHeroComponents(
        heroId: hero.id, category: 'perk', componentIds: hero.perks);
    await _db.setHeroComponents(
        heroId: hero.id, category: 'project', componentIds: hero.projects);
    await _db.setHeroComponents(
        heroId: hero.id, category: 'title', componentIds: hero.titles);
    await _db.setHeroComponents(
        heroId: hero.id, category: 'ability', componentIds: hero.abilities);
  }

  /// Export a hero aggregate to a portable JSON string.
  Future<String?> exportHero(String heroId) async {
    final model = await load(heroId);
    if (model == null) return null;
    return model.toExportString();
  }

  /// Import a hero from export JSON, creating a new hero id.
  Future<String> importHero(String exportJsonString) async {
    final map = jsonDecode(exportJsonString) as Map<String, dynamic>;
    final model = HeroModel.fromExportJson(map);
    final newId = await createHero(
        name: model.name.isEmpty ? 'Imported Hero' : model.name);
    final toSave = model..name = model.name; // keep same name
    // rebind id
    final rebound = HeroModel(
      id: newId,
      name: toSave.name,
      className: toSave.className,
      subclass: toSave.subclass,
      level: toSave.level,
      ancestry: toSave.ancestry,
      career: toSave.career,
      deityId: toSave.deityId,
      domain: toSave.domain,
      victories: toSave.victories,
      exp: toSave.exp,
      wealth: toSave.wealth,
      renown: toSave.renown,
      might: toSave.might,
      agility: toSave.agility,
      reason: toSave.reason,
      intuition: toSave.intuition,
      presence: toSave.presence,
      size: toSave.size,
      speed: toSave.speed,
      disengage: toSave.disengage,
      stability: toSave.stability,
      staminaCurrent: toSave.staminaCurrent,
      staminaMax: toSave.staminaMax,
      staminaTemp: toSave.staminaTemp,
      windedValue: toSave.windedValue,
      dyingValue: toSave.dyingValue,
      recoveriesCurrent: toSave.recoveriesCurrent,
      recoveriesValue: toSave.recoveriesValue,
      recoveriesMax: toSave.recoveriesMax,
      heroicResource: toSave.heroicResource,
      heroicResourceCurrent: toSave.heroicResourceCurrent,
      surgesCurrent: toSave.surgesCurrent,
      immunities: List.of(toSave.immunities),
      weaknesses: List.of(toSave.weaknesses),
      potencyStrong: toSave.potencyStrong,
      potencyAverage: toSave.potencyAverage,
      potencyWeak: toSave.potencyWeak,
      conditions: List.of(toSave.conditions),
      classFeatures: List.of(toSave.classFeatures),
      ancestryTraits: List.of(toSave.ancestryTraits),
      languages: List.of(toSave.languages),
      skills: List.of(toSave.skills),
      perks: List.of(toSave.perks),
      projects: List.of(toSave.projects),
      projectPoints: toSave.projectPoints,
      titles: List.of(toSave.titles),
      abilities: List.of(toSave.abilities),
      modifications: Map.of(toSave.modifications),
    );
    await save(rebound);
    return newId;
  }
}

class CultureSelection {
  final String? environmentId;
  final String? organisationId;
  final String? upbringingId;
  final String? environmentSkillId;
  final String? organisationSkillId;
  final String? upbringingSkillId;
  const CultureSelection({
    this.environmentId,
    this.organisationId,
    this.upbringingId,
    this.environmentSkillId,
    this.organisationSkillId,
    this.upbringingSkillId,
  });
}

class CareerSelection {
  final String? careerId;
  final List<String> chosenSkillIds;
  final List<String> chosenPerkIds;
  final String? incitingIncidentName;
  const CareerSelection({
    this.careerId,
    this.chosenSkillIds = const <String>[],
    this.chosenPerkIds = const <String>[],
    this.incitingIncidentName,
  });
}

/// Centralized list of keys used in HeroValues
class _HeroKeys {
  const _HeroKeys._();
  final String className = 'basics.className';
  final String subclass = 'basics.subclass';
  final String level = 'basics.level';
  final String ancestry = 'basics.ancestry';
  final String career = 'basics.career';
  final String deity = 'faith.deity';
  final String domain = 'faith.domain';
  // ancestry extras
  final String ancestrySelectedTraits = 'ancestry.selected_traits';
  final String ancestrySignature = 'ancestry.signature_name';

  final String victories = 'score.victories';
  final String exp = 'score.exp';
  final String wealth = 'score.wealth';
  final String renown = 'score.renown';

  final String might = 'stats.might';
  final String agility = 'stats.agility';
  final String reason = 'stats.reason';
  final String intuition = 'stats.intuition';
  final String presence = 'stats.presence';
  final String size = 'stats.size';
  final String speed = 'stats.speed';
  final String disengage = 'stats.disengage';
  final String stability = 'stats.stability';

  final String staminaCurrent = 'stamina.current';
  final String staminaMax = 'stamina.max';
  final String staminaTemp = 'stamina.temp';
  final String windedValue = 'stamina.winded';
  final String dyingValue = 'stamina.dying';
  final String recoveriesCurrent = 'recoveries.current';
  final String recoveriesValue = 'recoveries.value';
  final String recoveriesMax = 'recoveries.max';

  final String heroicResource = 'heroic.resource';
  final String heroicResourceCurrent = 'heroic.current';

  final String surgesCurrent = 'surges.current';

  final String immunities = 'resistances.immunities';
  final String weaknesses = 'resistances.weaknesses';

  final String potencyStrong = 'potency.strong';
  final String potencyAverage = 'potency.average';
  final String potencyWeak = 'potency.weak';

  final String conditions = 'conditions.list';

  final String projectPoints = 'projects.points';

  final String modifications = 'mods.map';

  // culture-chosen skill keys
  final String cultureEnvironmentSkill = 'culture.environment.skill';
  final String cultureOrganisationSkill = 'culture.organisation.skill';
  final String cultureUpbringingSkill = 'culture.upbringing.skill';

  // career selections
  final String careerChosenSkills = 'career.chosen_skills';
  final String careerChosenPerks = 'career.chosen_perks';
  final String careerIncitingIncident = 'career.inciting_incident';
}
