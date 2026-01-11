import 'package:flutter_test/flutter_test.dart';
import 'package:hero_smith/core/services/ability_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AbilityDataService', () {
    late AbilityDataService service;

    setUp(() {
      service = AbilityDataService();
    });

    test('loadLibrary indexes abilities by id and normalized name', () async {
      final library = await service.loadLibrary();
      expect(library.isEmpty, isFalse);

      final byId = library.byId('friend_catapult');
      expect(byId, isNotNull);

      expect(library.find('Friend Catapult'), same(byId));
      expect(library.find('friend catapult'), same(byId));
      expect(
        library.components.any(
          (component) => component.data['class_slug'] == 'fury',
        ),
        isTrue,
      );
    });

    test('loadClassAbilities filters by class slug and sorts results', () async {
      final abilities = await service.loadClassAbilities('fury');
      expect(abilities, isNotEmpty);
      expect(
        abilities.every((ability) => ability.data['class_slug'] == 'fury'),
        isTrue,
      );

      for (var i = 1; i < abilities.length; i++) {
        final prev = abilities[i - 1];
        final current = abilities[i];
        final prevLevel = service.componentLevel(prev) ?? 0;
        final currentLevel = service.componentLevel(current) ?? 0;

        if (prevLevel == currentLevel) {
          expect(prev.name.compareTo(current.name) <= 0, isTrue);
        } else {
          expect(prevLevel <= currentLevel, isTrue);
        }
      }

      final cached = await service.loadClassAbilities('fury');
      expect(identical(abilities, cached), isTrue);
    });

    test('loadClassAbilitiesSimplified parses, orders, and caches abilities',
        () async {
      final simplified = await service.loadClassAbilitiesSimplified('fury');
      expect(simplified, isNotEmpty);

      for (var i = 1; i < simplified.length; i++) {
        final prev = simplified[i - 1];
        final current = simplified[i];
        if (prev.level == current.level) {
          expect(prev.name.compareTo(current.name) <= 0, isTrue);
        } else {
          expect(prev.level <= current.level, isTrue);
        }
      }

      final cached = await service.loadClassAbilitiesSimplified('fury');
      expect(identical(simplified, cached), isTrue);

      final missing = await service.loadClassAbilitiesSimplified('missing-class');
      expect(missing, isEmpty);
    });
  });
}
