import 'package:flutter/material.dart';

import '../app_colors.dart';

/// Semantic tokens provide cross-domain mappings (inputs like "fire", "maneuver")
/// to visual tokens (colors/emojis) while centralizing actual color values
/// in AppColors. Use these in widgets instead of calling AppColors lookups directly.
class DamageTokens {
  DamageTokens._();

  static Color color(String element) {
    // Delegate to AppColors for the actual palette value
    return AppColors.getElementalColor(element);
  }

  static String emoji(String element) {
    // Delegate to existing emoji mapping for now (can be migrated here later)
    return AppColors.getDamageTypeEmoji(element);
  }
}

class CharacteristicTokens {
  CharacteristicTokens._();

  static Color color(String characteristic) {
    return AppColors.getCharacteristicColor(characteristic);
  }
}

class PotencyTokens {
  PotencyTokens._();

  static Color color(String strength) {
    return AppColors.getPotencyColor(strength);
  }
}

class KeywordTokens {
  KeywordTokens._();

  static Color color(String keyword) {
    return AppColors.getKeywordColor(keyword);
  }
}

class ActionTokens {
  ActionTokens._();

  static Color color(String actionType) {
    return AppColors.getActionTypeColor(actionType);
  }
}

class HeroicResourceTokens {
  HeroicResourceTokens._();

  static Color color(String resource) {
    return AppColors.getHeroicResourceColor(resource);
  }
}
