import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/providers.dart';
import '../../../core/models/class_data.dart';
import '../../../core/models/subclass_models.dart';
import '../../../core/models/component.dart' as model;
import '../../../core/models/feature.dart' as feature_model;
import '../../../core/services/class_data_service.dart';
import '../../../core/services/class_feature_data_service.dart';
import '../../../core/services/subclass_data_service.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/treasures/treasures.dart';

/// Highlights class features and gear.
class SheetFeatures extends ConsumerStatefulWidget {
  const SheetFeatures({
    super.key,
    required this.heroId,
  });

  final String heroId;

  @override
  ConsumerState<SheetFeatures> createState() => _SheetFeaturesState();
}

class _SheetFeaturesState extends ConsumerState<SheetFeatures>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Features'),
            Tab(text: 'Gear'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _FeaturesTab(heroId: widget.heroId),
              _GearTab(heroId: widget.heroId),
            ],
          ),
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

/// Tab for managing gear/treasures
class _GearTab extends ConsumerStatefulWidget {
  const _GearTab({required this.heroId});

  final String heroId;

  @override
  ConsumerState<_GearTab> createState() => _GearTabState();
}

class _GearTabState extends ConsumerState<_GearTab> {
  List<String> _heroTreasureIds = [];
  List<model.Component> _allTreasures = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final db = ref.read(appDatabaseProvider);
      
      // Load all treasures from all types
      final allComponents = await ref.read(allComponentsProvider.future);
      final treasures = allComponents.where((c) => 
        c.type == 'consumable' || 
        c.type == 'trinket' || 
        c.type == 'artifact' ||
        c.type == 'leveled_treasure'
      ).toList();

      // Load hero's treasures
      final heroTreasureIds = await db.getHeroComponentIds(widget.heroId, 'treasure');

