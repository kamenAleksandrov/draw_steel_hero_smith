/// Respite and Downtime row widget.
///
/// Contains the buttons for taking respite and navigating to downtime.
library;

import 'package:flutter/material.dart';

import '../../../core/repositories/hero_repository.dart';
import '../../../core/text/heroes_sheet/main_stats/hero_main_stats_view_text.dart';

/// Callback for taking respite action.
typedef OnTakeRespite = void Function();

/// Callback for navigating to downtime.
typedef OnNavigateDowntime = void Function();

/// Row with Respite and Downtime buttons
class RespiteDowntimeRowWidget extends StatelessWidget {
  const RespiteDowntimeRowWidget({
    super.key,
    required this.stats,
    required this.onTakeRespite,
    required this.onNavigateDowntime,
  });

  final HeroMainStats stats;
  final OnTakeRespite onTakeRespite;
  final OnNavigateDowntime onNavigateDowntime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onTakeRespite,
            icon: const Icon(Icons.bedtime_outlined, size: 18),
            label: const Text(HeroMainStatsViewText.respiteButtonLabel),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              side:
                  BorderSide(color: theme.colorScheme.primary.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onNavigateDowntime,
            icon: const Icon(Icons.assignment_outlined, size: 18),
            label: const Text(HeroMainStatsViewText.downtimeButtonLabel),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.secondary,
              side: BorderSide(
                  color: theme.colorScheme.secondary.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shows the respite confirmation dialog.
Future<bool?> showRespiteConfirmDialog(
  BuildContext context,
  HeroMainStats stats,
) async {
  final victories = stats.victories;
  final currentXp = stats.exp;
  final newXp = currentXp + victories;
  final recoveriesMax = stats.recoveriesMaxEffective;

  return showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bedtime_outlined),
            SizedBox(width: 8),
            Text(HeroMainStatsViewText.respiteDialogTitle),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(HeroMainStatsViewText.respiteDialogIntro),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.emoji_events,
                          size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${HeroMainStatsViewText.respiteDialogConvertPrefix}$victories ${victories == 1 ? HeroMainStatsViewText.respiteDialogConvertSingular : HeroMainStatsViewText.respiteDialogConvertPlural}${HeroMainStatsViewText.respiteDialogConvertSuffix}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.star,
                          size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${HeroMainStatsViewText.respiteDialogXpPrefix}$currentXp${HeroMainStatsViewText.respiteDialogArrowSeparator}$newXp',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.favorite,
                          size: 16, color: theme.colorScheme.tertiary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${HeroMainStatsViewText.respiteDialogRecoveriesPrefix}${HeroMainStatsViewText.respiteDialogRecoveriesArrow}$recoveriesMax${HeroMainStatsViewText.respiteDialogRecoveriesSuffix}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(HeroMainStatsViewText.respiteDialogCancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child:
                const Text(HeroMainStatsViewText.respiteDialogConfirmLabel),
          ),
        ],
      );
    },
  );
}
