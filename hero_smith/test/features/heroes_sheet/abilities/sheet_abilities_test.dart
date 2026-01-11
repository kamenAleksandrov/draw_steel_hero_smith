import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hero_smith/core/db/app_database.dart' hide Component;
import 'package:hero_smith/core/db/providers.dart';
import 'package:hero_smith/features/heroes_sheet/abilities/sheet_abilities.dart';
import 'package:hero_smith/core/text/heroes_sheet/abilities/sheet_abilities_text.dart';
import 'package:hero_smith/widgets/abilities/ability_expandable_item.dart';
import 'package:hero_smith/core/text/heroes_sheet/abilities/common_abilities_view_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const heroId = 'hero-1';

  group('SheetAbilities', () {
    late AppDatabase db;
    late StreamController<List<String>> idsController;

    ByteData _asByteData(String value) =>
        ByteData.view(Uint8List.fromList(utf8.encode(value)).buffer);

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.into(db.heroes).insert(
            HeroesCompanion.insert(id: heroId, name: 'Test Hero'),
          );
      idsController = StreamController<List<String>>();

      // Stub ability assets for AbilityDataService.
      ServicesBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (key == 'AssetManifest.json') {
            return _asByteData(jsonEncode({
              'data/abilities/class_abilities_simplified/common_abilities.json': [
                'data/abilities/class_abilities_simplified/common_abilities.json'
              ],
            }));
          }

          // Common abilities source path
          if (key
              .contains('data/abilities/class_abilities_simplified/common_abilities.json')) {
            return _asByteData(jsonEncode([
              {
                'type': 'ability',
                'id': 'common_ability',
                'name': 'Common Leap',
                'action_type': 'maneuver',
              }
            ]));
          }

          // Default ability set used for hero abilities
          return _asByteData(jsonEncode([
            {
              'type': 'ability',
              'id': 'hero_main',
              'name': 'Hero Main',
              'action_type': 'main action',
              'resource_value': 0,
            },
            {
              'type': 'ability',
              'id': 'hero_trigger',
              'name': 'Hero Trigger',
              'action_type': 'triggered action',
              'resource_value': 0,
            },
          ]));
        },
      );
    });

    tearDown(() async {
      await db.close();
      await idsController.close();
      ServicesBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
    });

    ProviderScope _buildHarness() {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          autoSeedEnabledProvider.overrideWithValue(false),
          heroAbilityIdsProvider.overrideWithProvider(
            (hero) => StreamProvider<List<String>>(
              (ref) => idsController.stream,
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SheetAbilities(heroId: heroId),
          ),
        ),
      );
    }

    Future<void> _pump(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    Finder _abilityText(String text) => find.byWidgetPredicate((widget) {
          final needle = text.toLowerCase();
          if (widget is RichText) {
            return widget.text.toPlainText().toLowerCase().contains(needle);
          }
          if (widget is Text) {
            return widget.data?.toLowerCase().contains(needle) ?? false;
          }
          return false;
        });

    testWidgets('shows empty state when no hero abilities', (tester) async {
      await tester.pumpWidget(_buildHarness());
      idsController.add(const []);
      await _pump(tester);

      expect(find.text(SheetAbilitiesText.emptyHeroTitle), findsOneWidget);
      expect(find.text(SheetAbilitiesText.emptyHeroSubtitle), findsOneWidget);
    });

    testWidgets('renders hero abilities and common tab content', (tester) async {
      await tester.pumpWidget(_buildHarness());
      idsController.add(const ['hero_main', 'hero_trigger']);
      await _pump(tester);
      await _pump(tester);

      expect(find.byType(AbilityExpandableItem), findsWidgets);

      await tester.tap(find.text(SheetAbilitiesText.tabCommonAbilities));
      await _pump(tester);
      await _pump(tester);

      final commonAbility = find.byType(AbilityExpandableItem);
      final commonEmpty =
          find.text(CommonAbilitiesViewText.emptyCategorySubtitle);
      expect(
        commonAbility.evaluate().isNotEmpty || commonEmpty.evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('renders error state from provider errors', (tester) async {
      await tester.pumpWidget(_buildHarness());
      idsController.addError('boom');
      await _pump(tester);

      expect(find.text(SheetAbilitiesText.errorTitle), findsOneWidget);
      expect(find.textContaining('boom'), findsOneWidget);
    });
  });
}
