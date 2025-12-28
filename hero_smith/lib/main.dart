import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/main_pages/heroes_page.dart';
import 'features/main_pages/strife/strife_page.dart';
import 'features/main_pages/story/story_page.dart';
import 'features/main_pages/gear/gear_page.dart';
import 'features/main_pages/downtime/downtime_projects_page.dart';
import 'features/splash/splash_screen.dart';
import 'core/theme/ds_theme.dart';
import 'core/db/providers.dart';
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
      home: const SplashWrapper(),
    );
  }
}

/// Wrapper that shows splash screen during initialization, then transitions to main app.
class SplashWrapper extends ConsumerStatefulWidget {
  const SplashWrapper({super.key});

  @override
  ConsumerState<SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends ConsumerState<SplashWrapper> {
  bool _showSplash = true;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Defer initialization until after first frame to avoid lifecycle edge-cases
    // around didChangeDependencies/first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_initialized) {
        _initialized = true;
        _initializeApp();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Future<void> _initializeApp() async {
    // Skip splash in test mode (when auto-seed is disabled)
    final shouldShowSplash = ref.read(autoSeedEnabledProvider);
    if (!shouldShowSplash) {
      if (mounted) {
        setState(() {
          _showSplash = false;
        });
      }
      return;
    }
    
    // Minimum splash duration for branding visibility
    await Future.delayed(const Duration(seconds: 2));

    // Seed DB while the splash screen is showing so the Heroes page doesn't
    // appear frozen during heavy first-run initialization.
    try {
      await ref.read(seedOnStartupProvider.future);
    } catch (e) {
      // Best-effort: allow app to continue; downstream pages can surface errors.
      debugPrint('Startup seed failed: $e');
    }

    if (mounted) {
      setState(() {
        _showSplash = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(onComplete: () {
        setState(() {
          _showSplash = false;
        });
      });
    }
    return const RootNavPage();
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

  // @override
  // void initState() {
  //   super.initState();
  //   // Print database path once (skipped in tests where auto-seed is disabled).
  //   final shouldShow = ref.read(autoSeedEnabledProvider);
  //   if (shouldShow) {
  //     WidgetsBinding.instance.addPostFrameCallback((_) async {
  //       final path = await AppDatabase.databasePath();
  //       debugPrint('Hero Smith DB path: $path');
  //       if (!mounted) return;
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('DB path: $path'), duration: const Duration(seconds: 5)),
  //       );
  //     });
  //   }
  // }

  @override
  Widget build(BuildContext context) {
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
