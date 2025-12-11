import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hero_smith/core/models/component.dart' as model;
import 'package:hero_smith/core/models/complication_grant_models.dart';
import 'package:hero_smith/core/db/providers.dart';
import 'package:hero_smith/features/creators/widgets/story_creator/story_complication_section.dart';

/// Widget tests for the StoryComplicationSection.
/// 
/// These tests verify the UI behavior of complication selection and grant display.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Map<String, dynamic>> allComplications;
  // ignore: unused_local_variable
  late List<model.Component> complicationComponents;

  setUpAll(() async {
    // Load complications from JSON
    final jsonString = await rootBundle.loadString('data/story/complications.json');
    final List<dynamic> data = json.decode(jsonString);
    allComplications = data.cast<Map<String, dynamic>>();
    
    // Convert to Component models
    complicationComponents = allComplications.map((comp) {
      return model.Component(
        id: comp['id'] as String,
        type: 'complication',
        name: comp['name'] as String,
        data: comp,
      );
    }).toList();
  });

  /// Helper to build the widget under test with required providers
  Widget buildTestWidget({
    String? selectedComplicationId,
    Map<String, String> complicationChoices = const {},
    void Function(String?)? onComplicationChanged,
    void Function(Map<String, String>)? onChoicesChanged,
  }) {
    return ProviderScope(
      overrides: [
        autoSeedEnabledProvider.overrideWithValue(false),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StoryComplicationSection(
              selectedComplicationId: selectedComplicationId,
              complicationChoices: complicationChoices,
              onComplicationChanged: onComplicationChanged ?? (_) {},
              onChoicesChanged: onChoicesChanged ?? (_) {},
              onDirty: () {},
            ),
          ),
        ),
      ),
    );
  }

  group('StoryComplicationSection Widget', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(StoryComplicationSection), findsOneWidget);
      expect(find.text('Complication'), findsOneWidget);
    });

    testWidgets('shows complication section structure', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Should have the section widget
      expect(find.byType(StoryComplicationSection), findsOneWidget);
      // Should show either a dropdown or loading state
      expect(find.text('Complication'), findsOneWidget);
    });
    
    testWidgets('handles null selection gracefully', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        selectedComplicationId: null,
        complicationChoices: const {},
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should not throw an error
      expect(tester.takeException(), isNull);
      expect(find.byType(StoryComplicationSection), findsOneWidget);
    });
  });

  group('Grant Parsing for UI', () {
    test('complication with token grants can be parsed for display', () {
      // Find a complication with token grants
      final compWithTokens = allComplications.firstWhere(
        (c) {
          final grants = c['grants'] as Map<String, dynamic>?;
          return grants != null && grants['tokens'] != null;
        },
        orElse: () => throw StateError('No complication with tokens found'),
      );

      final grantsData = compWithTokens['grants'] as Map<String, dynamic>;
      final grants = ComplicationGrant.parseFromGrantsData(
        grantsData,
        compWithTokens['id'] as String,
        compWithTokens['name'] as String,
      );

      // Should parse token grants correctly
      final tokenGrants = grants.whereType<TokenGrant>();
      expect(tokenGrants, isNotEmpty);
    });

    test('complication with skill grants can be parsed for display', () {
      // Find a complication with skill grants
      final compWithSkills = allComplications.firstWhere(
        (c) {
          final grants = c['grants'] as Map<String, dynamic>?;
          return grants != null && grants['skills'] != null;
        },
        orElse: () => throw StateError('No complication with skills found'),
      );

      final grantsData = compWithSkills['grants'] as Map<String, dynamic>;
      final grants = ComplicationGrant.parseFromGrantsData(
        grantsData,
        compWithSkills['id'] as String,
        compWithSkills['name'] as String,
      );

      // Should parse skill grants correctly
      expect(grants, isNotEmpty);
    });

    test('complication with treasure grants can be parsed for display', () {
      // Find a complication with treasure grants
      final compWithTreasures = allComplications.firstWhere(
        (c) {
          final grants = c['grants'] as Map<String, dynamic>?;
          return grants != null && grants['treasures'] != null;
        },
        orElse: () => throw StateError('No complication with treasures found'),
      );

      final grantsData = compWithTreasures['grants'] as Map<String, dynamic>;
      final grants = ComplicationGrant.parseFromGrantsData(
        grantsData,
        compWithTreasures['id'] as String,
        compWithTreasures['name'] as String,
      );

      // Should parse treasure grants correctly (TreasureGrant or LeveledTreasureGrant)
      final treasureGrants = grants.where((g) => 
          g is TreasureGrant || g is LeveledTreasureGrant);
      expect(treasureGrants, isNotEmpty);
    });
  });
}