      if (mounted) {
        setState(() {
          _allTreasures = treasures..sort((a, b) => a.name.compareTo(b.name));
          _heroTreasureIds = List.from(heroTreasureIds);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load treasures: $e';
        });
      }
    }
  }

  Future<void> _addTreasure(String treasureId) async {
    if (_heroTreasureIds.contains(treasureId)) return;

    final db = ref.read(appDatabaseProvider);
    final updated = [..._heroTreasureIds, treasureId];

    try {
      await db.setHeroComponentIds(
        heroId: widget.heroId,
        category: 'treasure',
        componentIds: updated,
      );

      if (mounted) {
        setState(() {
          _heroTreasureIds = updated;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Treasure added'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add treasure: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeTreasure(String treasureId) async {
    final db = ref.read(appDatabaseProvider);
    final updated = _heroTreasureIds.where((id) => id != treasureId).toList();

    try {
      await db.setHeroComponentIds(
        heroId: widget.heroId,
        category: 'treasure',
        componentIds: updated,
      );

      if (mounted) {
        setState(() {
          _heroTreasureIds = updated;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Treasure removed'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove treasure: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddTreasureDialog() {
    final availableTreasures = _allTreasures
        .where((t) => !_heroTreasureIds.contains(t.id))
        .toList();

    showDialog(
      context: context,
      builder: (context) => _AddTreasureDialog(
        availableTreasures: availableTreasures,
        onTreasureSelected: (treasureId) {
          _addTreasure(treasureId);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
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

    final heroTreasures = _allTreasures
        .where((t) => _heroTreasureIds.contains(t.id))
        .toList();

    // Group treasures by type
    final groupedTreasures = <String, List<model.Component>>{};
    for (final treasure in heroTreasures) {
      final groupKey = _getTreasureGroupName(treasure.type);
      groupedTreasures.putIfAbsent(groupKey, () => []).add(treasure);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Text(
                'Gear & Treasures (${heroTreasures.length})',
                style: AppTextStyles.subtitle,
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _showAddTreasureDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
              ),
            ],
          ),
        ),
        Expanded(
          child: heroTreasures.isEmpty
              ? const Center(
                  child: Text(
                    'No gear yet.\nTap "Add Item" to begin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: groupedTreasures.length,
                  itemBuilder: (context, index) {
                    final entry = groupedTreasures.entries.elementAt(index);
                    final groupName = entry.key;
                    final treasures = entry.value;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 8),
                          child: Text(
                            groupName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ),
                        ...treasures.map((treasure) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Stack(
                              children: [
                                _buildTreasureCard(treasure),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _removeTreasure(treasure.id),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTreasureCard(model.Component treasure) {
    switch (treasure.type) {
      case 'consumable':
        return ConsumableTreasureCard(component: treasure);
      case 'trinket':
        return TrinketTreasureCard(component: treasure);
      case 'artifact':
        return ArtifactTreasureCard(component: treasure);
      case 'leveled_treasure':
        return LeveledTreasureCard(component: treasure);
      default:
        return Card(
          child: ListTile(
            title: Text(treasure.name),
            subtitle: Text(treasure.type),
          ),
        );
    }
  }

  String _getTreasureGroupName(String type) {
    switch (type) {
      case 'consumable':
        return 'Consumables';
      case 'trinket':
        return 'Trinkets';
      case 'artifact':
        return 'Artifacts';
      case 'leveled_treasure':
        return 'Leveled Equipment';
      default:
        return 'Other';
    }
  }
}

/// Dialog for adding treasures
class _AddTreasureDialog extends StatefulWidget {
  final List<model.Component> availableTreasures;
  final Function(String) onTreasureSelected;

  const _AddTreasureDialog({
    required this.availableTreasures,
    required this.onTreasureSelected,
  });

  @override
  State<_AddTreasureDialog> createState() => _AddTreasureDialogState();
}

class _AddTreasureDialogState extends State<_AddTreasureDialog> {
  String _searchQuery = '';
  String _filterType = 'all';
  List<model.Component> _filteredTreasures = [];

  @override
  void initState() {
    super.initState();
    _filteredTreasures = widget.availableTreasures;
  }

  void _filterTreasures() {
    setState(() {
      _filteredTreasures = widget.availableTreasures.where((treasure) {
        final description = treasure.data['description']?.toString() ?? '';
        final matchesSearch = _searchQuery.isEmpty ||
            treasure.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            description.toLowerCase().contains(_searchQuery.toLowerCase());

        final matchesType = _filterType == 'all' || treasure.type == _filterType;

        return matchesSearch && matchesType;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Add Treasure'),
      content: SizedBox(
        width: double.maxFinite,
        height: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search treasures',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                _searchQuery = value;
                _filterTreasures();
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _filterType,
              decoration: const InputDecoration(
                labelText: 'Filter by type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Types')),
                DropdownMenuItem(value: 'consumable', child: Text('Consumables')),
                DropdownMenuItem(value: 'trinket', child: Text('Trinkets')),
                DropdownMenuItem(value: 'artifact', child: Text('Artifacts')),
                DropdownMenuItem(value: 'leveled_treasure', child: Text('Leveled Equipment')),
              ],
              onChanged: (value) {
                if (value != null) {
                  _filterType = value;
                  _filterTreasures();
                }
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _filteredTreasures.isEmpty
                  ? Center(
                      child: Text(
                        'No treasures found',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredTreasures.length,
                      itemBuilder: (context, index) {
                        final treasure = _filteredTreasures[index];
                        final echelon = treasure.data['echelon'] as int?;
                        final description = treasure.data['description']?.toString() ?? '';
                        
                        return ListTile(
                          leading: Icon(
                            _getTreasureIcon(treasure.type),
                            color: theme.colorScheme.primary,
                          ),
                          title: Text(treasure.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_getTreasureTypeName(treasure.type)),
                              if (echelon != null)
                                Text('Echelon $echelon'),
                              if (description.isNotEmpty)
                                Text(
                                  description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                          onTap: () => widget.onTreasureSelected(treasure.id),
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

  String _getTreasureTypeName(String type) {
    switch (type) {
      case 'consumable':
        return 'Consumable';
      case 'trinket':
        return 'Trinket';
      case 'artifact':
        return 'Artifact';
      case 'leveled_treasure':
        return 'Leveled Equipment';
      default:
        return type;
    }
  }

  IconData _getTreasureIcon(String type) {
    switch (type) {
      case 'consumable':
        return Icons.local_drink;
      case 'trinket':
        return Icons.diamond;
      case 'artifact':
        return Icons.auto_awesome;
      case 'leveled_treasure':
        return Icons.shield;
      default:
        return Icons.category;
    }
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
