import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hero_smith/core/db/app_database.dart';
import 'package:hero_smith/core/services/hero_data_validator.dart';
import 'package:drift/drift.dart' as drift;

void main() {
  group('HeroDataValidator', () {
    late AppDatabase db;
    late HeroDataValidator validator;
    const heroId = 'hero-1';

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.into(db.heroes).insert(
            HeroesCompanion.insert(id: heroId, name: 'Test Hero'),
          );
      validator = HeroDataValidator(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('flags banned hero_values keys and duplicate entries', () async {
      await db.into(db.heroValues).insert(
            HeroValuesCompanion.insert(
              heroId: heroId,
              key: 'perk_abilities.test',
              textValue: const drift.Value('p1'),
            ),
          );
      await db.into(db.heroEntries).insert(
            HeroEntriesCompanion.insert(
              heroId: heroId,
              entryType: 'ability',
              entryId: 'dup',
              sourceType: const drift.Value('s1'),
              sourceId: const drift.Value('s1'),
              gainedBy: const drift.Value('grant'),
            ),
          );
      await db.into(db.heroEntries).insert(
            HeroEntriesCompanion.insert(
              heroId: heroId,
              entryType: 'ability',
              entryId: 'dup',
              sourceType: const drift.Value('s1'),
              sourceId: const drift.Value('s1'),
              gainedBy: const drift.Value('grant'),
            ),
          );
      await db.into(db.components).insert(
            ComponentsCompanion.insert(
              id: 'dup',
              type: 'ability',
              name: 'Duplicate Ability',
            ),
          );

      final result = await validator.validate(heroId);

      expect(result.bannedValueKeys, isNotEmpty);
      expect(result.duplicateEntries, contains('ability:dup:s1:s1'));
      expect(result.isValid, isFalse);
    });

    test('passes clean data', () async {
      await db.into(db.components).insert(
            ComponentsCompanion.insert(
              id: 'clean',
              type: 'ability',
              name: 'Clean Ability',
            ),
          );
      await db.upsertHeroEntry(
        heroId: heroId,
        entryType: 'ability',
        entryId: 'clean',
      );

      final result = await validator.validate(heroId);
      expect(result.isValid, isTrue);
      expect(result.totalIssues, equals(0));
    });
  });
}
