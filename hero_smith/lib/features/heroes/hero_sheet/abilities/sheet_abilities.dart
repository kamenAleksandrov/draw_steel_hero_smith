import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/providers.dart';
import '../../../../core/models/component.dart';
import '../../../../core/repositories/hero_entry_repository.dart';
import '../../../../core/repositories/hero_repository.dart';
import '../../../../core/services/class_data_service.dart';
import '../../../../core/services/kit_bonus_service.dart';
import '../../../../core/services/perk_grants_service.dart';
import '../../../../core/theme/kit_theme.dart';
import '../main_stats/hero_main_stats_providers.dart';
import 'ability_list_view.dart';
import 'add_ability_dialog.dart';
import 'common_abilities_view.dart';
import 'equipment_constants.dart';
import 'equipment_dialogs.dart';
import 'sheet_abilities_providers.dart';

// Re-export providers for backwards compatibility
export 'sheet_abilities_providers.dart';

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

class _SheetAbilitiesState extends ConsumerState<SheetAbilities> {
  List<EquipmentSlotConfig> _equipmentSlots = [];
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

  List<EquipmentSlotConfig> _determineEquipmentSlots(dynamic classData, String? subclassName) {
    if (classData == null) {
      return [EquipmentSlotConfig(label: 'Kit', allowedTypes: ['kit'], index: 0)];
    }
    
    // Special case: Stormwight Fury - only stormwight kits
    final subclass = subclassName?.toLowerCase() ?? '';
    if (classData.classId == 'class_fury' && subclass == 'stormwight') {
      return [EquipmentSlotConfig(label: 'Stormwight Kit', allowedTypes: ['stormwight_kit'], index: 0)];
    }
    
    final kitFeatures = <Map<String, dynamic>>[];
    final typesList = <String>[];
    
    // Collect all kit-related features
    for (final level in classData.levels) {
      for (final feature in level.features) {
        final name = feature.name.trim().toLowerCase();
        if (name == 'kit' || EquipmentConstants.kitFeatureTypeMappings.containsKey(name)) {
          kitFeatures.add({
            'name': name,
            'count': feature.count ?? 1,
          });
          
          final mapped = EquipmentConstants.kitFeatureTypeMappings[name];
          if (mapped != null) {
            typesList.addAll(mapped);
          } else if (name == 'kit') {
            typesList.add('kit');
          }
        }
      }
    }
    
    if (kitFeatures.isEmpty) {
      return [EquipmentSlotConfig(label: 'Kit', allowedTypes: ['kit'], index: 0)];
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
    final configs = <EquipmentSlotConfig>[];
    var index = 0;
    
    // If we have multiple types and count >= uniqueTypes.length, create one slot per type
    if (uniqueTypes.length > 1 && totalCount >= uniqueTypes.length) {
      for (final type in uniqueTypes) {
        configs.add(EquipmentSlotConfig(
          label: EquipmentConstants.formatTypeName(type),
          allowedTypes: [type],
          index: index++,
        ));
      }
    } else {
      // Otherwise, create slots with all allowed types
      final sortedTypes = EquipmentConstants.sortByPriority(uniqueTypes);
      for (var i = 0; i < totalCount; i++) {
        final label = totalCount > 1 
            ? '${EquipmentConstants.formatTypeName(sortedTypes.first)} ${i + 1}'
            : EquipmentConstants.formatTypeName(sortedTypes.first);
        configs.add(EquipmentSlotConfig(
          label: label,
          allowedTypes: sortedTypes,
          index: index++,
        ));
      }
    }
    
    return configs.isEmpty 
        ? [EquipmentSlotConfig(label: 'Kit', allowedTypes: ['kit'], index: 0)]
        : configs;
  }

  Future<void> _changeEquipment() async {
    if (_equipmentSlots.isEmpty) return;
    
    // If only one slot, open selection directly
    if (_equipmentSlots.length == 1) {
      await _showEquipmentSelectionForSlot(_equipmentSlots.first);
      return;
    }
    
    // If 2 or more slots, show a menu to choose which to change
    final slot = await showDialog<EquipmentSlotConfig>(
      context: context,
      builder: (context) => EquipmentSlotMenuDialog(
        slots: _equipmentSlots,
        selectedIds: _selectedEquipmentIds,
        onFindItem: _findItemById,
      ),
    );
    
    if (slot != null && mounted) {
      await _showEquipmentSelectionForSlot(slot);
    }
  }
  
  Future<void> _showEquipmentSelectionForSlot(EquipmentSlotConfig slot) async {
    final currentId = slot.index < _selectedEquipmentIds.length 
        ? _selectedEquipmentIds[slot.index] 
        : null;
    
    final selected = await showDialog<String?>(
      context: context,
      builder: (context) => SheetEquipmentSelectionDialog(
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
      builder: (context) => AddAbilityDialog(heroId: widget.heroId),
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

                              return AbilityListView(
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
                          const CommonAbilitiesView(),
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
                EquipmentConstants.equipmentTypeIcons[slot.allowedTypes.first] ?? Icons.inventory_2_outlined,
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
              builder: (dialogContext) => KitPreviewDialog(item: item),
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
                  EquipmentConstants.equipmentTypeIcons[item.type] ?? Icons.inventory_2_outlined,
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

