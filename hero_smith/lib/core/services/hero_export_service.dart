import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// Version of the export format. Increment when making breaking changes.
///
/// Version history:
/// - 1: Initial version with hero_row, values, entries, config (legacy JSON format)
/// - 2: Added downtime_projects, followers, project_sources, notes (legacy JSON format)
/// - 3: Compact reference-based format (HS: prefix)
/// - 4: Ultra-compact format (H: prefix) - minimal data, smart compression
const int kHeroExportVersion = 4;

/// Version for the ultra-compact format
const int kUltraCompactVersion = 1;

/// Options for hero export - controls what optional data is included.
class HeroExportOptions {
  const HeroExportOptions({
    this.includeRuntimeState = false,
    this.includeUserData = false,
    this.includeCustomItems = false,
  });

  /// Include runtime state: current stamina, conditions, heroic resources, etc.
  final bool includeRuntimeState;

  /// Include user-generated data: notes, downtime projects, followers, project sources
  final bool includeUserData;

  /// Include custom/user-created items that don't exist in the standard database
  final bool includeCustomItems;

  /// Default options - minimal export with just hero build references
  static const minimal = HeroExportOptions();

  /// Full export with all optional data
  static const full = HeroExportOptions(
    includeRuntimeState: true,
    includeUserData: true,
    includeCustomItems: true,
  );
}

/// Service for exporting and importing heroes as shareable codes.
///
/// ULTRA-COMPACT format (v4+, prefix "H:"):
/// - Only exports: type code + entry ID (no source info)
/// - Payloads only for entries that truly need them (stat_mod, treasure qty)
/// - NO compression for small exports (gzip adds ~20 bytes overhead)
/// - Compression only kicks in if payload > 400 chars
/// - Example: H:10Ragnar~Cfury,Sberserker,Ahuman,Bstrike → ~50-100 chars!
///
/// COMPACT format (v3, prefix "HS:"):
/// - Exports Component IDs with source info
/// - Still supported for import
///
/// LEGACY format (v1-2, prefix "HERO:"):
/// - Full JSON export with all data
/// - Still supported for import (backward compatibility)
class HeroExportService {
  HeroExportService(this._db);
  final AppDatabase _db;

  // Single-character type codes for ultra-compact format
  static const _typeCode = {
    'class': 'C',
    'subclass': 'S',
    'ancestry': 'A',
    'ancestry_trait': 'T',
    'career': 'R',
    'kit': 'K',
    'deity': 'D',
    'domain': 'O',
    'ability': 'B',
    'skill': 'I',
    'perk': 'P',
    'language': 'L',
    'title': 'N',
    'equipment': 'E',
    'treasure': 'U',
    'stat_mod': 'M',
    'resistance': 'X',
    'condition_immunity': 'Y',
    'feature': 'F',
    'complication': 'W',
    'culture': 'V',
  };

  static final _codeToType = {
    for (final e in _typeCode.entries) e.value: e.key
  };

  // Types that MUST have payload (data can't be reconstructed from ID alone)
  static const _requiresPayload = {
    'stat_mod',
    'resistance',
    'condition_immunity'
  };

  // Legacy short codes for HS: format backward compatibility
  static const _legacyShortCodes = {
    'class': 'c',
    'subclass': 'sc',
    'ancestry': 'a',
    'ancestry_trait': 'at',
    'career': 'ca',
    'kit': 'k',
    'deity': 'd',
    'domain': 'dm',
    'ability': 'ab',
    'skill': 'sk',
    'perk': 'pk',
    'language': 'lg',
    'title': 'ti',
    'equipment': 'eq',
    'treasure': 'tr',
    'stat_mod': 'sm',
    'resistance': 'rs',
    'condition_immunity': 'ci',
    'kit_feature': 'kf',
    'kit_stat_bonus': 'ks',
    'equipment_bonuses': 'eb',
    'feature': 'ft',
    'complication': 'cm',
    'culture': 'cu',
  };

  static final _legacyCodeToType = {
    for (final e in _legacyShortCodes.entries) e.value: e.key
  };

  // ============================================================
  // COMPACT FORMAT (HS:) CONSTANTS - for backward compatibility
  // ============================================================

  /// Version for the compact HS: format (frozen at v3)
  static const int kCompactFormatVersion = 3;

  // Short codes for HS: format entry types
  static const _entryTypeShortCodes = {
    'class': 'c',
    'subclass': 'sc',
    'ancestry': 'a',
    'ancestry_trait': 'at',
    'career': 'ca',
    'kit': 'k',
    'deity': 'd',
    'domain': 'dm',
    'ability': 'ab',
    'skill': 'sk',
    'perk': 'pk',
    'language': 'lg',
    'title': 'ti',
    'equipment': 'eq',
    'treasure': 'tr',
    'stat_mod': 'sm',
    'resistance': 'rs',
    'condition_immunity': 'ci',
    'kit_feature': 'kf',
    'kit_stat_bonus': 'ks',
    'equipment_bonuses': 'eb',
    'feature': 'ft',
    'complication': 'cm',
    'culture': 'cu',
  };

  static final _shortCodeToEntryType = {
    for (final e in _entryTypeShortCodes.entries) e.value: e.key
  };

  // Source type short codes for HS: format
  static const _sourceTypeShortCodes = {
    'component': 'cp',
    'ancestry': 'an',
    'class': 'cl',
    'subclass': 'sc',
    'career': 'ca',
    'kit': 'kt',
    'perk': 'pk',
    'title': 'ti',
    'culture': 'cu',
    'complication': 'cm',
    'custom': 'cx',
  };

  static final _shortCodeToSourceType = {
    for (final e in _sourceTypeShortCodes.entries) e.value: e.key
  };

  // Gained by short codes for HS: format
  static const _gainedByShortCodes = {
    'grant': 'g',
    'choice': 'c',
    'swap': 's',
    'level_up': 'l',
    'manual': 'm',
  };

  static final _shortCodeToGainedBy = {
    for (final e in _gainedByShortCodes.entries) e.value: e.key
  };

