import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hero_smith/core/theme/hero_theme.dart';
import 'package:hero_smith/core/theme/strife_theme.dart';
import 'package:hero_smith/features/creators/hero_creators/story_creator_page.dart';
import 'package:hero_smith/features/creators/hero_creators/strife_creator_page.dart';
import 'package:hero_smith/features/heroes/hero_sheet/hero_sheet_page.dart';

class HeroCreatorPage extends ConsumerStatefulWidget {
  const HeroCreatorPage({super.key, required this.heroId});

  final String heroId;

  @override
  ConsumerState<HeroCreatorPage> createState() => _HeroCreatorPageState();
}

class _HeroCreatorPageState extends ConsumerState<HeroCreatorPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final GlobalKey<StoryCreatorTabState> _storyTabKey =
      GlobalKey<StoryCreatorTabState>();
  final GlobalKey<_StrifeCreatorTabState> _strifeTabKey =
      GlobalKey<_StrifeCreatorTabState>();

  bool _storyDirty = false;
  bool _strifeDirty = false;
  String _heroTitle = 'Hero Creator';
  String? _heroName;
  bool _suppressTabNotification = false;
  bool _handlingTabPrompt = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  Future<void> _handleTabChange() async {
    if (_suppressTabNotification || _handlingTabPrompt) {
      _suppressTabNotification = false;
      return;
    }
    if (!mounted) return;

    // Check if trying to leave a dirty tab
    final oldIndex = _tabController.previousIndex;
    final newIndex = _tabController.index;

    if (oldIndex == newIndex) {
      setState(() {});
      return;
    }

    // Check if the old tab has unsaved changes
    final bool hasUnsavedChanges =
        (oldIndex == 0 && _storyDirty) || (oldIndex == 1 && _strifeDirty);

    if (hasUnsavedChanges) {
      _handlingTabPrompt = true;
      // Temporarily block the tab change
      _suppressTabNotification = true;
      _tabController.index = oldIndex;

      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Unsaved changes'),
          content: Text(
              'You have unsaved changes in the ${oldIndex == 0 ? 'Story' : 'Strife'} tab. '
              'Do you want to save before switching?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('cancel'),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('discard'),
              child: const Text('Discard'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(ctx).pop('save'),
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
          ],
        ),
      );

      if (result == 'save') {
        if (oldIndex == 0) {
          await _saveStory();
        } else if (oldIndex == 1) {
          await _saveStrife();
        }
        if (mounted) {
          _suppressTabNotification = true;
          _tabController.index = newIndex;
        }
      } else if (result == 'discard') {
        if (mounted) {
          _suppressTabNotification = true;
          _tabController.index = newIndex;
        }
      }
      // If 'cancel' or dialog dismissed, stay on current tab (already set above)
      _handlingTabPrompt = false;
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleStoryDirty(bool dirty) {
    if (_storyDirty == dirty) return;
    setState(() {
      _storyDirty = dirty;
    });
  }

  void _handleStoryTitleChanged(String title) {
    final normalized = title.trim().isEmpty ? 'Hero Creator' : title.trim();
    if (_heroTitle == normalized) return;
    setState(() {
      _heroTitle = normalized;
      _heroName = title.trim().isNotEmpty ? title.trim() : null;
    });
  }

  void _handleStrifeDirty(bool dirty) {
    if (_strifeDirty == dirty) return;
    setState(() {
      _strifeDirty = dirty;
    });
  }

  Future<void> _saveStory() async {
    final state = _storyTabKey.currentState;
    if (state == null) return;
    await state.save();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Story saved')));
  }

  Future<void> _saveStrife() async {
    final state = _strifeTabKey.currentState;
    if (state == null) return;
    await state.save();
  }

  Future<void> _saveAll() async {
    if (_storyDirty) {
      await _saveStory();
    }
    final strifeState = _strifeTabKey.currentState;
    if (strifeState != null && strifeState.isDirty) {
      await strifeState.save();
    }
  }

  Future<bool> _onWillPop() async {
    if (!(_storyDirty || _strifeDirty)) return true;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('You have unsaved changes'),
        content: const Text('Do you want to save your changes before leaving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('discard'),
            child: const Text('Discard'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop('save'),
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == 'save') {
      await _saveAll();
      return true;
    }
    if (result == 'discard') {
      return true;
    }
    return false;
  }

  Widget? _buildFloatingActionButton() {
    if (_tabController.index == 0) {
      if (!_storyDirty) return null;
      return FloatingActionButton.extended(
        onPressed: _saveStory,
        icon: const Icon(Icons.save),
        label: const Text('Save'),
        backgroundColor: HeroTheme.primarySection,
      );
    }
    if (_tabController.index == 1) {
      if (!_strifeDirty) return null;
      return FloatingActionButton.extended(
        onPressed: _saveStrife,
        icon: const Icon(Icons.save),
        label: const Text('Save Strife'),
        backgroundColor: StrifeTheme.levelAccent,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !(_storyDirty || _strifeDirty),
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && (_storyDirty || _strifeDirty)) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          title: Text(
            _heroTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => HeroSheetPage(
                      heroId: widget.heroId,
                      heroName: _heroName ?? _heroTitle,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.visibility),
              tooltip: 'View Hero Sheet',
            ),
            if (_tabController.index == 0 && _storyDirty)
              IconButton(
                onPressed: _saveStory,
                icon: const Icon(Icons.save),
                tooltip: 'Save Hero',
              )
            else if (_tabController.index == 1 && _strifeDirty)
              IconButton(
                onPressed: _saveStrife,
                icon: const Icon(Icons.save),
                tooltip: 'Save Strife',
              ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Story'),
              Tab(text: 'Strife'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            StoryCreatorTab(
              key: _storyTabKey,
              heroId: widget.heroId,
              onDirtyChanged: _handleStoryDirty,
              onTitleChanged: _handleStoryTitleChanged,
            ),
            StrifeCreatorTab(
              key: _strifeTabKey,
              heroId: widget.heroId,
              onDirtyChanged: _handleStrifeDirty,
            ),
          ],
        ),
        floatingActionButton: _buildFloatingActionButton(),
      ),
    );
  }
}

class StrifeCreatorTab extends StatefulWidget {
  const StrifeCreatorTab({
    super.key,
    required this.heroId,
    required this.onDirtyChanged,
  });

  final String heroId;
  final ValueChanged<bool> onDirtyChanged;

  @override
  _StrifeCreatorTabState createState() => _StrifeCreatorTabState();
}

class _StrifeCreatorTabState extends State<StrifeCreatorTab> {
  bool _dirty = false;
  final GlobalKey<StrifeCreatorPageState> _pageKey =
    GlobalKey<StrifeCreatorPageState>();

  bool get isDirty => _dirty;

  void _handleDirtyChanged(bool dirty) {
    if (_dirty == dirty) return;
    setState(() {
      _dirty = dirty;
    });
    widget.onDirtyChanged(dirty);
  }

  Future<void> save() async {
    final state = _pageKey.currentState;
    if (state == null) return;
    await state.handleSave();
  }

  @override
  Widget build(BuildContext context) {
    return StrifeCreatorPage(
      key: _pageKey,
      heroId: widget.heroId,
      onDirtyChanged: _handleDirtyChanged,
      onSaveRequested: () async {
        setState(() {
          _dirty = false;
        });
        widget.onDirtyChanged(false);
      },
    );
  }
}
