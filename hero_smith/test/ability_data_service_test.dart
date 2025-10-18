import 'package:flutter_test/flutter_test.dart';
import 'package:hero_smith/core/services/ability_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AbilityDataService', () {
    test('loads library', () async {
      final service = AbilityDataService();
      
      try {
        final library = await service.loadLibrary();
        print('Library loaded with ${library.components.length} components');
        
        // Print the source paths to see what's being loaded
        final sourcePaths = library.components
            .map((c) => c.data['ability_source_path'] as String?)
            .where((path) => path != null)
            .toSet()
            .toList()..sort();
        print('Source paths:');
        for (final path in sourcePaths) {
          final count = library.components
              .where((c) => c.data['ability_source_path'] == path)
              .length;
          print('  $path ($count components)');
        }
        
        expect(library.isEmpty, isFalse);
      } catch (e) {
        print('Error loading library: $e');
        rethrow;
      }
    });

    test('loads censor abilities from new structure', () async {
      final service = AbilityDataService();
      
      final abilities = await service.loadClassAbilities('censor');
      
      print('Got ${abilities.length} censor abilities');
      for (final ability in abilities.take(3)) {
        print('  - ${ability.name}: costs = ${ability.data['costs']}');
      }
      
      expect(abilities, isNotEmpty, reason: 'Should load censor abilities');
      
      // Check that we have some signature abilities (costs == "signature")
      final signatureAbilities = abilities.where((ability) {
        final costs = ability.data['costs'];
        if (costs is String) {
          return costs.toLowerCase() == 'signature';
        }
        if (costs is Map) {
          return costs['signature'] == true;
        }
        return false;
      }).toList();
      
      expect(signatureAbilities, isNotEmpty, reason: 'Should have signature abilities');
      
      // Check that we have some cost-based abilities (with resource and amount)
      final costAbilities = abilities.where((ability) {
        final costs = ability.data['costs'];
        if (costs is Map) {
          return costs['resource'] != null && costs['amount'] != null;
        }
        return false;
      }).toList();
      
      expect(costAbilities, isNotEmpty, reason: 'Should have cost-based abilities');
      
      // Verify that level information is present
      final level1Abilities = abilities.where((ability) {
        final level = service.componentLevel(ability);
        return level == 1;
      }).toList();
      
      expect(level1Abilities, isNotEmpty, reason: 'Should have level 1 abilities');
      
      // Print some debug info
      print('Total censor abilities: ${abilities.length}');
      print('Signature abilities: ${signatureAbilities.length}');
      print('Cost-based abilities: ${costAbilities.length}');
      print('Level 1 abilities: ${level1Abilities.length}');
      
      // Check for specific expected abilities
      final abilityNames = abilities.map((a) => a.name).toList();
      expect(abilityNames, contains('Arrest'));
      expect(abilityNames, contains('Judgment'));
      expect(abilityNames, contains('Back Blasphemer!'));
    });

    test('loads conduit abilities from new structure', () async {
      final service = AbilityDataService();
      
      final abilities = await service.loadClassAbilities('conduit');
      
      expect(abilities, isNotEmpty, reason: 'Should load conduit abilities');
      
      print('Total conduit abilities: ${abilities.length}');
    });

    test('loads all class abilities', () async {
      final service = AbilityDataService();
      
      final classNames = [
        'censor',
        'conduit',
        'elementalist',
        'fury',
        'null',
        'shadow',
        'tactician',
        'talent',
        'troubadour',
      ];
      
      for (final className in classNames) {
        final abilities = await service.loadClassAbilities(className);
        expect(abilities, isNotEmpty, reason: 'Should load $className abilities');
        print('$className: ${abilities.length} abilities');
      }
    });
  });
}
