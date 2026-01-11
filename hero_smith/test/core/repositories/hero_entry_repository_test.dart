import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hero_smith/core/db/app_database.dart';
import 'package:hero_smith/core/repositories/hero_entry_repository.dart';

void main() {
  group('HeroEntryRepository', () {
    const heroId = 'hero-1';
    late AppDatabase db;
    late HeroEntryRepository repository;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.into(db.heroes).insert(
            HeroesCompanion.insert(id: heroId, name: 'Test Hero'),
          );
      repository = HeroEntryRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('addEntriesFromSource replaces existing entries from the same source',
        () async {
      await repository.addEntriesFromSource(
        heroId: heroId,
        sourceType: 'perk',
        sourceId: 'perk-1',
        entryType: 'ability',
        entryIds: const ['ability-a', 'ability-b'],
      );

      await repository.addEntry(
        heroId: heroId,
        entryType: 'ability',
        entryId: 'keep-me',
        sourceType: 'ancestry',
      );

      await repository.addEntriesFromSource(
        heroId: heroId,
        sourceType: 'perk',
        sourceId: 'perk-1',
        entryType: 'ability',
        entryIds: const ['ability-b', 'ability-c'],
      );

      final abilities = await repository.listEntriesByType(heroId, 'ability');
      final ids = abilities.map((e) => e.entryId).toSet();

      expect(ids.contains('ability-a'), isFalse);
      expect(ids.containsAll(['ability-b', 'ability-c', 'keep-me']), isTrue);

      final ancestry = abilities.firstWhere(
        (entry) => entry.entryId == 'keep-me',
      );
      expect(ancestry.sourceType, equals('ancestry'));
    });

    test('removeEntriesFromSource honors optional filters', () async {
      await repository.addEntry(
        heroId: heroId,
        entryType: 'ability',
        entryId: 'perk-ability-1',
        sourceType: 'perk',
        sourceId: 'perk-1',
      );
      await repository.addEntry(
        heroId: heroId,
        entryType: 'ability',
        entryId: 'perk-ability-2',
        sourceType: 'perk',
        sourceId: 'perk-2',
      );
      await repository.addEntry(
        heroId: heroId,
        entryType: 'perk',
        entryId: 'perk-1',
        sourceType: 'perk',
        sourceId: 'perk-1',
      );

      final removed = await repository.removeEntriesFromSource(
        heroId: heroId,
        sourceType: 'perk',
        sourceId: 'perk-1',
        entryType: 'ability',
      );

      expect(removed, equals(1));

      final remaining = await repository.listAllEntriesForHero(heroId);
      final remainingIds =
          remaining.map((e) => '${e.entryType}:${e.entryId}').toSet();

      expect(remainingIds.contains('ability:perk-ability-1'), isFalse);
      expect(
        remainingIds.containsAll(
          const ['ability:perk-ability-2', 'perk:perk-1'],
        ),
        isTrue,
      );
    });

    test('getEntryTypesForHero returns unique entry types for the hero',
        () async {
      await repository.addEntry(
        heroId: heroId,
        entryType: 'ability',
        entryId: 'ability-a',
      );
      await repository.addEntry(
        heroId: heroId,
        entryType: 'ability',
        entryId: 'ability-b',
      );
      await repository.addEntry(
        heroId: heroId,
        entryType: 'perk',
        entryId: 'perk-a',
      );

      await db.into(db.heroes).insert(
            HeroesCompanion.insert(id: 'hero-2', name: 'Other Hero'),
          );
      await repository.addEntry(
        heroId: 'hero-2',
        entryType: 'title',
        entryId: 'title-a',
      );

      final entryTypes = await repository.getEntryTypesForHero(heroId);
      expect(entryTypes, equals({'ability', 'perk'}));
    });

    test('entriesGroupedBySource groups entries by source type and id',
        () async {
      await repository.addEntry(
        heroId: heroId,
        entryType: 'ability',
        entryId: 'ability-a',
        sourceType: 'perk',
        sourceId: 'perk-1',
      );
      await repository.addEntry(
        heroId: heroId,
        entryType: 'ability',
        entryId: 'ability-b',
        sourceType: 'perk',
        sourceId: 'perk-1',
      );
      await repository.addEntry(
        heroId: heroId,
        entryType: 'perk',
        entryId: 'perk-2',
        sourceType: 'perk',
        sourceId: 'perk-2',
      );
      await repository.addEntry(
        heroId: heroId,
        entryType: 'ability',
        entryId: 'kit-ability',
        sourceType: 'kit',
        sourceId: 'starter-kit',
      );

      final grouped = await repository.entriesGroupedBySource(heroId);

      expect(grouped.containsKey('perk:perk-1'), isTrue);
      expect(
        grouped['perk:perk-1']!.map((e) => e.entryId).toSet(),
        equals({'ability-a', 'ability-b'}),
      );

      expect(grouped['perk:perk-2']!.single.entryId, equals('perk-2'));
      expect(grouped['kit:starter-kit']!.single.entryId, equals('kit-ability'));
    });
  });
}
