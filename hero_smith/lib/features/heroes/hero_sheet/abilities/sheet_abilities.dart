import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/providers.dart';
import '../../../../core/models/component.dart';
import '../../../../core/repositories/hero_entry_repository.dart';
import '../../../../core/repositories/hero_repository.dart';
import '../../../../core/services/ability_data_service.dart';
import '../../../../core/services/class_data_service.dart';
import '../../../../core/services/kit_bonus_service.dart';
import '../../../../core/services/perk_grants_service.dart';
import '../../../../core/theme/kit_theme.dart';
import '../state/hero_main_stats_providers.dart';
import '../../../../widgets/abilities/abilities_shared.dart';
import '../../../../widgets/abilities/ability_expandable_item.dart';
import '../../../../widgets/abilities/ability_summary.dart';
import '../../../../widgets/kits/kit_card.dart';
import '../../../../widgets/kits/modifier_card.dart';
import '../../../../widgets/kits/stormwight_kit_card.dart';
import '../../../../widgets/kits/ward_card.dart';

/// Provider that watches hero ability IDs for a specific hero.
/// 
/// All abilities are now stored in hero_entries with entryType='ability'.
/// Sources include:
/// - manual_choice: abilities chosen directly (class ability picks)
/// - ancestry: abilities from ancestry traits
/// - complication: abilities from complications
/// - kit: abilities from equipped kits
/// - perk: abilities from perks
/// - title: abilities from title benefits
/// - class_feature: abilities from class features
final heroAbilityIdsProvider =
    StreamProvider.family<List<String>, String>((ref, heroId) {
  final db = ref.watch(appDatabaseProvider);

  // Watch all abilities from hero_entries table
  // This automatically includes all sources (ancestry, complication, kit, perk, title, etc.)
  return db.watchHeroComponentIds(heroId, 'ability');
});

/// Provider that watches hero equipment IDs for a specific hero
final heroEquipmentIdsProvider =
    StreamProvider.family<List<String?>, String>((ref, heroId) {
  final db = ref.watch(appDatabaseProvider);

  // Watch equipment.slots from hero_config (primary storage)
  return db.watchHeroConfigValue(heroId, 'equipment.slots').asyncMap((config) async {
    if (config != null && config['ids'] is List) {
      return (config['ids'] as List)
          .map<String?>((e) => e == null ? null : e.toString())
          .toList();
    }

    // Fall back to hero_entries for equipment without slot ordering
    final entryIds = await db.getHeroEntryIds(heroId, 'equipment');
    if (entryIds.isNotEmpty) return entryIds.map<String?>((e) => e).toList();

    // Fall back to legacy kit entry
    final kitEntry = await db.getSingleHeroEntryId(heroId, 'kit');
    if (kitEntry != null) return <String?>[kitEntry];

    // Final fallback: legacy hero_values
    final legacyValues = await db.getHeroValues(heroId);
    for (final value in legacyValues) {
      if (value.key == 'basics.equipment') {
        if (value.jsonValue != null) {
          try {
            final decoded = jsonDecode(value.jsonValue!);
            if (decoded is Map && decoded['ids'] is List) {
              return (decoded['ids'] as List)
                  .map<String?>((e) => e == null ? null : e.toString())
                  .toList();
            }
          } catch (_) {}
        }
      } else if (value.key == 'basics.kit') {
        final kitId = value.textValue;
        if (kitId != null && kitId.isNotEmpty) {
          return <String?>[kitId];
        }
      }
    }
    return <String?>[];
  });
});

/// Shows active, passive, and situational abilities available to the hero.
class SheetAbilities extends ConsumerStatefulWidget {
  const SheetAbilities({
    super.key,
    required this.heroId,
  });

  final String heroId;

  @override
  ConsumerState<SheetAbilities> createState() => _SheetAbilitiesState();
}

/// Equipment slot configuration for the hero sheet
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

class _SheetAbilitiesState extends ConsumerState<SheetAbilities> {
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

  static const Map<String, IconData> _equipmentTypeIcons = {
    'kit': Icons.backpack_outlined,
    'psionic_augmentation': Icons.auto_awesome,
    'enchantment': Icons.auto_fix_high,
    'prayer': Icons.self_improvement,
    'ward': Icons.shield_outlined,
    'stormwight_kit': Icons.pets_outlined,
  };

  List<_EquipmentSlotConfig> _equipmentSlots = [];
  // ignore: unused_field
  bool _isLoadingSlotsConfig = true;
  bool _isLoadingEquipment = true;
  List<String?> _selectedEquipmentIds = [];
  // ignore: unused_field
  String? _className;
  // ignore: unused_field
  String? _subclassName;
  bool _perkGrantsEnsured = false;

  @override
  void initState() {
    super.initState();
    _loadEquipmentSlotConfig();
    _ensurePerkGrants();
  }
  
  /// Ensure all perk grants are applied when the abilities sheet loads.
  /// This handles cases where perks were added outside the PerksSelectionWidget.
  Future<void> _ensurePerkGrants() async {
    if (_perkGrantsEnsured) return;
    _perkGrantsEnsured = true;
    
    try {
      final db = ref.read(appDatabaseProvider);
      await PerkGrantsService().ensureAllPerkGrantsApplied(
        db: db,
        heroId: widget.heroId,
      );
    } catch (e) {
      debugPrint('Failed to ensure perk grants: $e');
    }
  }
  
