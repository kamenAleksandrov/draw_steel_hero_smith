// ignore_for_file: avoid_print
/// Validates all complications in the JSON file can be parsed correctly.
/// Run with: dart run scripts/validate_complications.dart

import 'dart:convert';
import 'dart:io';

void main() async {
  print('='.padRight(60, '='));
  print('COMPLICATION VALIDATION SCRIPT');
  print('='.padRight(60, '='));
  print('');

  final file = File('data/story/complications.json');
  if (!file.existsSync()) {
    print('ERROR: complications.json not found!');
    print('Make sure to run this from the hero_smith directory.');
    exit(1);
  }

  final content = file.readAsStringSync();
  final List<dynamic> complications;
  
  try {
    complications = jsonDecode(content) as List<dynamic>;
  } catch (e) {
    print('ERROR: Failed to parse JSON: $e');
    exit(1);
  }

  print('Found ${complications.length} complications to validate.\n');

  int passed = 0;
  int failed = 0;
  final errors = <String, List<String>>{};

  for (final comp in complications) {
    if (comp is! Map) {
      failed++;
      errors['INVALID_STRUCTURE'] = [...(errors['INVALID_STRUCTURE'] ?? []), 'Not a map: $comp'];
      continue;
    }

    final id = comp['id']?.toString() ?? 'UNKNOWN';
    final name = comp['name']?.toString() ?? 'UNKNOWN';
    final compErrors = <String>[];

    // Validate basic structure
    if (comp['id'] == null) compErrors.add('Missing id');
    if (comp['name'] == null) compErrors.add('Missing name');
    if (comp['type'] != 'complication') compErrors.add('Invalid type: ${comp['type']}');

    // Validate grants if present
    final grants = comp['grants'];
    if (grants != null && grants is Map) {
      compErrors.addAll(_validateGrants(grants.cast<String, dynamic>(), id));
    }

    // Validate effects if present
    final effects = comp['effects'];
    if (effects != null && effects is Map) {
      compErrors.addAll(_validateEffects(effects.cast<String, dynamic>(), id));
    }

    if (compErrors.isEmpty) {
      passed++;
      print('✓ $name');
    } else {
      failed++;
      errors[id] = compErrors;
      print('✗ $name');
      for (final err in compErrors) {
        print('    - $err');
      }
    }
  }

  print('');
  print('='.padRight(60, '='));
  print('SUMMARY');
  print('='.padRight(60, '='));
  print('Total: ${complications.length}');
  print('Passed: $passed');
  print('Failed: $failed');
  
  if (failed > 0) {
    print('');
    print('FAILED COMPLICATIONS:');
    for (final entry in errors.entries) {
      print('  ${entry.key}:');
      for (final err in entry.value) {
        print('    - $err');
      }
    }
    exit(1);
  } else {
    print('');
    print('All complications validated successfully!');
    exit(0);
  }
}

List<String> _validateGrants(Map<String, dynamic> grants, String compId) {
  final errors = <String>[];

  // Validate skills
  if (grants['skills'] != null) {
    errors.addAll(_validateSkillGrants(grants['skills'], compId));
  }

  // Validate treasures
  if (grants['treasures'] != null) {
    errors.addAll(_validateTreasureGrants(grants['treasures'], compId));
  }

  // Validate tokens
  if (grants['tokens'] != null) {
    errors.addAll(_validateTokenGrants(grants['tokens'], compId));
  }

  // Validate languages
  if (grants['languages'] != null) {
    errors.addAll(_validateLanguageGrants(grants['languages'], compId));
  }

  // Validate increase_total
  if (grants['increase_total'] != null) {
    errors.addAll(_validateIncreaseTotalGrants(grants['increase_total'], compId));
  }

  // Validate decrease_total
  if (grants['decrease_total'] != null) {
    errors.addAll(_validateDecreaseTotalGrants(grants['decrease_total'], compId));
  }

  // Validate set_base_stat_if_not_lower
  if (grants['set_base_stat_if_not_lower'] != null) {
    errors.addAll(_validateSetBaseStatGrants(grants['set_base_stat_if_not_lower'], compId));
  }

  // Validate abilities
  if (grants['abilities'] != null) {
    errors.addAll(_validateAbilityGrants(grants['abilities'], compId));
  }

  // Validate features
  if (grants['features'] != null) {
    errors.addAll(_validateFeatureGrants(grants['features'], compId));
  }

  // Validate ancestry_traits
  if (grants['ancestry_traits'] != null) {
    errors.addAll(_validateAncestryTraitsGrants(grants['ancestry_traits'], compId));
  }

  // Validate pick_one
  if (grants['pick_one'] != null) {
    errors.addAll(_validatePickOneGrants(grants['pick_one'], compId));
  }

  return errors;
}

