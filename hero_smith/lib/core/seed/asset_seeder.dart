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
      // Only seed when DB file is newly created (did not pre-exist).
      // This avoids reseeding on every startup even if tables are empty due to manual wipes.
      if (AppDatabase.databasePreexisted) {
        return;
      }

      final assets = await discoverDataJsonAssets();
      // print('DEBUG: Found ${assets.length} assets: $assets');

      final batchOps = <ComponentsCompanion>[];
      for (final path in assets) {
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
}