  /// Updates local state from the provider when equipment changes
  void _updateEquipmentFromProvider(List<String?> equipmentIds) {
    if (!mounted) return;
    
    final normalized = equipmentIds
        .map((id) => id == null || id.isEmpty ? null : id)
        .toList();

    var changed = _selectedEquipmentIds.length != normalized.length;
    if (!changed) {
      for (var i = 0; i < normalized.length; i++) {
        if (_selectedEquipmentIds[i] != normalized[i]) {
          changed = true;
          break;
        }
      }
    }

    if (changed || _isLoadingEquipment) {
      setState(() {
        _selectedEquipmentIds = normalized;
        _isLoadingEquipment = false;
      });
    }
  }

  /// Load only the equipment slot configuration (class-based), not the selected IDs
  Future<void> _loadEquipmentSlotConfig() async {
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
      
      // Load class data to determine equipment slots
      final classDataService = ClassDataService();
      await classDataService.initialize();
      final classData = className != null ? classDataService.getClassById(className) : null;
      
      // Build equipment slots based on class
      final slots = _determineEquipmentSlots(classData, subclassName);
      
      if (mounted) {
        setState(() {
          _equipmentSlots = slots;
          _className = className;
          _subclassName = subclassName;
          _isLoadingSlotsConfig = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSlotsConfig = false;
        });
      }
    }
  }

  List<_EquipmentSlotConfig> _determineEquipmentSlots(dynamic classData, String? subclassName) {
    if (classData == null) {
      return [_EquipmentSlotConfig(label: 'Kit', allowedTypes: ['kit'], index: 0)];
    }
    
    // Special case: Stormwight Fury - only stormwight kits
    final subclass = subclassName?.toLowerCase() ?? '';
    if (classData.classId == 'class_fury' && subclass == 'stormwight') {
      return [_EquipmentSlotConfig(label: 'Stormwight Kit', allowedTypes: ['stormwight_kit'], index: 0)];
    }
    
    final kitFeatures = <Map<String, dynamic>>[];
    final typesList = <String>[];
    
    // Collect all kit-related features
    for (final level in classData.levels) {
      for (final feature in level.features) {
        final name = feature.name.trim().toLowerCase();
        if (name == 'kit' || _kitFeatureTypeMappings.containsKey(name)) {
          kitFeatures.add({
            'name': name,
            'count': feature.count ?? 1,
          });
          
          final mapped = _kitFeatureTypeMappings[name];
          if (mapped != null) {
            typesList.addAll(mapped);
          } else if (name == 'kit') {
            typesList.add('kit');
          }
        }
      }
    }
    
    if (kitFeatures.isEmpty) {
      return [_EquipmentSlotConfig(label: 'Kit', allowedTypes: ['kit'], index: 0)];
    }
    
    // Remove duplicates while preserving order
    final uniqueTypes = <String>[];
    final seen = <String>{};
    for (final type in typesList) {
      if (seen.add(type)) {
        uniqueTypes.add(type);
      }
    }
    
    // Calculate total count needed
    var totalCount = 0;
    for (final feature in kitFeatures) {
      totalCount += feature['count'] as int;
    }
    
    // Build slot configs
    final configs = <_EquipmentSlotConfig>[];
    var index = 0;
    
    // If we have multiple types and count >= uniqueTypes.length, create one slot per type
    if (uniqueTypes.length > 1 && totalCount >= uniqueTypes.length) {
      for (final type in uniqueTypes) {
        configs.add(_EquipmentSlotConfig(
          label: _formatTypeName(type),
          allowedTypes: [type],
          index: index++,
        ));
      }
    } else {
      // Otherwise, create slots with all allowed types
      final sortedTypes = _sortKitTypesByPriority(uniqueTypes);
      for (var i = 0; i < totalCount; i++) {
        final label = totalCount > 1 
            ? '${_formatTypeName(sortedTypes.first)} ${i + 1}'
            : _formatTypeName(sortedTypes.first);
        configs.add(_EquipmentSlotConfig(
          label: label,
          allowedTypes: sortedTypes,
          index: index++,
        ));
      }
    }
    
    return configs.isEmpty 
        ? [_EquipmentSlotConfig(label: 'Kit', allowedTypes: ['kit'], index: 0)]
        : configs;
  }
  
  String _formatTypeName(String type) {
    switch (type) {
      case 'psionic_augmentation':
        return 'Augmentation';
      case 'stormwight_kit':
        return 'Stormwight Kit';
      default:
        return type[0].toUpperCase() + type.substring(1);
    }
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

  Future<void> _changeEquipment() async {
    if (_equipmentSlots.isEmpty) return;
    
    // If only one slot, open selection directly
    if (_equipmentSlots.length == 1) {
      await _showEquipmentSelectionForSlot(_equipmentSlots.first);
      return;
    }
    
    // If 2 or more slots, show a menu to choose which to change
    final slot = await showDialog<_EquipmentSlotConfig>(
      context: context,
      builder: (context) => _EquipmentSlotMenuDialog(
        slots: _equipmentSlots,
        selectedIds: _selectedEquipmentIds,
        onFindItem: _findItemById,
      ),
    );
    
    if (slot != null && mounted) {
      await _showEquipmentSelectionForSlot(slot);
    }
  }
  
  Future<void> _showEquipmentSelectionForSlot(_EquipmentSlotConfig slot) async {
    final currentId = slot.index < _selectedEquipmentIds.length 
        ? _selectedEquipmentIds[slot.index] 
        : null;
    
    final selected = await showDialog<String?>(
      context: context,
      builder: (context) => _SheetEquipmentSelectionDialog(
        slotLabel: slot.label,
        allowedTypes: slot.allowedTypes,
        currentItemId: currentId,
        canRemove: currentId != null,
      ),
    );
    
    // Only proceed if user selected something (not cancelled)
    if (selected == null || !mounted) return;
    
    // Update the selection
    setState(() {
      while (_selectedEquipmentIds.length <= slot.index) {
        _selectedEquipmentIds.add(null);
      }
      if (selected == '__remove_item__') {
        _selectedEquipmentIds[slot.index] = null;
      } else {
        _selectedEquipmentIds[slot.index] = selected;
      }
    });
    
    // Save all equipment to database
    await _saveEquipmentToDatabase();
  }
  
  Future<void> _saveEquipmentToDatabase() async {
    try {
      final db = ref.read(appDatabaseProvider);
      final repo = ref.read(heroRepositoryProvider);
      final slotOrderedIds = List<String?>.from(_selectedEquipmentIds);

      // Persist for UI watchers
      await db.upsertHeroValue(
        heroId: widget.heroId,
        key: 'basics.equipment',
        jsonMap: {'ids': slotOrderedIds},
      );

      // Persist canonical equipment ordering + legacy kit value
      await repo.saveEquipmentIds(widget.heroId, slotOrderedIds);

      await _recalculateAndSaveEquipmentBonuses(repo, db, slotOrderedIds);

      ref.invalidate(heroEquipmentBonusesProvider(widget.heroId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save equipment: $e')),
        );
      }
    }
  }

  Future<void> _recalculateAndSaveEquipmentBonuses(
    HeroRepository heroRepo,
    dynamic db,
    List<String?> slotIds,
  ) async {
    final normalizedIds = slotIds
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();

    final heroLevel = await heroRepo.getHeroLevel(widget.heroId);
    final kitBonusService = const KitBonusService();

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

    final equipmentComponents = <Component>[];
    for (final id in normalizedIds) {
      final componentRow = await db.getComponentById(id);
      if (componentRow == null) continue;
      final data = _decodeComponentData(componentRow.dataJson);
      equipmentComponents.add(Component(
        id: componentRow.id,
        type: componentRow.type,
        name: componentRow.name,
        data: data,
      ));
    }

    if (equipmentComponents.isEmpty) {
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

    final bonuses = kitBonusService.calculateBonuses(
      equipment: equipmentComponents,
      heroLevel: heroLevel,
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

  Map<String, dynamic> _decodeComponentData(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return Map<String, dynamic>.from(decoded);
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded.cast<String, dynamic>());
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  Future<void> _showAddAbilityDialog(BuildContext context) async {
    final selectedAbilityId = await showDialog<String?>(
      context: context,
      builder: (context) => _AddAbilityDialog(heroId: widget.heroId),
    );

    if (selectedAbilityId != null && mounted) {
      // Add the ability to the hero
      await _addAbilityToHero(selectedAbilityId);
    }
  }

  Future<void> _addAbilityToHero(String abilityId) async {
    try {
      final db = ref.read(appDatabaseProvider);
      final entries = HeroEntryRepository(db);
      
      // Check if ability is already added with manual_choice source
      final existingEntries = await entries.listEntriesByType(widget.heroId, 'ability');
      final alreadyAdded = existingEntries.any(
        (e) => e.entryId == abilityId && e.sourceType == 'manual_choice',
      );
      
      if (alreadyAdded) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ability already added')),
          );
        }
        return;
      }

      // Add ability to hero_entries with sourceType='manual_choice'
      await entries.addEntry(
        heroId: widget.heroId,
        entryType: 'ability',
        entryId: abilityId,
        sourceType: 'manual_choice',
        sourceId: 'sheet_add',
        gainedBy: 'choice',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ability added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add ability: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the ability IDs stream
    final abilityIdsAsync = ref.watch(heroAbilityIdsProvider(widget.heroId));
    
    // Watch equipment IDs and update local state for reactive updates
    final equipmentIdsAsync = ref.watch(heroEquipmentIdsProvider(widget.heroId));
    equipmentIdsAsync.whenData(_updateEquipmentFromProvider);
    
    final theme = Theme.of(context);

    return Stack(
      children: [
        Column(
          children: [
            // Compact equipment bar
            if (!_isLoadingEquipment) _buildCompactEquipmentBar(context),
            
            // Abilities tabs - takes all remaining space
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    // Compact tab bar
                    TabBar(
                      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                      tabs: const [
                        Tab(text: 'Hero Abilities'),
                        Tab(text: 'Common Abilities'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Hero-specific abilities tab
                          abilityIdsAsync.when(
                            data: (abilityIds) {
                              if (abilityIds.isEmpty) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.bolt_outlined,
                                            size: 48, color: theme.colorScheme.outline),
                                        const SizedBox(height: 12),
                                        Text(
                                          'No Abilities Yet',
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            color: theme.colorScheme.outline,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Tap + to add abilities',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              return _AbilityListView(
                                abilityIds: abilityIds,
                                heroId: widget.heroId,
                              );
                            },
                            loading: () =>
                                const Center(child: CircularProgressIndicator()),
                            error: (error, stack) => Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.error_outline,
                                        size: 48, color: Colors.red),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Error loading abilities',
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      error.toString(),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.outline,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Common abilities tab
                          const _CommonAbilitiesView(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        // Floating Action Button for adding abilities
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: () => _showAddAbilityDialog(context),
            tooltip: 'Add Ability',
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  /// Compact equipment bar - single row with chips and edit button
  Widget _buildCompactEquipmentBar(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Equipment chips in a scrollable row
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < _equipmentSlots.length; i++) ...[
                    _buildCompactEquipmentChip(context, i),
                    if (i < _equipmentSlots.length - 1) const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Compact edit button
          IconButton(
            onPressed: _changeEquipment,
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Change Equipment',
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              minimumSize: const Size(36, 36),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  /// Compact equipment chip for the bar
  Widget _buildCompactEquipmentChip(BuildContext context, int slotIndex) {
    final theme = Theme.of(context);
    final slot = _equipmentSlots[slotIndex];
    final selectedId = slotIndex < _selectedEquipmentIds.length 
        ? _selectedEquipmentIds[slotIndex] 
        : null;
    
    if (selectedId == null) {
      // Empty slot - minimal placeholder
      return InkWell(
        onTap: () async {
          await _showEquipmentSelectionForSlot(slot);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.4),
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _equipmentTypeIcons[slot.allowedTypes.first] ?? Icons.inventory_2_outlined,
                size: 14,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(width: 4),
              Text(
                slot.label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Selected equipment - show name
    return FutureBuilder<Component?>(
      future: _findItemById(selectedId),
      builder: (context, snapshot) {
        final item = snapshot.data;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        
        if (isLoading) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            child: const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
          );
        }
        
        if (item == null) {
          return InkWell(
            onTap: () async {
              await _showEquipmentSelectionForSlot(slot);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: theme.colorScheme.errorContainer.withOpacity(0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 14, color: theme.colorScheme.error),
                  const SizedBox(width: 4),
                  Text(
                    'Missing',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        final borderColor = _getBorderColorForType(item.type);
        return InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (dialogContext) => _KitPreviewDialog(item: item),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: borderColor.withOpacity(0.15),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _equipmentTypeIcons[item.type] ?? Icons.inventory_2_outlined,
                  size: 14,
                  color: borderColor,
                ),
                const SizedBox(width: 4),
                Text(
                  item.name,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getBorderColorForType(String type) {
    final colorScheme = KitTheme.getColorScheme(type);
    return colorScheme.borderColor;
  }

  Future<Component?> _findItemById(String itemId) async {
    // Try all equipment types
    const allTypes = ['kit', 'stormwight_kit', 'ward', 'psionic_augmentation', 'enchantment', 'prayer'];
    for (final type in allTypes) {
      final components = await ref.read(componentsByTypeProvider(type).future);
      for (final component in components) {
        if (component.id == itemId) {
          return component;
        }
      }
    }
    return null;
  }
}

/// Dialog for selecting which equipment slot to change when hero has multiple slots
class _EquipmentSlotMenuDialog extends StatelessWidget {
  const _EquipmentSlotMenuDialog({
    required this.slots,
    required this.selectedIds,
    required this.onFindItem,
  });

  final List<_EquipmentSlotConfig> slots;
  final List<String?> selectedIds;
  final Future<Component?> Function(String) onFindItem;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Equipment to Change'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < slots.length; i++)
            _buildSlotOption(context, slots[i], i),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
  
  Widget _buildSlotOption(BuildContext context, _EquipmentSlotConfig slot, int index) {
    final theme = Theme.of(context);
    final selectedId = index < selectedIds.length ? selectedIds[index] : null;
    
    return ListTile(
      leading: Icon(
        _SheetAbilitiesState._equipmentTypeIcons[slot.allowedTypes.first] ?? Icons.inventory_2_outlined,
      ),
      title: Text(slot.label),
      subtitle: selectedId == null 
          ? Text('Not selected', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)))
          : FutureBuilder<Component?>(
              future: onFindItem(selectedId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Text('Loading...');
                }
                return Text(snapshot.data?.name ?? 'Unknown');
              },
            ),
      onTap: () => Navigator.of(context).pop(slot),
    );
  }
}

/// Equipment selection dialog for the hero sheet (similar to creator but adapted)
class _SheetEquipmentSelectionDialog extends ConsumerStatefulWidget {
  const _SheetEquipmentSelectionDialog({
    required this.slotLabel,
    required this.allowedTypes,
    required this.currentItemId,
    required this.canRemove,
  });

  final String slotLabel;
  final List<String> allowedTypes;
  final String? currentItemId;
  final bool canRemove;

  @override
  ConsumerState<_SheetEquipmentSelectionDialog> createState() => _SheetEquipmentSelectionDialogState();
}

class _SheetEquipmentSelectionDialogState extends ConsumerState<_SheetEquipmentSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const List<String> _allEquipmentTypes = [
    'kit', 'psionic_augmentation', 'enchantment', 'prayer', 'ward', 'stormwight_kit',
  ];

  static const Map<String, String> _equipmentTypeTitles = {
    'kit': 'Standard Kits',
    'psionic_augmentation': 'Psionic Augmentations',
    'enchantment': 'Enchantments',
    'prayer': 'Prayers',
    'ward': 'Wards',
    'stormwight_kit': 'Stormwight Kits',
  };

  static const Map<String, IconData> _equipmentTypeIcons = {
    'kit': Icons.backpack_outlined,
    'psionic_augmentation': Icons.auto_awesome,
    'enchantment': Icons.auto_fix_high,
    'prayer': Icons.self_improvement,
    'ward': Icons.shield_outlined,
    'stormwight_kit': Icons.pets_outlined,
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _normalizeAllowedTypes() {
    final normalized = <String>{};
    for (final type in widget.allowedTypes) {
      final trimmed = type.trim().toLowerCase();
      if (trimmed.isNotEmpty) {
        normalized.add(trimmed);
      }
    }
    if (normalized.isEmpty) {
      normalized.addAll(_allEquipmentTypes);
    }
    return normalized.toList();
  }

  List<String> _sortEquipmentTypes(Iterable<String> types) {
    final seen = <String>{};
    final sorted = <String>[];
    for (final type in _allEquipmentTypes) {
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

  String _titleize(String value) {
    if (value.isEmpty) return value;
    return value
        .split(RegExp(r'[_\s]+'))
        .where((segment) => segment.isNotEmpty)
        .map((segment) => '${segment[0].toUpperCase()}${segment.substring(1).toLowerCase()}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final normalized = _normalizeAllowedTypes();
    final sorted = _sortEquipmentTypes(normalized);
    
    final categories = <({String type, String label, IconData icon, AsyncValue<List<Component>> data})>[];
    for (final type in sorted) {
      categories.add((
        type: type,
        label: _equipmentTypeTitles[type] ?? _titleize(type),
        icon: _equipmentTypeIcons[type] ?? Icons.inventory_2_outlined,
        data: ref.watch(componentsByTypeProvider(type)),
      ));
    }
    
    final navigator = Navigator.of(context);
    final hasMultipleCategories = categories.length > 1;

    if (categories.isEmpty) {
      return Dialog(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text('Select ${widget.slotLabel}'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => navigator.pop(),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('No items available'),
              ),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: categories.length,
      child: Dialog(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            children: [
              AppBar(
                title: Text('Select ${widget.slotLabel}'),
                automaticallyImplyLeading: false,
                actions: [
                  if (widget.canRemove)
                    TextButton.icon(
                      onPressed: () => navigator.pop('__remove_item__'),
                      icon: const Icon(Icons.clear, color: Colors.white),
                      label: const Text('Remove', style: TextStyle(color: Colors.white)),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => navigator.pop(),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search equipment...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _searchController.clear();
                              });
                            },
                          ),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.trim().toLowerCase();
                    });
                  },
                ),
              ),
              if (hasMultipleCategories)
                Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: TabBar(
                    isScrollable: true,
                    tabs: categories.map((cat) {
                      final count = cat.data.maybeWhen(
                        data: (items) => items.length,
                        orElse: () => null,
                      );
                      final label = count == null ? cat.label : '${cat.label} ($count)';
                      return Tab(text: label, icon: Icon(cat.icon, size: 18));
                    }).toList(),
                  ),
                ),
              Expanded(
                child: hasMultipleCategories
                    ? TabBarView(
                        children: [
                          for (final category in categories)
                            _buildCategoryList(context, category.type, category.label, category.data),
                        ],
                      )
                    : _buildCategoryList(context, categories.first.type, categories.first.label, categories.first.data),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryList(
    BuildContext context,
    String type,
    String label,
    AsyncValue<List<Component>> data,
  ) {
    final query = _searchQuery;
    final theme = Theme.of(context);

    return data.when(
      data: (items) {
        final filtered = query.isEmpty
            ? items
            : items.where((item) {
                final name = item.name.toLowerCase();
                final description = (item.data['description'] as String?)?.toLowerCase() ?? '';
                return name.contains(query) || description.contains(query);
              }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                query.isEmpty
                    ? 'No ${label.toLowerCase()} available'
                    : 'No results for "${_searchController.text}"',
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final item = filtered[index];
            final isSelected = item.id == widget.currentItemId;
            final description = item.data['description'] as String?;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => Navigator.of(context).pop(item.id),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                        : theme.colorScheme.surface,
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline.withOpacity(0.5),
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isSelected)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Icon(
                                Icons.check_circle,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              item.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isSelected ? theme.colorScheme.primary : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (description != null && description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.8),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text('Error loading ${label.toLowerCase()}: $error'),
        ),
      ),
    );
  }
}

class _KitPreviewDialog extends StatelessWidget {
  const _KitPreviewDialog({
    required this.item,
  });

  final Component item;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(item.name),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                child: _buildCardForComponent(item),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardForComponent(Component item) {
    switch (item.type) {
      case 'kit':
        return KitCard(component: item, initiallyExpanded: true);
      case 'stormwight_kit':
        return StormwightKitCard(component: item, initiallyExpanded: true);
      case 'ward':
        return WardCard(component: item, initiallyExpanded: true);
      case 'psionic_augmentation':
      case 'enchantment':
      case 'prayer':
        return ModifierCard(component: item, badgeLabel: item.type, initiallyExpanded: true);
      default:
        return KitCard(component: item, initiallyExpanded: true);
    }
  }
}

class _AbilityListView extends ConsumerStatefulWidget {
  const _AbilityListView({required this.abilityIds, required this.heroId});

  final List<String> abilityIds;
  final String heroId;

  @override
  ConsumerState<_AbilityListView> createState() => _AbilityListViewState();
}

/// Enum for action type categories
enum _ActionCategory {
  actions,
  maneuvers,
  triggered,
}

extension _ActionCategoryLabel on _ActionCategory {
  String get label {
    switch (this) {
      case _ActionCategory.actions:
        return 'Actions';
      case _ActionCategory.maneuvers:
        return 'Maneuvers';
      case _ActionCategory.triggered:
        return 'Triggered';
    }
  }
  
  IconData get icon {
    switch (this) {
      case _ActionCategory.actions:
        return Icons.flash_on;
      case _ActionCategory.maneuvers:
        return Icons.directions_run;
      case _ActionCategory.triggered:
        return Icons.bolt;
    }
  }
}

class _AbilityListViewState extends ConsumerState<_AbilityListView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _ActionCategory.values.length, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Categorize an ability into an action category based on action_type
  _ActionCategory _categorizeAbility(Component ability) {
    final data = ability.data;
    final actionType = (data['action_type']?.toString().toLowerCase() ?? '').trim();
    
    // Categorize by action_type
    if (actionType.contains('triggered')) {
      return _ActionCategory.triggered;
    }
    if (actionType.contains('maneuver')) {
      return _ActionCategory.maneuvers;
    }
    if (actionType.contains('action')) {
      return _ActionCategory.actions;
    }
    
    // Fallback: check trigger field for older data format
    final trigger = data['trigger']?.toString().toLowerCase() ?? '';
    if (trigger == 'triggered' || trigger == 'free triggered') {
      return _ActionCategory.triggered;
    }
    if (trigger == 'maneuver' || trigger == 'free maneuver') {
      return _ActionCategory.maneuvers;
    }
    
    // Default to actions
    return _ActionCategory.actions;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return FutureBuilder<List<Component>>(
      future: _loadAbilityComponents(widget.abilityIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading ability details',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final abilities = snapshot.data ?? [];

        if (abilities.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'No ability details found',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        // Group abilities by action category
        final grouped = <_ActionCategory, List<Component>>{};
        for (final category in _ActionCategory.values) {
          grouped[category] = [];
        }
        
        for (final ability in abilities) {
          final category = _categorizeAbility(ability);
          grouped[category]!.add(ability);
        }
        
        // Sort each category by cost (resource_value)
        for (final category in _ActionCategory.values) {
          grouped[category]!.sort((a, b) {
            final costA = (a.data['resource_value'] as num?)?.toInt() ?? 0;
            final costB = (b.data['resource_value'] as num?)?.toInt() ?? 0;
            return costA.compareTo(costB);
          });
        }

        return Column(
          children: [
            // Tab bar for action types
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              tabs: [
                for (final category in _ActionCategory.values)
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(category.icon, size: 16),
                        const SizedBox(width: 4),
                        Text(category.label),
                        if (grouped[category]!.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              grouped[category]!.length.toString(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
            // Tab views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  for (final category in _ActionCategory.values)
                    _buildCategoryList(grouped[category]!, category),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildCategoryList(List<Component> abilities, _ActionCategory category) {
    final theme = Theme.of(context);
    
    if (abilities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(category.icon, size: 48, color: theme.colorScheme.outline),
              const SizedBox(height: 12),
              Text(
                'No ${category.label}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Abilities of this type will appear here',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: abilities.length,
      itemBuilder: (context, index) {
        return _buildAbilityWithRemove(abilities[index]);
      },
    );
  }

  Widget _buildAbilityWithRemove(Component ability) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Stack(
        children: [
          AbilityExpandableItem(component: ability),
          Positioned(
            top: 18,
            right: 18,
            child: IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => _removeAbility(ability.id),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.6),
                foregroundColor: Colors.white70,
                padding: const EdgeInsets.all(6),
                minimumSize: const Size(32, 32),
              ),
              tooltip: 'Remove ability',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _removeAbility(String abilityId) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Ability'),
        content: const Text('Are you sure you want to remove this ability from your hero?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final db = ref.read(appDatabaseProvider);
      final entries = HeroEntryRepository(db);
      
      // Remove the ability entry from hero_entries
      // Only remove if it was manually added (sourceType='manual_choice')
      // First get the entries to find the one matching our criteria
      final existingEntries = await entries.listEntriesByType(widget.heroId, 'ability');
      final toRemove = existingEntries.where(
        (e) => e.entryId == abilityId && e.sourceType == 'manual_choice',
      ).toList();
      
      for (final entry in toRemove) {
        await db.customStatement(
          'DELETE FROM hero_entries WHERE id = ?',
          [entry.id],
        );
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ability removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove ability: $e')),
        );
      }
    }
  }

  Future<List<Component>> _loadAbilityComponents(
    List<String> abilityIds,
  ) async {
    final library = await AbilityDataService().loadLibrary();
    final components = <Component>[];
    final missingIds = <String>[];

    for (final id in abilityIds) {
      try {
        final component = library.byId(id) ?? library.find(id);
        if (component != null) {
          components.add(component);
        } else {
          missingIds.add(id);
        }
      } catch (e) {
        debugPrint('Failed to resolve ability $id: $e');
        missingIds.add(id);
      }
    }

    // Check the database for any abilities not found in the library
    // (e.g., perk-granted abilities that were dynamically inserted)
    if (missingIds.isNotEmpty) {
      final db = ref.read(appDatabaseProvider);
      for (final id in missingIds) {
        try {
          final row = await db.getComponentById(id);
          if (row != null && row.type == 'ability') {
            Map<String, dynamic> data = {};
            if (row.dataJson.isNotEmpty) {
              data = jsonDecode(row.dataJson) as Map<String, dynamic>;
            }
            components.add(Component(
              id: row.id,
              type: row.type,
              name: row.name,
              data: data,
            ));
          }
        } catch (e) {
          debugPrint('Failed to load ability $id from database: $e');
        }
      }
    }

    return components;
  }

  // ignore: unused_element
  Widget _buildSectionHeader(BuildContext context, String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Displays common abilities available to all heroes
class _CommonAbilitiesView extends StatelessWidget {
  const _CommonAbilitiesView();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Component>>(
      future: _loadCommonAbilities(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading common abilities',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final abilities = snapshot.data ?? [];

        if (abilities.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'No common abilities found',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        // Group common abilities by category
        final maneuvers = <Component>[];
        final moveActions = <Component>[];
        final mainActions = <Component>[];
        final other = <Component>[];

        for (final ability in abilities) {
          final path = ability.data['ability_source_path'] as String? ?? '';
          if (path.contains('/Maneuvers/')) {
            maneuvers.add(ability);
          } else if (path.contains('/Move Actions/')) {
            moveActions.add(ability);
          } else if (path.contains('/Main Actions/')) {
            mainActions.add(ability);
          } else {
            other.add(ability);
          }
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (mainActions.isNotEmpty) ...[
              _buildSectionHeader(
                  context, 'Main Actions', mainActions.length),
              ...mainActions.map(
                  (ability) => AbilityExpandableItem(component: ability)),
              const SizedBox(height: 24),
            ],
            if (moveActions.isNotEmpty) ...[
              _buildSectionHeader(
                  context, 'Move Actions', moveActions.length),
              ...moveActions.map(
                  (ability) => AbilityExpandableItem(component: ability)),
              const SizedBox(height: 24),
            ],
            if (maneuvers.isNotEmpty) ...[
              _buildSectionHeader(context, 'Maneuvers', maneuvers.length),
              ...maneuvers
                  .map((ability) => AbilityExpandableItem(component: ability)),
              const SizedBox(height: 24),
            ],
            if (other.isNotEmpty) ...[
              _buildSectionHeader(context, 'Other', other.length),
              ...other
                  .map((ability) => AbilityExpandableItem(component: ability)),
            ],
          ],
        );
      },
    );
  }

  Future<List<Component>> _loadCommonAbilities() async {
    final library = await AbilityDataService().loadLibrary();
    final components = <Component>[];

    for (final component in library.components) {
      final path = component.data['ability_source_path'] as String? ?? '';
      final normalizedPath = path.toLowerCase();
      if (normalizedPath.contains('class_abilities_new/common/') ||
          normalizedPath.contains('class_abilities_simplified/common_abilities')) {
        components.add(component);
      }
    }

    // Sort by name
    components.sort((a, b) => a.name.compareTo(b.name));

    return components;
  }

  Widget _buildSectionHeader(BuildContext context, String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog for adding abilities to a hero with search and filters
class _AddAbilityDialog extends StatefulWidget {
  const _AddAbilityDialog({required this.heroId});

  final String heroId;

  @override
  State<_AddAbilityDialog> createState() => _AddAbilityDialogState();
}

class _AddAbilityDialogState extends State<_AddAbilityDialog> {
  String _searchQuery = '';
  String? _resourceFilter;
  String? _costFilter;
  String? _actionTypeFilter;
  String? _distanceFilter;
  String? _targetsFilter;
  List<Component>? _allAbilities;
  bool _isLoading = false;

  List<Component> get _filteredItems {
    if (_allAbilities == null) return [];
    
    var filtered = _allAbilities!;

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((item) => item.name.toLowerCase().contains(query)).toList();
    }

    if (_resourceFilter != null) {
      filtered = filtered.where((item) {
        final abilityData = AbilityData.fromComponent(item);
        final resourceLabel = abilityData.resourceLabel?.toLowerCase();
        return resourceLabel == _resourceFilter!.toLowerCase();
      }).toList();
    }

    if (_costFilter != null) {
      filtered = filtered.where((item) {
        final abilityData = AbilityData.fromComponent(item);
        if (_costFilter == 'signature') return abilityData.isSignature;
        final cost = abilityData.costAmount;
        if (cost == null) return false;
        return cost.toString() == _costFilter;
      }).toList();
    }

    if (_actionTypeFilter != null) {
      filtered = filtered.where((item) {
        final abilityData = AbilityData.fromComponent(item);
        final actionType = abilityData.actionType?.toLowerCase();
        return actionType == _actionTypeFilter!.toLowerCase();
      }).toList();
    }

    if (_distanceFilter != null) {
      filtered = filtered.where((item) {
        final abilityData = AbilityData.fromComponent(item);
        final distance = abilityData.rangeSummary?.toLowerCase();
        return distance?.contains(_distanceFilter!.toLowerCase()) ?? false;
      }).toList();
    }

    if (_targetsFilter != null) {
      filtered = filtered.where((item) {
        final abilityData = AbilityData.fromComponent(item);
        final targets = abilityData.targets?.toLowerCase();
        return targets?.contains(_targetsFilter!.toLowerCase()) ?? false;
      }).toList();
    }

    return filtered..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> _loadAbilities() async {
    if (_isLoading || _allAbilities != null) return;
    setState(() => _isLoading = true);
    try {
      final library = await AbilityDataService().loadLibrary();
      setState(() {
        _allAbilities = library.components.toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _triggerSearch() {
    // Load abilities if they haven't been loaded yet and user has interacted with search/filters
    if (_allAbilities == null) {
      _loadAbilities();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;
    
    // Extract unique filter options (only if abilities are loaded)
    final resourceOptions = _allAbilities
            ?.map((item) => AbilityData.fromComponent(item).resourceLabel)
            .where((type) => type != null && type.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList() ??
        [];
    if (resourceOptions.isNotEmpty) resourceOptions.sort();
    
    final costSet = <String>{};
    if (_allAbilities != null) {
      for (final item in _allAbilities!) {
        final ability = AbilityData.fromComponent(item);
        if (ability.isSignature) costSet.add('signature');
        final amount = ability.costAmount;
        if (amount != null && amount > 0) costSet.add(amount.toString());
      }
    }
    final costOptions = costSet.toList()..sort((a, b) {
      if (a == 'signature' && b == 'signature') return 0;
      if (a == 'signature') return -1;
      if (b == 'signature') return 1;
      final aInt = int.tryParse(a);
      final bInt = int.tryParse(b);
      if (aInt != null && bInt != null) return aInt.compareTo(bInt);
      return a.compareTo(b);
    });
    
    final actionTypeOptions = _allAbilities
            ?.map((item) => AbilityData.fromComponent(item).actionType)
            .where((type) => type != null && type.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList() ??
        [];
    if (actionTypeOptions.isNotEmpty) actionTypeOptions.sort();
    
    final distanceOptions = _allAbilities
            ?.map((item) => AbilityData.fromComponent(item).rangeSummary)
            .where((dist) => dist != null && dist.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList() ??
        [];
    if (distanceOptions.isNotEmpty) distanceOptions.sort();
    
    final targetsOptions = _allAbilities
            ?.map((item) => AbilityData.fromComponent(item).targets)
            .where((targets) => targets != null && targets.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList() ??
        [];
    if (targetsOptions.isNotEmpty) targetsOptions.sort();

    return Dialog(
      child: Container(
        constraints: BoxConstraints(maxWidth: 800, maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Column(
          children: [
            AppBar(
              title: const Text('Add Ability'),
              automaticallyImplyLeading: false,
              actions: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop())],
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildSearchAndFilters(context, resourceOptions: resourceOptions, costOptions: costOptions, actionTypeOptions: actionTypeOptions, distanceOptions: distanceOptions, targetsOptions: targetsOptions),
                    ),
                  ),
                  if (_isLoading) const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
                  else if (_allAbilities == null) SliverFillRemaining(child: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.search, size: 64, color: Colors.grey.shade400), const SizedBox(height: 16), Text('Search by name or select filters to load abilities', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center)]))))
                  else if (filtered.isEmpty) SliverFillRemaining(child: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.search_off, size: 64, color: Colors.grey.shade400), const SizedBox(height: 16), Text('No abilities found', style: TextStyle(color: Colors.grey))]))))
                  else SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) => _buildAbilitySummaryCard(filtered[index]), childCount: filtered.length))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAbilitySummaryCard(Component ability) => Card(margin: const EdgeInsets.only(bottom: 12), child: InkWell(onTap: () => Navigator.of(context).pop(ability.id), borderRadius: BorderRadius.circular(12), child: Padding(padding: const EdgeInsets.all(16), child: AbilitySummary(component: ability))));

  Widget _buildSearchAndFilters(BuildContext context, {required List<String> resourceOptions, required List<String> costOptions, required List<String> actionTypeOptions, required List<String> distanceOptions, required List<String> targetsOptions}) {
    final isEnabled = _allAbilities != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Search abilities by name...', 
                prefixIcon: const Icon(Icons.search), 
                suffixIcon: _searchQuery.isNotEmpty ? IconButton(
                  icon: const Icon(Icons.clear), 
                  onPressed: () { setState(() => _searchQuery = ''); }
                ) : null, 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
              ), 
              onChanged: (value) { 
                setState(() => _searchQuery = value); 
                if (!isEnabled) _triggerSearch();
              }
            ), 
            const SizedBox(height: 16), 
            Text('Filters', style: TextStyle(fontWeight: FontWeight.bold)), 
            const SizedBox(height: 12), 
            Wrap(
              spacing: 8, 
              runSpacing: 8, 
              children: [
                GestureDetector(
                  onTap: !isEnabled ? _triggerSearch : null,
                  child: _buildFilterDropdown(
                    context, 
                    label: 'Resource', 
                    value: _resourceFilter, 
                    options: resourceOptions, 
                    enabled: isEnabled,
                    onChanged: (value) { 
                      setState(() => _resourceFilter = value); 
                      _triggerSearch(); 
                    }
                  ),
                ), 
                GestureDetector(
                  onTap: !isEnabled ? _triggerSearch : null,
                  child: _buildFilterDropdown(
                    context, 
                    label: 'Cost', 
                    value: _costFilter == null ? null : (_costFilter == 'signature' ? 'Signature' : _costFilter), 
                    options: costOptions.map((c) => c == 'signature' ? 'Signature' : c).toList(), 
                    enabled: isEnabled,
                    onChanged: (value) { 
                      setState(() => _costFilter = value == 'Signature' ? 'signature' : value); 
                      _triggerSearch(); 
                    }
                  ),
                ), 
                GestureDetector(
                  onTap: !isEnabled ? _triggerSearch : null,
                  child: _buildFilterDropdown(
                    context, 
                    label: 'Action Type', 
                    value: _actionTypeFilter, 
                    options: actionTypeOptions, 
                    enabled: isEnabled,
                    onChanged: (value) { 
                      setState(() => _actionTypeFilter = value); 
                      _triggerSearch(); 
                    }
                  ),
                ), 
                GestureDetector(
                  onTap: !isEnabled ? _triggerSearch : null,
                  child: _buildFilterDropdown(
                    context, 
                    label: 'Distance', 
                    value: _distanceFilter, 
                    options: distanceOptions, 
                    enabled: isEnabled,
                    onChanged: (value) { 
                      setState(() => _distanceFilter = value); 
                      _triggerSearch(); 
                    }
                  ),
                ), 
                GestureDetector(
                  onTap: !isEnabled ? _triggerSearch : null,
                  child: _buildFilterDropdown(
                    context, 
                    label: 'Targets', 
                    value: _targetsFilter, 
                    options: targetsOptions, 
                    enabled: isEnabled,
                    onChanged: (value) { 
                      setState(() => _targetsFilter = value); 
                      _triggerSearch(); 
                    }
                  ),
                )
              ]
            )
          ]
        )
      )
    );
  }

  Widget _buildFilterDropdown(BuildContext context, {required String label, required String? value, required List<String> options, required void Function(String?) onChanged, bool enabled = true}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), 
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8), 
        border: Border.all(
          color: value != null ? theme.colorScheme.primary : (enabled ? theme.colorScheme.outline : theme.colorScheme.outline.withValues(alpha: 0.5)), 
          width: value != null ? 2 : 1
        )
      ), 
      child: DropdownButton<String>(
        value: value, 
        hint: Text(label, style: TextStyle(color: enabled ? null : theme.disabledColor)), 
        underline: const SizedBox.shrink(), 
        isDense: true, 
        items: enabled ? [
          DropdownMenuItem<String>(value: null, child: Text('All $label')), 
          ...options.map((option) => DropdownMenuItem<String>(value: option, child: Text(option)))
        ] : null, 
        onChanged: enabled ? onChanged : null,
      )
    );
  }
}
