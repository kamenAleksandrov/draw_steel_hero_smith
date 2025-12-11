import 'package:flutter/material.dart';

/// Constants and mappings for equipment types used across the abilities sheet.
/// 
/// These constants are shared between the main SheetAbilities widget and 
/// the equipment selection dialogs to ensure consistency and DRY principles.
abstract final class EquipmentConstants {
  /// Maps kit feature names to their internal type identifiers
  static const Map<String, List<String>> kitFeatureTypeMappings = {
    'kit': ['kit'],
    'psionic augmentation': ['psionic_augmentation'],
    'enchantment': ['enchantment'],
    'prayer': ['prayer'],
    'elementalist ward': ['ward'],
    'talent ward': ['ward'],
    'conduit ward': ['ward'],
    'ward': ['ward'],
  };

  /// Priority order for sorting kit types
  static const List<String> kitTypePriority = [
    'kit',
    'psionic_augmentation',
    'enchantment',
    'prayer',
    'ward',
    'stormwight_kit',
  ];

  /// Icons for each equipment type
  static const Map<String, IconData> equipmentTypeIcons = {
    'kit': Icons.backpack_outlined,
    'psionic_augmentation': Icons.auto_awesome,
    'enchantment': Icons.auto_fix_high,
    'prayer': Icons.self_improvement,
    'ward': Icons.shield_outlined,
    'stormwight_kit': Icons.pets_outlined,
  };

  /// All equipment types in the system
  static const List<String> allEquipmentTypes = [
    'kit', 'psionic_augmentation', 'enchantment', 'prayer', 'ward', 'stormwight_kit',
  ];

  /// Human-readable titles for equipment types
  static const Map<String, String> equipmentTypeTitles = {
    'kit': 'Standard Kits',
    'psionic_augmentation': 'Psionic Augmentations',
    'enchantment': 'Enchantments',
    'prayer': 'Prayers',
    'ward': 'Wards',
    'stormwight_kit': 'Stormwight Kits',
  };

  /// Formats a type identifier into a human-readable name
  static String formatTypeName(String type) {
    switch (type) {
      case 'psionic_augmentation':
        return 'Augmentation';
      case 'stormwight_kit':
        return 'Stormwight Kit';
      default:
        return type[0].toUpperCase() + type.substring(1);
    }
  }

  /// Sorts equipment types by priority order
  static List<String> sortByPriority(Iterable<String> types) {
    final seen = <String>{};
    final sorted = <String>[];
    
    for (final type in kitTypePriority) {
      if (types.contains(type) && seen.add(type)) {
        sorted.add(type);
      }
    }
    
    for (final type in types) {
      if (seen.add(type)) {
        sorted.add(type);
      }
    }
    
    return sorted;
  }

  /// Titleizes a string (converts snake_case to Title Case)
  static String titleize(String value) {
    if (value.isEmpty) return value;
    return value
        .split(RegExp(r'[_\s]+'))
        .where((segment) => segment.isNotEmpty)
        .map((segment) => '${segment[0].toUpperCase()}${segment.substring(1).toLowerCase()}')
        .join(' ');
  }
}

/// Equipment slot configuration for the hero sheet
class EquipmentSlotConfig {
  const EquipmentSlotConfig({
    required this.label,
    required this.allowedTypes,
    required this.index,
  });
  
  final String label;
  final List<String> allowedTypes;
  final int index;
}
