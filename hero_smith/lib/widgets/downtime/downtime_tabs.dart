import 'package:flutter/material.dart';
import '../../core/theme/app_icons.dart';
import '../../core/models/downtime.dart';
import '../../core/data/downtime_data_source.dart';
import '../shared/expandable_card.dart';

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

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sortedCategories.length,
          itemBuilder: (context, categoryIndex) {
            final category = sortedCategories[categoryIndex];
            final projectsInCategory = groupedProjects[category]!;

            return _ProjectDifficultySection(
              category: category,
              projects: projectsInCategory,
              getProjectCardColor: _getProjectCardColor,
              getDifficultyTitle: _getDifficultyTitle,
              dataSource: _ds,
            );
          },
        );
      },
    );
  }
}

class _ProjectDifficultySection extends StatelessWidget {
  final int category;
  final List<DowntimeEntry> projects;
  final Color Function(DowntimeEntry) getProjectCardColor;
  final String Function(int) getDifficultyTitle;
  final DowntimeDataSource dataSource;

  const _ProjectDifficultySection({
    required this.category,
    required this.projects,
    required this.getProjectCardColor,
    required this.getDifficultyTitle,
    required this.dataSource,
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Card(
        elevation: 3,
        child: ExpandableCard(
          title: getDifficultyTitle(category),
          borderColor: _getCategoryColor(category),
          expandedContent: _ProjectCategoryContent(
            projects: projects,
            getProjectCardColor: getProjectCardColor,
            dataSource: dataSource,
          ),
        ),
      ),
    );
  }
}

class _ProjectCategoryContent extends StatelessWidget {
  final List<DowntimeEntry> projects;
  final Color Function(DowntimeEntry) getProjectCardColor;
  final DowntimeDataSource dataSource;