  // Runtime state keys (for HS: import filtering)
  static const _runtimeStateKeys = {
    'current_stamina',
    'temp_stamina',
    'current_surges',
    'current_recoveries',
    'current_heroic_resource',
    'active_conditions',
    'active_effects',
  };

  // Score keys that should always be imported from HS: format
  static const _scoreKeys = {
    'might_score',
    'agility_score',
    'reason_score',
    'intuition_score',
    'presence_score',
  };

  // Prefixes to strip from IDs for ultra-compact export (type -> prefix)
  static const _typePrefix = {
    'ancestry': 'ancestry_',
    'career': 'career_',
    'skill': 'skill_',
    'language': 'language_',
    'ability': 'ability_',
    'complication': 'complication_',
    'culture': 'culture_',
    'deity': 'deity_',
    'perk': 'perk_', // some perks have this prefix
  };

  /// Strip redundant prefix from entry ID for compact export
  String _stripPrefix(String entryType, String entryId) {
    final prefix = _typePrefix[entryType];
    if (prefix != null && entryId.startsWith(prefix)) {
      return entryId.substring(prefix.length);
    }
    return entryId;
  }

  /// Restore prefix to entry ID during import
  static String _restorePrefix(String entryType, String shortId) {
    final prefix = _typePrefix[entryType];
    if (prefix != null && !shortId.startsWith(prefix)) {
      return '$prefix$shortId';
    }
    return shortId;
  }

  /// Export a hero to ultra-compact code string.
  ///
  /// The code is prefixed with "H:" for the new ultra-compact format.
  /// Use [options] to control what optional data is included.
  Future<String> exportHeroToCode(
    String heroId, {
    HeroExportOptions options = HeroExportOptions.minimal,
  }) async {
    final heroRow = await (_db.select(_db.heroes)
          ..where((t) => t.id.equals(heroId)))
        .getSingleOrNull();
    if (heroRow == null) {
      throw ArgumentError('Hero not found: $heroId');
    }

    // Build flags: bit 0 = runtime, bit 1 = userData, bit 2 = custom
    int flags = 0;
    if (options.includeRuntimeState) flags |= 1;
    if (options.includeUserData) flags |= 2;
    if (options.includeCustomItems) flags |= 4;

    // Get entries and build ultra-compact format
    final entries = await (_db.select(_db.heroEntries)
          ..where((t) => t.heroId.equals(heroId)))
        .get();

    final seen = <String>{};
    final entryStrings = <String>[];
    for (final e in entries) {
      if (!options.includeCustomItems && e.sourceType == 'custom') continue;

      final code = _typeCode[e.entryType];
      if (code == null) continue; // Skip unknown types

      // Build unique key to detect duplicates
      final uniqueKey = '${e.entryType}:${e.entryId}';
      if (seen.contains(uniqueKey)) continue; // Skip duplicates
      seen.add(uniqueKey);

      // Most entries: just code + id (strip common prefixes)
      final shortId = _stripPrefix(e.entryType, e.entryId);
      String entryStr = '$code$shortId';

      // Add payload only if truly required
      if (_requiresPayload.contains(e.entryType) && e.payload != null) {
        try {
          final p = jsonDecode(e.payload!) as Map<String, dynamic>;
          if (e.entryType == 'stat_mod') {
            // Compact: Mstat_id:stat:value
            entryStr += ':${p['stat']}:${p['value']}';
          } else if (e.entryType == 'resistance') {
            entryStr += ':${p['type']}:${p['amount'] ?? 0}';
          } else if (e.entryType == 'condition_immunity') {
            entryStr += ':${p['condition']}';
          }
        } catch (_) {}
      } else if (e.entryType == 'treasure' && e.payload != null) {
        // Treasure: just quantity if > 1
        try {
          final p = jsonDecode(e.payload!) as Map<String, dynamic>;
          final qty = p['quantity'] as int? ?? 1;
          if (qty > 1) entryStr += ':$qty';
        } catch (_) {}
      }

      entryStrings.add(entryStr);
    }

    // Build payload: version + flags + name ~ entries ~ coreStats [~ runtimeValues] [~ userData]
    final name = _sanitizeName(heroRow.name);
    final coreStats = await _getCoreStatsCompact(heroId);
    var payload =
        '$kUltraCompactVersion$flags$name~${entryStrings.join(',')}~$coreStats';

    // Add runtime values if opted in (current stamina, conditions, etc.)
    if (options.includeRuntimeState) {
      final runtimeValues = await _getRuntimeValues(heroId);
      if (runtimeValues.isNotEmpty) {
        payload += '~$runtimeValues';
      }
    }

    // Add user data if opted in (compressed separately due to size)
    if (options.includeUserData) {
      final userData = await _getUserDataCompact(heroId);
      if (userData.isNotEmpty) {
        payload += '~$userData';
      }
    }

    // Smart compression: only if payload is large enough to benefit
    if (payload.length > 400) {
      final compressed = gzip.encode(utf8.encode(payload));
      // Only use compression if it actually helps
      final compressedB64 = base64Encode(compressed);
      final uncompressedB64 = base64Url.encode(utf8.encode(payload));
      if (compressedB64.length < uncompressedB64.length) {
        return 'H:$compressedB64';
      }
    }

    // For short payloads, base64url without compression
    return 'H:${base64Url.encode(utf8.encode(payload))}';
  }

  /// Sanitize hero name for URL-safe embedding (no delimiters)
  String _sanitizeName(String name) {
    return name
        .replaceAll('~', '-')
        .replaceAll(',', ' ')
        .replaceAll(':', ' ')
        .trim();
  }

  // Compact codes for core stats (always exported)
  static const _coreStatCodes = {
    'basics.level': 'L',
    'stats.might': 'M',
    'stats.agility': 'A',
    'stats.reason': 'R',
    'stats.intuition': 'I',
    'stats.presence': 'P',
    'stats.size': 'Z',
    'stats.speed': 'V',
    'stats.stability': 'Y',
    'stats.disengage': 'D',
    'stamina.max': 'H',
    'recoveries.max': 'C',
    'score.victories': 'v',
    'score.exp': 'x',
    'score.wealth': 'w',
    'score.renown': 'r',
    'mods.map': 'm', // user modifications JSON
    'resistances.damage': 'd', // damage resistances JSON
  };