List<String> _validateEffects(Map<String, dynamic> effects, String compId) {
  final errors = <String>[];
  
  // Effects should have benefit, drawback, or both
  final benefit = effects['benefit'];
  final drawback = effects['drawback'];
  final both = effects['both'];

  if (benefit == null && drawback == null && both == null) {
    errors.add('Effects has no benefit, drawback, or both');
  }

  return errors;
}

List<String> _validateSkillGrants(dynamic skills, String compId) {
  final errors = <String>[];

  if (skills is List) {
    for (var i = 0; i < skills.length; i++) {
      final skill = skills[i];
      if (skill is Map) {
        // Valid formats:
        // { "name": "Skill Name" }
        // { "group": "group_name", "count": 1 }
        // { "options": ["Skill1", "Skill2"] }
        if (skill['name'] == null && skill['group'] == null && skill['options'] == null) {
          errors.add('Skill[$i] has no name, group, or options');
        }
        if (skill['group'] != null && skill['count'] == null) {
          // count defaults to 1, so this is OK
        }
      } else if (skill is String) {
        // Simple skill name - OK
      } else {
        errors.add('Skill[$i] invalid format: $skill');
      }
    }
  } else if (skills is Map) {
    // Single skill object
    if (skills['name'] == null && skills['group'] == null && skills['options'] == null) {
      errors.add('Skills object has no name, group, or options');
    }
  } else if (skills is String) {
    // Simple skill name - OK
  } else {
    errors.add('Invalid skills format: ${skills.runtimeType}');
  }

  return errors;
}

List<String> _validateTreasureGrants(dynamic treasures, String compId) {
  final errors = <String>[];

  if (treasures is List) {
    for (var i = 0; i < treasures.length; i++) {
      final treasure = treasures[i];
      if (treasure is Map) {
        final type = treasure['type'];
        if (type == null) {
          errors.add('Treasure[$i] missing type');
        }
        // echelon is optional
        // choice is optional (defaults to true)
      } else {
        errors.add('Treasure[$i] invalid format: $treasure');
      }
    }
  } else if (treasures is Map) {
    if (treasures['type'] == null) {
      errors.add('Treasures object missing type');
    }
  } else {
    errors.add('Invalid treasures format: ${treasures.runtimeType}');
  }

  return errors;
}

List<String> _validateTokenGrants(dynamic tokens, String compId) {
  final errors = <String>[];

  if (tokens is Map) {
    // Format: { "name": "token_type", "count": 3 }
    final name = tokens['name'];
    final count = tokens['count'];
    if (name == null) {
      errors.add('Tokens missing name');
    }
    if (count == null) {
      errors.add('Tokens missing count');
    } else if (count is! num) {
      errors.add('Tokens count is not a number: $count');
    }
  } else if (tokens is List) {
    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (token is Map) {
        if (token['name'] == null) errors.add('Token[$i] missing name');
        if (token['count'] == null) errors.add('Token[$i] missing count');
      } else {
        errors.add('Token[$i] invalid format: $token');
      }
    }
  } else {
    errors.add('Invalid tokens format: ${tokens.runtimeType}');
  }

  return errors;
}

List<String> _validateLanguageGrants(dynamic languages, String compId) {
  final errors = <String>[];

  if (languages is num) {
    // Simple count - OK
  } else if (languages is Map) {
    // { "count": 1 } or { "dead": 1 } or { "count": 1, "dead": 1 }
    final count = languages['count'];
    final dead = languages['dead'];
    if (count == null && dead == null) {
      errors.add('Languages has neither count nor dead');
    }
  } else if (languages is List) {
    for (var i = 0; i < languages.length; i++) {
      final lang = languages[i];
      if (lang is! Map && lang is! num) {
        errors.add('Language[$i] invalid format: $lang');
      }
    }
  } else {
    errors.add('Invalid languages format: ${languages.runtimeType}');
  }

  return errors;
}

List<String> _validateIncreaseTotalGrants(dynamic data, String compId) {
  final errors = <String>[];

  void validateSingle(Map<String, dynamic> item, String prefix) {
    final stat = item['stat'];
    final value = item['value'];
    final valuePerEchelon = item['value_per_echelon'];

    if (stat == null) {
      errors.add('$prefix missing stat');
    }
    if (value == null && valuePerEchelon == null) {
      errors.add('$prefix has neither value nor value_per_echelon');
    }
    // value can be a number or "level" (for dynamic scaling)
    if (value != null && value is! num && value != 'level') {
      errors.add('$prefix value is not a number or "level": $value');
    }
  }

  if (data is Map) {
    validateSingle(data.cast<String, dynamic>(), 'increase_total');
  } else if (data is List) {
    for (var i = 0; i < data.length; i++) {
      if (data[i] is Map) {
        validateSingle((data[i] as Map).cast<String, dynamic>(), 'increase_total[$i]');
      } else {
        errors.add('increase_total[$i] invalid format: ${data[i]}');
      }
    }
  } else {
    errors.add('Invalid increase_total format: ${data.runtimeType}');
  }

  return errors;
}

