/// Dialog functions for editing stats.
///
/// Contains reusable dialog functions for editing various stats like
/// number fields, mods, stats, size, XP, etc.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/repositories/hero_repository.dart';
import '../../../core/text/heroes_sheet/main_stats/hero_main_stats_view_text.dart';
import 'hero_main_stats_models.dart';
import 'hero_stamina_helpers.dart';

/// Common input formatters for numeric fields.
List<TextInputFormatter> numericFormatters(bool allowNegative, int maxLength) {
  return [
    allowNegative
        ? FilteringTextInputFormatter.allow(RegExp(r'-?\d*'))
        : FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(maxLength),
  ];
}

/// Shows a dialog to edit a generic number field.
Future<int?> showNumberEditDialog(
  BuildContext context, {
  required String label,
  required int currentValue,
  bool allowNegative = false,
}) async {
  final controller = TextEditingController(text: currentValue.toString());

  try {
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('${HeroMainStatsViewText.numberEditTitlePrefix}$label'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
            inputFormatters: allowNegative
                ? numericFormatters(true, 4)
                : numericFormatters(false, 3),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(HeroMainStatsViewText.numberEditCancelLabel),
            ),
            TextButton(
              onPressed: () {
                final value = int.tryParse(controller.text);
                if (value != null) {
                  Navigator.of(dialogContext).pop(value);
                }
              },
              child: const Text(HeroMainStatsViewText.numberEditSaveLabel),
            ),
          ],
        );
      },
    );
    return result;
  } finally {
    await Future.delayed(const Duration(milliseconds: 50));
    controller.dispose();
  }
}

/// Shows a dialog to edit XP with insights.
Future<int?> showXpEditDialog(
  BuildContext context, {
  required int currentXp,
  required int currentLevel,
  required List<String> insights,
}) async {
  final controller = TextEditingController(text: currentXp.toString());

  try {
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(HeroMainStatsViewText.xpEditTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${HeroMainStatsViewText.xpEditCurrentLevelPrefix}$currentLevel',
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: HeroMainStatsViewText.xpEditExperienceLabel,
                  border: OutlineInputBorder(),
                ),
                inputFormatters: numericFormatters(false, 3),
              ),
              if (insights.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(dialogContext)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_graph,
                            size: 16,
                            color: Theme.of(dialogContext).colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            HeroMainStatsViewText.xpEditInsightsTitle,
                            style: Theme.of(dialogContext)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...insights.map((insight) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              insight,
                              style:
                                  Theme.of(dialogContext).textTheme.bodySmall,
                            ),
                          )),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(HeroMainStatsViewText.xpEditCancelLabel),
            ),
            TextButton(
              onPressed: () {
                final value = int.tryParse(controller.text);
                if (value != null) {
                  Navigator.of(dialogContext).pop(value);
                }
              },
              child: const Text(HeroMainStatsViewText.xpEditSaveLabel),
            ),
          ],
        );
      },
    );
    return result;
  } finally {
    await Future.delayed(const Duration(milliseconds: 50));
    controller.dispose();
  }
}

/// Shows a dialog to edit a modification value.
Future<int?> showModEditDialog(
  BuildContext context, {
  required String title,
  required int baseValue,
  required int currentModValue,
  required List<String> insights,
  String sourcesDescription = '',
}) async {
  final controller = TextEditingController(text: currentModValue.toString());

  try {
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('${HeroMainStatsViewText.modEditTitlePrefix}$title'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${HeroMainStatsViewText.modEditBasePrefix}$baseValue'),
              if (sourcesDescription.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(dialogContext).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 16,
                        color: Theme.of(dialogContext)
                            .colorScheme
                            .onPrimaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          sourcesDescription,
                          style: TextStyle(
                            color: Theme.of(dialogContext)
                                .colorScheme
                                .onPrimaryContainer,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(signed: true),
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: HeroMainStatsViewText.modEditModificationLabel,
                  border: OutlineInputBorder(),
                  helperText: HeroMainStatsViewText.modEditHelperText,
                ),
                inputFormatters: numericFormatters(true, 4),
              ),
              if (insights.isNotEmpty) ...[
                const SizedBox(height: 16),
                ...insights.map((insight) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        insight,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(HeroMainStatsViewText.modEditCancelLabel),
            ),
            TextButton(
              onPressed: () {
                final value = int.tryParse(controller.text);
                if (value != null) {
                  Navigator.of(dialogContext).pop(value);
                }
              },
              child: const Text(HeroMainStatsViewText.modEditSaveLabel),
            ),
          ],
        );
      },
    );
    return result;
  } finally {
    await Future.delayed(const Duration(milliseconds: 50));
    controller.dispose();
  }
}

