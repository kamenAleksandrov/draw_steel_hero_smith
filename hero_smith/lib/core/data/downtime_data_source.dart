import 'package:flutter/services.dart' show rootBundle;
import '../models/downtime.dart';

class DowntimeDataSource {
  static const _projectsPath = 'data/downtime/downtime_projects.json';
  static const _enhancementsPath = 'data/downtime/item_enhancements.json';
  static const _eventsPath = 'data/downtime/downtime_events.json';
  static const _fallbackEventsName = 'Crafting and Research Events';

  /// Public getter to expose the default/fallback events table name
  String get fallbackEventsName => _fallbackEventsName;

  /// Returns the expected events table name for a given entry, without loading tables
  String expectedEventsTableNameFor(DowntimeEntry entry) =>
      '${entry.name.trim()} Events';

  Future<List<DowntimeEntry>> loadProjects() async {
    final txt = await rootBundle.loadString(_projectsPath);
    final list = decodeJsonList(txt);
    return list
        .whereType<Map<String, dynamic>>()
        .map(DowntimeEntry.fromJson)
        .toList();
  }

  Future<List<DowntimeEntry>> loadEnhancements() async {
    final txt = await rootBundle.loadString(_enhancementsPath);
    final list = decodeJsonList(txt);
    return list
        .whereType<Map<String, dynamic>>()
        .map(DowntimeEntry.fromJson)
        .toList();
  }

  Future<List<EventTable>> loadEventTables() async {
    final txt = await rootBundle.loadString(_eventsPath);
    final list = decodeJsonList(txt);
    return list
        .whereType<Map<String, dynamic>>()
        .map(EventTable.fromJson)
        .toList();
  }

  Future<EventTable?> resolveEventsForEntry(DowntimeEntry entry) async {
    final tables = await loadEventTables();
    final wanted = '${entry.name.trim()} Events'.toLowerCase();
    final exact = tables.firstWhere(
      (t) => t.name.toLowerCase() == wanted,
      orElse: () => EventTable(id: '', name: '', events: const []),
    );
    if (exact.name.isNotEmpty) return exact;

    return tables.firstWhere(
      (t) => t.name == _fallbackEventsName,
      orElse: () => EventTable(
          id: _fallbackEventsName, name: _fallbackEventsName, events: const []),
    );
  }

  /// Groups enhancements by echelon (level) and then by type
  Future<Map<int, Map<String, List<DowntimeEntry>>>>
      loadEnhancementsByLevelAndType() async {
    final enhancements = await loadEnhancements();
    final grouped = <int, Map<String, List<DowntimeEntry>>>{};

    for (final enhancement in enhancements) {
      final level = enhancement.raw['level'] as int? ?? 1;
      final type = enhancement.raw['type'] as String? ?? 'unknown';

      grouped.putIfAbsent(level, () => <String, List<DowntimeEntry>>{});
      grouped[level]!.putIfAbsent(type, () => <DowntimeEntry>[]);
      grouped[level]![type]!.add(enhancement);
    }

    // Sort by level
    final sortedGrouped = <int, Map<String, List<DowntimeEntry>>>{};
    final sortedKeys = grouped.keys.toList()..sort();
    for (final key in sortedKeys) {
      sortedGrouped[key] = grouped[key]!;
    }

    return sortedGrouped;
  }

  /// Get a human-readable name for enhancement types
  String getEnhancementTypeName(String type) {
    switch (type) {
      case 'armor_enhancement':
        return 'Armor Enhancements';
      case 'weapon_enhancement':
        return 'Weapon Enhancements';
      case 'implement_enhancement':
        return 'Implement Enhancements';
      default:
        return type
            .replaceAll('_', ' ')
            .split(' ')
            .map((word) => word.isNotEmpty
                ? word[0].toUpperCase() + word.substring(1)
                : '')
            .join(' ');
    }
  }

  /// Get level display name
  String getLevelName(int level) {
    switch (level) {
      case 1:
        return '1st Level';
      case 5:
        return '5th Level';
      case 9:
        return '9th Level';
      default:
        return '${level}th Level';
    }
  }
}
