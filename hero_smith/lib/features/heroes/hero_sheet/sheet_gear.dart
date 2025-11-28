import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/providers.dart';
import '../../../core/models/component.dart' as model;
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/treasures/treasures.dart';

/// Gear and treasures management for the hero.
class SheetGear extends ConsumerStatefulWidget {
  const SheetGear({
    super.key,
    required this.heroId,
  });

  final String heroId;

  @override
  ConsumerState<SheetGear> createState() => _SheetGearState();
}

class _SheetGearState extends ConsumerState<SheetGear> {
  List<model.Component> _allTreasures = [];
  bool _isLoadingTreasures = true;
  String? _error;
  StreamSubscription<List<String>>? _treasureIdsSubscription;
  List<String> _heroTreasureIds = [];

  @override
  void initState() {
    super.initState();
    _loadAllTreasures();
    _watchHeroTreasureIds();
  }

  @override
  void dispose() {
    _treasureIdsSubscription?.cancel();
    super.dispose();
  }

  void _watchHeroTreasureIds() {
    final db = ref.read(appDatabaseProvider);
    _treasureIdsSubscription = db.watchHeroComponentIds(widget.heroId, 'treasure').listen(
      (ids) {
        if (mounted) {
          setState(() {
            _heroTreasureIds = ids;
          });
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _error = 'Failed to watch treasures: $e';
          });
        }
      },
    );
  }

  Future<void> _loadAllTreasures() async {
    try {
      // Load all treasures from all types
      final allComponents = await ref.read(allComponentsProvider.future);
      final treasures = allComponents.where((c) => 
        c.type == 'consumable' || 
        c.type == 'trinket' || 
        c.type == 'artifact' ||
        c.type == 'leveled_treasure'
      ).toList();

      if (mounted) {
        setState(() {
          _allTreasures = treasures..sort((a, b) => a.name.compareTo(b.name));
          _isLoadingTreasures = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingTreasures = false;
          _error = 'Failed to load treasures: $e';
        });
      }
    }
  }

  Future<void> _addTreasure(String treasureId) async {
    if (_heroTreasureIds.contains(treasureId)) return;

    final db = ref.read(appDatabaseProvider);
    final updated = [..._heroTreasureIds, treasureId];

    try {
      await db.setHeroComponentIds(
        heroId: widget.heroId,
        category: 'treasure',
        componentIds: updated,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Treasure added'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add treasure: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeTreasure(String treasureId) async {
    final db = ref.read(appDatabaseProvider);
    final updated = _heroTreasureIds.where((id) => id != treasureId).toList();

    try {
      await db.setHeroComponentIds(
        heroId: widget.heroId,
        category: 'treasure',
        componentIds: updated,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Treasure removed'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove treasure: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddTreasureDialog() {
    final availableTreasures = _allTreasures
        .where((t) => !_heroTreasureIds.contains(t.id))
        .toList();

    showDialog(
      context: context,
      builder: (context) => _AddTreasureDialog(
        availableTreasures: availableTreasures,
        onTreasureSelected: (treasureId) {
          _addTreasure(treasureId);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingTreasures) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final heroTreasures = _allTreasures
        .where((t) => _heroTreasureIds.contains(t.id))
        .toList();

    // Group treasures by type
    final groupedTreasures = <String, List<model.Component>>{};
    for (final treasure in heroTreasures) {
      final groupKey = _getTreasureGroupName(treasure.type);
      groupedTreasures.putIfAbsent(groupKey, () => []).add(treasure);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Text(
                'Gear & Treasures (${heroTreasures.length})',
                style: AppTextStyles.subtitle,
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _showAddTreasureDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
              ),
            ],
          ),
        ),
        Expanded(
          child: heroTreasures.isEmpty
              ? const Center(
                  child: Text(
                    'No gear yet.\nTap "Add Item" to begin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: groupedTreasures.length,
                  itemBuilder: (context, index) {
                    final entry = groupedTreasures.entries.elementAt(index);
                    final groupName = entry.key;
                    final treasures = entry.value;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 8),
                          child: Text(
                            groupName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ),
                        ...treasures.map((treasure) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Stack(
                              children: [
                                _buildTreasureCard(treasure),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _removeTreasure(treasure.id),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTreasureCard(model.Component treasure) {
    switch (treasure.type) {
      case 'consumable':
        return ConsumableTreasureCard(component: treasure);
      case 'trinket':
        return TrinketTreasureCard(component: treasure);
      case 'artifact':
        return ArtifactTreasureCard(component: treasure);
      case 'leveled_treasure':
        return LeveledTreasureCard(component: treasure);
      default:
        return Card(
          child: ListTile(
            title: Text(treasure.name),
            subtitle: Text(treasure.type),
          ),
        );
    }
  }

  String _getTreasureGroupName(String type) {
    switch (type) {
      case 'consumable':
        return 'Consumables';
      case 'trinket':
        return 'Trinkets';
      case 'artifact':
        return 'Artifacts';
      case 'leveled_treasure':
        return 'Leveled Equipment';
      default:
        return 'Other';
    }
  }
}

/// Dialog for adding treasures
class _AddTreasureDialog extends StatefulWidget {
  final List<model.Component> availableTreasures;
  final Function(String) onTreasureSelected;

  const _AddTreasureDialog({
    required this.availableTreasures,
    required this.onTreasureSelected,
  });

  @override
  State<_AddTreasureDialog> createState() => _AddTreasureDialogState();
}

class _AddTreasureDialogState extends State<_AddTreasureDialog> {
  String _searchQuery = '';
  String _filterType = 'all';
  List<model.Component> _filteredTreasures = [];

  @override
  void initState() {
    super.initState();
    _filteredTreasures = widget.availableTreasures;
  }

  void _filterTreasures() {
    setState(() {
      _filteredTreasures = widget.availableTreasures.where((treasure) {
        final description = treasure.data['description']?.toString() ?? '';
        final matchesSearch = _searchQuery.isEmpty ||
            treasure.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            description.toLowerCase().contains(_searchQuery.toLowerCase());

        final matchesType = _filterType == 'all' || treasure.type == _filterType;

        return matchesSearch && matchesType;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Add Treasure'),
      content: SizedBox(
        width: double.maxFinite,
        height: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search treasures',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                _searchQuery = value;
                _filterTreasures();
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _filterType,
              decoration: const InputDecoration(
                labelText: 'Filter by type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Types')),
                DropdownMenuItem(value: 'consumable', child: Text('Consumables')),
                DropdownMenuItem(value: 'trinket', child: Text('Trinkets')),
                DropdownMenuItem(value: 'artifact', child: Text('Artifacts')),
                DropdownMenuItem(value: 'leveled_treasure', child: Text('Leveled Equipment')),
              ],
              onChanged: (value) {
                if (value != null) {
                  _filterType = value;
                  _filterTreasures();
                }
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _filteredTreasures.isEmpty
                  ? Center(
                      child: Text(
                        'No treasures found',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredTreasures.length,
                      itemBuilder: (context, index) {
                        final treasure = _filteredTreasures[index];
                        final echelon = treasure.data['echelon'] as int?;
                        final description = treasure.data['description']?.toString() ?? '';
                        
                        return ListTile(
                          leading: Icon(
                            _getTreasureIcon(treasure.type),
                            color: theme.colorScheme.primary,
                          ),
                          title: Text(treasure.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_getTreasureTypeName(treasure.type)),
                              if (echelon != null)
                                Text('Echelon $echelon'),
                              if (description.isNotEmpty)
                                Text(
                                  description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                          onTap: () => widget.onTreasureSelected(treasure.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  String _getTreasureTypeName(String type) {
    switch (type) {
      case 'consumable':
        return 'Consumable';
      case 'trinket':
        return 'Trinket';
      case 'artifact':
        return 'Artifact';
      case 'leveled_treasure':
        return 'Leveled Equipment';
      default:
        return type;
    }
  }

  IconData _getTreasureIcon(String type) {
    switch (type) {
      case 'consumable':
        return Icons.local_drink;
      case 'trinket':
        return Icons.diamond;
      case 'artifact':
        return Icons.auto_awesome;
      case 'leveled_treasure':
        return Icons.shield;
      default:
        return Icons.category;
    }
  }
}
