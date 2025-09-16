import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Components extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get name => text()();
  TextColumn get dataJson => text().withDefault(const Constant('{}'))();
  // source of data: 'seed' | 'user' | 'import'
  TextColumn get source => text().withDefault(const Constant('seed'))();
  TextColumn get parentId => text().nullable().references(Components, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {id};
}

class Heroes extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get classComponentId => text().nullable().references(Components, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {id};
}

class HeroComponents extends Table {
  IntColumn get autoId => integer().autoIncrement()();
  TextColumn get heroId => text().references(Heroes, #id)();
  TextColumn get componentId => text().references(Components, #id)();
  TextColumn get category => text().withDefault(const Constant('generic'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class HeroValues extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get heroId => text().references(Heroes, #id)();
  TextColumn get key => text()();
  IntColumn get value => integer().nullable()();
  IntColumn get maxValue => integer().nullable()();
  RealColumn get doubleValue => real().nullable()();
  TextColumn get textValue => text().nullable()();
  TextColumn get jsonValue => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class MetaEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [
  Components,
  Heroes,
  HeroComponents,
  HeroValues,
  MetaEntries,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase._internal() : super(_openConnection());
  static final AppDatabase instance = AppDatabase._internal();

  @override
  int get schemaVersion => 1;

  // CRUD helpers for components
  Future<void> upsertComponentModel({
    required String id,
    required String type,
    required String name,
    required Map<String, dynamic> dataMap,
    String source = 'seed',
    String? parentId,
    DateTime? createdAtOverride,
  }) async {
    final existing = await (select(components)..where((c) => c.id.equals(id))).getSingleOrNull();
    final now = DateTime.now();
    await into(components).insert(
      ComponentsCompanion.insert(
        id: id,
        type: type,
        name: name,
        dataJson: Value(jsonEncode(dataMap)),
        source: Value(existing?.source ?? source),
        parentId: Value(parentId),
        createdAt: Value(existing?.createdAt ?? createdAtOverride ?? now),
        updatedAt: Value(now),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<List<Component>> getAllComponents() => select(components).get();
  Stream<List<Component>> watchAllComponents() => select(components).watch();
  Stream<List<Component>> watchComponentsByType(String type) => (select(components)..where((c) => c.type.equals(type))).watch();

  Future<bool> deleteComponent(String id) async {
    final count = await (delete(components)..where((c) => c.id.equals(id))).go();
    return count > 0;
  }

  Future<void> addHeroComponent({
    required String heroId,
    required String componentId,
    required String category,
  }) async {
    await into(heroComponents).insert(
      HeroComponentsCompanion.insert(
        heroId: heroId,
        componentId: componentId,
        category: Value(category),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<void> upsertHeroValue({
    required String heroId,
    required String key,
    int? value,
    int? maxValue,
    double? doubleValue,
    String? textValue,
    Map<String, dynamic>? jsonMap,
  }) async {
    final existing = await (select(heroValues)
          ..where((t) => t.heroId.equals(heroId) & t.key.equals(key)))
        .getSingleOrNull();
    final now = DateTime.now();
    final jsonStr = jsonMap == null ? null : jsonEncode(jsonMap);
    if (existing == null) {
      await into(heroValues).insert(
        HeroValuesCompanion.insert(
          heroId: heroId,
          key: key,
          value: Value(value),
          maxValue: Value(maxValue),
          doubleValue: Value(doubleValue),
          textValue: Value(textValue),
          jsonValue: Value(jsonStr),
          updatedAt: Value(now),
        ),
      );
    } else {
      await (update(heroValues)..where((t) => t.id.equals(existing.id))).write(
        HeroValuesCompanion(
          value: Value(value),
          maxValue: Value(maxValue),
          doubleValue: Value(doubleValue),
          textValue: Value(textValue),
          jsonValue: Value(jsonStr),
          updatedAt: Value(now),
        ),
      );
    }
  }

  // Seeding from assets when empty
  Future<void> seedComponentsIfEmpty(List<String> assetJsonPaths) async {
    final count = await customSelect('SELECT COUNT(id) as c FROM components', readsFrom: {components})
        .map((row) => row.data['c'] as int)
        .getSingle();
    if (count > 0) return;

    final batchOps = <ComponentsCompanion>[];
    for (final path in assetJsonPaths) {
      final raw = await rootBundle.loadString(path);
      final decoded = jsonDecode(raw);
      Iterable<Map<String, dynamic>> items;
      if (decoded is List) {
        items = decoded.cast<Map>().map((e) => Map<String, dynamic>.from(e));
      } else if (decoded is Map<String, dynamic>) {
        items = [decoded];
      } else {
        continue;
      }
      for (final map in items) {
        final work = Map<String, dynamic>.from(map);
        final id = work.remove('id') as String? ?? '';
        if (id.isEmpty) continue;
        final type = work.remove('type') as String? ?? 'unknown';
        final name = work.remove('name') as String? ?? '';
        final dataJson = jsonEncode(work);
        final now = DateTime.now();
        batchOps.add(ComponentsCompanion.insert(
          id: id,
          type: type,
          name: name,
          dataJson: Value(dataJson),
          source: const Value('seed'),
          parentId: const Value(null),
          createdAt: Value(now),
          updatedAt: Value(now),
        ));
      }
    }

    await batch((b) {
      for (final op in batchOps) {
        b.insert(components, op, mode: InsertMode.insertOrReplace);
      }
    });
  }

  // Discover all JSON assets under data/ via AssetManifest
  static Future<List<String>> discoverDataJsonAssets() async {
    final manifest = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> assets = jsonDecode(manifest);
    return assets.keys
        .where((k) => k.startsWith('data/') && k.endsWith('.json'))
        .toList();
  }

  Future<void> seedFromManifestIfEmpty() async {
    final assets = await AppDatabase.discoverDataJsonAssets();
    await seedComponentsIfEmpty(assets);
  }
}

// Open connection
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/hero_smith.db');
    final fileDb = NativeDatabase.createInBackground(file);
    return fileDb;
  });
}
