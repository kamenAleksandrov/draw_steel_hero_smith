/// Insight generators for hero stats display.
/// 
/// Pure functions that generate informative text about wealth, renown, 
/// and XP progression based on the game system rules.
library;

import 'package:collection/collection.dart';

import 'hero_main_stats_models.dart';

/// Generates insight strings about wealth based on current wealth score.
List<String> generateWealthInsights(int wealth) {
  if (wealth <= 0) {
    return const [
      'No notable wealth recorded yet.',
      'Increase wealth to unlock lifestyle perks.',
    ];
  }
  final tier = wealthTiers.lastWhereOrNull((t) => wealth >= t.score);
  final nextTier = wealthTiers.firstWhereOrNull((t) => wealth < t.score);
  final lines = <String>[];
  if (tier != null) {
    lines.add('Score ${tier.score}: ${tier.description}');
  }
  if (nextTier != null) {
    lines.add('Next tier at ${nextTier.score}: ${nextTier.description}');
  } else if (wealth > wealthTiers.last.score) {
    lines.add('You have surpassed all recorded wealth tiers.');
  }
  return lines;
}

/// Generates insight strings about renown based on current renown score.
List<String> generateRenownInsights(int renown) {
  final followers = renownFollowers.fold<int>(
    0,
    (acc, tier) => renown >= tier.threshold ? tier.followers : acc,
  );
  final impressionTier =
      impressionTiers.lastWhereOrNull((tier) => renown >= tier.value);
  final lines = <String>[];
  if (followers > 0) {
    lines.add(
      'Followers: $followers loyal ${followers == 1 ? 'supporter' : 'supporters'}.',
    );
  } else {
    lines.add('Followers: none yet - grow your renown to attract allies.');
  }
  if (impressionTier != null) {
    lines.add(
        'Impression ${impressionTier.value}: ${impressionTier.description}');
  } else {
    lines.add('Impression: your deeds are still largely unknown.');
  }
  return lines;
}

/// Generates insight strings about XP progression based on current XP and level.
List<String> generateXpInsights(int xp, int currentLevel) {
  final currentTier = xpAdvancementTiers.firstWhereOrNull(
    (tier) => tier.level == currentLevel,
  );
  final nextTier = xpAdvancementTiers.firstWhereOrNull(
    (tier) => tier.level == currentLevel + 1,
  );
  
  final lines = <String>[];
  if (currentTier != null) {
    if (currentTier.maxXp == -1) {
      lines.add('Level ${currentTier.level}: ${currentTier.minXp}+ XP');
    } else {
      lines.add('Level ${currentTier.level}: ${currentTier.minXp}-${currentTier.maxXp} XP');
    }
  }
  if (nextTier != null) {
    final xpNeeded = nextTier.minXp - xp;
    if (xpNeeded > 0) {
      lines.add('Next level at ${nextTier.minXp} XP ($xpNeeded more needed)');
    } else {
      lines.add('Ready to level up! (${nextTier.minXp} XP threshold reached)');
    }
  } else if (currentLevel >= 10) {
    lines.add('Maximum level reached!');
  }
  return lines;
}
