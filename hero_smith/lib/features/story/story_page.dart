import 'package:flutter/material.dart';
import 'ancestries_page.dart';
import 'cultures_page.dart';
import 'careers_page.dart';
import 'complications_page.dart';
import 'languages_page.dart';
import 'skills_page.dart';
import 'titles_page.dart';
import 'perks_page.dart';
import 'deities_page.dart';

class StoryPage extends StatelessWidget {
  const StoryPage({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text(
          'Story',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.left,
        ),
        const SizedBox(height: 16),
        _NavCard(
          icon: Icons.groups,
          title: 'Ancestries',
          subtitle: 'Background origins and lineages',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AncestriesPage()),
          ),
        ),
        const SizedBox(height: 12),
        _NavCard(
          icon: Icons.public,
          title: 'Cultures',
          subtitle: 'Peoples and societies of the world',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CulturesPage()),
          ),
        ),
        const SizedBox(height: 12),
        _NavCard(
          icon: Icons.work,
          title: 'Careers',
          subtitle: 'Occupations and life paths',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CareersPage()),
          ),
        ),
        const SizedBox(height: 12),
        _NavCard(
          icon: Icons.report,
          title: 'Complications',
          subtitle: 'Entanglements and hardships',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ComplicationsPage()),
          ),
        ),
        const SizedBox(height: 12),
        _NavCard(
          icon: Icons.language,
          title: 'Languages',
          subtitle: 'Tongues spoken across the lands',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LanguagesPage()),
          ),
        ),
        const SizedBox(height: 12),
        _NavCard(
          icon: Icons.school,
          title: 'Skills',
          subtitle: 'Capabilities and training',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SkillsPage()),
          ),
        ),
        const SizedBox(height: 12),
        _NavCard(
          icon: Icons.military_tech,
          title: 'Titles',
          subtitle: 'Ranks, honors, and renown',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TitlesPage()),
          ),
        ),
        const SizedBox(height: 12),
        _NavCard(
          icon: Icons.star,
          title: 'Perks',
          subtitle: 'Special boons and edges',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PerksPage()),
          ),
        ),
        const SizedBox(height: 12),
        _NavCard(
          icon: Icons.wb_sunny,
          title: 'Deities',
          subtitle: 'Gods, saints, and higher powers',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const DeitiesPage()),
          ),
        ),
      ],
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              child: Icon(icon, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
