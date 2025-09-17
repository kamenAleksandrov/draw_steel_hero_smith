import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show kReleaseMode;
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
    print('DEBUG: Database has $count existing components');
    if (count > 0) {
      print('DEBUG: Skipping seed - database not empty');
      return;
    }
    print('DEBUG: Starting seed with ${assetJsonPaths.length} assets');

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
        String type;
        // For abilities assets, we store component type as 'ability'.
        if (path.contains('/abilities/') || path.startsWith('data/abilities/')) {
          // If the source data used a generic 'type' field for action label, preserve it under 'action_type'.
          final maybeAction = work.remove('type');
          if (maybeAction != null && work['action_type'] == null) {
            work['action_type'] = maybeAction;
          }
          type = 'ability';
        } else {
          type = work.remove('type') as String? ?? 'unknown';
        }
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
    try {
      final assets = await AppDatabase.discoverDataJsonAssets();
      print('DEBUG: Found ${assets.length} assets: $assets');
      await seedComponentsIfEmpty(assets);
      print('DEBUG: seedFromManifestIfEmpty completed successfully');
    } catch (e, stackTrace) {
      print('DEBUG: Error in seedFromManifestIfEmpty: $e');
      print('DEBUG: Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Upsert components from a set of asset JSON files (no emptiness check).
  Future<void> upsertComponentsFromAssets(List<String> assetJsonPaths) async {
    print('DEBUG: upsertComponentsFromAssets called with ${assetJsonPaths.length} paths');
    final batchOps = <ComponentsCompanion>[];
    for (final path in assetJsonPaths) {
      print('DEBUG: Processing asset: $path');
      try {
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
          String type;
          if (path.contains('/abilities/') || path.startsWith('data/abilities/')) {
            // For abilities, ignore the "type" field since it's just "ability" now
            work.remove('type');
            type = 'ability';
          } else {
            type = work.remove('type') as String? ?? 'unknown';
          }
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
      } catch (e) {
        print('DEBUG: Error processing asset $path: $e');
        continue;
      }
    }

    if (batchOps.isEmpty) {
      print('DEBUG: No batch operations to execute');
      return;
    }
    print('DEBUG: Executing ${batchOps.length} batch operations');
    await batch((b) {
      for (final op in batchOps) {
        b.insert(components, op, mode: InsertMode.insertOrReplace);
      }
    });
    print('DEBUG: Batch operations completed');
  }

  // Ensure abilities are present even if the DB already has other components.
  Future<void> seedAbilitiesIncremental() async {
    final all = await AppDatabase.discoverDataJsonAssets();
    final abilityAssets = all.where((p) => p.startsWith('data/abilities/')).toList();
    if (abilityAssets.isEmpty) return;
    await upsertComponentsFromAssets(abilityAssets);
  }

  // Expose the full path to the database file for diagnostics.
  static Future<String> databasePath() async {
    final file = await _getDatabaseFile();
    return file.path;
  }
}

// Open connection
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final file = await _getDatabaseFile();
    final fileDb = NativeDatabase.createInBackground(file);
    return fileDb;
  });
}

// Determine the DB file location inside the application support directory
// (an app-specific folder not visible to end users in Documents).
Future<File> _getDatabaseFile() async {
  // In Windows debug/profile builds, prefer writing the DB inside the project folder
  // so it's easy to find under version-controlled sources. We attempt to locate
  // the repo root by walking up to a directory containing pubspec.yaml.
  if (Platform.isWindows && !kReleaseMode) {
    final root = _findProjectRoot();
    if (root != null) {
      final dbDir = Directory('${root.path}/lib/core/db');
      if (await dbDir.exists()) {
        final file = File('${dbDir.path}/hero_smith.db');
        await dbDir.create(recursive: true);
        return file;
      }
    }
  }

  // Default: Use application support dir to keep files inside the app container.
  final supportDir = await getApplicationSupportDirectory();
  await supportDir.create(recursive: true);
  return File('${supportDir.path}/hero_smith.db');
}

// Attempt to locate the Flutter project root by walking upward from the
// current working directory until a pubspec.yaml is found.
Directory? _findProjectRoot() {
  var dir = Directory.current.absolute;
  // Walk up to 15 levels to be safe.
  for (var i = 0; i < 15; i++) {
    final pubspec = File('${dir.path}/pubspec.yaml');
    if (pubspec.existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return null;
}
