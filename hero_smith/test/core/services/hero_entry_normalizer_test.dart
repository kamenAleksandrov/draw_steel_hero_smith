import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hero_smith/core/db/app_database.dart';
import 'package:hero_smith/core/repositories/hero_entry_repository.dart';
import 'package:hero_smith/core/services/hero_entry_normalizer.dart';
import 'package:hero_smith/core/models/damage_resistance_model.dart';
import 'dart:convert';
import 'package:drift/drift.dart' as drift;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const heroId = 'hero-1';

  group('HeroEntryNormalizer', () {
    late AppDatabase db;
    late HeroEntryNormalizer normalizer;
    late HeroEntryRepository entries;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.into(db.heroes).insert(
            HeroesCompanion.insert(id: heroId, name: 'Test Hero'),
          );
      normalizer = HeroEntryNormalizer(db);
      entries = HeroEntryRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('migrates basics.className from hero_values to hero_entries', () async {
      await db.into(db.heroValues).insert(
            HeroValuesCompanion.insert(
              heroId: heroId,
              key: 'basics.className',
              textValue: const Value('fighter'),
            ),
          );

      await normalizer.normalize(heroId);

      final heroValues = await (db.select(db.heroValues)
            ..where((t) => t.heroId.equals(heroId)))
          .get();
      expect(
        heroValues.any((value) => value.key == 'basics.className'),
        isFalse,
      );

      final heroEntries = await entries.listEntriesByType(heroId, 'class');
      expect(heroEntries.length, equals(1));
      expect(heroEntries.single.entryId, equals('fighter'));
      expect(heroEntries.single.sourceType, equals('manual_choice'));
    });

    test('removes banned values and deduplicates hero_entries', () async {
      await db.into(db.heroValues).insert(
            HeroValuesCompanion.insert(
              heroId: heroId,
              key: 'perk_abilities.test',
              textValue: const Value('perk-power'),
            ),
          );

      for (int i = 0; i < 2; i++) {
        await db.into(db.heroEntries).insert(
              HeroEntriesCompanion.insert(
                heroId: heroId,
                entryType: 'ability',
                entryId: 'duplicate',
                sourceType: const Value('perk'),
                sourceId: const Value('perk-1'),
              ),
            );
      }

      await normalizer.normalize(heroId);

      final remainingValues = await (db.select(db.heroValues)
            ..where((t) => t.heroId.equals(heroId)))
          .get();
      expect(
        remainingValues.any((value) => value.key.startsWith('perk_abilities')),
        isFalse,
      );

      final abilityEntries = await entries.listEntriesByType(heroId, 'ability');
      expect(abilityEntries.length, equals(1));
      expect(abilityEntries.single.entryId, equals('duplicate'));
    });

    test('recomputes resistances aggregate from resistance entries', () async {
      await db.into(db.heroEntries).insert(
            HeroEntriesCompanion.insert(
              heroId: heroId,
              entryType: 'resistance',
              entryId: 'fire',
              sourceType: const Value('ancestry'),
              sourceId: const Value('ancestry-1'),
              payload: Value(jsonEncode({
                'immunityMods': [
                  {'value': 2, 'source': 'ancestry-1'}
                ],
                'weaknessMods': [
                  {'value': 1, 'source': 'curse'}
                ],
              })),
            ),
          );

      await normalizer.normalize(heroId);

      final heroValues = await db.getHeroValues(heroId);
      final resistRow = heroValues.firstWhere(
        (v) => v.key == 'resistances.damage',
      );
      final parsed = HeroDamageResistances.fromJsonString(
        resistRow.textValue ?? resistRow.jsonValue ?? '{}',
      );
      final fire = parsed.forType('fire');
      expect(fire is DamageResistance, isTrue);
      expect(fire!.bonusImmunity, equals(2));
      expect(fire.bonusWeakness, equals(1));
    });

    test('removes duplicate hero_config rows and banned config keys', () async {
      await db.into(db.heroConfig).insert(
            HeroConfigCompanion.insert(
              heroId: heroId,
              configKey: 'complication.applied_grants',
              valueJson: '{}',
              metadata: const drift.Value('old'),
            ),
          );
      await db.into(db.heroConfig).insert(
            HeroConfigCompanion.insert(
              heroId: heroId,
              configKey: 'complication.applied_grants',
              valueJson: '{"dup":true}',
              metadata: const drift.Value('newer'),
            ),
          );
      await db.into(db.heroConfig).insert(
            HeroConfigCompanion.insert(
              heroId: heroId,
              configKey: 'class_feature.subclass_key',
              valueJson: '{}',
            ),
          );

      await normalizer.normalize(heroId);

      final configs = await (db.select(db.heroConfig)
            ..where((t) => t.heroId.equals(heroId)))
          .get();
      expect(configs.any((c) => c.configKey == 'complication.applied_grants'),
          isFalse);
      expect(configs.any((c) => c.configKey == 'class_feature.subclass_key'),
          isFalse);
    });

    test('parses legacy immunity/weakness entries into aggregate', () async {
      await db.into(db.heroEntries).insert(
            HeroEntriesCompanion.insert(
              heroId: heroId,
              entryType: 'immunity',
              entryId: 'legacy',
              payload: drift.Value(jsonEncode({
                'immunities': ['cold', 'cold'],
              })),
            ),
          );
      await db.into(db.heroEntries).insert(
            HeroEntriesCompanion.insert(
              heroId: heroId,
              entryType: 'weakness',
              entryId: 'legacy',
              payload: drift.Value(jsonEncode({
                'weaknesses': ['cold'],
              })),
            ),
          );

      await normalizer.normalize(heroId);

      final heroValues = await db.getHeroValues(heroId);
      final resistRow = heroValues.firstWhere(
        (v) => v.key == 'resistances.damage',
      );
      final parsed = HeroDamageResistances.fromJsonString(
        resistRow.textValue ?? resistRow.jsonValue ?? '{}',
      );
      final cold = parsed.forType('cold');
      expect(cold?.bonusImmunity, equals(2));
      expect(cold?.bonusWeakness, equals(1));
    });
  });
}