/// Shows a dialog to edit a stat with auto bonuses.
Future<int?> showStatEditDialog(
  BuildContext context, {
  required String label,
  required int baseValue,
  required int currentModValue,
  String autoBonusDescription = '',
}) async {
  final controller = TextEditingController(text: currentModValue.toString());

  try {
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('${HeroMainStatsViewText.statEditTitlePrefix}$label'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${HeroMainStatsViewText.statEditBasePrefix}$baseValue'),
              if (autoBonusDescription.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(dialogContext).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 16,
                        color: Theme.of(dialogContext)
                            .colorScheme
                            .onPrimaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          autoBonusDescription,
                          style: TextStyle(
                            color: Theme.of(dialogContext)
                                .colorScheme
                                .onPrimaryContainer,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(signed: true),
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: HeroMainStatsViewText.statEditModificationLabel,
                  border: OutlineInputBorder(),
                  helperText: HeroMainStatsViewText.statEditHelperText,
                ),
                inputFormatters: numericFormatters(true, 4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(HeroMainStatsViewText.statEditCancelLabel),
            ),
            TextButton(
              onPressed: () {
                final value = int.tryParse(controller.text);
                if (value != null) {
                  Navigator.of(dialogContext).pop(value);
                }
              },
              child: const Text(HeroMainStatsViewText.statEditSaveLabel),
            ),
          ],
        );
      },
    );
    return result;
  } finally {
    await Future.delayed(const Duration(milliseconds: 50));
    controller.dispose();
  }
}

/// Shows a dialog to edit size.
Future<int?> showSizeEditDialog(
  BuildContext context, {
  required String sizeBase,
  required int currentModValue,
  String sourcesDescription = '',
}) async {
  final controller = TextEditingController(text: currentModValue.toString());
  final parsed = HeroMainStats.parseSize(sizeBase);
  final categoryName = switch (parsed.category) {
    'T' => HeroMainStatsViewText.sizeCategoryTiny,
    'S' => HeroMainStatsViewText.sizeCategorySmall,
    'M' => HeroMainStatsViewText.sizeCategoryMedium,
    'L' => HeroMainStatsViewText.sizeCategoryLarge,
    _ => '',
  };
  final baseDisplay =
      categoryName.isNotEmpty ? '$sizeBase ($categoryName)' : sizeBase;

  try {
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(HeroMainStatsViewText.sizeEditTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${HeroMainStatsViewText.sizeEditBasePrefix}$baseDisplay'),
              if (sourcesDescription.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(dialogContext).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 16,
                        color: Theme.of(dialogContext)
                            .colorScheme
                            .onPrimaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          sourcesDescription,
                          style: TextStyle(
                            color: Theme.of(dialogContext)
                                .colorScheme
                                .onPrimaryContainer,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(signed: true),
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: HeroMainStatsViewText.sizeEditModificationLabel,
                  border: OutlineInputBorder(),
                  helperText: HeroMainStatsViewText.sizeEditHelperText,
                ),
                inputFormatters: numericFormatters(true, 4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(HeroMainStatsViewText.sizeEditCancelLabel),
            ),
            TextButton(
              onPressed: () {
                final value = int.tryParse(controller.text);
                if (value != null) {
                  Navigator.of(dialogContext).pop(value);
                }
              },
              child: const Text(HeroMainStatsViewText.sizeEditSaveLabel),
            ),
          ],
        );
      },
    );
    return result;
  } finally {
    await Future.delayed(const Duration(milliseconds: 50));
    controller.dispose();
  }
}