  const _ProjectCategoryContent({
    required this.projects,
    required this.getProjectCardColor,
    required this.dataSource,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  AppIcons.projects,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${projects.length} projects in this category',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...projects.map((entry) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Card(
                  elevation: 4,
                  shadowColor:
                      getProjectCardColor(entry).withValues(alpha: 0.3),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          getProjectCardColor(entry).withValues(alpha: 0.05),
                          getProjectCardColor(entry).withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                    child: ExpandableCard(
                      title: entry.name,
                      borderColor: getProjectCardColor(entry),
                      expandedContent: _EntryDetails(entry: entry),
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class EnhancementsTab extends StatefulWidget {
  const EnhancementsTab({super.key});

  @override
  State<EnhancementsTab> createState() => _EnhancementsTabState();
}

class _EntryDetails extends StatelessWidget {
  final DowntimeEntry entry;
  const _EntryDetails({required this.entry});

  @override
  Widget build(BuildContext context) {
    final desc = (entry.raw['description'] ?? '').toString();
    final projectGoal = entry.raw['project_goal'];
    final prerequisites = entry.raw['prerequisites'] as Map<String, dynamic>?;
    final rollCharacteristics =
        entry.raw['project_roll_characteristic'] as List<dynamic>?;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (desc.isNotEmpty) ...[
            Text(
              desc,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 16),
          ],
          // Project info section
          if (projectGoal != null ||
              (rollCharacteristics != null &&
                  rollCharacteristics.isNotEmpty)) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (projectGoal != null)
                  _InfoChip(
                    icon: Icons.flag,
                    label: 'Project Goal',
                    value: projectGoal.toString(),
                    color: _getProjectGoalColor(projectGoal),
                  ),
                _InfoChip(
                  icon: Icons.event_note,
                  label: 'Events',
                  value: _getEventTableName(entry.name),
                  color: Theme.of(context).colorScheme.secondary,
                ),
                _InfoChip(
                  icon: Icons.timeline,
                  label: 'Milestones',
                  value: _suggestedMilestoneLabel(projectGoal),
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ],
            ),
            if (rollCharacteristics != null &&
                rollCharacteristics.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Roll Characteristics',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: rollCharacteristics.map((char) {
                  final charName = char['name']?.toString() ?? char.toString();
                  return _CharacteristicChip(
                    characteristic: charName,
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 16),
          ],
          if (prerequisites != null && prerequisites.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.checklist,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Prerequisites',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._buildPrerequisites(context, prerequisites),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildPrerequisites(
      BuildContext context, Map<String, dynamic> prerequisites) {
    final widgets = <Widget>[];

    prerequisites.forEach((key, value) {
      if (value is List && value.isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  key
                      .replaceAll('_', ' ')
                      .split(' ')
                      .map((word) => word.isNotEmpty
                          ? word[0].toUpperCase() + word.substring(1)
                          : '')
                      .join(' '),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 4),
                ...value.map((item) => Container(
                      margin: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item['name']?.toString() ?? item.toString(),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    height: 1.2,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        );
      }
    });

    return widgets;
  }

  Color _getProjectGoalColor(dynamic projectGoal) {
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
    return Colors.grey;
  }

  String _suggestedMilestoneLabel(dynamic projectGoal) {
    final goal = int.tryParse(projectGoal?.toString() ?? '') ?? 0;
    if (goal <= 0) return 'None';
    if (goal <= 30) return 'None';
    if (goal <= 200) return '1 at halfway';
    if (goal <= 999) return '2 at 1/3 and 2/3';
    return '3 at 1/4, 1/2, 3/4';
  }

  String _getEventTableName(String entryName) {
    // Map specific project names to their event table names
    final eventMappings = {
      'Build Airship': 'Crafting and Research Events',
      'Build or Repair Road': 'Build or Repair Roads Events',
      'Community Service': 'Community Service Events',
      'Fishing': 'Fishing Events',
      'Spend Time With Loved Ones': 'Spend Time With Loved Ones Events',
      'Learn From a Master: Hone Ability': 'Learn From a Master Events',
      'Learn From a Master: Improve Control': 'Learn From a Master Events',
      'Learn From a Master: Acquire Ability': 'Learn From a Master Events',
    };

    // Check for direct mapping first
    if (eventMappings.containsKey(entryName)) {
      return eventMappings[entryName]!;
    }

    // Check for "Learn From a Master" prefix
    if (entryName.startsWith('Learn From a Master')) {
      return 'Learn From a Master Events';
    }

    // Check for career-related projects (Home Career Skills pattern)
    if (entryName.contains('Career') || entryName.contains('Work')) {
      return 'Home Career Skills Events';
    }

    // Default to Crafting and Research for most other projects
    return 'Crafting and Research Events';
  }
}

class _CharacteristicChip extends StatelessWidget {
  final String characteristic;

  const _CharacteristicChip({
    required this.characteristic,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getCharacteristicColor(characteristic).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getCharacteristicColor(characteristic).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getCharacteristicIcon(characteristic),
            size: 14,
            color: _getCharacteristicColor(characteristic),
          ),
          const SizedBox(width: 4),
          Text(
            characteristic,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _getCharacteristicColor(characteristic),
                ),
          ),
        ],
      ),
    );
  }

  Color _getCharacteristicColor(String characteristic) {
    switch (characteristic.toLowerCase()) {
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
      default:
        return Colors.grey;
    }
  }

  IconData _getCharacteristicIcon(String characteristic) {
    switch (characteristic.toLowerCase()) {
      case 'might':
        return Icons.fitness_center;
      case 'agility':
        return Icons.directions_run;
      case 'reason':
        return Icons.psychology;
      case 'intuition':
        return Icons.lightbulb;
      case 'presence':
        return Icons.person;
      default:
        return Icons.casino;
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: IntrinsicWidth(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              '$label: ',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
            ),
            Flexible(
              child: Text(
                value,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
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

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: enhancementsByEchelon.length,
          itemBuilder: (context, echelonIndex) {
            final echelonLevel =
                enhancementsByEchelon.keys.toList()[echelonIndex];
            final enhancementsByType = enhancementsByEchelon[echelonLevel]!;

            return _EchelonSection(
              echelonLevel: echelonLevel,
              enhancementsByType: enhancementsByType,
              dataSource: _ds,
            );
          },
        );
      },
    );
  }
}

class _EchelonSection extends StatelessWidget {
  final int echelonLevel;
  final Map<String, List<DowntimeEntry>> enhancementsByType;
  final DowntimeDataSource dataSource;

