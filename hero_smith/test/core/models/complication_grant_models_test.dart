import 'package:flutter_test/flutter_test.dart';
import 'package:hero_smith/core/models/complication_grant_models.dart';

void main() {
  group('ComplicationGrant', () {
    group('parseFromGrantsData', () {
      const testComplicationId = 'complication-test';
      const testComplicationName = 'Test Complication';

      test('returns empty list for empty grants data', () {
        final grants = ComplicationGrant.parseFromGrantsData(
          {},
          testComplicationId,
          testComplicationName,
        );
        expect(grants, isEmpty);
      });

      group('skill grants', () {
        test('parses skill by name', () {
          final grants = ComplicationGrant.parseFromGrantsData(
            {
              'skills': [
                {'name': 'Stealth'},
              ],
            },
            testComplicationId,
            testComplicationName,
          );

          expect(grants.length, equals(1));
          expect(grants.first, isA<SkillGrant>());
          final skillGrant = grants.first as SkillGrant;
          expect(skillGrant.skillName, equals('Stealth'));
          expect(skillGrant.sourceComplicationId, equals(testComplicationId));
        });

        test('parses skill from group with count', () {
          final grants = ComplicationGrant.parseFromGrantsData(
            {
              'skills': [
                {'group': 'exploration', 'count': 2},
              ],
            },
            testComplicationId,
            testComplicationName,
          );

          expect(grants.length, equals(1));
          expect(grants.first, isA<SkillFromGroupGrant>());
          final skillGrant = grants.first as SkillFromGroupGrant;
          expect(skillGrant.groups, equals(['exploration']));
          expect(skillGrant.count, equals(2));
        });

        test('parses skill from options', () {
          final grants = ComplicationGrant.parseFromGrantsData(
            {
              'skills': [
                {
                  'options': ['Stealth', 'Deception', 'Thievery'],
                },
              ],
            },
            testComplicationId,
            testComplicationName,
          );

          expect(grants.length, equals(1));
          expect(grants.first, isA<SkillFromOptionsGrant>());
          final skillGrant = grants.first as SkillFromOptionsGrant;
          expect(
            skillGrant.options,
            equals(['Stealth', 'Deception', 'Thievery']),
          );
        });

        test('parses single skill object (not list)', () {
          final grants = ComplicationGrant.parseFromGrantsData(
            {
              'skills': {'group': 'any', 'count': 1},
            },
            testComplicationId,
            testComplicationName,
          );

          expect(grants.length, equals(1));
          expect(grants.first, isA<SkillFromGroupGrant>());
          final skillGrant = grants.first as SkillFromGroupGrant;
          expect(skillGrant.groups, equals(['any']));
          expect(skillGrant.count, equals(1));
        });

        test('parses multiple skills from list', () {
          final grants = ComplicationGrant.parseFromGrantsData(
            {
              'skills': [
                {'name': 'Stealth'},
                {'name': 'Deception'},
              ],
            },
            testComplicationId,
            testComplicationName,
          );

          expect(grants.length, equals(2));
          expect(grants[0], isA<SkillGrant>());
          expect(grants[1], isA<SkillGrant>());
          expect((grants[0] as SkillGrant).skillName, equals('Stealth'));
          expect((grants[1] as SkillGrant).skillName, equals('Deception'));
        });
      });

      group('ability grants', () {
        test('parses ability by name', () {
          final grants = ComplicationGrant.parseFromGrantsData(
            {
              'abilities': [
                {'name': 'Dark Vision'},
              ],
            },
            testComplicationId,
            testComplicationName,
          );

          expect(grants.length, equals(1));
          expect(grants.first, isA<AbilityGrant>());
          final abilityGrant = grants.first as AbilityGrant;
          expect(abilityGrant.abilityName, equals('Dark Vision'));
        });

        test('parses ability by id', () {
          final grants = ComplicationGrant.parseFromGrantsData(
            {
              'abilities': [
                {'id': 'dark-vision'},
              ],
            },
            testComplicationId,
            testComplicationName,
          );

          expect(grants.length, equals(1));
          expect(grants.first, isA<AbilityGrant>());
          final abilityGrant = grants.first as AbilityGrant;
          // Note: AbilityGrant stores the name, parsing converts id to name
          expect(abilityGrant.abilityName, equals('dark-vision'));
        });
      });

      group('token grants', () {
        test('parses simple token grant', () {
          final grants = ComplicationGrant.parseFromGrantsData(
            {
              'tokens': [
                {'name': 'Heroic Token', 'count': 2},
              ],
            },
            testComplicationId,
            testComplicationName,
          );

          expect(grants.length, equals(1));
          expect(grants.first, isA<TokenGrant>());
          final tokenGrant = grants.first as TokenGrant;
          expect(tokenGrant.tokenType, equals('Heroic Token'));
          expect(tokenGrant.count, equals(2));
        });
      });

      group('language grants', () {
        test('parses language count as integer', () {
          final grants = ComplicationGrant.parseFromGrantsData(
            {
              'languages': 2,
            },
            testComplicationId,
            testComplicationName,
          );

          expect(grants.length, equals(1));
          expect(grants.first, isA<LanguageGrant>());
          final langGrant = grants.first as LanguageGrant;
          expect(langGrant.count, equals(2));
        });

        test('parses language with dead language option', () {
          final grants = ComplicationGrant.parseFromGrantsData(
            {
              'languages': {
                'count': 1,
                'can_be_dead': true,
              },
            },
            testComplicationId,
            testComplicationName,
          );

          expect(grants.length, equals(1));
          expect(grants.first, isA<DeadLanguageGrant>());
        });
      });

      group('stat modification grants', () {
        test('parses increase_total single value', () {
          final grants = ComplicationGrant.parseFromGrantsData(
            {
              'increase_total': {
                'stat': 'corruption',
                'type': 'weakness',
                'value': 5,
              },
            },
            testComplicationId,
            testComplicationName,
          );

          expect(grants.length, equals(1));
          expect(grants.first, isA<IncreaseTotalGrant>());
          final statGrant = grants.first as IncreaseTotalGrant;
          expect(statGrant.stat, equals('corruption'));
          expect(statGrant.type, equals('weakness'));
          expect(statGrant.value, equals(5));
        });

        test('parses increase_total list of values', () {
          final grants = ComplicationGrant.parseFromGrantsData(
            {
              'increase_total': [
                {'stat': 'fire', 'type': 'immunity', 'value': 1},
                {'stat': 'cold', 'type': 'resistance', 'value': 2},
              ],
            },
            testComplicationId,
            testComplicationName,
          );

          expect(grants.length, equals(2));
          expect(grants[0], isA<IncreaseTotalGrant>());
          expect(grants[1], isA<IncreaseTotalGrant>());
          expect((grants[0] as IncreaseTotalGrant).stat, equals('fire'));
          expect((grants[1] as IncreaseTotalGrant).stat, equals('cold'));
        });

        test('parses decrease_total', () {
          final grants = ComplicationGrant.parseFromGrantsData(
            {
              'decrease_total': {
                'stat': 'stamina',
                'value': 3,
              },
            },
            testComplicationId,
            testComplicationName,
          );

          expect(grants.length, equals(1));
          expect(grants.first, isA<DecreaseTotalGrant>());
          final statGrant = grants.first as DecreaseTotalGrant;
          expect(statGrant.stat, equals('stamina'));
          expect(statGrant.value, equals(3));
        });

        test('parses increase_total_per_echelon', () {
          final grants = ComplicationGrant.parseFromGrantsData(
            {
              'increase_total_per_echelon': {
                'stat': 'stamina',
                'base_value': 2,
                'per_echelon': 1,
              },
            },
            testComplicationId,
            testComplicationName,
          );

          expect(grants.length, equals(1));
          expect(grants.first, isA<IncreaseTotalPerEchelonGrant>());
        });
      });

      group('treasure grants', () {
        test('parses simple treasure grant', () {
          final grants = ComplicationGrant.parseFromGrantsData(
            {
              'treasures': [
                {'name': 'Magic Sword'},
              ],
            },
            testComplicationId,
            testComplicationName,
          );

          expect(grants.length, equals(1));
          expect(grants.first, isA<TreasureGrant>());
          final treasureGrant = grants.first as TreasureGrant;
          expect(treasureGrant.treasureType, equals('Magic Sword'));
        });

        test('parses leveled treasure grant', () {
          final grants = ComplicationGrant.parseFromGrantsData(
            {
              'treasures': [
                {
                  'leveled': true,
                  'category': 'weapon',
                },
              ],
            },
            testComplicationId,
            testComplicationName,
          );

          expect(grants.length, equals(1));
          expect(grants.first, isA<LeveledTreasureGrant>());
          final treasureGrant = grants.first as LeveledTreasureGrant;
          expect(treasureGrant.category, equals('weapon'));
        });
      });

      group('set_base_stat_if_not_already_lower', () {
        test('parses set base stat grant', () {
          final grants = ComplicationGrant.parseFromGrantsData(
            {
              'set_base_stat_if_not_already_lower': {
                'stat': 'speed',
                'value': 5,
              },
            },
            testComplicationId,
            testComplicationName,
          );

          expect(grants.length, equals(1));
          expect(grants.first, isA<SetBaseStatIfNotLowerGrant>());
          final statGrant = grants.first as SetBaseStatIfNotLowerGrant;
          expect(statGrant.stat, equals('speed'));
          expect(statGrant.value, equals(5));
        });
      });

      group('ancestry_traits', () {
        test('parses ancestry traits grant', () {
          final grants = ComplicationGrant.parseFromGrantsData(
            {
              'ancestry_traits': {
                'ancestry': 'human',
                'ancestry_points': 2,
              },
            },
            testComplicationId,
            testComplicationName,
          );

          expect(grants.length, equals(1));
          expect(grants.first, isA<AncestryTraitsGrant>());
          final traitGrant = grants.first as AncestryTraitsGrant;
          expect(traitGrant.ancestry, equals('human'));
          expect(traitGrant.ancestryPoints, equals(2));
        });
      });

      group('pick_one', () {
        test('parses pick_one grant with options', () {
          final grants = ComplicationGrant.parseFromGrantsData(
            {
              'pick_one': [
                {
                  'label': 'Option A',
                  'increase_total': {'stat': 'might', 'value': 1},
                },
                {
                  'label': 'Option B',
                  'increase_total': {'stat': 'agility', 'value': 1},
                },
              ],
            },
            testComplicationId,
            testComplicationName,
          );

          // Should have PickOneGrant (no selection made)
          expect(grants.length, equals(1));
          expect(grants.first, isA<PickOneGrant>());
          final pickGrant = grants.first as PickOneGrant;
          expect(pickGrant.options.length, equals(2));
          expect(pickGrant.selectedIndex, isNull);
        });

        test('applies selected option grants when choice is provided', () {
          final choices = {
            '${testComplicationId}_pick_one': '0',
          };
          final grants = ComplicationGrant.parseFromGrantsData(
            {
              'pick_one': [
                {
                  'label': 'Option A',
                  'increase_total': {'stat': 'might', 'value': 1},
                },
                {
                  'label': 'Option B',
                  'increase_total': {'stat': 'agility', 'value': 1},
                },
              ],
            },
            testComplicationId,
            testComplicationName,
            choices,
          );

          // Should have PickOneGrant + IncreaseTotalGrant from selected option
          expect(grants.length, equals(2));
          expect(grants[0], isA<PickOneGrant>());
          expect(grants[1], isA<IncreaseTotalGrant>());
          final pickGrant = grants[0] as PickOneGrant;
          expect(pickGrant.selectedIndex, equals(0));
          final statGrant = grants[1] as IncreaseTotalGrant;
          expect(statGrant.stat, equals('might'));
        });
      });

      group('feature grants', () {
        test('parses feature grant', () {
          final grants = ComplicationGrant.parseFromGrantsData(
            {
              'features': [
                {'name': 'Mount', 'description': 'You have a loyal mount'},
              ],
            },
            testComplicationId,
            testComplicationName,
          );

          expect(grants.length, equals(1));
          expect(grants.first, isA<FeatureGrant>());
          final featureGrant = grants.first as FeatureGrant;
          expect(featureGrant.featureName, equals('Mount'));
        });
      });

      group('increase_recovery', () {
        test('parses increase recovery grant', () {
          final grants = ComplicationGrant.parseFromGrantsData(
            {
              'increase_recovery': {
                'value': '+2',
              },
            },
            testComplicationId,
            testComplicationName,
          );

          expect(grants.length, equals(1));
          expect(grants.first, isA<IncreaseRecoveryGrant>());
          final recoveryGrant = grants.first as IncreaseRecoveryGrant;
          expect(recoveryGrant.value, equals('+2'));
        });
      });

      group('complex combinations', () {
        test('parses multiple grant types in single data', () {
          final grants = ComplicationGrant.parseFromGrantsData(
            {
              'skills': [
                {'name': 'Stealth'},
              ],
              'abilities': [
                {'name': 'Dark Vision'},
              ],
              'increase_total': {
                'stat': 'perception',
                'type': 'bonus',
                'value': 1,
              },
              'languages': 1,
            },
            testComplicationId,
            testComplicationName,
          );

          // Should have 4 grants: 1 skill + 1 ability + 1 stat + 1 language
          expect(grants.length, equals(4));
          expect(grants.whereType<SkillGrant>().length, equals(1));
          expect(grants.whereType<AbilityGrant>().length, equals(1));
          expect(grants.whereType<IncreaseTotalGrant>().length, equals(1));
          expect(grants.whereType<LanguageGrant>().length, equals(1));
        });
      });
    });

    group('JSON serialization', () {
      test('SkillGrant round-trips through JSON', () {
        const original = SkillGrant(
          sourceComplicationId: 'test-comp',
          sourceComplicationName: 'Test',
          skillName: 'Stealth',
        );

        final json = original.toJson();
        final restored = ComplicationGrant.fromJson(json);

        expect(restored, isA<SkillGrant>());
        final restoredGrant = restored as SkillGrant;
        expect(restoredGrant.skillName, equals(original.skillName));
        expect(
          restoredGrant.sourceComplicationId,
          equals(original.sourceComplicationId),
        );
      });

      test('IncreaseTotalGrant round-trips through JSON', () {
        const original = IncreaseTotalGrant(
          sourceComplicationId: 'test-comp',
          sourceComplicationName: 'Test',
          stat: 'fire',
          damageType: 'immunity',
          value: 5,
        );

        final json = original.toJson();
        final restored = ComplicationGrant.fromJson(json);

        expect(restored, isA<IncreaseTotalGrant>());
        final restoredGrant = restored as IncreaseTotalGrant;
        expect(restoredGrant.stat, equals(original.stat));
        expect(restoredGrant.damageType, equals(original.damageType));
        expect(restoredGrant.value, equals(original.value));
      });
    });
  });

  group('Grant Types', () {
    test('ComplicationGrantType has all expected types', () {
      // Verify enum has the expected grant types
      expect(ComplicationGrantType.values, contains(ComplicationGrantType.skill));
      expect(
        ComplicationGrantType.values,
        contains(ComplicationGrantType.skillFromGroup),
      );
      expect(
        ComplicationGrantType.values,
        contains(ComplicationGrantType.ability),
      );
      expect(
        ComplicationGrantType.values,
        contains(ComplicationGrantType.treasure),
      );
      expect(ComplicationGrantType.values, contains(ComplicationGrantType.token));
      expect(
        ComplicationGrantType.values,
        contains(ComplicationGrantType.language),
      );
      expect(
        ComplicationGrantType.values,
        contains(ComplicationGrantType.increaseTotal),
      );
      expect(
        ComplicationGrantType.values,
        contains(ComplicationGrantType.decreaseTotal),
      );
      expect(
        ComplicationGrantType.values,
        contains(ComplicationGrantType.pickOne),
      );
      expect(
        ComplicationGrantType.values,
        contains(ComplicationGrantType.feature),
      );
    });
  });
}
