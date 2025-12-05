/// Data models and constants used by HeroMainStatsView.
/// 
/// This file contains pure data classes and constant tier definitions
/// that are used for displaying hero statistics and calculating insights.
library;

import 'package:flutter/material.dart';

// ============================================================================
// Numeric Field Enum
// ============================================================================

/// Identifies which numeric field is being edited or displayed.
enum NumericField {
  victories,
  exp,
  level,
  staminaCurrent,
  staminaTemp,
  recoveriesCurrent,
  heroicResourceCurrent,
  surgesCurrent,
}

/// Extension to get human-readable labels for numeric fields.
extension NumericFieldLabel on NumericField {
  String get label {
    switch (this) {
      case NumericField.victories:
        return 'Victories';
      case NumericField.exp:
        return 'Experience';
      case NumericField.level:
        return 'Level';
      case NumericField.staminaCurrent:
        return 'Stamina';
      case NumericField.staminaTemp:
        return 'Temporary stamina';
      case NumericField.recoveriesCurrent:
        return 'Recoveries';
      case NumericField.heroicResourceCurrent:
        return 'Heroic resource';
      case NumericField.surgesCurrent:
        return 'Surges';
    }
  }
}

// ============================================================================
// Stat Display Models
// ============================================================================

/// Data for displaying a stat tile with base, total, and modification key.
class StatTileData {
  const StatTileData(this.label, this.baseValue, this.totalValue, this.modKey);

  final String label;
  final int baseValue;
  final int totalValue;
  final String modKey;
}

/// Represents the current stamina state (Healthy, Winded, Dying, Dead).
class StaminaState {
  const StaminaState(this.label, this.color);

  final String label;
  final Color color;
}

// ============================================================================
// Heroic Resource Details
// ============================================================================

/// Details about a class's heroic resource, including in/out of combat info.
class HeroicResourceDetails {
  const HeroicResourceDetails({
    required this.name,
    this.description,
    this.inCombatName,
    this.inCombatDescription,
    this.outCombatName,
    this.outCombatDescription,
  });

  final String name;
  final String? description;
  final String? inCombatName;
  final String? inCombatDescription;
  final String? outCombatName;
  final String? outCombatDescription;
}

/// Request key for fetching heroic resource details.
class HeroicResourceRequest {
  const HeroicResourceRequest({
    required this.classId,
    required this.fallbackName,
  });

  final String? classId;
  final String? fallbackName;

  @override
  bool operator ==(Object other) {
    return other is HeroicResourceRequest &&
        other.classId == classId &&
        other.fallbackName == fallbackName;
  }

  @override
  int get hashCode => Object.hash(classId, fallbackName);
}

// ============================================================================
// Wealth Tiers
// ============================================================================

/// Represents a wealth tier with score threshold and description.
class WealthTier {
  const WealthTier(this.score, this.description);

  final int score;
  final String description;
}

/// Wealth tier definitions for the game system.
const List<WealthTier> wealthTiers = [
  WealthTier(1, 'Common gear, lodging, and travel'),
  WealthTier(2, 'Fine dining, fine lodging, horse and cart'),
  WealthTier(3, 'Catapult, small house'),
  WealthTier(4, 'Library, tavern, manor home, sailing boat'),
  WealthTier(5, 'Church, keep, wizard tower'),
  WealthTier(6, 'Castle, shipyard'),
];

// ============================================================================
// Renown Tiers
// ============================================================================

/// Represents a renown tier for follower count.
class RenownFollowerTier {
  const RenownFollowerTier(this.threshold, this.followers);

  final int threshold;
  final int followers;
}

/// Renown follower tier definitions.
const List<RenownFollowerTier> renownFollowers = [
  RenownFollowerTier(3, 1),
  RenownFollowerTier(6, 2),
  RenownFollowerTier(9, 3),
  RenownFollowerTier(12, 4),
];

/// Represents a renown impression tier.
class RenownImpressionTier {
  const RenownImpressionTier(this.value, this.description);

  final int value;
  final String description;
}

/// Renown impression tier definitions.
const List<RenownImpressionTier> impressionTiers = [
  RenownImpressionTier(1, 'Brigand leader, commoner, shop owner'),
  RenownImpressionTier(2, 'Knight, local guildmaster, professor'),
  RenownImpressionTier(3, 'Cult leader, locally known mage, noble lord'),
  RenownImpressionTier(4, 'Assassin, baron, locally famous entertainer'),
  RenownImpressionTier(5, 'Captain of the watch, high priest, viscount'),
  RenownImpressionTier(6, 'Count, warlord'),
  RenownImpressionTier(7, 'Marquis, world-renowned entertainer'),
  RenownImpressionTier(8, 'Duke, spymaster'),
  RenownImpressionTier(9, 'Archmage, prince'),
  RenownImpressionTier(10, 'Demon lord, monarch'),
  RenownImpressionTier(11, 'Archdevil, archfey, demigod'),
  RenownImpressionTier(12, 'Deity, titan'),
];

// ============================================================================
// XP Advancement Tiers
// ============================================================================

/// Represents an XP advancement tier for leveling.
class XpAdvancement {
  const XpAdvancement(this.level, this.minXp, this.maxXp);

  final int level;
  final int minXp;
  /// Use -1 for no max (level 10).
  final int maxXp;
}

/// XP advancement tier definitions for levels 1-10.
const List<XpAdvancement> xpAdvancementTiers = [
  XpAdvancement(1, 0, 15),
  XpAdvancement(2, 16, 31),
  XpAdvancement(3, 32, 47),
  XpAdvancement(4, 48, 63),
  XpAdvancement(5, 64, 79),
  XpAdvancement(6, 80, 95),
  XpAdvancement(7, 96, 111),
  XpAdvancement(8, 112, 127),
  XpAdvancement(9, 128, 143),
  XpAdvancement(10, 144, -1), // -1 means no max
];
