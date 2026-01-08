import 'package:flutter_test/flutter_test.dart';
import 'package:hero_smith/core/models/component.dart';
import 'package:hero_smith/core/services/kit_bonus_service.dart';

void main() {
  group('EquipmentBonuses', () {
    test('empty returns all zeros', () {
      const bonuses = EquipmentBonuses.empty;
      expect(bonuses.staminaBonus, equals(0));
      expect(bonuses.speedBonus, equals(0));
      expect(bonuses.stabilityBonus, equals(0));
      expect(bonuses.disengageBonus, equals(0));
      expect(bonuses.meleeDamageBonus, equals(0));
      expect(bonuses.rangedDamageBonus, equals(0));
      expect(bonuses.meleeDistanceBonus, equals(0));
      expect(bonuses.rangedDistanceBonus, equals(0));
      expect(bonuses.equipmentIds, isEmpty);
    });

    test('constructor creates instance with given values', () {
      const bonuses = EquipmentBonuses(
        staminaBonus: 3,
        speedBonus: 2,
        stabilityBonus: 1,
        disengageBonus: 1,
        meleeDamageBonus: 2,
        rangedDamageBonus: 1,
        meleeDistanceBonus: 1,
        rangedDistanceBonus: 5,
        equipmentIds: ['kit-1', 'kit-2'],
      );

      expect(bonuses.staminaBonus, equals(3));
      expect(bonuses.speedBonus, equals(2));
      expect(bonuses.stabilityBonus, equals(1));
      expect(bonuses.disengageBonus, equals(1));
      expect(bonuses.meleeDamageBonus, equals(2));
      expect(bonuses.rangedDamageBonus, equals(1));
      expect(bonuses.meleeDistanceBonus, equals(1));
      expect(bonuses.rangedDistanceBonus, equals(5));
      expect(bonuses.equipmentIds, equals(['kit-1', 'kit-2']));
    });

    test('toString formats correctly', () {
      const bonuses = EquipmentBonuses(
        staminaBonus: 3,
        speedBonus: 2,
        stabilityBonus: 1,
        disengageBonus: 1,
        meleeDamageBonus: 2,
        rangedDamageBonus: 1,
        meleeDistanceBonus: 1,
        rangedDistanceBonus: 5,
      );

      expect(bonuses.toString(), contains('stamina: 3'));
      expect(bonuses.toString(), contains('speed: 2'));
    });
  });

  group('KitBonusService', () {
    const service = KitBonusService();

    /// Helper to create a kit Component with specific bonuses
    /// Uses the actual field names expected by KitBonusService:
    /// - 'stamina_bonus', 'speed_bonus', 'stability_bonus', 'disengage_bonus'
    /// - 'melee_damage_bonus' with '1st_tier', '2nd_tier', '3rd_tier' keys
    /// - 'ranged_damage_bonus' with '1st_tier', '2nd_tier', '3rd_tier' keys
    /// - 'melee_distance_bonus' with '1st_echelon', '2nd_echelon', '3rd_echelon' keys
    /// - 'ranged_distance_bonus' with '1st_echelon', '2nd_echelon', '3rd_echelon' keys
    Component createKit({
      required String id,
      int? staminaBonus,
      int? speedBonus,
      int? stabilityBonus,
      int? disengageBonus,
      Map<String, dynamic>? meleeDamageBonus,
      Map<String, dynamic>? rangedDamageBonus,
      Map<String, dynamic>? meleeDistanceBonus,
      Map<String, dynamic>? rangedDistanceBonus,
    }) {
      return Component(
        id: id,
        type: 'kit',
        name: 'Test Kit',
        data: {
          if (staminaBonus != null) 'stamina_bonus': staminaBonus,
          if (speedBonus != null) 'speed_bonus': speedBonus,
          if (stabilityBonus != null) 'stability_bonus': stabilityBonus,
          if (disengageBonus != null) 'disengage_bonus': disengageBonus,
          if (meleeDamageBonus != null) 'melee_damage_bonus': meleeDamageBonus,
          if (rangedDamageBonus != null)
            'ranged_damage_bonus': rangedDamageBonus,
          if (meleeDistanceBonus != null)
            'melee_distance_bonus': meleeDistanceBonus,
          if (rangedDistanceBonus != null)
            'ranged_distance_bonus': rangedDistanceBonus,
        },
      );
    }

    group('calculateBonuses', () {
      test('returns empty for empty equipment list', () {
        final bonuses = service.calculateBonuses(
          equipment: [],
          heroLevel: 1,
        );

        expect(bonuses.staminaBonus, equals(0));
        expect(bonuses.speedBonus, equals(0));
        expect(bonuses.equipmentIds, isEmpty);
      });

      test('extracts stamina bonus from kit', () {
        final equipment = [createKit(id: 'kit-1', staminaBonus: 3)];

        final bonuses = service.calculateBonuses(
          equipment: equipment,
          heroLevel: 1,
        );

        // Stamina of 3 scales with level: 3 * ((1-1)~/3 + 1) = 3 * 1 = 3
        expect(bonuses.staminaBonus, equals(3));
        expect(bonuses.equipmentIds, contains('kit-1'));
      });

      test('scales stamina with level when base is 3', () {
        final equipment = [createKit(id: 'kit-1', staminaBonus: 3)];

        // Level 1-3: 1x multiplier = 3
        expect(
          service
              .calculateBonuses(equipment: equipment, heroLevel: 1)
              .staminaBonus,
          equals(3),
        );

        // Level 4-6: 2x multiplier = 6
        expect(
          service
              .calculateBonuses(equipment: equipment, heroLevel: 4)
              .staminaBonus,
          equals(6),
        );

        // Level 7-9: 3x multiplier = 9
        expect(
          service
              .calculateBonuses(equipment: equipment, heroLevel: 7)
              .staminaBonus,
          equals(9),
        );

        // Level 10: 4x multiplier = 12
        expect(
          service
              .calculateBonuses(equipment: equipment, heroLevel: 10)
              .staminaBonus,
          equals(12),
        );
      });

      test('scales stamina with level when base is 6', () {
        final equipment = [createKit(id: 'kit-1', staminaBonus: 6)];

        // Level 1-3: 1x multiplier = 6
        expect(
          service
              .calculateBonuses(equipment: equipment, heroLevel: 1)
              .staminaBonus,
          equals(6),
        );

        // Level 4-6: 2x multiplier = 12
        expect(
          service
              .calculateBonuses(equipment: equipment, heroLevel: 4)
              .staminaBonus,
          equals(12),
        );

        // Level 7-9: 3x multiplier = 18
        expect(
          service
              .calculateBonuses(equipment: equipment, heroLevel: 7)
              .staminaBonus,
          equals(18),
        );

        // Level 10: 4x multiplier = 24
        expect(
          service
              .calculateBonuses(equipment: equipment, heroLevel: 10)
              .staminaBonus,
          equals(24),
        );
      });

      test('scales stamina with level when base is 9', () {
        // Kits like Mountain have stamina 9
        final equipment = [createKit(id: 'kit-1', staminaBonus: 9)];

        // Level 1-3: 1x multiplier = 9
        expect(
          service
              .calculateBonuses(equipment: equipment, heroLevel: 1)
              .staminaBonus,
          equals(9),
        );

        // Level 4-6: 2x multiplier = 18
        expect(
          service
              .calculateBonuses(equipment: equipment, heroLevel: 4)
              .staminaBonus,
          equals(18),
        );

        // Level 7-9: 3x multiplier = 27
        expect(
          service
              .calculateBonuses(equipment: equipment, heroLevel: 7)
              .staminaBonus,
          equals(27),
        );

        // Level 10: 4x multiplier = 36
        expect(
          service
              .calculateBonuses(equipment: equipment, heroLevel: 10)
              .staminaBonus,
          equals(36),
        );
      });

      test('scales stamina with level when base is 12', () {
        // Kits like Shining Armor have stamina 12
        final equipment = [createKit(id: 'kit-1', staminaBonus: 12)];

        // Level 1-3: 1x multiplier = 12
        expect(
          service
              .calculateBonuses(equipment: equipment, heroLevel: 1)
              .staminaBonus,
          equals(12),
        );

        // Level 4-6: 2x multiplier = 24
        expect(
          service
              .calculateBonuses(equipment: equipment, heroLevel: 4)
              .staminaBonus,
          equals(24),
        );

        // Level 7-9: 3x multiplier = 36
        expect(
          service
              .calculateBonuses(equipment: equipment, heroLevel: 7)
              .staminaBonus,
          equals(36),
        );

        // Level 10: 4x multiplier = 48
        expect(
          service
              .calculateBonuses(equipment: equipment, heroLevel: 10)
              .staminaBonus,
          equals(48),
        );
      });

      test('extracts speed bonus from kit', () {
        final equipment = [createKit(id: 'kit-1', speedBonus: 2)];

        final bonuses = service.calculateBonuses(
          equipment: equipment,
          heroLevel: 1,
        );

        expect(bonuses.speedBonus, equals(2));
      });

      test('extracts stability bonus from kit', () {
        final equipment = [createKit(id: 'kit-1', stabilityBonus: 3)];

        final bonuses = service.calculateBonuses(
          equipment: equipment,
          heroLevel: 1,
        );

        expect(bonuses.stabilityBonus, equals(3));
      });

      test('extracts disengage bonus from kit', () {
        final equipment = [createKit(id: 'kit-1', disengageBonus: 1)];

        final bonuses = service.calculateBonuses(
          equipment: equipment,
          heroLevel: 1,
        );

        expect(bonuses.disengageBonus, equals(1));
      });

      test('takes highest bonus from multiple equipment', () {
        final equipment = [
          createKit(id: 'kit-1', staminaBonus: 3), // scales to 3 at level 1
          createKit(id: 'kit-2', staminaBonus: 6), // scales to 6 at level 1
          createKit(id: 'kit-3', speedBonus: 2),
        ];

        final bonuses = service.calculateBonuses(
          equipment: equipment,
          heroLevel: 1,
        );

        // Kit-2 has stamina 6 (highest)
        expect(bonuses.staminaBonus, equals(6));
        expect(bonuses.speedBonus, equals(2));
        expect(bonuses.equipmentIds, containsAll(['kit-1', 'kit-2', 'kit-3']));
      });

      test('extracts melee damage per tier', () {
        final equipment = [
          createKit(
            id: 'kit-1',
            meleeDamageBonus: {
              '1st_tier': 2,
              '2nd_tier': 4,
              '3rd_tier': 6,
            },
          ),
        ];

        // Level 1 = Tier 1
        expect(
          service
              .calculateBonuses(equipment: equipment, heroLevel: 1)
              .meleeDamageBonus,
          equals(2),
        );

        // Level 5 = Tier 2
        expect(
          service
              .calculateBonuses(equipment: equipment, heroLevel: 5)
              .meleeDamageBonus,
          equals(4),
        );

        // Level 8 = Tier 3
        expect(
          service
              .calculateBonuses(equipment: equipment, heroLevel: 8)
              .meleeDamageBonus,
          equals(6),
        );
      });

      test('extracts ranged damage per tier', () {
        final equipment = [
          createKit(
            id: 'kit-1',
            rangedDamageBonus: {
              '1st_tier': 1,
              '2nd_tier': 2,
              '3rd_tier': 3,
            },
          ),
        ];

        // Level 2 = Tier 1
        expect(
          service
              .calculateBonuses(equipment: equipment, heroLevel: 2)
              .rangedDamageBonus,
          equals(1),
        );

        // Level 6 = Tier 2
        expect(
          service
              .calculateBonuses(equipment: equipment, heroLevel: 6)
              .rangedDamageBonus,
          equals(2),
        );

        // Level 9 = Tier 3
        expect(
          service
              .calculateBonuses(equipment: equipment, heroLevel: 9)
              .rangedDamageBonus,
          equals(3),
        );
      });

      test('extracts melee distance per echelon', () {
        final equipment = [
          createKit(
            id: 'kit-1',
            meleeDistanceBonus: {
              '1st_echelon': 1,
              '2nd_echelon': 2,
              '3rd_echelon': 3,
            },
          ),
        ];

        // Level 1 = Echelon 1
        expect(
          service
              .calculateBonuses(equipment: equipment, heroLevel: 1)
              .meleeDistanceBonus,
          equals(1),
        );

        // Level 5 = Echelon 2
        expect(
          service
              .calculateBonuses(equipment: equipment, heroLevel: 5)
              .meleeDistanceBonus,
          equals(2),
        );

        // Level 8 = Echelon 3
        expect(
          service
              .calculateBonuses(equipment: equipment, heroLevel: 8)
              .meleeDistanceBonus,
          equals(3),
        );
      });

      test('extracts ranged distance per echelon', () {
        final equipment = [
          createKit(
            id: 'kit-1',
            rangedDistanceBonus: {
              '1st_echelon': 5,
              '2nd_echelon': 7,
              '3rd_echelon': 10,
            },
          ),
        ];

        // Level 3 = Echelon 1
        expect(
          service
              .calculateBonuses(equipment: equipment, heroLevel: 3)
              .rangedDistanceBonus,
          equals(5),
        );

        // Level 4 = Echelon 2
        expect(
          service
              .calculateBonuses(equipment: equipment, heroLevel: 4)
              .rangedDistanceBonus,
          equals(7),
        );

        // Level 10 = Echelon 3
        expect(
          service
              .calculateBonuses(equipment: equipment, heroLevel: 10)
              .rangedDistanceBonus,
          equals(10),
        );
      });
    });

    group('edge cases', () {
      test('handles missing data gracefully', () {
        final equipment = [
          const Component(id: 'kit-1', type: 'kit', name: 'Empty Kit'),
        ];

        final bonuses = service.calculateBonuses(
          equipment: equipment,
          heroLevel: 1,
        );

        expect(bonuses.staminaBonus, equals(0));
        expect(bonuses.speedBonus, equals(0));
        expect(bonuses.equipmentIds, contains('kit-1'));
      });

      test('handles null values gracefully', () {
        final equipment = [
          const Component(
            id: 'kit-1',
            type: 'kit',
            name: 'Null Kit',
            data: {
              'stamina_bonus': null,
              'speed_bonus': null,
            },
          ),
        ];

        final bonuses = service.calculateBonuses(
          equipment: equipment,
          heroLevel: 1,
        );

        expect(bonuses.staminaBonus, equals(0));
        expect(bonuses.speedBonus, equals(0));
      });

      test('handles string numbers in data', () {
        final equipment = [
          const Component(
            id: 'kit-1',
            type: 'kit',
            name: 'String Kit',
            data: {
              'stamina_bonus': '6',
              'speed_bonus': '2',
            },
          ),
        ];

        final bonuses = service.calculateBonuses(
          equipment: equipment,
          heroLevel: 1,
        );

        // '6' parses to 6, which scales (base 6)
        expect(bonuses.staminaBonus, equals(6));
        expect(bonuses.speedBonus, equals(2));
      });

      test('handles tiered data with missing keys', () {
        final equipment = [
          createKit(
            id: 'kit-1',
            meleeDamageBonus: {
              '1st_tier': 2,
              // Missing 2nd and 3rd tier
            },
          ),
        ];

        // Tier 1 works
        expect(
          service
              .calculateBonuses(equipment: equipment, heroLevel: 1)
              .meleeDamageBonus,
          equals(2),
        );

        // Missing tiers default to 0
        expect(
          service
              .calculateBonuses(equipment: equipment, heroLevel: 5)
              .meleeDamageBonus,
          equals(0),
        );
      });
    });

    group('tierForLevel', () {
      test('returns tier 1 for levels 1-3', () {
        expect(KitBonusService.tierForLevel(1), equals(1));
        expect(KitBonusService.tierForLevel(2), equals(1));
        expect(KitBonusService.tierForLevel(3), equals(1));
      });

      test('returns tier 2 for levels 4-6', () {
        expect(KitBonusService.tierForLevel(4), equals(2));
        expect(KitBonusService.tierForLevel(5), equals(2));
        expect(KitBonusService.tierForLevel(6), equals(2));
      });

      test('returns tier 3 for levels 7-10', () {
        expect(KitBonusService.tierForLevel(7), equals(3));
        expect(KitBonusService.tierForLevel(8), equals(3));
        expect(KitBonusService.tierForLevel(9), equals(3));
        expect(KitBonusService.tierForLevel(10), equals(3));
      });
    });

    group('echelonForLevel', () {
      test('returns echelon 1 for levels 1-3', () {
        expect(KitBonusService.echelonForLevel(1), equals(1));
        expect(KitBonusService.echelonForLevel(2), equals(1));
        expect(KitBonusService.echelonForLevel(3), equals(1));
      });

      test('returns echelon 2 for levels 4-6', () {
        expect(KitBonusService.echelonForLevel(4), equals(2));
        expect(KitBonusService.echelonForLevel(5), equals(2));
        expect(KitBonusService.echelonForLevel(6), equals(2));
      });

      test('returns echelon 3 for levels 7-10', () {
        expect(KitBonusService.echelonForLevel(7), equals(3));
        expect(KitBonusService.echelonForLevel(8), equals(3));
        expect(KitBonusService.echelonForLevel(9), equals(3));
        expect(KitBonusService.echelonForLevel(10), equals(3));
      });
    });
  });
}
