import 'dart:async';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/providers.dart';
import '../../../../core/models/hero_mod_keys.dart';
import '../../../../core/models/stat_modification_model.dart';
import '../../../../core/repositories/feature_repository.dart';
import '../../../../core/repositories/hero_repository.dart';
import '../../../../core/services/class_data_service.dart';
import '../../../../core/services/resource_generation_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../hero_downtime_tracking_page.dart';
import '../state/hero_main_stats_providers.dart';
import 'conditions_tracker_widget.dart';
import 'damage_resistance_tracker_widget.dart';

class HeroMainStatsView extends ConsumerStatefulWidget {
  const HeroMainStatsView({
    super.key,
    required this.heroId,
    required this.heroName,
  });

  final String heroId;
  final String heroName;

  @override
  ConsumerState<HeroMainStatsView> createState() => _HeroMainStatsViewState();
}

enum _NumericField {
  victories,
  exp,
  level,
  staminaCurrent,
  staminaTemp,
  recoveriesCurrent,
  heroicResourceCurrent,
  surgesCurrent,
}

extension _NumericFieldLabel on _NumericField {
  String get label {
    switch (this) {
      case _NumericField.victories:
        return 'Victories';
      case _NumericField.exp:
        return 'Experience';
      case _NumericField.level:
        return 'Level';
      case _NumericField.staminaCurrent:
        return 'Stamina';
      case _NumericField.staminaTemp:
        return 'Temporary stamina';
      case _NumericField.recoveriesCurrent:
        return 'Recoveries';
      case _NumericField.heroicResourceCurrent:
        return 'Heroic resource';
      case _NumericField.surgesCurrent:
        return 'Surges';
    }
  }
}

class _HeroMainStatsViewState extends ConsumerState<HeroMainStatsView> {
  final Map<_NumericField, TextEditingController> _numberControllers = {
    for (final field in _NumericField.values) field: TextEditingController(),
  };
  ProviderSubscription<AsyncValue<HeroMainStats>>? _statsSub;

  final Map<_NumericField, FocusNode> _numberFocusNodes = {
    for (final field in _NumericField.values) field: FocusNode(),
  };

  final Map<_NumericField, Timer?> _numberDebounce = {};

  static const List<String> _modKeys = [
    HeroModKeys.wealth,
    HeroModKeys.renown,
    HeroModKeys.might,
    HeroModKeys.agility,
    HeroModKeys.reason,
    HeroModKeys.intuition,
    HeroModKeys.presence,
    HeroModKeys.size,
    HeroModKeys.speed,
    HeroModKeys.disengage,
    HeroModKeys.stability,
    HeroModKeys.staminaMax,
    HeroModKeys.recoveriesMax,
    HeroModKeys.surges,
  ];

  final Map<String, TextEditingController> _modControllers = {
    for (final key in _modKeys) key: TextEditingController(),
  };

  final Map<String, FocusNode> _modFocusNodes = {
    for (final key in _modKeys) key: FocusNode(),
  };

  final Map<String, Timer?> _modDebounce = {};

