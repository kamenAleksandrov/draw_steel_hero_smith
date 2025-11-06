import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/providers.dart';
import '../../../core/models/component.dart';
import '../../../core/services/ability_data_service.dart';
import '../../../widgets/abilities/ability_expandable_item.dart';
import '../../../widgets/kits/kit_card.dart';
import '../../../widgets/kits/modifier_card.dart';
import '../../../widgets/kits/stormwight_kit_card.dart';
import '../../../widgets/kits/ward_card.dart';

/// Provider that watches hero ability IDs for a specific hero
final heroAbilityIdsProvider =
    StreamProvider.family<List<String>, String>((ref, heroId) {
  final db = ref.watch(appDatabaseProvider);

  // Watch hero values and filter for ability component IDs
  return db.watchHeroValues(heroId).map((values) {
    final abilityKey = 'component.ability';

    dynamic row;
    for (final value in values) {
      if (value.key == abilityKey) {
        row = value;
        break;
      }
    }

    if (row == null) {
      return const <String>[];
    }

    // Check if it's stored as JSON array
    if (row.jsonValue != null) {
      try {
        final decoded = jsonDecode(row.jsonValue!);
        if (decoded is Map && decoded['ids'] is List) {
          return (decoded['ids'] as List)
              .map((e) => e.toString())
              .toList(growable: false);
        }
      } catch (_) {
        return <String>[];
      }
    }

    // Check if it's a single ID stored as textValue
    if (row.textValue != null && row.textValue!.isNotEmpty) {
      return [row.textValue!];
    }

    return <String>[];
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

                          return _AbilityListView(abilityIds: abilityIds);
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

    if (_selectedKitId == null) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No Kit Equipped',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Go to the Strife Creator to select a kit',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<Component?>(
      future: _findKitById(_selectedKitId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kit not found',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _changeKit,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Change Kit'),
                ),
              ],
            ),
          );
        }

        final kit = snapshot.data!;
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
                    label: const Text('Change'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildKitCard(kit),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKitCard(Component kit) {
    // Return appropriate card based on type
    switch (kit.type) {
      case 'kit':
        return KitCard(component: kit);
      case 'stormwight_kit':
        return StormwightKitCard(component: kit);
      case 'ward':
        return WardCard(component: kit);
      case 'psionic_augmentation':
      case 'enchantment':
      case 'prayer':
        return ModifierCard(component: kit, badgeLabel: kit.type);
      default:
        return KitCard(component: kit);
    }
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
          padding: const EdgeInsets.only(bottom: 16),
          child: InkWell(
            onTap: () => Navigator.of(context).pop(kit.id),
            borderRadius: BorderRadius.circular(16),
            child: Opacity(
              opacity: isSelected ? 0.6 : 1.0,
              child: Stack(
                children: [
                  _buildKitCard(kit),
                  if (isSelected)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildKitCard(Component kit) {
    switch (kit.type) {
      case 'kit':
        return KitCard(component: kit);
      case 'stormwight_kit':
        return StormwightKitCard(component: kit);
      case 'ward':
        return WardCard(component: kit);
      case 'psionic_augmentation':
      case 'enchantment':
      case 'prayer':
        return ModifierCard(component: kit, badgeLabel: kit.type);
      default:
        return KitCard(component: kit);
    }
  }
}

class _AbilityListView extends ConsumerWidget {
  const _AbilityListView({required this.abilityIds});

  final List<String> abilityIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Component>>(
      future: _loadAbilityComponents(abilityIds),
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
                  .map((ability) => AbilityExpandableItem(component: ability)),
              const SizedBox(height: 24),
            ],
            if (active.isNotEmpty) ...[
              _buildSectionHeader(context, 'Active Abilities', active.length),
              ...active
                  .map((ability) => AbilityExpandableItem(component: ability)),
              const SizedBox(height: 24),
            ],
            if (passive.isNotEmpty) ...[
              _buildSectionHeader(context, 'Passive Abilities', passive.length),
              ...passive
                  .map((ability) => AbilityExpandableItem(component: ability)),
              const SizedBox(height: 24),
            ],
            if (other.isNotEmpty) ...[
              _buildSectionHeader(context, 'Other Abilities', other.length),
              ...other
                  .map((ability) => AbilityExpandableItem(component: ability)),
            ],
          ],
        );
      },
    );
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
