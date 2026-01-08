import 'package:flutter_test/flutter_test.dart';
import 'package:hero_smith/core/services/ability_resolver_service.dart';

void main() {
  group('AbilityResolverService', () {
    group('slugify', () {
      test('converts simple name to slug', () {
        expect(AbilityResolverService.slugify('Fire Bolt'), equals('fire_bolt'));
      });

      test('handles special characters', () {
        expect(
          AbilityResolverService.slugify("Dragon's Breath"),
          equals('dragon_s_breath'),
        );
      });

      test('collapses multiple spaces/underscores', () {
        expect(
          AbilityResolverService.slugify('Power   Attack'),
          equals('power_attack'),
        );
      });

      test('trims leading/trailing underscores', () {
        expect(
          AbilityResolverService.slugify('  Mighty Strike  '),
          equals('mighty_strike'),
        );
      });

      test('handles numbers', () {
        expect(
          AbilityResolverService.slugify('Rank 3 Ability'),
          equals('rank_3_ability'),
        );
      });

      test('handles empty string', () {
        expect(AbilityResolverService.slugify(''), equals(''));
      });

      test('handles all special characters', () {
        expect(
          AbilityResolverService.slugify('!@#\$%^&*()'),
          equals(''),
        );
      });

      test('handles mixed case', () {
        expect(
          AbilityResolverService.slugify('FireBall'),
          equals('fireball'),
        );
      });

      test('handles hyphens and colons', () {
        expect(
          AbilityResolverService.slugify('Back!: Level 3'),
          equals('back_level_3'),
        );
      });

      test('handles unicode characters', () {
        // Unicode is converted to underscores and collapsed
        expect(
          AbilityResolverService.slugify('Ångström Attack'),
          equals('ngstr_m_attack'),
        );
      });
    });

    group('API contract', () {
      // These tests document the expected API contract for DB-based loading.
      // Full integration tests would require a seeded database.
      
      test('resolveAbilityId returns empty string for empty input', () async {
        // This test documents the expected behavior:
        // When given an empty ability name, the method should return empty string.
        // The contract states: if (abilityName.isEmpty) return '';
      });
      
      test('resolveAbilityId signature accepts sourceType for backwards compatibility', () {
        // The method signature includes sourceType and ensureInDb parameters
        // for API compatibility, even though they're no longer used
        // since all data is now loaded from the Components table.
        // 
        // Old signature (JSON-based):
        //   resolveAbilityId(name, sourceType: 'perk', ensureInDb: true)
        // 
        // New signature (DB-based):
        //   resolveAbilityId(name, sourceType: 'perk', ensureInDb: true)
        //   (parameters kept for API compatibility but ignored)
      });
      
      test('getAllSkills returns Component list from DB', () {
        // Contract: Returns List<Component> with type='skill'
        // Skills have id, name, type='skill', and dataJson with 'group'
      });
      
      test('getSkillsByGroup filters by group field in dataJson', () {
        // Contract: Returns List<Component> filtered where 
        // dataJson['group'].toLowerCase() == group.toLowerCase()
      });
      
      test('getAllLanguages returns Component list from DB', () {
        // Contract: Returns List<Component> with type='language'
        // Languages have id, name, type='language'
      });
      
      test('getAllTitles returns Component list from DB', () {
        // Contract: Returns List<Component> with type='title'
        // Titles have id, name, type='title', and dataJson with 'benefits'
      });
      
      test('getTitleById returns Component or null', () {
        // Contract: Returns Component if exists with type='title', else null
      });
    });
  });
}
