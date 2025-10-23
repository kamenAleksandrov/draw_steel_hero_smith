import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hero_smith/features/creators/hero_creators/strife_creator_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Selecting Conduit does not throw', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StrifeCreatorPage(heroId: 'TEST_HERO')));

    // Allow initial async work.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    // Open the class dropdown.
    final classDropdownFinder = find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButtonFormField &&
      widget.decoration.labelText == 'Class',
    );
    expect(classDropdownFinder, findsOneWidget);

    await tester.tap(classDropdownFinder);
    await tester.pumpAndSettle();

    final conduitFinder = find.text('Conduit').last;
    await tester.tap(conduitFinder);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
  // Allow subclass/domain data to load and scroll to domain section.
  await tester.pump(const Duration(seconds: 3));
  final scrollable = find.byType(Scrollable).first;
  await tester.scrollUntilVisible(find.text('Life'), 500,
    scrollable: scrollable);
  await tester.scrollUntilVisible(find.text('Protection'), 500,
    scrollable: scrollable);

  // Select two domains to mirror typical subclass choices.
  await tester.tap(find.text('Life').last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));

  await tester.tap(find.text('Protection').last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 1));

    final exception = tester.takeException();
    expect(exception, isNull);
  });
}