  static final _codeToCoreStat = {
    for (final e in _coreStatCodes.entries) e.value: e.key
  };

  /// Get core stats as compact string (always included)
  /// Format: L3,M2,A1,R0,I1,P3,Z1M,V5,Y0,D0,H21,C8,v0,x0,w0,r0
  Future<String> _getCoreStatsCompact(String heroId) async {
    final values = await _db.getHeroValues(heroId);
    final parts = <String>[];

    // Helper to find a value
    T? find<T>(String key, T? Function(HeroValue) getter) {
      final v = values.firstWhereOrNull((e) => e.key == key);
      return v != null ? getter(v) : null;
    }

    // Always export these core stats (even if 0, except for scores)
    final coreKeys = [
      'basics.level',
      'stats.might',
      'stats.agility',
      'stats.reason',
      'stats.intuition',
      'stats.presence',
      'stats.speed',
      'stats.stability',
      'stats.disengage',
      'stamina.max',
      'recoveries.max',
    ];

    for (final key in coreKeys) {
      final code = _coreStatCodes[key];
      if (code == null) continue;

      final val = find<int>(key, (v) => v.value);
      if (val != null) {
        parts.add('$code$val');
      }
    }

    // Size is text
    final size = find<String>('stats.size', (v) => v.textValue);
    if (size != null && size.isNotEmpty) {
      parts.add('Z$size');
    }

    // Scores (only if non-zero)
    final scoreKeys = ['score.victories', 'score.exp', 'score.wealth', 'score.renown'];
    for (final key in scoreKeys) {
      final code = _coreStatCodes[key];
      if (code == null) continue;
      final val = find<int>(key, (v) => v.value);
      if (val != null && val > 0) {
        parts.add('$code$val');
      }
    }

    // User modifications (compact JSON if present)
    final modsJson = find<String>('mods.map', (v) => v.textValue ?? v.jsonValue);
    if (modsJson != null && modsJson != '{}' && modsJson.isNotEmpty) {
      // Simplify the JSON to just stat:value pairs
      try {
        final mods = jsonDecode(modsJson) as Map<String, dynamic>;
        if (mods.isNotEmpty) {
          // Flatten to simple key=value format
          final modParts = mods.entries
              .where((e) => e.value != 0 && e.value != null)
              .map((e) => '${e.key}=${e.value}')
              .join(';');
          if (modParts.isNotEmpty) {
            parts.add('m$modParts');
          }
        }
      } catch (_) {}
    }

    // Damage resistances (compact JSON if present)
    final resistJson = find<String>('resistances.damage', (v) => v.textValue ?? v.jsonValue);
    if (resistJson != null && resistJson != '[]' && resistJson.isNotEmpty) {
      try {
        final resists = jsonDecode(resistJson) as List<dynamic>;
        if (resists.isNotEmpty) {
          // Format: type:amount;type:amount
          final resistParts = resists
              .map((r) => '${r['type']}:${r['amount'] ?? 0}')
              .join(';');
          if (resistParts.isNotEmpty) {
            parts.add('d$resistParts');
          }
        }
      } catch (_) {}
    }

    return parts.join(',');
  }

  /// Get runtime values as compact string (optional, for current state)
  Future<String> _getRuntimeValues(String heroId) async {
    final values = await _db.getHeroValues(heroId);
    final parts = <String>[];

    for (final v in values) {
      if (v.value == null) continue;

      switch (v.key) {
        case 'stamina.current':
          parts.add('h${v.value}');
          break;
        case 'stamina.temp':
          if (v.value != 0) parts.add('t${v.value}');
          break;
        case 'recoveries.current':
          parts.add('c${v.value}');
          break;
        case 'heroic.current':
          parts.add('e${v.value}');
          break;
        case 'surges.current':
          if (v.value != 0) parts.add('s${v.value}');
          break;
      }
    }

    return parts.join(',');
  }

  /// Get user data in compact format (compressed JSON for large data)
  Future<String> _getUserDataCompact(String heroId) async {
    final userData = <String, dynamic>{};

    // Just get project template IDs and progress (minimal)
    final projects = await (_db.select(_db.heroDowntimeProjects)
          ..where((t) => t.heroId.equals(heroId)))
        .get();
    if (projects.isNotEmpty) {
      userData['p'] = projects
          .map((p) => <String, dynamic>{
                if (p.templateProjectId != null) 't': p.templateProjectId,
                'n': p.name,
                'g': p.projectGoal,
                'c': p.currentPoints,
                if (p.isCompleted) 'd': true,
                if (p.projectSource != null) 's': p.projectSource,
              })
          .toList();
    }

    // Project sources
    final sources = await (_db.select(_db.heroProjectSources)
          ..where((t) => t.heroId.equals(heroId)))
        .get();
    if (sources.isNotEmpty) {
      userData['s'] = sources
          .map((s) => <String, dynamic>{
                'n': s.name,
                't': s.type,
                if (s.language != null) 'l': s.language,
                if (s.description != null) 'd': s.description,
              })
          .toList();
    }

    // Followers - essential fields only
    final followers = await (_db.select(_db.heroFollowers)
          ..where((t) => t.heroId.equals(heroId)))
        .get();
    if (followers.isNotEmpty) {
      userData['f'] = followers
          .map((f) => <String, dynamic>{
                'n': f.name,
                't': f.followerType,
              })
          .toList();
    }

    // Notes - just titles (content is too large)
    final notes = await (_db.select(_db.heroNotes)
          ..where((t) => t.heroId.equals(heroId)))
        .get();
    if (notes.isNotEmpty) {
      userData['n'] = notes.map((n) => n.title).toList();
    }

    // Inventory containers (custom items)
    final inventoryConfig =
        await _db.getHeroConfigValue(heroId, 'gear.inventory_containers');
    if (inventoryConfig != null) {
      final containers = inventoryConfig['containers'] as List<dynamic>?;
      if (containers != null && containers.isNotEmpty) {
        userData['i'] = containers;
      }
    }

    if (userData.isEmpty) return '';

    // Compress user data
    final json = jsonEncode(userData);
    final bytes = utf8.encode(json);
    final compressed = gzip.encode(bytes);
    return base64Encode(compressed);
  }

