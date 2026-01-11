import 'package:flutter_test/flutter_test.dart';
import 'package:hero_smith/core/services/ability_resolver_service.dart';
import 'package:drift/native.dart';
import 'package:hero_smith/core/db/app_database.dart';
import 'dart:convert';
import 'package:drift/drift.dart' as drift;

void main() {
  group('AbilityResolverService', () {
    group('db-backed resolution', () {
      late AppDatabase db;
      late AbilityResolverService service;

      setUp(() async {
        db = AppDatabase.forTesting(NativeDatabase.memory());
        await db.into(db.components).insert(
              ComponentsCompanion.insert(
                id: 'fire_bolt',
                type: 'ability',
                name: 'Fire Bolt',
                dataJson: const drift.Value('{}'),
              ),
            );
        await db.into(db.components).insert(
              ComponentsCompanion.insert(
                id: 'Shadow_Step',
                type: 'ability',
                name: 'Shadow Step',
                dataJson: const drift.Value('{}'),
              ),
            );
        await db.into(db.components).insert(
              ComponentsCompanion.insert(
                id: 'crafting_1',
                type: 'skill',
                name: 'Crafting Basics',
                dataJson: drift.Value(jsonEncode({'group': 'crafting'})),
              ),
            );
        await db.into(db.components).insert(
              ComponentsCompanion.insert(
                id: 'language_common',
                type: 'language',
                name: 'Common Tongue',
                dataJson: const drift.Value('{}'),
              ),
            );
        await db.into(db.components).insert(
              ComponentsCompanion.insert(
                id: 'title_hero',
                type: 'title',
                name: 'Hero of Light',
                dataJson: drift.Value(jsonEncode({'benefits': 'shiny'})),
              ),
            );
        service = AbilityResolverService(db);
      });

      tearDown(() async {
        await db.close();
      });

      test('resolveAbilityId matches by name and slug', () async {
        final byName = await service.resolveAbilityId('fire bolt');
        expect(byName, equals('fire_bolt'));

        final bySlug = await service.resolveAbilityId('Shadow-Step');
        expect(bySlug, equals('Shadow_Step'));
      });

      test('resolveAbilityId falls back to slugified input when missing', () async {
        final id = await service.resolveAbilityId('Unknown Ability');
        expect(id, equals('unknown_ability'));
      });

      test('resolveAbilityIds skips empty and preserves order', () async {
        final ids = await service.resolveAbilityIds(
          const ['Fire Bolt', '', 'Shadow Step'],
        );
        expect(ids, equals(const ['fire_bolt', 'Shadow_Step']));
      });

      test('buildAbilityNameToIdMap builds lowercased lookup', () async {
        final map = await service.buildAbilityNameToIdMap();
        expect(map['fire bolt'], equals('fire_bolt'));
        expect(map['shadow step'], equals('Shadow_Step'));
      });

      test('abilityExistsInDb and getAbilityById respect type', () async {
        expect(await service.abilityExistsInDb('fire_bolt'), isTrue);
        expect(await service.abilityExistsInDb('missing'), isFalse);
        expect(await service.getAbilityById('fire_bolt'), isNotNull);
        expect(await service.getAbilityById('crafting_1'), isNull);
      });

      test('fetches skills, languages, and titles by type/group', () async {
        final skills = await service.getAllSkills();
        expect(skills.single.id, equals('crafting_1'));

        final crafting = await service.getSkillsByGroup('crafting');
        expect(crafting.single.id, equals('crafting_1'));

        final languages = await service.getAllLanguages();
        expect(languages.single.id, equals('language_common'));

        final titles = await service.getAllTitles();
        expect(titles.single.id, equals('title_hero'));

        expect(await service.getTitleById('title_hero'), isNotNull);
        expect(await service.getTitleById('missing'), isNull);
      });
    });

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
