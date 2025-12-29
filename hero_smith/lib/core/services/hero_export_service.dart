import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// Version of the export format. Increment when making breaking changes.
/// 
/// Version history:
/// - 1: Initial version with hero_row, values, entries, config
/// - 2: Added downtime_projects, followers, project_sources, notes
const int kHeroExportVersion = 2;

/// Service for exporting and importing heroes as shareable codes.
/// 
/// Export format is a compressed, base64-encoded JSON containing:
/// - format_version: Version number for compatibility checking
/// - hero: Basic hero info (name)
/// - values: All hero_values rows (stats, resources, etc.)
/// - entries: All hero_entries rows (class, ancestry, skills, abilities, etc.)
/// - config: All hero_config rows (choices, preferences, etc.)
class HeroExportService {
  HeroExportService(this._db);
  final AppDatabase _db;

  /// Export a hero to a shareable code string.
  /// 
  /// The code is prefixed with "HERO:" for easy identification.
  Future<String> exportHeroToCode(String heroId) async {
    final data = await _gatherHeroData(heroId);
    final json = jsonEncode(data);
    final bytes = utf8.encode(json);
    final compressed = gzip.encode(bytes);
    final base64Code = base64Encode(compressed);
    return 'HERO:$base64Code';
  }

  /// Import a hero from a shareable code string.
  /// 
  /// Returns the new hero's ID on success.
  /// Throws an exception if the code is invalid or incompatible.
  Future<String> importHeroFromCode(String code) async {
    if (!code.startsWith('HERO:')) {
      throw const FormatException('Invalid hero code: must start with "HERO:"');
    }

    final base64Part = code.substring(5);
    final Map<String, dynamic> data;
    try {
      final compressed = base64Decode(base64Part);
      final bytes = gzip.decode(compressed);
      final json = utf8.decode(bytes);
      data = jsonDecode(json) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('Failed to decode hero code: $e');
    }

    // Version check
    final version = data['format_version'] as int?;
    if (version == null || version > kHeroExportVersion) {
      throw FormatException(
        'Incompatible hero code version: $version (max supported: $kHeroExportVersion)',
      );
    }

    return _importHeroData(data);
  }

