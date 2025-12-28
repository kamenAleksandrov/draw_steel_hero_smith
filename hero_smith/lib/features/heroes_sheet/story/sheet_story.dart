import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/providers.dart';
import '../../../core/models/class_data.dart';
import '../../../core/models/component.dart' as model;
import '../../../core/models/subclass_models.dart';
import '../../../core/services/class_data_service.dart';
import '../../../core/services/class_feature_data_service.dart';
import '../../../core/services/class_feature_grants_service.dart';
import '../../../core/services/complication_grants_service.dart';
import '../../../core/services/story_creator_service.dart';
import '../../../core/services/skill_data_service.dart';
import '../../../core/services/subclass_data_service.dart';
import '../../../core/services/title_grants_service.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/text/heroes_sheet/story/sheet_story_text.dart';
import '../../creators/widgets/strength_creator/class_features_section.dart';
import '../../../widgets/shared/story_display_widgets.dart';
import '../../../widgets/perks/perks_selection_widget.dart';
import 'story_sections/story_sections.dart';

part 'sheet_story_story_tab.dart';
part 'sheet_story_skills_tab.dart';
part 'sheet_story_languages_tab.dart';
part 'sheet_story_titles_tab.dart';
part 'sheet_story_features_tab.dart';
part 'sheet_story_perks_tab.dart';

// Provider to fetch a single component by ID
final componentByIdProvider =
    FutureProvider.family<model.Component?, String>((ref, id) async {
  final allComponents = await ref.read(allComponentsProvider.future);
  return allComponents.firstWhere(
    (c) => c.id == id,
    orElse: () => model.Component(
      id: '',
      type: '',
      name: 'Not found',
      data: const {},
      source: '',
    ),
  );
});

/// Class features, narrative, background, and progression notes for the hero.
class SheetStory extends ConsumerStatefulWidget {
  const SheetStory({
    super.key,
    required this.heroId,
  });

  final String heroId;

  @override
  ConsumerState<SheetStory> createState() => _SheetStoryState();
}

class _SheetStoryState extends ConsumerState<SheetStory>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _error;
  dynamic _storyData;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadStoryData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStoryData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(storyCreatorServiceProvider);
      final result = await service.loadInitialData(widget.heroId);
      
      if (mounted) {
        setState(() {
          _storyData = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load story data: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: SheetStoryTabsText.features),
            Tab(text: SheetStoryTabsText.story),
            Tab(text: SheetStoryTabsText.skills),
            Tab(text: SheetStoryTabsText.languages),
            Tab(text: SheetStoryTabsText.perks),
            Tab(text: SheetStoryTabsText.titles),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _FeaturesTab(heroId: widget.heroId),
              _buildStoryTab(context),
              _SkillsTab(heroId: widget.heroId),
              _LanguagesTab(heroId: widget.heroId),
              _PerksTab(heroId: widget.heroId),
              _TitlesTab(heroId: widget.heroId),
            ],
          ),
        ),
      ],
    );
  }
}
