import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/providers.dart';
import 'hero_detail_page.dart';

class HeroesPage extends ConsumerWidget {
  const HeroesPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heroesAsync = ref.watch(allHeroesProvider);
    return heroesAsync.when(
      data: (items) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Heroes Page', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton.icon(
                onPressed: () async {
                  final repo = ref.read(heroRepositoryProvider);
                  final id = await repo.createHero(name: 'New Hero');
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Created $id')),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Create Hero'),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('No heroes yet'))
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final c = items[index];
                        return ListTile(
                          title: Text(c.name),
                          subtitle: Text(c.id),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => HeroDetailPage(heroId: c.id)),
                            );
                          },
                          dense: true,
                        );
                      },
                    ),
            ),
          ],
        );
      },
      error: (e, st) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Heroes Page', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Center(
              child: Text('Error: $e'),
            ),
          ),
        ],
      ),
      loading: () => const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Heroes Page', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Center(child: Text('Loading heroes...'))),
        ],
      ),
    );
  }
}
