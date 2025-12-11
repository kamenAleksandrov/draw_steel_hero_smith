import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/downtime_data_source.dart';
import '../../../core/db/providers.dart';
import '../../../core/models/class_data.dart';
import '../../../core/models/component.dart' as model;
import '../../../core/models/downtime.dart';
import '../../../core/repositories/hero_repository.dart';
import '../../../core/services/class_data_service.dart';
import '../../../core/services/kit_bonus_service.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/treasures/treasures.dart';
import 'state/hero_main_stats_providers.dart';

String _kitTypeDisplayName(String type) {
  switch (type) {
    case 'psionic_augmentation':
      return 'Psionic Augmentation';
    case 'enchantment':
      return 'Enchantment';
    case 'prayer':
      return 'Prayer';
    case 'ward':
      return 'Ward';
    case 'stormwight_kit':
      return 'Stormwight Kit';
    default:
      if (type.isEmpty) return 'Kit';
      return type[0].toUpperCase() + type.substring(1);
  }
}

// ignore: unused_element
IconData _kitTypeIcon(String type) {
  switch (type) {
    case 'kit':
      return Icons.shield;
    case 'stormwight_kit':
      return Icons.flash_on;
    case 'psionic_augmentation':
      return Icons.psychology;
    case 'ward':
      return Icons.security;
    case 'prayer':
      return Icons.auto_fix_high;
    case 'enchantment':
      return Icons.auto_awesome;
    default:
      return Icons.category;
  }
}

class _EquipmentSlotConfig {
  const _EquipmentSlotConfig({
    required this.label,
    required this.allowedTypes,
    required this.index,
  });

  final String label;
  final List<String> allowedTypes;
  final int index;
}

/// Gear and treasures management for the hero with tabbed interface.
class SheetGear extends ConsumerStatefulWidget {
  const SheetGear({
    super.key,
    required this.heroId,
  });

  final String heroId;

  @override
  ConsumerState<SheetGear> createState() => _SheetGearState();
}

