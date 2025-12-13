import 'dart:convert';

/// Represents a single stat modification with its source.
/// 
/// Supports both static values and dynamic values that scale with level:
/// - `value`: The base static value
/// - `dynamicValue`: If set to "level", the value equals the hero level
/// - `perEchelon`: If true, the value is multiplied by the echelon (levels 1-3 = 1, 4-6 = 2, 7-9 = 3, 10 = 4)
/// - `valuePerEchelon`: When `perEchelon` is true, this is the value added per echelon
class StatModification {
  final int value;
  final String source;
  final String? dynamicValue;
  final bool perEchelon;
  final int valuePerEchelon;

  const StatModification({
    required this.value,
    required this.source,
    this.dynamicValue,
    this.perEchelon = false,
    this.valuePerEchelon = 0,
  });

  /// Calculate the actual value based on the hero's level.
  int getActualValue(int heroLevel) {
    // Dynamic value based on level
    if (dynamicValue == 'level') {
      return heroLevel;
    }
    // Per-echelon scaling (levels 1, 4, 7, 10 add the value)
    if (perEchelon && valuePerEchelon > 0) {
      final echelon = ((heroLevel - 1) ~/ 3) + 1;
      return valuePerEchelon * echelon;
    }
    return value;
  }

  /// Whether this modification has dynamic scaling
  bool get isDynamic => dynamicValue != null || perEchelon;

  factory StatModification.fromJson(
    Map<String, dynamic> json, {
    String? defaultSource,
  }) {
    return StatModification(
      value: (json['value'] as num?)?.toInt() ?? 0,
      source: json['source'] as String? ?? defaultSource ?? 'Unknown',
      dynamicValue: json['dynamicValue'] as String?,
      perEchelon: json['perEchelon'] as bool? ?? false,
      valuePerEchelon: (json['valuePerEchelon'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'value': value,
    'source': source,
    if (dynamicValue != null) 'dynamicValue': dynamicValue,
    if (perEchelon) 'perEchelon': perEchelon,
    if (valuePerEchelon > 0) 'valuePerEchelon': valuePerEchelon,
  };

  StatModification copyWith({
    int? value,
    String? source,
    String? dynamicValue,
    bool? perEchelon,
    int? valuePerEchelon,
  }) {
    return StatModification(
      value: value ?? this.value,
      source: source ?? this.source,
      dynamicValue: dynamicValue ?? this.dynamicValue,
      perEchelon: perEchelon ?? this.perEchelon,
      valuePerEchelon: valuePerEchelon ?? this.valuePerEchelon,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StatModification &&
          value == other.value &&
          source == other.source &&
          dynamicValue == other.dynamicValue &&
          perEchelon == other.perEchelon &&
          valuePerEchelon == other.valuePerEchelon;

  @override
  int get hashCode => Object.hash(value, source, dynamicValue, perEchelon, valuePerEchelon);

  @override
  String toString() => 'StatModification(value: $value, source: $source, dynamicValue: $dynamicValue, perEchelon: $perEchelon, valuePerEchelon: $valuePerEchelon)';
}

/// Collection of all stat modifications for a hero.
class HeroStatModifications {
  final Map<String, List<StatModification>> modifications;

  const HeroStatModifications({required this.modifications});

  const HeroStatModifications.empty() : modifications = const {};

  factory HeroStatModifications.fromJsonString(String jsonString) {
    try {
      final json = jsonDecode(jsonString);
      if (json is! Map) return const HeroStatModifications.empty();
      
      final mods = <String, List<StatModification>>{};
      for (final entry in json.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        
        if (value is List) {
          // New format: list of modifications
          mods[key] = value
              .whereType<Map<String, dynamic>>()
              .map((e) => StatModification.fromJson(e))
              .toList();
        } else if (value is Map) {
          // Single modification format
          mods[key] = [StatModification.fromJson(value as Map<String, dynamic>)];
        } else if (value is num) {
          // Legacy format: just a number (no source info)
          mods[key] = [StatModification(value: value.toInt(), source: 'Ancestry')];
        }
      }
      return HeroStatModifications(modifications: mods);
    } catch (_) {
      return const HeroStatModifications.empty();
    }
  }

  String toJsonString() {
    final map = <String, dynamic>{};
    for (final entry in modifications.entries) {
      map[entry.key] = entry.value.map((m) => m.toJson()).toList();
    }
    return jsonEncode(map);
  }

  /// Get total modification value for a stat.
  int getTotalForStat(String stat) {
    final mods = modifications[stat.toLowerCase()];
    if (mods == null || mods.isEmpty) return 0;
    return mods.fold(0, (sum, m) => sum + m.value);
  }

  /// Get total modification value for a stat, calculating dynamic values based on hero level.
  int getTotalForStatAtLevel(String stat, int heroLevel) {
    final mods = modifications[stat.toLowerCase()];
    if (mods == null || mods.isEmpty) return 0;
    return mods.fold(0, (sum, m) => sum + m.getActualValue(heroLevel));
  }

  /// Get all modifications for a stat.
  List<StatModification> getModsForStat(String stat) {
    return modifications[stat.toLowerCase()] ?? [];
  }

  /// Check if any modifications exist for a stat.
  bool hasModsForStat(String stat) {
    final mods = modifications[stat.toLowerCase()];
    return mods != null && mods.isNotEmpty;
  }

  /// Get a formatted string of all sources for a stat.
  String getSourcesDescription(String stat, [int heroLevel = 1]) {
    final mods = getModsForStat(stat);
    if (mods.isEmpty) return '';
    
    return mods.map((m) {
      final actualValue = m.getActualValue(heroLevel);
      final sign = actualValue >= 0 ? '+' : '';
      return '$sign$actualValue from ${m.source}';
    }).join(', ');
  }

  /// Add or update a modification.
  HeroStatModifications withModification(
    String stat,
    int value,
    String source,
  ) {
    final key = stat.toLowerCase();
    final currentMods = List<StatModification>.from(modifications[key] ?? []);
    
    // Find existing mod from this source and update it
    final existingIndex = currentMods.indexWhere((m) => m.source == source);
    if (existingIndex >= 0) {
      currentMods[existingIndex] = StatModification(value: value, source: source);
    } else {
      currentMods.add(StatModification(value: value, source: source));
    }
    
    return HeroStatModifications(
      modifications: {
        ...modifications,
        key: currentMods,
      },
    );
  }

  /// Remove all modifications from a specific source.
  HeroStatModifications removeSource(String source) {
    final newMods = <String, List<StatModification>>{};
    
    for (final entry in modifications.entries) {
      final filtered = entry.value.where((m) => m.source != source).toList();
      if (filtered.isNotEmpty) {
        newMods[entry.key] = filtered;
      }
    }
    
    return HeroStatModifications(modifications: newMods);
  }

  /// Clear all modifications.
  HeroStatModifications clear() => const HeroStatModifications.empty();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeroStatModifications &&
          _mapsEqual(modifications, other.modifications);

  static bool _mapsEqual(
    Map<String, List<StatModification>> a,
    Map<String, List<StatModification>> b,
  ) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      final listA = a[key]!;
      final listB = b[key]!;
      if (listA.length != listB.length) return false;
      for (var i = 0; i < listA.length; i++) {
        if (listA[i] != listB[i]) return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(
    modifications.entries.map((e) => Object.hash(e.key, Object.hashAll(e.value))),
  );
}
