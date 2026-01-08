import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hero_smith/core/models/stat_modification_model.dart';

void main() {
  group('StatModification sealed class hierarchy', () {
    group('StaticStatModification', () {
      test('returns fixed value regardless of level', () {
        const mod = StaticStatModification(value: 5, source: 'Test');
        
        expect(mod.getActualValue(1), equals(5));
        expect(mod.getActualValue(5), equals(5));
        expect(mod.getActualValue(10), equals(5));
      });

      test('isDynamic returns false', () {
        const mod = StaticStatModification(value: 3, source: 'Test');
        expect(mod.isDynamic, isFalse);
      });

      test('baseValue returns the value', () {
        const mod = StaticStatModification(value: 7, source: 'Test');
        expect(mod.baseValue, equals(7));
      });

      test('toJson serializes correctly', () {
        const mod = StaticStatModification(value: 5, source: 'Ancestry');
        final json = mod.toJson();
        
        expect(json['value'], equals(5));
        expect(json['source'], equals('Ancestry'));
        expect(json.containsKey('dynamicValue'), isFalse);
        expect(json.containsKey('perEchelon'), isFalse);
      });

      test('equality works correctly', () {
        const mod1 = StaticStatModification(value: 5, source: 'Test');
        const mod2 = StaticStatModification(value: 5, source: 'Test');
        const mod3 = StaticStatModification(value: 5, source: 'Other');
        const mod4 = StaticStatModification(value: 3, source: 'Test');
        
        expect(mod1, equals(mod2));
        expect(mod1, isNot(equals(mod3)));
        expect(mod1, isNot(equals(mod4)));
      });

      test('supports negative values', () {
        const mod = StaticStatModification(value: -3, source: 'Curse');
        
        expect(mod.getActualValue(1), equals(-3));
        expect(mod.baseValue, equals(-3));
      });
    });

    group('LevelScaledStatModification', () {
      test('returns hero level as value', () {
        const mod = LevelScaledStatModification(source: 'Mundane');
        
        expect(mod.getActualValue(1), equals(1));
        expect(mod.getActualValue(5), equals(5));
        expect(mod.getActualValue(10), equals(10));
      });

      test('isDynamic returns true', () {
        const mod = LevelScaledStatModification(source: 'Test');
        expect(mod.isDynamic, isTrue);
      });

      test('baseValue returns 0', () {
        const mod = LevelScaledStatModification(source: 'Test');
        expect(mod.baseValue, equals(0));
      });

      test('toJson serializes with dynamicValue=level', () {
        const mod = LevelScaledStatModification(source: 'Mundane');
        final json = mod.toJson();
        
        expect(json['value'], equals(0));
        expect(json['source'], equals('Mundane'));
        expect(json['dynamicValue'], equals('level'));
      });

      test('equality works correctly', () {
        const mod1 = LevelScaledStatModification(source: 'Test');
        const mod2 = LevelScaledStatModification(source: 'Test');
        const mod3 = LevelScaledStatModification(source: 'Other');
        
        expect(mod1, equals(mod2));
        expect(mod1, isNot(equals(mod3)));
      });
    });

    group('EchelonScaledStatModification', () {
      test('returns valuePerEchelon × echelon for level 1 (echelon 1)', () {
        const mod = EchelonScaledStatModification(valuePerEchelon: 3, source: 'Elemental Inside');
        expect(mod.getActualValue(1), equals(3));
      });

      test('returns valuePerEchelon × echelon for level 3 (echelon 1)', () {
        const mod = EchelonScaledStatModification(valuePerEchelon: 3, source: 'Test');
        expect(mod.getActualValue(3), equals(3));
      });

      test('returns valuePerEchelon × echelon for level 4 (echelon 2)', () {
        const mod = EchelonScaledStatModification(valuePerEchelon: 3, source: 'Test');
        expect(mod.getActualValue(4), equals(6));
      });

      test('returns valuePerEchelon × echelon for level 7 (echelon 3)', () {
        const mod = EchelonScaledStatModification(valuePerEchelon: 3, source: 'Test');
        expect(mod.getActualValue(7), equals(9));
      });

      test('returns valuePerEchelon × echelon for level 10 (echelon 4)', () {
        const mod = EchelonScaledStatModification(valuePerEchelon: 3, source: 'Test');
        expect(mod.getActualValue(10), equals(12));
      });

      test('isDynamic returns true', () {
        const mod = EchelonScaledStatModification(valuePerEchelon: 3, source: 'Test');
        expect(mod.isDynamic, isTrue);
      });

      test('baseValue returns valuePerEchelon', () {
        const mod = EchelonScaledStatModification(valuePerEchelon: 6, source: 'Test');
        expect(mod.baseValue, equals(6));
      });

      test('toJson serializes with perEchelon=true', () {
        const mod = EchelonScaledStatModification(
          valuePerEchelon: 3,
          source: 'Elemental Inside',
        );
        final json = mod.toJson();
        
        expect(json['value'], equals(0));
        expect(json['source'], equals('Elemental Inside'));
        expect(json['perEchelon'], isTrue);
        expect(json['valuePerEchelon'], equals(3));
      });

      test('equality works correctly', () {
        const mod1 = EchelonScaledStatModification(valuePerEchelon: 3, source: 'Test');
        const mod2 = EchelonScaledStatModification(valuePerEchelon: 3, source: 'Test');
        const mod3 = EchelonScaledStatModification(valuePerEchelon: 6, source: 'Test');
        const mod4 = EchelonScaledStatModification(valuePerEchelon: 3, source: 'Other');
        
        expect(mod1, equals(mod2));
        expect(mod1, isNot(equals(mod3)));
        expect(mod1, isNot(equals(mod4)));
      });
    });

    group('StatModification.fromJson', () {
      test('creates StaticStatModification for basic JSON', () {
        final json = {'value': 5, 'source': 'Ancestry'};
        final mod = StatModification.fromJson(json);
        
        expect(mod, isA<StaticStatModification>());
        expect(mod.getActualValue(1), equals(5));
        expect(mod.source, equals('Ancestry'));
      });

      test('creates LevelScaledStatModification when dynamicValue=level', () {
        final json = {'value': 0, 'source': 'Mundane', 'dynamicValue': 'level'};
        final mod = StatModification.fromJson(json);
        
        expect(mod, isA<LevelScaledStatModification>());
        expect(mod.getActualValue(5), equals(5));
        expect(mod.source, equals('Mundane'));
      });

      test('creates EchelonScaledStatModification when perEchelon=true', () {
        final json = {
          'value': 0,
          'source': 'Elemental Inside',
          'perEchelon': true,
          'valuePerEchelon': 3,
        };
        final mod = StatModification.fromJson(json);
        
        expect(mod, isA<EchelonScaledStatModification>());
        expect(mod.getActualValue(4), equals(6)); // echelon 2 × 3
        expect(mod.source, equals('Elemental Inside'));
      });

      test('uses defaultSource when source is missing', () {
        final json = {'value': 5};
        final mod = StatModification.fromJson(json, defaultSource: 'Default');
        
        expect(mod.source, equals('Default'));
      });

      test('uses Unknown when source and defaultSource are missing', () {
        final json = {'value': 5};
        final mod = StatModification.fromJson(json);
        
        expect(mod.source, equals('Unknown'));
      });
    });

    group('Factory constructors', () {
      test('StatModification.static creates StaticStatModification', () {
        final mod = StatModification.static(value: 5, source: 'Test');
        
        expect(mod, isA<StaticStatModification>());
        expect(mod.getActualValue(1), equals(5));
      });

      test('StatModification.levelScaled creates LevelScaledStatModification', () {
        final mod = StatModification.levelScaled(source: 'Test');
        
        expect(mod, isA<LevelScaledStatModification>());
        expect(mod.getActualValue(5), equals(5));
      });

      test('StatModification.echelonScaled creates EchelonScaledStatModification', () {
        final mod = StatModification.echelonScaled(valuePerEchelon: 3, source: 'Test');
        
        expect(mod, isA<EchelonScaledStatModification>());
        expect(mod.getActualValue(4), equals(6));
      });
    });

    group('Serialization roundtrip', () {
      test('StaticStatModification survives JSON roundtrip', () {
        const original = StaticStatModification(value: 5, source: 'Ancestry');
        final json = original.toJson();
        final restored = StatModification.fromJson(json);
        
        expect(restored, isA<StaticStatModification>());
        expect(restored, equals(original));
      });

      test('LevelScaledStatModification survives JSON roundtrip', () {
        const original = LevelScaledStatModification(source: 'Mundane');
        final json = original.toJson();
        final restored = StatModification.fromJson(json);
        
        expect(restored, isA<LevelScaledStatModification>());
        expect(restored, equals(original));
      });

      test('EchelonScaledStatModification survives JSON roundtrip', () {
        const original = EchelonScaledStatModification(
          valuePerEchelon: 3,
          source: 'Elemental Inside',
        );
        final json = original.toJson();
        final restored = StatModification.fromJson(json);
        
        expect(restored, isA<EchelonScaledStatModification>());
        expect(restored, equals(original));
      });
    });
  });

  group('HeroStatModifications', () {
    test('fromJsonString parses list of modifications', () {
      final json = jsonEncode({
        'might': [
          {'value': 2, 'source': 'Ancestry'},
          {'value': 1, 'source': 'Culture'},
        ],
      });
      
      final mods = HeroStatModifications.fromJsonString(json);
      
      expect(mods.hasModsForStat('might'), isTrue);
      expect(mods.getModsForStat('might').length, equals(2));
    });

    test('getTotalForStat sums baseValues', () {
      final json = jsonEncode({
        'might': [
          {'value': 2, 'source': 'Ancestry'},
          {'value': 1, 'source': 'Culture'},
        ],
      });
      
      final mods = HeroStatModifications.fromJsonString(json);
      
      expect(mods.getTotalForStat('might'), equals(3));
    });

    test('getTotalForStatAtLevel respects dynamic scaling', () {
      final json = jsonEncode({
        'stamina': [
          {'value': 0, 'source': 'Elemental Inside', 'perEchelon': true, 'valuePerEchelon': 3},
        ],
      });
      
      final mods = HeroStatModifications.fromJsonString(json);
      
      // Level 1 (echelon 1): 3 × 1 = 3
      expect(mods.getTotalForStatAtLevel('stamina', 1), equals(3));
      // Level 4 (echelon 2): 3 × 2 = 6
      expect(mods.getTotalForStatAtLevel('stamina', 4), equals(6));
      // Level 7 (echelon 3): 3 × 3 = 9
      expect(mods.getTotalForStatAtLevel('stamina', 7), equals(9));
      // Level 10 (echelon 4): 3 × 4 = 12
      expect(mods.getTotalForStatAtLevel('stamina', 10), equals(12));
    });

    test('getSourcesDescription formats correctly at different levels', () {
      final json = jsonEncode({
        'stamina': [
          {'value': 0, 'source': 'Elemental Inside', 'perEchelon': true, 'valuePerEchelon': 3},
        ],
      });
      
      final mods = HeroStatModifications.fromJsonString(json);
      
      // Should include "(scales with echelon)" suffix from pattern matching
      expect(mods.getSourcesDescription('stamina', 1), equals('+3 from Elemental Inside (scales with echelon)'));
      expect(mods.getSourcesDescription('stamina', 7), equals('+9 from Elemental Inside (scales with echelon)'));
    });

    test('getSourcesDescription shows scaling type for each mod type', () {
      final json = jsonEncode({
        'might': [
          {'value': 2, 'source': 'Ancestry'},
        ],
        'stamina': [
          {'value': 0, 'source': 'Level Bonus', 'dynamicValue': 'level'},
        ],
        'speed': [
          {'value': 0, 'source': 'Echelon Bonus', 'perEchelon': true, 'valuePerEchelon': 1},
        ],
      });
      
      final mods = HeroStatModifications.fromJsonString(json);
      
      // Static mod - no suffix
      expect(mods.getSourcesDescription('might', 5), equals('+2 from Ancestry'));
      // Level-scaled mod - shows "(scales with level)"
      expect(mods.getSourcesDescription('stamina', 5), equals('+5 from Level Bonus (scales with level)'));
      // Echelon-scaled mod - shows "(scales with echelon)"
      expect(mods.getSourcesDescription('speed', 5), equals('+2 from Echelon Bonus (scales with echelon)'));
    });

    test('withModification adds static modification', () {
      const mods = HeroStatModifications.empty();
      final updated = mods.withModification('might', 2, 'Test');
      
      expect(updated.hasModsForStat('might'), isTrue);
      expect(updated.getTotalForStat('might'), equals(2));
      expect(updated.getModsForStat('might').first, isA<StaticStatModification>());
    });

    test('removeSource removes all mods from source', () {
      final json = jsonEncode({
        'might': [
          {'value': 2, 'source': 'Ancestry'},
          {'value': 1, 'source': 'Culture'},
        ],
      });
      
      final mods = HeroStatModifications.fromJsonString(json);
      final updated = mods.removeSource('Ancestry');
      
      expect(updated.getModsForStat('might').length, equals(1));
      expect(updated.getModsForStat('might').first.source, equals('Culture'));
    });

    test('toJsonString produces parseable output', () {
      const mods = HeroStatModifications(modifications: {
        'might': [StaticStatModification(value: 2, source: 'Test')],
      });
      
      final jsonString = mods.toJsonString();
      final restored = HeroStatModifications.fromJsonString(jsonString);
      
      expect(restored.getTotalForStat('might'), equals(2));
    });

    test('handles legacy numeric format', () {
      final json = jsonEncode({
        'might': 2,
      });
      
      final mods = HeroStatModifications.fromJsonString(json);
      
      expect(mods.hasModsForStat('might'), isTrue);
      expect(mods.getTotalForStat('might'), equals(2));
    });
  });

  group('Pattern matching (exhaustiveness)', () {
    test('switch expression covers all cases', () {
      StatModification mod = const StaticStatModification(value: 5, source: 'Test');
      
      // This should compile without warnings because the switch is exhaustive
      final description = switch (mod) {
        StaticStatModification(:final value) => 'Static: $value',
        LevelScaledStatModification() => 'Level-scaled',
        EchelonScaledStatModification(:final valuePerEchelon) => 'Echelon: $valuePerEchelon per',
      };
      
      expect(description, equals('Static: 5'));
    });

    test('pattern matching extracts correct values', () {
      final mods = <StatModification>[
        const StaticStatModification(value: 5, source: 'A'),
        const LevelScaledStatModification(source: 'B'),
        const EchelonScaledStatModification(valuePerEchelon: 3, source: 'C'),
      ];
      
      final descriptions = mods.map((mod) => switch (mod) {
        StaticStatModification(:final value, :final source) => '$source: static $value',
        LevelScaledStatModification(:final source) => '$source: level',
        EchelonScaledStatModification(:final valuePerEchelon, :final source) => '$source: $valuePerEchelon/echelon',
      }).toList();
      
      expect(descriptions[0], equals('A: static 5'));
      expect(descriptions[1], equals('B: level'));
      expect(descriptions[2], equals('C: 3/echelon'));
    });
  });
}
