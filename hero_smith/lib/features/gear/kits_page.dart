import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/providers.dart';
import '../../core/models/component.dart' as model;
import '../../widgets/kits/kit_card.dart';
import '../../widgets/kits/stormwight_kit_card.dart';
import '../../widgets/kits/modifier_card.dart';
import '../../widgets/kits/ward_card.dart';

class KitsPage extends ConsumerWidget {
  const KitsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kits'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Kits'),
              Tab(text: 'Stormwight'),
              Tab(text: 'Augmentations'),
              Tab(text: 'Enchantments'),
              Tab(text: 'Prayers'),
              Tab(text: 'Wards'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ComponentsList(
              stream: ref.watch(componentsByTypeProvider('kit')),
              itemBuilder: (c) => KitCard(component: c),
            ),
            _ComponentsList(
              stream: ref.watch(componentsByTypeProvider('stormwight_kit')),
              itemBuilder: (c) => StormwightKitCard(component: c),
            ),
            _ComponentsList(
              stream: ref.watch(componentsByTypeProvider('psionic_augmentation')),
              itemBuilder: (c) => ModifierCard(component: c, badgeLabel: 'Augmentation'),
            ),
            _ComponentsList(
              stream: ref.watch(componentsByTypeProvider('enchantment')),
              itemBuilder: (c) => ModifierCard(component: c, badgeLabel: 'Enchantment'),
            ),
            _ComponentsList(
              stream: ref.watch(componentsByTypeProvider('prayer')),
              itemBuilder: (c) => ModifierCard(component: c, badgeLabel: 'Prayer'),
            ),
            _ComponentsList(
              stream: ref.watch(componentsByTypeProvider('ward')),
              itemBuilder: (c) => WardCard(component: c),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComponentsList extends StatelessWidget {
  final AsyncValue<List<model.Component>> stream;
  final Widget Function(model.Component) itemBuilder;

  const _ComponentsList({
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
