import 'package:flutter_test/flutter_test.dart';
import 'package:hero_smith/core/models/ancestry_bonus_models.dart';

void main() {
  group('AncestryBonus', () {
    group('parseFromTraitData', () {
      const testTraitId = 'trait-test';
      const testTraitName = 'Test Trait';

      test('returns empty list for empty trait data', () {
        final bonuses = AncestryBonus.parseFromTraitData(
          {},
          testTraitId,
          testTraitName,
        );
        expect(bonuses, isEmpty);
      });

      group('set_base_stat_if_not_already_higher', () {
        test('parses stat and value', () {
          final bonuses = AncestryBonus.parseFromTraitData(
            {
              'set_base_stat_if_not_already_higher': {
                'stat': 'speed',
                'value': 6,
              },
            },
            testTraitId,
            testTraitName,
          );

          expect(bonuses.length, equals(1));
          expect(bonuses.first, isA<SetBaseStatBonus>());
          final bonus = bonuses.first as SetBaseStatBonus;
          expect(bonus.stat, equals('speed'));
          expect(bonus.value, equals('6'));
          expect(bonus.sourceTraitId, equals(testTraitId));
          expect(bonus.sourceTraitName, equals(testTraitName));
        });

        test('handles string value like "1L"', () {
          final bonuses = AncestryBonus.parseFromTraitData(
            {
              'set_base_stat_if_not_already_higher': {
                'stat': 'size',
                'value': '1L',
              },
            },
            testTraitId,
            testTraitName,
          );

          expect(bonuses.length, equals(1));
          final bonus = bonuses.first as SetBaseStatBonus;
          expect(bonus.value, equals('1L'));
        });
      });

      group('grants_ability_name', () {
        test('parses single ability name as string', () {
          final bonuses = AncestryBonus.parseFromTraitData(
            {
              'grants_ability_name': 'Barbed Tail',
            },
            testTraitId,
            testTraitName,
          );

          expect(bonuses.length, equals(1));
          expect(bonuses.first, isA<GrantsAbilityBonus>());
          final bonus = bonuses.first as GrantsAbilityBonus;
          expect(bonus.abilityNames, equals(['Barbed Tail']));
        });

        test('parses multiple ability names as list', () {
          final bonuses = AncestryBonus.parseFromTraitData(
            {
              'grants_ability_name': ['Vengeance Mark', 'Detonate Sigil'],
            },
            testTraitId,
            testTraitName,
          );

          expect(bonuses.length, equals(1));
          final bonus = bonuses.first as GrantsAbilityBonus;
          expect(
            bonus.abilityNames,
            equals(['Vengeance Mark', 'Detonate Sigil']),
          );
        });

        test('parses ability_name key (alternative to grants_ability_name)', () {
          final bonuses = AncestryBonus.parseFromTraitData(
            {
              'ability_name': 'Dark Vision',
            },
            testTraitId,
            testTraitName,
          );

          expect(bonuses.length, equals(1));
          expect(bonuses.first, isA<GrantsAbilityBonus>());
          final bonus = bonuses.first as GrantsAbilityBonus;
          expect(bonus.abilityNames, equals(['Dark Vision']));
        });

        test('ignores empty ability name', () {
          final bonuses = AncestryBonus.parseFromTraitData(
            {
              'grants_ability_name': '',
            },
            testTraitId,
            testTraitName,
          );

          expect(bonuses, isEmpty);
        });
      });

      group('increase_total_per_echelon', () {
        test('parses stat and value per echelon', () {
          final bonuses = AncestryBonus.parseFromTraitData(
            {
              'increase_total_per_echelon': {
                'stat': 'stamina',
                'value': 3,
              },
            },
            testTraitId,
            testTraitName,
          );

          expect(bonuses.length, equals(1));
          expect(bonuses.first, isA<IncreaseTotalPerEchelonBonus>());
          final bonus = bonuses.first as IncreaseTotalPerEchelonBonus;
          expect(bonus.stat, equals('stamina'));
          expect(bonus.valuePerEchelon, equals(3));
        });
      });

      group('increase_total', () {
        test('parses single increase_total as map', () {
          final bonuses = AncestryBonus.parseFromTraitData(
            {
              'increase_total': {
                'stat': 'fire',
                'type': 'immunity',
                'value': 1,
              },
            },
            testTraitId,
            testTraitName,
          );

          expect(bonuses.length, equals(1));
          expect(bonuses.first, isA<IncreaseTotalBonus>());
          final bonus = bonuses.first as IncreaseTotalBonus;
          expect(bonus.stat, equals('fire'));
          expect(bonus.damageTypes, equals(['immunity']));
          expect(bonus.value, equals('1'));
        });

        test('parses list of increase_total', () {
          final bonuses = AncestryBonus.parseFromTraitData(
            {
              'increase_total': [
                {'stat': 'fire', 'type': 'immunity', 'value': 1},
                {'stat': 'cold', 'type': 'weakness', 'value': 2},
              ],
            },
            testTraitId,
            testTraitName,
          );

          expect(bonuses.length, equals(2));
          expect(bonuses[0], isA<IncreaseTotalBonus>());
          expect(bonuses[1], isA<IncreaseTotalBonus>());
          expect((bonuses[0] as IncreaseTotalBonus).stat, equals('fire'));
          expect((bonuses[1] as IncreaseTotalBonus).stat, equals('cold'));
        });

        test('handles pick_one type with no choice', () {
          final bonuses = AncestryBonus.parseFromTraitData(
            {
              'increase_total': {
                'stat': 'damage',
                'type': 'pick_one',
                'value': 5,
              },
            },
            testTraitId,
            testTraitName,
          );

          // No choice made, so no bonus created
          expect(bonuses, isEmpty);
        });

        test('handles pick_one type with choice provided', () {
          final bonuses = AncestryBonus.parseFromTraitData(
            {
              'increase_total': {
                'stat': 'damage',
                'type': 'pick_one',
                'value': 5,
              },
            },
            testTraitId,
            testTraitName,
            {testTraitId: 'fire'}, // User chose fire
          );

          expect(bonuses.length, equals(1));
          final bonus = bonuses.first as IncreaseTotalBonus;
          expect(bonus.stat, equals('damage'));
          expect(bonus.damageTypes, equals(['fire']));
        });

        test('handles multiple damage types as list', () {
          final bonuses = AncestryBonus.parseFromTraitData(
            {
              'increase_total': {
                'stat': 'resistance',
                'type': ['fire', 'cold'],
                'value': 5,
              },
            },
            testTraitId,
            testTraitName,
          );

          expect(bonuses.length, equals(1));
          final bonus = bonuses.first as IncreaseTotalBonus;
          expect(bonus.damageTypes, equals(['fire', 'cold']));
        });
      });

      group('decrease_total', () {
        test('parses stat and value', () {
          final bonuses = AncestryBonus.parseFromTraitData(
            {
              'decrease_total': {
                'stat': 'speed',
                'value': 1,
              },
            },
            testTraitId,
            testTraitName,
          );

          expect(bonuses.length, equals(1));
          expect(bonuses.first, isA<DecreaseTotalBonus>());
          final bonus = bonuses.first as DecreaseTotalBonus;
          expect(bonus.stat, equals('speed'));
          expect(bonus.value, equals(1));
        });
      });

      group('condition_immunity', () {
        test('parses condition name as string', () {
          final bonuses = AncestryBonus.parseFromTraitData(
            {
              'condition_immunity': 'Frightened',
            },
            testTraitId,
            testTraitName,
          );

          expect(bonuses.length, equals(1));
          expect(bonuses.first, isA<ConditionImmunityBonus>());
          final bonus = bonuses.first as ConditionImmunityBonus;
          expect(bonus.conditionName, equals('Frightened'));
        });
      });

      group('pick_ability_name', () {
        test('parses ability options without selection', () {
          final bonuses = AncestryBonus.parseFromTraitData(
            {
              'pick_ability_name': ['Fly', 'Teleport', 'Burrow'],
            },
            testTraitId,
            testTraitName,
          );

          expect(bonuses.length, equals(1));
          expect(bonuses.first, isA<PickAbilityBonus>());
          final bonus = bonuses.first as PickAbilityBonus;
          expect(bonus.abilityOptions, equals(['Fly', 'Teleport', 'Burrow']));
          expect(bonus.selectedAbilityName, isNull);
        });

        test('parses ability options with selection', () {
          final bonuses = AncestryBonus.parseFromTraitData(
            {
              'pick_ability_name': ['Fly', 'Teleport', 'Burrow'],
            },
            testTraitId,
            testTraitName,
            {testTraitId: 'Fly'},
          );

          // Should have PickAbilityBonus + GrantsAbilityBonus for selection
          expect(bonuses.length, equals(2));
          expect(bonuses[0], isA<PickAbilityBonus>());
          expect(bonuses[1], isA<GrantsAbilityBonus>());

          final pickBonus = bonuses[0] as PickAbilityBonus;
          expect(pickBonus.selectedAbilityName, equals('Fly'));

          final grantBonus = bonuses[1] as GrantsAbilityBonus;
          expect(grantBonus.abilityNames, equals(['Fly']));
        });
      });

      group('complex combinations', () {
        test('parses multiple bonus types from single trait', () {
          final bonuses = AncestryBonus.parseFromTraitData(
            {
              'set_base_stat_if_not_already_higher': {'stat': 'speed', 'value': 6},
              'grants_ability_name': 'Dark Vision',
              'condition_immunity': 'Poisoned',
            },
            testTraitId,
            testTraitName,
          );

          expect(bonuses.length, equals(3));
          expect(bonuses.whereType<SetBaseStatBonus>().length, equals(1));
          expect(bonuses.whereType<GrantsAbilityBonus>().length, equals(1));
          expect(bonuses.whereType<ConditionImmunityBonus>().length, equals(1));
        });
      });
    });

    group('JSON serialization', () {
      test('SetBaseStatBonus round-trips through JSON', () {
        const original = SetBaseStatBonus(
          sourceTraitId: 'trait-1',
          sourceTraitName: 'Fast',
          stat: 'speed',
          value: '6',
        );

        final json = original.toJson();
        final restored = AncestryBonus.fromJson(json);

        expect(restored, isA<SetBaseStatBonus>());
        final restoredBonus = restored as SetBaseStatBonus;
        expect(restoredBonus.stat, equals(original.stat));
        expect(restoredBonus.value, equals(original.value));
      });

      test('GrantsAbilityBonus round-trips through JSON', () {
        const original = GrantsAbilityBonus(
          sourceTraitId: 'trait-1',
          sourceTraitName: 'Tail Attack',
          abilityNames: ['Barbed Tail', 'Tail Sweep'],
        );

        final json = original.toJson();
        final restored = AncestryBonus.fromJson(json);

        expect(restored, isA<GrantsAbilityBonus>());
        final restoredBonus = restored as GrantsAbilityBonus;
        expect(restoredBonus.abilityNames, equals(original.abilityNames));
      });

      test('ConditionImmunityBonus round-trips through JSON', () {
        const original = ConditionImmunityBonus(
          sourceTraitId: 'trait-1',
          sourceTraitName: 'Fearless',
          conditionName: 'Frightened',
        );

        final json = original.toJson();
        final restored = AncestryBonus.fromJson(json);

        expect(restored, isA<ConditionImmunityBonus>());
        final restoredBonus = restored as ConditionImmunityBonus;
        expect(restoredBonus.conditionName, equals(original.conditionName));
      });

      test('IncreaseTotalBonus round-trips through JSON', () {
        const original = IncreaseTotalBonus(
          sourceTraitId: 'trait-1',
          sourceTraitName: 'Fire Immunity',
          stat: 'fire',
          value: '5',
          damageTypes: ['immunity'],
        );

        final json = original.toJson();
        final restored = AncestryBonus.fromJson(json);

        expect(restored, isA<IncreaseTotalBonus>());
        final restoredBonus = restored as IncreaseTotalBonus;
        expect(restoredBonus.stat, equals(original.stat));
        expect(restoredBonus.value, equals(original.value));
        expect(restoredBonus.damageTypes, equals(original.damageTypes));
      });

      test('DecreaseTotalBonus round-trips through JSON', () {
        const original = DecreaseTotalBonus(
          sourceTraitId: 'trait-1',
          sourceTraitName: 'Slow',
          stat: 'speed',
          value: 1,
        );

        final json = original.toJson();
        final restored = AncestryBonus.fromJson(json);

        expect(restored, isA<DecreaseTotalBonus>());
        final restoredBonus = restored as DecreaseTotalBonus;
        expect(restoredBonus.stat, equals(original.stat));
        expect(restoredBonus.value, equals(original.value));
      });
    });
  });

  group('AncestryBonusType', () {
    test('has all expected types', () {
      expect(
        AncestryBonusType.values,
        contains(AncestryBonusType.setBaseStatIfNotAlreadyHigher),
      );
      expect(
        AncestryBonusType.values,
        contains(AncestryBonusType.grantsAbilityName),
      );
      expect(
        AncestryBonusType.values,
        contains(AncestryBonusType.increaseTotalPerEchelon),
      );
      expect(
        AncestryBonusType.values,
        contains(AncestryBonusType.increaseTotal),
      );
      expect(
        AncestryBonusType.values,
        contains(AncestryBonusType.decreaseTotal),
      );
      expect(
        AncestryBonusType.values,
        contains(AncestryBonusType.conditionImmunity),
      );
      expect(
        AncestryBonusType.values,
        contains(AncestryBonusType.pickAbilityName),
      );
    });
  });
}
