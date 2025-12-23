import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/data/downtime_data_source.dart';
import '../../../../core/db/providers.dart';
import '../../../../core/models/downtime.dart';
import '../../../../core/theme/hero_theme.dart';
import '../../../../core/theme/text/heroes_sheet/downtime/project_template_browser_text.dart';

/// Provider for loading project templates from JSON
final projectTemplatesProvider = FutureProvider<List<DowntimeEntry>>((ref) async {
  final dataSource = DowntimeDataSource();
  return await dataSource.loadProjects();
});

/// Provider for loading imbuement templates from JSON
final imbuementTemplatesProvider = FutureProvider<List<DowntimeEntry>>((ref) async {
  final dataSource = DowntimeDataSource();
  return await dataSource.loadImbuements();
});

/// Provider for loading craftable treasures from JSON
final craftableTreasuresProvider = FutureProvider<List<CraftableTreasure>>((ref) async {
  final dataSource = DowntimeDataSource();
  return await dataSource.loadAllCraftableTreasures();
});

/// Unified search result that can hold any type of project
class SearchableProject {
  final String id;
  final String name;
  final String description;
  final int? projectGoal;
  final String category; // 'project', 'imbuement', 'treasure'
  final dynamic source; // Original DowntimeEntry or CraftableTreasure
  
  SearchableProject({
    required this.id,
    required this.name,
    required this.description,
    this.projectGoal,
    required this.category,
    required this.source,
  });
  
  factory SearchableProject.fromDowntimeEntry(DowntimeEntry entry, String category) {
    final projectGoalRaw = entry.raw['project_goal'];
    final projectGoal = projectGoalRaw is int 
        ? projectGoalRaw 
        : (projectGoalRaw is String ? int.tryParse(projectGoalRaw) : null);
    
    return SearchableProject(
      id: entry.id,
      name: entry.name,
      description: entry.raw['description'] as String? ?? '',
      projectGoal: projectGoal,
      category: category,
      source: entry,
    );
  }
  