  /// Export using the legacy full JSON format (for compatibility).
  ///
  /// The code is prefixed with "HERO:" for the legacy format.
  Future<String> exportHeroToCodeLegacy(String heroId) async {
    final data = await _gatherHeroDataLegacy(heroId);
    final json = jsonEncode(data);
    final bytes = utf8.encode(json);
    final compressed = gzip.encode(bytes);
    final base64Code = base64Encode(compressed);
    return 'HERO:$base64Code';
  }

  /// Import a hero from a shareable code string.
  ///
  /// Supports ultra-compact (H:), compact (HS:), and legacy (HERO:) formats.
  /// Returns the new hero's ID on success.
  /// Throws an exception if the code is invalid or incompatible.
  Future<String> importHeroFromCode(String code) async {
    if (code.startsWith('H:') && !code.startsWith('HERO:')) {
      return _importUltraCompact(code);
    } else if (code.startsWith('HS:')) {
      return _importCompact(code);
    } else if (code.startsWith('HERO:')) {
      return _importLegacy(code);
    } else {
      throw const FormatException(
        'Invalid hero code: must start with "H:", "HS:", or "HERO:"',
      );
    }
  }

  /// Validate a hero code without importing.
  ///
  /// Returns a summary of what would be imported, or null if invalid.
  HeroImportPreview? validateCode(String code) {
    if (code.startsWith('H:') && !code.startsWith('HERO:')) {
      return _validateUltraCompact(code);
    } else if (code.startsWith('HS:')) {
      return _validateCompact(code);
    } else if (code.startsWith('HERO:')) {
      return _validateLegacy(code);
    }
    return null;
  }

  // ============================================================
  // ULTRA-COMPACT FORMAT (H:) - NEW
  // ============================================================

  /// Import from ultra-compact H: format
  Future<String> _importUltraCompact(String code) async {
    final base64Part = code.substring(2); // Remove "H:"

    String payload;
    try {
      // Try base64url decode first (uncompressed)
      final bytes = base64Url.decode(base64Part);

      // Check if it's gzip compressed (magic bytes 0x1f 0x8b)
      if (bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
        payload = utf8.decode(gzip.decode(bytes));
      } else {
        payload = utf8.decode(bytes);
      }
    } catch (e) {
      // Try regular base64 + gzip as fallback
      try {
        final compressed = base64Decode(base64Part);
        payload = utf8.decode(gzip.decode(compressed));
      } catch (_) {
        throw FormatException('Failed to decode hero code: $e');
      }
    }

    // Parse: version + flags + name ~ entries ~ coreStats [~ runtimeValues] [~ userData]
    final sections = payload.split('~');
    if (sections.length < 3) {
      throw const FormatException('Invalid hero code format');
    }

    // Parse header: first char = version, second char = flags, rest = name
    final header = sections[0];
    if (header.length < 2) {
      throw const FormatException('Invalid hero code header');
    }

    final version = int.tryParse(header[0]) ?? 1;
    if (version > kUltraCompactVersion) {
      throw FormatException('Unsupported format version: $version');
    }

    final flags = int.tryParse(header[1]) ?? 0;
    final hasRuntime = (flags & 1) != 0;
    final hasUserData = (flags & 2) != 0;
    final heroName = header.substring(2);

    // Create hero
    final newHeroId = await _db.createHero(name: heroName);

    // Section 1: Parse and import entries
    final entriesStr = sections[1];
    if (entriesStr.isNotEmpty) {
      await _importUltraCompactEntries(newHeroId, entriesStr);
    }

    // Section 2: Parse core stats (always present)
    if (sections[2].isNotEmpty) {
      await _importCoreStats(newHeroId, sections[2]);
    }

    // Determine which sections are runtime vs userData based on flags
    int nextSection = 3;

    // Section 3: Runtime values (if flag set)
    if (hasRuntime && sections.length > nextSection && sections[nextSection].isNotEmpty) {
      await _importRuntimeValues(newHeroId, sections[nextSection]);
      nextSection++;
    }

    // Section 4: User data (if flag set)
    if (hasUserData && sections.length > nextSection && sections[nextSection].isNotEmpty) {
      await _importUltraCompactUserData(newHeroId, sections[nextSection]);
    }

    return newHeroId;
  }

  /// Parse ultra-compact entries: "Cfury,Sberserker,Ahuman,Bstrike"
  Future<void> _importUltraCompactEntries(
      String heroId, String entriesStr) async {
    final entries = entriesStr.split(',');

    for (final entry in entries) {
      if (entry.isEmpty) continue;

      final typeCode = entry[0];
      final entryType = _codeToType[typeCode];
      if (entryType == null) continue;

      // Parse: TypeId or TypeId:payload...
      final rest = entry.substring(1);
      final parts = rest.split(':');
      // Restore prefix that was stripped during export
      final entryId = _restorePrefix(entryType, parts[0]);

      Map<String, dynamic>? payload;

      // Handle specific payload formats
      if (entryType == 'stat_mod' && parts.length >= 3) {
        payload = {'stat': parts[1], 'value': int.tryParse(parts[2]) ?? 0};
      } else if (entryType == 'resistance' && parts.length >= 3) {
        payload = {'type': parts[1], 'amount': int.tryParse(parts[2]) ?? 0};
      } else if (entryType == 'condition_immunity' && parts.length >= 2) {
        payload = {'condition': parts[1]};
      } else if (entryType == 'treasure' && parts.length >= 2) {
        payload = {'quantity': int.tryParse(parts[1]) ?? 1};
      }

      await _db.upsertHeroEntry(
        heroId: heroId,
        entryType: entryType,
        entryId: entryId,
        sourceType: 'import',
        sourceId: '',
        gainedBy: 'grant',
        payload: payload,
      );
    }
  }

