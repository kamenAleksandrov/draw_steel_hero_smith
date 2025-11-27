import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hero_smith/core/models/complication_grant_models.dart';

/// Tests for complication grant parsing and validation.
/// 
/// These tests verify that all complications in the JSON data can be parsed
/// correctly and that the grant models work as expected.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Map<String, dynamic>> allComplications;

  setUpAll(() async {
    // Load the complications JSON
    final jsonString = await rootBundle.loadString('data/story/complications.json');
    final List<dynamic> data = json.decode(jsonString);
    allComplications = data.cast<Map<String, dynamic>>();
  });

  group('Complication JSON Loading', () {
    test('complications.json loads successfully', () {
      expect(allComplications, isNotEmpty);
      expect(allComplications.length, greaterThan(50)); // We know there are ~100
    });

    test('all complications have required fields', () {
      for (final comp in allComplications) {
        expect(comp['id'], isNotNull, reason: 'Complication missing id');
        expect(comp['name'], isNotNull, reason: 'Complication ${comp['id']} missing name');
        expect(comp['type'], equals('complication'), 
            reason: 'Complication ${comp['id']} has wrong type');
      }
    });
  });

  group('Grant Parsing', () {
    test('all complications parse without errors', () {
      final errors = <String>[];
      
      for (final comp in allComplications) {
        try {
          final grantsData = comp['grants'] as Map<String, dynamic>?;
          if (grantsData == null) continue;
          
          final grants = ComplicationGrant.parseFromGrantsData(
            grantsData,
            comp['id'] as String,
            comp['name'] as String,
          );
          
          // Verify each grant has required fields
          for (final grant in grants) {
            expect(grant.sourceComplicationId, equals(comp['id']));
            expect(grant.sourceComplicationName, equals(comp['name']));
          }
        } catch (e) {
          errors.add('${comp['name']}: $e');
        }
      }
      
      if (errors.isNotEmpty) {
        fail('Parsing errors:\n${errors.join('\n')}');
      }
    });

    test('treasure grants parse correctly', () {
      // Find a complication with treasure grants
      final compsWithTreasures = allComplications.where((comp) {
        final grants = comp['grants'] as Map<String, dynamic>?;
        return grants != null && grants['treasures'] != null;
      });
      
      expect(compsWithTreasures, isNotEmpty, 
          reason: 'No complications with treasure grants found');
      
      for (final comp in compsWithTreasures) {
        final grantsData = comp['grants'] as Map<String, dynamic>;
        final grants = ComplicationGrant.parseFromGrantsData(
          grantsData,
          comp['id'] as String,
          comp['name'] as String,
        );
        
        // Treasure grants can be TreasureGrant or LeveledTreasureGrant
        final treasureGrants = grants.where((g) => 
            g is TreasureGrant || g is LeveledTreasureGrant);
        expect(treasureGrants, isNotEmpty,
            reason: '${comp['name']} should have treasure grants');
      }
    });

    test('token grants parse correctly', () {
      final compsWithTokens = allComplications.where((comp) {
        final grants = comp['grants'] as Map<String, dynamic>?;
        return grants != null && grants['tokens'] != null;
      });
      
      expect(compsWithTokens, isNotEmpty,
          reason: 'No complications with token grants found');
      
      for (final comp in compsWithTokens) {
        final grantsData = comp['grants'] as Map<String, dynamic>;
        final grants = ComplicationGrant.parseFromGrantsData(
          grantsData,
          comp['id'] as String,
          comp['name'] as String,
        );
        
        final tokenGrants = grants.whereType<TokenGrant>();
        expect(tokenGrants, isNotEmpty,
            reason: '${comp['name']} should have token grants');
        
        for (final token in tokenGrants) {
          expect(token.tokenType, isNotEmpty);
          expect(token.count, greaterThan(0));
        }
      }
    });

    test('skill grants parse correctly', () {
      final compsWithSkills = allComplications.where((comp) {
        final grants = comp['grants'] as Map<String, dynamic>?;
        return grants != null && 
            (grants['skills'] != null || 
             grants['skill_from_group'] != null ||
             grants['skill_from_options'] != null);
      });
      
      expect(compsWithSkills, isNotEmpty,
          reason: 'No complications with skill grants found');
      
      for (final comp in compsWithSkills) {
        final grantsData = comp['grants'] as Map<String, dynamic>;
        final grants = ComplicationGrant.parseFromGrantsData(
          grantsData,
          comp['id'] as String,
          comp['name'] as String,
        );
        
        final allSkillGrants = grants.where((g) => 
            g is SkillGrant || 
            g is SkillFromGroupGrant || 
            g is SkillFromOptionsGrant);
        expect(allSkillGrants, isNotEmpty,
            reason: '${comp['name']} should have skill grants');
      }
    });

    test('language grants parse correctly', () {
      final compsWithLanguages = allComplications.where((comp) {
        final grants = comp['grants'] as Map<String, dynamic>?;
        return grants != null && 
            (grants['languages'] != null || grants['dead_language'] != null);
      });
      
      expect(compsWithLanguages, isNotEmpty,
          reason: 'No complications with language grants found');
      
      for (final comp in compsWithLanguages) {
        final grantsData = comp['grants'] as Map<String, dynamic>;
        final grants = ComplicationGrant.parseFromGrantsData(
          grantsData,
          comp['id'] as String,
          comp['name'] as String,
        );
        
        final langGrants = grants.where((g) => 
            g is LanguageGrant || g is DeadLanguageGrant);
        expect(langGrants, isNotEmpty,
            reason: '${comp['name']} should have language grants');
      }
    });

    test('increase_total grants parse with dynamic values', () {
      final compsWithIncreases = allComplications.where((comp) {
        final grants = comp['grants'] as Map<String, dynamic>?;
        return grants != null && grants['increase_total'] != null;
      });
      
      expect(compsWithIncreases, isNotEmpty,
          reason: 'No complications with increase_total grants found');
      
      for (final comp in compsWithIncreases) {
        final grantsData = comp['grants'] as Map<String, dynamic>;
        final grants = ComplicationGrant.parseFromGrantsData(
          grantsData,
          comp['id'] as String,
          comp['name'] as String,
        );
        
        // Can be IncreaseTotalGrant or IncreaseTotalPerEchelonGrant
        final increaseGrants = grants.where((g) => 
            g is IncreaseTotalGrant || g is IncreaseTotalPerEchelonGrant);
        expect(increaseGrants, isNotEmpty,
            reason: '${comp['name']} should have increase grants');
      }
    });

    test('pick_one grants parse with options', () {
      final compsWithPickOne = allComplications.where((comp) {
        final grants = comp['grants'] as Map<String, dynamic>?;
        return grants != null && grants['pick_one'] != null;
      });
      
      expect(compsWithPickOne, isNotEmpty,
          reason: 'No complications with pick_one grants found');
      
      for (final comp in compsWithPickOne) {
        final grantsData = comp['grants'] as Map<String, dynamic>;
        final grants = ComplicationGrant.parseFromGrantsData(
          grantsData,
          comp['id'] as String,
          comp['name'] as String,
        );
        
        final pickOneGrants = grants.whereType<PickOneGrant>();
        expect(pickOneGrants, isNotEmpty,
            reason: '${comp['name']} should have pick_one grants');
        
        for (final grant in pickOneGrants) {
          expect(grant.options, isNotEmpty,
              reason: '${comp['name']} pick_one should have options');
          expect(grant.options.length, greaterThanOrEqualTo(2),
              reason: '${comp['name']} pick_one should have at least 2 options');
        }
      }
    });

    test('ability grants parse correctly', () {
      final compsWithAbilities = allComplications.where((comp) {
        final grants = comp['grants'] as Map<String, dynamic>?;
        return grants != null && grants['abilities'] != null;
      });
      
      expect(compsWithAbilities, isNotEmpty,
          reason: 'No complications with ability grants found');
      
      for (final comp in compsWithAbilities) {
        final grantsData = comp['grants'] as Map<String, dynamic>;
        final grants = ComplicationGrant.parseFromGrantsData(
          grantsData,
          comp['id'] as String,
          comp['name'] as String,
        );
        
        final abilityGrants = grants.whereType<AbilityGrant>();
        expect(abilityGrants, isNotEmpty,
            reason: '${comp['name']} should have ability grants');
        
        for (final grant in abilityGrants) {
          expect(grant.abilityName, isNotEmpty);
        }
      }
    });

    test('feature grants parse correctly', () {
      final compsWithFeatures = allComplications.where((comp) {
        final grants = comp['grants'] as Map<String, dynamic>?;
        return grants != null && grants['features'] != null;
      });
      
      expect(compsWithFeatures, isNotEmpty,
          reason: 'No complications with feature grants found');
      
      for (final comp in compsWithFeatures) {
        final grantsData = comp['grants'] as Map<String, dynamic>;
        final grants = ComplicationGrant.parseFromGrantsData(
          grantsData,
          comp['id'] as String,
          comp['name'] as String,
        );
        
        final featureGrants = grants.whereType<FeatureGrant>();
        expect(featureGrants, isNotEmpty,
            reason: '${comp['name']} should have feature grants');
        
        for (final grant in featureGrants) {
          expect(grant.featureName, isNotEmpty);
        }
      }
    });
  });

  group('Grant Type Coverage', () {
    test('all grant types are covered in test data', () {
      // Collect all grant types that appear in the data
      final grantTypesSeen = <ComplicationGrantType>{};
      
      for (final comp in allComplications) {
        final grantsData = comp['grants'] as Map<String, dynamic>?;
        if (grantsData == null) continue;
        
        final grants = ComplicationGrant.parseFromGrantsData(
          grantsData,
          comp['id'] as String,
          comp['name'] as String,
        );
        
        for (final grant in grants) {
          grantTypesSeen.add(grant.type);
        }
      }
      
      // Log which grant types we found
      print('Grant types found in data: ${grantTypesSeen.map((t) => t.name).join(', ')}');
      
      // We should have a good variety
      expect(grantTypesSeen.length, greaterThanOrEqualTo(10),
          reason: 'Expected at least 10 different grant types in the data');
    });
  });

  group('Grant Serialization', () {
    test('grants can be serialized and deserialized', () {
      for (final comp in allComplications.take(20)) { // Test first 20 for speed
        final grantsData = comp['grants'] as Map<String, dynamic>?;
        if (grantsData == null) continue;
        
        final grants = ComplicationGrant.parseFromGrantsData(
          grantsData,
          comp['id'] as String,
          comp['name'] as String,
        );
        
        for (final grant in grants) {
          // Serialize to JSON
          final jsonMap = grant.toJson();
          expect(jsonMap, isNotNull);
          expect(jsonMap['type'], equals(grant.type.name));
          expect(jsonMap['sourceComplicationId'], equals(comp['id']));
          expect(jsonMap['sourceComplicationName'], equals(comp['name']));
          
          // Deserialize back
          final restored = ComplicationGrant.fromJson(jsonMap);
          expect(restored.type, equals(grant.type));
          expect(restored.sourceComplicationId, equals(grant.sourceComplicationId));
          expect(restored.sourceComplicationName, equals(grant.sourceComplicationName));
        }
      }
    });
  });
}
