import 'dart:convert';

/// Represents a tracked damage resistance (immunity or weakness) for a specific damage type.
/// Immunities and weaknesses are additive: if you have 5 immunity and 3 weakness,
/// the net result is 2 immunity.
class DamageResistance {
  const DamageResistance({
    required this.damageType,
    this.baseImmunity = 0,
    this.baseWeakness = 0,
    this.bonusImmunity = 0,
    this.bonusWeakness = 0,
    this.sources = const [],
  });

  /// The damage type (e.g., "fire", "cold", "corruption", "psychic")
  final String damageType;

  /// Base immunity value (manually set by user)
  final int baseImmunity;

  /// Base weakness value (manually set by user)
  final int baseWeakness;

  /// Bonus immunity from ancestry traits or other sources (calculated)
  final int bonusImmunity;

  /// Bonus weakness from ancestry traits or other sources (calculated)
  final int bonusWeakness;

  /// List of sources contributing to this resistance (trait names, etc.)
  final List<String> sources;

  /// Total immunity before netting against weakness
  int get totalImmunity => baseImmunity + bonusImmunity;

  /// Total weakness before netting against immunity
  int get totalWeakness => baseWeakness + bonusWeakness;

  /// Net resistance value. Positive = immunity, Negative = weakness
  int get netValue => totalImmunity - totalWeakness;

  /// Whether this results in immunity (net positive)
  bool get hasImmunity => netValue > 0;

  /// Whether this results in weakness (net negative)
  bool get hasWeakness => netValue < 0;

  /// Display string for the net value
  String get displayValue {
    final net = netValue;
    if (net > 0) return 'Immunity $net';
    if (net < 0) return 'Weakness ${net.abs()}';
    return 'None';
  }

  DamageResistance copyWith({
    String? damageType,
    int? baseImmunity,
    int? baseWeakness,
    int? bonusImmunity,
    int? bonusWeakness,
    List<String>? sources,
  }) {
    return DamageResistance(
      damageType: damageType ?? this.damageType,
      baseImmunity: baseImmunity ?? this.baseImmunity,
      baseWeakness: baseWeakness ?? this.baseWeakness,
      bonusImmunity: bonusImmunity ?? this.bonusImmunity,
      bonusWeakness: bonusWeakness ?? this.bonusWeakness,
      sources: sources ?? this.sources,
    );
  }

  Map<String, dynamic> toJson() => {
        'damageType': damageType,
        'baseImmunity': baseImmunity,
        'baseWeakness': baseWeakness,
        'bonusImmunity': bonusImmunity,
        'bonusWeakness': bonusWeakness,
        'sources': sources,
      };

  factory DamageResistance.fromJson(Map<String, dynamic> json) {
    return DamageResistance(
      damageType: json['damageType'] as String? ?? '',
      baseImmunity: (json['baseImmunity'] as num?)?.toInt() ?? 0,
      baseWeakness: (json['baseWeakness'] as num?)?.toInt() ?? 0,
      bonusImmunity: (json['bonusImmunity'] as num?)?.toInt() ?? 0,
      bonusWeakness: (json['bonusWeakness'] as num?)?.toInt() ?? 0,
      sources: (json['sources'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

/// Container for all damage resistances for a hero.
class HeroDamageResistances {
  const HeroDamageResistances({
    required this.resistances,
  });

  final List<DamageResistance> resistances;

  /// Get resistance for a specific damage type, or null if not tracked.
  DamageResistance? forType(String damageType) {
    final normalized = damageType.toLowerCase();
    return resistances.cast<DamageResistance?>().firstWhere(
          (r) => r!.damageType.toLowerCase() == normalized,
          orElse: () => null,
        );
  }

  /// Get all types that have any immunity or weakness
  List<DamageResistance> get activeResistances {
    return resistances.where((r) => r.netValue != 0).toList();
  }

  /// Add or update a resistance for a damage type
  HeroDamageResistances upsertResistance(DamageResistance resistance) {
    final normalized = resistance.damageType.toLowerCase();
    final updated = List<DamageResistance>.from(resistances);
    final index = updated.indexWhere(
      (r) => r.damageType.toLowerCase() == normalized,
    );
    if (index >= 0) {
      updated[index] = resistance;
    } else {
      updated.add(resistance);
    }
    return HeroDamageResistances(resistances: updated);
  }

  /// Remove a resistance by damage type
  HeroDamageResistances removeResistance(String damageType) {
    final normalized = damageType.toLowerCase();
    return HeroDamageResistances(
      resistances: resistances
          .where((r) => r.damageType.toLowerCase() != normalized)
          .toList(),
    );
  }

  /// Merge bonus values from ancestry/traits while preserving base values
  HeroDamageResistances applyBonuses(Map<String, DamageResistanceBonus> bonuses) {
    final updated = <DamageResistance>[];
    final processed = <String>{};

    // Update existing resistances
    for (final existing in resistances) {
      final key = existing.damageType.toLowerCase();
      processed.add(key);
      final bonus = bonuses[key];
      if (bonus != null) {
        updated.add(existing.copyWith(
          bonusImmunity: bonus.immunity,
          bonusWeakness: bonus.weakness,
          sources: bonus.sources,
        ));
      } else {
        // Keep existing but clear bonus values
        updated.add(existing.copyWith(
          bonusImmunity: 0,
          bonusWeakness: 0,
          sources: const [],
        ));
      }
    }

    // Add new damage types from bonuses that weren't in existing resistances
    for (final entry in bonuses.entries) {
      if (!processed.contains(entry.key)) {
        updated.add(DamageResistance(
          damageType: entry.value.damageType,
          bonusImmunity: entry.value.immunity,
          bonusWeakness: entry.value.weakness,
          sources: entry.value.sources,
        ));
      }
    }

    return HeroDamageResistances(resistances: updated);
  }

  Map<String, dynamic> toJson() => {
        'resistances': resistances.map((r) => r.toJson()).toList(),
      };

  factory HeroDamageResistances.fromJson(Map<String, dynamic> json) {
    final list = json['resistances'] as List?;
    return HeroDamageResistances(
      resistances: list
              ?.map((r) => DamageResistance.fromJson(r as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory HeroDamageResistances.fromJsonString(String jsonString) {
    return HeroDamageResistances.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }

  static const empty = HeroDamageResistances(resistances: []);
}

/// Intermediate structure for accumulating bonuses from multiple sources
class DamageResistanceBonus {
  DamageResistanceBonus({
    required this.damageType,
    this.immunity = 0,
    this.weakness = 0,
    List<String>? sources,
  }) : sources = sources ?? [];

  final String damageType;
  int immunity;
  int weakness;
  final List<String> sources;

  void addImmunity(int value, String source) {
    immunity += value;
    if (!sources.contains(source)) {
      sources.add(source);
    }
  }

  void addWeakness(int value, String source) {
    weakness += value;
    if (!sources.contains(source)) {
      sources.add(source);
    }
  }
}

/// Standard damage types in the system
class DamageTypes {
  DamageTypes._();

  static const String acid = 'acid';
  static const String cold = 'cold';
  static const String corruption = 'corruption';
  static const String fire = 'fire';
  static const String holy = 'holy';
  static const String lightning = 'lightning';
  static const String poison = 'poison';
  static const String psychic = 'psychic';
  static const String sonic = 'sonic';

  static const List<String> all = [
    acid,
    cold,
    corruption,
    fire,
    holy,
    lightning,
    poison,
    psychic,
    sonic,
  ];

  static String displayName(String type) {
    return type.substring(0, 1).toUpperCase() + type.substring(1);
  }
}
