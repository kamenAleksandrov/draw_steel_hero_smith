import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/providers.dart';
import '../../../core/models/class_data.dart';
import '../../../core/models/component.dart' as model;
import '../../../core/models/feature.dart' as feature_model;
import '../../../core/models/subclass_models.dart';
import '../../../core/services/class_data_service.dart';
import '../../../core/services/class_feature_data_service.dart';
import '../../../core/services/complication_grants_service.dart';
import '../../../core/services/story_creator_service.dart';
import '../../../core/services/skill_data_service.dart';
import '../../../core/services/subclass_data_service.dart';
import '../../../core/theme/app_text_styles.dart';
import 'widgets/token_tracker_widget.dart';

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
    _tabController = TabController(length: 5, vsync: this);
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
            Tab(text: 'Features'),
            Tab(text: 'Story'),
            Tab(text: 'Skills'),
            Tab(text: 'Languages'),
            Tab(text: 'Titles'),
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
              _TitlesTab(heroId: widget.heroId),
            ],
          ),
        ),
      ],
    );
  }

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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeroNameSection(context),
        const SizedBox(height: 16),
        _buildAncestrySection(context),
        const SizedBox(height: 16),
        _buildCultureSection(context),
        const SizedBox(height: 16),
        _buildCareerSection(context),
        const SizedBox(height: 16),
        _buildComplicationSection(context),
      ],
    );
  }

  Widget _buildHeroNameSection(BuildContext context) {
    final theme = Theme.of(context);
    final hero = _storyData.hero;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hero Identity',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              context,
              'Name',
              hero?.name ?? 'Unnamed Hero',
              Icons.person,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAncestrySection(BuildContext context) {
    final theme = Theme.of(context);
    final hero = _storyData.hero;
    final ancestryId = hero?.ancestry;
    final traitIds = _storyData.ancestryTraitIds as List<String>? ?? [];

    if (ancestryId == null || ancestryId.isEmpty) {
      return const SizedBox.shrink();
    }

    final ancestryAsync = ref.watch(componentByIdProvider(ancestryId));
    final traitsAsync = ref.watch(componentsByTypeProvider('ancestry_trait'));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ancestry',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ancestryAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Error loading ancestry: $e'),
              data: (ancestry) {
                if (ancestry == null) return const Text('Ancestry not found');
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      context,
                      'Ancestry',
                      ancestry.name,
                      Icons.family_restroom,
                    ),
                    if (ancestry.data['description'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        ancestry.data['description'].toString(),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ],
                );
              },
            ),
            if (traitIds.isNotEmpty) ...[
              const SizedBox(height: 16),
              traitsAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Error loading traits: $e'),
                data: (allTraits) {
                  // Find the ancestry_trait component for this ancestry
                  final ancestryTraitComponent = allTraits.cast<dynamic>().firstWhere(
                    (t) => t.data['ancestry_id'] == ancestryId,
                    orElse: () => null,
                  );
                  
                  if (ancestryTraitComponent == null && allTraits.isNotEmpty) {
                    return const Text('No trait data available for this ancestry');
                  }
                  
                  if (ancestryTraitComponent == null) {
                    return const Text('No traits available');
                  }

                  final signature = ancestryTraitComponent.data['signature'] as Map<String, dynamic>?;
                  final traitsList = ancestryTraitComponent.data['traits'] as List?;
                  
                  // Get selected traits
                  final selectedTraits = traitsList
                      ?.where((trait) => 
                          trait is Map && 
                          traitIds.contains(trait['id']?.toString()))
                      .toList() ?? [];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Signature ability
                      if (signature != null) ...[
                        Text(
                          '✨ Signature Ability',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.amber.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                signature['name']?.toString() ?? 'Unknown',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade800,
                                ),
                              ),
                              if (signature['description'] != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  signature['description'].toString(),
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Selected optional traits
                      if (selectedTraits.isNotEmpty) ...[
                        Text(
                          'Optional Traits',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...selectedTraits.map((trait) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildSelectedTraitCard(context, trait as Map<String, dynamic>),
                          );
                        }),
                      ],
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedTraitCard(BuildContext context, Map<String, dynamic> trait) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            trait['name']?.toString() ?? 'Unknown Trait',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (trait['description'] != null) ...[
            const SizedBox(height: 4),
            Text(
              trait['description'].toString(),
              style: theme.textTheme.bodySmall,
            ),
          ],
          // Display cost
          if (trait['cost'] != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Cost: ${trait['cost']} pt${trait['cost'] == 1 ? '' : 's'}',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
          // Display any ability reference
          if (trait['ability_name'] != null && 
              trait['ability_name'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildAbilityReference(context, trait['ability_name']),
          ],
        ],
      ),
    );
  }

  Widget _buildCultureSection(BuildContext context) {
    final theme = Theme.of(context);
    final culture = _storyData.cultureSelection;
    
    final hasAnySelection = (culture.environmentId != null && culture.environmentId!.isNotEmpty) ||
        (culture.organisationId != null && culture.organisationId!.isNotEmpty) ||
        (culture.upbringingId != null && culture.upbringingId!.isNotEmpty);

    if (!hasAnySelection) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Culture',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (culture.environmentId != null && culture.environmentId!.isNotEmpty)
              _buildComponentDisplay(context, 'Environment', culture.environmentId!, Icons.terrain),
            if (culture.organisationId != null && culture.organisationId!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildComponentDisplay(context, 'Organization', culture.organisationId!, Icons.groups),
            ],
            if (culture.upbringingId != null && culture.upbringingId!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildComponentDisplay(context, 'Upbringing', culture.upbringingId!, Icons.home),
            ],
            if (culture.environmentSkillId != null || 
                culture.organisationSkillId != null ||
                culture.upbringingSkillId != null) ...[
              const SizedBox(height: 16),
              Text(
                'Culture Skills',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (culture.environmentSkillId != null)
                _buildComponentDisplay(context, 'Environment Skill', culture.environmentSkillId!, Icons.school),
              if (culture.organisationSkillId != null) ...[
                const SizedBox(height: 4),
                _buildComponentDisplay(context, 'Organization Skill', culture.organisationSkillId!, Icons.school),
              ],
              if (culture.upbringingSkillId != null) ...[
                const SizedBox(height: 4),
                _buildComponentDisplay(context, 'Upbringing Skill', culture.upbringingSkillId!, Icons.school),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCareerSection(BuildContext context) {
    final theme = Theme.of(context);
    final career = _storyData.careerSelection;
    final careerId = career.careerId;

    if (careerId == null || careerId.isEmpty) {
      return const SizedBox.shrink();
    }

    final careerAsync = ref.watch(componentByIdProvider(careerId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Career',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            careerAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Error loading career: $e'),
              data: (careerComp) {
                if (careerComp == null) return const Text('Career not found');
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      context,
                      'Career',
                      careerComp.name,
                      Icons.work,
                    ),
                    if (careerComp.data['description'] != null) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 32),
                        child: Text(
                          careerComp.data['description'].toString(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ],
                    if (career.incitingIncidentName != null && 
                        career.incitingIncidentName!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Inciting Incident',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildIncitingIncident(
                        context,
                        careerComp.data,
                        career.incitingIncidentName!,
                      ),
                    ],
                    if (career.chosenSkillIds.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Career Skills',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...career.chosenSkillIds.map((skillId) =>
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _buildComponentDisplay(context, '', skillId, Icons.school),
                        ),
                      ),
                    ],
                    if (career.chosenPerkIds.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Career Perks',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...career.chosenPerkIds.map((perkId) =>
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _buildComponentDisplay(context, '', perkId, Icons.star),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplicationSection(BuildContext context) {
    final theme = Theme.of(context);
    final complicationId = _storyData.complicationId as String?;

    if (complicationId == null || complicationId.isEmpty) {
      return const SizedBox.shrink();
    }

    final complicationAsync = ref.watch(componentByIdProvider(complicationId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Complication',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            complicationAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Error loading complication: $e'),
              data: (comp) {
                if (comp == null) return const Text('Complication not found');
                
                return _buildComplicationDetails(context, comp);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplicationDetails(BuildContext context, dynamic complication) {
    final theme = Theme.of(context);
    final data = complication.data;
    final complicationId = complication.id as String;
    final choices = (_storyData.complicationChoices as Map<String, String>?) ?? {};

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            complication.name,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (data['description'] != null) ...[
            Text(
              data['description'].toString(),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
          ],
          if (data['effects'] != null) ...[
            _buildEffects(context, data['effects']),
            const SizedBox(height: 12),
          ],
          // Token tracker widget for complication tokens
          TokenTrackerWidget(heroId: widget.heroId),
          const SizedBox(height: 12),
          if (data['grants'] != null) ...[
            _buildGrants(context, data['grants'], complicationId, choices),
            const SizedBox(height: 12),
          ],
          if (data['ability'] != null) ...[
            _buildAbilityReference(context, data['ability']),
            const SizedBox(height: 12),
          ],
          if (data['feature'] != null) ...[
            _buildFeatureReference(context, data['feature']),
          ],
        ],
      ),
    );
  }

  Widget _buildEffects(BuildContext context, dynamic effects) {
    final theme = Theme.of(context);
    final effectsData = effects as Map<String, dynamic>?;
    if (effectsData == null) return const SizedBox.shrink();

    final benefit = effectsData['benefit']?.toString();
    final drawback = effectsData['drawback']?.toString();
    final both = effectsData['both']?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Effects',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (benefit != null && benefit.isNotEmpty) ...[
          _buildEffectItem(
            context,
            'Benefit',
            benefit,
            theme.colorScheme.primary,
            Icons.add_circle_outline,
          ),
          const SizedBox(height: 8),
        ],
        if (drawback != null && drawback.isNotEmpty) ...[
          _buildEffectItem(
            context,
            'Drawback',
            drawback,
            theme.colorScheme.error,
            Icons.remove_circle_outline,
          ),
          const SizedBox(height: 8),
        ],
        if (both != null && both.isNotEmpty) ...[
          _buildEffectItem(
            context,
            'Mixed Effect',
            both,
            theme.colorScheme.tertiary,
            Icons.swap_horiz,
          ),
        ],
      ],
    );
  }

  Widget _buildEffectItem(
    BuildContext context,
    String label,
    String text,
    Color color,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrants(
    BuildContext context,
    dynamic grants,
    String complicationId,
    Map<String, String> choices,
  ) {
    final theme = Theme.of(context);
    final grantsData = grants as Map<String, dynamic>?;
    if (grantsData == null || grantsData.isEmpty) {
      return const SizedBox.shrink();
    }

    final items = <Widget>[];

    // Treasures
    if (grantsData['treasures'] is List) {
      final treasures = grantsData['treasures'] as List;
      for (final treasure in treasures) {
        if (treasure is Map) {
          final type = treasure['type']?.toString() ?? 'treasure';
          final echelon = treasure['echelon'];
          final choice = treasure['choice'] == true;
          
          final text = choice
              ? '${type.replaceAll('_', ' ')}${echelon != null ? ' (echelon $echelon)' : ''} of your choice'
              : '${type.replaceAll('_', ' ')}${echelon != null ? ' (echelon $echelon)' : ''}';
          
          items.add(_buildGrantItem(context, text, Icons.diamond_outlined));
        }
      }
    }

    // Tokens
    if (grantsData['tokens'] is Map) {
      final tokens = grantsData['tokens'] as Map;
      tokens.forEach((key, value) {
        items.add(_buildGrantItem(
          context,
          '$value ${key.toString().replaceAll('_', ' ')} token${value == 1 ? '' : 's'}',
          Icons.token_outlined,
        ));
      });
    }

    // Languages
    if (grantsData['languages'] != null) {
      final count = grantsData['languages'] as int? ?? 1;
      items.add(_buildLanguageGrantsDisplay(context, complicationId, choices, count));
    }

    // Dead Languages
    if (grantsData['dead_language'] != null) {
      final count = grantsData['dead_language'] as int? ?? 1;
      items.add(_buildDeadLanguageGrantsDisplay(context, complicationId, choices, count));
    }

    // Skill from options
    if (grantsData['skill_from_options'] != null) {
      items.add(_buildSkillChoiceDisplay(context, complicationId, choices, 'skill_option'));
    }

    // Skill from group
    if (grantsData['skill_from_group'] != null) {
      items.add(_buildSkillChoiceDisplay(context, complicationId, choices, 'skill_group'));
    }

    // Ancestry traits (e.g., Dragon Dreams)
    if (grantsData['ancestry_traits'] != null) {
      items.add(_buildAncestryTraitsDisplay(context, complicationId, choices, grantsData['ancestry_traits']));
    }

    // Pick one grants
    if (grantsData['pick_one'] != null) {
      items.add(_buildPickOneDisplay(context, complicationId, choices, grantsData['pick_one']));
    }

    // Increase total grants
    if (grantsData['increase_total'] is List) {
      final increases = grantsData['increase_total'] as List;
      for (final inc in increases) {
        if (inc is Map) {
          final stat = inc['stat']?.toString() ?? '';
          final value = inc['value'];
          final perEchelon = inc['per_echelon'] == true;
          final text = perEchelon
              ? '+$value ${stat.replaceAll('_', ' ')} per echelon'
              : '+$value ${stat.replaceAll('_', ' ')}';
          items.add(_buildGrantItem(context, text, Icons.trending_up_outlined));
        }
      }
    }

    // Abilities
    if (grantsData['abilities'] is List) {
      final abilities = grantsData['abilities'] as List;
      for (final ability in abilities) {
        items.add(_buildGrantItem(context, 'Ability: $ability', Icons.auto_awesome_outlined));
      }
    }
    if (grantsData['ability'] != null) {
      items.add(_buildGrantItem(context, 'Ability: ${grantsData['ability']}', Icons.auto_awesome_outlined));
    }

    // Skills (direct grants)
    if (grantsData['skills'] is List) {
      final skills = grantsData['skills'] as List;
      for (final skill in skills) {
        items.add(_buildGrantItem(context, 'Skill: $skill', Icons.psychology_outlined));
      }
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Grants',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...items,
      ],
    );
  }

  Widget _buildLanguageGrantsDisplay(
    BuildContext context,
    String complicationId,
    Map<String, String> choices,
    int count,
  ) {
    final languagesAsync = ref.watch(componentsByTypeProvider('language'));
    
    return languagesAsync.when(
      loading: () => _buildGrantItem(context, 'Languages: Loading...', Icons.translate_outlined),
      error: (e, _) => _buildGrantItem(context, 'Languages: Error loading', Icons.translate_outlined),
      data: (allLanguages) {
        final selectedNames = <String>[];
        for (int i = 0; i < count; i++) {
          final choiceKey = '${complicationId}_language_$i';
          final selectedId = choices[choiceKey];
          if (selectedId != null && selectedId.isNotEmpty) {
            final lang = allLanguages.firstWhere(
              (l) => l.id == selectedId,
              orElse: () => model.Component(id: '', type: '', name: selectedId, data: const {}),
            );
            selectedNames.add(lang.name);
          }
        }
        
        if (selectedNames.isEmpty) {
          return _buildGrantItem(context, 'Choose $count language${count == 1 ? '' : 's'}', Icons.translate_outlined);
        }
        
        return _buildGrantItem(
          context,
          'Language${selectedNames.length == 1 ? '' : 's'}: ${selectedNames.join(', ')}',
          Icons.translate_outlined,
        );
      },
    );
  }

  Widget _buildDeadLanguageGrantsDisplay(
    BuildContext context,
    String complicationId,
    Map<String, String> choices,
    int count,
  ) {
    final languagesAsync = ref.watch(componentsByTypeProvider('language'));
    
    return languagesAsync.when(
      loading: () => _buildGrantItem(context, 'Dead Languages: Loading...', Icons.history_edu_outlined),
      error: (e, _) => _buildGrantItem(context, 'Dead Languages: Error loading', Icons.history_edu_outlined),
      data: (allLanguages) {
        final selectedNames = <String>[];
        for (int i = 0; i < count; i++) {
          final choiceKey = '${complicationId}_dead_language_$i';
          final selectedId = choices[choiceKey];
          if (selectedId != null && selectedId.isNotEmpty) {
            final lang = allLanguages.firstWhere(
              (l) => l.id == selectedId,
              orElse: () => model.Component(id: '', type: '', name: selectedId, data: const {}),
            );
            selectedNames.add(lang.name);
          }
        }
        
        if (selectedNames.isEmpty) {
          return _buildGrantItem(context, 'Choose $count dead language${count == 1 ? '' : 's'}', Icons.history_edu_outlined);
        }
        
        return _buildGrantItem(
          context,
          'Dead Language${selectedNames.length == 1 ? '' : 's'}: ${selectedNames.join(', ')}',
          Icons.history_edu_outlined,
        );
      },
    );
  }

  Widget _buildSkillChoiceDisplay(
    BuildContext context,
    String complicationId,
    Map<String, String> choices,
    String choiceType,
  ) {
    final skillsAsync = ref.watch(componentsByTypeProvider('skill'));
    final choiceKey = '${complicationId}_$choiceType';
    final selectedId = choices[choiceKey];
    
    return skillsAsync.when(
      loading: () => _buildGrantItem(context, 'Skill: Loading...', Icons.psychology_outlined),
      error: (e, _) => _buildGrantItem(context, 'Skill: Error loading', Icons.psychology_outlined),
      data: (allSkills) {
        if (selectedId == null || selectedId.isEmpty) {
          return _buildGrantItem(context, 'Choose a skill', Icons.psychology_outlined);
        }
        
        final skill = allSkills.firstWhere(
          (s) => s.id == selectedId,
          orElse: () => model.Component(id: '', type: '', name: selectedId, data: const {}),
        );
        
        return _buildGrantItem(context, 'Skill: ${skill.name}', Icons.psychology_outlined);
      },
    );
  }

  Widget _buildAncestryTraitsDisplay(
    BuildContext context,
    String complicationId,
    Map<String, String> choices,
    dynamic ancestryTraitsData,
  ) {
    final theme = Theme.of(context);
    final ancestry = ancestryTraitsData['ancestry'] as String? ?? '';
    final points = ancestryTraitsData['ancestry_points'] as int? ?? 0;
    final ancestryTraitsAsync = ref.watch(componentsByTypeProvider('ancestry_trait'));
    
    final choiceKey = '${complicationId}_ancestry_traits';
    final selectedIdsStr = choices[choiceKey] ?? '';
    final selectedIds = selectedIdsStr.isNotEmpty ? selectedIdsStr.split(',').toSet() : <String>{};
    
    if (selectedIds.isEmpty) {
      return _buildGrantItem(
        context,
        'Choose $points ${_formatAncestryName(ancestry)} ancestry trait point${points == 1 ? '' : 's'}',
        Icons.person_outline,
      );
    }
    
    return ancestryTraitsAsync.when(
      loading: () => _buildGrantItem(context, 'Ancestry Traits: Loading...', Icons.person_outline),
      error: (e, _) => _buildGrantItem(context, 'Ancestry Traits: ${selectedIds.length} selected', Icons.person_outline),
      data: (allAncestryTraits) {
        // Find the ancestry traits component
        final targetAncestryId = 'ancestry_$ancestry';
        final traitsComp = allAncestryTraits.cast<model.Component>().firstWhere(
          (t) => t.data['ancestry_id'] == targetAncestryId,
          orElse: () => model.Component(id: '', type: '', name: '', data: const {}),
        );
        
        final traitsList = (traitsComp.data['traits'] as List?)?.cast<Map>() ?? const <Map>[];
        final selectedTraits = <Map<String, dynamic>>[];
        
        for (final id in selectedIds) {
          final trait = traitsList.firstWhere(
            (t) => (t['id'] ?? t['name']).toString() == id,
            orElse: () => const {},
          );
          if (trait.isNotEmpty) {
            selectedTraits.add(trait.cast<String, dynamic>());
          }
        }
        
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.person_outline, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_formatAncestryName(ancestry)} Traits',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...selectedTraits.map((trait) {
                final name = trait['name']?.toString() ?? '';
                final description = trait['description']?.toString() ?? '';
                final cost = trait['cost'] as int? ?? 0;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$cost pt${cost == 1 ? '' : 's'}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            description,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPickOneDisplay(
    BuildContext context,
    String complicationId,
    Map<String, String> choices,
    dynamic pickOneData,
  ) {
    final theme = Theme.of(context);
    final choiceKey = '${complicationId}_pick_one';
    final selectedIndexStr = choices[choiceKey];
    final selectedIndex = selectedIndexStr != null ? int.tryParse(selectedIndexStr) : null;
    
    if (pickOneData is! List || pickOneData.isEmpty) {
      return const SizedBox.shrink();
    }
    
    if (selectedIndex == null || selectedIndex < 0 || selectedIndex >= pickOneData.length) {
      return _buildGrantItem(context, 'Choose one option', Icons.check_circle_outline);
    }
    
    final selectedOption = pickOneData[selectedIndex] as Map<String, dynamic>;
    final description = selectedOption['description'] as String? ?? 'Option ${selectedIndex + 1}';
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 16, color: theme.colorScheme.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAncestryName(String ancestry) {
    // Convert "dragon_knight" to "Dragon Knight"
    return ancestry.split('_').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  Widget _buildGrantItem(BuildContext context, String text, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComponentDisplay(
    BuildContext context,
    String label,
    String componentId,
    IconData icon,
  ) {
    final componentAsync = ref.watch(componentByIdProvider(componentId));
    
    return componentAsync.when(
      loading: () => const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
      data: (component) {
        if (component == null) return Text('$label not found');
        
        return _buildComponentDetails(context, label, component, icon);
      },
    );
  }

  Widget _buildComponentDetails(
    BuildContext context,
    String label,
    dynamic component,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final description = component.data['description']?.toString();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isEmpty)
          _buildInfoRow(context, '', component.name, icon)
        else
          _buildInfoRow(context, label, component.name, icon),
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGrantsList(BuildContext context, dynamic grants) {
    final theme = Theme.of(context);
    if (grants == null) return const SizedBox.shrink();
    
    final items = <Widget>[];
    
    if (grants is Map) {
      grants.forEach((key, value) {
        if (value != null) {
          items.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$key: $value',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      });
    } else if (grants is List) {
      for (final grant in grants) {
        items.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(
                  Icons.add_circle_outline,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    grant.toString(),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    
    if (items.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Grants:',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        ...items,
      ],
    );
  }

  Widget _buildAbilityReference(BuildContext context, dynamic ability) {
    final theme = Theme.of(context);
    if (ability == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.flash_on,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Ability: ${ability.toString()}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureReference(BuildContext context, dynamic feature) {
    final theme = Theme.of(context);
    if (feature == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.secondary.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.stars,
            size: 16,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Feature: ${feature.toString()}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (label.isNotEmpty) ...[
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIncitingIncident(
    BuildContext context,
    Map<String, dynamic> careerData,
    String incidentName,
  ) {
    final theme = Theme.of(context);
    final incidents = careerData['inciting_incidents'] as List?;
    
    if (incidents == null) {
      return Text(incidentName);
    }
    
    // Find the matching incident
    final incident = incidents.cast<Map<String, dynamic>>().firstWhere(
      (i) => i['name']?.toString() == incidentName,
      orElse: () => <String, dynamic>{},
    );
    
    if (incident.isEmpty) {
      return Text(incidentName);
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.flash_on,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  incident['name']?.toString() ?? incidentName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (incident['description'] != null) ...[
            const SizedBox(height: 8),
            Text(
              incident['description'].toString(),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

// Skills Tab Widget
class _SkillsTab extends ConsumerStatefulWidget {
  final String heroId;

  const _SkillsTab({required this.heroId});

  @override
  ConsumerState<_SkillsTab> createState() => _SkillsTabState();
}

class _SkillsTabState extends ConsumerState<_SkillsTab> {
  final SkillDataService _skillService = SkillDataService();
  List<_SkillOption> _availableSkills = [];
  List<String> _selectedSkillIds = [];
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

      // Load skills from service
      final skills = await _skillService.loadSkills();

      _availableSkills = skills.map((skill) {
        return _SkillOption(
          id: skill.id,
          name: skill.name,
          group: skill.group,
          description: skill.description,
        );
      }).toList();

      final grantsService = ref.read(complicationGrantsServiceProvider);
      await grantsService.syncSkillGrants(widget.heroId);

      // Load selected skills for this hero
      final db = ref.read(appDatabaseProvider);
      _selectedSkillIds = await db.getHeroComponentIds(widget.heroId, 'skill');

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load skills: $e';
      });
    }
  }

  Future<void> _addSkill(String skillId) async {
    try {
      final db = ref.read(appDatabaseProvider);
      final updatedIds = [..._selectedSkillIds, skillId];
      await db.setHeroComponentIds(
        heroId: widget.heroId,
        category: 'skill',
        componentIds: updatedIds,
      );

      setState(() {
        _selectedSkillIds = updatedIds;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add skill: $e')),
        );
      }
    }
  }

  Future<void> _removeSkill(String skillId) async {
    try {
      final db = ref.read(appDatabaseProvider);
      final updatedIds = _selectedSkillIds.where((id) => id != skillId).toList();
      await db.setHeroComponentIds(
        heroId: widget.heroId,
        category: 'skill',
        componentIds: updatedIds,
      );

      setState(() {
        _selectedSkillIds = updatedIds;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove skill: $e')),
        );
      }
    }
  }

  void _showAddSkillDialog() {
    final unselectedSkills = _availableSkills
        .where((skill) => !_selectedSkillIds.contains(skill.id))
        .toList();

    showDialog(
      context: context,
      builder: (context) => _AddSkillDialog(
        availableSkills: unselectedSkills,
        onSkillSelected: (skillId) {
          _addSkill(skillId);
          Navigator.of(context).pop();
        },
      ),
    );
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

    final selectedSkills = _availableSkills
        .where((skill) => _selectedSkillIds.contains(skill.id))
        .toList();

    // Group skills by category
    final groupedSkills = <String, List<_SkillOption>>{};
    for (final skill in selectedSkills) {
      groupedSkills.putIfAbsent(skill.group, () => []).add(skill);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Skills',
                style: AppTextStyles.title,
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _showAddSkillDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Skill'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (selectedSkills.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No skills selected. Tap "Add Skill" to get started.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...groupedSkills.entries.map((entry) {
              final groupName = entry.key;
              final skills = entry.value;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (groupName.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                      child: Text(
                        groupName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                  ...skills.map((skill) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(skill.name),
                          subtitle: skill.description.isNotEmpty
                              ? Text(skill.description)
                              : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => _removeSkill(skill.id),
                            tooltip: 'Remove skill',
                          ),
                        ),
                      )),
                ],
              );
            }),
        ],
      ),
    );
  }
}

class _AddSkillDialog extends StatefulWidget {
  final List<_SkillOption> availableSkills;
  final Function(String) onSkillSelected;

  const _AddSkillDialog({
    required this.availableSkills,
    required this.onSkillSelected,
  });

  @override
  State<_AddSkillDialog> createState() => _AddSkillDialogState();
}

class _AddSkillDialogState extends State<_AddSkillDialog> {
  String _searchQuery = '';
  List<_SkillOption> _filteredSkills = [];

  @override
  void initState() {
    super.initState();
    _filteredSkills = widget.availableSkills;
  }

  void _filterSkills(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredSkills = widget.availableSkills;
      } else {
        _filteredSkills = widget.availableSkills
            .where((skill) =>
                skill.name.toLowerCase().contains(query.toLowerCase()) ||
                skill.description.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Add Skill'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search skills',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _filterSkills,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: _filteredSkills.isEmpty
                  ? Center(
                      child: Text(
                        'No skills found',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredSkills.length,
                      itemBuilder: (context, index) {
                        final skill = _filteredSkills[index];
                        return ListTile(
                          title: Text(skill.name),
                          subtitle: skill.description.isNotEmpty
                              ? Text(skill.description)
                              : null,
                          onTap: () => widget.onSkillSelected(skill.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

// Languages Tab Widget
class _LanguagesTab extends ConsumerStatefulWidget {
  final String heroId;

  const _LanguagesTab({required this.heroId});

  @override
  ConsumerState<_LanguagesTab> createState() => _LanguagesTabState();
}

class _LanguagesTabState extends ConsumerState<_LanguagesTab> {
  List<_LanguageOption> _availableLanguages = [];
  List<String> _selectedLanguageIds = [];
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

      // Load languages from JSON - it's a direct array, not wrapped in an object
      final languagesData = await rootBundle.loadString('data/story/languages.json');
      final languagesList = json.decode(languagesData) as List;

      _availableLanguages = languagesList.map((lang) {
        final langMap = lang as Map<String, dynamic>;
        return _LanguageOption(
          id: langMap['id'] as String,
          name: langMap['name'] as String,
          languageType: langMap['language_type'] as String? ?? '',
          region: langMap['region'] as String? ?? '',
          ancestry: langMap['ancestry'] as String? ?? '',
        );
      }).toList();

      // Load selected languages for this hero
      final db = ref.read(appDatabaseProvider);
      _selectedLanguageIds = await db.getHeroComponentIds(widget.heroId, 'language');

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load languages: $e';
      });
    }
  }

  Future<void> _addLanguage(String languageId) async {
    try {
      final db = ref.read(appDatabaseProvider);
      final updatedIds = [..._selectedLanguageIds, languageId];
      await db.setHeroComponentIds(
        heroId: widget.heroId,
        category: 'language',
        componentIds: updatedIds,
      );

      setState(() {
        _selectedLanguageIds = updatedIds;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add language: $e')),
        );
      }
    }
  }

  Future<void> _removeLanguage(String languageId) async {
    try {
      final db = ref.read(appDatabaseProvider);
      final updatedIds = _selectedLanguageIds.where((id) => id != languageId).toList();
      await db.setHeroComponentIds(
        heroId: widget.heroId,
        category: 'language',
        componentIds: updatedIds,
      );

      setState(() {
        _selectedLanguageIds = updatedIds;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove language: $e')),
        );
      }
    }
  }

  void _showAddLanguageDialog() {
    final unselectedLanguages = _availableLanguages
        .where((lang) => !_selectedLanguageIds.contains(lang.id))
        .toList();

    showDialog(
      context: context,
      builder: (context) => _AddLanguageDialog(
        availableLanguages: unselectedLanguages,
        onLanguageSelected: (languageId) {
          _addLanguage(languageId);
          Navigator.of(context).pop();
        },
      ),
    );
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

    final selectedLanguages = _availableLanguages
        .where((lang) => _selectedLanguageIds.contains(lang.id))
        .toList();

    // Group languages by type
    final groupedLanguages = <String, List<_LanguageOption>>{};
    for (final lang in selectedLanguages) {
      final groupKey = lang.languageType.isNotEmpty ? lang.languageType : 'Other';
      groupedLanguages.putIfAbsent(groupKey, () => []).add(lang);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Languages',
                style: AppTextStyles.title,
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _showAddLanguageDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Language'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (selectedLanguages.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No languages selected. Tap "Add Language" to get started.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...groupedLanguages.entries.map((entry) {
              final groupName = entry.key;
              final languages = entry.value;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 8),
                    child: Text(
                      groupName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  ...languages.map((lang) {
                    String subtitle = '';
                    if (lang.region.isNotEmpty) {
                      subtitle = 'Region: ${lang.region}';
                    }
                    if (lang.ancestry.isNotEmpty) {
                      subtitle = subtitle.isEmpty
                          ? 'Ancestry: ${lang.ancestry}'
                          : '$subtitle • Ancestry: ${lang.ancestry}';
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(lang.name),
                        subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => _removeLanguage(lang.id),
                          tooltip: 'Remove language',
                        ),
                      ),
                    );
                  }),
                ],
              );
            }),
        ],
      ),
    );
  }
}

class _AddLanguageDialog extends StatefulWidget {
  final List<_LanguageOption> availableLanguages;
  final Function(String) onLanguageSelected;

  const _AddLanguageDialog({
    required this.availableLanguages,
    required this.onLanguageSelected,
  });

  @override
  State<_AddLanguageDialog> createState() => _AddLanguageDialogState();
}

class _AddLanguageDialogState extends State<_AddLanguageDialog> {
  String _searchQuery = '';
  List<_LanguageOption> _filteredLanguages = [];

  @override
  void initState() {
    super.initState();
    _filteredLanguages = widget.availableLanguages;
  }

  void _filterLanguages(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredLanguages = widget.availableLanguages;
      } else {
        _filteredLanguages = widget.availableLanguages
            .where((lang) =>
                lang.name.toLowerCase().contains(query.toLowerCase()) ||
                lang.region.toLowerCase().contains(query.toLowerCase()) ||
                lang.ancestry.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Add Language'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search languages',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _filterLanguages,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: _filteredLanguages.isEmpty
                  ? Center(
                      child: Text(
                        'No languages found',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredLanguages.length,
                      itemBuilder: (context, index) {
                        final lang = _filteredLanguages[index];
                        String subtitle = '';
                        if (lang.region.isNotEmpty) {
                          subtitle = 'Region: ${lang.region}';
                        }
                        if (lang.ancestry.isNotEmpty) {
                          subtitle = subtitle.isEmpty
                              ? 'Ancestry: ${lang.ancestry}'
                              : '$subtitle • Ancestry: ${lang.ancestry}';
                        }

                        return ListTile(
                          title: Text(lang.name),
                          subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
                          onTap: () => widget.onLanguageSelected(lang.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

// Data models
class _SkillOption {
  final String id;
  final String name;
  final String group;
  final String description;

  _SkillOption({
    required this.id,
    required this.name,
    required this.group,
    required this.description,
  });
}

class _LanguageOption {
  final String id;
  final String name;
  final String languageType;
  final String region;
  final String ancestry;

  _LanguageOption({
    required this.id,
    required this.name,
    required this.languageType,
    required this.region,
    required this.ancestry,
  });
}

// Titles Tab Widget
class _TitlesTab extends ConsumerStatefulWidget {
  final String heroId;

  const _TitlesTab({required this.heroId});

  @override
  ConsumerState<_TitlesTab> createState() => _TitlesTabState();
}

class _TitlesTabState extends ConsumerState<_TitlesTab> {
  List<Map<String, dynamic>> _availableTitles = [];
  Map<String, Map<String, dynamic>> _selectedTitles = {}; // titleId -> {title, selectedBenefitIndex}
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

      // Load titles from JSON
      final titlesData = await rootBundle.loadString('data/story/titles.json');
      final titlesList = json.decode(titlesData) as List;
      _availableTitles = titlesList.cast<Map<String, dynamic>>();

      // Load selected titles for this hero from database
      final db = ref.read(appDatabaseProvider);
      final storedTitles = await db.getHeroComponentIds(widget.heroId, 'title');
      
      // Parse stored titles - format: "titleId:benefitIndex"
      _selectedTitles = {};
      for (final storedTitle in storedTitles) {
        final parts = storedTitle.split(':');
        if (parts.length == 2) {
          final titleId = parts[0];
          final benefitIndex = int.tryParse(parts[1]) ?? 0;
          final title = _availableTitles.firstWhere(
            (t) => t['id'] == titleId,
            orElse: () => <String, dynamic>{},
          );
          if (title.isNotEmpty) {
            _selectedTitles[titleId] = {
              'title': title,
              'selectedBenefitIndex': benefitIndex,
            };
          }
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load titles: $e';
      });
    }
  }

  Future<void> _addTitle(String titleId, int benefitIndex) async {
    try {
      final db = ref.read(appDatabaseProvider);
      final title = _availableTitles.firstWhere((t) => t['id'] == titleId);
      
      _selectedTitles[titleId] = {
        'title': title,
        'selectedBenefitIndex': benefitIndex,
      };
      
      // Store as "titleId:benefitIndex"
      final updatedIds = _selectedTitles.entries
          .map((e) => '${e.key}:${e.value['selectedBenefitIndex']}')
          .toList();
      
      await db.setHeroComponentIds(
        heroId: widget.heroId,
        category: 'title',
        componentIds: updatedIds,
      );

      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add title: $e')),
        );
      }
    }
  }

  Future<void> _removeTitle(String titleId) async {
    try {
      final db = ref.read(appDatabaseProvider);
      _selectedTitles.remove(titleId);
      
      final updatedIds = _selectedTitles.entries
          .map((e) => '${e.key}:${e.value['selectedBenefitIndex']}')
          .toList();
      
      await db.setHeroComponentIds(
        heroId: widget.heroId,
        category: 'title',
        componentIds: updatedIds,
      );

      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove title: $e')),
        );
      }
    }
  }

  Future<void> _changeBenefit(String titleId, int newBenefitIndex) async {
    if (_selectedTitles.containsKey(titleId)) {
      _selectedTitles[titleId]!['selectedBenefitIndex'] = newBenefitIndex;
      
      final db = ref.read(appDatabaseProvider);
      final updatedIds = _selectedTitles.entries
          .map((e) => '${e.key}:${e.value['selectedBenefitIndex']}')
          .toList();
      
      await db.setHeroComponentIds(
        heroId: widget.heroId,
        category: 'title',
        componentIds: updatedIds,
      );

      setState(() {});
    }
  }

  void _showAddTitleDialog() {
    final unselectedTitles = _availableTitles
        .where((title) => !_selectedTitles.containsKey(title['id']))
        .toList();

    showDialog(
      context: context,
      builder: (context) => _AddTitleDialog(
        availableTitles: unselectedTitles,
        onTitleSelected: (titleId, benefitIndex) {
          _addTitle(titleId, benefitIndex);
          Navigator.of(context).pop();
        },
      ),
    );
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
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Group titles by echelon
    final groupedTitles = <int, List<MapEntry<String, Map<String, dynamic>>>>{};
    for (final entry in _selectedTitles.entries) {
      final echelon = entry.value['title']['echelon'] as int? ?? 1;
      groupedTitles.putIfAbsent(echelon, () => []).add(entry);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Titles',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _showAddTitleDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Title'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_selectedTitles.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No titles selected'),
              ),
            )
          else
            ...groupedTitles.entries.map((group) {
              final echelon = group.key;
              final titles = group.value;
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Echelon $echelon',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  ...titles.map((entry) => _buildTitleCard(context, entry.key, entry.value)),
                  const SizedBox(height: 16),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTitleCard(BuildContext context, String titleId, Map<String, dynamic> data) {
    final theme = Theme.of(context);
    final title = data['title'] as Map<String, dynamic>;
    final selectedBenefitIndex = data['selectedBenefitIndex'] as int;
    final benefits = title['benefits'] as List? ?? [];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title['name'] as String? ?? 'Unknown',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (title['prerequisite'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Prerequisite: ${title['prerequisite']}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _removeTitle(titleId),
                  tooltip: 'Remove Title',
                ),
              ],
            ),
            if (title['description_text'] != null) ...[
              const SizedBox(height: 12),
              Text(
                title['description_text'] as String,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Selected Benefit:',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (benefits.isNotEmpty && selectedBenefitIndex < benefits.length)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBenefitContent(context, benefits[selectedBenefitIndex]),
                    if (benefits.length > 1) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => _showChangeBenefitDialog(titleId, benefits),
                        icon: const Icon(Icons.swap_horiz, size: 18),
                        label: const Text('Change Benefit'),
                      ),
                    ],
                  ],
                ),
              ),
            if (title['special'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 20, color: theme.colorScheme.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Special: ${title['special']}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitContent(BuildContext context, dynamic benefit) {
    final theme = Theme.of(context);
    if (benefit is! Map<String, dynamic>) return const SizedBox.shrink();
    
    final description = benefit['description'] as String?;
    final ability = benefit['ability'] as String?;
    final grants = benefit['grants'] as List?;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (description != null && description.isNotEmpty)
          Text(description, style: theme.textTheme.bodyMedium),
        if (ability != null && ability.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.flash_on, size: 16, color: theme.colorScheme.secondary),
              const SizedBox(width: 4),
              Text(
                'Ability: $ability',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ],
          ),
        ],
        if (grants != null && grants.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...grants.map((grant) {
            if (grant is Map<String, dynamic>) {
              final type = grant['type'] as String?;
              final value = grant['value'];
              if (type != null) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.card_giftcard, size: 16, color: theme.colorScheme.tertiary),
                      const SizedBox(width: 4),
                      Text(
                        'Grants: ${_formatGrant(type, value)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.tertiary,
                        ),
                      ),
                    ],
                  ),
                );
              }
            }
            return const SizedBox.shrink();
          }),
        ],
      ],
    );
  }

  String _formatGrant(String type, dynamic value) {
    switch (type) {
      case 'renown':
        return '+$value Renown';
      case 'wealth':
        return '+$value Wealth';
      case 'followers_cap':
        return '+$value Followers Cap';
      case 'skill_choice':
        return 'Choose $value Skill';
      case 'languages':
        return 'Language: ${value}';
      default:
        return '$type: $value';
    }
  }

  void _showChangeBenefitDialog(String titleId, List benefits) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Benefit'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: benefits.length,
            itemBuilder: (context, index) {
              final benefit = benefits[index];
              final isSelected = _selectedTitles[titleId]!['selectedBenefitIndex'] == index;
              
              return Card(
                color: isSelected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                child: InkWell(
                  onTap: () {
                    _changeBenefit(titleId, index);
                    Navigator.of(context).pop();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Benefit ${index + 1}',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.check_circle,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildBenefitContent(context, benefit),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

// Add Title Dialog
class _AddTitleDialog extends StatefulWidget {
  final List<Map<String, dynamic>> availableTitles;
  final Function(String, int) onTitleSelected;

  const _AddTitleDialog({
    required this.availableTitles,
    required this.onTitleSelected,
  });

  @override
  State<_AddTitleDialog> createState() => _AddTitleDialogState();
}

class _AddTitleDialogState extends State<_AddTitleDialog> {
  String _searchQuery = '';
  int? _selectedEchelon;
  List<Map<String, dynamic>> _filteredTitles = [];

  @override
  void initState() {
    super.initState();
    _filteredTitles = widget.availableTitles;
  }

  void _filterTitles() {
    setState(() {
      _filteredTitles = widget.availableTitles.where((title) {
        final matchesSearch = _searchQuery.isEmpty ||
            (title['name'] as String?)?.toLowerCase().contains(_searchQuery.toLowerCase()) == true ||
            (title['description_text'] as String?)?.toLowerCase().contains(_searchQuery.toLowerCase()) == true;
        
        final matchesEchelon = _selectedEchelon == null ||
            title['echelon'] == _selectedEchelon;
        
        return matchesSearch && matchesEchelon;
      }).toList();
    });
  }

  void _showBenefitSelectionDialog(Map<String, dynamic> title) {
    final benefits = title['benefits'] as List? ?? [];
    
    if (benefits.isEmpty) {
      widget.onTitleSelected(title['id'] as String, 0);
      return;
    }
    
    if (benefits.length == 1) {
      widget.onTitleSelected(title['id'] as String, 0);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Benefit for ${title['name']}'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: benefits.length,
            itemBuilder: (context, index) {
              final benefit = benefits[index];
              
              return Card(
                child: InkWell(
                  onTap: () {
                    widget.onTitleSelected(title['id'] as String, index);
                    Navigator.of(context).pop();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Benefit ${index + 1}',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (benefit is Map<String, dynamic>) ...[
                          if (benefit['description'] != null)
                            Text(
                              benefit['description'] as String,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Add Title'),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search titles',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                _searchQuery = value;
                _filterTitles();
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedEchelon == null,
                  onSelected: (selected) {
                    _selectedEchelon = null;
                    _filterTitles();
                  },
                ),
                ...List.generate(4, (index) {
                  final echelon = index + 1;
                  return FilterChip(
                    label: Text('Echelon $echelon'),
                    selected: _selectedEchelon == echelon,
                    onSelected: (selected) {
                      _selectedEchelon = selected ? echelon : null;
                      _filterTitles();
                    },
                  );
                }),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _filteredTitles.isEmpty
                  ? const Center(child: Text('No titles found'))
                  : ListView.builder(
                      itemCount: _filteredTitles.length,
                      itemBuilder: (context, index) {
                        final title = _filteredTitles[index];
                        
                        return Card(
                          child: ListTile(
                            title: Text(
                              title['name'] as String? ?? 'Unknown',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (title['description_text'] != null)
                                  Text(
                                    title['description_text'] as String,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  'Echelon ${title['echelon']} • ${(title['benefits'] as List?)?.length ?? 0} benefits',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () => _showBenefitSelectionDialog(title),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

/// Tab showing class features (read-only)
class _FeaturesTab extends ConsumerStatefulWidget {
  const _FeaturesTab({required this.heroId});

  final String heroId;

  @override
  ConsumerState<_FeaturesTab> createState() => _FeaturesTabState();
}

class _FeaturesTabState extends ConsumerState<_FeaturesTab> {
  final ClassDataService _classDataService = ClassDataService();
  final ClassFeatureDataService _featureService = ClassFeatureDataService();
  final SubclassDataService _subclassDataService = SubclassDataService();

  bool _isLoading = true;
  String? _error;
  ClassData? _classData;
  int _level = 1;
  ClassFeatureDataResult? _featureData;
  SubclassSelectionResult? _subclassSelection;
  DeityOption? _selectedDeity;
  List<String> _selectedDomains = const <String>[];
  String? _characteristicArrayDescription;
  Map<String, Set<String>> _autoSelections = const <String, Set<String>>{};

  @override
  void initState() {
    super.initState();
    _loadHeroData();
  }

  Future<void> _loadHeroData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _classDataService.initialize();
      final repo = ref.read(heroRepositoryProvider);
      final db = ref.read(appDatabaseProvider);
      final hero = await repo.load(widget.heroId);

      if (hero == null || hero.className == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = 'No class assigned to this hero';
          });
        }
        return;
      }

      final classData = _classDataService
          .getAllClasses()
          .firstWhere((c) => c.classId == hero.className);

      // Capture characteristic array description if stored in hero values
      String? arrayDescription;
      final heroValues = await db.getHeroValues(widget.heroId);
      for (final value in heroValues) {
        if (value.key == 'strife.characteristic_array') {
          arrayDescription = value.textValue;
          break;
        }
      }

      final domainNames = hero.domain == null
          ? <String>[]
          : hero.domain!
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();

      DeityOption? deityOption;
      if (hero.deityId != null && hero.deityId!.trim().isNotEmpty) {
        final deities = await _subclassDataService.loadDeities();
        final target = hero.deityId!.trim();
        final targetLower = target.toLowerCase();
        final targetSlug = ClassFeatureDataService.slugify(target);
        deityOption = deities.firstWhereOrNull((deity) {
          final idLower = deity.id.toLowerCase();
          if (idLower == targetLower) return true;
          final slugId = ClassFeatureDataService.slugify(deity.id);
          final slugName = ClassFeatureDataService.slugify(deity.name);
          if (slugId == targetSlug || slugName == targetSlug) {
            return true;
          }
          return false;
        });
      }

      SubclassSelectionResult? selection;
      final subclassName = hero.subclass?.trim();
      if ((subclassName != null && subclassName.isNotEmpty) ||
          (hero.deityId != null && hero.deityId!.trim().isNotEmpty) ||
          domainNames.isNotEmpty) {
        final subclassKey = (subclassName != null && subclassName.isNotEmpty)
            ? ClassFeatureDataService.slugify(subclassName)
            : null;
        selection = SubclassSelectionResult(
          subclassKey: subclassKey,
          subclassName: subclassName,
          deityId: hero.deityId?.trim(),
          deityName: deityOption?.name ?? hero.deityId?.trim(),
          domainNames: domainNames,
        );
      }

      final activeSubclassSlugs =
          ClassFeatureDataService.activeSubclassSlugs(selection);

      final featureData = await _featureService.loadFeatures(
        classData: classData,
        level: hero.level,
        activeSubclassSlugs: activeSubclassSlugs,
      );

      final autoSelections =
          _deriveAutomaticSelections(featureData, selection);

      if (mounted) {
        setState(() {
          _classData = classData;
          _level = hero.level;
          _featureData = featureData;
          _subclassSelection = selection;
          _selectedDeity = deityOption;
          _selectedDomains = domainNames;
          _characteristicArrayDescription = arrayDescription;
          _autoSelections = autoSelections;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load features: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_classData == null || _featureData == null) {
      return const Center(
        child: Text('No features available'),
      );
    }

    // Get all the computed data
    final domainSlugs = ClassFeatureDataService.selectedDomainSlugs(_subclassSelection);
    final subclassSlugs = ClassFeatureDataService.activeSubclassSlugs(_subclassSelection);
    final deitySlugs = ClassFeatureDataService.selectedDeitySlugs(_subclassSelection);

    // Build list of features to display
    final displayFeatures = <_FeatureDisplay>[];
    
    for (final feature in _featureData!.features) {
      final details = _featureData!.featureDetailsById[feature.id];
      if (details == null) continue;

      // Check if feature should be shown based on subclass/domain/deity
      if (!_shouldShowFeature(feature, details, subclassSlugs, domainSlugs, deitySlugs)) {
        continue;
      }

      final selectedOptions = _autoSelections[feature.id] ?? {};
      final displayOptions = _getDisplayOptions(feature, details, selectedOptions, subclassSlugs, domainSlugs, deitySlugs);

      displayFeatures.add(_FeatureDisplay(
        name: feature.name,
        level: feature.level,
        description: details['description'] as String? ?? '',
        options: displayOptions,
      ));
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Header with class and level
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _classData!.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Level $_level',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_subclassSelection != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _buildSelectionChips(theme),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        // Features list
        ...displayFeatures.map((feature) => _buildFeatureCard(context, feature)),
      ],
    );
  }

  List<Widget> _buildSelectionChips(ThemeData theme) {
    final chips = <Widget>[];

    final subclassName = _subclassSelection?.subclassName;
    if (subclassName != null && subclassName.trim().isNotEmpty) {
      chips.add(_buildCompactChip(theme, subclassName.trim(), Icons.star));
    }

    if (_selectedDomains.isNotEmpty) {
      for (final domain in _selectedDomains) {
        if (domain.trim().isEmpty) continue;
        chips.add(_buildCompactChip(theme, domain.trim(), Icons.account_tree));
      }
    }

    final deityDisplay = _selectedDeity?.name ?? _subclassSelection?.deityName;
    if (deityDisplay != null && deityDisplay.trim().isNotEmpty) {
      chips.add(_buildCompactChip(theme, deityDisplay.trim(), Icons.church));
    }

    if (_characteristicArrayDescription != null &&
        _characteristicArrayDescription!.trim().isNotEmpty) {
      chips.add(_buildCompactChip(theme, _characteristicArrayDescription!.trim(), Icons.view_module));
    }

    return chips;
  }

  Widget _buildCompactChip(ThemeData theme, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onPrimaryContainer),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowFeature(
    feature_model.Feature feature,
    Map<String, dynamic> details,
    Set<String> subclassSlugs,
    Set<String> domainSlugs,
    Set<String> deitySlugs,
  ) {
    // Check if feature requires subclass
    final options = details['options'] as List<dynamic>? ?? [];
    final requiresSubclass = options.any((opt) {
      if (opt is! Map<String, dynamic>) return false;
      return opt['subclass'] != null || (opt['restricts'] as List?)?.isNotEmpty == true;
    });
    
    if (requiresSubclass && subclassSlugs.isEmpty) {
      return false;
    }

    // Check if feature requires domain
    final requiresDomain = _featureData!.domainLinkedFeatureIds.contains(feature.id);
    if (requiresDomain && domainSlugs.isEmpty) {
      return false;
    }

    // Check if feature requires deity
    final requiresDeity = _featureData!.deityLinkedFeatureIds.contains(feature.id);
    if (requiresDeity && deitySlugs.isEmpty) {
      return false;
    }

    return true;
  }

  List<_FeatureOption> _getDisplayOptions(
    feature_model.Feature feature,
    Map<String, dynamic> details,
    Set<String> selectedKeys,
    Set<String> subclassSlugs,
    Set<String> domainSlugs,
    Set<String> deitySlugs,
  ) {
    final displayOptions = <_FeatureOption>[];
    final options = details['options'] as List<dynamic>? ?? [];

    for (final optionData in options) {
      if (optionData is! Map<String, dynamic>) continue;
      
      final option = optionData;

      // Check if option should be shown
      if (option['subclass'] != null) {
        final optionSubclassSlug = ClassFeatureDataService.slugify(option['subclass'] as String);
        if (!subclassSlugs.contains(optionSubclassSlug)) {
          continue;
        }
      }

      final restricts = option['restricts'] as List<dynamic>?;
      if (restricts?.isNotEmpty == true) {
        final restrictStrings = restricts!.whereType<String>().toList();
        final matchesRestriction = restrictStrings.any((r) => subclassSlugs.contains(r));
        if (!matchesRestriction) {
          continue;
        }
      }

      if (option['domain'] != null) {
        final optionDomainSlug = ClassFeatureDataService.slugify(option['domain'] as String);
        if (!domainSlugs.contains(optionDomainSlug)) {
          continue;
        }
      }

      if (option['deity'] != null) {
        final optionDeitySlug = ClassFeatureDataService.slugify(option['deity'] as String);
        if (!deitySlugs.contains(optionDeitySlug)) {
          continue;
        }
      }

      // Get abilities for this option
      final abilities = <String>[];
      final abilityRefs = option['abilities'] as List<dynamic>?;
      if (abilityRefs?.isNotEmpty == true) {
        for (final abilityRef in abilityRefs!) {
          if (abilityRef is! String) continue;
          final abilityId = _featureData!.abilityIdByName[abilityRef] ?? abilityRef;
          final abilityDetail = _featureData!.abilityDetailsById[abilityId];
          if (abilityDetail != null) {
            final abilityName = abilityDetail['name'] as String? ?? abilityRef;
            abilities.add(abilityName);
          }
        }
      }

      displayOptions.add(_FeatureOption(
        name: option['name'] as String? ?? '',
        description: option['description'] as String? ?? '',
        abilities: abilities,
      ));
    }

    return displayOptions;
  }

  Widget _buildFeatureCard(BuildContext context, _FeatureDisplay feature) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: feature.description.isNotEmpty || feature.options.isNotEmpty
            ? () => _showFeatureDetails(context, feature)
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${feature.level}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feature.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (feature.options.isNotEmpty)
                      Text(
                        '${feature.options.length} option${feature.options.length != 1 ? 's' : ''}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (feature.description.isNotEmpty || feature.options.isNotEmpty)
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFeatureDetails(BuildContext context, _FeatureDisplay feature) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${feature.level}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                feature.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (feature.description.isNotEmpty) ...[
                Text(
                  feature.description,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
              ],
              if (feature.options.isNotEmpty) ...[
                Text(
                  'Options',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...feature.options.map((option) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          option.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (option.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            option.description,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                        if (option.abilities.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: option.abilities.map((ability) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondaryContainer.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  ability,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Map<String, Set<String>> _deriveAutomaticSelections(
    ClassFeatureDataResult data,
    SubclassSelectionResult? selection,
  ) {
    if (selection == null) {
      return const <String, Set<String>>{};
    }

    final result = <String, Set<String>>{};

    void addSelections(String featureId, Set<String> keys) {
      if (keys.isEmpty) return;
      final existing = result[featureId];
      if (existing == null) {
        result[featureId] = Set<String>.from(keys);
      } else {
        result[featureId] = {...existing, ...keys};
      }
    }

    final domainSlugs = ClassFeatureDataService.selectedDomainSlugs(selection);
    if (domainSlugs.isNotEmpty) {
      for (final featureId in data.domainLinkedFeatureIds) {
        final keys = ClassFeatureDataService.domainOptionKeysFor(
          data.featureDetailsById,
          featureId,
          domainSlugs,
        );
        addSelections(featureId, keys);
      }
    }

    final subclassSlugs = ClassFeatureDataService.activeSubclassSlugs(selection);
    if (subclassSlugs.isNotEmpty) {
      for (final feature in data.features) {
        final keys = ClassFeatureDataService.subclassOptionKeysFor(
          data.featureDetailsById,
          feature.id,
          subclassSlugs,
        );
        addSelections(feature.id, keys);
      }
    }

    final deitySlugs = ClassFeatureDataService.selectedDeitySlugs(selection);
    if (deitySlugs.isNotEmpty) {
      for (final featureId in data.deityLinkedFeatureIds) {
        final keys = ClassFeatureDataService.deityOptionKeysFor(
          data.featureDetailsById,
          featureId,
          deitySlugs,
        );
        addSelections(featureId, keys);
      }
    }

    return result;
  }
}

// Helper classes for feature display
class _FeatureDisplay {
  final String name;
  final int level;
  final String description;
  final List<_FeatureOption> options;

  const _FeatureDisplay({
    required this.name,
    required this.level,
    required this.description,
    required this.options,
  });
}

class _FeatureOption {
  final String name;
  final String description;
  final List<String> abilities;

  const _FeatureOption({
    required this.name,
    required this.description,
    required this.abilities,
  });
}
