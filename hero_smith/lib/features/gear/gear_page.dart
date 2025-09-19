import 'package:flutter/material.dart';

import 'items_page.dart';
import 'kits_page.dart';
import 'treasure_page.dart';

class GearPage extends StatelessWidget {
  const GearPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8.0),
          child: Text(
            'Gear Page',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        _NavCard(
          title: 'Kits',
          subtitle: 'Preset equipment bundles by role',
          icon: Icons.backpack,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const KitsPage()),
          ),
        ),
        const SizedBox(height: 12),
        _NavCard(
          title: 'Items',
          subtitle: 'All items (coming soon)',
          icon: Icons.handyman,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const GearItemsPage()),
          ),
        ),
        const SizedBox(height: 12),
        _NavCard(
          title: 'Treasure',
          subtitle: 'Loot, valuables, and special finds',
          icon: Icons.diamond,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TreasurePage()),
          ),
        ),
      ],
    );
  }
}

class _NavCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _NavCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
