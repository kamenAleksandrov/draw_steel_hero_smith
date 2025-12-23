import 'package:flutter/material.dart';

import '../../../core/models/component.dart';
import '../../../core/services/ability_data_service.dart';
import '../../../core/theme/text/common_abilities_view_text.dart';
import '../../../widgets/abilities/ability_expandable_item.dart';

/// Enum for common ability categories
enum CommonAbilityCategory {
  actions,
  move,
  maneuvers,
}

extension CommonAbilityCategoryLabel on CommonAbilityCategory {
  String get label {
    switch (this) {
      case CommonAbilityCategory.actions:
        return CommonAbilitiesViewText.actionLabelActions;
      case CommonAbilityCategory.move:
        return CommonAbilitiesViewText.actionLabelMove;
      case CommonAbilityCategory.maneuvers:
        return CommonAbilitiesViewText.actionLabelManeuvers;
    }
  }
  
  IconData get icon {
    switch (this) {
      case CommonAbilityCategory.actions:
        return Icons.flash_on;
      case CommonAbilityCategory.move:
        return Icons.directions_walk;
      case CommonAbilityCategory.maneuvers:
        return Icons.directions_run;
    }
  }
}

/// Displays common abilities available to all heroes.
/// 
/// Common abilities are loaded from the ability library and grouped by category:
/// - Actions (Main Actions)
/// - Move (Move Actions)
/// - Maneuvers
class CommonAbilitiesView extends StatefulWidget {
  const CommonAbilitiesView({super.key});

  @override
  State<CommonAbilitiesView> createState() => _CommonAbilitiesViewState();
}

class _CommonAbilitiesViewState extends State<CommonAbilitiesView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: CommonAbilityCategory.values.length, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Categorize an ability based on its action_type field
  CommonAbilityCategory _categorizeAbility(Component ability) {
    final data = ability.data;
    final actionType = (data['action_type']?.toString().toLowerCase() ?? '').trim();
    
    // Categorize by action_type
    if (actionType.contains('move')) {
      return CommonAbilityCategory.move;
    }
    if (actionType.contains('maneuver')) {
      return CommonAbilityCategory.maneuvers;
    }
    // Main actions and any other type go into Actions tab
    return CommonAbilityCategory.actions;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
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
                    CommonAbilitiesViewText.errorTitle,
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
                CommonAbilitiesViewText.emptyListMessage,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        // Group abilities by category
        final grouped = <CommonAbilityCategory, List<Component>>{};
        for (final category in CommonAbilityCategory.values) {
          grouped[category] = [];
        }
        
        for (final ability in abilities) {
          final category = _categorizeAbility(ability);
          grouped[category]!.add(ability);
        }
        
        // Sort each category by name
        for (final category in CommonAbilityCategory.values) {
          grouped[category]!.sort((a, b) => a.name.compareTo(b.name));
        }

        return Column(
          children: [
            // Tab bar for ability types
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              tabs: [
                for (final category in CommonAbilityCategory.values)
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
                              color: theme.colorScheme.primary.withValues(alpha: 0.2),
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
                  for (final category in CommonAbilityCategory.values)
                    _buildCategoryList(grouped[category]!, category),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildCategoryList(List<Component> abilities, CommonAbilityCategory category) {
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
                '${CommonAbilitiesViewText.emptyCategoryPrefix}${category.label}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                CommonAbilitiesViewText.emptyCategorySubtitle,
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
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AbilityExpandableItem(component: abilities[index]),
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
}
