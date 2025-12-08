part of 'sheet_story.dart';

// Perks Tab Widget
class _PerksTab extends ConsumerStatefulWidget {
  final String heroId;

  const _PerksTab({required this.heroId});

  @override
  ConsumerState<_PerksTab> createState() => _PerksTabState();
}

class _PerksTabState extends ConsumerState<_PerksTab> {
  Set<String> _selectedPerkIds = {};
  List<model.Component> _languages = [];
  List<model.Component> _skills = [];
  Set<String> _reservedLanguageIds = {};
  Set<String> _reservedSkillIds = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final db = ref.read(appDatabaseProvider);
      
      // Load selected perks for this hero
      final perkIds = await db.getHeroComponentIds(widget.heroId, 'perk');
      
      // Load languages and skills for grant selections
      final languagesAsync = await ref.read(componentsByTypeProvider('language').future);
      final skillsAsync = await ref.read(componentsByTypeProvider('skill').future);
      
      // Load reserved languages and skills (already assigned to hero)
      final languageIds = await db.getHeroComponentIds(widget.heroId, 'language');
      final skillIds = await db.getHeroComponentIds(widget.heroId, 'skill');

      if (mounted) {
        setState(() {
          _selectedPerkIds = perkIds.toSet();
          _languages = languagesAsync;
          _skills = skillsAsync;
          _reservedLanguageIds = languageIds.toSet();
          _reservedSkillIds = skillIds.toSet();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load perks: $e';
        });
      }
    }
  }

  Future<void> _handleSelectionChanged(Set<String> newSelection) async {
    try {
      final db = ref.read(appDatabaseProvider);
      await db.setHeroComponentIds(
        heroId: widget.heroId,
        category: 'perk',
        componentIds: newSelection.toList(),
      );

      setState(() {
        _selectedPerkIds = newSelection;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update perks: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: PerksSelectionWidget(
        heroId: widget.heroId,
        selectedPerkIds: _selectedPerkIds,
        onSelectionChanged: _handleSelectionChanged,
        onDirty: _loadData,
        languages: _languages,
        skills: _skills,
        reservedLanguageIds: _reservedLanguageIds,
        reservedSkillIds: _reservedSkillIds,
        showHeader: true,
        headerTitle: 'Perks',
        headerSubtitle: 'Special abilities and bonuses from your career and titles',
        allowAddingNew: true,
        emptyStateMessage: 'No perks selected. Tap "Add Perk" to get started.',
      ),
    );
  }
}
