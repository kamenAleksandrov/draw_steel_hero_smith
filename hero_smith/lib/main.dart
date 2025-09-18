import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/heroes/heroes_page.dart';
import 'features/strife/strife_page.dart';
import 'features/story/story_page.dart';
import 'features/gear/gear_page.dart';
import 'features/downtime/downtime_projects_page.dart';
import 'core/theme/ds_theme.dart';
import 'core/providers.dart';
import 'core/db/app_database.dart';

void main() {
  runApp(const ProviderScope(child: HeroSmithApp()));
}

class HeroSmithApp extends StatelessWidget {
  const HeroSmithApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hero Smith',
      theme: (() {
        final base = ThemeData(
          colorSchemeSeed: Colors.indigo,
          useMaterial3: true,
        );
        return base.copyWith(
          extensions: <ThemeExtension<dynamic>>[
            DsTheme.defaults(base.colorScheme),
          ],
        );
      })(),
      darkTheme: (() {
        final base = ThemeData(
          colorSchemeSeed: Colors.indigo,
          brightness: Brightness.dark,
          useMaterial3: true,
        );
        return base.copyWith(
          extensions: <ThemeExtension<dynamic>>[
            DsTheme.defaults(base.colorScheme),
          ],
        );
      })(),
      themeMode: ThemeMode.dark,
      home: const RootNavPage(),
    );
  }
}

class RootNavPage extends ConsumerStatefulWidget {
  const RootNavPage({super.key});

  @override
  ConsumerState<RootNavPage> createState() => _RootNavPageState();
}

class _RootNavPageState extends ConsumerState<RootNavPage> {
  int _index = 0;

  static const _pages = <Widget>[
    HeroesPage(),
    StrifePage(),
    StoryPage(),
    GearPage(),
    DowntimeProjectsPage(),
  ];

  @override
  void initState() {
    super.initState();
    // Print database path once (skipped in tests where auto-seed is disabled).
    final shouldShow = ref.read(autoSeedEnabledProvider);
    if (shouldShow) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final path = await AppDatabase.databasePath();
        debugPrint('Hero Smith DB path: $path');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('DB path: $path'), duration: const Duration(seconds: 5)),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kick off seeding (no-op if already seeded or disabled via provider override)
    ref.watch(seedOnStartupProvider);
    return Scaffold(
      appBar: AppBar(title: Text(_titleForIndex(_index))),
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.person), label: 'Heroes'),
          NavigationDestination(icon: Icon(Icons.flash_on), label: 'Strife'),
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'Story'),
          NavigationDestination(icon: Icon(Icons.handyman), label: 'Gear'),
          NavigationDestination(icon: Icon(Icons.timer), label: 'Downtime'),
        ],
      ),
    );
  }

  String _titleForIndex(int i) {
    switch (i) {
      case 0:
        return 'Heroes';
      case 1:
        return 'Strife';
      case 2:
        return 'Story';
      case 3:
        return 'Gear';
      case 4:
        return 'Downtime Projects';
      default:
        return 'Hero Smith';
    }
  }
}
