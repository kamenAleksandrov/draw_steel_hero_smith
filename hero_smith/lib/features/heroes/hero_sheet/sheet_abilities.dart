import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/providers.dart';
import '../../../core/models/component.dart';
import '../../../core/services/ability_data_service.dart';
import '../../../core/services/class_data_service.dart';
import '../../../core/theme/kit_theme.dart';
import '../../../widgets/abilities/abilities_shared.dart';
import '../../../widgets/abilities/ability_expandable_item.dart';
import '../../../widgets/abilities/ability_summary.dart';
import '../../../widgets/kits/kit_card.dart';
import '../../../widgets/kits/modifier_card.dart';
import '../../../widgets/kits/stormwight_kit_card.dart';
import '../../../widgets/kits/ward_card.dart';

/// Provider that watches hero ability IDs for a specific hero
final heroAbilityIdsProvider =
    StreamProvider.family<List<String>, String>((ref, heroId) {
  final db = ref.watch(appDatabaseProvider);

  // Watch hero values and filter for ability component IDs
  return db.watchHeroValues(heroId).asyncMap((values) async {
    // Get manually selected abilities
    final abilityKey = 'component.ability';

    dynamic row;
    for (final value in values) {
      if (value.key == abilityKey) {
        row = value;
        break;
      }
    }

    final selectedAbilityIds = <String>[];

    if (row != null) {
      // Check if it's stored as JSON array
      if (row.jsonValue != null) {
        try {
          final decoded = jsonDecode(row.jsonValue!);
          if (decoded is Map && decoded['ids'] is List) {
            selectedAbilityIds.addAll(
              (decoded['ids'] as List).map((e) => e.toString()),
            );
          }
        } catch (_) {
          // Ignore parsing errors
        }
      }

      // Check if it's a single ID stored as textValue
      if (row.textValue != null && row.textValue!.isNotEmpty) {
        selectedAbilityIds.add(row.textValue!);
      }
    }

    // Get feature-granted abilities
    final grantedAbilityNames = await _getFeatureGrantedAbilities(values);
    
    // Load ability library and resolve granted ability names to IDs
    final library = await AbilityDataService().loadLibrary();
    final grantedAbilityIds = <String>[];
    
    for (final abilityName in grantedAbilityNames) {
      final component = library.components.cast<Component?>().firstWhere(
        (c) => c?.name.toLowerCase() == abilityName.toLowerCase(),
        orElse: () => null,
      );
      if (component != null) {
        grantedAbilityIds.add(component.id);
      }
    }

    // Combine selected and granted abilities
    final allAbilityIds = <String>{...selectedAbilityIds, ...grantedAbilityIds}.toList();
    
    return allAbilityIds;
  });
});

