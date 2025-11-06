import 'dart:convert';
import 'app_database.dart';
import '../seed/asset_seeder.dart';

/// Utility methods for database maintenance
class DatabaseMaintenance {
  /// Clear all ability components from the database
  /// Useful when switching between data formats to avoid duplicates
  static Future<void> clearAbilities(AppDatabase db) async {
    await (db.delete(db.components)
          ..where((c) => c.type.equals('ability')))
        .go();
  }

  /// Clear all components and reseed from assets
  /// WARNING: This will delete all seed data
  static Future<void> clearAndReseed(AppDatabase db) async {
    await (db.delete(db.components)
          ..where((c) => c.source.equals('seed')))
        .go();
    await AssetSeeder.seedFromManifestIfEmpty(db);
  }

  /// Clear only duplicate abilities (keeps one copy of each name)
  static Future<void> removeDuplicateAbilities(AppDatabase db) async {
    // Get all abilities
    final allAbilities = await (db.select(db.components)
          ..where((c) => c.type.equals('ability')))
        .get();

    // Group by name
    final byName = <String, List<Component>>{};
    for (final ability in allAbilities) {
      byName.putIfAbsent(ability.name, () => []).add(ability);
    }

    // For each name with duplicates, keep the simplified version
    for (final entry in byName.entries) {
      if (entry.value.length <= 1) continue;

      // Find simplified version (has 'resource' field as string in dataJson)
      Component? simplified;
      final toDelete = <Component>[];

      for (final ability in entry.value) {
        final dataJson = ability.dataJson;
        final data = jsonDecode(dataJson);
        final hasSimplifiedResource = data['resource'] is String;
        
        if (hasSimplifiedResource && simplified == null) {
          simplified = ability; // Keep this one
        } else {
          toDelete.add(ability); // Mark for deletion
        }
      }

      // If no simplified version found, keep the first one
      if (simplified == null && toDelete.isNotEmpty) {
        simplified = toDelete.removeAt(0);
      }

      // Delete duplicates
      for (final ability in toDelete) {
        await (db.delete(db.components)
              ..where((c) => c.id.equals(ability.id)))
            .go();
      }
    }
  }
}