  /// Validate a hero code without importing.
  /// 
  /// Returns a summary of what would be imported, or throws if invalid.
  HeroImportPreview? validateCode(String code) {
    if (!code.startsWith('HERO:')) {
      return null;
    }

    try {
      final base64Part = code.substring(5);
      final compressed = base64Decode(base64Part);
      final bytes = gzip.decode(compressed);
      final json = utf8.decode(bytes);
      final data = jsonDecode(json) as Map<String, dynamic>;

      final version = data['format_version'] as int?;
      final hero = data['hero'] as Map<String, dynamic>?;
      final heroName = hero?['name'] as String? ?? 'Unknown Hero';

      // Extract class/ancestry from entries if available
      final entries = data['entries'] as List<dynamic>? ?? [];
      String? className;
      String? ancestryName;
      for (final e in entries) {
        if (e is Map<String, dynamic>) {
          if (e['entry_type'] == 'class') {
            className = e['entry_id'] as String?;
          } else if (e['entry_type'] == 'ancestry') {
            ancestryName = e['entry_id'] as String?;
          }
        }
      }

      return HeroImportPreview(
        name: heroName,
        formatVersion: version ?? 1,
        isCompatible: version != null && version <= kHeroExportVersion,
        className: className,
        ancestryName: ancestryName,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _gatherHeroData(String heroId) async {
    // Get hero row
    final heroRow = await (_db.select(_db.heroes)
          ..where((t) => t.id.equals(heroId)))
        .getSingleOrNull();
    if (heroRow == null) {
      throw ArgumentError('Hero not found: $heroId');
    }

    // Get all hero values
    final values = await _db.getHeroValues(heroId);
    final valuesData = values.map((v) => {
          'key': v.key,
          'value': v.value,
          'max_value': v.maxValue,
          'double_value': v.doubleValue,
          'text_value': v.textValue,
          'json_value': v.jsonValue,
        }).toList();

    // Get all hero entries
    final entries = await (_db.select(_db.heroEntries)
          ..where((t) => t.heroId.equals(heroId)))
        .get();
    final entriesData = entries.map((e) => {
          'entry_type': e.entryType,
          'entry_id': e.entryId,
          'source_type': e.sourceType,
          'source_id': e.sourceId,
          'gained_by': e.gainedBy,
          'payload': e.payload,
        }).toList();

    // Get all hero config
    final config = await (_db.select(_db.heroConfig)
          ..where((t) => t.heroId.equals(heroId)))
        .get();
    final configData = config.map((c) => {
          'config_key': c.configKey,
          'value_json': c.valueJson,
          'metadata': c.metadata,
        }).toList();

    // Get downtime projects
    final projects = await (_db.select(_db.heroDowntimeProjects)
          ..where((t) => t.heroId.equals(heroId)))
        .get();
    final projectsData = projects.map((p) => {
          'template_project_id': p.templateProjectId,
          'name': p.name,
          'description': p.description,
          'project_goal': p.projectGoal,
          'current_points': p.currentPoints,
          'prerequisites_json': p.prerequisitesJson,
          'project_source': p.projectSource,
          'source_language': p.sourceLanguage,
          'guides_json': p.guidesJson,
          'roll_characteristics_json': p.rollCharacteristicsJson,
          'events_json': p.eventsJson,
          'notes': p.notes,
          'is_custom': p.isCustom,
          'is_completed': p.isCompleted,
        }).toList();

    // Get followers
    final followers = await (_db.select(_db.heroFollowers)
          ..where((t) => t.heroId.equals(heroId)))
        .get();
    final followersData = followers.map((f) => {
          'name': f.name,
          'follower_type': f.followerType,
          'might': f.might,
          'agility': f.agility,
          'reason': f.reason,
          'intuition': f.intuition,
          'presence': f.presence,
          'skills_json': f.skillsJson,
          'languages_json': f.languagesJson,
        }).toList();

    // Get project sources
    final sources = await (_db.select(_db.heroProjectSources)
          ..where((t) => t.heroId.equals(heroId)))
        .get();
    final sourcesData = sources.map((s) => {
          'name': s.name,
          'type': s.type,
          'language': s.language,
          'description': s.description,
        }).toList();

    // Get notes
    final notes = await (_db.select(_db.heroNotes)
          ..where((t) => t.heroId.equals(heroId)))
        .get();
    final notesData = notes.map((n) => {
          'title': n.title,
          'content': n.content,
          'folder_id': n.folderId,
          'is_folder': n.isFolder,
          'sort_order': n.sortOrder,
        }).toList();

    return {
      'format_version': kHeroExportVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'hero': {
        'name': heroRow.name,
      },
      'values': valuesData,
      'entries': entriesData,
      'config': configData,
      'downtime_projects': projectsData,
      'followers': followersData,
      'project_sources': sourcesData,
      'notes': notesData,
    };
  }

  Future<String> _importHeroData(Map<String, dynamic> data) async {
    final hero = data['hero'] as Map<String, dynamic>?;
    final heroName = hero?['name'] as String? ?? 'Imported Hero';

    // Create new hero
    final newHeroId = await _db.createHero(name: heroName);

    // Import values
    final values = data['values'] as List<dynamic>? ?? [];
    for (final v in values) {
      if (v is Map<String, dynamic>) {
        final key = v['key'] as String?;
        if (key == null) continue;

        await _db.upsertHeroValue(
          heroId: newHeroId,
          key: key,
          value: v['value'] as int?,
          maxValue: v['max_value'] as int?,
          doubleValue: (v['double_value'] as num?)?.toDouble(),
          textValue: v['text_value'] as String?,
          jsonMap: v['json_value'] != null
              ? _tryDecodeJson(v['json_value'] as String)
              : null,
        );
      }
    }

    // Import entries
    final entries = data['entries'] as List<dynamic>? ?? [];
    for (final e in entries) {
      if (e is Map<String, dynamic>) {
        await _db.upsertHeroEntry(
          heroId: newHeroId,
          entryType: e['entry_type'] as String? ?? '',
          entryId: e['entry_id'] as String? ?? '',
          sourceType: e['source_type'] as String? ?? 'import',
          sourceId: e['source_id'] as String? ?? '',
          gainedBy: e['gained_by'] as String? ?? 'grant',
          payload: e['payload'] != null
              ? _tryDecodeJson(e['payload'] as String)
              : null,
        );
      }
    }

    // Import config
    final config = data['config'] as List<dynamic>? ?? [];
    for (final c in config) {
      if (c is Map<String, dynamic>) {
        final configKey = c['config_key'] as String?;
        final valueJson = c['value_json'] as String?;
        if (configKey == null || valueJson == null) continue;

        final value = _tryDecodeJson(valueJson);
        if (value != null) {
          await _db.setHeroConfig(
            heroId: newHeroId,
            configKey: configKey,
            value: value,
            metadata: c['metadata'] as String?,
          );
        }
      }
    }

    // Import downtime projects (v2+)
    final projects = data['downtime_projects'] as List<dynamic>? ?? [];
    for (final p in projects) {
      if (p is Map<String, dynamic>) {
        final projectId = _generateId();
        await _db.into(_db.heroDowntimeProjects).insert(
          HeroDowntimeProjectsCompanion.insert(
            id: projectId,
            heroId: newHeroId,
            templateProjectId: Value(p['template_project_id'] as String?),
            name: p['name'] as String? ?? 'Imported Project',
            description: Value(p['description'] as String? ?? ''),
            projectGoal: p['project_goal'] as int? ?? 0,
            currentPoints: Value(p['current_points'] as int? ?? 0),
            prerequisitesJson: Value(p['prerequisites_json'] as String? ?? '[]'),
            projectSource: Value(p['project_source'] as String?),
            sourceLanguage: Value(p['source_language'] as String?),
            guidesJson: Value(p['guides_json'] as String? ?? '[]'),
            rollCharacteristicsJson: Value(p['roll_characteristics_json'] as String? ?? '[]'),
            eventsJson: Value(p['events_json'] as String? ?? '[]'),
            notes: Value(p['notes'] as String? ?? ''),
            isCustom: Value(p['is_custom'] as bool? ?? false),
            isCompleted: Value(p['is_completed'] as bool? ?? false),
          ),
        );
      }
    }

    // Import followers (v2+)
    final followers = data['followers'] as List<dynamic>? ?? [];
    for (final f in followers) {
      if (f is Map<String, dynamic>) {
        final followerId = _generateId();
        await _db.into(_db.heroFollowers).insert(
          HeroFollowersCompanion.insert(
            id: followerId,
            heroId: newHeroId,
            name: f['name'] as String? ?? 'Follower',
            followerType: f['follower_type'] as String? ?? 'retainer',
            might: Value(f['might'] as int? ?? 0),
            agility: Value(f['agility'] as int? ?? 0),
            reason: Value(f['reason'] as int? ?? 0),
            intuition: Value(f['intuition'] as int? ?? 0),
            presence: Value(f['presence'] as int? ?? 0),
            skillsJson: Value(f['skills_json'] as String? ?? '[]'),
            languagesJson: Value(f['languages_json'] as String? ?? '[]'),
          ),
        );
      }
    }

    // Import project sources (v2+)
    final sources = data['project_sources'] as List<dynamic>? ?? [];
    for (final s in sources) {
      if (s is Map<String, dynamic>) {
        final sourceId = _generateId();
        await _db.into(_db.heroProjectSources).insert(
          HeroProjectSourcesCompanion.insert(
            id: sourceId,
            heroId: newHeroId,
            name: s['name'] as String? ?? 'Source',
            type: s['type'] as String? ?? 'source',
            language: Value(s['language'] as String?),
            description: Value(s['description'] as String?),
          ),
        );
      }
    }

    // Import notes (v2+) - need to remap folder IDs
    final notes = data['notes'] as List<dynamic>? ?? [];
    final folderIdMap = <String, String>{}; // old folder placeholder -> new folder id
    
    // First pass: create folders and build ID map
    for (int i = 0; i < notes.length; i++) {
      final n = notes[i];
      if (n is Map<String, dynamic> && n['is_folder'] == true) {
        final noteId = _generateId();
        folderIdMap['folder_$i'] = noteId;
        await _db.into(_db.heroNotes).insert(
          HeroNotesCompanion.insert(
            id: noteId,
            heroId: newHeroId,
            title: n['title'] as String? ?? 'Folder',
            content: Value(n['content'] as String? ?? ''),
            folderId: const Value(null), // Folders at root for simplicity
            isFolder: const Value(true),
            sortOrder: Value(n['sort_order'] as int? ?? i),
          ),
        );
      }
    }
    
    // Second pass: create notes
    for (int i = 0; i < notes.length; i++) {
      final n = notes[i];
      if (n is Map<String, dynamic> && n['is_folder'] != true) {
        final noteId = _generateId();
        await _db.into(_db.heroNotes).insert(
          HeroNotesCompanion.insert(
            id: noteId,
            heroId: newHeroId,
            title: n['title'] as String? ?? 'Note',
            content: Value(n['content'] as String? ?? ''),
            folderId: const Value(null), // Put all notes at root for simplicity
            isFolder: const Value(false),
            sortOrder: Value(n['sort_order'] as int? ?? i),
          ),
        );
      }
    }

    return newHeroId;
  }

  String _generateId() {
    return DateTime.now().microsecondsSinceEpoch.toString() + 
           '_${(DateTime.now().millisecond * 1000 + DateTime.now().microsecond).toRadixString(36)}';
  }

  Map<String, dynamic>? _tryDecodeJson(String? jsonStr) {
    if (jsonStr == null) return null;
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

/// Preview information for a hero import.
class HeroImportPreview {
  const HeroImportPreview({
    required this.name,
    required this.formatVersion,
    required this.isCompatible,
    this.className,
    this.ancestryName,
  });

  final String name;
  final int formatVersion;
  final bool isCompatible;
  final String? className;
  final String? ancestryName;
}
