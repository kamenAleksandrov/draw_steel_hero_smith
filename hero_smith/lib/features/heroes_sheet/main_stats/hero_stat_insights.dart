/// Insight generators for hero stats display.
///
/// Pure functions that generate informative text about wealth, renown,
/// and XP progression based on the game system rules.
library;

import 'package:collection/collection.dart';

import '../../../core/text/heroes_sheet/main_stats/hero_stat_insights_text.dart';
import 'hero_main_stats_models.dart';

/// Generates insight strings about wealth based on current wealth score.
List<String> generateWealthInsights(int wealth) {
  if (wealth <= 0) {
    return const [
      HeroStatInsightsText.wealthNonePrimary,
      HeroStatInsightsText.wealthNoneSecondary,
    ];
  }
  final tier = wealthTiers.lastWhereOrNull((t) => wealth >= t.score);
  final nextTier = wealthTiers.firstWhereOrNull((t) => wealth < t.score);
  final lines = <String>[];
  if (tier != null) {
    lines.add(
        HeroStatInsightsText.wealthScoreLine(tier.score, tier.description));
  }
  if (nextTier != null) {
    lines.add(
      HeroStatInsightsText.wealthNextTierLine(
          nextTier.score, nextTier.description),
    );
  } else if (wealth > wealthTiers.last.score) {
    lines.add(HeroStatInsightsText.wealthSurpassedAll);
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
    lines.add(HeroStatInsightsText.renownFollowersLine(followers));
  } else {
    lines.add(HeroStatInsightsText.renownNoFollowers);
  }
  if (impressionTier != null) {
    lines.add(
      HeroStatInsightsText.impressionTierLine(
        impressionTier.value,
        impressionTier.description,
      ),
    );
  } else {
    lines.add(HeroStatInsightsText.impressionUnknown);
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
      lines.add(
        HeroStatInsightsText.xpLevelMinPlusLine(
          currentTier.level,
          currentTier.minXp,
        ),
      );
    } else {
      lines.add(
        HeroStatInsightsText.xpLevelRangeLine(
          currentTier.level,
          currentTier.minXp,
          currentTier.maxXp,
        ),
      );
    }
  }
  if (nextTier != null) {
    final xpNeeded = nextTier.minXp - xp;
    if (xpNeeded > 0) {
      lines.add(
        HeroStatInsightsText.xpNextLevelNeededLine(nextTier.minXp, xpNeeded),
      );
    } else {
      lines.add(HeroStatInsightsText.xpReadyToLevelUpLine(nextTier.minXp));
    }
  } else if (currentLevel >= 10) {
    lines.add(HeroStatInsightsText.maxLevelReached);
  }
  return lines;
}