/// Shows a dialog to display max vital breakdown.
Future<void> showMaxVitalBreakdownDialog(
  BuildContext context, {
  required String label,
  required String modKey,
  required int classBase,
  required int equipmentBonus,
  required int featureBonus,
  required int choiceValue,
  required int userValue,
  required int total,
  required Future<void> Function() onEditModifier,
}) async {
  final theme = Theme.of(context);
  final hasChoice = equipmentBonus != 0 || choiceValue != 0;
  final hasUser = userValue != 0;
  final hasFeature = featureBonus != 0;

  await showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(
          '$label${HeroMainStatsViewText.maxVitalBreakdownTitleSuffix}',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBreakdownRow(
              theme,
              HeroMainStatsViewText.breakdownClassBaseLabel,
              classBase,
            ),
            if (equipmentBonus > 0)
              _buildBreakdownRow(
                theme,
                HeroMainStatsViewText.breakdownEquipmentLabel,
                equipmentBonus,
                isBonus: equipmentBonus > 0,
              ),
            if (hasFeature)
              _buildBreakdownRow(
                theme,
                HeroMainStatsViewText.breakdownFeaturesLabel,
                featureBonus,
                isBonus: featureBonus > 0,
              ),
            if (hasChoice)
              _buildBreakdownRow(
                theme,
                HeroMainStatsViewText.breakdownChoiceModsLabel,
                choiceValue,
                isBonus: choiceValue >= 0,
              ),
            if (hasUser)
              _buildBreakdownRow(
                theme,
                HeroMainStatsViewText.breakdownManualModsLabel,
                userValue,
                isBonus: userValue >= 0,
              ),
            const Divider(),
            _buildBreakdownRow(
              theme,
              HeroMainStatsViewText.breakdownTotalLabel,
              total,
              isBold: true,
            ),
            const SizedBox(height: 16),
            Text(
              HeroMainStatsViewText.breakdownEditHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(HeroMainStatsViewText.breakdownCloseLabel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await onEditModifier();
            },
            child:
                const Text(HeroMainStatsViewText.breakdownEditModifierLabel),
          ),
        ],
      );
    },
  );
}

Widget _buildBreakdownRow(ThemeData theme, String label, int value,
    {bool isBonus = false, bool isBold = false}) {
  final valueText = isBonus ? '+$value' : value.toString();
  final color = isBonus
      ? Colors.green
      : (value < 0 ? Colors.red : theme.colorScheme.onSurface);

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          valueText,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: isBold ? null : color,
          ),
        ),
      ],
    ),
  );
}

/// Shows a dialog to prompt for an amount (damage/healing).
Future<int?> promptForAmount(
  BuildContext context, {
  required String title,
  String? description,
}) async {
  final controller = TextEditingController(text: '1');

  try {
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (description != null) ...[
                Text(description),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: numericFormatters(false, 3),
                decoration: const InputDecoration(
                  labelText: HeroMainStatsViewText.promptAmountLabel,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(HeroMainStatsViewText.promptCancelLabel),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(controller.text.trim());
                if (value == null || value <= 0) {
                  Navigator.of(dialogContext).pop();
                } else {
                  Navigator.of(dialogContext).pop(value);
                }
              },
              child: const Text(HeroMainStatsViewText.promptApplyLabel),
            ),
          ],
        );
      },
    );

    if (result != null) {
      await Future.delayed(const Duration(milliseconds: 300));
    }

    return result;
  } finally {
    await Future.delayed(const Duration(milliseconds: 100));
    controller.dispose();
  }
}

