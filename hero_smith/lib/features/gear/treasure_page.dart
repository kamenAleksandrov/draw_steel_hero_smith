import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/models/component.dart' as model;
import '../../widgets/treasures/treasures.dart';
import 'echelon_treasure_detail_page.dart';
import 'leveled_treasure_type_page.dart';

class TreasurePage extends ConsumerWidget {
  const TreasurePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Treasures'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Consumables'),
              Tab(text: 'Trinkets'),
              Tab(text: 'Leveled'),
              Tab(text: 'Artifacts'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Consumables - Echelon Groups
            _EchelonGroupsTab(treasureType: 'consumable', displayName: 'Consumables'),
            // Trinkets - Echelon Groups
            _EchelonGroupsTab(treasureType: 'trinket', displayName: 'Trinkets'),
            // Leveled - Equipment Type Groups
            _LeveledTreasureTypesTab(),
            // Artifacts
            _TreasureList(
              stream: ref.watch(componentsByTypeProvider('artifact')),
              itemBuilder: (c) => ArtifactTreasureCard(component: c),
            ),
          ],
        ),
      ),
    );
  }
}

class _EchelonGroupsTab extends StatelessWidget {
  final String treasureType;
  final String displayName;

  const _EchelonGroupsTab({
    required this.treasureType,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose an echelon:',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              _EchelonCard(
                echelon: 1,
                title: '1st Echelon $displayName',
                description: 'Basic $displayName for starting adventurers',
                treasureType: treasureType,
                displayName: displayName,
              ),
              const SizedBox(height: 12),
              _EchelonCard(
                echelon: 2,
                title: '2nd Echelon $displayName',
                description: 'Intermediate $displayName for experienced heroes',
                treasureType: treasureType,
                displayName: displayName,
              ),
              const SizedBox(height: 12),
              _EchelonCard(
                echelon: 3,
                title: '3rd Echelon $displayName',
                description: 'Advanced $displayName for seasoned adventurers',
                treasureType: treasureType,
                displayName: displayName,
              ),
              const SizedBox(height: 12),
              _EchelonCard(
                echelon: 4,
                title: '4th Echelon $displayName',
                description: 'Master-level $displayName for legendary heroes',
                treasureType: treasureType,
                displayName: displayName,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeveledTreasureTypesTab extends StatelessWidget {
  const _LeveledTreasureTypesTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose equipment type:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              _LeveledTypeCard(
                leveledType: 'armor',
                title: 'Armor & Shields',
                description: 'Protective equipment and defensive gear',
                icon: Icons.shield,
              ),
              const SizedBox(height: 12),
              _LeveledTypeCard(
                leveledType: 'implement',
                title: 'Implements',
                description: 'Magical focuses and casting tools',
                icon: Icons.auto_fix_high,
              ),
              const SizedBox(height: 12),
              _LeveledTypeCard(
                leveledType: 'weapon',
                title: 'Weapons',
                description: 'Combat weapons and martial equipment',
                icon: Icons.gavel,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EchelonCard extends StatelessWidget {
  final int echelon;
  final String title;
  final String description;
  final String treasureType;
  final String displayName;

  const _EchelonCard({
    required this.echelon,
    required this.title,
    required this.description,
    required this.treasureType,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getEchelonColor(echelon),
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => EchelonTreasureDetailPage(
                echelon: echelon,
                treasureType: treasureType,
                displayName: displayName,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: Text(
                  echelon.toString(),
                  style: TextStyle(
                    color: _getEchelonColor(echelon),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios),
            ],
          ),
        ),
      ),
    );
  }

  Color _getEchelonColor(int echelon) {
    switch (echelon) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.orange;
      case 4:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

class _LeveledTypeCard extends StatelessWidget {
  final String leveledType;
  final String title;
  final String description;
  final IconData icon;

  const _LeveledTypeCard({
    required this.leveledType,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          // Handle both armor and shield in the same page since they're grouped
          String actualType = leveledType;
          String displayName = title;
          
          if (leveledType == 'armor') {
            // For armor type, we need to show both armor and shield
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => _ArmorShieldPage(),
              ),
            );
            return;
          }
          
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => LeveledTreasureTypePage(
                leveledType: actualType,
                displayName: displayName,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: _getTypeColor(),
                child: Icon(
                  icon,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTypeColor() {
    switch (leveledType) {
      case 'armor':
        return Colors.brown;
      case 'implement':
        return Colors.indigo;
      case 'weapon':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class _ArmorShieldPage extends ConsumerWidget {
  const _ArmorShieldPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Armor & Shields'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Armor'),
              Tab(text: 'Shields'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _LeveledTreasureTypeList(
              stream: ref.watch(componentsByTypeProvider('leveled_treasure')),
              leveledType: 'armor',
            ),
            _LeveledTreasureTypeList(
              stream: ref.watch(componentsByTypeProvider('leveled_treasure')),
              leveledType: 'shield',
            ),
          ],
        ),
      ),
    );
  }
}

class _LeveledTreasureTypeList extends StatelessWidget {
  final AsyncValue<List<model.Component>> stream;
  final String leveledType;

  const _LeveledTreasureTypeList({
    required this.stream,
    required this.leveledType,
  });

  @override
  Widget build(BuildContext context) {
    return stream.when(
      data: (items) {
        final filteredItems = items
            .where((item) => item.data['leveled_type'] == leveledType)
            .toList();
        
        if (filteredItems.isEmpty) {
          return const Center(child: Text('No treasures available for this type'));
        }
        
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (_, i) => LeveledTreasureCard(component: filteredItems[i]),
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemCount: filteredItems.length,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

class _TreasureList extends StatelessWidget {
  final AsyncValue<List<model.Component>> stream;
  final Widget Function(model.Component) itemBuilder;

  const _TreasureList({
    required this.stream,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return stream.when(
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('None available'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (_, i) => itemBuilder(items[i]),
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemCount: items.length,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}


