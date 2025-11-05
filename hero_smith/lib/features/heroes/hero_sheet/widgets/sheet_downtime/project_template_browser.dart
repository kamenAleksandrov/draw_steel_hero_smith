import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/data/downtime_data_source.dart';
import '../../../../../core/db/providers.dart';
import '../../../../../core/models/downtime.dart';
import '../../../../../core/theme/hero_theme.dart';

/// Provider for loading project templates from JSON
final projectTemplatesProvider = FutureProvider<List<DowntimeEntry>>((ref) async {
  final dataSource = DowntimeDataSource();
  return await dataSource.loadProjects();
});

/// Provider for loading enhancement templates from JSON
final enhancementTemplatesProvider = FutureProvider<List<DowntimeEntry>>((ref) async {
  final dataSource = DowntimeDataSource();
  return await dataSource.loadEnhancements();
});

/// Dialog to browse and select project templates
class ProjectTemplateBrowser extends ConsumerStatefulWidget {
  const ProjectTemplateBrowser({
    super.key,
    required this.heroId,
  });

  final String heroId;

  @override
  ConsumerState<ProjectTemplateBrowser> createState() => _ProjectTemplateBrowserState();
}

class _ProjectTemplateBrowserState extends ConsumerState<ProjectTemplateBrowser>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                children: [
                  const Icon(Icons.source, size: 32, color: HeroTheme.primarySection),
                  const SizedBox(width: 12),
                  Text(
                    'Downtime Projects',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Tab bar
            TabBar(
              controller: _tabController,
              labelColor: HeroTheme.primarySection,
              indicatorColor: HeroTheme.primarySection,
              tabs: const [
                Tab(text: 'Projects'),
                Tab(text: 'Enhancements'),
              ],
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildProjectsTab(),
                  _buildEnhancementsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectsTab() {
    final templatesAsync = ref.watch(projectTemplatesProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select a project to add to your hero',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: templatesAsync.when(
              data: (templates) => _buildTemplateList(context, templates),
              loading: () => const Center(
                child: CircularProgressIndicator(color: HeroTheme.primarySection),
              ),
              error: (error, stack) => _buildErrorState(context, error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancementsTab() {
    final enhancementsAsync = ref.watch(enhancementTemplatesProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select an enhancement project to add to your hero',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: enhancementsAsync.when(
              data: (enhancements) => _buildEnhancementsGrouped(context, enhancements),
              loading: () => const Center(
                child: CircularProgressIndicator(color: HeroTheme.primarySection),
              ),
              error: (error, stack) => _buildErrorState(context, error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancementsGrouped(
    BuildContext context,
    List<DowntimeEntry> enhancements,
  ) {
    if (enhancements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No enhancements found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      );
    }

    // Group enhancements by level and type
    final grouped = <int, Map<String, List<DowntimeEntry>>>{};
    
    for (final enhancement in enhancements) {
      final level = enhancement.raw['level'] as int? ?? 1;
      final type = enhancement.raw['type'] as String? ?? 'unknown';
      
      grouped.putIfAbsent(level, () => <String, List<DowntimeEntry>>{});
      grouped[level]!.putIfAbsent(type, () => <DowntimeEntry>[]);
      grouped[level]![type]!.add(enhancement);
    }

    // Sort by level
    final sortedLevels = grouped.keys.toList()..sort();

    return ListView.builder(
      itemCount: sortedLevels.length,
      itemBuilder: (context, index) {
        final level = sortedLevels[index];
        final typeGroups = grouped[level]!;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            backgroundColor: HeroTheme.primarySection.withValues(alpha: 0.05),
            collapsedBackgroundColor: HeroTheme.primarySection.withValues(alpha: 0.1),
            leading: Icon(
              Icons.star,
              color: HeroTheme.primarySection,
              size: 20,
            ),
            title: Text(
              _getLevelName(level),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: HeroTheme.primarySection,
                  ),
            ),
            children: typeGroups.entries.map((entry) {
              final type = entry.key;
              final items = entry.value;
              
              return ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                childrenPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: Text(
                  _getEnhancementTypeName(type),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                children: items.map((enhancement) => _buildTemplateCard(context, enhancement)).toList(),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  String _getLevelName(int level) {
    switch (level) {
      case 1:
        return '1st Level Enhancements';
      case 5:
        return '5th Level Enhancements';
      case 9:
        return '9th Level Enhancements';
      default:
        return '${level}th Level Enhancements';
    }
  }

  String _getEnhancementTypeName(String type) {
    switch (type) {
      case 'armor_enhancement':
        return 'Armor Enhancements';
      case 'weapon_enhancement':
        return 'Weapon Enhancements';
      case 'implement_enhancement':
        return 'Implement Enhancements';
      default:
        return type
            .replaceAll('_', ' ')
            .split(' ')
            .map((word) => word.isNotEmpty
                ? word[0].toUpperCase() + word.substring(1)
                : '')
            .join(' ');
    }
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
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
            'Failed to load templates',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateList(
    BuildContext context,
    List<DowntimeEntry> templates,
  ) {
    if (templates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No templates found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final template = templates[index];
        return _buildTemplateCard(context, template);
      },
    );
  }

  Widget _buildTemplateCard(
    BuildContext context,
    DowntimeEntry template,
  ) {
    final theme = Theme.of(context);
    final prerequisites = template.raw['prerequisites'] as Map<String, dynamic>? ?? {};
    final itemPrereqs = (prerequisites['item_prerequisite'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final sourcePrereqs = (prerequisites['project_source'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final rollChars = (template.raw['project_roll_characteristic'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    
    // Handle project_goal which might be stored as String or int in JSON
    final projectGoalRaw = template.raw['project_goal'];
    final projectGoal = projectGoalRaw is int 
        ? projectGoalRaw 
        : (projectGoalRaw is String ? int.tryParse(projectGoalRaw) : null) ?? 100;
    
    final description = template.raw['description'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _takeOnProject(context, ref, template),
        borderRadius: HeroTheme.heroCardRadius,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and goal
              Row(
                children: [
                  Expanded(
                    child: Text(
                      template.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: HeroTheme.primarySection,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: HeroTheme.primarySection.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Goal: $projectGoal',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: HeroTheme.primarySection,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Description
              if (description.isNotEmpty) ...[
                Text(
                  description,
                  style: theme.textTheme.bodySmall,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
              ],

              // Prerequisites
              if (itemPrereqs.isNotEmpty) ...[
                _buildSection(
                  context,
                  'Item Prerequisites',
                  itemPrereqs.map((p) => p['name'] as String? ?? '').toList(),
                  Icons.inventory_2_outlined,
                ),
                const SizedBox(height: 8),
              ],

              // Sources
              if (sourcePrereqs.isNotEmpty) ...[
                _buildSection(
                  context,
                  'Sources',
                  sourcePrereqs.map((p) {
                    final name = p['name'] as String? ?? '';
                    final lang = p['language'] as String? ?? '';
                    return lang.isNotEmpty ? '$name ($lang)' : name;
                  }).toList(),
                  Icons.book_outlined,
                ),
                const SizedBox(height: 8),
              ],

              // Roll characteristics
              if (rollChars.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  children: [
                    const Icon(Icons.casino_outlined, size: 16, color: Colors.grey),
                    Text(
                      'Roll: ${rollChars.map((c) => c['name'] as String? ?? '').join(', ')}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),

              // Take on button
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => _takeOnProject(context, ref, template),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Take On Project'),
                  style: HeroTheme.primaryActionButtonStyle(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<String> items,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(left: 24, top: 2),
              child: Text(
                '• $item',
                style: theme.textTheme.bodySmall,
              ),
            )),
      ],
    );
  }

  void _takeOnProject(
    BuildContext context,
    WidgetRef ref,
    DowntimeEntry template,
  ) async {
    // Extract data from template
    final prerequisites = template.raw['prerequisites'] as Map<String, dynamic>? ?? {};
    final itemPrereqs = (prerequisites['item_prerequisite'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final sourcePrereqs = (prerequisites['project_source'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final rollChars = (template.raw['project_roll_characteristic'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final projectGoal = template.raw['project_goal'] as int? ?? 100;
    final description = template.raw['description'] as String? ?? '';

    // Create prerequisites list
    final prereqsList = itemPrereqs
        .map((p) => p['name'] as String? ?? '')
        .where((name) => name.isNotEmpty)
        .toList();

    // Get first source if available
    final firstSource = sourcePrereqs.isNotEmpty ? sourcePrereqs.first : null;
    final sourceName = firstSource?['name'] as String?;
    final sourceLanguage = firstSource?['language'] as String?;

    // Create roll characteristics list
    final rollCharsList = rollChars
        .map((c) => c['name'] as String? ?? '')
        .where((name) => name.isNotEmpty)
        .toList();

    try {
      final repo = ref.read(downtimeRepositoryProvider);
      await repo.createProject(
        heroId: widget.heroId,
        templateProjectId: template.id,
        name: template.name,
        description: description,
        projectGoal: projectGoal,
        prerequisites: prereqsList,
        projectSource: sourceName,
        sourceLanguage: sourceLanguage,
        guides: [],
        rollCharacteristics: rollCharsList,
        isCustom: false,
      );

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${template.name}" to your projects'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add project: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
