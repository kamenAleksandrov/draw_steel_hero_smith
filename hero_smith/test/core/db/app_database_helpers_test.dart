import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hero_smith/core/db/app_database.dart';
import 'package:drift/drift.dart' as drift;

void main() {
  group('AppDatabase helper methods', () {
    late AppDatabase db;
    const heroId = 'hero-1';

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.into(db.heroes).insert(
            HeroesCompanion.insert(id: heroId, name: 'Test Hero'),
          );
    });

    tearDown(() async {
      await db.close();
    });

    test('setHeroEntryIds replaces entries only for matching source', () async {
      await db.upsertHeroEntry(
        heroId: heroId,
        entryType: 'ability',
        entryId: 'keep-me',
        sourceType: 'ancestry',
        sourceId: 'ancestry-1',
      );

      await db.setHeroEntryIds(
        heroId: heroId,
        entryType: 'ability',
        entryIds: const ['a', 'b'],
        sourceType: 'manual_choice',
        sourceId: 'manual',
      );

      final abilityIds = await db.getHeroEntryIds(heroId, 'ability');
      expect(abilityIds.toSet(), contains('keep-me'));
      expect(abilityIds.toSet(), containsAll(const {'a', 'b'}));
    });

    test('watchHeroEntriesWithPayload merges quantities for duplicates', () async {
      await db.upsertHeroEntry(
        heroId: heroId,
        entryType: 'equipment',
        entryId: 'item-1',
        sourceType: 'manual_choice',
        sourceId: 's1',
        payload: {'quantity': 2},
      );
      await db.upsertHeroEntry(
        heroId: heroId,
        entryType: 'equipment',
        entryId: 'item-1',
        sourceType: 'manual_choice',
        sourceId: 's2',
        payload: {'quantity': 3},
      );

      final stream = db.watchHeroEntriesWithPayload(heroId, 'equipment');
      final payload = await stream.first;
      expect(payload['item-1']?['quantity'], equals(5));
    });

    test('watchHeroComponentIds falls back to legacy hero_values', () async {
      await db.into(db.heroValues).insert(
            HeroValuesCompanion.insert(
              heroId: heroId,
              key: 'component.ability',
              jsonValue:
                  drift.Value(jsonEncode({'ids': ['legacy-ability']})),
            ),
          );

      final stream = db.watchHeroComponentIds(heroId, 'ability');
      final ids = await stream.first;
      expect(ids, equals(['legacy-ability']));
    });
  });
}