  /// Import core stats from compact format
  /// Format: L3,M2,A1,R0,I1,P3,Z1M,V5,Y0,D0,H21,C8,v0,x0,w0,r0,m...,d...
  Future<void> _importCoreStats(String heroId, String statsStr) async {
    final parts = statsStr.split(',');

    for (final part in parts) {
      if (part.isEmpty) continue;

      final code = part[0];
      final valueStr = part.substring(1);

      // Handle special cases first
      if (code == 'm') {
        // User modifications: mkey1=val1;key2=val2
        await _importModifications(heroId, valueStr);
        continue;
      }
      if (code == 'd') {
        // Damage resistances: dtype1:amt1;type2:amt2
        await _importDamageResistances(heroId, valueStr);
        continue;
      }

      // Standard stats
      final key = _codeToCoreStat[code];
      if (key == null) continue;

      if (code == 'Z') {
        // Size is text
        await _db.upsertHeroValue(
          heroId: heroId,
          key: key,
          textValue: valueStr,
        );
      } else {
        final value = int.tryParse(valueStr);
        if (value != null) {
          await _db.upsertHeroValue(
            heroId: heroId,
            key: key,
            value: value,
          );
        }
      }
    }
  }

  /// Import user modifications map
  Future<void> _importModifications(String heroId, String modsStr) async {
    if (modsStr.isEmpty) return;

    final mods = <String, dynamic>{};
    for (final pair in modsStr.split(';')) {
      final parts = pair.split('=');
      if (parts.length != 2) continue;
      final value = int.tryParse(parts[1]) ?? double.tryParse(parts[1]);
      if (value != null) {
        mods[parts[0]] = value;
      }
    }

    if (mods.isNotEmpty) {
      await _db.upsertHeroValue(
        heroId: heroId,
        key: 'mods.map',
        textValue: jsonEncode(mods),
      );
    }
  }

  /// Import damage resistances
  Future<void> _importDamageResistances(String heroId, String resistStr) async {
    if (resistStr.isEmpty) return;

    final resists = <Map<String, dynamic>>[];
    for (final pair in resistStr.split(';')) {
      final parts = pair.split(':');
      if (parts.length >= 2) {
        resists.add({
          'type': parts[0],
          'amount': int.tryParse(parts[1]) ?? 0,
        });
      }
    }

    if (resists.isNotEmpty) {
      await _db.upsertHeroValue(
        heroId: heroId,
        key: 'resistances.damage',
        textValue: jsonEncode(resists),
      );
    }
  }

  /// Import runtime values (current stamina, recoveries, etc.)
  Future<void> _importRuntimeValues(String heroId, String valuesStr) async {
    final parts = valuesStr.split(',');

    for (final part in parts) {
      if (part.isEmpty) continue;

      final code = part[0];
      final value = int.tryParse(part.substring(1));
      if (value == null) continue;

      String? key;
      switch (code) {
        case 'h':
          key = 'stamina.current';
          break;
        case 't':
          key = 'stamina.temp';
          break;
        case 'c':
          key = 'recoveries.current';
          break;
        case 'e':
          key = 'heroic.current';
          break;
        case 's':
          key = 'surges.current';
          break;
      }

      if (key != null) {
        await _db.upsertHeroValue(
          heroId: heroId,
          key: key,
          value: value,
        );
      }
    }
  }

  /// Parse compact values (legacy HS: format): "v5,x100,h45"
  Future<void> _importCompactValues(String heroId, String valuesStr) async {
    final values = valuesStr.split(',');

    for (final v in values) {
      if (v.isEmpty) continue;

      final prefix = v[0];
      final value = int.tryParse(v.substring(1));
      if (value == null) continue;

      String? key;
      switch (prefix) {
        case 'v':
          key = 'score.victories';
          break;
        case 'x':
          key = 'score.exp';
          break;
        case 'w':
          key = 'score.wealth';
          break;
        case 'r':
          key = 'score.renown';
          break;
        case 'h':
          key = 'stamina.current';
          break;
        case 'c':
          key = 'recoveries.current';
          break;
        case 'e':
          key = 'heroic.current';
          break;
      }

      if (key != null) {
        await _db.upsertHeroValue(
          heroId: heroId,
          key: key,
          value: value,
        );
      }
    }
  }

  /// Import user data from ultra-compact format
  Future<void> _importUltraCompactUserData(
      String heroId, String userDataStr) async {
    if (userDataStr.isEmpty) return;

    Map<String, dynamic> userData;
    try {
      final compressed = base64Decode(userDataStr);
      final bytes = gzip.decode(compressed);
      final json = utf8.decode(bytes);
      userData = jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return; // Invalid user data, skip
    }

    // Import projects (minimal data)
    final projects = userData['p'] as List<dynamic>? ?? [];
    for (final p in projects) {
      if (p is! Map<String, dynamic>) continue;

      final projectId = _generateId();
      await _db.into(_db.heroDowntimeProjects).insert(
            HeroDowntimeProjectsCompanion.insert(
              id: projectId,
              heroId: heroId,
              templateProjectId: Value(p['t'] as String?),
              name: p['n'] as String? ?? 'Project',
              description: const Value(''),
              projectGoal: p['g'] as int? ?? 0,
              currentPoints: Value(p['c'] as int? ?? 0),
              isCompleted: Value(p['d'] as bool? ?? false),
            ),
          );
    }

    // Import followers (minimal data)
    final followers = userData['f'] as List<dynamic>? ?? [];
    for (final f in followers) {
      if (f is! Map<String, dynamic>) continue;

      final followerId = _generateId();
      await _db.into(_db.heroFollowers).insert(
            HeroFollowersCompanion.insert(
              id: followerId,
              heroId: heroId,
              name: f['n'] as String? ?? 'Follower',
              followerType: f['t'] as String? ?? 'retainer',
            ),
          );
    }

    // Import note titles
    final notes = userData['n'] as List<dynamic>? ?? [];
    for (int i = 0; i < notes.length; i++) {
      final title = notes[i] as String? ?? 'Note';
      final noteId = _generateId();
      await _db.into(_db.heroNotes).insert(
            HeroNotesCompanion.insert(
              id: noteId,
              heroId: heroId,
              title: title,
              content: const Value(''),
              sortOrder: Value(i),
            ),
          );
    }

    // Import project sources
    final sources = userData['s'] as List<dynamic>? ?? [];
    for (final s in sources) {
      if (s is! Map<String, dynamic>) continue;

      final sourceId = _generateId();
      await _db.into(_db.heroProjectSources).insert(
            HeroProjectSourcesCompanion.insert(
              id: sourceId,
              heroId: heroId,
              name: s['n'] as String? ?? 'Source',
              type: s['t'] as String? ?? 'source',
              language: Value(s['l'] as String?),
              description: Value(s['d'] as String?),
            ),
          );
    }

    // Import inventory containers
    final containers = userData['i'] as List<dynamic>?;
    if (containers != null && containers.isNotEmpty) {
      await _db.setHeroConfig(
        heroId: heroId,
        configKey: 'gear.inventory_containers',
        value: {'containers': containers},
      );
    }
  }

