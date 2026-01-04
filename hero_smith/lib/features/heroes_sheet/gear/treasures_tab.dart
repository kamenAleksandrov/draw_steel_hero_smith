import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/downtime_data_source.dart';
import '../../../core/db/providers.dart';
import '../../../core/models/component.dart' as model;
import '../../../core/models/downtime.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/navigation_theme.dart';
import '../../../core/text/heroes_sheet/gear/treasures_tab_text.dart';
import '../../../widgets/treasures/treasures.dart';
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
  List<DowntimeEntry> _allImbuements = [];
  bool _isLoadingTreasures = true;
  String? _error;
  StreamSubscription<List<String>>? _treasureIdsSubscription;
  StreamSubscription<List<String>>? _imbuementIdsSubscription;
  List<String> _heroTreasureIds = [];
  List<String> _heroImbuementIds = [];

  @override
  void initState() {
    super.initState();
    _loadAllTreasures();
    _loadAllImbuements();
    _watchHeroTreasureIds();
    _watchHeroImbuementIds();
  }

  @override
  void dispose() {
    _treasureIdsSubscription?.cancel();
    _imbuementIdsSubscription?.cancel();
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
            _error = '${TreasuresTabText.watchTreasuresFailedPrefix}$e';
          });
        }
      },
    );
  }

  void _watchHeroImbuementIds() {
    final db = ref.read(appDatabaseProvider);
    _imbuementIdsSubscription =
        db.watchHeroComponentIds(widget.heroId, 'imbuement').listen(
      (ids) {
        if (mounted) {
          setState(() {
            _heroImbuementIds = ids;
          });
        }
      },
      onError: (e) {
        // Ignore imbuement errors - they're optional
      },
    );
  }

  Future<void> _loadAllImbuements() async {
    try {
      final dataSource = DowntimeDataSource();
      final imbuements = await dataSource.loadImbuements();
      if (mounted) {
        setState(() {
          _allImbuements = imbuements;
        });
      }
    } catch (e) {
      // Ignore imbuement loading errors - they're optional
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
          _error = '${TreasuresTabText.loadTreasuresFailedPrefix}$e';
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
            content: Text(TreasuresTabText.treasureAddedSnack),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${TreasuresTabText.addTreasureFailedPrefix}$e'),
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
            content: Text(TreasuresTabText.treasureRemovedSnack),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${TreasuresTabText.removeTreasureFailedPrefix}$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddTreasureDialog() {
    final availableTreasures =
        _allTreasures.where((t) => !_heroTreasureIds.contains(t.id)).toList();
    final availableImbuements =
        _allImbuements.where((i) => !_heroImbuementIds.contains(i.id)).toList();

    showDialog(
      context: context,
      builder: (context) => AddTreasureDialog(
        availableTreasures: availableTreasures,
        availableImbuements: availableImbuements,
        onTreasureSelected: (treasureId) {
          _addTreasure(treasureId);
          Navigator.of(context).pop();
        },
        onImbuementSelected: (imbuementId) {
          _addImbuement(imbuementId);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _addImbuement(String imbuementId) async {
    if (_heroImbuementIds.contains(imbuementId)) return;

    final db = ref.read(appDatabaseProvider);
    final updated = [..._heroImbuementIds, imbuementId];

    try {
      await db.setHeroComponentIds(
        heroId: widget.heroId,
        category: 'imbuement',
        componentIds: updated,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(TreasuresTabText.imbuementAddedSnack),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${TreasuresTabText.addImbuementFailedPrefix}$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingTreasures) {
      return Center(
          child:
              CircularProgressIndicator(color: NavigationTheme.treasureColor));
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

    // Get hero's imbuements
    final heroImbuements =
        _allImbuements.where((e) => _heroImbuementIds.contains(e.id)).toList();

    // Group treasures by type
    final groupedTreasures = <String, List<model.Component>>{};
    for (final treasure in heroTreasures) {
      final groupKey = getTreasureGroupName(treasure.type);
      groupedTreasures.putIfAbsent(groupKey, () => []).add(treasure);
    }

    // Total count includes both treasures and imbuements
    final totalCount = heroTreasures.length + heroImbuements.length;

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Text(
                    '${TreasuresTabText.treasuresAndImbuementsHeaderPrefix}$totalCount${TreasuresTabText.treasuresAndImbuementsHeaderSuffix}',
                    style: TextStyle(
                      color: Colors.grey.shade300,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: (heroTreasures.isEmpty && heroImbuements.isEmpty)
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 64,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            TreasuresTabText.emptyStateMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        // Imbuements section (if any)
                        if (heroImbuements.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 16, bottom: 8),
                            child: Text(
                              TreasuresTabText.itemImbuementsHeader,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: NavigationTheme.imbuementsTabColor,
                              ),
                            ),
                          ),
                          ...heroImbuements.map((imbuement) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Stack(
                                children: [
                                  ImbuementCard(imbuement: imbuement),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.white70, size: 20),
                                      onPressed: () =>
                                          _removeImbuement(imbuement.id),
                                      style: IconButton.styleFrom(
                                        backgroundColor:
                                            Colors.black.withValues(alpha: 0.6),
                                        padding: const EdgeInsets.all(6),
                                        minimumSize: const Size(32, 32),
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
                          // Get color from first treasure in group (all same type)
                          final sectionColor = _getTreasureGroupColor(
                              treasures.isNotEmpty ? treasures.first.type : '');

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 16, bottom: 8),
                                child: Text(
                                  groupName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: sectionColor,
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
                                          icon: const Icon(Icons.delete_outline,
                                              color: Colors.white70, size: 20),
                                          onPressed: () =>
                                              _removeTreasure(treasure.id),
                                          style: IconButton.styleFrom(
                                            backgroundColor: Colors.black
                                                .withValues(alpha: 0.6),
                                            padding: const EdgeInsets.all(6),
                                            minimumSize: const Size(32, 32),
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
        ),
        // Floating Action Button for adding treasures
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.small(
            heroTag: 'treasures_tab_fab',
            onPressed: _showAddTreasureDialog,
            tooltip: TreasuresTabText.addButtonLabel,
            backgroundColor: Colors.black54,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side:
                  BorderSide(color: NavigationTheme.treasureColor, width: 1.5),
            ),
            child:
                Icon(Icons.add, color: NavigationTheme.treasureColor, size: 20),
          ),
        ),
      ],
    );
  }

  Future<void> _removeImbuement(String imbuementId) async {
    final db = ref.read(appDatabaseProvider);
    final updated = _heroImbuementIds.where((id) => id != imbuementId).toList();

    try {
      await db.setHeroComponentIds(
        heroId: widget.heroId,
        category: 'imbuement',
        componentIds: updated,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(TreasuresTabText.imbuementRemovedSnack),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${TreasuresTabText.removeImbuementFailedPrefix}$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildTreasureCard(model.Component treasure) {
    // Use the unified TreasureCard for all treasure types
    return TreasureCard(component: treasure);
  }

  /// Get the color for a treasure type group header.
  Color _getTreasureGroupColor(String type) {
    switch (type.toLowerCase()) {
      case 'consumable':
        return NavigationTheme.consumablesColor;
      case 'trinket':
        return NavigationTheme.trinketsColor;
      case 'leveled_treasure':
        return NavigationTheme.leveledColor;
      case 'artifact':
        return NavigationTheme.artifactsColor;
      default:
        return NavigationTheme.treasureColor;
    }
  }
}
