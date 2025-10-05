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
    'data/abilities/class_abilities/censor_abilities.json',
    'data/abilities/class_abilities/conduit_abilities.json',
    'data/abilities/class_abilities/elementalist_abilities.json',
    'data/abilities/class_abilities/fury_abilities.json',
    'data/abilities/class_abilities/null_abilities.json',
    'data/abilities/class_abilities/shadow_abilities.json',
    'data/abilities/class_abilities/tactician_abilities.json',
    'data/abilities/class_abilities/talent_abilities.json',
    'data/abilities/class_abilities/troubadour_abilities.json',
  ];

  Future<AbilityLibrary> loadLibrary() async {
    if (_cachedLibrary != null) {
      return _cachedLibrary!;
    }

    final index = <String, Component>{};
    final byId = <String, Component>{};

    for (final path in _abilityAssetPaths) {
      try {
        final raw = await rootBundle.loadString(path);
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final entry in decoded) {
            final component = _parseComponent(entry, sourcePath: path);
            if (component != null) {
              _registerComponent(index, byId, component);
            }
          }
        } else if (decoded is Map) {
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
      } catch (e) {
        rethrow;
      }
    }

    final library = AbilityLibrary(
      Map.unmodifiable(index),
      Map.unmodifiable(byId),
    );
    _cachedLibrary = library;
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
    final prefix = 'ability_${normalizedSlug}_';
    final components = library.components.where((component) {
      final idLower = component.id.toLowerCase();
      if (idLower.startsWith(prefix)) return true;
      // Some data uses double underscore after slug (e.g., ability_null__foo)
      final altPrefix = 'ability_${normalizedSlug}__';
      if (idLower.startsWith(altPrefix)) return true;
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

    return Component(
      id: id,
      type: 'ability',
      name: componentName,
      data: data,
      source: 'seed',
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
