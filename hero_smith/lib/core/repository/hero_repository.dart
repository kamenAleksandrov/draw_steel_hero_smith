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

    int _getInt(String key, int def) {
      final v = values.firstWhereOrNull((e) => e.key == key);
      if (v == null) return def;
      return v.value ?? int.tryParse(v.textValue ?? '') ?? def;
    }

    String? _getString(String key) {
      final v = values.firstWhereOrNull((e) => e.key == key);
      return v?.textValue;
    }

    List<String> _jsonList(String key) {
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

    Map<String, int> _jsonMapInt(String key) {
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
  className: _getString(_k.className),
  subclass: _getString(_k.subclass),
  level: _getInt(_k.level, 1),
  ancestry: _getString(_k.ancestry),
  career: _getString(_k.career),
  victories: _getInt(_k.victories, 0),
  exp: _getInt(_k.exp, 0),
  wealth: _getInt(_k.wealth, 0),
  renown: _getInt(_k.renown, 0),
  might: _getInt(_k.might, 0),
  agility: _getInt(_k.agility, 0),
  reason: _getInt(_k.reason, 0),
  intuition: _getInt(_k.intuition, 0),
  presence: _getInt(_k.presence, 0),
  size: _getInt(_k.size, 0),
  speed: _getInt(_k.speed, 0),
  disengage: _getInt(_k.disengage, 0),
  stability: _getInt(_k.stability, 0),
  staminaCurrent: _getInt(_k.staminaCurrent, 0),
  staminaMax: _getInt(_k.staminaMax, 0),
  staminaTemp: _getInt(_k.staminaTemp, 0),
  windedValue: _getInt(_k.windedValue, 0),
  dyingValue: _getInt(_k.dyingValue, 0),
  recoveriesCurrent: _getInt(_k.recoveriesCurrent, 0),
  recoveriesValue: _getInt(_k.recoveriesValue, 0),
  recoveriesMax: _getInt(_k.recoveriesMax, 0),
  heroicResource: _getString(_k.heroicResource),
  heroicResourceCurrent: _getInt(_k.heroicResourceCurrent, 0),
  surgesCurrent: _getInt(_k.surgesCurrent, 0),
      immunities: _jsonList(_k.immunities),
      weaknesses: _jsonList(_k.weaknesses),
  potencyStrong: _getString(_k.potencyStrong),
  potencyAverage: _getString(_k.potencyAverage),
  potencyWeak: _getString(_k.potencyWeak),
      conditions: _jsonList(_k.conditions),
      classFeatures: compsBy('class_feature'),
      ancestryTraits: compsBy('ancestry_trait'),
      languages: compsBy('language'),
      skills: compsBy('skill'),
      perks: compsBy('perk'),
      projects: compsBy('project'),
  projectPoints: _getInt(_k.projectPoints, 0),
      titles: compsBy('title'),
      abilities: compsBy('ability'),
      modifications: _jsonMapInt(_k.modifications),
    );
  }

  /// Persist editable properties of a HeroModel back to DB.
  Future<void> save(HeroModel hero) async {
    await _db.renameHero(hero.id, hero.name);

    // Values (simple keys)
    Future<void> _setInt(String key, int value) =>
        _db.upsertHeroValue(heroId: hero.id, key: key, value: value);
    Future<void> _setText(String key, String? value) =>
        _db.upsertHeroValue(heroId: hero.id, key: key, textValue: value);
  Future<void> _setJsonMap(String key, Map<String, dynamic>? map) =>
    _db.upsertHeroValue(heroId: hero.id, key: key, jsonMap: map);

    await Future.wait([
      // basics
      _setText(_k.className, hero.className),
      _setText(_k.subclass, hero.subclass),
      _setInt(_k.level, hero.level),
      _setText(_k.ancestry, hero.ancestry),
      _setText(_k.career, hero.career),
      // victories & exp
      _setInt(_k.victories, hero.victories),
      _setInt(_k.exp, hero.exp),
      _setInt(_k.wealth, hero.wealth),
      _setInt(_k.renown, hero.renown),
      // stats
      _setInt(_k.might, hero.might),
      _setInt(_k.agility, hero.agility),
      _setInt(_k.reason, hero.reason),
      _setInt(_k.intuition, hero.intuition),
      _setInt(_k.presence, hero.presence),
      _setInt(_k.size, hero.size),
      _setInt(_k.speed, hero.speed),
      _setInt(_k.disengage, hero.disengage),
      _setInt(_k.stability, hero.stability),
      // stamina
      _setInt(_k.staminaCurrent, hero.staminaCurrent),
      _setInt(_k.staminaMax, hero.staminaMax),
      _setInt(_k.staminaTemp, hero.staminaTemp),
      _setInt(_k.windedValue, hero.windedValue),
      _setInt(_k.dyingValue, hero.dyingValue),
      _setInt(_k.recoveriesCurrent, hero.recoveriesCurrent),
      _setInt(_k.recoveriesValue, hero.recoveriesValue),
      _setInt(_k.recoveriesMax, hero.recoveriesMax),
      // hero resource
      _setText(_k.heroicResource, hero.heroicResource),
      _setInt(_k.heroicResourceCurrent, hero.heroicResourceCurrent),
      // surges
      _setInt(_k.surgesCurrent, hero.surgesCurrent),
      // arrays
  _setJsonMap(_k.immunities, {'list': hero.immunities}),
  _setJsonMap(_k.weaknesses, {'list': hero.weaknesses}),
  _setJsonMap(_k.conditions, {'list': hero.conditions}),
      // potencies
      _setText(_k.potencyStrong, hero.potencyStrong),
      _setText(_k.potencyAverage, hero.potencyAverage),
      _setText(_k.potencyWeak, hero.potencyWeak),
      // projects meta
      _setInt(_k.projectPoints, hero.projectPoints),
      // modifications map
  _setJsonMap(_k.modifications, hero.modifications.map((k, v) => MapEntry(k, v))),
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
