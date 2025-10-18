import 'package:flutter_test/flutter_test.dart';
import 'package:hero_smith/core/services/subclass_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SubclassDataService', () {
    test('loads censor subclass options with correct names', () async {
      final service = SubclassDataService();
      
      final featureData = await service.loadSubclassFeatureData(
        classSlug: 'censor',
        featureName: 'Censor Order',
      );

      expect(featureData, isNotNull);
      expect(featureData!.options, isNotEmpty);
      
      // Verify that options have proper names and keys
      for (final option in featureData.options) {
        expect(option.name, isNot(equals('Subclass Option')));
        expect(option.key, isNot(equals('subclass_option')));
        expect(option.name.trim(), isNotEmpty);
        expect(option.key.trim(), isNotEmpty);
      }
      
      // Check for specific expected subclasses
      final optionNames = featureData.options.map((o) => o.name).toList();
      expect(optionNames, contains('Exorcist'));
      expect(optionNames, contains('Oracle'));
      expect(optionNames, contains('Paragon'));
    });

    test('loads conduit domain options', () async {
      final service = SubclassDataService();
      
      final featureData = await service.loadSubclassFeatureData(
        classSlug: 'conduit',
        featureName: 'Deity and Domains',
      );

      expect(featureData, isNotNull);
      if (featureData != null && featureData.options.isNotEmpty) {
        for (final option in featureData.options) {
          expect(option.name, isNot(equals('Subclass Option')));
          expect(option.key, isNot(equals('subclass_option')));
        }
      }
    });
  });
}
