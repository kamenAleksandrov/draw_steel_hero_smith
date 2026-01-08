import 'package:flutter_test/flutter_test.dart';
import 'package:hero_smith/core/models/damage_resistance_model.dart';

void main() {
  group('DamageResistanceBonus', () {
    group('addImmunity', () {
      test('adds immunity values', () {
        final bonus = DamageResistanceBonus(damageType: 'fire');
        bonus.addImmunity(5, 'ancestry_dragon');
        bonus.addImmunity(3, 'complication_curse');

        expect(bonus.damageType, equals('fire'));
        expect(bonus.immunity, equals(8));
        expect(bonus.weakness, equals(0));
        expect(bonus.sources, containsAll(['ancestry_dragon', 'complication_curse']));
      });

      test('does not duplicate sources', () {
        final bonus = DamageResistanceBonus(damageType: 'fire');
        bonus.addImmunity(5, 'ancestry_dragon');
        bonus.addImmunity(3, 'ancestry_dragon');

        expect(bonus.immunity, equals(8));
        expect(bonus.sources.length, equals(1));
        expect(bonus.sources, contains('ancestry_dragon'));
      });
    });

    group('addWeakness', () {
      test('adds weakness values', () {
        final bonus = DamageResistanceBonus(damageType: 'cold');
        bonus.addWeakness(2, 'complication_curse');
        bonus.addWeakness(3, 'kit_shadow');

        expect(bonus.damageType, equals('cold'));
        expect(bonus.immunity, equals(0));
        expect(bonus.weakness, equals(5));
        expect(bonus.sources, containsAll(['complication_curse', 'kit_shadow']));
      });
    });

    group('addImmunityPerEchelon', () {
      test('adds echelon scaling', () {
        final bonus = DamageResistanceBonus(damageType: 'fire');
        bonus.addImmunityPerEchelon(2, 'ancestry_dragon');
        bonus.addImmunityPerEchelon(1, 'kit_flame');

        expect(bonus.immunityPerEchelon, equals(3));
        expect(bonus.sources, containsAll(['ancestry_dragon', 'kit_flame']));
      });
    });

    group('setDynamicImmunity', () {
      test('sets dynamic immunity value', () {
        final bonus = DamageResistanceBonus(damageType: 'fire');
        bonus.setDynamicImmunity('level', 'trait_fireborn');

        expect(bonus.dynamicImmunity, equals('level'));
        expect(bonus.sources, contains('trait_fireborn'));
      });

      test('overwrites previous dynamic immunity', () {
        final bonus = DamageResistanceBonus(damageType: 'fire');
        bonus.setDynamicImmunity('level', 'trait_a');
        bonus.setDynamicImmunity('might', 'trait_b');

        expect(bonus.dynamicImmunity, equals('might'));
      });
    });

    group('setDynamicWeakness', () {
      test('sets dynamic weakness value', () {
        final bonus = DamageResistanceBonus(damageType: 'cold');
        bonus.setDynamicWeakness('level', 'curse_frost');

        expect(bonus.dynamicWeakness, equals('level'));
        expect(bonus.sources, contains('curse_frost'));
      });
    });

    group('addWeaknessPerEchelon', () {
      test('adds echelon scaling for weakness', () {
        final bonus = DamageResistanceBonus(damageType: 'cold');
        bonus.addWeaknessPerEchelon(1, 'curse_frost');
        bonus.addWeaknessPerEchelon(2, 'curse_ice');

        expect(bonus.weaknessPerEchelon, equals(3));
      });
    });
  });

  group('DamageResistance', () {
    group('totalImmunityAtLevel', () {
      test('returns base + bonus immunity for static values', () {
        final resistance = DamageResistance(
          damageType: 'fire',
          baseImmunity: 5,
          bonusImmunity: 3,
        );

        expect(resistance.totalImmunityAtLevel(1), equals(8));
        expect(resistance.totalImmunityAtLevel(10), equals(8));
      });

      test('adds level when dynamicImmunity is "level"', () {
        final resistance = DamageResistance(
          damageType: 'fire',
          baseImmunity: 5,
          dynamicImmunity: 'level',
        );

        expect(resistance.totalImmunityAtLevel(1), equals(6)); // 5 + 1
        expect(resistance.totalImmunityAtLevel(5), equals(10)); // 5 + 5
        expect(resistance.totalImmunityAtLevel(10), equals(15)); // 5 + 10
      });

      test('scales with echelon when immunityPerEchelon is set', () {
        final resistance = DamageResistance(
          damageType: 'fire',
          baseImmunity: 5,
          immunityPerEchelon: 2,
        );

        // Level 1 = echelon 1: 5 + 2*1 = 7
        expect(resistance.totalImmunityAtLevel(1), equals(7));
        // Level 4 = echelon 2: 5 + 2*2 = 9
        expect(resistance.totalImmunityAtLevel(4), equals(9));
        // Level 7 = echelon 3: 5 + 2*3 = 11
        expect(resistance.totalImmunityAtLevel(7), equals(11));
        // Level 10 = echelon 4: 5 + 2*4 = 13
        expect(resistance.totalImmunityAtLevel(10), equals(13));
      });
    });

    group('totalWeaknessAtLevel', () {
      test('returns base + bonus weakness for static values', () {
        final resistance = DamageResistance(
          damageType: 'cold',
          baseWeakness: 3,
          bonusWeakness: 2,
        );

        expect(resistance.totalWeaknessAtLevel(1), equals(5));
      });

      test('scales with echelon when weaknessPerEchelon is set', () {
        final resistance = DamageResistance(
          damageType: 'cold',
          baseWeakness: 3,
          weaknessPerEchelon: 1,
        );

        // Level 7 = echelon 3: 3 + 1*3 = 6
        expect(resistance.totalWeaknessAtLevel(7), equals(6));
      });
    });
  });
}
