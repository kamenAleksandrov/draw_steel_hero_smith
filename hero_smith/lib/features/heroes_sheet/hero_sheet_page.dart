import 'package:flutter/material.dart';

import '../creators/hero_creators/hero_creator_page.dart';
import 'abilities/sheet_abilities.dart';
import 'gear/sheet_gear.dart';
import 'main_stats/sheet_main_stats.dart';
import 'sheet_notes.dart';
import 'story/sheet_story.dart';

/// Top-level hero sheet that hosts all hero information.
class HeroSheetPage extends StatefulWidget {
  const HeroSheetPage({
    super.key,
    required this.heroId,
    required this.heroName,
  });

  final String heroId;
  final String heroName;

  @override
  State<HeroSheetPage> createState() => _HeroSheetPageState();
}

class _HeroSheetPageState extends State<HeroSheetPage> {
  int _currentIndex = 0;
  late final List<Widget> _sections;

  @override
  void initState() {
    super.initState();
    _sections = [
      SheetMainStats(heroId: widget.heroId, heroName: widget.heroName),
      SheetAbilities(heroId: widget.heroId),
      SheetGear(heroId: widget.heroId),
      SheetStory(heroId: widget.heroId),
      SheetNotes(heroId: widget.heroId),
    ];
  }

  void _onSectionTapped(int index) {
    if (_currentIndex == index) {
      return;
    }
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hero Sheet - ${widget.heroName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Hero',
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => HeroCreatorPage(heroId: widget.heroId),
                ),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _sections,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onSectionTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Main',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.flash_on),
            label: 'Abilities',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.backpack),
            label: 'Gear',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome),
            label: 'Features',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sticky_note_2),
            label: 'Notes',
          ),
        ],
      ),
    );
  }
}