/// Helper function to extract granted ability names from class features
Future<List<String>> _getFeatureGrantedAbilities(List<dynamic> heroValues) async {
  // Get hero's class name and level
  String? className;
  int heroLevel = 1;

  for (final value in heroValues) {
    if (value.key == 'basics.className') {
      className = value.textValue;
    } else if (value.key == 'basics.level') {
      heroLevel = int.tryParse(value.textValue ?? '1') ?? 1;
    }
  }

  if (className == null) {
    return [];
  }

  // Load class data
  final classDataService = ClassDataService();
  await classDataService.initialize();
  
  final classData = classDataService.getClassById(className);
  
  if (classData == null) {
    return [];
  }

  // Extract granted abilities from features up to hero's level
  final grantedAbilityNames = <String>[];
  
  for (final levelData in classData.levels) {
    if (levelData.level > heroLevel) {
      break;
    }
    
    for (final feature in levelData.features) {
      if (feature.grantType == 'ability') {
        grantedAbilityNames.add(feature.name);
      }
    }
  }

  return grantedAbilityNames;
}

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
  String? _selectedKitId;
  bool _isLoadingKit = true;

  @override
  void initState() {
    super.initState();
    _loadKit();
  }

  Future<void> _loadKit() async {
    try {
      final db = ref.read(appDatabaseProvider);
      final values = await db.getHeroValues(widget.heroId);
      final kitRow = values.cast<dynamic>().firstWhere(
        (v) => v.key == 'basics.kit',
        orElse: () => null,
      );
      
      if (mounted) {
        setState(() {
          _selectedKitId = kitRow?.textValue;
          _isLoadingKit = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingKit = false;
        });
      }
    }
  }

  Future<void> _changeKit() async {
    // Load all kit types
    final kits = await ref.read(componentsByTypeProvider('kit').future);
    final stormwightKits =
        await ref.read(componentsByTypeProvider('stormwight_kit').future);
    final wards = await ref.read(componentsByTypeProvider('ward').future);

    if (!mounted) return;

    final allKits = [...kits, ...stormwightKits, ...wards];

    // Show dialog
    final selected = await showDialog<String?>(
      context: context,
      builder: (context) => _KitSelectionDialog(
        currentKitId: _selectedKitId,
        allKits: allKits,
      ),
    );

    if (selected != null && mounted) {
      // Save the new kit
      final repo = ref.read(heroRepositoryProvider);
      await repo.updateKit(widget.heroId, selected);
      
      // Reload
      _loadKit();
    }
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
      final _db = ref.read(appDatabaseProvider);
      final db = _db;
      final values = await db.getHeroValues(widget.heroId);
      
      // Get current abilities
      final abilityKey = 'component.ability';
      final row = values.cast<dynamic>().firstWhere(
        (v) => v.key == abilityKey,
        orElse: () => null,
      );

      final currentAbilityIds = <String>[];
      
      if (row?.jsonValue != null) {
        try {
          final decoded = jsonDecode(row.jsonValue!);
          if (decoded is Map && decoded['ids'] is List) {
            currentAbilityIds.addAll(
              (decoded['ids'] as List).map((e) => e.toString()),
            );
          }
        } catch (_) {}
      }
      
      if (row?.textValue != null && row.textValue!.isNotEmpty) {
        currentAbilityIds.add(row.textValue!);
      }

      // Add new ability if not already present
      if (!currentAbilityIds.contains(abilityId)) {
        currentAbilityIds.add(abilityId);
        
        // Save back to database
        final jsonData = {'ids': currentAbilityIds};
        await _db.upsertHeroValue(
          heroId: widget.heroId,
          key: abilityKey,
          jsonMap: jsonData,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ability added successfully')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ability already added')),
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
    // Watch the ability IDs streamz
    final abilityIdsAsync = ref.watch(heroAbilityIdsProvider(widget.heroId));

    return Column(
      children: [
        // Kit display section
        if (_isLoadingKit)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          _buildKitSection(context),
        
        const Divider(height: 1),
        
        // Add Ability button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showAddAbilityDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Ability'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        
        // Abilities tabs
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(
                      icon: Icon(Icons.star_outline),
                      text: 'Hero Abilities',
                    ),
                    Tab(
                      icon: Icon(Icons.all_inclusive),
                      text: 'Common Abilities',
                    ),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Hero-specific abilities tab
                      abilityIdsAsync.when(
                        data: (abilityIds) {
                          if (abilityIds.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.bolt_outlined,
                                        size: 64, color: Colors.grey),
                                    SizedBox(height: 16),
                                    Text(
                                      'No Abilities',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'This hero has not learned any abilities yet.',
                                      style: TextStyle(color: Colors.grey),
                                      textAlign: TextAlign.center,
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
                                    size: 64, color: Colors.red),
                                const SizedBox(height: 16),
                                Text(
                                  'Error loading abilities',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  error.toString(),
                                  style: const TextStyle(color: Colors.grey),
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
    );
  }

  Widget _buildKitSection(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🎒 Equipped Kit',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _changeKit,
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: Text(_selectedKitId == null ? 'Select Kit' : 'Change'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
          if (_selectedKitId != null) ...[
            const SizedBox(height: 12),
            FutureBuilder<Component?>(
              future: _findKitById(_selectedKitId!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final kit = snapshot.data;
                if (kit == null) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.error,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: theme.colorScheme.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Kit not found',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (dialogContext) => _KitPreviewDialog(item: kit),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getBorderColorForType(kit.type),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            kit.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.visibility_outlined,
                          color: _getBorderColorForType(kit.type),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Color _getBorderColorForType(String type) {
    // Import KitTheme at the top of the file
    final colorScheme = KitTheme.getColorScheme(type);
    return colorScheme.borderColor;
  }

  Future<Component?> _findKitById(String kitId) async {
    // Try all kit types
    final kits = await ref.read(componentsByTypeProvider('kit').future);
    final found = kits.cast<Component?>().firstWhere(
          (k) => k?.id == kitId,
          orElse: () => null,
        );
    if (found != null) return found;

    final stormwightKits =
        await ref.read(componentsByTypeProvider('stormwight_kit').future);
    final foundStormwight = stormwightKits.cast<Component?>().firstWhere(
          (k) => k?.id == kitId,
          orElse: () => null,
        );
    if (foundStormwight != null) return foundStormwight;

    final wards = await ref.read(componentsByTypeProvider('ward').future);
    final foundWard = wards.cast<Component?>().firstWhere(
          (k) => k?.id == kitId,
          orElse: () => null,
        );
    return foundWard;
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

class _KitSelectionDialog extends StatelessWidget {
  const _KitSelectionDialog({
    required this.currentKitId,
    required this.allKits,
  });

  final String? currentKitId;
  final List<Component> allKits;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Group by type
    final standardKits = allKits.where((k) => k.type == 'kit').toList();
    final stormwightKits =
        allKits.where((k) => k.type == 'stormwight_kit').toList();
    final wards = allKits.where((k) => k.type == 'ward').toList();
    final other = allKits
        .where((k) =>
            k.type != 'kit' && k.type != 'stormwight_kit' && k.type != 'ward')
        .toList();

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 800,
          maxHeight: 700,
        ),
        child: Column(
          children: [
            AppBar(
              title: const Text('Change Kit'),
              automaticallyImplyLeading: false,
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text(
                    'Remove Kit',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Expanded(
              child: DefaultTabController(
                length: 4,
                child: Column(
                  children: [
                    TabBar(
                      tabs: [
                        Tab(
                            text:
                                'Standard (${standardKits.length})'),
                        Tab(
                            text:
                                'Stormwight (${stormwightKits.length})'),
                        Tab(text: 'Wards (${wards.length})'),
                        Tab(text: 'Other (${other.length})'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildKitList(context, standardKits),
                          _buildKitList(context, stormwightKits),
                          _buildKitList(context, wards),
                          _buildKitList(context, other),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKitList(BuildContext context, List<Component> kits) {
    if (kits.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No kits in this category'),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: kits.length,
      itemBuilder: (context, index) {
        final kit = kits[index];
        final isSelected = kit.id == currentKitId;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => Navigator.of(context).pop(kit.id),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                    : Theme.of(context).colorScheme.surface,
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline.withOpacity(0.5),
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
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          kit.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (kit.data['description'] != null && kit.data['description'].toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      kit.data['description'].toString(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
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
  }
}

class _AbilityListView extends ConsumerStatefulWidget {
  const _AbilityListView({required this.abilityIds, required this.heroId});

  final List<String> abilityIds;
  final String heroId;

  @override
  ConsumerState<_AbilityListView> createState() => _AbilityListViewState();
}

class _AbilityListViewState extends ConsumerState<_AbilityListView> {

  @override
  Widget build(BuildContext context) {
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

        // Group abilities by type
        final signature = <Component>[];
        final active = <Component>[];
        final passive = <Component>[];
        final other = <Component>[];

        for (final ability in abilities) {
          final data = ability.data;
          final costs = data['costs'];

          // Check if signature
          if (costs is String && costs.toLowerCase() == 'signature') {
            signature.add(ability);
          } else if (costs is Map && costs['signature'] == true) {
            signature.add(ability);
          } else {
            // Check trigger type
            final trigger = data['trigger']?.toString().toLowerCase();
            if (trigger == 'passive' ||
                trigger == 'triggered' ||
                trigger == 'perk') {
              passive.add(ability);
            } else if (trigger == 'action' ||
                trigger == 'maneuver' ||
                costs != null) {
              active.add(ability);
            } else {
              other.add(ability);
            }
          }
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (signature.isNotEmpty) ...[
              _buildSectionHeader(
                  context, 'Signature Abilities', signature.length),
              ...signature
                  .map((ability) => _buildAbilityWithRemove(ability)),
              const SizedBox(height: 24),
            ],
            if (active.isNotEmpty) ...[
              _buildSectionHeader(context, 'Active Abilities', active.length),
              ...active
                  .map((ability) => _buildAbilityWithRemove(ability)),
              const SizedBox(height: 24),
            ],
            if (passive.isNotEmpty) ...[
              _buildSectionHeader(context, 'Passive Abilities', passive.length),
              ...passive
                  .map((ability) => _buildAbilityWithRemove(ability)),
              const SizedBox(height: 24),
            ],
            if (other.isNotEmpty) ...[
              _buildSectionHeader(context, 'Other Abilities', other.length),
              ...other
                  .map((ability) => _buildAbilityWithRemove(ability)),
            ],
          ],
        );
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
      final values = await db.getHeroValues(widget.heroId);
      
      final abilityKey = 'component.ability';
      final row = values.cast<dynamic>().firstWhere(
        (v) => v.key == abilityKey,
        orElse: () => null,
      );

      final currentAbilityIds = <String>[];
      
      if (row?.jsonValue != null) {
        try {
          final decoded = jsonDecode(row.jsonValue!);
          if (decoded is Map && decoded['ids'] is List) {
            currentAbilityIds.addAll(
              (decoded['ids'] as List).map((e) => e.toString()),
            );
          }
        } catch (_) {}
      }
      
      if (row?.textValue != null && row.textValue!.isNotEmpty) {
        currentAbilityIds.add(row.textValue!);
      }

      // Remove the ability
      currentAbilityIds.remove(abilityId);
      
      // Save back to database
      final jsonData = {'ids': currentAbilityIds};
      await db.upsertHeroValue(
        heroId: widget.heroId,
        key: abilityKey,
        jsonMap: jsonData,
      );
      
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

    for (final id in abilityIds) {
      try {
        final component = library.byId(id) ?? library.find(id);
        if (component != null) {
          components.add(component);
        }
      } catch (e) {
        debugPrint('Failed to resolve ability $id: $e');
      }
    }

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
