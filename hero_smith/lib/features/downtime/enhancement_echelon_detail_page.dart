import 'package:flutter/material.dart';
import '../../core/models/downtime.dart';
import '../../core/data/downtime_data_source.dart';
import '../../widgets/shared/expandable_card.dart';

class EnhancementEchelonDetailPage extends StatelessWidget {
  final int echelonLevel;
  final Map<String, List<DowntimeEntry>> enhancementsByType;
  final DowntimeDataSource dataSource;

  const EnhancementEchelonDetailPage({
    super.key,
    required this.echelonLevel,
    required this.enhancementsByType,
    required this.dataSource,
  });

  Color _getEchelonColor(int level) {
    switch (level) {
      case 1:
        return Colors.green;
      case 5:
        return Colors.blue;
      case 9:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedTypes = enhancementsByType.keys.toList()..sort();
    final totalCount = enhancementsByType.values.fold(0, (sum, list) => sum + list.length);

    return DefaultTabController(
      length: sortedTypes.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(dataSource.getLevelName(echelonLevel)),
          backgroundColor: _getEchelonColor(echelonLevel).withOpacity(0.1),
          bottom: TabBar(
            tabs: sortedTypes.map((type) {
              return Tab(
                icon: Icon(_getTypeIcon(type)),
                text: _getShortTypeName(type),
              );
            }).toList(),
          ),
        ),
        body: Padding(
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
                      .withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_fix_high,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$totalCount enhancements across ${enhancementsByType.length} categories',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  children: sortedTypes.map((type) {
                    final enhancements = enhancementsByType[type]!;
                    return _EnhancementTypeTab(
                      type: type,
                      enhancements: enhancements,
                      dataSource: dataSource,
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'armor_enhancement':
        return Icons.shield;
      case 'weapon_enhancement':
        return Icons.gavel;
      case 'implement_enhancement':
        return Icons.auto_fix_high;
      default:
        return Icons.build;
    }
  }

  String _getShortTypeName(String type) {
    switch (type) {
      case 'armor_enhancement':
        return 'Armor';
      case 'weapon_enhancement':
        return 'Weapon';
      case 'implement_enhancement':
        return 'Implement';
      default:
        return type.replaceAll('_enhancement', '').toUpperCase();
    }
  }
}

class _EnhancementTypeTab extends StatelessWidget {
  final String type;
  final List<DowntimeEntry> enhancements;
  final DowntimeDataSource dataSource;

  const _EnhancementTypeTab({
    required this.type,
    required this.enhancements,
    required this.dataSource,
  });

  Color _getTypeColor(String type) {
    switch (type) {
      case 'armor_enhancement':
        return Colors.indigo; // Blue
      case 'weapon_enhancement':
        return Colors.deepOrange; // Reddish
      case 'implement_enhancement':
        return Colors.teal; // Greenish
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _getTypeColor(type).withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: enhancements.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final enhancement = enhancements[index];
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: _getTypeColor(type).withOpacity(0.3),
                width: 2,
              ),
            ),
            child: ExpandableCard(
              title: enhancement.name.replaceAll(
                  ' - ${dataSource.getLevelName((enhancement.raw['level'] as int? ?? 1))}-Level ${dataSource.getEnhancementTypeName(enhancement.type).replaceAll('s', '')}',
                  ''),
              borderColor: _getTypeColor(type),
              expandedContent: _EntryDetails(entry: enhancement),
            ),
          );
        },
      ),
    );
  }
}

class _EntryDetails extends StatelessWidget {
  final DowntimeEntry entry;
  const _EntryDetails({required this.entry});

  @override
  Widget build(BuildContext context) {
    final desc = (entry.raw['description'] ?? '').toString();
    final enhancement = entry.raw['enhancement']?.toString() ?? '';
    final cost = entry.raw['cost']?.toString() ?? '';
    final projectGoal = entry.raw['project_goal'];
    final prerequisites = entry.raw['prerequisites'] as Map<String, dynamic>?;
    final rollCharacteristics = entry.raw['project_roll_characteristic'] as List<dynamic>?;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (desc.isNotEmpty) ...[
            Text(
              desc,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
          ],
          
          if (enhancement.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enhancement Effect',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    enhancement,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Project details section
          if (projectGoal != null || rollCharacteristics != null || cost.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Project Details',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (projectGoal != null)
                        _InfoChip(
                          icon: Icons.flag,
                          label: 'Goal',
                          value: '$projectGoal points',
                          color: _getProjectGoalColor(projectGoal),
                        ),
                      if (cost.isNotEmpty)
                        _InfoChip(
                          icon: Icons.monetization_on,
                          label: 'Cost',
                          value: cost,
                          color: Colors.amber,
                        ),
                    ],
                  ),
                  
                  if (rollCharacteristics != null && rollCharacteristics.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Roll Characteristics:',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: rollCharacteristics.map((char) {
                        final charName = char['name']?.toString() ?? '';
                        return _CharacteristicChip(characteristic: charName);
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Prerequisites section
          if (prerequisites != null && prerequisites.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.checklist,
                        color: Theme.of(context).colorScheme.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Prerequisites',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._buildPrerequisites(context, prerequisites),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildPrerequisites(
      BuildContext context, Map<String, dynamic> prerequisites) {
    final widgets = <Widget>[];

    prerequisites.forEach((key, value) {
      // Get human-readable label for the prerequisite type
      final label = _getPrerequisiteLabel(key);
      
      if (value is List && value.isNotEmpty) {
        // Extract names from the list of prerequisite objects
        final names = <String>[];
        for (final item in value) {
          if (item is Map<String, dynamic> && item['name'] != null) {
            names.add(item['name'].toString());
          } else if (item is String) {
            names.add(item);
          }
        }
        
        if (names.isNotEmpty) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getPrerequisiteIcon(key),
                          color: Theme.of(context).colorScheme.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: names.map((name) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '• $name',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        )).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      } else if (value != null && value.toString().isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _getPrerequisiteIcon(key),
                    color: Theme.of(context).colorScheme.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodySmall,
                        children: [
                          TextSpan(
                            text: '$label: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          TextSpan(text: value.toString()),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    });

    return widgets;
  }

  String _getPrerequisiteLabel(String key) {
    switch (key.toLowerCase()) {
      case 'item_prerequisite':
        return 'Required Items';
      case 'project_source':
        return 'Knowledge Source';
      case 'location':
        return 'Location Required';
      case 'skill':
        return 'Skill Required';
      case 'level':
        return 'Level Required';
      case 'class':
        return 'Class Required';
      case 'feature':
        return 'Feature Required';
      default:
        return key.replaceAll('_', ' ').split(' ')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }

  IconData _getPrerequisiteIcon(String key) {
    switch (key.toLowerCase()) {
      case 'item_prerequisite':
        return Icons.inventory_2;
      case 'project_source':
        return Icons.menu_book;
      case 'location':
        return Icons.place;
      case 'skill':
        return Icons.build;
      case 'level':
        return Icons.bar_chart;
      case 'class':
        return Icons.person;
      case 'feature':
        return Icons.star;
      default:
        return Icons.arrow_right;
    }
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
        color: _getCharacteristicColor(characteristic).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getCharacteristicColor(characteristic).withOpacity(0.4),
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
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _getCharacteristicColor(characteristic),
                  fontWeight: FontWeight.w500,
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
        return Icons.lightbulb_outline;
      case 'presence':
        return Icons.person;
      default:
        return Icons.help_outline;
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}