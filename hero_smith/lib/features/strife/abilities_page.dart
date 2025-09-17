import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/models/component.dart';
import '../../widgets/abilities/ability_expandable_item.dart';

class AbilitiesPage extends ConsumerWidget {
  const AbilitiesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final abilitiesAsync = ref.watch(componentsByTypeProvider('ability'));
    
    // Debug: also watch all components to see what's in the database
    final allAsync = ref.watch(allComponentsProvider);
    
    return Scaffold(
      appBar: AppBar(title: const Text('Abilities')),
      body: abilitiesAsync.when(
        data: (items) {
          // Debug logging
          debugPrint('Abilities found: ${items.length}');
          for (var item in items.take(3)) {
            debugPrint('Ability: ${item.id} (${item.type}) - ${item.name}');
          }
          
          return _AbilitiesList(items: items);
        },
        loading: () {
          debugPrint('Loading abilities...');
          // Show what's in all components while loading abilities
          return allAsync.when(
            data: (allItems) {
              debugPrint('Total components in DB: ${allItems.length}');
              final abilityTypes = allItems.map((e) => e.type).toSet();
              debugPrint('Types found: $abilityTypes');
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Loading abilities...\nTotal components: ${allItems.length}\nTypes: ${abilityTypes.join(', ')}'),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Debug - All components error: $e')),
          );
        },
        error: (e, stackTrace) {
          debugPrint('Error loading abilities: $e');
          debugPrint('Stack trace: $stackTrace');
          return Center(child: Text('Failed to load abilities: $e'));
        },
      ),
    );
  }
}

class _AbilitiesList extends StatelessWidget {
  final List<Component> items;
  const _AbilitiesList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No abilities found'));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text('Found ${items.length} abilities', 
            style: Theme.of(context).textTheme.titleMedium),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (_, i) => AbilityExpandableItem(component: items[i]),
          ),
        ),
      ],
    );
  }
}