class _SheetGearState extends ConsumerState<SheetGear>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.auto_awesome), text: 'Treasures'),
            Tab(icon: Icon(Icons.shield), text: 'Kits'),
            Tab(icon: Icon(Icons.inventory_2), text: 'Inventory'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _TreasuresTab(heroId: widget.heroId),
              _KitsTab(heroId: widget.heroId),
              _InventoryTab(heroId: widget.heroId),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// TREASURES TAB
// ============================================================================

class _TreasuresTab extends ConsumerStatefulWidget {
  const _TreasuresTab({required this.heroId});

  final String heroId;

  @override
  ConsumerState<_TreasuresTab> createState() => _TreasuresTabState();
}

class _TreasuresTabState extends ConsumerState<_TreasuresTab> {
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

    final heroTreasures =
        _allTreasures.where((t) => _heroTreasureIds.contains(t.id)).toList();

    // Get hero's enhancements
    final heroEnhancements =
        _allEnhancements.where((e) => _heroEnhancementIds.contains(e.id)).toList();

    // Group treasures by type
    final groupedTreasures = <String, List<model.Component>>{};
    for (final treasure in heroTreasures) {
      final groupKey = _getTreasureGroupName(treasure.type);
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
                              _buildEnhancementCard(enhancement),
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

  Widget _buildEnhancementCard(DowntimeEntry enhancement) {
    return _EnhancementCard(enhancement: enhancement);
  }

  // ignore: unused_element
  Color _getLevelColor(int level) {
    if (level <= 2) {
      return Colors.green.shade600;
    } else if (level <= 4) {
      return Colors.blue.shade600;
    } else if (level <= 6) {
      return Colors.purple.shade600;
    } else if (level <= 8) {
      return Colors.orange.shade700;
    } else {
      return Colors.red.shade600;
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

// ============================================================================
// KITS TAB
// ============================================================================

class _KitsTab extends ConsumerStatefulWidget {
  const _KitsTab({required this.heroId});

  final String heroId;

  @override
  ConsumerState<_KitsTab> createState() => _KitsTabState();
}

class _KitsTabState extends ConsumerState<_KitsTab> {
  // Mapping from kit feature names to equipment types
  static const Map<String, List<String>> _kitFeatureTypeMappings = {
    'kit': ['kit'],
    'psionic augmentation': ['psionic_augmentation'],
    'enchantment': ['enchantment'],
    'prayer': ['prayer'],
    'elementalist ward': ['ward'],
    'talent ward': ['ward'],
    'conduit ward': ['ward'],
    'ward': ['ward'],
  };
  static const List<String> _kitTypePriority = [
    'kit',
    'psionic_augmentation',
    'enchantment',
    'prayer',
    'ward',
    'stormwight_kit',
  ];

  List<model.Component> _allKits = [];
  List<String> _allowedEquipmentTypes = ['kit']; // Default to standard kit
  List<String> _favoriteKitIds = [];
  List<String> _equippedKitIds = [];
  List<_EquipmentSlotConfig> _equipmentSlots = [];
  List<String?> _equippedSlotIds = [];
  final Map<String, model.Component> _kitCache = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final db = ref.read(appDatabaseProvider);
      final values = await db.getHeroValues(widget.heroId);

      // Get class and subclass info
      String? className;
      String? subclassName;

      for (final value in values) {
        if (value.key == 'basics.className') {
          className = value.textValue;
        } else if (value.key == 'basics.subclass') {
          subclassName = value.textValue;
        }
      }

      // Load class data to determine allowed equipment types
      final classDataService = ClassDataService();
      await classDataService.initialize();
      final classData =
          className != null ? classDataService.getClassById(className) : null;
      final slots = _determineEquipmentSlots(classData, subclassName);
      final allowedTypes = slots.isEmpty
          ? ['kit']
          : _sortKitTypesByPriority(slots
              .expand((slot) => slot.allowedTypes)
              .toSet());

      // Load all kit-type components that match allowed types
      final allComponents = await ref.read(allComponentsProvider.future);
      final kits = allComponents
          .where((c) => allowedTypes.contains(c.type))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      // Load favorite and equipped kits
      final heroRepo = ref.read(heroRepositoryProvider);
      final favorites = await heroRepo.getFavoriteKitIds(widget.heroId);
      final equipped = await heroRepo.getEquipmentIds(widget.heroId);
      final alignedEquipped = await _alignEquipmentToSlots(
        slots: slots,
        equipmentIds: equipped,
        db: db,
      );
      final equippedActive = alignedEquipped.whereType<String>().toList();
      final cache = {for (final kit in kits) kit.id: kit};

      if (mounted) {
        setState(() {
          _allKits = kits;
          _allowedEquipmentTypes = allowedTypes;
          _favoriteKitIds = favorites;
          _equipmentSlots = slots;
          _equippedSlotIds = alignedEquipped;
          _equippedKitIds = equippedActive;
          _kitCache
            ..clear()
            ..addAll(cache);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load kits: $e';
          _isLoading = false;
        });
      }
    }
  }

  // ignore: unused_element
  Widget _buildEquippedSlotsSummary() {
    if (_equipmentSlots.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Equipped Modifications',
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final slot in _equipmentSlots) _buildSlotCard(slot),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlotCard(_EquipmentSlotConfig slot) {
    final theme = Theme.of(context);
    final kit = _getSlotKit(slot.index);

    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            slot.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            kit?.name ?? 'Empty',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            kit != null ? _kitTypeDisplayName(kit.type) : 'Use Swap to equip',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  List<_EquipmentSlotConfig> _determineEquipmentSlots(
    ClassData? classData,
    String? subclassName,
  ) {
    if (classData == null) {
      return [
        const _EquipmentSlotConfig(label: 'Kit', allowedTypes: ['kit'], index: 0),
      ];
    }

    final subclass = subclassName?.toLowerCase() ?? '';
    if (classData.classId == 'class_fury' && subclass == 'stormwight') {
      return [
        const _EquipmentSlotConfig(
          label: 'Stormwight Kit',
          allowedTypes: ['stormwight_kit'],
          index: 0,
        ),
      ];
    }

    final kitFeatures = <Map<String, dynamic>>[];
    final typesList = <String>[];

    for (final level in classData.levels) {
      for (final feature in level.features) {
        final name = feature.name.trim().toLowerCase();
        if (name == 'kit' || _kitFeatureTypeMappings.containsKey(name)) {
          kitFeatures.add({'name': name, 'count': feature.count ?? 1});

          final mapped = _kitFeatureTypeMappings[name];
          if (mapped != null) {
            typesList.addAll(mapped);
          } else {
            typesList.add('kit');
          }
        }
      }
    }

    if (kitFeatures.isEmpty) {
      return [
        const _EquipmentSlotConfig(label: 'Kit', allowedTypes: ['kit'], index: 0),
      ];
    }

    final uniqueTypes = <String>[];
    final seen = <String>{};
    for (final type in typesList) {
      if (seen.add(type)) {
        uniqueTypes.add(type);
      }
    }

    final totalCount = kitFeatures.fold<int>(0, (sum, feature) {
      return sum + (feature['count'] as int);
    });

    if (totalCount <= 0) {
      return [
        const _EquipmentSlotConfig(label: 'Kit', allowedTypes: ['kit'], index: 0),
      ];
    }

    final slots = <_EquipmentSlotConfig>[];
    var index = 0;

    if (uniqueTypes.length > 1 && totalCount >= uniqueTypes.length) {
      for (final type in uniqueTypes) {
        slots.add(_EquipmentSlotConfig(
          label: _kitTypeDisplayName(type),
          allowedTypes: [type],
          index: index++,
        ));
      }
    } else {
      final sortedTypes = _sortKitTypesByPriority(uniqueTypes);
      final displayName = sortedTypes.isNotEmpty
          ? _kitTypeDisplayName(sortedTypes.first)
          : 'Kit';
      for (var i = 0; i < totalCount; i++) {
        final label = totalCount > 1 ? '$displayName ${i + 1}' : displayName;
        slots.add(_EquipmentSlotConfig(
          label: label,
          allowedTypes: sortedTypes.isEmpty ? ['kit'] : sortedTypes,
          index: index++,
        ));
      }
    }

    return slots.isEmpty
        ? [
            const _EquipmentSlotConfig(
              label: 'Kit',
              allowedTypes: ['kit'],
              index: 0,
            ),
          ]
        : slots;
  }

  List<String> _sortKitTypesByPriority(Iterable<String> types) {
    final seen = <String>{};
    final sorted = <String>[];

    for (final type in _kitTypePriority) {
      if (types.contains(type) && seen.add(type)) {
        sorted.add(type);
      }
    }

    for (final type in types) {
      if (seen.add(type)) {
        sorted.add(type);
      }
    }

    return sorted;
  }

  Future<List<String?>> _alignEquipmentToSlots({
    required List<_EquipmentSlotConfig> slots,
    required List<String?> equipmentIds,
    required dynamic db,
  }) async {
    if (slots.isEmpty) {
      return equipmentIds
          .where((id) => id != null && id.isNotEmpty)
          .cast<String?>()
          .toList();
    }

    final slotCount = slots.length;
    final result = List<String?>.filled(slotCount, null);
    final usedIds = <String>{};
    final equipmentTypes = <String, String>{};
    final normalizedIds = equipmentIds
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toList();

    for (final id in normalizedIds) {
      final component = await db.getComponentById(id);
      if (component != null) {
        equipmentTypes[id] = component.type;
      }
    }

    for (var i = 0; i < slotCount; i++) {
      final allowedTypes = slots[i].allowedTypes;
      for (final id in normalizedIds) {
        if (usedIds.contains(id)) continue;
        final type = equipmentTypes[id];
        if (type != null && allowedTypes.contains(type)) {
          result[i] = id;
          usedIds.add(id);
          break;
        }
      }
    }

    for (var i = 0; i < slotCount; i++) {
      if (result[i] != null) continue;
      for (final id in normalizedIds) {
        if (usedIds.contains(id)) continue;
        result[i] = id;
        usedIds.add(id);
        break;
      }
    }

    return result;
  }

  Future<void> _toggleFavorite(String kitId) async {
    final heroRepo = ref.read(heroRepositoryProvider);
    final newFavorites = _favoriteKitIds.contains(kitId)
        ? _favoriteKitIds.where((id) => id != kitId).toList()
        : [..._favoriteKitIds, kitId];

    try {
      await heroRepo.saveFavoriteKitIds(widget.heroId, newFavorites);
      setState(() {
        _favoriteKitIds = newFavorites;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update favorites: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _swapToKit(model.Component kit) async {
    if (_equipmentSlots.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This hero cannot equip modifications.')),
        );
      }
      return;
    }

    final matchingSlots = _equipmentSlots
        .where((slot) => slot.allowedTypes.contains(kit.type))
        .map((slot) => slot.index)
        .toList()
      ..sort();

    if (matchingSlots.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot equip ${kit.name}; no ${_kitTypeDisplayName(kit.type)} slot available.'),
          ),
        );
      }
      return;
    }

    final targetSlotIndex = matchingSlots.length == 1
        ? matchingSlots.first
        : await _selectSlotForKit(kit, matchingSlots);

    if (targetSlotIndex == null) return;

    final slot = _equipmentSlots[targetSlotIndex];
    final currentKitName = _slotCurrentName(targetSlotIndex);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Swap ${slot.label}'),
        content: Text(
          currentKitName != null
              ? 'Replace $currentKitName with "${kit.name}" in ${slot.label}?'
              : 'Equip "${kit.name}" in ${slot.label}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Swap'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _applyKitSwap(kit, targetSlotIndex);
  }

  Future<int?> _selectSlotForKit(
    model.Component kit,
    List<int> slotIndices,
  ) async {
    return showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Choose slot for ${kit.name}'),
        children: [
          for (final index in slotIndices)
            ListTile(
              title: Text(_equipmentSlots[index].label),
              subtitle: Text(_slotCurrentName(index) ?? 'Currently empty'),
              onTap: () => Navigator.of(context).pop(index),
            ),
          const Divider(),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  String? _slotCurrentName(int slotIndex) {
    return _getSlotKit(slotIndex)?.name;
  }

  model.Component? _getSlotKit(int slotIndex) {
    if (slotIndex >= _equippedSlotIds.length) return null;
    final kitId = _equippedSlotIds[slotIndex];
    if (kitId == null) return null;
    return _findKitById(kitId);
  }

  Future<void> _applyKitSwap(model.Component kit, int slotIndex) async {
    try {
      final heroRepo = ref.read(heroRepositoryProvider);
      final db = ref.read(appDatabaseProvider);

      final updatedSlots = List<String?>.from(_equippedSlotIds);
      while (updatedSlots.length < _equipmentSlots.length) {
        updatedSlots.add(null);
      }
      updatedSlots[slotIndex] = kit.id;

      await heroRepo.saveEquipmentIds(widget.heroId, updatedSlots);
      await db.upsertHeroValue(
        heroId: widget.heroId,
        key: 'basics.equipment',
        jsonMap: {'ids': updatedSlots},
      );

      await _recalculateAndSaveBonuses(heroRepo, updatedSlots);

      ref.invalidate(heroRepositoryProvider);
      ref.invalidate(heroEquipmentBonusesProvider(widget.heroId));

      final equippedActive = updatedSlots.whereType<String>().toList();
      _kitCache[kit.id] = kit;

      if (mounted) {
        setState(() {
          _equippedSlotIds = updatedSlots;
          _equippedKitIds = equippedActive;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Equipped ${kit.name} in ${_equipmentSlots[slotIndex].label}.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to swap kit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _recalculateAndSaveBonuses(
      HeroRepository heroRepo, List<String?> equipmentSlotIds) async {
    final normalizedIds = equipmentSlotIds
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();

    if (normalizedIds.isEmpty) {
      await heroRepo.saveEquipmentBonuses(
        widget.heroId,
        staminaBonus: 0,
        speedBonus: 0,
        stabilityBonus: 0,
        disengageBonus: 0,
        meleeDamageBonus: 0,
        rangedDamageBonus: 0,
        meleeDistanceBonus: 0,
        rangedDistanceBonus: 0,
      );
      return;
    }

    final level = await heroRepo.getHeroLevel(widget.heroId);
    final equippedComponents = <model.Component>[];
    for (final kitId in normalizedIds) {
      final component = _findKitById(kitId);
      if (component != null) {
        equippedComponents.add(component);
      }
    }

    if (equippedComponents.isEmpty) {
      await heroRepo.saveEquipmentBonuses(
        widget.heroId,
        staminaBonus: 0,
        speedBonus: 0,
        stabilityBonus: 0,
        disengageBonus: 0,
        meleeDamageBonus: 0,
        rangedDamageBonus: 0,
        meleeDistanceBonus: 0,
        rangedDistanceBonus: 0,
      );
      return;
    }

    const kitBonusService = KitBonusService();
    final bonuses = kitBonusService.calculateBonuses(
      equipment: equippedComponents,
      heroLevel: level,
    );

    await heroRepo.saveEquipmentBonuses(
      widget.heroId,
      staminaBonus: bonuses.staminaBonus,
      speedBonus: bonuses.speedBonus,
      stabilityBonus: bonuses.stabilityBonus,
      disengageBonus: bonuses.disengageBonus,
      meleeDamageBonus: bonuses.meleeDamageBonus,
      rangedDamageBonus: bonuses.rangedDamageBonus,
      meleeDistanceBonus: bonuses.meleeDistanceBonus,
      rangedDistanceBonus: bonuses.rangedDistanceBonus,
    );
  }

  model.Component? _findKitById(String kitId) {
    final cached = _kitCache[kitId];
    if (cached != null) return cached;
    for (final kit in _allKits) {
      if (kit.id == kitId) {
        _kitCache[kitId] = kit;
        return kit;
      }
    }
    return null;
  }

  void _showAddFavoriteDialog() {
    // Filter to only allowed types and exclude already-favorited kits
    final availableKits = _allKits
        .where((k) =>
            _allowedEquipmentTypes.contains(k.type) &&
            !_favoriteKitIds.contains(k.id))
        .toList();

    showDialog(
      context: context,
      builder: (context) => _AddKitFavoriteDialog(
        availableKits: availableKits,
        allowedTypes: _allowedEquipmentTypes,
        onKitSelected: (kitId) {
          _toggleFavorite(kitId);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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

    final favoriteKits =
        _allKits.where((k) => _favoriteKitIds.contains(k.id)).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Text(
                'Favorite Kits (${favoriteKits.length})',
                style: AppTextStyles.subtitle,
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _showAddFavoriteDialog,
                icon: const Icon(Icons.favorite_border),
                label: const Text('Add Favorite'),
              ),
            ],
          ),
        ),
        Expanded(
          child: favoriteKits.isEmpty
              ? const Center(
                  child: Text(
                    'No favorite kits yet.\nAdd kits to quickly swap between them.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: favoriteKits.length,
                  itemBuilder: (context, index) {
                    final kit = favoriteKits[index];
                    final isEquipped = _equippedKitIds.contains(kit.id);

                    return _KitFavoriteCard(
                      kit: kit,
                      isEquipped: isEquipped,
                      onSwap: () => _swapToKit(kit),
                      onRemoveFavorite: () => _toggleFavorite(kit.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _KitFavoriteCard extends StatelessWidget {
  const _KitFavoriteCard({
    required this.kit,
    required this.isEquipped,
    required this.onSwap,
    required this.onRemoveFavorite,
  });

  final model.Component kit;
  final bool isEquipped;
  final VoidCallback onSwap;
  final VoidCallback onRemoveFavorite;

  String _getKitTypeName(String type) {
    switch (type) {
      case 'kit':
        return 'Kit';
      case 'stormwight_kit':
        return 'Stormwight Kit';
      case 'psionic_augmentation':
        return 'Augmentation';
      case 'ward':
        return 'Ward';
      case 'prayer':
        return 'Prayer';
      case 'enchantment':
        return 'Enchantment';
      default:
        return type;
    }
  }

  IconData _getKitIcon(String type) {
    switch (type) {
      case 'kit':
        return Icons.shield;
      case 'stormwight_kit':
        return Icons.flash_on;
      case 'psionic_augmentation':
        return Icons.psychology;
      case 'ward':
        return Icons.security;
      case 'prayer':
        return Icons.auto_fix_high;
      case 'enchantment':
        return Icons.auto_awesome;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = kit.data;

    final staminaBonus = data['stamina_bonus'] as int? ?? 0;
    final speedBonus = data['speed_bonus'] as int? ?? 0;
    final stabilityBonus = data['stability_bonus'] as int? ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isEquipped
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with name, type, and actions
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _getKitIcon(kit.type),
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kit.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            _getKitTypeName(kit.type),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          if (isEquipped) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'EQUIPPED',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.favorite, color: Colors.red, size: 20),
                  onPressed: onRemoveFavorite,
                  tooltip: 'Remove from favorites',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
              ],
            ),
            // Bonus stats row
            if (staminaBonus != 0 || speedBonus != 0 || stabilityBonus != 0) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (staminaBonus != 0)
                    _StatChip(label: 'Stamina', value: '+$staminaBonus'),
                  if (speedBonus != 0)
                    _StatChip(label: 'Speed', value: '+$speedBonus'),
                  if (stabilityBonus != 0)
                    _StatChip(label: 'Stability', value: '+$stabilityBonus'),
                ],
              ),
            ],
            // Swap button
            if (!isEquipped) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onSwap,
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('Swap To'),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $value',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}

class _AddKitFavoriteDialog extends StatefulWidget {
  const _AddKitFavoriteDialog({
    required this.availableKits,
    required this.allowedTypes,
    required this.onKitSelected,
  });

  final List<model.Component> availableKits;
  final List<String> allowedTypes;
  final Function(String) onKitSelected;

  @override
  State<_AddKitFavoriteDialog> createState() => _AddKitFavoriteDialogState();
}

class _AddKitFavoriteDialogState extends State<_AddKitFavoriteDialog> {
  String _searchQuery = '';
  String _filterType = 'all';
  List<model.Component> _filteredKits = [];

  static const Map<String, String> _typeLabels = {
    'kit': 'Kits',
    'stormwight_kit': 'Stormwight Kits',
    'psionic_augmentation': 'Augmentations',
    'ward': 'Wards',
    'prayer': 'Prayers',
    'enchantment': 'Enchantments',
  };

  static const Map<String, IconData> _typeIcons = {
    'kit': Icons.shield,
    'stormwight_kit': Icons.flash_on,
    'psionic_augmentation': Icons.psychology,
    'ward': Icons.security,
    'prayer': Icons.auto_fix_high,
    'enchantment': Icons.auto_awesome,
  };

  @override
  void initState() {
    super.initState();
    _filteredKits = widget.availableKits;
  }

  void _filterKits() {
    setState(() {
      _filteredKits = widget.availableKits.where((kit) {
        final matchesSearch = _searchQuery.isEmpty ||
            kit.name.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesType = _filterType == 'all' || kit.type == _filterType;
        return matchesSearch && matchesType;
      }).toList();
    });
  }

  List<DropdownMenuItem<String>> _buildTypeDropdownItems() {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'all', child: Text('All Types')),
    ];

    // Only add types that the hero has access to
    for (final type in widget.allowedTypes) {
      final label = _typeLabels[type] ?? type;
      items.add(DropdownMenuItem(value: type, child: Text(label)));
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Add Favorite'),
      content: SizedBox(
        width: double.maxFinite,
        height: 500,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                _searchQuery = value;
                _filterKits();
              },
            ),
            if (widget.allowedTypes.length > 1) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _filterType,
                decoration: const InputDecoration(
                  labelText: 'Filter by type',
                  border: OutlineInputBorder(),
                ),
                items: _buildTypeDropdownItems(),
                onChanged: (value) {
                  if (value != null) {
                    _filterType = value;
                    _filterKits();
                  }
                },
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: _filteredKits.isEmpty
                  ? Center(
                      child: Text(
                        'No equipment found',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredKits.length,
                      itemBuilder: (context, index) {
                        final kit = _filteredKits[index];
                        final icon = _typeIcons[kit.type] ?? Icons.inventory_2;
                        final typeLabel = _typeLabels[kit.type] ?? kit.type;
                        return ListTile(
                          leading: Icon(icon, color: theme.colorScheme.primary),
                          title: Text(kit.name),
                          subtitle: Text(typeLabel),
                          onTap: () => widget.onKitSelected(kit.id),
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
}

// ============================================================================
// INVENTORY TAB
// ============================================================================

class _InventoryTab extends ConsumerStatefulWidget {
  const _InventoryTab({required this.heroId});

  final String heroId;

  @override
  ConsumerState<_InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends ConsumerState<_InventoryTab> {
  List<Map<String, dynamic>> _containers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    try {
      final heroRepo = ref.read(heroRepositoryProvider);
      final containers = await heroRepo.getInventoryContainers(widget.heroId);
      if (mounted) {
        setState(() {
          _containers = containers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load inventory: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createContainer() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _CreateContainerDialog(),
    );

    if (name == null || name.isEmpty) return;

    try {
      final heroRepo = ref.read(heroRepositoryProvider);
      final newContainer = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': name,
        'items': <Map<String, dynamic>>[],
      };
      final updated = [..._containers, newContainer];
      await heroRepo.saveInventoryContainers(widget.heroId, updated);
      setState(() {
        _containers = updated;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create container: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteContainer(String containerId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Container'),
        content: const Text(
            'Delete this container and all items inside? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final heroRepo = ref.read(heroRepositoryProvider);
      final updated =
          _containers.where((c) => c['id'] != containerId).toList();
      await heroRepo.saveInventoryContainers(widget.heroId, updated);
      setState(() {
        _containers = updated;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete container: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addItemToContainer(String containerId) async {
    final itemData = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _CreateItemDialog(),
    );

    if (itemData == null) return;

    try {
      final heroRepo = ref.read(heroRepositoryProvider);
      final containerIndex =
          _containers.indexWhere((c) => c['id'] == containerId);
      if (containerIndex == -1) return;

      final container =
          Map<String, dynamic>.from(_containers[containerIndex]);
      final items =
          List<Map<String, dynamic>>.from(container['items'] as List? ?? []);

      items.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': itemData['name'],
        'description': itemData['description'],
      });

      container['items'] = items;

      final updated = List<Map<String, dynamic>>.from(_containers);
      updated[containerIndex] = container;

      await heroRepo.saveInventoryContainers(widget.heroId, updated);
      setState(() {
        _containers = updated;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add item: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteItem(String containerId, String itemId) async {
    try {
      final heroRepo = ref.read(heroRepositoryProvider);
      final containerIndex =
          _containers.indexWhere((c) => c['id'] == containerId);
      if (containerIndex == -1) return;

      final container =
          Map<String, dynamic>.from(_containers[containerIndex]);
      final items =
          List<Map<String, dynamic>>.from(container['items'] as List? ?? []);

      items.removeWhere((item) => item['id'] == itemId);
      container['items'] = items;

      final updated = List<Map<String, dynamic>>.from(_containers);
      updated[containerIndex] = container;

      await heroRepo.saveInventoryContainers(widget.heroId, updated);
      setState(() {
        _containers = updated;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete item: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Text(
                'Inventory',
                style: AppTextStyles.subtitle,
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _createContainer,
                icon: const Icon(Icons.create_new_folder),
                label: const Text('New Container'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _containers.isEmpty
              ? const Center(
                  child: Text(
                    'No containers yet.\nCreate a container to organize your items.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _containers.length,
                  itemBuilder: (context, index) {
                    final container = _containers[index];
                    return _ContainerCard(
                      container: container,
                      onAddItem: () =>
                          _addItemToContainer(container['id'] as String),
                      onDeleteContainer: () =>
                          _deleteContainer(container['id'] as String),
                      onDeleteItem: (itemId) =>
                          _deleteItem(container['id'] as String, itemId),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ContainerCard extends StatefulWidget {
  const _ContainerCard({
    required this.container,
    required this.onAddItem,
    required this.onDeleteContainer,
    required this.onDeleteItem,
  });

  final Map<String, dynamic> container;
  final VoidCallback onAddItem;
  final VoidCallback onDeleteContainer;
  final Function(String) onDeleteItem;

  @override
  State<_ContainerCard> createState() => _ContainerCardState();
}

class _ContainerCardState extends State<_ContainerCard> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items =
        widget.container['items'] as List<dynamic>? ?? <Map<String, dynamic>>[];
    final name = widget.container['name'] as String? ?? 'Container';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              _isExpanded ? Icons.folder_open : Icons.folder,
              color: theme.colorScheme.primary,
            ),
            title: Text(
              name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text('${items.length} items'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: widget.onAddItem,
                  tooltip: 'Add item',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: widget.onDeleteContainer,
                  tooltip: 'Delete container',
                ),
                IconButton(
                  icon: Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                ),
              ],
            ),
          ),
          if (_isExpanded && items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                children: items.map((item) {
                  final itemMap = item as Map<String, dynamic>;
                  return ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Text(itemMap['name'] as String? ?? 'Item'),
                    subtitle: itemMap['description'] != null &&
                            (itemMap['description'] as String).isNotEmpty
                        ? Text(itemMap['description'] as String)
                        : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () =>
                          widget.onDeleteItem(itemMap['id'] as String),
                    ),
                    dense: true,
                  );
                }).toList(),
              ),
            ),
          if (_isExpanded && items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'No items. Tap + to add one.',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }
}

class _CreateContainerDialog extends StatefulWidget {
  @override
  State<_CreateContainerDialog> createState() => _CreateContainerDialogState();
}

class _CreateContainerDialogState extends State<_CreateContainerDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Container'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Container name',
          hintText: 'e.g., Backpack, Belt Pouch...',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
        textCapitalization: TextCapitalization.words,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _CreateItemDialog extends StatefulWidget {
  @override
  State<_CreateItemDialog> createState() => _CreateItemDialogState();
}

class _CreateItemDialogState extends State<_CreateItemDialog> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Item'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Item name',
                hintText: 'e.g., Rope, Torch...',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'e.g., 50ft hemp rope',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop({
              'name': name,
              'description': _descController.text.trim(),
            });
          },
          child: const Text('Add'),
        ),
      ],
    );
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

// ============================================================================
// ENHANCEMENT CARD
// ============================================================================

class _EnhancementCard extends StatefulWidget {
  final DowntimeEntry enhancement;

  const _EnhancementCard({required this.enhancement});

  @override
  State<_EnhancementCard> createState() => _EnhancementCardState();
}

class _EnhancementCardState extends State<_EnhancementCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  String _getTypeDisplay(String enhancementType) {
    switch (enhancementType) {
      case 'armor_enhancement':
        return 'Armor';
      case 'weapon_enhancement':
        return 'Weapon';
      case 'implement_enhancement':
        return 'Implement';
      case 'shield_enhancement':
        return 'Shield';
      default:
        return enhancementType.replaceAll('_', ' ');
    }
  }

  IconData _getTypeIcon(String enhancementType) {
    switch (enhancementType) {
      case 'armor_enhancement':
        return Icons.shield;
      case 'weapon_enhancement':
        return Icons.sports_martial_arts;
      case 'implement_enhancement':
        return Icons.auto_awesome;
      case 'shield_enhancement':
        return Icons.security;
      default:
        return Icons.auto_fix_high;
    }
  }

  Color _getLevelColor(int level) {
    if (level <= 2) {
      return Colors.green.shade400;
    } else if (level <= 4) {
      return Colors.blue.shade400;
    } else if (level <= 6) {
      return Colors.purple.shade400;
    } else if (level <= 8) {
      return Colors.orange.shade400;
    } else {
      return Colors.red.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enhancementType = widget.enhancement.raw['type'] as String? ?? '';
    final level = widget.enhancement.raw['level'] as int?;
    final description = widget.enhancement.raw['description'] as String? ?? '';
    final typeDisplay = _getTypeDisplay(enhancementType);
    final typeIcon = _getTypeIcon(enhancementType);

    // Use orange scheme matching treasure card styling exactly
    const primaryColor = Colors.orange;
    final cardBorderColor = theme.brightness == Brightness.dark
      ? primaryColor.shade600.withOpacity(0.3)
      : primaryColor.shade300.withOpacity(0.5);
    final cardBgColor = theme.brightness == Brightness.dark
      ? const Color.fromARGB(255, 37, 36, 36)
      : Colors.white;

    return Card(
      margin: EdgeInsets.zero,
      color: cardBgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: cardBorderColor,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: _toggleExpanded,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with name and expand icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.shade700,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      typeIcon,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.enhancement.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Type and level tags
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.shade700,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      typeDisplay.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (level != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getLevelColor(level),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'LEVEL $level',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              // Expandable content
              SizeTransition(
                sizeFactor: _expandAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.dark
                            ? primaryColor.shade800.withOpacity(0.2)
                            : primaryColor.shade50.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.brightness == Brightness.dark
                              ? primaryColor.shade600.withOpacity(0.5)
                              : primaryColor.shade300.withOpacity(0.8),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.auto_fix_high,
                                  size: 14,
                                  color: primaryColor.shade400,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'EFFECT',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: primaryColor.shade400,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              description,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.5,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}