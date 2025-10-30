import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/providers.dart';
import '../../../core/models/class_data.dart';
import '../../../core/models/subclass_models.dart';
import '../../../core/services/class_data_service.dart';
import '../../../core/services/class_feature_data_service.dart';
import '../../../core/services/skill_data_service.dart';
import '../../../core/services/subclass_data_service.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../creators/widgets/strife_creator/class_features_widget.dart';

/// Highlights class features, skills, and languages.
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
    _tabController = TabController(length: 3, vsync: this);
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
            Tab(text: 'Skills'),
            Tab(text: 'Languages'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _FeaturesTab(heroId: widget.heroId),
              _SkillsTab(heroId: widget.heroId),
              _LanguagesTab(heroId: widget.heroId),
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

    if (_classData == null || _featureData == null) {
      return const Center(
        child: Text('No features available'),
      );
    }

    final summary = _buildSelectionSummary(context);
    final domainSlugs =
        ClassFeatureDataService.selectedDomainSlugs(_subclassSelection);
    final subclassSlugs =
        ClassFeatureDataService.activeSubclassSlugs(_subclassSelection);
    final subclassLabel =
        ClassFeatureDataService.subclassLabel(_subclassSelection);
    final deitySlugs =
        ClassFeatureDataService.selectedDeitySlugs(_subclassSelection);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${_classData!.name} Features (Level $_level)',
          style: AppTextStyles.title,
        ),
        const SizedBox(height: 16),
        if (summary != null) ...[
          summary,
          const SizedBox(height: 16),
        ],
        ClassFeaturesWidget(
          level: _level,
          features: _featureData!.features,
          featureDetailsById: _featureData!.featureDetailsById,
          selectedOptions: _autoSelections,
          onSelectionChanged: null, // Read-only
          domainLinkedFeatureIds: _featureData!.domainLinkedFeatureIds,
          selectedDomainSlugs: domainSlugs,
          deityLinkedFeatureIds: _featureData!.deityLinkedFeatureIds,
          selectedDeitySlugs: deitySlugs,
          abilityDetailsById: _featureData!.abilityDetailsById,
          abilityIdByName: _featureData!.abilityIdByName,
          activeSubclassSlugs: subclassSlugs,
          subclassLabel: subclassLabel,
          subclassSelection: _subclassSelection,
        ),
      ],
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

  Widget? _buildSelectionSummary(BuildContext context) {
    final chips = <Widget>[];
    final subclassName = _subclassSelection?.subclassName;
    if (subclassName != null && subclassName.trim().isNotEmpty) {
      chips.add(_buildInfoChip(Icons.star, 'Subclass: $subclassName'));
    }

    if (_selectedDomains.isNotEmpty) {
      for (final domain in _selectedDomains) {
        if (domain.trim().isEmpty) continue;
        chips.add(
          _buildInfoChip(Icons.account_tree, 'Domain: ${domain.trim()}'),
        );
      }
    }

    final deityDisplay = _selectedDeity?.name ?? _subclassSelection?.deityName;
    if (deityDisplay != null && deityDisplay.trim().isNotEmpty) {
      chips.add(
        _buildInfoChip(Icons.church, 'Deity: ${deityDisplay.trim()}'),
      );
    }

    if (_characteristicArrayDescription != null &&
        _characteristicArrayDescription!.trim().isNotEmpty) {
      chips.add(
        _buildInfoChip(
          Icons.view_module,
          'Characteristics: ${_characteristicArrayDescription!.trim()}',
        ),
      );
    }

    if (chips.isEmpty) {
      return null;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selections',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}

/// Tab for managing skills
class _SkillsTab extends ConsumerStatefulWidget {
  const _SkillsTab({required this.heroId});

  final String heroId;

  @override
  ConsumerState<_SkillsTab> createState() => _SkillsTabState();
}

class _SkillsTabState extends ConsumerState<_SkillsTab> {
  final SkillDataService _skillService = SkillDataService();

  List<String> _heroSkillIds = [];
  List<_SkillOption> _allSkills = [];
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
      final skills = await _skillService.loadSkills();
      final heroSkillIds = await db.getHeroComponentIds(widget.heroId, 'skill');

      if (mounted) {
        setState(() {
          _allSkills = skills
              .map((s) => _SkillOption(
                    id: s.id,
                    name: s.name,
                    group: s.group,
                    description: s.description,
                  ))
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
          _heroSkillIds = List.from(heroSkillIds);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load skills: $e';
        });
      }
    }
  }

  Future<void> _addSkill(String skillId) async {
    if (_heroSkillIds.contains(skillId)) return;

    final db = ref.read(appDatabaseProvider);
    final updated = [..._heroSkillIds, skillId];

    try {
      await db.setHeroComponentIds(
        heroId: widget.heroId,
        category: 'skill',
        componentIds: updated,
      );

      if (mounted) {
        setState(() {
          _heroSkillIds = updated;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Skill added'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add skill: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeSkill(String skillId) async {
    final db = ref.read(appDatabaseProvider);
    final updated = _heroSkillIds.where((id) => id != skillId).toList();

    try {
      await db.setHeroComponentIds(
        heroId: widget.heroId,
        category: 'skill',
        componentIds: updated,
      );

      if (mounted) {
        setState(() {
          _heroSkillIds = updated;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Skill removed'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove skill: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddSkillDialog() {
    final availableSkills =
        _allSkills.where((skill) => !_heroSkillIds.contains(skill.id)).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Skill'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableSkills.length,
            itemBuilder: (context, index) {
              final skill = availableSkills[index];
              return ListTile(
                title: Text(skill.name),
                subtitle: Text(
                  '${skill.group.toUpperCase()}\n${skill.description}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _addSkill(skill.id);
                },
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

    final heroSkills =
        _allSkills.where((skill) => _heroSkillIds.contains(skill.id)).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Text(
                'Skills (${heroSkills.length})',
                style: AppTextStyles.subtitle,
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _showAddSkillDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Skill'),
              ),
            ],
          ),
        ),
        Expanded(
          child: heroSkills.isEmpty
              ? const Center(
                  child: Text(
                    'No skills yet.\nTap "Add Skill" to begin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: heroSkills.length,
                  itemBuilder: (context, index) {
                    final skill = heroSkills[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(skill.name),
                        subtitle: Text(
                          '${skill.group.toUpperCase()}\n${skill.description}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeSkill(skill.id),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Tab for managing languages
class _LanguagesTab extends ConsumerStatefulWidget {
  const _LanguagesTab({required this.heroId});

  final String heroId;

  @override
  ConsumerState<_LanguagesTab> createState() => _LanguagesTabState();
}

class _LanguagesTabState extends ConsumerState<_LanguagesTab> {
  List<String> _heroLanguageIds = [];
  List<_LanguageOption> _allLanguages = [];
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
      final languages = await _loadLanguages();
      final heroLanguageIds =
          await db.getHeroComponentIds(widget.heroId, 'language');

      if (mounted) {
        setState(() {
          _allLanguages = languages..sort((a, b) => a.name.compareTo(b.name));
          _heroLanguageIds = List.from(heroLanguageIds);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load languages: $e';
        });
      }
    }
  }

  Future<List<_LanguageOption>> _loadLanguages() async {
    final raw = await DefaultAssetBundle.of(context)
        .loadString('data/story/languages.json');
    final decoded = jsonDecode(raw) as List;

    return decoded.map((entry) {
      final map = entry as Map<String, dynamic>;
      return _LanguageOption(
        id: map['id'] as String,
        name: map['name'] as String,
        languageType: map['language_type'] as String? ?? '',
        region: map['region'] as String?,
        ancestry: map['ancestry'] as String?,
      );
    }).toList();
  }

  Future<void> _addLanguage(String languageId) async {
    if (_heroLanguageIds.contains(languageId)) return;

    final db = ref.read(appDatabaseProvider);
    final updated = [..._heroLanguageIds, languageId];

    try {
      await db.setHeroComponentIds(
        heroId: widget.heroId,
        category: 'language',
        componentIds: updated,
      );

      if (mounted) {
        setState(() {
          _heroLanguageIds = updated;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Language added'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add language: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeLanguage(String languageId) async {
    final db = ref.read(appDatabaseProvider);
    final updated = _heroLanguageIds.where((id) => id != languageId).toList();

    try {
      await db.setHeroComponentIds(
        heroId: widget.heroId,
        category: 'language',
        componentIds: updated,
      );

      if (mounted) {
        setState(() {
          _heroLanguageIds = updated;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Language removed'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove language: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddLanguageDialog() {
    final availableLanguages = _allLanguages
        .where((lang) => !_heroLanguageIds.contains(lang.id))
        .toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Language'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableLanguages.length,
            itemBuilder: (context, index) {
              final language = availableLanguages[index];
              return ListTile(
                title: Text(language.name),
                subtitle: Text(
                  [
                    language.languageType.toUpperCase(),
                    if (language.region != null) language.region,
                    if (language.ancestry != null) language.ancestry,
                  ].join(' • '),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _addLanguage(language.id);
                },
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

    final heroLanguages = _allLanguages
        .where((lang) => _heroLanguageIds.contains(lang.id))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Text(
                'Languages (${heroLanguages.length})',
                style: AppTextStyles.subtitle,
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _showAddLanguageDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Language'),
              ),
            ],
          ),
        ),
        Expanded(
          child: heroLanguages.isEmpty
              ? const Center(
                  child: Text(
                    'No languages yet.\nTap "Add Language" to begin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: heroLanguages.length,
                  itemBuilder: (context, index) {
                    final language = heroLanguages[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(language.name),
                        subtitle: Text(
                          [
                            language.languageType.toUpperCase(),
                            if (language.region != null) language.region,
                            if (language.ancestry != null) language.ancestry,
                          ].join(' • '),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeLanguage(language.id),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

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
  final String? region;
  final String? ancestry;

  _LanguageOption({
    required this.id,
    required this.name,
    required this.languageType,
    this.region,
    this.ancestry,
  });
}
