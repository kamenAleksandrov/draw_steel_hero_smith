import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/db/providers.dart';
import '../../../../../core/models/downtime_tracking.dart';
import '../../../../../core/theme/hero_theme.dart';
import 'project_editor_dialog.dart';
import 'project_detail_card.dart';
import 'project_template_browser.dart';

/// Provider for hero's downtime projects
final heroProjectsProvider =
    StreamProvider.family<List<HeroDowntimeProject>, String>((ref, heroId) async* {
  final repo = ref.read(downtimeRepositoryProvider);
  
  // Initial load
  yield await repo.getHeroProjects(heroId);
  
  // Poll for updates every 2 seconds
  await for (final _ in Stream.periodic(const Duration(seconds: 2))) {
    yield await repo.getHeroProjects(heroId);
  }
});

class ProjectsListTab extends ConsumerWidget {
  const ProjectsListTab({super.key, required this.heroId});

  final String heroId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(heroProjectsProvider(heroId));

    return projectsAsync.when(
      data: (projects) => _buildContent(context, ref, projects),
      loading: () => _buildLoadingState(context),
      error: (error, stack) => _buildErrorState(context, ref, error),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<HeroDowntimeProject> projects,
  ) {
    return CustomScrollView(
      slivers: [
        // Add project button
        SliverToBoxAdapter(
          child: _buildAddProjectButton(context, ref),
        ),

        // Active projects
        if (projects.where((p) => !p.isCompleted).isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Active Projects',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final activeProjects =
                    projects.where((p) => !p.isCompleted).toList();
                return ProjectDetailCard(
                  project: activeProjects[index],
                  heroId: heroId,
                  onTap: () => _editProject(context, ref, activeProjects[index]),
                  onAddPoints: () => _addPointsToProject(context, ref, activeProjects[index]),
                  onDelete: () => _deleteProject(context, ref, activeProjects[index]),
                );
              },
              childCount: projects.where((p) => !p.isCompleted).length,
            ),
          ),
        ],

        // Completed projects
        if (projects.where((p) => p.isCompleted).isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                'Completed Projects',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final completedProjects =
                    projects.where((p) => p.isCompleted).toList();
                return ProjectDetailCard(
                  project: completedProjects[index],
                  heroId: heroId,
                  onTap: () =>
                      _editProject(context, ref, completedProjects[index]),
                  onDelete: () => _deleteProject(context, ref, completedProjects[index]),
                );
              },
              childCount: projects.where((p) => p.isCompleted).length,
            ),
          ),
        ],

        // Empty state
        if (projects.isEmpty)
          SliverFillRemaining(
            child: _buildEmptyState(context, ref),
          ),

        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: 24),
        ),
      ],
    );
  }

  Widget _buildAddProjectButton(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _createCustomProject(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Create Custom Project'),
              style: HeroTheme.primaryActionButtonStyle(context),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _browseTemplates(context, ref),
              icon: const Icon(Icons.library_books),
              label: const Text('Browse Projects'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return HeroTheme.buildEmptyState(
      context,
      icon: Icons.assignment_outlined,
      title: 'No Projects Yet',
      subtitle: 'Create a custom project or choose from templates',
      action: FilledButton.icon(
        onPressed: () => _createCustomProject(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Create First Project'),
        style: HeroTheme.primaryActionButtonStyle(context),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: HeroTheme.primarySection,
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load projects',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                ref.invalidate(heroProjectsProvider(heroId));
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _createCustomProject(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<HeroDowntimeProject>(
      context: context,
      builder: (context) => ProjectEditorDialog(heroId: heroId),
    );

    if (result != null) {
      final repo = ref.read(downtimeRepositoryProvider);
      await repo.createProject(
        heroId: heroId,
        name: result.name,
        description: result.description,
        projectGoal: result.projectGoal,
        prerequisites: result.prerequisites,
        projectSource: result.projectSource,
        sourceLanguage: result.sourceLanguage,
        guides: result.guides,
        rollCharacteristics: result.rollCharacteristics,
        isCustom: true,
      );
      
      // Refresh the list
      ref.invalidate(heroProjectsProvider(heroId));
    }
  }

  void _deleteProject(
    BuildContext context,
    WidgetRef ref,
    HeroDowntimeProject project,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Project'),
        content: Text(
          'Are you sure you want to remove "${project.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = ref.read(downtimeRepositoryProvider);
      await repo.deleteProject(project.id);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed "${project.name}"'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      
      // Refresh the list
      ref.invalidate(heroProjectsProvider(heroId));
    }
  }

  void _editProject(
    BuildContext context,
    WidgetRef ref,
    HeroDowntimeProject project,
  ) async {
    final result = await showDialog<HeroDowntimeProject>(
      context: context,
      builder: (context) => ProjectEditorDialog(
        heroId: heroId,
        existingProject: project,
      ),
    );

    if (result != null) {
      final repo = ref.read(downtimeRepositoryProvider);
      await repo.updateProject(result);
      
      // Refresh the list
      ref.invalidate(heroProjectsProvider(heroId));
    }
  }

  void _addPointsToProject(
    BuildContext context,
    WidgetRef ref,
    HeroDowntimeProject project,
  ) async {
    final pointsController = TextEditingController();
    
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Points'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add points to: ${project.name}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Current: ${project.currentPoints} / ${project.projectGoal}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pointsController,
              decoration: const InputDecoration(
                labelText: 'Points to Add',
                border: OutlineInputBorder(),
                hintText: 'Enter amount',
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
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
              final points = int.tryParse(pointsController.text);
              if (points != null && points > 0) {
                Navigator.of(context).pop(points);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result > 0) {
      final repo = ref.read(downtimeRepositoryProvider);
      final newTotal = project.currentPoints + result;
      await repo.updateProjectPoints(project.id, newTotal);
      
      // Refresh the list
      ref.invalidate(heroProjectsProvider(heroId));
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $result points to ${project.name}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _browseTemplates(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => ProjectTemplateBrowser(heroId: heroId),
    );
  }
}
