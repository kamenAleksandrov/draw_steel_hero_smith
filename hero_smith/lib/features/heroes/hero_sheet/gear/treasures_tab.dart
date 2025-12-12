import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/downtime_data_source.dart';
import '../../../../core/db/providers.dart';
import '../../../../core/models/component.dart' as model;
import '../../../../core/models/downtime.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../widgets/treasures/treasures.dart';
import 'gear_dialogs.dart';
import 'gear_utils.dart';
import 'gear_widgets.dart';

/// Treasures tab for the gear sheet.
class TreasuresTab extends ConsumerStatefulWidget {
  const TreasuresTab({super.key, required this.heroId});

  final String heroId;

  @override
  ConsumerState<TreasuresTab> createState() => _TreasuresTabState();
}

class _TreasuresTabState extends ConsumerState<TreasuresTab> {
  List<model.Component> _allTreasures = [];
  List<DowntimeEntry> _allEnhancements = [];
  bool _isLoadingTreasures = true;
  String? _error;
  StreamSubscription<List<String>>? _treasureIdsSubscription;
  StreamSubscription<List<String>>? _enhancementIdsSubscription;
  List<String> _heroTreasureIds = [];
  List<String> _heroEnhancementIds = [];

  @override
  void initState() {
    super.initState();
    _loadAllTreasures();
    _loadAllEnhancements();
    _watchHeroTreasureIds();
    _watchHeroEnhancementIds();
  }

  @override
  void dispose() {
    _treasureIdsSubscription?.cancel();
    _enhancementIdsSubscription?.cancel();
    super.dispose();
  }

  void _watchHeroTreasureIds() {
    final db = ref.read(appDatabaseProvider);
    _treasureIdsSubscription =
        db.watchHeroComponentIds(widget.heroId, 'treasure').listen(
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

  void _watchHeroEnhancementIds() {
    final db = ref.read(appDatabaseProvider);
    _enhancementIdsSubscription =
        db.watchHeroComponentIds(widget.heroId, 'enhancement').listen(
      (ids) {
        if (mounted) {
          setState(() {
            _heroEnhancementIds = ids;
          });
        }
      },
      onError: (e) {
        // Ignore enhancement errors - they're optional
      },
    );
  }

  Future<void> _loadAllEnhancements() async {
    try {
      final dataSource = DowntimeDataSource();
      final enhancements = await dataSource.loadEnhancements();
      if (mounted) {
        setState(() {
          _allEnhancements = enhancements;
        });
      }
    } catch (e) {
      // Ignore enhancement loading errors - they're optional
    }
  }

  Future<void> _loadAllTreasures() async {
    try {
      // Load all treasures from all types
      final allComponents = await ref.read(allComponentsProvider.future);
      final treasures = allComponents
          .where((c) =>
              c.type == 'consumable' ||
              c.type == 'trinket' ||
              c.type == 'artifact' ||
              c.type == 'leveled_treasure')
          .toList();

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
    final availableTreasures =
        _allTreasures.where((t) => !_heroTreasureIds.contains(t.id)).toList();

    showDialog(
      context: context,
      builder: (context) => AddTreasureDialog(
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

    final heroTreasures =
        _allTreasures.where((t) => _heroTreasureIds.contains(t.id)).toList();

    // Get hero's enhancements
    final heroEnhancements =
        _allEnhancements.where((e) => _heroEnhancementIds.contains(e.id)).toList();

    // Group treasures by type
    final groupedTreasures = <String, List<model.Component>>{};
    for (final treasure in heroTreasures) {
      final groupKey = getTreasureGroupName(treasure.type);
      groupedTreasures.putIfAbsent(groupKey, () => []).add(treasure);
    }

    // Total count includes both treasures and enhancements
    final totalCount = heroTreasures.length + heroEnhancements.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Text(
                'Treasures & Enhancements ($totalCount)',
                style: AppTextStyles.subtitle,
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _showAddTreasureDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
        ),
        Expanded(
          child: (heroTreasures.isEmpty && heroEnhancements.isEmpty)
              ? const Center(
                  child: Text(
                    'No treasures or enhancements yet.\nTap "Add" to begin or complete a downtime project.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // Enhancements section (if any)
                    if (heroEnhancements.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        child: Text(
                          'Item Enhancements',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                        ),
                      ),
                      ...heroEnhancements.map((enhancement) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Stack(
                            children: [
                              EnhancementCard(enhancement: enhancement),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _removeEnhancement(enhancement.id),
                                  style: IconButton.styleFrom(
                                    backgroundColor:
                                        Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    
                    // Treasures sections
                    ...groupedTreasures.entries.map((entry) {
                      final groupName = entry.key;
                      final treasures = entry.value;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 16, bottom: 8),
                            child: Text(
                              groupName,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
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
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () =>
                                          _removeTreasure(treasure.id),
                                      style: IconButton.styleFrom(
                                        backgroundColor:
                                            Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      );
                    }),
                    
                    const SizedBox(height: 16),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _removeEnhancement(String enhancementId) async {
    final db = ref.read(appDatabaseProvider);
    final updated = _heroEnhancementIds.where((id) => id != enhancementId).toList();

    try {
      await db.setHeroComponentIds(
        heroId: widget.heroId,
        category: 'enhancement',
        componentIds: updated,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enhancement removed'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove enhancement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
}