  HeroMainStats? _latestStats;
  HeroStatModifications _ancestryMods = const HeroStatModifications.empty();
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _statsSub = ref.listenManual<AsyncValue<HeroMainStats>>(
      heroMainStatsProvider(widget.heroId),
      _handleStatsChanged,
      fireImmediately: true,
    );
    for (final entry in _numberControllers.entries) {
      entry.value.addListener(() => _handleNumberChanged(entry.key));
    }
    for (final entry in _modControllers.entries) {
      entry.value.addListener(() => _handleModChanged(entry.key));
    }
  }

  @override
  void didUpdateWidget(covariant HeroMainStatsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.heroId != widget.heroId) {
      _statsSub?.close();
      _statsSub = ref.listenManual<AsyncValue<HeroMainStats>>(
        heroMainStatsProvider(widget.heroId),
        _handleStatsChanged,
        fireImmediately: true,
      );
    }
  }

  @override
  void dispose() {
    _statsSub?.close();
    for (final timer in _numberDebounce.values) {
      timer?.cancel();
    }
    for (final timer in _modDebounce.values) {
      timer?.cancel();
    }

    for (final controller in _numberControllers.values) {
      controller.dispose();
    }
    for (final node in _numberFocusNodes.values) {
      node.dispose();
    }
    for (final controller in _modControllers.values) {
      controller.dispose();
    }
    for (final node in _modFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _applyStats(HeroMainStats stats) {
    if (!mounted) return;
    _latestStats = stats;
    _isApplying = true;

    void setNumber(_NumericField field, int value) {
      final controller = _numberControllers[field]!;
      final focusNode = _numberFocusNodes[field]!;
      final text = value.toString();
      if (!focusNode.hasFocus && controller.text != text) {
        controller.text = text;
      }
    }

    void setMod(String key, int value) {
      final controller = _modControllers[key]!;
      final focusNode = _modFocusNodes[key]!;
      final text = value.toString();
      if (!focusNode.hasFocus && controller.text != text) {
        controller.text = text;
      }
    }

    setNumber(_NumericField.victories, stats.victories);
    setNumber(_NumericField.exp, stats.exp);
    setNumber(_NumericField.level, stats.level);
    setNumber(_NumericField.staminaCurrent, stats.staminaCurrent);
    setNumber(_NumericField.staminaTemp, stats.staminaTemp);
    setNumber(_NumericField.recoveriesCurrent, stats.recoveriesCurrent);
    setNumber(_NumericField.heroicResourceCurrent, stats.heroicResourceCurrent);
    setNumber(_NumericField.surgesCurrent, stats.surgesCurrent);

    for (final key in _modKeys) {
      setMod(key, stats.modValue(key));
    }

    _isApplying = false;
  }

  void _handleStatsChanged(
    AsyncValue<HeroMainStats>? previous,
    AsyncValue<HeroMainStats> next,
  ) {
    next.whenData(_applyStats);
  }

  void _handleNumberChanged(_NumericField field) {
    if (_isApplying) return;
    _numberDebounce[field]?.cancel();
    _numberDebounce[field] = Timer(
      const Duration(milliseconds: 300),
      () => _persistNumberField(field, _numberControllers[field]!.text),
    );
  }

  Future<void> _persistNumberField(
    _NumericField field,
    String rawValue,
  ) async {
    final repo = ref.read(heroRepositoryProvider);
    final stats = _latestStats;
    int value = int.tryParse(rawValue) ?? 0;

    switch (field) {
      case _NumericField.victories:
      case _NumericField.exp:
        value = value.clamp(0, 999);
        break;
      case _NumericField.level:
        value = value.clamp(1, 99);
        break;
      case _NumericField.staminaCurrent:
        value = value.clamp(-999, 999);
        break;
      case _NumericField.staminaTemp:
        value = value.clamp(0, 999);
        break;
      case _NumericField.recoveriesCurrent:
        final max = stats?.recoveriesMaxEffective ?? 999;
        value = value.clamp(0, max);
        break;
      case _NumericField.heroicResourceCurrent:
      case _NumericField.surgesCurrent:
        value = value.clamp(0, 999);
        break;
    }

    if (stats != null && _numberValueFromStats(stats, field) == value) {
      return;
    }

    try {
      switch (field) {
        case _NumericField.victories:
          await repo.updateMainStats(widget.heroId, victories: value);
          break;
        case _NumericField.exp:
          await repo.updateMainStats(widget.heroId, exp: value);
          break;
        case _NumericField.level:
          await repo.updateMainStats(widget.heroId, level: value);
          break;
        case _NumericField.staminaCurrent:
          await repo.updateVitals(widget.heroId, staminaCurrent: value);
          break;
        case _NumericField.staminaTemp:
          await repo.updateVitals(widget.heroId, staminaTemp: value);
          break;
        case _NumericField.recoveriesCurrent:
          await repo.updateVitals(widget.heroId, recoveriesCurrent: value);
          break;
        case _NumericField.heroicResourceCurrent:
          await repo.updateVitals(widget.heroId, heroicResourceCurrent: value);
          break;
        case _NumericField.surgesCurrent:
          await repo.updateVitals(widget.heroId, surgesCurrent: value);
          break;
      }
    } catch (err) {
      if (!mounted) return;
      _showSnack('Failed to update ${field.label.toLowerCase()}: $err');
    }
  }

  void _handleModChanged(String key) {
    if (_isApplying) return;
    _modDebounce[key]?.cancel();
    _modDebounce[key] = Timer(
      const Duration(milliseconds: 300),
      () => _persistModification(key, _modControllers[key]!.text),
    );
  }

  Future<void> _persistModification(String key, String rawValue) async {
    final repo = ref.read(heroRepositoryProvider);
    int value = int.tryParse(rawValue) ?? 0;
    value = value.clamp(-99, 99);
    if (_latestStats?.modValue(key) == value) {
      return;
    }
    try {
      await repo.setModification(widget.heroId, key: key, value: value);
    } catch (err) {
      if (!mounted) return;
      _showSnack('Failed to update modifier: $err');
    }
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(heroMainStatsProvider(widget.heroId));
    final ancestryModsAsync = ref.watch(heroAncestryStatModsProvider(widget.heroId));
    
    // Update ancestry mods state
    _ancestryMods = ancestryModsAsync.valueOrNull ?? const HeroStatModifications.empty();

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _buildErrorState(context, error),
      data: (stats) {
        if (_latestStats == null) {
          _applyStats(stats);
        }
        
        final resourceDetailsAsync = ref.watch(
          _heroicResourceDetailsProvider(
            _HeroicResourceRequest(
              classId: stats.classId,
              fallbackName: stats.heroicResourceName,
            ),
          ),
        );
        return _buildContent(context, stats, resourceDetailsAsync);
      },
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              'Unable to load hero statistics.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () =>
                  ref.invalidate(heroMainStatsProvider(widget.heroId)),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    HeroMainStats stats,
    AsyncValue<HeroicResourceDetails?> resourceDetails,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProgressionRow(context),
          const SizedBox(height: 8),
          _buildRespiteDowntimeRow(context, stats),
          const SizedBox(height: 12),
          _buildCombinedStatsCard(context, stats),
          const SizedBox(height: 12),
          _buildVitalsCard(context, stats, resourceDetails),
          const SizedBox(height: 12),
          ConditionsTrackerWidget(heroId: widget.heroId),
          const SizedBox(height: 12),
          DamageResistanceTrackerWidget(heroId: widget.heroId),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Compact horizontal row for Level, XP, Victories, Wealth, Renown
  Widget _buildProgressionRow(BuildContext context) {
    final theme = Theme.of(context);
    final stats = _latestStats;
    final level = stats?.level ?? 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            // Level - prominent display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'LVL',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    level.toString(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // XP and Victories
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildProgressionItem(
                    context,
                    icon: Icons.star_outline,
                    label: 'XP',
                    field: _NumericField.exp,
                  ),
                  _buildProgressionItem(
                    context,
                    icon: Icons.emoji_events_outlined,
                    label: 'Victories',
                    field: _NumericField.victories,
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: theme.colorScheme.outlineVariant,
            ),
            // Wealth and Renown
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildEconomyItem(
                    context,
                    icon: Icons.paid_outlined,
                    label: 'Wealth',
                    baseValue: stats?.wealthBase ?? 0,
                    totalValue: stats?.wealthTotal ?? 0,
                    modKey: HeroModKeys.wealth,
                    insights: _wealthInsights(stats?.wealthTotal ?? 0),
                  ),
                  _buildEconomyItem(
                    context,
                    icon: Icons.military_tech_outlined,
                    label: 'Renown',
                    baseValue: stats?.renownBase ?? 0,
                    totalValue: stats?.renownTotal ?? 0,
                    modKey: HeroModKeys.renown,
                    insights: _renownInsights(stats?.renownTotal ?? 0),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Row with Respite and Downtime buttons
  Widget _buildRespiteDowntimeRow(BuildContext context, HeroMainStats stats) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showRespiteConfirmDialog(context, stats),
            icon: const Icon(Icons.bedtime_outlined, size: 18),
            label: const Text('Take Respite'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _navigateToDowntime(context),
            icon: const Icon(Icons.assignment_outlined, size: 18),
            label: const Text('Downtime'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.secondary,
              side: BorderSide(color: theme.colorScheme.secondary.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToDowntime(BuildContext context) {
    // Navigate to the downtime page
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HeroDowntimeTrackingPage(
          heroId: widget.heroId,
          heroName: widget.heroName,
          isEmbedded: false,
        ),
      ),
    );
  }

  Future<void> _showRespiteConfirmDialog(BuildContext context, HeroMainStats stats) async {
    final victories = stats.victories;
    final currentXp = stats.exp;
    final newXp = currentXp + victories;
    final recoveriesMax = stats.recoveriesMaxEffective;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.bedtime_outlined),
              SizedBox(width: 8),
              Text('Take Respite'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Taking a respite will:'),
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
                        Icon(Icons.emoji_events, size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Convert $victories ${victories == 1 ? 'victory' : 'victories'} to XP',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.star, size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'XP: $currentXp → $newXp',
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
                        Icon(Icons.favorite, size: 16, color: theme.colorScheme.tertiary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Regain all recoveries (→ $recoveriesMax)',
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
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Take Respite'),
            ),
          ],
        );
      },
    );
    
    if (confirmed == true && mounted) {
      await _handleTakeRespite(stats);
    }
  }

  Future<void> _handleTakeRespite(HeroMainStats stats) async {
    // Convert victories to XP
    final victories = stats.victories;
    final currentXp = stats.exp;
    final newXp = currentXp + victories;
    
    // Regain all recoveries
    final recoveriesMax = stats.recoveriesMaxEffective;
    
    // Apply changes
    await _persistNumberField(_NumericField.exp, newXp.toString());
    await _persistNumberField(_NumericField.victories, '0');
    await _persistNumberField(_NumericField.recoveriesCurrent, recoveriesMax.toString());
    
    if (mounted) {
      _showSnack('Respite complete: +$victories XP, recoveries restored');
    }
  }

  Widget _buildProgressionItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required _NumericField field,
  }) {
    final theme = Theme.of(context);
    final value = _latestStats != null
        ? _numberValueFromStats(_latestStats!, field)
        : 0;

    return InkWell(
      onTap: () {
        if (field == _NumericField.exp) {
          _showXpEditDialog(context, value);
        } else {
          _showNumberEditDialog(context, label, field);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(height: 2),
            Text(
              value.toString(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEconomyItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int baseValue,
    required int totalValue,
    required String modKey,
    required List<String> insights,
  }) {
    final theme = Theme.of(context);
    final modValue = totalValue - baseValue;

    return InkWell(
      onTap: () => _showModEditDialog(
        context,
        title: label,
        modKey: modKey,
        baseValue: baseValue,
        currentModValue: modValue,
        insights: insights,
      ),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.secondary),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  totalValue.toString(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (modValue != 0)
                  Text(
                    modValue > 0 ? '+$modValue' : modValue.toString(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: modValue > 0
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Combined attributes and combat stats card with grid layout
  Widget _buildCombinedStatsCard(BuildContext context, HeroMainStats stats) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Characteristics section header (M/A/R/I/P)
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  'Characteristics',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 5-column characteristic grid
            Row(
              children: [
                _buildGridStatItem(context, 'M', stats.mightBase, stats.mightTotal, HeroModKeys.might, 'Might'),
                _buildGridStatItem(context, 'A', stats.agilityBase, stats.agilityTotal, HeroModKeys.agility, 'Agility'),
                _buildGridStatItem(context, 'R', stats.reasonBase, stats.reasonTotal, HeroModKeys.reason, 'Reason'),
                _buildGridStatItem(context, 'I', stats.intuitionBase, stats.intuitionTotal, HeroModKeys.intuition, 'Intuition'),
                _buildGridStatItem(context, 'P', stats.presenceBase, stats.presenceTotal, HeroModKeys.presence, 'Presence'),
              ],
            ),
            // Potency section
            _buildPotencyRow(context, stats),
            const Divider(height: 20),
            // Attributes section header (Size, Speed, Disengage, Stability)
            Row(
              children: [
                Icon(Icons.shield_outlined, size: 16, color: theme.colorScheme.secondary),
                const SizedBox(width: 6),
                Text(
                  'Attributes',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 4-column attributes grid
            Row(
              children: [
                _buildGridSizeItem(context, stats.sizeBase, stats.sizeTotal, HeroModKeys.size),
                _buildGridStatItem(context, 'SPD', stats.speedBase, stats.speedTotal, HeroModKeys.speed, 'Speed'),
                _buildGridStatItem(context, 'DIS', stats.disengageBase, stats.disengageTotal, HeroModKeys.disengage, 'Disengage'),
                _buildGridStatItem(context, 'STB', stats.stabilityBase, stats.stabilityTotal, HeroModKeys.stability, 'Stability'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build potency row based on class data
  Widget _buildPotencyRow(BuildContext context, HeroMainStats stats) {
    final theme = Theme.of(context);
    final classId = stats.classId;
    
    if (classId == null || classId.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calculate potency based on highest characteristic
    final totals = {
      'might': stats.mightTotal,
      'agility': stats.agilityTotal,
      'reason': stats.reasonTotal,
      'intuition': stats.intuitionTotal,
      'presence': stats.presenceTotal,
    };

    return FutureBuilder<Map<String, int>?>(
      future: _computePotencyForClass(classId, totals),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final potencyValues = snapshot.data!;
        const order = ['strong', 'average', 'weak'];

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: order.map((strength) {
              final value = potencyValues[strength] ?? 0;
              final label = strength[0].toUpperCase();
              final color = AppColors.getPotencyColor(strength);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withOpacity(0.6)),
                    color: color.withOpacity(0.15),
                  ),
                  child: Text(
                    '$label ${_formatSigned(value)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<Map<String, int>?> _computePotencyForClass(
    String classId,
    Map<String, int> totals,
  ) async {
    try {
      final classDataService = ClassDataService();
      await classDataService.initialize();
      final classData = classDataService.getClassById(classId);
      if (classData == null) return null;

      final progression = classData.startingCharacteristics.potencyProgression;
      final baseKey = progression.characteristic.toLowerCase();
      final baseScore = totals[baseKey] ?? 0;
      final result = <String, int>{};
      progression.modifiers.forEach((strength, modifier) {
        result[strength.toLowerCase()] = baseScore + modifier;
      });
      return result;
    } catch (_) {
      return null;
    }
  }

  Widget _buildGridStatItem(
    BuildContext context,
    String shortLabel,
    int baseValue,
    int totalValue,
    String modKey,
    String fullLabel,
  ) {
    final theme = Theme.of(context);
    final modValue = totalValue - baseValue;
    final isPositive = totalValue >= 0;

    return Expanded(
      child: InkWell(
        onTap: () => _showStatEditDialog(
          context,
          label: fullLabel,
          modKey: modKey,
          baseValue: baseValue,
          currentModValue: modValue,
        ),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                shortLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isPositive
                      ? theme.colorScheme.surfaceContainerHighest
                      : theme.colorScheme.errorContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatSigned(totalValue),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isPositive
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.error,
                      ),
                    ),
                    if (modValue != 0)
                      Text(
                        modValue > 0 ? ' +$modValue' : ' $modValue',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          color: modValue > 0
                              ? theme.colorScheme.primary
                              : theme.colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridSizeItem(
    BuildContext context,
    String sizeBase,
    String sizeTotal,
    String modKey,
  ) {
    final theme = Theme.of(context);
    // Use progression index difference to calculate mod value
    final baseIndex = HeroMainStats.sizeToIndex(sizeBase);
    final totalIndex = HeroMainStats.sizeToIndex(sizeTotal);
    final modValue = totalIndex - baseIndex;

    return Expanded(
      child: InkWell(
        onTap: () => _showSizeEditDialog(
          context,
          sizeBase: sizeBase,
          currentModValue: modValue,
        ),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SIZE',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      sizeTotal,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (modValue != 0)
                      Text(
                        modValue > 0 ? ' +$modValue' : ' $modValue',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          color: modValue > 0
                              ? theme.colorScheme.primary
                              : theme.colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Combined vitals card: Stamina, Recoveries, Heroic Resource, Surges
  Widget _buildVitalsCard(
    BuildContext context,
    HeroMainStats stats,
    AsyncValue<HeroicResourceDetails?> resourceDetails,
  ) {
    final theme = Theme.of(context);
    final staminaState = _calculateStaminaState(stats);
    final healAmount = _recoveryHealAmount(stats);
    final staminaMaxMod = _latestStats?.modValue(HeroModKeys.staminaMax) ?? 0;
    final recoveriesMaxMod = _latestStats?.modValue(HeroModKeys.recoveriesMax) ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stamina Section with visual bar
            Row(
              children: [
                Icon(Icons.favorite_outline, size: 16, color: staminaState.color),
                const SizedBox(width: 6),
                Text(
                  'Stamina',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: staminaState.color,
                  ),
                ),
                const Spacer(),
                Text(
                  staminaState.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: staminaState.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Stamina bar and values
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Custom stamina bar showing -halfMax to max with temp HP
                      _buildStaminaBar(context, stats, staminaState),
                      const SizedBox(height: 6),
                      // Current / Temp / Max row
                      Row(
                        children: [
                          _buildVitalItem(
                            context,
                            label: 'Current',
                            value: stats.staminaCurrent,
                            field: _NumericField.staminaCurrent,
                            allowNegative: true,
                          ),
                          const SizedBox(width: 12),
                          _buildVitalItem(
                            context,
                            label: 'Temp',
                            value: stats.staminaTemp,
                            field: _NumericField.staminaTemp,
                          ),
                          const SizedBox(width: 12),
                          _buildMaxVitalItem(
                            context,
                            label: 'Max',
                            value: stats.staminaMaxEffective,
                            modKey: HeroModKeys.staminaMax,
                            modValue: staminaMaxMod,
                            baseValue: stats.staminaMaxBase,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Action buttons
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCompactActionButton(
                      context,
                      icon: Icons.flash_on,
                      label: 'Dmg',
                      onPressed: () => _handleDealDamage(stats),
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 4),
                    _buildCompactActionButton(
                      context,
                      icon: Icons.healing,
                      label: 'Heal',
                      onPressed: () => _handleApplyHealing(stats),
                      color: Colors.green,
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 20),
            // Recoveries row
            Row(
              children: [
                Icon(Icons.local_hospital_outlined, size: 16, color: theme.colorScheme.tertiary),
                const SizedBox(width: 6),
                Text(
                  'Recoveries',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildVitalItem(
                  context,
                  label: 'Current',
                  value: stats.recoveriesCurrent,
                  field: _NumericField.recoveriesCurrent,
                ),
                const SizedBox(width: 12),
                _buildMaxVitalItem(
                  context,
                  label: 'Max',
                  value: stats.recoveriesMaxEffective,
                  modKey: HeroModKeys.recoveriesMax,
                  modValue: recoveriesMaxMod,
                  baseValue: stats.recoveriesMaxBase,
                ),
                const Spacer(),
                FilledButton.tonal(
                  onPressed: () => _handleUseRecovery(stats),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_circle_outline, size: 16),
                      const SizedBox(width: 4),
                      Text('Use (+$healAmount)', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            // Heroic Resource and Surges row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildHeroicResourceSection(context, stats, resourceDetails),
                ),
                Container(
                  width: 1,
                  height: 80,
                  color: theme.colorScheme.outlineVariant,
                ),
                Expanded(
                  child: _buildSurgesSection(context, stats),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // End of Combat button
            Center(
              child: OutlinedButton.icon(
                onPressed: () => _handleEndOfCombat(stats),
                icon: const Icon(Icons.flag_outlined, size: 16),
                label: const Text('End of Combat'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(color: theme.colorScheme.error.withOpacity(0.5)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Custom stamina bar with two independent overlapping tracks:
  /// - Stamina bar: ranges from -halfMax to maxStamina
  /// - Temp HP bar: ranges from -halfMax to maxStamina (independent track, shown semi-transparent)
  /// Both bars are visible simultaneously with the temp HP bar slightly offset/transparent
  Widget _buildStaminaBar(BuildContext context, HeroMainStats stats, _StaminaState staminaState) {
    final theme = Theme.of(context);
    final maxStamina = stats.staminaMaxEffective;
    final currentStamina = stats.staminaCurrent;
    final tempHp = stats.staminaTemp;
    
    if (maxStamina <= 0) {
      return const SizedBox(height: 16);
    }
    
    // Range: -halfMax to max (total range = 1.5 * max)
    final halfMax = maxStamina ~/ 2;
    final totalRange = maxStamina + halfMax;
    
    // The "zero point" (stamina = 0) is at halfMax / totalRange
    final zeroPointRatio = halfMax / totalRange;
    
    // Stamina position: from -halfMax to maxStamina
    // When current = -halfMax, position = 0
    // When current = 0, position = zeroPointRatio  
    // When current = max, position = 1
    final clampedCurrent = currentStamina.clamp(-halfMax, maxStamina);
    final staminaPosition = (clampedCurrent + halfMax) / totalRange;
    
    // Temp HP position: independent track from -halfMax to maxStamina (same as stamina)
    // Temp HP of 0 = starts at left edge (position 0)
    // Temp HP of maxStamina + halfMax = fills to right edge (position 1.0)
    final clampedTemp = tempHp.clamp(0, maxStamina + halfMax);
    final tempPosition = clampedTemp / totalRange;
    
    return SizedBox(
      height: 16,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final zeroX = width * zeroPointRatio;
          final staminaX = width * staminaPosition;
          final tempX = width * tempPosition;
          
          return Stack(
            children: [
              // Background bar
              Container(
                height: 16,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              // Negative zone background (red tint from left to zero point)
              Positioned(
                left: 0,
                width: zeroX,
                child: Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withOpacity(0.1),
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                  ),
                ),
              ),
              // Temp HP bar (bottom layer, cyan, from left edge)
              // This is the independent temp HP track starting from -halfMax
              if (tempHp > 0)
                Positioned(
                  left: 0,
                  width: tempX.clamp(0, width),
                  top: 8, // Offset to bottom half
                  height: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.cyan.withOpacity(0.8),
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(4),
                        right: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
              // Stamina bar (top layer, from left edge)
              if (staminaX > 0)
                Positioned(
                  left: 0,
                  width: staminaX,
                  top: 0,
                  height: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: currentStamina >= 0 
                          ? staminaState.color 
                          : theme.colorScheme.error.withOpacity(0.8),
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(4),
                        right: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
              // Zero point marker (vertical line)
              Positioned(
                left: zeroX - 1,
                child: Container(
                  width: 2,
                  height: 16,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              // Labels overlay
              Positioned.fill(
                child: Row(
                  children: [
                    // Negative zone label
                    SizedBox(
                      width: zeroX,
                      child: Center(
                        child: Text(
                          '-${halfMax}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ),
                    // Positive zone - show stamina and temp if both present
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '0',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                            Text(
                              '$maxStamina',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVitalItem(
    BuildContext context, {
    required String label,
    required int value,
    required _NumericField field,
    bool allowNegative = false,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () async {
        final controller = TextEditingController(text: value.toString());
        try {
          final result = await showDialog<String>(
            context: context,
            builder: (dialogContext) {
              return AlertDialog(
                title: Text('Edit $label'),
                content: TextField(
                  controller: controller,
                  keyboardType: TextInputType.numberWithOptions(signed: allowNegative),
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Value',
                    border: OutlineInputBorder(),
                  ),
                  inputFormatters: _formatters(allowNegative, 4),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(controller.text),
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          );
          if (result != null && result.isNotEmpty && mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!mounted) return;
              await _persistNumberField(field, result);
            });
          }
        } finally {
          await Future.delayed(const Duration(milliseconds: 50));
          controller.dispose();
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: theme.textTheme.labelSmall),
            Text(
              value.toString(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaxVitalItem(
    BuildContext context, {
    required String label,
    required int value,
    required String modKey,
    required int modValue,
    required int baseValue,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () async {
        await _showStatEditDialog(
          context,
          label: '$label Modifier',
          modKey: modKey,
          baseValue: baseValue,
          currentModValue: modValue,
        );
      },
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: theme.textTheme.labelSmall),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value.toString(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (modValue != 0)
                  Text(
                    modValue > 0 ? '+$modValue' : modValue.toString(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: modValue > 0
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return SizedBox(
      width: 56,
      height: 32,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: BorderSide(color: color.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroicResourceSection(
    BuildContext context,
    HeroMainStats stats,
    AsyncValue<HeroicResourceDetails?> resourceDetails,
  ) {
    final theme = Theme.of(context);
    final value = stats.heroicResourceCurrent;

    return resourceDetails.when(
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, __) => _buildResourceDisplay(context, stats, stats.heroicResourceName ?? 'Resource', value),
      data: (details) {
        final resourceName = details?.name ?? stats.heroicResourceName ?? 'Resource';
        final hasDetails = (details?.description ?? '').isNotEmpty ||
            (details?.inCombatDescription ?? '').isNotEmpty ||
            (details?.outCombatDescription ?? '').isNotEmpty;

        return Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.bolt_outlined, size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      resourceName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasDetails)
                    InkWell(
                      onTap: () => _showResourceDetailsDialog(context, resourceName, details),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(Icons.info_outline, size: 14, color: theme.colorScheme.primary),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: () => _showNumberEditDialog(context, resourceName, _NumericField.heroicResourceCurrent),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    value.toString(),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              _buildResourceGenerationButtons(context, stats),
            ],
          ),
        );
      },
    );
  }

  /// Builds the resource generation buttons based on class
  Widget _buildResourceGenerationButtons(BuildContext context, HeroMainStats stats) {
    return FutureBuilder<List<GenerationPreset>>(
      future: _getResourceGenerationOptions(stats.classId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final options = snapshot.data!;
        final theme = Theme.of(context);

        return Wrap(
          spacing: 4,
          runSpacing: 4,
          children: options.map((option) {
            final label = ResourceGenerationService.instance.getDisplayLabel(
              option.key,
              stats.victories,
            );

            return InkWell(
              onTap: () => _handleResourceGeneration(context, stats, option.key),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.5),
                  ),
                  color: theme.colorScheme.primary.withOpacity(0.1),
                ),
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<List<GenerationPreset>> _getResourceGenerationOptions(String? classId) async {
    await ResourceGenerationService.instance.initialize();
    return ResourceGenerationService.instance.getGenerationOptionsForClass(classId);
  }

  Future<void> _handleResourceGeneration(
    BuildContext context,
    HeroMainStats stats,
    String optionKey,
  ) async {
    final result = ResourceGenerationService.instance.calculateGeneration(
      optionKey: optionKey,
      victories: stats.victories,
    );

    if (result.requiresConfirmation && result.alternativeValues != null) {
      // Show dice roll confirmation dialog
      final selectedValue = await _showDiceRollDialog(
        context,
        rolledValue: result.value,
        alternatives: result.alternativeValues!,
        diceType: '1d3',
      );

      if (selectedValue != null && mounted) {
        await _applyResourceGeneration(stats, selectedValue);
      }
    } else {
      // Apply directly
      await _applyResourceGeneration(stats, result.value);
    }
  }

  Future<int?> _showDiceRollDialog(
    BuildContext context, {
    required int rolledValue,
    required List<int> alternatives,
    required String diceType,
  }) async {
    final theme = Theme.of(context);

    return showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.casino, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('$diceType Roll'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'You rolled: $rolledValue',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Accept this roll or choose a different value:',
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
                        fontWeight: isRolled ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    backgroundColor: isRolled
                        ? theme.colorScheme.primaryContainer
                        : null,
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
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(rolledValue),
              child: Text('Accept +$rolledValue'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _applyResourceGeneration(HeroMainStats stats, int amount) async {
    if (!mounted || amount <= 0) return;

    final newValue = stats.heroicResourceCurrent + amount;

    try {
      await ref.read(heroRepositoryProvider).updateVitals(
            widget.heroId,
            heroicResourceCurrent: newValue,
          );
      _showSnack('+$amount resource');
    } catch (err) {
      if (!mounted) return;
      _showSnack('Failed to add resource: $err');
    }
  }

  Widget _buildResourceDisplay(BuildContext context, HeroMainStats stats, String name, int value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_outlined, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 4),
              Text(
                name,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => _showNumberEditDialog(context, name, _NumericField.heroicResourceCurrent),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                value.toString(),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          _buildResourceGenerationButtons(context, stats),
        ],
      ),
    );
  }

  Widget _buildSurgesSection(BuildContext context, HeroMainStats stats) {
    final theme = Theme.of(context);
    final value = stats.surgesCurrent;

    // Calculate surge damage based on highest attribute
    final highestAttribute = [
      stats.mightTotal,
      stats.agilityTotal,
      stats.reasonTotal,
      stats.intuitionTotal,
      stats.presenceTotal,
    ].reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.electric_bolt_outlined, size: 14, color: theme.colorScheme.tertiary),
              const SizedBox(width: 4),
              Text(
                'Surges',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => _showNumberEditDialog(context, 'Surges', _NumericField.surgesCurrent),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                value.toString(),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Add surges buttons (+1, +2)
          Row(
            children: [
              _buildAddSurgeButton(context, 1),
              const SizedBox(width: 4),
              _buildAddSurgeButton(context, 2),
            ],
          ),
          const SizedBox(height: 4),
          // Spend surges buttons
          Row(
            children: [
              Expanded(
                child: _buildSurgeButton(
                  context,
                  cost: 1,
                  label: '+$highestAttribute dmg',
                  enabled: value >= 1,
                  onPressed: () => _spendSurges(1),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildSurgeButton(
                  context,
                  cost: 2,
                  label: '+1 potency',
                  enabled: value >= 2,
                  onPressed: () => _spendSurges(2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddSurgeButton(BuildContext context, int amount) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: () => _addSurges(amount),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer.withOpacity(0.5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: theme.colorScheme.tertiary.withOpacity(0.3),
          ),
        ),
        child: Text(
          '+$amount',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.tertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSurgeButton(
    BuildContext context, {
    required int cost,
    required String label,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: enabled ? onPressed : null,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: enabled 
                ? theme.colorScheme.tertiary.withOpacity(0.5)
                : theme.colorScheme.outline.withOpacity(0.3),
          ),
          color: enabled
              ? theme.colorScheme.tertiary.withOpacity(0.1)
              : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$cost→',
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: enabled
                    ? theme.colorScheme.tertiary
                    : theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
            ),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 9,
                  color: enabled
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _spendSurges(int amount) async {
    final stats = _latestStats;
    if (stats == null) return;
    
    final current = stats.surgesCurrent;
    if (current < amount) return;
    
    final newValue = current - amount;
    await _persistNumberField(_NumericField.surgesCurrent, newValue.toString());
  }

  Future<void> _addSurges(int amount) async {
    final stats = _latestStats;
    if (stats == null) return;
    
    final current = stats.surgesCurrent;
    final newValue = current + amount;
    await _persistNumberField(_NumericField.surgesCurrent, newValue.toString());
  }

  Future<void> _handleEndOfCombat(HeroMainStats stats) async {
    // Reset heroic resource and surges to 0
    await _persistNumberField(_NumericField.heroicResourceCurrent, '0');
    await _persistNumberField(_NumericField.surgesCurrent, '0');
  }

  Widget _buildSummaryCard(BuildContext context) {
    final theme = Theme.of(context);
    final level = _latestStats?.level ?? 1;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildCompactNumberDisplay(
              context,
              label: 'Victories',
              field: _NumericField.victories,
            ),
            _buildCompactNumberDisplay(
              context,
              label: 'XP',
              field: _NumericField.exp,
            ),
            // Level - read-only display
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Level',
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    level.toString(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWealthRenownCard(BuildContext context, HeroMainStats stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: _buildCompactEconomyTile(
                context,
                title: 'Wealth',
                baseValue: stats.wealthBase,
                totalValue: stats.wealthTotal,
                modKey: HeroModKeys.wealth,
                insights: _wealthInsights(stats.wealthTotal),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCompactEconomyTile(
                context,
                title: 'Renown',
                baseValue: stats.renownBase,
                totalValue: stats.renownTotal,
                modKey: HeroModKeys.renown,
                insights: _renownInsights(stats.renownTotal),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEconomyTile(
    BuildContext context, {
    required String title,
    required int baseValue,
    required int totalValue,
    required String modKey,
    required List<String> insights,
  }) {
    final theme = Theme.of(context);
    final currentMod = _latestStats?.modValue(modKey) ?? 0;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            totalValue.toString(),
            style: theme.textTheme.displaySmall?.copyWith(fontSize: 32),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Chip(label: Text('Base $baseValue')),
              Chip(label: Text('Mod ${_formatSigned(currentMod)}')),
            ],
          ),
          const SizedBox(height: 12),
          _buildModificationInput(
            context,
            label: 'Adjust mod',
            modKey: modKey,
          ),
          if (insights.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final line in insights)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  line,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrimaryStatsCard(BuildContext context, HeroMainStats stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Core Attributes',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCompactStatTile(context, 'Might', stats.mightBase,
                    stats.mightTotal, HeroModKeys.might),
                _buildCompactStatTile(context, 'Agility', stats.agilityBase,
                    stats.agilityTotal, HeroModKeys.agility),
                _buildCompactStatTile(context, 'Reason', stats.reasonBase,
                    stats.reasonTotal, HeroModKeys.reason),
                _buildCompactStatTile(context, 'Intuition', stats.intuitionBase,
                    stats.intuitionTotal, HeroModKeys.intuition),
                _buildCompactStatTile(context, 'Presence', stats.presenceBase,
                    stats.presenceTotal, HeroModKeys.presence),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryStatsCard(BuildContext context, HeroMainStats stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Combat Readiness',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCompactSizeTile(context, stats.sizeBase,
                    stats.sizeTotal, HeroModKeys.size),
                _buildCompactStatTile(context, 'Speed', stats.speedBase,
                    stats.speedTotal, HeroModKeys.speed),
                _buildCompactStatTile(context, 'Disengage', stats.disengageBase,
                    stats.disengageTotal, HeroModKeys.disengage),
                _buildCompactStatTile(context, 'Stability', stats.stabilityBase,
                    stats.stabilityTotal, HeroModKeys.stability),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCollection(
    BuildContext context,
    String title,
    List<_StatTileData> data,
  ) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 20,
              runSpacing: 20,
              children: [
                for (final item in data) _buildStatTile(context, item),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(BuildContext context, _StatTileData data) {
    final theme = Theme.of(context);
    final currentMod = _latestStats?.modValue(data.modKey) ?? 0;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 180),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data.label, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            _formatSigned(data.totalValue),
            style: theme.textTheme.displaySmall?.copyWith(fontSize: 28),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Chip(label: Text('Base ${_formatSigned(data.baseValue)}')),
              Chip(label: Text('Mod ${_formatSigned(currentMod)}')),
            ],
          ),
          const SizedBox(height: 8),
          _buildModificationInput(
            context,
            label: 'Adjust mod',
            modKey: data.modKey,
          ),
        ],
      ),
    );
  }

  Widget _buildStaminaAndRecoveries(
    BuildContext context,
    HeroMainStats stats,
  ) {
    final children = [
      Expanded(child: _buildStaminaCard(context, stats)),
      const SizedBox(width: 16),
      Expanded(child: _buildRecoveriesCard(context, stats)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 760) {
          return Row(children: children);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStaminaCard(context, stats),
            const SizedBox(height: 16),
            _buildRecoveriesCard(context, stats),
          ],
        );
      },
    );
  }

  Widget _buildStaminaCard(BuildContext context, HeroMainStats stats) {
    final theme = Theme.of(context);
    final state = _calculateStaminaState(stats);
    final effectiveMax = stats.staminaMaxEffective;
    final staminaMaxMod = _latestStats?.modValue(HeroModKeys.staminaMax) ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Stamina', style: theme.textTheme.titleSmall),
                const Spacer(),
                Text(
                  state.label,
                  style: theme.textTheme.labelSmall?.copyWith(color: state.color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildCompactVitalDisplay(
                    context,
                    label: 'Current',
                    field: _NumericField.staminaCurrent,
                    allowNegative: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCompactVitalDisplay(
                    context,
                    label: 'Temp',
                    field: _NumericField.staminaTemp,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      if (!mounted) return;
                      await _showStatEditDialog(
                        context,
                        label: 'Stamina Max',
                        modKey: HeroModKeys.staminaMax,
                        baseValue: stats.staminaMaxBase,
                        currentModValue: staminaMaxMod,
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          Text('Max', style: theme.textTheme.labelSmall),
                          const SizedBox(height: 2),
                          Text(
                            effectiveMax.toString(),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          _buildModValueWithSources(
                            modValue: staminaMaxMod,
                            modKey: HeroModKeys.staminaMax,
                            ancestryMods: _ancestryMods,
                            theme: theme,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleDealDamage(stats),
                    icon: const Icon(Icons.flash_on, size: 16),
                    label: const Text('Damage', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleApplyHealing(stats),
                    icon: const Icon(Icons.healing, size: 16),
                    label: const Text('Heal', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecoveriesCard(BuildContext context, HeroMainStats stats) {
    final theme = Theme.of(context);
    final healAmount = _recoveryHealAmount(stats);
    final recoveriesMaxMod = _latestStats?.modValue(HeroModKeys.recoveriesMax) ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recoveries', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildCompactVitalDisplay(
                    context,
                    label: 'Current',
                    field: _NumericField.recoveriesCurrent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: () async {
                      if (!mounted) return;
                      await _showStatEditDialog(
                        context,
                        label: 'Recoveries Max',
                        modKey: HeroModKeys.recoveriesMax,
                        baseValue: stats.recoveriesMaxBase,
                        currentModValue: recoveriesMaxMod,
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          Text('Max', style: theme.textTheme.labelSmall),
                          const SizedBox(height: 2),
                          Text(
                            stats.recoveriesMaxEffective.toString(),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          _buildModValueWithSources(
                            modValue: recoveriesMaxMod,
                            modKey: HeroModKeys.recoveriesMax,
                            ancestryMods: _ancestryMods,
                            theme: theme,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: FilledButton.icon(
                    onPressed: () => _handleUseRecovery(stats),
                    icon: const Icon(Icons.local_hospital, size: 16),
                    label: Text('Use (+$healAmount)', style: const TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceAndSurges(
    BuildContext context,
    HeroMainStats stats,
    AsyncValue<HeroicResourceDetails?> resourceDetails,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildHeroicResourceCard(context, stats, resourceDetails),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSurgesCard(context, stats),
        ),
      ],
    );
  }

  Widget _buildHeroicResourceCard(
    BuildContext context,
    HeroMainStats stats,
    AsyncValue<HeroicResourceDetails?> resourceDetails,
  ) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: resourceDetails.when(
          loading: () => const SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stats.heroicResourceName ?? 'Heroic Resource',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              _buildCompactVitalDisplay(
                context,
                label: 'Current',
                field: _NumericField.heroicResourceCurrent,
              ),
            ],
          ),
          data: (details) {
            final resourceName = details?.name ?? stats.heroicResourceName ?? 'Heroic Resource';
            final hasDetails = (details?.description ?? '').isNotEmpty ||
                (details?.inCombatDescription ?? '').isNotEmpty ||
                (details?.outCombatDescription ?? '').isNotEmpty;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        resourceName,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasDetails)
                      IconButton(
                        icon: const Icon(Icons.info_outline, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _showResourceDetailsDialog(
                          context,
                          resourceName,
                          details,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildCompactVitalDisplay(
                  context,
                  label: 'Current',
                  field: _NumericField.heroicResourceCurrent,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showResourceDetailsDialog(
    BuildContext context,
    String name,
    HeroicResourceDetails? details,
  ) {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(name),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if ((details?.description ?? '').isNotEmpty) ...[
                  Text(
                    details!.description!,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                ],
                if ((details?.inCombatDescription ?? '').isNotEmpty) ...[
                  Text(
                    details?.inCombatName ?? 'In Combat',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    details!.inCombatDescription!,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                ],
                if ((details?.outCombatDescription ?? '').isNotEmpty) ...[
                  Text(
                    details?.outCombatName ?? 'Out of Combat',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    details!.outCombatDescription!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSurgesCard(BuildContext context, HeroMainStats stats) {
    final theme = Theme.of(context);
    
    // Calculate surge damage based on highest attribute
    final highestAttribute = [
      stats.mightTotal,
      stats.agilityTotal,
      stats.reasonTotal,
      stats.intuitionTotal,
      stats.presenceTotal,
    ].reduce((a, b) => a > b ? a : b);
    
    final surgeDamage = highestAttribute;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Surges', style: theme.textTheme.titleSmall),
                const Spacer(),
                Text(
                  'Total: ${stats.surgesTotal}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildCompactVitalDisplay(
              context,
              label: 'Current',
              field: _NumericField.surgesCurrent,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '1 Surge',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$surgeDamage Damage',
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '2 Surges',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Potency +1',
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _numberValueFromStats(HeroMainStats stats, _NumericField field) {
    switch (field) {
      case _NumericField.victories:
        return stats.victories;
      case _NumericField.exp:
        return stats.exp;
      case _NumericField.level:
        return stats.level;
      case _NumericField.staminaCurrent:
        return stats.staminaCurrent;
      case _NumericField.staminaTemp:
        return stats.staminaTemp;
      case _NumericField.recoveriesCurrent:
        return stats.recoveriesCurrent;
      case _NumericField.heroicResourceCurrent:
        return stats.heroicResourceCurrent;
      case _NumericField.surgesCurrent:
        return stats.surgesCurrent;
    }
  }

  Widget _buildModificationInput(
    BuildContext context, {
    required String label,
    required String modKey,
  }) {
    final theme = Theme.of(context);
    final controller = _modControllers[modKey]!;
    final focusNode = _modFocusNodes[modKey]!;

    return SizedBox(
      width: 88,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            focusNode: focusNode,
            textAlign: TextAlign.center,
            maxLength: 4,
            buildCounter: (_,
                    {int? currentLength, bool? isFocused, int? maxLength}) =>
                null,
            inputFormatters: _formatters(true, 4),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactNumberDisplay(
    BuildContext context, {
    required String label,
    required _NumericField field,
  }) {
    final theme = Theme.of(context);
    final value = _latestStats != null
        ? _numberValueFromStats(_latestStats!, field)
        : 0;

    return InkWell(
      onTap: () async {
        if (!mounted) return;
        await _showNumberEditDialog(context, label, field);
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(height: 2),
            Text(
              value.toString(),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactEconomyTile(
    BuildContext context, {
    required String title,
    required int baseValue,
    required int totalValue,
    required String modKey,
    required List<String> insights,
  }) {
    final theme = Theme.of(context);
    final modValue = totalValue - baseValue;

    return InkWell(
      onTap: () async {
        if (!mounted) return;
        await _showModEditDialog(
          context,
          title: title,
          modKey: modKey,
          baseValue: baseValue,
          currentModValue: modValue,
          insights: insights,
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  totalValue.toString(),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (modValue != 0) ...[
                  const SizedBox(width: 4),
                  _buildModValueWithSources(
                    modValue: modValue,
                    modKey: modKey,
                    ancestryMods: _ancestryMods,
                    theme: theme,
                  ),
                ],
              ],
            ),
            if (insights.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                insights.first,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showNumberEditDialog(
    BuildContext context,
    String label,
    _NumericField field,
  ) async {
    if (!mounted) return;
    
    final controller = TextEditingController(
      text: _numberValueFromStats(_latestStats!, field).toString(),
    );

    try {
      final result = await showDialog<int>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text('Edit $label'),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
              ),
              inputFormatters: field == _NumericField.staminaCurrent
                  ? _formatters(true, 4)
                  : _formatters(false, 3),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final value = int.tryParse(controller.text);
                  if (value != null) {
                    Navigator.of(dialogContext).pop(value);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );

      // Ensure dialog is fully dismissed before persisting
      if (result != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          await _persistNumberField(field, result.toString());
        });
      }
    } finally {
      // Brief delay to ensure dialog animation completes
      await Future.delayed(const Duration(milliseconds: 50));
      controller.dispose();
    }
  }

  Future<void> _showXpEditDialog(BuildContext context, int currentXp) async {
    if (!mounted) return;
    
    final controller = TextEditingController(text: currentXp.toString());
    final currentLevel = _latestStats?.level ?? 1;
    final insights = _xpInsights(currentXp, currentLevel);

    try {
      final result = await showDialog<int>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Edit XP'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current Level: $currentLevel'),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Experience Points',
                    border: OutlineInputBorder(),
                  ),
                  inputFormatters: _formatters(false, 3),
                ),
                if (insights.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(dialogContext).colorScheme.surfaceContainerHighest,
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
                              'Heroic Advancement',
                              style: Theme.of(dialogContext).textTheme.labelMedium?.copyWith(
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
                            style: Theme.of(dialogContext).textTheme.bodySmall,
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
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final value = int.tryParse(controller.text);
                  if (value != null) {
                    Navigator.of(dialogContext).pop(value);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );

      // Ensure dialog is fully dismissed before persisting
      if (result != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          await _persistNumberField(_NumericField.exp, result.toString());
        });
      }
    } finally {
      await Future.delayed(const Duration(milliseconds: 50));
      controller.dispose();
    }
  }

  Future<void> _showModEditDialog(
    BuildContext context, {
    required String title,
    required String modKey,
    required int baseValue,
    required int currentModValue,
    required List<String> insights,
  }) async {
    if (!mounted) return;
    
    final controller = TextEditingController(text: currentModValue.toString());
    final sourcesDesc = _getModSourceDescription(modKey, _ancestryMods);

    try {
      final result = await showDialog<int>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text('Edit $title'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Base: $baseValue'),
                if (sourcesDesc.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(dialogContext).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 16,
                          color: Theme.of(dialogContext).colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            sourcesDesc,
                            style: TextStyle(
                              color: Theme.of(dialogContext).colorScheme.onPrimaryContainer,
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
                  keyboardType: const TextInputType.numberWithOptions(signed: true),
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Modification',
                    border: OutlineInputBorder(),
                    helperText: 'Enter modifier (-99 to +99)',
                  ),
                  inputFormatters: _formatters(true, 4),
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
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final value = int.tryParse(controller.text);
                  if (value != null) {
                    Navigator.of(dialogContext).pop(value);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );

      // Ensure dialog is fully dismissed before persisting
      if (result != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          await _persistModification(modKey, result.toString());
        });
      }
    } finally {
      await Future.delayed(const Duration(milliseconds: 50));
      controller.dispose();
    }
  }

  Widget _buildCompactStatTile(
    BuildContext context,
    String label,
    int baseValue,
    int totalValue,
    String modKey,
  ) {
    final theme = Theme.of(context);
    final modValue = totalValue - baseValue;
    
    return Expanded(
      child: InkWell(
        onTap: () async {
          if (!mounted) return;
          await _showStatEditDialog(
            context,
            label: label,
            modKey: modKey,
            baseValue: baseValue,
            currentModValue: modValue,
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                totalValue.toString(),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildModValueWithSources(
                modValue: modValue,
                modKey: modKey,
                ancestryMods: _ancestryMods,
                theme: theme,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a compact tile for Size which uses string values (e.g., "1M", "2")
  Widget _buildCompactSizeTile(
    BuildContext context,
    String sizeBase,
    String sizeTotal,
    String modKey,
  ) {
    final theme = Theme.of(context);
    // Use progression index difference to calculate mod value
    final baseIndex = HeroMainStats.sizeToIndex(sizeBase);
    final totalIndex = HeroMainStats.sizeToIndex(sizeTotal);
    final modValue = totalIndex - baseIndex;
    
    return Expanded(
      child: InkWell(
        onTap: () async {
          if (!mounted) return;
          await _showSizeEditDialog(
            context,
            sizeBase: sizeBase,
            currentModValue: modValue,
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Size',
                style: theme.textTheme.labelSmall,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                sizeTotal,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildModValueWithSources(
                modValue: modValue,
                modKey: modKey,
                ancestryMods: _ancestryMods,
                theme: theme,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactVitalDisplay(
    BuildContext context, {
    required String label,
    required _NumericField field,
    bool allowNegative = false,
  }) {
    final theme = Theme.of(context);
    final value = _latestStats != null
        ? _numberValueFromStats(_latestStats!, field)
        : 0;

    return InkWell(
      onTap: () async {
        if (!mounted) return;
        
        final controller = TextEditingController(text: value.toString());
        
        try {
          final result = await showDialog<String>(
            context: context,
            builder: (dialogContext) {
              return AlertDialog(
                title: Text('Edit $label'),
                content: TextField(
                  controller: controller,
                  keyboardType: TextInputType.numberWithOptions(signed: allowNegative),
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Value',
                    border: OutlineInputBorder(),
                  ),
                  inputFormatters: _formatters(allowNegative, 4),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(controller.text),
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          );
          
          // Ensure dialog is fully dismissed before persisting
          if (result != null && result.isNotEmpty && mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!mounted) return;
              await _persistNumberField(field, result);
            });
          }
        } finally {
          await Future.delayed(const Duration(milliseconds: 50));
          controller.dispose();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Text(label, style: theme.textTheme.labelSmall),
            const SizedBox(height: 2),
            Text(
              value.toString(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showStatEditDialog(
    BuildContext context, {
    required String label,
    required String modKey,
    required int baseValue,
    required int currentModValue,
  }) async {
    if (!mounted) return;
    
    final controller = TextEditingController(text: currentModValue.toString());
    final sourcesDesc = _getModSourceDescription(modKey, _ancestryMods);

    try {
      final result = await showDialog<int>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text('Edit $label'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Base: $baseValue'),
                if (sourcesDesc.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(dialogContext).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 16,
                          color: Theme.of(dialogContext).colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            sourcesDesc,
                            style: TextStyle(
                              color: Theme.of(dialogContext).colorScheme.onPrimaryContainer,
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
                  keyboardType: const TextInputType.numberWithOptions(signed: true),
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Modification',
                    border: OutlineInputBorder(),
                    helperText: 'Enter modifier (-99 to +99)',
                  ),
                  inputFormatters: _formatters(true, 4),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final value = int.tryParse(controller.text);
                  if (value != null) {
                    Navigator.of(dialogContext).pop(value);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );

      // Ensure dialog is fully dismissed before persisting
      if (result != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          await _persistModification(modKey, result.toString());
        });
      }
    } finally {
      await Future.delayed(const Duration(milliseconds: 50));
      controller.dispose();
    }
  }

  Future<void> _showSizeEditDialog(
    BuildContext context, {
    required String sizeBase,
    required int currentModValue,
  }) async {
    if (!mounted) return;
    
    final controller = TextEditingController(text: currentModValue.toString());
    final sourcesDesc = _getModSourceDescription(HeroModKeys.size, _ancestryMods);
    final parsed = HeroMainStats.parseSize(sizeBase);
    final categoryName = switch (parsed.category) {
      'T' => 'Tiny',
      'S' => 'Small',
      'M' => 'Medium',
      'L' => 'Large',
      _ => '',
    };
    final baseDisplay = categoryName.isNotEmpty 
        ? '$sizeBase ($categoryName)'
        : sizeBase;

    try {
      final result = await showDialog<int>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Edit Size'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Base: $baseDisplay'),
                if (sourcesDesc.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(dialogContext).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 16,
                          color: Theme.of(dialogContext).colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            sourcesDesc,
                            style: TextStyle(
                              color: Theme.of(dialogContext).colorScheme.onPrimaryContainer,
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
                  keyboardType: const TextInputType.numberWithOptions(signed: true),
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Size Modification',
                    border: OutlineInputBorder(),
                    helperText: 'Enter modifier (affects numeric portion)',
                  ),
                  inputFormatters: _formatters(true, 4),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final value = int.tryParse(controller.text);
                  if (value != null) {
                    Navigator.of(dialogContext).pop(value);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );

      // Ensure dialog is fully dismissed before persisting
      if (result != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          await _persistModification(HeroModKeys.size, result.toString());
        });
      }
    } finally {
      await Future.delayed(const Duration(milliseconds: 50));
      controller.dispose();
    }
  }

  List<String> _wealthInsights(int wealth) {
    if (wealth <= 0) {
      return const [
        'No notable wealth recorded yet.',
        'Increase wealth to unlock lifestyle perks.',
      ];
    }
    final tier = _wealthTiers.lastWhereOrNull((t) => wealth >= t.score);
    final nextTier = _wealthTiers.firstWhereOrNull((t) => wealth < t.score);
    final lines = <String>[];
    if (tier != null) {
      lines.add('Score ${tier.score}: ${tier.description}');
    }
    if (nextTier != null) {
      lines.add('Next tier at ${nextTier.score}: ${nextTier.description}');
    } else if (wealth > _wealthTiers.last.score) {
      lines.add('You have surpassed all recorded wealth tiers.');
    }
    return lines;
  }

  List<String> _renownInsights(int renown) {
    final followers = _renownFollowers.fold<int>(
      0,
      (acc, tier) => renown >= tier.threshold ? tier.followers : acc,
    );
    final impressionTier =
        _impressionTiers.lastWhereOrNull((tier) => renown >= tier.value);
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

  List<String> _xpInsights(int xp, int currentLevel) {
    final currentTier = _xpAdvancementTiers.firstWhereOrNull(
      (tier) => tier.level == currentLevel,
    );
    final nextTier = _xpAdvancementTiers.firstWhereOrNull(
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

  _StaminaState _calculateStaminaState(HeroMainStats stats) {
    final max = stats.staminaMaxEffective;
    final half = (max / 2).floor();
    final current = stats.staminaCurrent;
    if (current > half) {
      return const _StaminaState('Healthy', Colors.green);
    }
    if (current > 0) {
      return const _StaminaState('Winded', Colors.orange);
    }
    if (current > -half) {
      return const _StaminaState('Dying', Colors.redAccent);
    }
    return const _StaminaState('Dead', Colors.red);
  }

  int _recoveryHealAmount(HeroMainStats stats) {
    return stats.recoveryValueEffective;
  }

  Future<void> _handleUseRecovery(HeroMainStats stats) async {
    if (!mounted) return;
    if (stats.recoveriesCurrent <= 0) {
      _showSnack('No recoveries remaining.');
      return;
    }
    final healAmount = _recoveryHealAmount(stats);
    if (healAmount <= 0) {
      _showSnack('Cannot spend a recovery while stamina max is zero.');
      return;
    }
    final newRecoveries = stats.recoveriesCurrent - 1;
    final newStamina = math.min(
      stats.staminaCurrent + healAmount,
      stats.staminaMaxEffective,
    );
    try {
      await ref.read(heroRepositoryProvider).updateVitals(
            widget.heroId,
            recoveriesCurrent: newRecoveries,
            staminaCurrent: newStamina,
          );
    } catch (err) {
      if (!mounted) return;
      _showSnack('Failed to spend recovery: $err');
    }
  }

  Future<void> _handleDealDamage(HeroMainStats stats) async {
    final amount = await _promptForAmount(
      title: 'Apply Damage',
      description: 'Temporary stamina is removed before current stamina.',
    );
    if (amount == null || amount <= 0) return;
    if (!mounted) return;

    var temp = stats.staminaTemp;
    var current = stats.staminaCurrent;

    if (amount <= temp) {
      temp -= amount;
    } else {
      final remaining = amount - temp;
      temp = 0;
      current -= remaining;
    }

    try {
      await ref.read(heroRepositoryProvider).updateVitals(
            widget.heroId,
            staminaTemp: temp,
            staminaCurrent: current,
          );
    } catch (err) {
      if (!mounted) return;
      _showSnack('Failed to apply damage: $err');
    }
  }

  Future<void> _handleApplyHealing(HeroMainStats stats) async {
    final amount = await _promptForAmount(
      title: 'Apply Healing',
      description: 'Healing restores current stamina up to its effective max.',
    );
    if (amount == null || amount <= 0) return;
    if (!mounted) return;

    final newCurrent = math.min(
      stats.staminaCurrent + amount,
      stats.staminaMaxEffective,
    );

    try {
      await ref.read(heroRepositoryProvider).updateVitals(
            widget.heroId,
            staminaCurrent: newCurrent,
          );
    } catch (err) {
      if (!mounted) return;
      _showSnack('Failed to apply healing: $err');
    }
  }

  Future<int?> _promptForAmount({
    required String title,
    String? description,
  }) async {
    if (!mounted) return null;
    
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
                  inputFormatters: _formatters(false, 3),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
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
                child: const Text('Apply'),
              ),
            ],
          );
        },
      );
      
      // Wait for dialog animation to complete before returning result
      if (result != null) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
      
      return result;
    } finally {
      await Future.delayed(const Duration(milliseconds: 100));
      controller.dispose();
    }
  }

  List<TextInputFormatter> _formatters(bool allowNegative, int maxLength) {
    return [
      allowNegative
          ? FilteringTextInputFormatter.allow(RegExp(r'-?\d*'))
          : FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(maxLength),
    ];
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatSigned(int value) {
    if (value > 0) return '+$value';
    return value.toString();
  }

  /// Maps HeroModKeys to ancestry stat names for looking up sources.
  String? _modKeyToAncestryStatName(String modKey) {
    return switch (modKey) {
      HeroModKeys.might => 'might',
      HeroModKeys.agility => 'agility',
      HeroModKeys.reason => 'reason',
      HeroModKeys.intuition => 'intuition',
      HeroModKeys.presence => 'presence',
      HeroModKeys.size => 'size',
      HeroModKeys.speed => 'speed',
      HeroModKeys.disengage => 'disengage',
      HeroModKeys.stability => 'stability',
      HeroModKeys.staminaMax => 'stamina',
      HeroModKeys.recoveriesMax => 'recoveries',
      HeroModKeys.surges => 'surges',
      HeroModKeys.wealth => 'wealth',
      HeroModKeys.renown => 'renown',
      _ => null,
    };
  }

  /// Gets the source description for a given modification key.
  String _getModSourceDescription(
    String modKey,
    HeroStatModifications ancestryMods,
  ) {
    final statName = _modKeyToAncestryStatName(modKey);
    if (statName == null) return '';
    return ancestryMods.getSourcesDescription(statName);
  }

  /// Builds a widget showing the modification value.
  Widget _buildModValueWithSources({
    required int modValue,
    required String modKey,
    required HeroStatModifications ancestryMods,
    required ThemeData theme,
  }) {
    if (modValue == 0) return const SizedBox.shrink();
    
    return Text(
      _formatSigned(modValue),
      style: theme.textTheme.labelSmall?.copyWith(
        color: modValue > 0 ? Colors.green : Colors.red,
      ),
    );
  }
}

class _StatTileData {
  const _StatTileData(this.label, this.baseValue, this.totalValue, this.modKey);

  final String label;
  final int baseValue;
  final int totalValue;
  final String modKey;
}

class _StaminaState {
  const _StaminaState(this.label, this.color);

  final String label;
  final Color color;
}

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

class _HeroicResourceRequest {
  const _HeroicResourceRequest({
    required this.classId,
    required this.fallbackName,
  });

  final String? classId;
  final String? fallbackName;

  @override
  bool operator ==(Object other) {
    return other is _HeroicResourceRequest &&
        other.classId == classId &&
        other.fallbackName == fallbackName;
  }

  @override
  int get hashCode => Object.hash(classId, fallbackName);
}

final _heroicResourceCache = <String, HeroicResourceDetails>{};

final _heroicResourceDetailsProvider =
    FutureProvider.family<HeroicResourceDetails?, _HeroicResourceRequest>(
  (ref, request) async {
    final slug = _slugFromClassId(request.classId);
    if (slug == null) {
      final fallback = request.fallbackName;
      return fallback == null ? null : HeroicResourceDetails(name: fallback);
    }

    final cached = _heroicResourceCache[slug];
    if (cached != null) return cached;

    try {
      final maps = await FeatureRepository.loadClassFeatureMaps(slug);
      final entry = maps.firstWhereOrNull(
        (map) =>
            (map['type']?.toString().toLowerCase() ?? '') == 'heroic resource',
      );
      if (entry == null) {
        final fallback = request.fallbackName;
        if (fallback == null) return null;
        final details = HeroicResourceDetails(name: fallback);
        _heroicResourceCache[slug] = details;
        return details;
      }

      final name = entry['name']?.toString() ??
          request.fallbackName ??
          'Heroic Resource';
      final description = entry['description']?.toString();

      String? inCombatName;
      String? inCombatDescription;
      final inCombat = entry['in_combat'];
      if (inCombat is Map) {
        inCombatName = inCombat['name']?.toString();
        inCombatDescription = inCombat['description']?.toString();
      }

      String? outCombatName;
      String? outCombatDescription;
      final outCombat = entry['out_of_combat'];
      if (outCombat is Map) {
        outCombatName = outCombat['name']?.toString();
        outCombatDescription = outCombat['description']?.toString();
      }

      final details = HeroicResourceDetails(
        name: name,
        description: description,
        inCombatName: inCombatName,
        inCombatDescription: inCombatDescription,
        outCombatName: outCombatName,
        outCombatDescription: outCombatDescription,
      );
      _heroicResourceCache[slug] = details;
      return details;
    } catch (_) {
      final fallback = request.fallbackName;
      return fallback == null ? null : HeroicResourceDetails(name: fallback);
    }
  },
);

String? _slugFromClassId(String? classId) {
  if (classId == null || classId.isEmpty) return null;
  if (classId.startsWith('class_')) {
    return classId.substring('class_'.length);
  }
  return classId;
}

class _WealthTier {
  const _WealthTier(this.score, this.description);

  final int score;
  final String description;
}

const List<_WealthTier> _wealthTiers = [
  _WealthTier(1, 'Common gear, lodging, and travel'),
  _WealthTier(2, 'Fine dining, fine lodging, horse and cart'),
  _WealthTier(3, 'Catapult, small house'),
  _WealthTier(4, 'Library, tavern, manor home, sailing boat'),
  _WealthTier(5, 'Church, keep, wizard tower'),
  _WealthTier(6, 'Castle, shipyard'),
];

class _RenownFollowerTier {
  const _RenownFollowerTier(this.threshold, this.followers);

  final int threshold;
  final int followers;
}

const List<_RenownFollowerTier> _renownFollowers = [
  _RenownFollowerTier(3, 1),
  _RenownFollowerTier(6, 2),
  _RenownFollowerTier(9, 3),
  _RenownFollowerTier(12, 4),
];

class _RenownImpressionTier {
  const _RenownImpressionTier(this.value, this.description);

  final int value;
  final String description;
}

const List<_RenownImpressionTier> _impressionTiers = [
  _RenownImpressionTier(1, 'Brigand leader, commoner, shop owner'),
  _RenownImpressionTier(2, 'Knight, local guildmaster, professor'),
  _RenownImpressionTier(3, 'Cult leader, locally known mage, noble lord'),
  _RenownImpressionTier(4, 'Assassin, baron, locally famous entertainer'),
  _RenownImpressionTier(5, 'Captain of the watch, high priest, viscount'),
  _RenownImpressionTier(6, 'Count, warlord'),
  _RenownImpressionTier(7, 'Marquis, world-renowned entertainer'),
  _RenownImpressionTier(8, 'Duke, spymaster'),
  _RenownImpressionTier(9, 'Archmage, prince'),
  _RenownImpressionTier(10, 'Demon lord, monarch'),
  _RenownImpressionTier(11, 'Archdevil, archfey, demigod'),
  _RenownImpressionTier(12, 'Deity, titan'),
];

class _XpAdvancement {
  const _XpAdvancement(this.level, this.minXp, this.maxXp);

  final int level;
  final int minXp;
  final int maxXp;
}

const List<_XpAdvancement> _xpAdvancementTiers = [
  _XpAdvancement(1, 0, 15),
  _XpAdvancement(2, 16, 31),
  _XpAdvancement(3, 32, 47),
  _XpAdvancement(4, 48, 63),
  _XpAdvancement(5, 64, 79),
  _XpAdvancement(6, 80, 95),
  _XpAdvancement(7, 96, 111),
  _XpAdvancement(8, 112, 127),
  _XpAdvancement(9, 128, 143),
  _XpAdvancement(10, 144, -1), // -1 means no max
];
