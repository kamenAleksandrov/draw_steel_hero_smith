import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
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
  TextColumn get classComponentId =>
      text().nullable().references(Components, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {id};
}

// HeroComponents table removed - all data now stored in HeroValues

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
  HeroValues,
  MetaEntries,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase._internal() : super(_openConnection());
  static final AppDatabase instance = AppDatabase._internal();
  // Indicates whether the database file existed before this process opened it.
  // This is set during database path resolution and read by the seeder to
  // avoid reseeding when the DB file already exists (even if it's empty).
  static bool databasePreexisted = false;

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            // Migration from schema version 1 to 2
            // Move data from HeroComponents to HeroValues
            await _migrateHeroComponentsToValues();
          }
        },
      );

  /// Migrate hero components data to hero values (schema v1 -> v2)
  Future<void> _migrateHeroComponentsToValues() async {
    try {
      // Check if heroComponents table exists
      final result = await customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='hero_components'",
      ).getSingleOrNull();

      if (result != null) {
        // Fetch all hero components
        final components = await customSelect(
          'SELECT hero_id, component_id, category FROM hero_components',
        ).get();

        // Group by heroId and category
        final Map<String, Map<String, List<String>>> grouped = {};
        for (final row in components) {
          final heroId = row.read<String>('hero_id');
          final componentId = row.read<String>('component_id');
          final category = row.read<String>('category');

          grouped.putIfAbsent(heroId, () => {});
          grouped[heroId]!.putIfAbsent(category, () => []);
          grouped[heroId]![category]!.add(componentId);
        }

        // Insert into HeroValues
        for (final heroId in grouped.keys) {
          for (final category in grouped[heroId]!.keys) {
            final componentIds = grouped[heroId]![category]!;
            
            // For single-item categories, store as textValue
            // For multi-item categories, store as JSON array
            if (componentIds.length == 1 && 
                (category == 'culture_environment' || 
                 category == 'culture_organisation' || 
                 category == 'culture_upbringing' ||
                 category == 'ancestry' ||
                 category == 'career' ||
                 category == 'complication')) {
              await upsertHeroValue(
                heroId: heroId,
                key: 'component.$category',
                textValue: componentIds.first,
              );
            } else {
              // Store as JSON array for languages, skills, etc.
              await upsertHeroValue(
                heroId: heroId,
                key: 'component.$category',
                jsonMap: {'ids': componentIds},
              );
            }
          }
        }

        // Drop the old table
        await customStatement('DROP TABLE IF EXISTS hero_components');
      }
    } catch (e) {
      // If migration fails, log it but don't crash
      print('Migration warning: $e');
    }
  }

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
    final existing = await (select(components)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
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
  Stream<List<Component>> watchComponentsByType(String type) =>
      (select(components)..where((c) => c.type.equals(type))).watch();

  Future<bool> deleteComponent(String id) async {
    final count =
        await (delete(components)..where((c) => c.id.equals(id))).go();
    return count > 0;
  }

  // --- Meta helpers (simple key-value store) ---
  Future<String?> getMeta(String key) async {
    final row = await (select(metaEntries)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setMeta(String key, String value) async {
    final existing = await (select(metaEntries)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    if (existing == null) {
      await into(metaEntries)
          .insert(MetaEntriesCompanion.insert(key: key, value: value));
    } else {
      await (update(metaEntries)..where((t) => t.key.equals(key)))
          .write(MetaEntriesCompanion(value: Value(value)));
    }
  }

  /// Atomically increment a numeric meta counter and return the new value.
  Future<int> nextSequence(String seqKey) async {
    return transaction(() async {
      final currentStr = await getMeta(seqKey);
      final current = int.tryParse(currentStr ?? '') ?? 0;
      final next = current + 1;
      await setMeta(seqKey, next.toString());
      return next;
    });
  }

  // --- Heroes CRUD helpers ---
  /// Create a hero with an incremental id. The id format is H0001, H0002, ...
  Future<String> createHero({required String name}) async {
    final n = await nextSequence('hero_id_seq');
    final id = 'H${n.toString().padLeft(4, '0')}';
    final now = DateTime.now();
    await into(heroes).insert(
      HeroesCompanion.insert(
        id: id,
        name: name,
        classComponentId: const Value(null),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
      mode: InsertMode.insertOrAbort,
    );
    return id;
  }

  Future<void> renameHero(String heroId, String newName) async {
    await (update(heroes)..where((t) => t.id.equals(heroId))).write(
      HeroesCompanion(
        name: Value(newName),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<Heroe>> getAllHeroes() => select(heroes).get();
  Stream<List<Heroe>> watchAllHeroes() => select(heroes).watch();

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

  Future<List<HeroValue>> getHeroValues(String heroId) {
    return (select(heroValues)..where((t) => t.heroId.equals(heroId))).get();
  }

  Stream<List<HeroValue>> watchHeroValues(String heroId) {
    return (select(heroValues)..where((t) => t.heroId.equals(heroId))).watch();
  }

  /// Get component IDs for a specific category (replaces getHeroComponents)
  Future<List<String>> getHeroComponentIds(String heroId, String category) async {
    final key = 'component.$category';
    final row = await (select(heroValues)
          ..where((t) => t.heroId.equals(heroId) & t.key.equals(key)))
        .getSingleOrNull();

    if (row == null) return [];

    // Check if it's a single ID stored as textValue
    if (row.textValue != null && row.textValue!.isNotEmpty) {
      return [row.textValue!];
    }

    // Check if it's stored as JSON array
    if (row.jsonValue != null) {
      try {
        final decoded = jsonDecode(row.jsonValue!);
        if (decoded is Map && decoded['ids'] is List) {
          return (decoded['ids'] as List).map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    return [];
  }

  /// Set component IDs for a specific category (replaces setHeroComponents)
  Future<void> setHeroComponentIds({
    required String heroId,
    required String category,
    required List<String> componentIds,
  }) async {
    final key = 'component.$category';

    if (componentIds.isEmpty) {
      // Remove the entry if no components
      await (delete(heroValues)
            ..where((t) => t.heroId.equals(heroId) & t.key.equals(key)))
          .go();
      return;
    }

    // For single-item categories, store as textValue
    if (componentIds.length == 1 &&
        (category == 'culture_environment' ||
            category == 'culture_organisation' ||
            category == 'culture_upbringing' ||
            category == 'ancestry' ||
            category == 'career' ||
            category == 'complication')) {
      await upsertHeroValue(
        heroId: heroId,
        key: key,
        textValue: componentIds.first,
      );
    } else {
      // Store as JSON array for languages, skills, etc.
      await upsertHeroValue(
        heroId: heroId,
        key: key,
        jsonMap: {'ids': componentIds},
      );
    }
  }

  /// Add a single component ID to a category (replaces addHeroComponent)
  Future<void> addHeroComponentId({
    required String heroId,
    required String componentId,
    required String category,
  }) async {
    final existing = await getHeroComponentIds(heroId, category);
    if (!existing.contains(componentId)) {
      await setHeroComponentIds(
        heroId: heroId,
        category: category,
        componentIds: [...existing, componentId],
      );
    }
  }

  Future<void> deleteHero(String heroId) async {
    await transaction(() async {
      await (delete(heroValues)..where((t) => t.heroId.equals(heroId))).go();
      await (delete(heroes)..where((t) => t.id.equals(heroId))).go();
    });
  }

  // Deprecated methods - kept for backwards compatibility during transition
  @Deprecated('Use getHeroComponentIds instead')
  Future<List<Map<String, String>>> getHeroComponents(String heroId) async {
    // Return all component entries as a list of maps
    final values = await getHeroValues(heroId);
    final result = <Map<String, String>>[];
    
    for (final value in values) {
      if (value.key.startsWith('component.')) {
        final category = value.key.substring('component.'.length);
        
        // Handle textValue (single component)
        if (value.textValue != null && value.textValue!.isNotEmpty) {
          result.add({
            'componentId': value.textValue!,
            'category': category,
          });
        }
        
        // Handle jsonValue (multiple components)
        if (value.jsonValue != null) {
          try {
            final decoded = jsonDecode(value.jsonValue!);
            if (decoded is Map && decoded['ids'] is List) {
              for (final id in decoded['ids']) {
                result.add({
                  'componentId': id.toString(),
                  'category': category,
                });
              }
            }
          } catch (_) {}
        }
      }
    }
    
    return result;
  }

  @Deprecated('Use setHeroComponentIds instead')
  Future<void> setHeroComponents({
    required String heroId,
    required String category,
    required List<String> componentIds,
  }) async {
    await setHeroComponentIds(
      heroId: heroId,
      category: category,
      componentIds: componentIds,
    );
  }

  @Deprecated('Use addHeroComponentId instead')
  Future<void> addHeroComponent({
    required String heroId,
    required String componentId,
    required String category,
  }) async {
    await addHeroComponentId(
      heroId: heroId,
      componentId: componentId,
      category: category,
    );
  }

  // Note: seeding logic has been extracted to core/seed/asset_seeder.dart

  // // Ensure abilities are present even if the DB already has other components.
  // Future<void> seedAbilitiesIncremental() async {
  //   final all = await AppDatabase.discoverDataJsonAssets();
  //   final abilityAssets = all.where((p) => p.startsWith('data/abilities/')).toList();
  //   if (abilityAssets.isEmpty) return;
  //   await upsertComponentsFromAssets(abilityAssets);
  // }

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
        AppDatabase.databasePreexisted = await file.exists();
        return file;
      }
    }
  }

  // Default: Use application support dir to keep files inside the app container.
  final supportDir = await getApplicationSupportDirectory();
  await supportDir.create(recursive: true);
  final file = File('${supportDir.path}/hero_smith.db');
  // Set the preexistence flag before the database is created/opened.
  AppDatabase.databasePreexisted = await file.exists();
  return file;
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
