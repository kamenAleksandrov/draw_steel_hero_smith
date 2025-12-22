import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/providers.dart';
import '../../core/theme/ability_colors.dart';
import '../../core/theme/hero_theme.dart';
import '../creators/hero_creators/hero_creator_page.dart';
import '../heroes_sheet/hero_sheet_page.dart';
// import '../creators/hero_creators/strife_creator_page.dart';
// OutlinedButton.icon(
//             onPressed: () {
//               Navigator.of(context).push(
//                 MaterialPageRoute(builder: (_) => const StrifeCreatorPage2()),
//               );
//             },
//             icon: const Icon(Icons.science),
//             label: const Text('Test New Creator (Demo)'),
//           ),

class HeroesPage extends ConsumerWidget {
  const HeroesPage({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summariesAsync = ref.watch(heroSummariesProvider);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: summariesAsync.when(
        data: (items) => _buildContent(context, ref, items),
        error: (e, st) => _buildErrorState(context, ref, e),
        loading: () => _buildLoadingState(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, List items) {
    if (items.isEmpty) {
      return _buildEmptyState(context, ref);
    }

    return CustomScrollView(
      slivers: [
        // Header section
        SliverToBoxAdapter(
          child: _buildHeader(context),
        ),
        
        // Create hero button
        SliverToBoxAdapter(
          child: _buildCreateHeroSection(context, ref),
        ),

        // Heroes list
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildHeroCard(context, ref, items[index]),
              childCount: items.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: HeroTheme.heroCardRadius,
        gradient: HeroTheme.headerGradient(context),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // const Icon(
          //   Icons.person,
          //   size: 48,
          //   color: HeroTheme.primarySection,
          // ),
          const SizedBox(),
          Text(
            'Your Heroes',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: HeroTheme.primarySection,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create and manage your Draw Steel heroes',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCreateHeroSection(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          FilledButton.icon(
            onPressed: () async {
              final repo = ref.read(heroRepositoryProvider);
              final id = await repo.createHero(name: 'New Hero');
              if (!context.mounted) return;
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => HeroCreatorPage(heroId: id)),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Create New Hero'),
            style: HeroTheme.primaryActionButtonStyle(context),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, WidgetRef ref, dynamic hero) {
    final theme = Theme.of(context);
    final chips = <Widget>[];
    
    // Add chips only if values exist and are not empty
    if (hero.className != null && hero.className!.isNotEmpty) {
      final resourceColor = hero.heroicResourceName != null
          ? AbilityColors.getHeroicResourceColor(hero.heroicResourceName!)
          : HeroTheme.primarySection;
      chips.add(_buildChip(context, hero.className!, resourceColor));
    }
    if (hero.ancestryName != null && hero.ancestryName!.isNotEmpty) {
      chips.add(_buildChip(context, hero.ancestryName!, HeroTheme.ancestryStep));
    }
    if (hero.careerName != null && hero.careerName!.isNotEmpty) {
      chips.add(_buildChip(context, hero.careerName!, HeroTheme.careerStep));
    }
    if (hero.complicationName != null && hero.complicationName!.isNotEmpty) {
      chips.add(_buildChip(context, hero.complicationName!, theme.colorScheme.error));
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: HeroTheme.cardElevation,
      shape: const RoundedRectangleBorder(borderRadius: HeroTheme.cardRadius),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => HeroSheetPage(
                heroId: hero.id,
                heroName: hero.name,
              ),
            ),
          );
        },
        borderRadius: HeroTheme.cardRadius,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildChip(context, 'Lvl ${hero.level}', HeroTheme.primarySection),
                  const SizedBox(height: 6),
                  CircleAvatar(
                    backgroundColor: HeroTheme.getHeroStatusColor('draft').withValues(alpha: 0.2),
                    child: Icon(
                      Icons.person,
                      color: HeroTheme.getHeroStatusColor('draft'),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hero.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: chips,
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit Hero',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => HeroCreatorPage(heroId: hero.id),
                    ),
                  );
                },
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) async {
                  if (value == 'delete') {
                    await _deleteHero(context, ref, hero);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(BuildContext context, String label, Color color) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return HeroTheme.buildEmptyState(
      context,
      icon: Icons.person_add,
      title: 'No Heroes Yet',
      subtitle: 'Create your first hero to begin your Draw Steel adventure',
      action: FilledButton.icon(
        onPressed: () async {
          final repo = ref.read(heroRepositoryProvider);
          final id = await repo.createHero(name: 'New Hero');
          if (!context.mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => HeroCreatorPage(heroId: id)),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Create First Hero'),
        style: HeroTheme.primaryActionButtonStyle(context),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              'Failed to Load Heroes',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error.toString(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                // Refresh by rebuilding the provider
                ref.invalidate(heroSummariesProvider);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: HeroTheme.primaryActionButtonStyle(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: HeroTheme.primarySection,
          ),
          const SizedBox(height: 24),
          Text(
            'Loading heroes...',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteHero(BuildContext context, WidgetRef ref, dynamic hero) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Hero'),
        content: Text('Are you sure you want to delete "${hero.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete),
            label: const Text('Delete'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final repo = ref.read(heroRepositoryProvider);
      await repo.deleteHero(hero.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted ${hero.name}')),
      );
    }
  }
}

