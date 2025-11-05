import 'package:flutter/material.dart';
import '../../core/theme/app_icons.dart';
import '../../core/models/downtime.dart';
import '../../core/data/downtime_data_source.dart';
import '../shared/expandable_card.dart';
import '../../features/downtime/project_category_detail_page.dart';
import '../../features/downtime/enhancement_echelon_detail_page.dart';

class ProjectsTab extends StatefulWidget {
  const ProjectsTab({super.key});

  @override
  State<ProjectsTab> createState() => _ProjectsTabState();
}

class _ProjectsTabState extends State<ProjectsTab> {
  final _ds = DowntimeDataSource();

  Color _getProjectCardColor(DowntimeEntry entry) {
    final projectGoal = entry.raw['project_goal'];
    final rollCharacteristics =
        entry.raw['project_roll_characteristic'] as List<dynamic>?;

    // Color based on project complexity and characteristics
    if (projectGoal != null) {
      final goal = int.tryParse(projectGoal.toString()) ?? 0;
      if (goal >= 1000) {
        return Colors.deepPurple; // Epic projects (1000+)
      } else if (goal >= 201) {
        return Colors.indigo; // Major projects (201-999)
      } else if (goal >= 21) {
        return Colors.blue; // Medium projects (21-200)
      } else if (goal > 0) {
        return Colors.teal; // Small projects (<30)
      }
    }

    // Color based on primary characteristic if no goal
    if (rollCharacteristics != null && rollCharacteristics.isNotEmpty) {
      final primaryChar =
          rollCharacteristics.first['name']?.toString().toLowerCase();
      switch (primaryChar) {
        case 'might':
          return Colors.red;
        case 'agility':
          return Colors.green;
        case 'reason':
          return Colors.blue;
        case 'intuition':
          return Colors.purple;
        case 'presence':
          return Colors.orange;
      }
    }

    // Default color for projects without clear categorization
    return Colors.blueGrey;
  }

  int _getProjectDifficultyCategory(DowntimeEntry entry) {
    final projectGoal = entry.raw['project_goal'];
    if (projectGoal != null) {
      final goal = int.tryParse(projectGoal.toString()) ?? 0;
      if (goal >= 1000) {
        return 4; // Epic (1000+)
      } else if (goal >= 201) {
        return 3; // Major (201-999)
      } else if (goal >= 21) {
        return 2; // Medium (21-200)
      } else if (goal > 0) {
        return 1; // Small (<30)
      }
    }
    return 0; // Unknown/no goal
  }