  const _EchelonSection({
    required this.echelonLevel,
    required this.enhancementsByType,
    required this.dataSource,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Card(
        elevation: 3,
        child: ExpandableCard(
          title: dataSource.getLevelName(echelonLevel),
          borderColor: _getEchelonColor(context, echelonLevel),
          expandedContent: _EchelonContent(
            enhancementsByType: enhancementsByType,
            dataSource: dataSource,
            echelonLevel: echelonLevel,
          ),
        ),
      ),
    );
  }

  Color _getEchelonColor(BuildContext context, int level) {
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
        return Colors.red;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }
}

class _EchelonContent extends StatelessWidget {
  final Map<String, List<DowntimeEntry>> enhancementsByType;
  final DowntimeDataSource dataSource;
  final int echelonLevel;

  const _EchelonContent({
    required this.enhancementsByType,
    required this.dataSource,
    required this.echelonLevel,
  });

  @override
  Widget build(BuildContext context) {
    final sortedTypes = enhancementsByType.keys.toList()..sort();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EchelonSummary(
            echelonLevel: echelonLevel,
            enhancementsByType: enhancementsByType,
          ),
          const SizedBox(height: 16),
          ...sortedTypes.map((type) => _TypeSection(
                type: type,
                enhancements: enhancementsByType[type]!,
                dataSource: dataSource,
              )),
        ],
      ),
    );
  }
}

class _EchelonSummary extends StatelessWidget {
  final int echelonLevel;
  final Map<String, List<DowntimeEntry>> enhancementsByType;

  const _EchelonSummary({
    required this.echelonLevel,
    required this.enhancementsByType,
  });

  @override
  Widget build(BuildContext context) {
    final totalCount =
        enhancementsByType.values.fold(0, (sum, list) => sum + list.length);
    final typeCount = enhancementsByType.length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            AppIcons.enhancements,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$totalCount enhancements across $typeCount categories',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeSection extends StatelessWidget {
  final String type;
  final List<DowntimeEntry> enhancements;
  final DowntimeDataSource dataSource;

  const _TypeSection({
    required this.type,
    required this.enhancements,
    required this.dataSource,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: ExpandableCard(
          title:
              '${dataSource.getEnhancementTypeName(type)} (${enhancements.length})',
          borderColor: _getTypeColor(type),
          expandedContent: _TypeContent(
            enhancements: enhancements,
            dataSource: dataSource,
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'armor_enhancement':
        return Colors.indigo;
      case 'weapon_enhancement':
        return Colors.deepOrange;
      case 'implement_enhancement':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}

class _TypeContent extends StatelessWidget {
  final List<DowntimeEntry> enhancements;
  final DowntimeDataSource dataSource;

  const _TypeContent({
    required this.enhancements,
    required this.dataSource,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: enhancements
            .map((enhancement) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ExpandableCard(
                      title: enhancement.name.replaceAll(
                          ' - ${dataSource.getLevelName((enhancement.raw['level'] as int? ?? 1))}-Level ${dataSource.getEnhancementTypeName(enhancement.type).replaceAll('s', '')}',
                          ''),
                      borderColor: Theme.of(context).colorScheme.outline,
                      expandedContent: _EntryDetails(entry: enhancement),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class DowntimeTabsScaffold extends StatelessWidget {
  const DowntimeTabsScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Downtime'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(AppIcons.projects), text: 'Projects'),
              Tab(icon: Icon(AppIcons.enhancements), text: 'Item Enhancements'),
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
            _MilestoneRow(
              color: Colors.teal,
              range: '30 or fewer points',
              suggestion: 'None',
            ),
            _MilestoneRow(
              color: Colors.blue,
              range: '31–200 points',
              suggestion: 'One at halfway',
            ),
            _MilestoneRow(
              color: Colors.indigo,
              range: '201–999 points',
              suggestion: 'Two at 1/3 and 2/3',
            ),
            _MilestoneRow(
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine how many columns based on available width
        int crossAxisCount = 1;
        if (constraints.maxWidth > 800) {
          crossAxisCount = 3;
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 2;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 2.5,
            crossAxisSpacing: 16,
            mainAxisSpacing: 12,
          ),
          itemCount: eventTables.length,
          itemBuilder: (context, index) {
            final table = eventTables[index];
            return _EventTableCard(table: table);
          },
        );
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
