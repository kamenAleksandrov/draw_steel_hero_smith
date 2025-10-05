import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hero_smith/core/models/subclass_models.dart';
import 'package:hero_smith/core/services/class_data_service.dart';
import 'package:hero_smith/features/creators/widgets/strife_creator/class_features_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ClassFeaturesSection renders for Conduit', (tester) async {
    final classDataService = ClassDataService();
    await classDataService.initialize();
    final conduit = classDataService
        .getAllClasses()
        .firstWhere((c) => c.classId == 'class_conduit');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClassFeaturesSection(
            classData: conduit,
            selectedLevel: 1,
            selectedSubclass: const SubclassSelectionResult(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final exception = tester.takeException();
    expect(exception, isNull);
    expect(find.byType(ClassFeaturesSection), findsOneWidget);
  });

  testWidgets('ClassFeaturesSection handles domain selections for Conduit',
      (tester) async {
    final classDataService = ClassDataService();
    await classDataService.initialize();
    final conduit = classDataService
        .getAllClasses()
        .firstWhere((c) => c.classId == 'class_conduit');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClassFeaturesSection(
            classData: conduit,
            selectedLevel: 1,
            selectedSubclass: const SubclassSelectionResult(
              domainNames: ['Life', 'Protection'],
            ),
          ),
        ),
      ),
    );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 1));

    final exception = tester.takeException();
    expect(exception, isNull);
    expect(find.byType(ClassFeaturesSection), findsOneWidget);
  });
}