  String _getDifficultyTitle(int category) {
    switch (category) {
      case 4:
        return 'Epic Projects (1000+ points)';
      case 3:
        return 'Major Projects (201-999 points)';
      case 2:
        return 'Medium Projects (21-200 points)';
      case 1:
        return 'Small Projects (<30 points)';
      default:
        return 'Other Projects';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DowntimeEntry>>(
      future: _ds.loadProjects(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? const [];
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AppIcons.projects,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No downtime projects found',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          );
        }

        // Group projects by difficulty categories
        final groupedProjects = <int, List<DowntimeEntry>>{};
        for (final entry in items) {
          final category = _getProjectDifficultyCategory(entry);
          groupedProjects.putIfAbsent(category, () => <DowntimeEntry>[]);
          groupedProjects[category]!.add(entry);
        }

        // Sort categories in descending order (Epic -> Small -> Other)
        final sortedCategories = groupedProjects.keys.toList()
          ..sort((a, b) => b.compareTo(a));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose a project category:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Column(
                children: sortedCategories.map((category) {
                  final projectsInCategory = groupedProjects[category]!;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ProjectCategoryCard(
                      category: category,
                      projects: projectsInCategory,
                      getProjectCardColor: _getProjectCardColor,
                      getDifficultyTitle: _getDifficultyTitle,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProjectCategoryCard extends StatelessWidget {
  final int category;
  final List<DowntimeEntry> projects;
  final Color Function(DowntimeEntry) getProjectCardColor;
  final String Function(int) getDifficultyTitle;

  const _ProjectCategoryCard({
    required this.category,
    required this.projects,
    required this.getProjectCardColor,
    required this.getDifficultyTitle,
  });

  Color _getCategoryColor(int category) {
    switch (category) {
      case 4:
        return Colors.deepPurple; // Epic
      case 3:
        return Colors.indigo; // Major
      case 2:
        return Colors.blue; // Medium
      case 1:
        return Colors.teal; // Small
      default:
        return Colors.blueGrey; // Other
    }
  }

  String _getCategoryDescription(int category) {
    switch (category) {
      case 4:
        return 'Legendary endeavors requiring massive commitment and resources';
      case 3:
        return 'Significant undertakings for experienced adventurers';
      case 2:
        return 'Moderate projects suitable for most heroes';
      case 1:
        return 'Quick projects that can be completed efficiently';
      default:
        return 'Miscellaneous projects with unique requirements';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getCategoryColor(category),
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ProjectCategoryDetailPage(
                category: category,
                projects: projects,
                getProjectCardColor: getProjectCardColor,
                getDifficultyTitle: getDifficultyTitle,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getCategoryColor(category).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getCategoryIcon(category),
                  color: _getCategoryColor(category),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      getDifficultyTitle(category),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getCategoryDescription(category),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${projects.length} projects available',
                      style: TextStyle(
                        fontSize: 12,
                        color: _getCategoryColor(category),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(int category) {
    switch (category) {
      case 4:
        return Icons.stars; // Epic
      case 3:
        return Icons.assignment_ind; // Major
      case 2:
        return Icons.assignment; // Medium
      case 1:
        return Icons.assignment_outlined; // Small
      default:
        return Icons.help_outline; // Other
    }
  }
}



class EnhancementsTab extends StatefulWidget {
  const EnhancementsTab({super.key});

  @override
  State<EnhancementsTab> createState() => _EnhancementsTabState();
}

class _EnhancementsTabState extends State<EnhancementsTab> {
  final _ds = DowntimeDataSource();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<int, Map<String, List<DowntimeEntry>>>>(
      future: _ds.loadEnhancementsByLevelAndType(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        final enhancementsByEchelon =
            snap.data ?? <int, Map<String, List<DowntimeEntry>>>{};
        if (enhancementsByEchelon.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AppIcons.enhancements,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No item enhancements found',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          );
        }

        final sortedEchelons = enhancementsByEchelon.keys.toList()..sort();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Item Enhancements by Echelon',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose an echelon level to view available item enhancements',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              ...sortedEchelons.map((echelonLevel) {
                final enhancementsByType = enhancementsByEchelon[echelonLevel]!;
                return _EchelonNavigationCard(
                  echelonLevel: echelonLevel,
                  enhancementsByType: enhancementsByType,
                  dataSource: _ds,
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _EchelonNavigationCard extends StatelessWidget {
  final int echelonLevel;
  final Map<String, List<DowntimeEntry>> enhancementsByType;
  final DowntimeDataSource dataSource;

  const _EchelonNavigationCard({
    required this.echelonLevel,
    required this.enhancementsByType,
    required this.dataSource,
  });

  Color _getEchelonColor(int level) {
    switch (level) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.purple;
      case 4:
        return Colors.orange;
      case 5:
        return Colors.blue; // Changed from red to blue as requested
      case 9:
        return Colors.purple; // Added purple for level 9
      default:
        return Colors.grey;
    }
  }

  String _getEchelonDescription(int level) {
    switch (level) {
      case 1:
        return 'Basic enhancements for starting adventurers';
      case 2:
        return 'Improved enhancements for developing heroes';
      case 3:
        return 'Advanced enhancements for experienced adventurers';
      case 4:
        return 'Superior enhancements for veteran heroes';
      case 5:
        return 'Legendary enhancements for master adventurers';
      case 9:
        return 'Mythical enhancements of extraordinary power';
      default:
        return 'Specialized item enhancements';
    }
  }

  IconData _getEchelonIcon(int level) {
    switch (level) {
      case 1:
        return Icons.star_half;
      case 2:
        return Icons.auto_fix_high;
      case 3:
        return Icons.auto_awesome;
      case 4:
        return Icons.stars;
      case 5:
        return Icons.diamond;
      case 9:
        return Icons.flare;
      default:
        return Icons.auto_fix_high;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = enhancementsByType.values.fold(0, (sum, list) => sum + list.length);
    final typeCount = enhancementsByType.length;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getEchelonColor(echelonLevel).withOpacity(0.3),
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => EnhancementEchelonDetailPage(
                echelonLevel: echelonLevel,
                enhancementsByType: enhancementsByType,
                dataSource: dataSource,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getEchelonColor(echelonLevel).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  _getEchelonIcon(echelonLevel),
                  color: _getEchelonColor(echelonLevel),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dataSource.getLevelName(echelonLevel),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _getEchelonColor(echelonLevel),
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getEchelonDescription(echelonLevel),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$totalCount enhancements',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.category,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$typeCount types',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: _getEchelonColor(echelonLevel),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DowntimeTabsScaffold extends StatelessWidget {
  const DowntimeTabsScaffold({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Downtime'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(AppIcons.projects), text: 'Projects'),
              Tab(icon: Icon(AppIcons.enhancements), text: 'Enhancements'),
              Tab(icon: Icon(Icons.event_note), text: 'Events'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ProjectsTab(),
            EnhancementsTab(),
            EventsTab(),
          ],
        ),
      ),
    );
  }
}

class EventsTab extends StatefulWidget {
  const EventsTab({super.key});

  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
  final _ds = DowntimeDataSource();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EventTable>>(
      future: _ds.loadEventTables(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final eventTables = snap.data ?? const [];
        if (eventTables.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text('No event tables found'),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // First section: Suggested Milestones
              _SuggestedMilestonesCard(),
              const SizedBox(height: 24),

              // Second section: Event Tables
              Text(
                'Event Tables',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              _EventTablesGrid(eventTables: eventTables),
            ],
          ),
        );
      },
    );
  }
}

class _SuggestedMilestonesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_available, color: cs.primary),
                const SizedBox(width: 8),
                Text('Suggested Event Milestones',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            const _MilestoneRow(
              color: Colors.teal,
              range: '30 or fewer points',
              suggestion: 'None',
            ),
            const _MilestoneRow(
              color: Colors.blue,
              range: '31–200 points',
              suggestion: 'One at halfway',
            ),
            const _MilestoneRow(
              color: Colors.indigo,
              range: '201–999 points',
              suggestion: 'Two at 1/3 and 2/3',
            ),
            const _MilestoneRow(
              color: Colors.deepPurple,
              range: '1,000+ points',
              suggestion: 'Three at 1/4, 1/2, 3/4',
            ),
          ],
        ),
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  final Color color;
  final String range;
  final String suggestion;

  const _MilestoneRow({
    required this.color,
    required this.range,
    required this.suggestion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(range,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
          Text(suggestion, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _EventTablesGrid extends StatelessWidget {
  final List<EventTable> eventTables;

  const _EventTablesGrid({required this.eventTables});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: eventTables.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final table = eventTables[index];
        return _EventTableCard(table: table);
      },
    );
  }
}

class _EventTableCard extends StatelessWidget {
  final EventTable table;

  const _EventTableCard({required this.table});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _navigateToEventTable(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Icon and title section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.table_chart,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            table.name.replaceAll(' Events', ''),
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Event count
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${table.events.length} events',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              // Action button
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToEventTable(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _EventTableDetailPage(table: table),
      ),
    );
  }
}

class _EventTableDetailPage extends StatelessWidget {
  final EventTable table;

  const _EventTableDetailPage({required this.table});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(table.name),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Table header with info
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.table_chart,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          table.name,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${table.events.length} events available',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Events as expandable cards
          ...table.events.map((event) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ExpandableCard(
                    title: 'Roll ${event.diceValue}',
                    borderColor: Theme.of(context).colorScheme.primary,
                    expandedContent: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        event.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              height: 1.4,
                            ),
                      ),
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
