import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/component.dart';
import '../models/characteristics_models.dart';

class AbilityLibrary {
  AbilityLibrary(this._index, this._componentsById);

  final Map<String, Component> _index;
  final Map<String, Component> _componentsById;

  Iterable<Component> get components => _componentsById.values;

  Component? find(String reference) {
    final key = _normalizeAbilityKey(reference);
    if (key.isEmpty) return null;
    return _index[key];
  }

  Component? byId(String id) {
    if (id.isEmpty) return null;
    return _componentsById[id];
  }

  bool get isEmpty => _componentsById.isEmpty;
}

class AbilityDataService {
  AbilityDataService._();

  static final AbilityDataService _instance = AbilityDataService._();

  factory AbilityDataService() => _instance;

  AbilityLibrary? _cachedLibrary;
  final Map<String, List<Component>> _classAbilityCache = {};

  static const List<String> _abilityAssetPaths = [
    'data/abilities/abilities.json',
    'data/abilities/ancestry_abilities.json',
    'data/abilities/complication_abilities.json',
    'data/abilities/item_enhancement_abilities.json',
    'data/abilities/kit_abilities.json',
    'data/abilities/perk_abilities.json',
    'data/abilities/titles_abilities.json',
    'data/abilities/treasure_abilities.json',
  ];
  static const String _classAbilityAssetPrefix =
      'data/abilities/class_abilities_new/';

  Future<AbilityLibrary> loadLibrary() async {
    if (_cachedLibrary != null) {
      return _cachedLibrary!;
    }

    final index = <String, Component>{};
    final byId = <String, Component>{};

    for (final path in _abilityAssetPaths) {
      await _ingestAbilityAsset(path, index, byId);
    }

    final classAbilityPaths = await _resolveClassAbilityAssets();
    for (final path in classAbilityPaths) {
      await _ingestAbilityAsset(path, index, byId);
    }

    final library = AbilityLibrary(
      Map.unmodifiable(index),
      Map.unmodifiable(byId),
    );
    _cachedLibrary = library;
    _classAbilityCache.clear();
    return library;
  }

  Future<List<Component>> loadClassAbilities(String classSlug) async {
    final normalizedSlug = classSlug.trim().toLowerCase();
    if (normalizedSlug.isEmpty) return const [];

    final cached = _classAbilityCache[normalizedSlug];
    if (cached != null) {
      return cached;
    }

    final library = await loadLibrary();
    final components = library.components.where((component) {
      final slug = component.data['class_slug'];
      if (slug is String && slug.trim().toLowerCase() == normalizedSlug) {
        return true;
      }
      final path = component.data['ability_source_path'];
      if (path is String &&
          path.startsWith(_classAbilityAssetPrefix) &&
          path
              .substring(_classAbilityAssetPrefix.length)
              .toLowerCase()
              .startsWith('$normalizedSlug/')) {
        return true;
      }
      return false;
    }).toList(growable: false);

    components.sort((a, b) {
      final levelA = (componentLevel(a) ?? 0);
      final levelB = (componentLevel(b) ?? 0);
      if (levelA != levelB) {
        return levelA.compareTo(levelB);
      }
      return a.name.compareTo(b.name);
    });

    final result = List<Component>.unmodifiable(components);
    _classAbilityCache[normalizedSlug] = result;
    return result;
  }

  int? componentLevel(Component component) {
    final value = component.data['level'];
    if (value is num) return value.toInt();
    return CharacteristicUtils.toIntOrNull(value);
  }

