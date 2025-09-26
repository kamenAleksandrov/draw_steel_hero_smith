import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../db/app_database.dart';

/// Handles discovering JSON assets under data/ and seeding the database.
class AssetSeeder {
  /// Discover all JSON assets under data/ via AssetManifest
  static Future<List<String>> discoverDataJsonAssets() async {
    final manifest = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> assets = jsonDecode(manifest);
    return assets.keys
        .where((k) => k.startsWith('data/') && k.endsWith('.json'))
        .toList();
  }

  /// Seed once from assets if the database is empty. No incremental seeding.
  static Future<void> seedFromManifestIfEmpty(AppDatabase db) async {
    try {
      final assets = await discoverDataJsonAssets();
      if (AppDatabase.databasePreexisted) {
        await _seedTypeIfMissing(
          db: db,
          assets: assets,
          type: 'class',
          pathPredicate: (path) =>
              path.startsWith('data/classes_levels_and_stats/'),
        );
        return;
      }

      final batchOps = await _buildSeedBatch(assets);

      if (batchOps.isEmpty) return;
      await db.batch((b) {
        for (final op in batchOps) {
          b.insert(db.components, op, mode: InsertMode.insertOrReplace);
        }
      });
      // print('DEBUG: Seeding completed');
    } catch (e) {
      // print('DEBUG: Error in seedFromManifestIfEmpty: $e');
      rethrow;
    }
  }

  static Future<List<ComponentsCompanion>> _buildSeedBatch(
      Iterable<String> assetPaths) async {
    final batchOps = <ComponentsCompanion>[];
    for (final path in assetPaths) {
      final raw = await rootBundle.loadString(path);
      final decoded = jsonDecode(raw);
      Iterable<Map<String, dynamic>> items;
      if (decoded is List) {
        items = decoded.cast<Map>().map((e) => Map<String, dynamic>.from(e));
      } else if (decoded is Map<String, dynamic>) {
        items = [Map<String, dynamic>.from(decoded)];
      } else {
        continue;
      }

      for (final map in items) {
        final work = Map<String, dynamic>.from(map);
        final id = _popComponentId(work);
        if (id == null || id.isEmpty) continue;

        String type;
        if (path.contains('/abilities/') ||
            path.startsWith('data/abilities/')) {
          // Preserve action label if the source used a generic 'type' field
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
        batchOps.add(
          ComponentsCompanion.insert(
            id: id,
            type: type,
            name: name,
            dataJson: Value(dataJson),
            source: const Value('seed'),
            parentId: const Value(null),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      }
    }
    return batchOps;
  }

  static String? _popComponentId(Map<String, dynamic> source) {
    const candidateKeys = [
      'id',
      'componentId',
      'classId',
      'abilityId',
      'featureId',
    ];
    for (final key in candidateKeys) {
      final value = source.remove(key);
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  static Future<void> _seedTypeIfMissing({
    required AppDatabase db,
    required List<String> assets,
    required String type,
    required bool Function(String path) pathPredicate,
  }) async {
    final existing = await (db.select(db.components)
          ..where((c) => c.type.equals(type)))
        .get();
    if (existing.isNotEmpty) return;
    final filtered = assets.where(pathPredicate).toList();
    if (filtered.isEmpty) return;
    final batchOps = await _buildSeedBatch(filtered);
    if (batchOps.isEmpty) return;
    await db.batch((b) {
      for (final op in batchOps) {
        b.insert(db.components, op, mode: InsertMode.insertOrReplace);
      }
    });
  }
}
