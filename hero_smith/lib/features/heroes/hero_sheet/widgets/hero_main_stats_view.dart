import 'dart:async';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/providers.dart';
import '../../../../core/models/hero_mod_keys.dart';
import '../../../../core/repositories/feature_repository.dart';
import '../../../../core/repositories/hero_repository.dart';
import '../state/hero_main_stats_providers.dart';

class HeroMainStatsView extends ConsumerStatefulWidget {
  const HeroMainStatsView({
    super.key,
    required this.heroId,
  });

  final String heroId;

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
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    for (final entry in _numberControllers.entries) {
      entry.value.addListener(() => _handleNumberChanged(entry.key));
    }
    for (final entry in _modControllers.entries) {
      entry.value.addListener(() => _handleModChanged(entry.key));
    }
  }

  @override
  void dispose() {
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
    
    // Listen for changes and apply them to controllers
    ref.listen<AsyncValue<HeroMainStats>>(
      heroMainStatsProvider(widget.heroId),
      (previous, next) {
        next.whenData(_applyStats);
      },
    );
    
    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _buildErrorState(context, error),
      data: (stats) {
        // Apply stats when data becomes available
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_latestStats != stats) {
            _applyStats(stats);
          }
        });
        
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(context),
          const SizedBox(height: 16),
          _buildWealthRenownCard(context, stats),
          const SizedBox(height: 16),
          _buildPrimaryStatsCard(context, stats),
          const SizedBox(height: 16),
          _buildSecondaryStatsCard(context, stats),
          const SizedBox(height: 16),
          _buildStaminaAndRecoveries(context, stats),
          const SizedBox(height: 16),
          _buildResourceAndSurges(context, stats, resourceDetails),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
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
            _buildCompactNumberDisplay(
              context,
              label: 'Level',
              field: _NumericField.level,
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
                _buildCompactStatTile(context, 'Size', stats.sizeBase,
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
                    onTap: () => _showStatEditDialog(
                      context,
                      label: 'Stamina Max',
                      modKey: HeroModKeys.staminaMax,
                      baseValue: stats.staminaMaxBase,
                      currentModValue: staminaMaxMod,
                    ),
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
                          if (staminaMaxMod != 0)
                            Text(
                              _formatSigned(staminaMaxMod),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: staminaMaxMod > 0 ? Colors.green : Colors.red,
                              ),
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
                    onTap: () => _showStatEditDialog(
                      context,
                      label: 'Recoveries Max',
                      modKey: HeroModKeys.recoveriesMax,
                      baseValue: stats.recoveriesMaxBase,
                      currentModValue: recoveriesMaxMod,
                    ),
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
                          if (recoveriesMaxMod != 0)
                            Text(
                              _formatSigned(recoveriesMaxMod),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: recoveriesMaxMod > 0 ? Colors.green : Colors.red,
                              ),
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
      builder: (context) {
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
              onPressed: () => Navigator.of(context).pop(),
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

  Widget _buildNumberInput(
    BuildContext context, {
    required String label,
    required _NumericField field,
    String? helper,
    bool allowNegative = false,
    TextAlign textAlign = TextAlign.start,
  }) {
    final theme = Theme.of(context);
    final controller = _numberControllers[field]!;
    final focusNode = _numberFocusNodes[field]!;
    final maxLength = allowNegative ? 4 : 3;

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
            keyboardType: TextInputType.number,
            textAlign: textAlign,
            maxLength: maxLength,
            buildCounter: (_,
                    {int? currentLength, bool? isFocused, int? maxLength}) =>
                null,
            inputFormatters: _formatters(allowNegative, maxLength),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              helperText: helper,
            ),
          ),
        ],
      ),
    );
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
      onTap: () => _showNumberEditDialog(context, label, field),
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
      onTap: () => _showModEditDialog(
        context,
        title: title,
        modKey: modKey,
        baseValue: baseValue,
        currentModValue: modValue,
        insights: insights,
      ),
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
                  Text(
                    '(${_formatSigned(modValue)})',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: modValue > 0 ? Colors.green : Colors.red,
                    ),
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
    final controller = TextEditingController(
      text: _numberValueFromStats(_latestStats!, field).toString(),
    );

    final result = await showDialog<int>(
      context: context,
      builder: (context) {
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final value = int.tryParse(controller.text);
                if (value != null) {
                  Navigator.of(context).pop(value);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result != null) {
      await _persistNumberField(field, result.toString());
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
    final controller = TextEditingController(text: currentModValue.toString());

    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit $title'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Base: $baseValue'),
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final value = int.tryParse(controller.text);
                if (value != null) {
                  Navigator.of(context).pop(value);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result != null) {
      await _persistModification(modKey, result.toString());
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
        onTap: () => _showStatEditDialog(
          context,
          label: label,
          modKey: modKey,
          baseValue: baseValue,
          currentModValue: modValue,
        ),
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
              if (modValue != 0)
                Text(
                  _formatSigned(modValue),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: modValue > 0 ? Colors.green : Colors.red,
                  ),
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
        final controller = TextEditingController(text: value.toString());
        final result = await showDialog<String>(
          context: context,
          builder: (context) {
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
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(controller.text),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
        controller.dispose();

        if (result != null && result.isNotEmpty) {
          await _persistNumberField(field, result);
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
    final controller = TextEditingController(text: currentModValue.toString());

    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit $label'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Base: $baseValue'),
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final value = int.tryParse(controller.text);
                if (value != null) {
                  Navigator.of(context).pop(value);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result != null) {
      await _persistModification(modKey, result.toString());
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
    final max = stats.staminaMaxEffective;
    if (max <= 0) return 0;
    return math.max(max ~/ 3, 1);
  }

  Future<void> _handleUseRecovery(HeroMainStats stats) async {
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
    final controller = TextEditingController(text: '1');
    final result = await showDialog<int>(
      context: context,
      builder: (context) {
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(controller.text.trim());
                if (value == null || value <= 0) {
                  Navigator.of(context).pop();
                } else {
                  Navigator.of(context).pop(value);
                }
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
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
}

class _HeroicResourceContent extends StatelessWidget {
  const _HeroicResourceContent({
    required this.name,
    required this.description,
    required this.inCombatName,
    required this.inCombatDescription,
    required this.outCombatName,
    required this.outCombatDescription,
    required this.currentField,
  });

  final String name;
  final String? description;
  final String? inCombatName;
  final String? inCombatDescription;
  final String? outCombatName;
  final String? outCombatDescription;
  final Widget currentField;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        currentField,
        if ((description ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            description!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if ((inCombatDescription ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(inCombatName ?? 'In Combat', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            inCombatDescription!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if ((outCombatDescription ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(outCombatName ?? 'Out of Combat',
              style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            outCombatDescription!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
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
