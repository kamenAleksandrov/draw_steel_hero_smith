import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hero_smith/core/models/component.dart';
import 'package:hero_smith/core/services/ability_data_service.dart';
import 'package:hero_smith/features/heroes_sheet/abilities/add_ability_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const heroId = 'hero-1';

  List<Component> stubAbilities() => const [
        Component(
          id: 'fire_bolt',
          type: 'ability',
          name: 'Fire Bolt',
          data: {
            'resource': 'Ferocity',
            'resource_value': 3,
            'action_type': 'main action',
            'distance': '10 squares',
            'targets': 'one target',
          },
        ),
        Component(
          id: 'shadow_step',
          type: 'ability',
          name: 'Shadow Step',
          data: {
            'resource': 'Signature',
            'resource_value': 0,
            'action_type': 'triggered action',
            'distance': 'self',
            'targets': 'self',
          },
        ),
        Component(
          id: 'sidestep',
          type: 'ability',
          name: 'Side Step',
          data: {
            'resource': 'Focus',
            'resource_value': 1,
            'action_type': 'maneuver',
            'distance': 'self',
            'targets': 'self',
          },
        ),
      ];

  AbilityLibrary stubLibrary() {
    final components = stubAbilities();
    final byId = {for (final c in components) c.id: c};
    return AbilityLibrary(const {}, byId);
  }

  Finder abilityText(String text) => find.byWidgetPredicate((widget) {
        final needle = text.toLowerCase();
        if (widget is RichText) {
          return widget.text.toPlainText().toLowerCase().contains(needle);
        }
        if (widget is Text) {
          return widget.data?.toLowerCase().contains(needle) ?? false;
        }
        return false;
      });

  group('AddAbilityDialog', () {
    testWidgets('filters by search and resource/cost/action', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AddAbilityDialog(
            heroId: heroId,
            loadLibraryOverride: () async => stubLibrary(),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'fire',
      );
      await tester.pumpAndSettle();

      expect(abilityText('Fire Bolt'), findsOneWidget);
      expect(abilityText('Shadow Step'), findsNothing);

      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      await tester.tap(find.text('All Cost'));
      await tester.pumpAndSettle();
      final costThreeOption = find.descendant(
        of: find.byType(Scrollable).last,
        matching: find.text('3'),
      );
      await tester.tap(costThreeOption);
      await tester.pumpAndSettle();

      expect(abilityText('Fire Bolt'), findsOneWidget);
      expect(abilityText('Shadow Step'), findsNothing);

      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      final allCostOption = find.descendant(
        of: find.byType(Scrollable).last,
        matching: find.text('All Cost'),
      );
      await tester.tap(allCostOption);
      await tester.pumpAndSettle();

      await tester.tap(find.text('All Action Type'));
      await tester.pumpAndSettle();
      final maneuverOption = find.descendant(
        of: find.byType(Scrollable).last,
        matching: find.text('Maneuver'),
      );
      await tester.tap(maneuverOption);
      await tester.pumpAndSettle();

      expect(abilityText('Side Step'), findsOneWidget);
      expect(abilityText('Shadow Step'), findsNothing);
    });

    testWidgets('returns selected ability id on tap', (tester) async {
      String? selectedId;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    selectedId = await showDialog<String>(
                      context: context,
                      builder: (_) => AddAbilityDialog(
                        heroId: heroId,
                        loadLibraryOverride: () async => stubLibrary(),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'shadow');
      await tester.pumpAndSettle();

      await tester.tap(abilityText('Shadow Step'));
      await tester.pumpAndSettle();

      expect(selectedId, equals('shadow_step'));
    });
  });
}
