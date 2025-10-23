import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hero_smith/core/services/class_data_service.dart';
import 'package:hero_smith/features/creators/hero_creators/strife_creator_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Selecting Censor does not throw', (tester) async {
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

    final censorFinder = find.text('Censor').last;
    await tester.tap(censorFinder);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    final exception = tester.takeException();
    expect(exception, isNull);
  });

  test('Load censor class data', () async {
    final classDataService = ClassDataService();
    await classDataService.initialize();
    final censor = classDataService
        .getAllClasses()
        .firstWhere((c) => c.classId == 'class_censor');

    expect(censor, isNotNull);
    expect(censor.name, 'Censor');
  });
}
