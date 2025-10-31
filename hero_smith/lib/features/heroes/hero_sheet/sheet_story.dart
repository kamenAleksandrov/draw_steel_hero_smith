import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/providers.dart';
import '../../../core/models/component.dart' as model;
import '../../../core/services/story_creator_service.dart';
import '../../../core/services/skill_data_service.dart';
import '../../../core/theme/app_text_styles.dart';

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

/// Narrative, background, and progression notes for the hero.
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
    _tabController = TabController(length: 3, vsync: this);
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
            Tab(text: 'Story'),
            Tab(text: 'Skills'),
            Tab(text: 'Languages'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildStoryTab(context),
              _SkillsTab(heroId: widget.heroId),
              _LanguagesTab(heroId: widget.heroId),
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
          if (data['grants'] != null) ...[
            _buildGrants(context, data['grants']),
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

  Widget _buildGrants(BuildContext context, dynamic grants) {
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