  Future<void> _ingestAbilityAsset(
    String path,
    Map<String, Component> index,
    Map<String, Component> byId,
  ) async {
    try {
      final raw = await rootBundle.loadString(path);
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) {
            final component = _parseComponent(item, sourcePath: path);
            if (component != null) {
              _registerComponent(index, byId, component);
            }
          }
        }
      } else if (decoded is Map) {
        // Check if this is a single component (has 'type' field) or a collection
        if (decoded['type'] != null) {
          // Single component file (new format)
          final component = _parseComponent(decoded, sourcePath: path);
          if (component != null) {
            _registerComponent(index, byId, component);
          }
        } else {
          // Collection of components (old format)
          for (final mapEntry in decoded.entries) {
            final value = mapEntry.value;
            if (value is Map) {
              final merged = Map<String, dynamic>.from(value);
              merged['id'] ??= mapEntry.key;
              final component = _parseComponent(merged, sourcePath: path);
              if (component != null) {
                _registerComponent(index, byId, component);
              }
            }
          }
        }
      }
    } catch (error) {
      // Surface the asset path to simplify debugging without failing silently.
      throw Exception('Failed to load ability asset "$path": $error');
    }
  }

  Component? _parseComponent(dynamic raw, {required String sourcePath}) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);

    final nameRaw = map['name'];
    final name = _cleanString(nameRaw);
    final idRaw = map['id'];
    final id = _extractId(idRaw, fallback: name);
    if (id == null) return null;

    map.remove('id');
    map.remove('type');
    map.remove('name');

    final data = Map<String, dynamic>.from(map);

    final componentName = name.isNotEmpty ? name : _titleFromIdentifier(id);

    final derived = _buildDerivedMetadata(
      sourcePath: sourcePath,
      baseId: id,
      data: data,
      componentName: componentName,
    );

    return Component(
      id: derived.id,
      type: 'ability',
      name: componentName,
      data: derived.data,
      source: 'seed',
    );
  }

  Future<List<String>> _resolveClassAbilityAssets() async {
    try {
      final manifestRaw = await rootBundle.loadString('AssetManifest.json');
      final decoded = jsonDecode(manifestRaw);
      final paths = <String>{};

      void addPath(dynamic candidate) {
        if (candidate is! String) return;
        if (!candidate.startsWith(_classAbilityAssetPrefix)) return;
        if (!candidate.endsWith('.json')) return;
        paths.add(candidate);
      }

      if (decoded is Map) {
        for (final entry in decoded.entries) {
          addPath(entry.key);
          if (entry.value is List) {
            for (final variant in entry.value as List) {
              addPath(variant);
            }
          }
        }
      } else if (decoded is List) {
        for (final entry in decoded) {
          addPath(entry);
        }
      }

      final sorted = paths.toList()..sort();
      return sorted;
    } catch (error) {
      throw Exception('Unable to resolve class ability assets: $error');
    }
  }

  _DerivedComponentMetadata _buildDerivedMetadata({
    required String sourcePath,
    required String baseId,
    required Map<String, dynamic> data,
    required String componentName,
  }) {
    final normalizedPath = sourcePath.replaceAll('\\', '/');
    final augmented = Map<String, dynamic>.from(data);
    augmented['original_id'] ??= baseId;
    augmented['ability_source_path'] ??= normalizedPath;

    String resolvedId = baseId;

    if (normalizedPath.startsWith(_classAbilityAssetPrefix)) {
      final relative =
          normalizedPath.substring(_classAbilityAssetPrefix.length);
      final segments = relative.split('/');
      final classSegment = segments.isNotEmpty ? segments.first.trim() : null;
      final levelSegment = segments.length >= 2 ? segments[1].trim() : null;

      final classSlug = classSegment != null ? _slugify(classSegment) : null;
      if (classSlug != null && classSlug.isNotEmpty) {
        augmented['class_slug'] ??= classSlug;
        augmented['class_name'] ??= classSegment;
      }
      if (levelSegment != null && levelSegment.isNotEmpty) {
        augmented['level_band'] ??= levelSegment;
      }

      final costs = augmented['costs'];
      String? resourceSlug;
      String? costAmountSlug;
      if (costs is Map) {
        final resource = costs['resource'];
        if (resource is String && resource.trim().isNotEmpty) {
          resourceSlug = _slugify(resource);
        }
        final amount = costs['amount'];
        if (amount != null) {
          costAmountSlug = 'cost${amount.toString()}';
        }
      }

      final parts = <String>[
        'ability',
        if (classSlug != null && classSlug.isNotEmpty) classSlug,
        if (levelSegment != null && levelSegment.isNotEmpty)
          _slugify(levelSegment),
        if (resourceSlug != null && resourceSlug.isNotEmpty) resourceSlug,
        if (costAmountSlug != null) costAmountSlug,
        baseId,
      ];

      resolvedId = parts.where((element) => element.isNotEmpty).join('_');
      augmented['display_name'] ??= componentName;
    }

    augmented['resolved_id'] ??= resolvedId;

    return _DerivedComponentMetadata(
      id: resolvedId,
      data: augmented,
    );
  }

  void _registerComponent(
    Map<String, Component> index,
    Map<String, Component> byId,
    Component component,
  ) {
    byId[component.id] = component;

    void addKey(String? value) {
      if (value == null) return;
      final normalized = _normalizeAbilityKey(value);
      if (normalized.isEmpty) return;
      index.putIfAbsent(normalized, () => component);
      index.putIfAbsent(normalized.replaceAll('_', ''), () => component);
    }

    addKey(component.id);
    addKey(component.name);
    addKey(component.id.replaceAll('_', ' '));
    addKey(component.name.replaceAll('-', ' '));
  }
}

class _DerivedComponentMetadata {
  const _DerivedComponentMetadata({
    required this.id,
    required this.data,
  });

  final String id;
  final Map<String, dynamic> data;
}

String _normalizeAbilityKey(String value) {
  final trimmed = value.trim().toLowerCase();
  if (trimmed.isEmpty) return '';
  final normalized = trimmed.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  final collapsed = normalized.replaceAll(RegExp(r'_+'), '_');
  return collapsed.replaceAll(RegExp(r'^_|_$'), '');
}

String? _extractId(dynamic value, {String? fallback}) {
  final id = _cleanString(value);
  if (id.isNotEmpty) return id;
  if (fallback != null && fallback.isNotEmpty) {
    return _slugify(fallback);
  }
  return null;
}

String _cleanString(dynamic value) {
  if (value == null) return '';
  final str = value.toString().trim();
  return str;
}

String _slugify(String value) {
  final lower = value.trim().toLowerCase();
  if (lower.isEmpty) return '';
  final slug = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  return slug.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
}

String _titleFromIdentifier(String id) {
  final parts = id.split(RegExp(r'[_\s-]+')).where((part) => part.isNotEmpty);
  return parts
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}
