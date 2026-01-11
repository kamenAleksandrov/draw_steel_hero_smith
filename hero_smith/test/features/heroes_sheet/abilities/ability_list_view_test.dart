import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hero_smith/core/db/app_database.dart' hide Component;
import 'package:hero_smith/core/db/providers.dart';
import 'package:hero_smith/core/repositories/hero_entry_repository.dart';
import 'package:hero_smith/core/models/component.dart' as models;
import 'package:hero_smith/features/heroes_sheet/abilities/ability_list_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const heroId = 'hero-1';

  group('AbilityListView', () {
    late AppDatabase db;
    late HeroEntryRepository entries;
    late List<models.Component> components;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();

      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.into(db.heroes).insert(
            HeroesCompanion.insert(id: heroId, name: 'Test Hero'),
          );
      entries = HeroEntryRepository(db);

      components = const [
        models.Component(
          id: 'arcane_trick',
          type: 'ability',
          name: 'Arcane Trick',
          data: {'action_type': 'main action', 'resource_value': 0},
        ),
        models.Component(
          id: 'friend_catapult',
          type: 'ability',
          name: 'Friend Catapult',
          data: {'action_type': 'maneuver', 'resource_value': 0},
        ),
        models.Component(
          id: 'gum_up_the_works',
          type: 'ability',
          name: 'Gum Up the Works',
          data: {'action_type': 'triggered action', 'resource_value': 0},
        ),
      ];
    });

    tearDown(() async {
      await db.close();
    });

    Widget buildHarness({List<String>? abilityIds}) {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          autoSeedEnabledProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AbilityListView(
              abilityIds: abilityIds ??
                  const [
                    'arcane_trick', // main action
                    'friend_catapult', // maneuver
                    'gum_up_the_works', // triggered
                  ],
              heroId: heroId,
              loadAbilities: (ids) async {
                return components
                    .where((component) => ids.contains(component.id))
                    .toList();
              },
            ),
          ),
        ),
      );
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
    }
    
    Finder abilityText(String text) => find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().toLowerCase().contains(
                    text.toLowerCase(),
                  ),
        );

    testWidgets('groups abilities by action type tabs', (tester) async {
      await tester.pumpWidget(buildHarness());
      await settle(tester);

      expect(abilityText('Arcane Trick'), findsOneWidget);

      await tester.tap(find.text('Maneuvers'));
      await settle(tester);
      expect(abilityText('Friend Catapult'), findsOneWidget);

      await tester.tap(find.text('Triggered'));
      await settle(tester);
      expect(abilityText('Gum Up the Works'), findsOneWidget);
    });

    testWidgets('removes an ability via delete action', (tester) async {
      await entries.addEntry(
        heroId: heroId,
        entryType: 'ability',
        entryId: 'friend_catapult',
        sourceType: 'manual_choice',
      );

      await tester.pumpWidget(buildHarness());
      await settle(tester);

      await tester.tap(find.text('Maneuvers'));
      await settle(tester);

      await tester.tap(find.byTooltip('Remove ability'));
      await settle(tester);

      await tester.tap(find.text('Remove'));
      await settle(tester);

      expect(find.text('Ability removed'), findsOneWidget);

      final remaining = await entries.listEntriesByType(heroId, 'ability');
      expect(
        remaining.any((entry) => entry.entryId == 'friend_catapult'),
        isFalse,
      );
    });
  });
}
