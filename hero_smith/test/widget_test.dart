// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hero_smith/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hero_smith/core/db/providers.dart';

void main() {
  testWidgets('Bottom navigation has 5 destinations and switches pages', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          autoSeedEnabledProvider.overrideWithValue(false),
        ],
        child: const HeroSmithApp(),
      ),
    );
    
    // Allow initial pump cycles for basic UI
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    
    // Initial page should be HeroesPage - just verify we're on the right page structure
    // Since the heroes provider might be loading, just check for navigation destinations
    expect(find.byType(NavigationDestination), findsNWidgets(5));

    // Tap Story tab (index 2)
    await tester.tap(find.text('Story'));
    await tester.pumpAndSettle();
    expect(find.text('Story Page'), findsOneWidget);

    // Tap Gear tab (index 3)
    await tester.tap(find.text('Gear'));
    await tester.pumpAndSettle();
    expect(find.text('Gear Page'), findsOneWidget);
  });
}