/// Shows a dialog to prompt for healing amount with temp option.
Future<({int amount, bool applyToTemp})?> promptForHealingAmount(
  BuildContext context, {
  required String title,
  String? description,
}) async {
  final controller = TextEditingController(text: '1');

  try {
    final result = await showDialog<({int amount, bool applyToTemp})>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (description != null) ...[
                Text(description),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: numericFormatters(false, 3),
                decoration: const InputDecoration(
                  labelText: HeroMainStatsViewText.promptAmountLabel,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(HeroMainStatsViewText.promptCancelLabel),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(controller.text.trim());
                if (value == null || value <= 0) {
                  Navigator.of(dialogContext).pop();
                } else {
                  Navigator.of(dialogContext).pop(
                    (amount: value, applyToTemp: true),
                  );
                }
              },
              child: const Text(HeroMainStatsViewText.promptApplyTempLabel),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(controller.text.trim());
                if (value == null || value <= 0) {
                  Navigator.of(dialogContext).pop();
                } else {
                  Navigator.of(dialogContext).pop(
                    (amount: value, applyToTemp: false),
                  );
                }
              },
              child: const Text(HeroMainStatsViewText.promptApplyLabel),
            ),
          ],
        );
      },
    );

    if (result != null) {
      await Future.delayed(const Duration(milliseconds: 300));
    }

    return result;
  } finally {
    await Future.delayed(const Duration(milliseconds: 100));
    controller.dispose();
  }
}

/// Shows a dice roll confirmation dialog for resource generation.
Future<int?> showDiceRollDialog(
  BuildContext context, {
  required int rolledValue,
  required List<int> alternatives,
  required String diceType,
  Map<int, int>? diceToValueMapping,
}) async {
  final theme = Theme.of(context);

  // Find which dice roll corresponds to the rolled value
  int? rolledDice;
  if (diceToValueMapping != null) {
    for (final entry in diceToValueMapping.entries) {
      if (entry.value == rolledValue) {
        rolledDice = entry.key;
        break;
      }
    }
  }

  return showDialog<int>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.casino, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text('$diceType${HeroMainStatsViewText.diceRollTitleSuffix}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (rolledDice != null && diceToValueMapping != null) ...[
              Text(
                '${HeroMainStatsViewText.diceRolledDicePrefix}$rolledDice',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${HeroMainStatsViewText.diceGainPrefix}$rolledValue${HeroMainStatsViewText.diceGainSuffix}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
            ] else
              Text(
                '${HeroMainStatsViewText.diceRolledValuePrefix}$rolledValue',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            const SizedBox(height: 16),
            // Show the dice-to-value mapping table if available
            if (diceToValueMapping != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      HeroMainStatsViewText.diceRollValuesTitle,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: diceToValueMapping.entries.map((entry) {
                        final isRolled = entry.key == rolledDice;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isRolled
                                ? theme.colorScheme.primaryContainer
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: isRolled
                                ? Border.all(
                                    color: theme.colorScheme.primary,
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${entry.key}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: isRolled
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              Text(
                                '+${entry.value}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              HeroMainStatsViewText.diceAcceptPrompt,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: alternatives.map((value) {
                final isRolled = value == rolledValue;
                return ActionChip(
                  label: Text(
                    '+$value',
                    style: TextStyle(
                      fontWeight:
                          isRolled ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  backgroundColor:
                      isRolled ? theme.colorScheme.primaryContainer : null,
                  side: isRolled
                      ? BorderSide(color: theme.colorScheme.primary, width: 2)
                      : null,
                  onPressed: () => Navigator.of(dialogContext).pop(value),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text(HeroMainStatsViewText.diceCancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(rolledValue),
            child: Text(
              '${HeroMainStatsViewText.diceAcceptPrefix}$rolledValue',
            ),
          ),
        ],
      );
    },
  );
}
