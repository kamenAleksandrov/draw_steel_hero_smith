import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/providers.dart';
import '../../core/models/component.dart';
import '../../core/theme/strife_theme.dart';
import '../../widgets/abilities/abilities_shared.dart';
import '../../widgets/abilities/ability_expandable_item.dart';

class AbilitiesPage extends ConsumerWidget {
  const AbilitiesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final abilitiesAsync = ref.watch(componentsByTypeProvider('ability'));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: StrifeTheme.abilitiesAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Abilities Compendium'),
      ),
      body: abilitiesAsync.when(
        data: (items) => SafeArea(
          top: false,
          child: _AbilitiesView(items: items),
        ),
        loading: () => const _AbilitiesLoadingState(),
        error: (err, _) => _AbilitiesErrorState(error: err),
      ),
    );
  }
}

class _AbilitiesView extends StatelessWidget {
  const _AbilitiesView({required this.items});

  final List<Component> items;

  @override
  Widget build(BuildContext context) {
    final decoration = _abilitiesBackground(context);
    final sorted = List<Component>.from(items)
      ..sort((a, b) => a.name.compareTo(b.name));

    if (sorted.isEmpty) {
      return DecoratedBox(
        decoration: decoration,
        child: const _AbilitiesEmptyState(),
      );
    }

    final stats = _AbilitySummaryStats.fromComponents(sorted);

    return DecoratedBox(
      decoration: decoration,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: _AbilitiesSummaryCard(stats: stats),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: AbilityExpandableItem(component: sorted[index]),
                ),
                childCount: sorted.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AbilitiesSummaryCard extends StatelessWidget {
  const _AbilitiesSummaryCard({required this.stats});

  final _AbilitySummaryStats stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: StrifeTheme.cardElevation,
      shape: const RoundedRectangleBorder(borderRadius: StrifeTheme.cardRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StrifeTheme.sectionHeader(
            context,
            title: 'Ability Library',
            subtitle: 'Browse ${stats.total} abilities by resource and cost.',
            icon: Icons.bolt,
            accent: StrifeTheme.abilitiesAccent,
          ),
          Padding(
            padding: StrifeTheme.cardPadding,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildStatChip(
                  context,
                  icon: Icons.auto_awesome,
                  label: 'Total abilities',
                  value: stats.total.toString(),
                ),
                _buildStatChip(
                  context,
                  icon: Icons.star_border,
                  label: 'Signature (no cost)',
                  value: stats.signatureCount.toString(),
                ),
                _buildStatChip(
                  context,
                  icon: Icons.flash_on,
                  label: 'Costed abilities',
                  value: stats.costedCount.toString(),
                ),
                _buildStatChip(
                  context,
                  icon: Icons.science_outlined,
                  label: 'Resource types',
                  value: stats.resourceTypeCount.toString(),
                ),
                _buildStatChip(
                  context,
                  icon: Icons.trending_up,
                  label: 'Highest cost',
                  value: stats.highestCost?.toString() ?? '—',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final accent = StrifeTheme.abilitiesAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: accent.withValues(alpha: 0.08),
        border: Border.all(color: accent.withValues(alpha: 0.24), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AbilitiesEmptyState extends StatelessWidget {
  const _AbilitiesEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          elevation: StrifeTheme.cardElevation,
          shape: const RoundedRectangleBorder(borderRadius: StrifeTheme.cardRadius),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StrifeTheme.sectionHeader(
                context,
                title: 'No abilities found',
                subtitle: 'Check your data seed or try syncing again.',
                icon: Icons.info_outline,
                accent: StrifeTheme.abilitiesAccent,
              ),
              Padding(
                padding: StrifeTheme.cardPadding,
                child: Text(
                  'We couldn\'t find any abilities in the database. '
                  'Verify that the compendium has been seeded and then refresh this page.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AbilitiesLoadingState extends StatelessWidget {
  const _AbilitiesLoadingState();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _abilitiesBackground(context),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading abilities...'),
          ],
        ),
      ),
    );
  }
}

class _AbilitiesErrorState extends StatelessWidget {
  const _AbilitiesErrorState({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final message = error.toString();
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: _abilitiesBackground(context),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: StrifeTheme.cardElevation,
            shape: const RoundedRectangleBorder(borderRadius: StrifeTheme.cardRadius),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StrifeTheme.sectionHeader(
                  context,
                  title: 'Unable to load abilities',
                  subtitle: 'Please try again in a moment.',
                  icon: Icons.error_outline,
                  accent: StrifeTheme.abilitiesAccent,
                ),
                Padding(
                  padding: StrifeTheme.cardPadding,
                  child: Text(
                    message,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AbilitySummaryStats {
  const _AbilitySummaryStats({
    required this.total,
    required this.signatureCount,
    required this.costedCount,
    required this.highestCost,
    required this.resourceTypeCount,
  });

  factory _AbilitySummaryStats.fromComponents(List<Component> components) {
    var signature = 0;
    var costed = 0;
    int? highestCost;
    final resourceTypes = <String>{};

    for (final component in components) {
      final abilityData = AbilityData(component);
      final cost = _resolveCost(component);

      if (cost == null || cost <= 0) {
        signature += 1;
      } else {
        costed += 1;
        if (highestCost == null || cost > highestCost) {
          highestCost = cost;
        }
      }

      final resourceType = abilityData.resourceType;
      if (resourceType != null && resourceType.isNotEmpty) {
        resourceTypes.add(resourceType);
      }
    }

    return _AbilitySummaryStats(
      total: components.length,
      signatureCount: signature,
      costedCount: costed,
      highestCost: highestCost,
      resourceTypeCount: resourceTypes.length,
    );
  }

  static int? _resolveCost(Component ability) {
    final data = ability.data;
    final direct = _toInt(data['cost']);
    if (direct != null) return direct;

    final costs = data['costs'];
    if (costs is Map) {
      return _toInt(costs['amount']);
    }

    return null;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();
    if (value is String) {
      final match = RegExp(r'^-?\\d+').firstMatch(value.trim());
      if (match != null) {
        return int.tryParse(match.group(0)!);
      }
    }
    return null;
  }

  final int total;
  final int signatureCount;
  final int costedCount;
  final int? highestCost;
  final int resourceTypeCount;
}

BoxDecoration _abilitiesBackground(BuildContext context) {
  final theme = Theme.of(context);
  return BoxDecoration(
    gradient: LinearGradient(
      colors: [
        StrifeTheme.abilitiesAccent.withValues(alpha: 0.08),
        theme.colorScheme.surface,
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );
}
