import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/models/component.dart' as model;
import '../../widgets/treasures/treasures.dart';

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
            // Consumables
            _TreasureList(
              stream: ref.watch(componentsByTypeProvider('consumable')),
              itemBuilder: (c) => ConsumableTreasureCard(component: c),
            ),
            // Trinkets
            _TreasureList(
              stream: ref.watch(componentsByTypeProvider('trinket')),
              itemBuilder: (c) => TrinketTreasureCard(component: c),
            ),
            // Leveled
            _TreasureList(
              stream: ref.watch(componentsByTypeProvider('leveled_treasure')),
              itemBuilder: (c) => LeveledTreasureCard(component: c),
            ),
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

class _TreasureList extends StatelessWidget {
  final AsyncValue<List<model.Component>> stream;
  final bool Function(model.Component c)? filter;
  final Widget Function(model.Component) itemBuilder;

  const _TreasureList({
    required this.stream,
    required this.itemBuilder,
    this.filter,
  });

  @override
  Widget build(BuildContext context) {
    return stream.when(
      data: (items) {
        final list = filter == null ? items : items.where(filter!).toList();
        if (list.isEmpty) {
          return const Center(child: Text('None available'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (_, i) => itemBuilder(list[i]),
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemCount: list.length,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}


