import 'package:flutter_test/flutter_test.dart';

import 'package:hero_smith/core/models/subclass_models.dart';
import 'package:hero_smith/core/services/class_data_service.dart';
import 'package:hero_smith/core/services/class_feature_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('load conduit features', () async {
    final classDataService = ClassDataService();
    await classDataService.initialize();
    final conduit = classDataService
        .getAllClasses()
        .firstWhere((c) => c.classId == 'class_conduit');

    final service = ClassFeatureDataService();
    final result = await service.loadFeatures(
      classData: conduit,
      level: 1,
      activeSubclassSlugs:
          ClassFeatureDataService.activeSubclassSlugs(const SubclassSelectionResult()),
    );

    expect(result.features, isNotEmpty);
  });
}
