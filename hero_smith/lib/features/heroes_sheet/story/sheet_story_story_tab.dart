part of 'sheet_story.dart';

extension _StoryTabBuilders on _SheetStoryState {
  Widget _buildStoryTab(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadStoryData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_storyData == null) {
      return const Center(
        child: Text('No story data available'),
      );
    }

    // Extract data from _storyData for the section widgets
    final hero = _storyData.hero;
    final ancestryId = hero?.ancestry as String?;
    final traitIds = (_storyData.ancestryTraitIds as List<dynamic>? ?? [])
        .map((id) => id.toString())
        .toList();
    
    final culture = _storyData.cultureSelection;
    final cultureData = CultureSelectionData(
      environmentId: culture.environmentId,
      organisationId: culture.organisationId,
      upbringingId: culture.upbringingId,
      environmentSkillId: culture.environmentSkillId,
      organisationSkillId: culture.organisationSkillId,
      upbringingSkillId: culture.upbringingSkillId,
    );

    final career = _storyData.careerSelection;
    final careerData = CareerSelectionData(
      careerId: career.careerId,
      incitingIncidentName: career.incitingIncidentName,
      chosenSkillIds: List<String>.from(career.chosenSkillIds),
      chosenPerkIds: List<String>.from(career.chosenPerkIds),
    );

    final complicationId = _storyData.complicationId as String?;
    final complicationChoices = 
        (_storyData.complicationChoices as Map<String, String>?) ?? {};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeroNameSection(context),
        const SizedBox(height: 16),
        AncestrySection(
          ancestryId: ancestryId,
          traitIds: traitIds,
        ),
        const SizedBox(height: 16),
        CultureSection(culture: cultureData),
        const SizedBox(height: 16),
        CareerSection(
          career: careerData,
          heroId: widget.heroId,
        ),
        const SizedBox(height: 16),
        ComplicationSection(
          complicationId: complicationId,
          complicationChoices: complicationChoices,
          heroId: widget.heroId,
        ),
      ],
    );
  }

  Widget _buildHeroNameSection(BuildContext context) {
    final theme = Theme.of(context);
    final hero = _storyData.hero;

    if (hero == null) {
      return const SizedBox.shrink();
    }

    final classAsync = (hero.className != null && (hero.className as String).isNotEmpty)
        ? ref.watch(componentByIdProvider(hero.className as String))
        : null;
    final subclassAsync = (hero.subclass != null && (hero.subclass as String).isNotEmpty)
        ? ref.watch(componentByIdProvider(hero.subclass as String))
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hero',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            InfoRow(label: 'Name', value: hero.name, icon: Icons.person),
            const SizedBox(height: 4),
            InfoRow(
              label: 'Level',
              value: hero.level.toString(),
              icon: Icons.trending_up,
            ),
            if (classAsync != null) ...[
              const SizedBox(height: 12),
              classAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Error loading class: $e'),
                data: (classComp) => InfoRow(
                  label: 'Class',
                  value: classComp?.name ?? 'Unknown',
                  icon: Icons.shield,
                ),
              ),
            ],
            if (subclassAsync != null) ...[
              const SizedBox(height: 8),
              subclassAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Error loading subclass: $e'),
                data: (subclassComp) => InfoRow(
                  label: 'Subclass',
                  value: subclassComp?.name ?? 'Unknown',
                  icon: Icons.bolt,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