List<String> _validateDecreaseTotalGrants(dynamic data, String compId) {
  final errors = <String>[];

  void validateSingle(Map<String, dynamic> item, String prefix) {
    if (item['stat'] == null) errors.add('$prefix missing stat');
    if (item['value'] == null) errors.add('$prefix missing value');
  }

  if (data is Map) {
    validateSingle(data.cast<String, dynamic>(), 'decrease_total');
  } else if (data is List) {
    for (var i = 0; i < data.length; i++) {
      if (data[i] is Map) {
        validateSingle((data[i] as Map).cast<String, dynamic>(), 'decrease_total[$i]');
      } else {
        errors.add('decrease_total[$i] invalid format: ${data[i]}');
      }
    }
  } else {
    errors.add('Invalid decrease_total format: ${data.runtimeType}');
  }

  return errors;
}

List<String> _validateSetBaseStatGrants(dynamic data, String compId) {
  final errors = <String>[];

  void validateSingle(Map<String, dynamic> item, String prefix) {
    if (item['stat'] == null) errors.add('$prefix missing stat');
    if (item['value'] == null) errors.add('$prefix missing value');
  }

  if (data is Map) {
    validateSingle(data.cast<String, dynamic>(), 'set_base_stat_if_not_lower');
  } else if (data is List) {
    for (var i = 0; i < data.length; i++) {
      if (data[i] is Map) {
        validateSingle((data[i] as Map).cast<String, dynamic>(), 'set_base_stat_if_not_lower[$i]');
      } else {
        errors.add('set_base_stat_if_not_lower[$i] invalid format: ${data[i]}');
      }
    }
  } else {
    errors.add('Invalid set_base_stat_if_not_lower format: ${data.runtimeType}');
  }

  return errors;
}

List<String> _validateAbilityGrants(dynamic data, String compId) {
  final errors = <String>[];

  if (data is List) {
    for (var i = 0; i < data.length; i++) {
      final ability = data[i];
      if (ability is String) {
        // Simple ability name - OK
      } else if (ability is Map) {
        if (ability['name'] == null) {
          errors.add('Ability[$i] missing name');
        }
      } else {
        errors.add('Ability[$i] invalid format: $ability');
      }
    }
  } else if (data is String) {
    // Single ability name - OK
  } else if (data is Map) {
    if (data['name'] == null) {
      errors.add('Abilities object missing name');
    }
  } else {
    errors.add('Invalid abilities format: ${data.runtimeType}');
  }

  return errors;
}

List<String> _validateFeatureGrants(dynamic data, String compId) {
  final errors = <String>[];

  if (data is List) {
    for (var i = 0; i < data.length; i++) {
      final feature = data[i];
      if (feature is String) {
        // Simple feature type - OK
      } else if (feature is Map) {
        // Feature object - should have type or name
        if (feature['type'] == null && feature['name'] == null) {
          errors.add('Feature[$i] missing type or name');
        }
      } else {
        errors.add('Feature[$i] invalid format: $feature');
      }
    }
  } else if (data is String) {
    // Single feature type - OK
  } else if (data is Map) {
    if (data['type'] == null && data['name'] == null) {
      errors.add('Features object missing type or name');
    }
  } else {
    errors.add('Invalid features format: ${data.runtimeType}');
  }

  return errors;
}

List<String> _validateAncestryTraitsGrants(dynamic data, String compId) {
  final errors = <String>[];

  if (data is Map) {
    if (data['ancestry'] == null) {
      errors.add('ancestry_traits missing ancestry');
    }
    if (data['ancestry_points'] == null) {
      errors.add('ancestry_traits missing ancestry_points');
    }
  } else {
    errors.add('Invalid ancestry_traits format: ${data.runtimeType}');
  }

  return errors;
}

List<String> _validatePickOneGrants(dynamic data, String compId) {
  final errors = <String>[];

  if (data is List) {
    if (data.isEmpty) {
      errors.add('pick_one has no options');
    }
    for (var i = 0; i < data.length; i++) {
      if (data[i] is! Map) {
        errors.add('pick_one[$i] is not a map');
      }
    }
  } else {
    errors.add('Invalid pick_one format: ${data.runtimeType}');
  }

  return errors;
}