  /// Validate ultra-compact format code
  HeroImportPreview? _validateUltraCompact(String code) {
    try {
      final base64Part = code.substring(2);

      String payload;
      try {
        final bytes = base64Url.decode(base64Part);
        if (bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
          payload = utf8.decode(gzip.decode(bytes));
        } else {
          payload = utf8.decode(bytes);
        }
      } catch (_) {
        final compressed = base64Decode(base64Part);
        payload = utf8.decode(gzip.decode(compressed));
      }

      final sections = payload.split('~');
      if (sections.length < 2) return null;

      final header = sections[0];
      if (header.length < 2) return null;

      final version = int.tryParse(header[0]) ?? 1;
      final flags = int.tryParse(header[1]) ?? 0;
      final heroName = header.substring(2);

      // Extract class/ancestry from entries
      String? classId, ancestryId;
      final entries = sections[1].split(',');
      for (final e in entries) {
        if (e.isEmpty) continue;
        final typeCode = e[0];
        final rest = e.substring(1).split(':')[0];

        if (typeCode == 'C') classId = rest;
        if (typeCode == 'A') ancestryId = rest;
      }

      return HeroImportPreview(
        name: heroName,
        formatVersion: version,
        isCompatible: version <= kUltraCompactVersion,
        className: classId,
        ancestryName: ancestryId,
        isCompactFormat: true,
        hasRuntimeState: (flags & 1) != 0,
        hasUserData: (flags & 2) != 0,
        hasCustomItems: (flags & 4) != 0,
      );
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // COMPACT FORMAT (HS:) - LEGACY IMPORT SUPPORT
  // ============================================================

  /// Import hero from compact format (HS:)
  Future<String> _importCompact(String code) async {
    final base64Part = code.substring(3); // Remove "HS:"

    String payload;
    try {
      final compressed = base64Decode(base64Part);
      final bytes = gzip.decode(compressed);
      payload = utf8.decode(bytes);
    } catch (e) {
      throw FormatException('Failed to decode hero code: $e');
    }

    final parts = payload.split('|');
    if (parts.length < 5) {
      throw const FormatException(
          'Invalid hero code: missing required sections');
    }

    final version = int.tryParse(parts[0]) ?? 0;
    if (version > kCompactFormatVersion) {
      throw FormatException(
        'Incompatible hero code version: $version (max supported: $kCompactFormatVersion)',
      );
    }

    final flags = int.tryParse(parts[1]) ?? 0;
    final hasRuntimeState = (flags & 1) != 0;
    final hasUserData = (flags & 2) != 0;
    // final hasCustomItems = (flags & 4) != 0; // For future use

    final heroName = Uri.decodeComponent(parts[2]);
    final entriesCompact = parts[3];
    final configCompact = parts[4];
    final valuesCompact = parts.length > 5 ? parts[5] : '';
    final userDataCompact = parts.length > 6 ? parts[6] : '';

    // Create new hero
    final newHeroId = await _db.createHero(name: heroName);

    // Import entries
    await _importEntriesCompact(newHeroId, entriesCompact);

    // Import config
    await _importConfigCompact(newHeroId, configCompact);

    // Import values (scores always, runtime if flagged)
    await _importValuesCompact(newHeroId, valuesCompact, hasRuntimeState);

    // Import user data if present
    if (hasUserData && userDataCompact.isNotEmpty) {
      await _importUserDataCompact(newHeroId, userDataCompact);
    }

    return newHeroId;
  }

  /// Import entries from compact format
  Future<void> _importEntriesCompact(
      String heroId, String entriesCompact) async {
    if (entriesCompact.isEmpty) return;

    final entries = entriesCompact.split(',');

    for (final entry in entries) {
      if (entry.isEmpty) continue;

      final parts = entry.split('.');
      if (parts.length < 5) continue;

      final entryType = _shortCodeToEntryType[parts[0]] ?? parts[0];
      final entryId = parts[1];
      final sourceType = _shortCodeToSourceType[parts[2]] ?? parts[2];
      final sourceId = parts[3];
      final gainedBy = _shortCodeToGainedBy[parts[4]] ?? 'grant';

      // Decode payload if present
      Map<String, dynamic>? payload;
      if (parts.length > 5 && parts[5].isNotEmpty) {
        try {
          final payloadJson = utf8.decode(base64Decode(parts[5]));
          payload = jsonDecode(payloadJson) as Map<String, dynamic>?;
        } catch (_) {
          // Ignore payload decode errors
        }
      }

      await _db.upsertHeroEntry(
        heroId: heroId,
        entryType: entryType,
        entryId: entryId,
        sourceType: sourceType,
        sourceId: sourceId,
        gainedBy: gainedBy,
        payload: payload,
      );
    }
  }

  /// Import config from compact format
  Future<void> _importConfigCompact(String heroId, String configCompact) async {
    if (configCompact.isEmpty) return;

    final configs = configCompact.split(',');

    for (final config in configs) {
      if (config.isEmpty) continue;

      final eqIndex = config.indexOf('=');
      if (eqIndex < 0) continue;

      final configKey = config.substring(0, eqIndex);
      final valueB64 = config.substring(eqIndex + 1);

      try {
        final valueJson = utf8.decode(base64Decode(valueB64));
        final value = jsonDecode(valueJson);
        if (value is Map<String, dynamic>) {
          await _db.setHeroConfig(
            heroId: heroId,
            configKey: configKey,
            value: value,
          );
        }
      } catch (_) {
        // Ignore config decode errors
      }
    }
  }

  /// Import values from compact format
  Future<void> _importValuesCompact(
    String heroId,
    String valuesCompact,
    bool includeRuntime,
  ) async {
    if (valuesCompact.isEmpty) return;

    final values = valuesCompact.split(',');

    for (final value in values) {
      if (value.isEmpty) continue;

      final parts = value.split(':');
      if (parts.isEmpty) continue;

      final key = parts[0];

      // Skip runtime values if not opted in
      final isRuntime = _runtimeStateKeys.contains(key);
      if (isRuntime && !includeRuntime) continue;

      int? intValue;
      int? maxValue;
      double? doubleValue;
      String? textValue;
      Map<String, dynamic>? jsonValue;

      for (int i = 1; i < parts.length; i++) {
        final part = parts[i];
        if (part.isEmpty) continue;

        final prefix = part[0];
        final data = part.substring(1);

        switch (prefix) {
          case 'v':
            intValue = int.tryParse(data);
            break;
          case 'm':
            maxValue = int.tryParse(data);
            break;
          case 'd':
            doubleValue = double.tryParse(data);
            break;
          case 't':
            try {
              textValue = utf8.decode(base64Decode(data));
            } catch (_) {}
            break;
          case 'j':
            try {
              final jsonStr = utf8.decode(base64Decode(data));
              jsonValue = jsonDecode(jsonStr) as Map<String, dynamic>?;
            } catch (_) {}
            break;
        }
      }

      await _db.upsertHeroValue(
        heroId: heroId,
        key: key,
        value: intValue,
        maxValue: maxValue,
        doubleValue: doubleValue,
        textValue: textValue,
        jsonMap: jsonValue,
      );
    }
  }

  /// Import user data from compact format
  Future<void> _importUserDataCompact(
      String heroId, String userDataCompact) async {
    if (userDataCompact.isEmpty) return;

    Map<String, dynamic> userData;
    try {
      final compressed = base64Decode(userDataCompact);
      final bytes = gzip.decode(compressed);
      final json = utf8.decode(bytes);
      userData = jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return; // Invalid user data, skip
    }

    // Import projects
    final projects = userData['p'] as List<dynamic>? ?? [];
    for (final p in projects) {
      if (p is! Map<String, dynamic>) continue;

      final projectId = _generateId();
      await _db.into(_db.heroDowntimeProjects).insert(
            HeroDowntimeProjectsCompanion.insert(
              id: projectId,
              heroId: heroId,
              templateProjectId: Value(p['t'] as String?),
              name: p['n'] as String? ?? 'Project',
              description: Value(p['d'] as String? ?? ''),
              projectGoal: p['g'] as int? ?? 0,
              currentPoints: Value(p['c'] as int? ?? 0),
              prerequisitesJson: Value(p['pr'] as String? ?? '[]'),
              projectSource: Value(p['ps'] as String?),
              sourceLanguage: Value(p['sl'] as String?),
              guidesJson: Value(p['gu'] as String? ?? '[]'),
              rollCharacteristicsJson: Value(p['rc'] as String? ?? '[]'),
              eventsJson: Value(p['e'] as String? ?? '[]'),
              notes: Value(p['no'] as String? ?? ''),
              isCustom: Value(p['ic'] as bool? ?? false),
              isCompleted: Value(p['io'] as bool? ?? false),
            ),
          );
    }

    // Import followers
    final followers = userData['f'] as List<dynamic>? ?? [];
    for (final f in followers) {
      if (f is! Map<String, dynamic>) continue;

      final followerId = _generateId();
      await _db.into(_db.heroFollowers).insert(
            HeroFollowersCompanion.insert(
              id: followerId,
              heroId: heroId,
              name: f['n'] as String? ?? 'Follower',
              followerType: f['t'] as String? ?? 'retainer',
              might: Value(f['m'] as int? ?? 0),
              agility: Value(f['a'] as int? ?? 0),
              reason: Value(f['r'] as int? ?? 0),
              intuition: Value(f['i'] as int? ?? 0),
              presence: Value(f['p'] as int? ?? 0),
              skillsJson: Value(f['s'] as String? ?? '[]'),
              languagesJson: Value(f['l'] as String? ?? '[]'),
            ),
          );
    }

    // Import project sources
    final sources = userData['s'] as List<dynamic>? ?? [];
    for (final s in sources) {
      if (s is! Map<String, dynamic>) continue;

      final sourceId = _generateId();
      await _db.into(_db.heroProjectSources).insert(
            HeroProjectSourcesCompanion.insert(
              id: sourceId,
              heroId: heroId,
              name: s['n'] as String? ?? 'Source',
              type: s['t'] as String? ?? 'source',
              language: Value(s['l'] as String?),
              description: Value(s['d'] as String?),
            ),
          );
    }

    // Import notes
    final notes = userData['n'] as List<dynamic>? ?? [];
    for (int i = 0; i < notes.length; i++) {
      final n = notes[i];
      if (n is! Map<String, dynamic>) continue;

      final noteId = _generateId();
      await _db.into(_db.heroNotes).insert(
            HeroNotesCompanion.insert(
              id: noteId,
              heroId: heroId,
              title: n['t'] as String? ?? 'Note',
              content: Value(n['c'] as String? ?? ''),
              folderId: const Value(null),
              isFolder: Value(n['f'] as bool? ?? false),
              sortOrder: Value(n['o'] as int? ?? i),
            ),
          );
    }
  }

  /// Validate compact format code
  HeroImportPreview? _validateCompact(String code) {
    try {
      final base64Part = code.substring(3);
      final compressed = base64Decode(base64Part);
      final bytes = gzip.decode(compressed);
      final payload = utf8.decode(bytes);

      final parts = payload.split('|');
      if (parts.length < 5) return null;

      final version = int.tryParse(parts[0]) ?? 0;
      final flags = int.tryParse(parts[1]) ?? 0;
      final heroName = Uri.decodeComponent(parts[2]);
      final entriesCompact = parts[3];

      // Extract class/ancestry from entries
      String? classId;
      String? ancestryId;

      final entries = entriesCompact.split(',');
      for (final entry in entries) {
        final entryParts = entry.split('.');
        if (entryParts.length < 2) continue;

        final typeCode = entryParts[0];
        final entryId = entryParts[1];

        if (typeCode == 'c') {
          classId = entryId;
        } else if (typeCode == 'a') {
          ancestryId = entryId;
        }
      }

      return HeroImportPreview(
        name: heroName,
        formatVersion: version,
        isCompatible: version <= kCompactFormatVersion,
        className: classId,
        ancestryName: ancestryId,
        isCompactFormat: true,
        hasRuntimeState: (flags & 1) != 0,
        hasUserData: (flags & 2) != 0,
        hasCustomItems: (flags & 4) != 0,
      );
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // LEGACY FORMAT IMPLEMENTATION (for backward compatibility)
  // ============================================================

  /// Import from legacy HERO: format
  Future<String> _importLegacy(String code) async {
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

    final version = data['format_version'] as int?;
    if (version == null || version > kHeroExportVersion) {
      throw FormatException(
        'Incompatible hero code version: $version (max supported: $kHeroExportVersion)',
      );
    }

    return _importHeroDataLegacy(data);
  }

  /// Validate legacy HERO: format
  HeroImportPreview? _validateLegacy(String code) {
    try {
      final base64Part = code.substring(5);
      final compressed = base64Decode(base64Part);
      final bytes = gzip.decode(compressed);
      final json = utf8.decode(bytes);
      final data = jsonDecode(json) as Map<String, dynamic>;

      final version = data['format_version'] as int?;
      final hero = data['hero'] as Map<String, dynamic>?;
      final heroName = hero?['name'] as String? ?? 'Unknown Hero';

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
        isCompactFormat: false,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _gatherHeroDataLegacy(String heroId) async {
    // Get hero row
    final heroRow = await (_db.select(_db.heroes)
          ..where((t) => t.id.equals(heroId)))
        .getSingleOrNull();
    if (heroRow == null) {
      throw ArgumentError('Hero not found: $heroId');
    }

    // Get all hero values
    final values = await _db.getHeroValues(heroId);
    final valuesData = values
        .map((v) => {
              'key': v.key,
              'value': v.value,
              'max_value': v.maxValue,
              'double_value': v.doubleValue,
              'text_value': v.textValue,
              'json_value': v.jsonValue,
            })
        .toList();

    // Get all hero entries
    final entries = await (_db.select(_db.heroEntries)
          ..where((t) => t.heroId.equals(heroId)))
        .get();
    final entriesData = entries
        .map((e) => {
              'entry_type': e.entryType,
              'entry_id': e.entryId,
              'source_type': e.sourceType,
              'source_id': e.sourceId,
              'gained_by': e.gainedBy,
              'payload': e.payload,
            })
        .toList();

    // Get all hero config
    final config = await (_db.select(_db.heroConfig)
          ..where((t) => t.heroId.equals(heroId)))
        .get();
    final configData = config
        .map((c) => {
              'config_key': c.configKey,
              'value_json': c.valueJson,
              'metadata': c.metadata,
            })
        .toList();

    // Get downtime projects
    final projects = await (_db.select(_db.heroDowntimeProjects)
          ..where((t) => t.heroId.equals(heroId)))
        .get();
    final projectsData = projects
        .map((p) => {
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
            })
        .toList();

    // Get followers
    final followers = await (_db.select(_db.heroFollowers)
          ..where((t) => t.heroId.equals(heroId)))
        .get();
    final followersData = followers
        .map((f) => {
              'name': f.name,
              'follower_type': f.followerType,
              'might': f.might,
              'agility': f.agility,
              'reason': f.reason,
              'intuition': f.intuition,
              'presence': f.presence,
              'skills_json': f.skillsJson,
              'languages_json': f.languagesJson,
            })
        .toList();

    // Get project sources
    final sources = await (_db.select(_db.heroProjectSources)
          ..where((t) => t.heroId.equals(heroId)))
        .get();
    final sourcesData = sources
        .map((s) => {
              'name': s.name,
              'type': s.type,
              'language': s.language,
              'description': s.description,
            })
        .toList();

    // Get notes
    final notes = await (_db.select(_db.heroNotes)
          ..where((t) => t.heroId.equals(heroId)))
        .get();
    final notesData = notes
        .map((n) => {
              'title': n.title,
              'content': n.content,
              'folder_id': n.folderId,
              'is_folder': n.isFolder,
              'sort_order': n.sortOrder,
            })
        .toList();

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

  Future<String> _importHeroDataLegacy(Map<String, dynamic> data) async {
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
                prerequisitesJson:
                    Value(p['prerequisites_json'] as String? ?? '[]'),
                projectSource: Value(p['project_source'] as String?),
                sourceLanguage: Value(p['source_language'] as String?),
                guidesJson: Value(p['guides_json'] as String? ?? '[]'),
                rollCharacteristicsJson:
                    Value(p['roll_characteristics_json'] as String? ?? '[]'),
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
    final folderIdMap =
        <String, String>{}; // old folder placeholder -> new folder id

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
                folderId:
                    const Value(null), // Put all notes at root for simplicity
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
    this.isCompactFormat = false,
    this.hasRuntimeState = false,
    this.hasUserData = false,
    this.hasCustomItems = false,
  });

  /// Hero name
  final String name;

  /// Format version of the export
  final int formatVersion;

  /// Whether this version is compatible with the current app
  final bool isCompatible;

  /// Class ID (if found in export)
  final String? className;

  /// Ancestry ID (if found in export)
  final String? ancestryName;

  /// True if using new compact format (HS:), false for legacy (HERO:)
  final bool isCompactFormat;

  /// Whether export includes runtime state (stamina, conditions, etc.)
  final bool hasRuntimeState;

  /// Whether export includes user data (notes, projects, followers)
  final bool hasUserData;

  /// Whether export includes custom/user-created items
  final bool hasCustomItems;
}
