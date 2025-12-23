import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/hero_theme.dart';
import '../../../core/theme/text/downtime/hero_downtime_tracking_page_text.dart';
import '../../../widgets/downtime/downtime_tabs.dart';
import 'sheet_downtime/projects_list_tab.dart';
import 'sheet_downtime/followers_tab.dart';
import 'sheet_downtime/sources_tab.dart';

/// Main page for managing hero downtime projects
class HeroDowntimeTrackingPage extends ConsumerStatefulWidget {
  const HeroDowntimeTrackingPage({
    super.key,
    required this.heroId,
    required this.heroName,
    this.isEmbedded = false,
  });

  final String heroId;
  final String heroName;
  final bool isEmbedded;

  @override
  ConsumerState<HeroDowntimeTrackingPage> createState() =>
      _HeroDowntimeTrackingPageState();
}

class _HeroDowntimeTrackingPageState
    extends ConsumerState<HeroDowntimeTrackingPage> {
  int _currentTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    // If embedded, return content with top tab navigation
    if (widget.isEmbedded) {
      return DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surface,
              elevation: 1,
              child: TabBar(
                labelColor: HeroTheme.primarySection,
                unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                indicatorColor: HeroTheme.primarySection,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.assignment),
                    text: HeroDowntimeTrackingPageText.tabProjectsLabel,
                  ),
                  Tab(
                    icon: Icon(Icons.people),
                    text: HeroDowntimeTrackingPageText.tabFollowersLabel,
                  ),
                  Tab(
                    icon: Icon(Icons.book),
                    text: HeroDowntimeTrackingPageText.tabSourcesLabel,
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ProjectsListTab(heroId: widget.heroId),
                  FollowersTab(heroId: widget.heroId),
                  SourcesTab(heroId: widget.heroId),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.heroName} - Downtime Projects'),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.event_note),
            tooltip: HeroDowntimeTrackingPageText.viewEventTablesTooltip,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const EventsPageScaffold(),
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
            label: HeroDowntimeTrackingPageText.bottomNavProjectsLabel,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: HeroDowntimeTrackingPageText.bottomNavFollowersLabel,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: HeroDowntimeTrackingPageText.bottomNavSourcesLabel,
          ),
        ],
      ),
    );
  }
}
