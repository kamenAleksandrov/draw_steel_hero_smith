import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/providers.dart';
import '../../../../core/repositories/hero_entry_repository.dart';
import '../../../../core/services/perk_grants_service.dart';
import 'ability_list_view.dart';
import 'add_ability_dialog.dart';
import 'common_abilities_view.dart';
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
  bool _perkGrantsEnsured = false;

  @override
  void initState() {
    super.initState();
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

  Future<void> _showAddAbilityDialog(BuildContext context) async {
    final selectedAbilityId = await showDialog<String?>(
      context: context,
      builder: (context) => AddAbilityDialog(heroId: widget.heroId),
    );

    if (selectedAbilityId != null && mounted) {
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
    final theme = Theme.of(context);

    return Stack(
      children: [
        DefaultTabController(
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
        // Floating Action Button for adding abilities
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'sheet_abilities_fab',
            onPressed: () => _showAddAbilityDialog(context),
            tooltip: 'Add Ability',
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

