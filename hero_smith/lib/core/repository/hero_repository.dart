import 'dart:convert';

import 'package:collection/collection.dart';

import '../db/app_database.dart' as db;
import '../models/hero_model.dart';

class HeroRepository {
  HeroRepository(this._db);
  final db.AppDatabase _db;

  // Keys mapping for HeroValues
  static const _k = _HeroKeys._();

  Future<String> createHero({required String name}) => _db.createHero(name: name);

  Stream<List<db.Heroe>> watchAllHeroes() => _db.watchAllHeroes();
  Future<List<db.Heroe>> getAllHeroes() => _db.getAllHeroes();

  /// Load a HeroModel by id from DB aggregating values and components.
  Future<HeroModel?> load(String heroId) async {
    final row = await (_db.select(_db.heroes)..where((t) => t.id.equals(heroId))).getSingleOrNull();
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
        return map.map((k, v) => MapEntry(k, (v is int) ? v : int.tryParse(v.toString()) ?? 0));
      } catch (_) {
        return <String, int>{};
      }
    }

    // Collect components by category
    List<String> compsBy(String category) =>
        comps.where((e) => e.category == category).map((e) => e.componentId).toList();

    return HeroModel(
      id: row.id,
      name: row.name,
  className: getString(_k.className),
  subclass: getString(_k.subclass),
  level: getInt(_k.level, 1),
  ancestry: getString(_k.ancestry),
  career: getString(_k.career),
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
  setJsonMap(_k.modifications, hero.modifications.map((k, v) => MapEntry(k, v))),
    ]);

    // Components by category
    await _db.setHeroComponents(heroId: hero.id, category: 'class_feature', componentIds: hero.classFeatures);
    await _db.setHeroComponents(heroId: hero.id, category: 'ancestry_trait', componentIds: hero.ancestryTraits);
    await _db.setHeroComponents(heroId: hero.id, category: 'language', componentIds: hero.languages);
    await _db.setHeroComponents(heroId: hero.id, category: 'skill', componentIds: hero.skills);
    await _db.setHeroComponents(heroId: hero.id, category: 'perk', componentIds: hero.perks);
    await _db.setHeroComponents(heroId: hero.id, category: 'project', componentIds: hero.projects);
    await _db.setHeroComponents(heroId: hero.id, category: 'title', componentIds: hero.titles);
    await _db.setHeroComponents(heroId: hero.id, category: 'ability', componentIds: hero.abilities);
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
    final newId = await createHero(name: model.name.isEmpty ? 'Imported Hero' : model.name);
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

/// Centralized list of keys used in HeroValues
class _HeroKeys {
  const _HeroKeys._();
  final String className = 'basics.className';
  final String subclass = 'basics.subclass';
  final String level = 'basics.level';
  final String ancestry = 'basics.ancestry';
  final String career = 'basics.career';

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
}