  factory SearchableProject.fromCraftableTreasure(CraftableTreasure treasure) {
    return SearchableProject(
      id: treasure.id,
      name: treasure.name,
      description: treasure.description,
      projectGoal: treasure.projectGoal,
      category: 'treasure',
      source: treasure,
    );
  }
}

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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  
  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase().trim();
    });
  }
  
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
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
                  Expanded(
                    child: _isSearching
                        ? TextField(
                            controller: _searchController,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: ProjectTemplateBrowserText.searchHint,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();
                                      },
                                    )
                                  : null,
                            ),
                          )
                        : Text(
                            ProjectTemplateBrowserText.dialogTitle,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                  ),
                  IconButton(
                    icon: Icon(_isSearching ? Icons.close : Icons.search),
                    onPressed: _toggleSearch,
                    tooltip: _isSearching
                        ? ProjectTemplateBrowserText.closeSearchTooltip
                        : ProjectTemplateBrowserText.openSearchTooltip,
                  ),
                  if (!_isSearching)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
            ),

            // Show search results or tabs
            if (_searchQuery.isNotEmpty)
              Expanded(child: _buildSearchResults())
            else ...[
              // Tab bar
              TabBar(
                controller: _tabController,
                labelColor: HeroTheme.primarySection,
                indicatorColor: HeroTheme.primarySection,
                tabs: const [
                  Tab(text: ProjectTemplateBrowserText.tabProjectsLabel),
                  Tab(text: ProjectTemplateBrowserText.tabImbuementsLabel),
                  Tab(text: ProjectTemplateBrowserText.tabTreasuresLabel),
                ],
              ),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildProjectsTab(),
                    _buildImbuementsTab(),
                    _buildTreasuresTab(),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildSearchResults() {
    final projectsAsync = ref.watch(projectTemplatesProvider);
    final imbuementsAsync = ref.watch(imbuementTemplatesProvider);
    final treasuresAsync = ref.watch(craftableTreasuresProvider);
    
    // Check if any are still loading
    if (projectsAsync.isLoading || imbuementsAsync.isLoading || treasuresAsync.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: HeroTheme.primarySection),
      );
    }
    
    // Collect all searchable projects
    final allProjects = <SearchableProject>[];
    
    // Add projects
    if (projectsAsync.hasValue) {
      for (final entry in projectsAsync.value!) {
        allProjects.add(SearchableProject.fromDowntimeEntry(entry, 'project'));
      }
    }
    
    // Add imbuements
    if (imbuementsAsync.hasValue) {
      for (final entry in imbuementsAsync.value!) {
        allProjects.add(SearchableProject.fromDowntimeEntry(entry, 'imbuement'));
      }
    }
    
    // Add treasures
    if (treasuresAsync.hasValue) {
      for (final treasure in treasuresAsync.value!) {
        allProjects.add(SearchableProject.fromCraftableTreasure(treasure));
      }
    }
    
    // Filter by search query
    final filteredProjects = allProjects.where((project) {
      return project.name.toLowerCase().contains(_searchQuery);
    }).toList();
    
    // Sort by name
    filteredProjects.sort((a, b) => a.name.compareTo(b.name));
    
    if (filteredProjects.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'No projects found for "$_searchQuery"',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${filteredProjects.length} results for "$_searchQuery"',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: filteredProjects.length,
              itemBuilder: (context, index) {
                final project = filteredProjects[index];
                return _buildSearchResultCard(context, project);
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSearchResultCard(BuildContext context, SearchableProject project) {
    final theme = Theme.of(context);
    final categoryColor = _getCategoryColor(project.category);
    final categoryIcon = _getCategoryIcon(project.category);
    final categoryLabel = _getCategoryLabel(project.category);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _takeOnSearchableProject(context, ref, project),
        borderRadius: HeroTheme.heroCardRadius,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category badge and name
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: categoryColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(categoryIcon, size: 14, color: categoryColor),
                        const SizedBox(width: 4),
                        Text(
                          categoryLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: categoryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      project.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: HeroTheme.primarySection,
                      ),
                    ),
                  ),
                  if (project.projectGoal != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: HeroTheme.primarySection.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Goal: ${project.projectGoal}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: HeroTheme.primarySection,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              
              if (project.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  project.description,
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              
              const SizedBox(height: 12),
              
              // Take on button
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => _takeOnSearchableProject(context, ref, project),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text(
                    ProjectTemplateBrowserText.takeOnSearchResultButtonLabel,
                  ),
                  style: HeroTheme.primaryActionButtonStyle(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Color _getCategoryColor(String category) {
    switch (category) {
      case 'project':
        return Colors.blue;
      case 'imbuement':
        return Colors.purple;
      case 'treasure':
        return Colors.amber.shade700;
      default:
        return Colors.grey;
    }
  }
  
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'project':
        return Icons.assignment;
      case 'imbuement':
        return Icons.build;
      case 'treasure':
        return Icons.diamond;
      default:
        return Icons.help_outline;
    }
  }
  
  String _getCategoryLabel(String category) {
    switch (category) {
      case 'project':
        return ProjectTemplateBrowserText.categoryProjectLabel;
      case 'imbuement':
        return ProjectTemplateBrowserText.categoryImbuementLabel;
      case 'treasure':
        return ProjectTemplateBrowserText.categoryTreasureLabel;
      default:
        return category;
    }
  }
  
  void _takeOnSearchableProject(
    BuildContext context,
    WidgetRef ref,
    SearchableProject project,
  ) {
    if (project.source is DowntimeEntry) {
      _takeOnProject(context, ref, project.source as DowntimeEntry);
    } else if (project.source is CraftableTreasure) {
      _takeOnTreasureProject(context, ref, project.source as CraftableTreasure);
    }
  }

  Widget _buildProjectsTab() {
    final templatesAsync = ref.watch(projectTemplatesProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ProjectTemplateBrowserText.selectProjectPrompt,
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

  Widget _buildImbuementsTab() {
    final imbuementsAsync = ref.watch(imbuementTemplatesProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ProjectTemplateBrowserText.selectImbuementPrompt,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: imbuementsAsync.when(
              data: (imbuements) => _buildImbuementsGrouped(context, imbuements),
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

  Widget _buildTreasuresTab() {
    final treasuresAsync = ref.watch(craftableTreasuresProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ProjectTemplateBrowserText.selectTreasurePrompt,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: treasuresAsync.when(
              data: (treasures) => _buildTreasuresGrouped(context, treasures),
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

  Widget _buildTreasuresGrouped(
    BuildContext context,
    List<CraftableTreasure> treasures,
  ) {
    if (treasures.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              ProjectTemplateBrowserText.noCraftableTreasuresLabel,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      );
    }

    // Group treasures by type
    final grouped = <String, List<CraftableTreasure>>{};
    
    for (final treasure in treasures) {
      grouped.putIfAbsent(treasure.type, () => <CraftableTreasure>[]);
      grouped[treasure.type]!.add(treasure);
    }

    // Sort by type order
    final typeOrder = ['consumable', 'trinket', 'leveled_treasure'];
    final sortedTypes = grouped.keys.toList()
      ..sort((a, b) {
        final indexA = typeOrder.indexOf(a);
        final indexB = typeOrder.indexOf(b);
        if (indexA == -1 && indexB == -1) return a.compareTo(b);
        if (indexA == -1) return 1;
        if (indexB == -1) return -1;
        return indexA.compareTo(indexB);
      });

    return ListView.builder(
      itemCount: sortedTypes.length,
      itemBuilder: (context, index) {
        final type = sortedTypes[index];
        final items = grouped[type]!;
        
        // Further group by echelon for consumables/trinkets, or by equipment type for leveled
        if (type == 'leveled_treasure') {
          return _buildLeveledTreasuresSection(context, items);
        } else {
          return _buildEchelonTreasuresSection(context, type, items);
        }
      },
    );
  }

  Widget _buildEchelonTreasuresSection(
    BuildContext context,
    String type,
    List<CraftableTreasure> treasures,
  ) {
    // Group by echelon
    final byEchelon = <int, List<CraftableTreasure>>{};
    for (final treasure in treasures) {
      final echelon = treasure.echelon ?? 0;
      byEchelon.putIfAbsent(echelon, () => <CraftableTreasure>[]);
      byEchelon[echelon]!.add(treasure);
    }
    
    final sortedEchelons = byEchelon.keys.toList()..sort();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        backgroundColor: _getTreasureTypeColor(type).withValues(alpha: 0.05),
        collapsedBackgroundColor: _getTreasureTypeColor(type).withValues(alpha: 0.1),
        leading: Icon(
          _getTreasureTypeIcon(type),
          color: _getTreasureTypeColor(type),
          size: 20,
        ),
        title: Text(
          _getTreasureTypeName(type),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: _getTreasureTypeColor(type),
              ),
        ),
        subtitle: Text(
          '${treasures.length} items',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        children: sortedEchelons.map((echelon) {
          final items = byEchelon[echelon]!;
          
          return ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 8),
            title: Text(
              _getEchelonName(echelon),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            trailing: Text('${items.length}', style: Theme.of(context).textTheme.bodySmall),
            children: items.map((treasure) => _buildTreasureCard(context, treasure)).toList(),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLeveledTreasuresSection(
    BuildContext context,
    List<CraftableTreasure> treasures,
  ) {
    // Group by equipment type
    final byEquipType = <String, List<CraftableTreasure>>{};
    for (final treasure in treasures) {
      final equipType = treasure.leveledType ?? 'other';
      byEquipType.putIfAbsent(equipType, () => <CraftableTreasure>[]);
      byEquipType[equipType]!.add(treasure);
    }
    
    final typeOrder = ['armor', 'shield', 'weapon', 'implement', 'other'];
    final sortedTypes = byEquipType.keys.toList()
      ..sort((a, b) {
        final indexA = typeOrder.indexOf(a);
        final indexB = typeOrder.indexOf(b);
        if (indexA == -1 && indexB == -1) return a.compareTo(b);
        if (indexA == -1) return 1;
        if (indexB == -1) return -1;
        return indexA.compareTo(indexB);
      });
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        backgroundColor: Colors.deepPurple.withValues(alpha: 0.05),
        collapsedBackgroundColor: Colors.deepPurple.withValues(alpha: 0.1),
        leading: const Icon(
          Icons.shield,
          color: Colors.deepPurple,
          size: 20,
        ),
        title: Text(
          ProjectTemplateBrowserText.leveledTreasuresHeader,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
        ),
        subtitle: Text(
          '${treasures.length} items',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        children: sortedTypes.map((equipType) {
          final items = byEquipType[equipType]!;
          
          return ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 8),
            title: Text(
              _getEquipmentTypeName(equipType),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            trailing: Text('${items.length}', style: Theme.of(context).textTheme.bodySmall),
            children: items.map((treasure) => _buildTreasureCard(context, treasure)).toList(),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTreasureCard(BuildContext context, CraftableTreasure treasure) {
    final theme = Theme.of(context);
    final typeColor = _getTreasureTypeColor(treasure.type);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _takeOnTreasureProject(context, ref, treasure),
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
                      treasure.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: typeColor,
                      ),
                    ),
                  ),
                  if (treasure.projectGoal != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Goal: ${treasure.projectGoal}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: typeColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),

              // Keywords
              if (treasure.keywords.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: treasure.keywords.map((keyword) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        keyword,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: typeColor,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 8),

              // Description
              if (treasure.description.isNotEmpty) ...[
                Text(
                  treasure.description,
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
              ],

              // Prerequisites
              if (treasure.itemPrerequisite != null && treasure.itemPrerequisite!.isNotEmpty) ...[
                _buildSection(
                  context,
                  ProjectTemplateBrowserText.prerequisitesLabel,
                  [treasure.itemPrerequisite!],
                  Icons.inventory_2_outlined,
                ),
                const SizedBox(height: 8),
              ],

              // Roll characteristics
              if (treasure.projectRollCharacteristics.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  children: [
                    const Icon(Icons.casino_outlined, size: 16, color: Colors.grey),
                    Text(
                      'Roll: ${treasure.projectRollCharacteristics.join(', ')}',
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
                  onPressed: () => _takeOnTreasureProject(context, ref, treasure),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text(
                    ProjectTemplateBrowserText.takeOnTreasureButtonLabel,
                  ),
                  style: HeroTheme.primaryActionButtonStyle(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTreasureTypeColor(String type) {
    switch (type) {
      case 'consumable':
        return Colors.teal;
      case 'trinket':
        return Colors.amber.shade700;
      case 'leveled_treasure':
        return Colors.deepPurple;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _getTreasureTypeIcon(String type) {
    switch (type) {
      case 'consumable':
        return Icons.local_drink;
      case 'trinket':
        return Icons.auto_awesome;
      case 'leveled_treasure':
        return Icons.shield;
      default:
        return Icons.diamond;
    }
  }

  String _getTreasureTypeName(String type) {
    switch (type) {
      case 'consumable':
        return ProjectTemplateBrowserText.treasureTypeConsumablesLabel;
      case 'trinket':
        return ProjectTemplateBrowserText.treasureTypeTrinketsLabel;
      case 'leveled_treasure':
        return ProjectTemplateBrowserText.treasureTypeLeveledLabel;
      default:
        return type;
    }
  }

  String _getEchelonName(int echelon) {
    switch (echelon) {
      case 0:
        return ProjectTemplateBrowserText.echelonNoneLabel;
      case 1:
        return ProjectTemplateBrowserText.echelon1Label;
      case 2:
        return ProjectTemplateBrowserText.echelon2Label;
      case 3:
        return ProjectTemplateBrowserText.echelon3Label;
      case 4:
        return ProjectTemplateBrowserText.echelon4Label;
      default:
        return '${echelon}th Echelon';
    }
  }

  String _getEquipmentTypeName(String equipType) {
    switch (equipType) {
      case 'armor':
        return ProjectTemplateBrowserText.equipmentArmorLabel;
      case 'weapon':
        return ProjectTemplateBrowserText.equipmentWeaponsLabel;
      case 'implement':
        return ProjectTemplateBrowserText.equipmentImplementsLabel;
      case 'shield':
        return ProjectTemplateBrowserText.equipmentShieldsLabel;
      default:
        return equipType
            .split('_')
            .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '')
            .join(' ');
    }
  }

  void _takeOnTreasureProject(
    BuildContext context,
    WidgetRef ref,
    CraftableTreasure treasure,
  ) async {
    try {
      final repo = ref.read(downtimeRepositoryProvider);
      await repo.createProject(
        heroId: widget.heroId,
        templateProjectId: treasure.id,
        name: treasure.name,
        description: treasure.description,
        projectGoal: treasure.projectGoal ?? 100,
        prerequisites: treasure.itemPrerequisite != null ? [treasure.itemPrerequisite!] : [],
        projectSource: treasure.projectSource,
        sourceLanguage: null,
        guides: [],
        rollCharacteristics: treasure.projectRollCharacteristics,
        isCustom: false,
      );

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${treasure.name}" crafting project'),
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

  Widget _buildImbuementsGrouped(
    BuildContext context,
    List<DowntimeEntry> imbuements,
  ) {
    if (imbuements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              ProjectTemplateBrowserText.noImbuementsLabel,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      );
    }

    // Group imbuements by level and type
    final grouped = <int, Map<String, List<DowntimeEntry>>>{};
    
    for (final imbuement in imbuements) {
      final level = imbuement.raw['level'] as int? ?? 1;
      final type = imbuement.raw['type'] as String? ?? 'unknown';
      
      grouped.putIfAbsent(level, () => <String, List<DowntimeEntry>>{});
      grouped[level]!.putIfAbsent(type, () => <DowntimeEntry>[]);
      grouped[level]![type]!.add(imbuement);
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
            leading: const Icon(
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
                  _getImbuementTypeName(type),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                children: items.map((imbuement) => _buildTemplateCard(context, imbuement)).toList(),
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
        return ProjectTemplateBrowserText.levelImbuements1Label;
      case 5:
        return ProjectTemplateBrowserText.levelImbuements5Label;
      case 9:
        return ProjectTemplateBrowserText.levelImbuements9Label;
      default:
        return '${level}th Level Imbuements';
    }
  }

  String _getImbuementTypeName(String type) {
    switch (type) {
      case 'armor_imbuement':
        return ProjectTemplateBrowserText.imbuementTypeArmorLabel;
      case 'weapon_imbuement':
        return ProjectTemplateBrowserText.imbuementTypeWeaponLabel;
      case 'implement_imbuement':
        return ProjectTemplateBrowserText.imbuementTypeImplementLabel;
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
            ProjectTemplateBrowserText.failedToLoadTemplatesLabel,
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
              ProjectTemplateBrowserText.noTemplatesFoundLabel,
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
                  ProjectTemplateBrowserText.itemPrerequisitesLabel,
                  itemPrereqs.map((p) => p['name'] as String? ?? '').toList(),
                  Icons.inventory_2_outlined,
                ),
                const SizedBox(height: 8),
              ],

              // Sources
              if (sourcePrereqs.isNotEmpty) ...[
                _buildSection(
                  context,
                  ProjectTemplateBrowserText.sourcesLabel,
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
                  label: const Text(
                    ProjectTemplateBrowserText.takeOnTemplateButtonLabel,
                  ),
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
    
    // Handle project_goal which might be stored as String or int in JSON
    final projectGoalRaw = template.raw['project_goal'];
    int projectGoal;
    if (projectGoalRaw is int) {
      projectGoal = projectGoalRaw;
    } else if (projectGoalRaw is String) {
      projectGoal = int.tryParse(projectGoalRaw) ?? 100; // Default to 100 for "Varies" etc.
    } else {
      projectGoal = 100;
    }
    
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
