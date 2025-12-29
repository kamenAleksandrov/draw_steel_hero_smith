import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/providers.dart';
import '../../core/services/hero_export_service.dart';
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
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
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
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _showImportDialog(context, ref),
                icon: const Icon(Icons.download),
                label: const Text('Import'),
              ),
            ],
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
                  if (value == 'export') {
                    await _exportHeroCode(context, ref, hero);
                  } else if (value == 'delete') {
                    await _deleteHero(context, ref, hero);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'export',
                    child: Row(
                      children: [
                        Icon(Icons.share),
                        SizedBox(width: 8),
                        Text('Export Code'),
                      ],
                    ),
                  ),
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

  Future<void> _exportHeroCode(BuildContext context, WidgetRef ref, dynamic hero) async {
    try {
      final db = ref.read(appDatabaseProvider);
      final exportService = HeroExportService(db);
      final code = await exportService.exportHeroToCode(hero.id);
      
      if (!context.mounted) return;
      
      await showDialog(
        context: context,
        builder: (ctx) {
          final theme = Theme.of(ctx);
          final codeLength = code.length;
          
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.upload_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(child: Text('Export ${hero.name}')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Share this code with a friend so they can import your hero build.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Code preview container with scroll
                Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  width: double.maxFinite,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      code,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Code info
                Text(
                  '${codeLength} characters',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 12),
                          Text('Code copied to clipboard!'),
                        ],
                      ),
                      backgroundColor: Colors.green.shade700,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  Navigator.of(ctx).pop();
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy Code'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export hero: $e')),
      );
    }
  }

  Future<void> _showImportDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.download_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                const Text('Import Hero'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paste a hero code from a friend to add their build to your heroes.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  maxLines: 5,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                  decoration: InputDecoration(
                    hintText: 'HERO:H4sIAAAA...',
                    hintStyle: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.paste),
                      tooltip: 'Paste from clipboard',
                      onPressed: () async {
                        final data = await Clipboard.getData(Clipboard.kTextPlain);
                        if (data?.text != null) {
                          controller.text = data!.text!;
                          setState(() {});
                        }
                      },
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (controller.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${controller.text.length} characters',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: controller.text.trim().isEmpty
                    ? null
                    : () => Navigator.of(ctx).pop(controller.text.trim()),
                icon: const Icon(Icons.download),
                label: const Text('Import'),
              ),
            ],
          ),
        );
      },
    );
    
    if (result == null || result.isEmpty) return;
    
    try {
      final db = ref.read(appDatabaseProvider);
      final exportService = HeroExportService(db);
      
      // Validate first
      final preview = exportService.validateCode(result);
      if (preview == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Text('Invalid hero code format'),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      
      if (!preview.isCompatible) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Incompatible version (v${preview.formatVersion}). Please ask for an updated code.',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      
      // Import the hero
      final newHeroId = await exportService.importHeroFromCode(result);
      
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Imported "${preview.name}" successfully!')),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      // Navigate to the imported hero
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => HeroCreatorPage(heroId: newHeroId)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Failed to import: $e')),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

