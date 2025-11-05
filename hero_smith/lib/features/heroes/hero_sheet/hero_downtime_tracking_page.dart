import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/hero_theme.dart';
import '../../../widgets/downtime/downtime_tabs.dart';
import 'widgets/sheet_downtime/projects_list_tab.dart';
import 'widgets/sheet_downtime/followers_tab.dart';
import 'widgets/sheet_downtime/sources_tab.dart';

/// Main page for managing hero downtime projects
class HeroDowntimeTrackingPage extends ConsumerStatefulWidget {
  const HeroDowntimeTrackingPage({
    super.key,
    required this.heroId,
    required this.heroName,
  });

  final String heroId;
  final String heroName;

  @override
  ConsumerState<HeroDowntimeTrackingPage> createState() =>
      _HeroDowntimeTrackingPageState();
}

class _HeroDowntimeTrackingPageState
    extends ConsumerState<HeroDowntimeTrackingPage> {
  int _currentTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.heroName} - Downtime Projects'),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.event_note),
            tooltip: 'View Event Tables',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const DowntimeTabsScaffold(initialIndex: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          ProjectsListTab(heroId: widget.heroId),
          FollowersTab(heroId: widget.heroId),
          SourcesTab(heroId: widget.heroId),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) => setState(() => _currentTabIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: HeroTheme.primarySection,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Projects',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Followers',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: 'Sources',
          ),
        ],
      ),
    );
  }
}
