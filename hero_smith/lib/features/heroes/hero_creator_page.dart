import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/db/providers.dart';
import '../../core/models/hero_model.dart';
import '../../core/models/component.dart' as model;
import '../../core/theme/hero_theme.dart';

class HeroCreatorPage extends ConsumerStatefulWidget {
  const HeroCreatorPage({super.key, required this.heroId});
  final String heroId;

  @override
  ConsumerState<HeroCreatorPage> createState() => _HeroCreatorPageState();
}

class _HeroCreatorPageState extends ConsumerState<HeroCreatorPage> {
  String? _selectedLanguageId; // Single language selection
  // Core state
  final TextEditingController _nameCtrl = TextEditingController();
  bool _dirty = false;
  bool _loading = true;
  HeroModel? _model;
  // Ancestry state
  String? _selectedAncestryId;
  final Set<String> _selectedTraitIds = <String>{};
  // Culture chosen skills
  String? _envSkillId;
  String? _orgSkillId;
  String? _upSkillId;
  // Cached culture suggestions by ancestry name (lowercase)
  final Map<String, Map<String, String>> _ancestryCultureSuggestions =
      <String, Map<String, String>>{};
  // Suggestion Future that updates only when ancestry changes
  Future<Map<String, String>?>? _suggestionFuture;
  String? _lastAncestryNameForSuggestion;

  @override
  void initState() {
    super.initState();
    _load();
    _loadCultureSuggestionsOnce();
  }

  Future<void> _load() async {
    final repo = ref.read(heroRepositoryProvider);
    final m = await repo.load(widget.heroId);
    if (m == null) {
      setState(() {
        _loading = false;
      });
      return;
    }
    // Load additional selections from repository
    final cultureSel = await repo.loadCultureSelection(widget.heroId);
    final careerSel = await repo.loadCareerSelection(widget.heroId);
    final selectedTraitIds =
        await repo.getSelectedAncestryTraits(widget.heroId);

    setState(() {
      _model = m;
      _nameCtrl.text = m.name;
      _selectedAncestryId = m.ancestry;
      _selectedTraitIds
        ..clear()
        ..addAll(selectedTraitIds);

      // Culture preload
      _envId = cultureSel.environmentId;
      _orgId = cultureSel.organisationId;
      _upId = cultureSel.upbringingId;
      _envSkillId = cultureSel.environmentSkillId;
      _orgSkillId = cultureSel.organisationSkillId;
      _upSkillId = cultureSel.upbringingSkillId;
      _selectedLanguageId = m.languages.isNotEmpty ? m.languages.first : null;
      _careerLanguageIds =
          m.languages.where((id) => id != _selectedLanguageId).toList();

      // Career preload
      _careerId = careerSel.careerId ?? m.career;
      _careerChosenSkillIds
        ..clear()
        ..addAll(careerSel.chosenSkillIds);
      _careerChosenPerkIds
        ..clear()
        ..addAll(careerSel.chosenPerkIds);
      _careerIncidentName = careerSel.incitingIncidentName;
      _loading = false;
    });
  }

  Future<void> _loadCultureSuggestionsOnce() async {
    try {
      final raw = await rootBundle
          .loadString('data/story/culture/culture_suggestions.json');
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final List items =
          (map['typical_ancestry_cultures'] as List?) ?? const [];
      for (final e in items) {
        final m = Map<String, dynamic>.from(e as Map);
        final key = (m['ancestry']?.toString() ?? '').toLowerCase();
        if (key.isEmpty) continue;
        _ancestryCultureSuggestions[key] = {
          'language': m['language']?.toString() ?? '',
          'environment': m['environment']?.toString() ?? '',
          'organization': m['organization']?.toString() ?? '',
          'upbringing': m['upbringing']?.toString() ?? '',
        };
      }
      if (mounted) setState(() {});
    } catch (_) {
      // ignore
    }
  }

  // Returns suggestion map for the given ancestry name; loads cache on first use.
  Future<Map<String, String>?> _getSuggestionFor(String? ancestryName) async {
    if (ancestryName == null || ancestryName.trim().isEmpty) return null;
    if (_ancestryCultureSuggestions.isEmpty) {
      await _loadCultureSuggestionsOnce();
    }
    return _ancestryCultureSuggestions[ancestryName.toLowerCase()];
  }

  Future<void> _save() async {
    if (_model == null) return;
    final repo = ref.read(heroRepositoryProvider);
    _model!.name = _nameCtrl.text.trim();
    // Persist ancestry selection (component id) as a value
    _model!.ancestry = _selectedAncestryId;
    _model!.career = _careerId;
    await repo.save(_model!);
    // Persist selected ancestry traits (signature is inferred by repo)
    await repo.saveAncestryTraits(
      heroId: _model!.id,
      ancestryId: _selectedAncestryId,
      selectedTraitIds: _selectedTraitIds.toList(),
    );
    // Persist culture selection
    // Merge language choices from culture and career selections
    final mergedLanguageIds = <String>{};
    if (_selectedLanguageId != null)
      mergedLanguageIds.add(_selectedLanguageId!);
    mergedLanguageIds.addAll(_careerLanguageIds.whereType<String>());
    await repo.saveCultureSelection(
      heroId: _model!.id,
      environmentId: _envId,
      organisationId: _orgId,
      upbringingId: _upId,
      languageIds: mergedLanguageIds.toList(),
      environmentSkillId: _envSkillId,
      organisationSkillId: _orgSkillId,
      upbringingSkillId: _upSkillId,
    );
    // Persist career selection and grants
    await repo.saveCareerSelection(
      heroId: _model!.id,
      careerId: _careerId,
      chosenSkillIds: _careerChosenSkillIds.toList(),
      chosenPerkIds: _careerChosenPerkIds.toList(),
      incitingIncidentName: _careerIncidentName,
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved')));
    }
    _dirty = false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && _dirty) {
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
            _model?.name.isNotEmpty == true ? _model!.name : 'Hero Creator',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            if (!_loading && _dirty)
              IconButton(
                onPressed: _save,
                icon: const Icon(Icons.save),
                tooltip: 'Save Hero',
              ),
          ],
        ),
        body: _loading ? _buildLoadingState(context) : _buildContent(context),
        floatingActionButton: _loading || !_dirty
            ? null
            : FloatingActionButton.extended(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Save'),
                backgroundColor: HeroTheme.primarySection,
              ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: HeroTheme.primarySection,
          ),
          const SizedBox(height: 24),
          Text(
            'Loading hero data...',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (!_dirty) return true;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('You have unsaved changes'),
        content: const Text('Do you want to save your changes before leaving?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop('cancel'),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop('discard'),
              child: const Text('Discard')),
          FilledButton.icon(
              onPressed: () => Navigator.of(ctx).pop('save'),
              icon: const Icon(Icons.save),
              label: const Text('Save')),
        ],
      ),
    );
    if (result == 'save') {
      await _save();
      return true;
    }
    if (result == 'discard') {
      return true;
    }
    return false;
  }

  Widget _buildContent(BuildContext context) {
    final ancestriesAsync = ref.watch(componentsByTypeProvider('ancestry'));
    final ancestryTraitsAsync =
        ref.watch(componentsByTypeProvider('ancestry_trait'));

    return ancestriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error loading ancestries: $e')),
      data: (ancestries) {
        ancestries = List.of(ancestries)
          ..sort((a, b) => a.name.compareTo(b.name));
        final selectedAncestry = ancestries.firstWhere(
          (a) => a.id == _selectedAncestryId,
          orElse: () => ancestries.isNotEmpty
              ? ancestries.first
              : model.Component(id: '', type: 'ancestry', name: 'Unknown'),
        );

        return ancestryTraitsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) =>
              Center(child: Text('Error loading ancestry traits: $e')),
          data: (traitsComps) {
            final traitsForSelected = traitsComps.firstWhere(
              (t) => t.data['ancestry_id'] == _selectedAncestryId,
              orElse: () => traitsComps.firstWhere(
                (t) => t.data['ancestry_id'] == selectedAncestry.id,
                orElse: () => traitsComps.isNotEmpty
                    ? traitsComps.first
                    : model.Component(
                        id: '', type: 'ancestry_trait', name: '—'),
              ),
            );
            final points = (traitsForSelected.data['points'] as int?) ?? 0;
            final traitsList =
                (traitsForSelected.data['traits'] as List?)?.cast<Map>() ??
                    const <Map>[];
            final remaining = points -
                _selectedTraitIds
                    .map((id) =>
                        traitsList
                            .firstWhere((t) => t['id'] == id,
                                orElse: () => const {})
                            .cast<String, dynamic>()['cost'] as int? ??
                        0)
                    .fold<int>(0, (a, b) => a + b);

            return CustomScrollView(
              slivers: [
                // Hero Name Section
                SliverToBoxAdapter(
                  child: _buildNameSection(context),
                ),

                // Ancestry Section
                SliverToBoxAdapter(
                  child: _buildAncestrySection(context, selectedAncestry,
                      traitsForSelected, remaining, points, traitsList),
                ),

                // Culture Section
                SliverToBoxAdapter(
                  child: _buildCultureSection(selectedAncestry.name),
                ),

                // Career Section
                SliverToBoxAdapter(
                  child: _buildCareerSection(),
                ),

                // Bottom padding for floating action button
                const SliverToBoxAdapter(
                  child: SizedBox(height: 80),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildNameSection(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: HeroTheme.sectionCardElevation,
        shape: const RoundedRectangleBorder(borderRadius: HeroTheme.cardRadius),
        child: Column(
          children: [
            HeroTheme.buildSectionHeader(
              context,
              title: 'Hero Identity',
              subtitle: 'Give your hero a name',
              icon: Icons.person,
              color: HeroTheme.getStepColor('identity'),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Hero Name',
                      hintText: 'Enter your hero\'s name...',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (_) => setState(() => _dirty = true),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose an ancestry below for name suggestions!',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  // Show name suggestions here if ancestry is selected
                  if (_selectedAncestryId != null) ...[
                    const SizedBox(height: 16),
                    _buildNameSuggestions(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAncestrySection(
      BuildContext context,
      model.Component selectedAncestry,
      model.Component traitsForSelected,
      int remaining,
      int points,
      List<Map> traitsList) {
    final theme = Theme.of(context);
    final ancestriesAsync = ref.watch(componentsByTypeProvider('ancestry'));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: HeroTheme.sectionCardElevation,
        shape: const RoundedRectangleBorder(borderRadius: HeroTheme.cardRadius),
        child: Column(
          children: [
            HeroTheme.buildSectionHeader(
              context,
              title: 'Ancestry',
              subtitle: 'Your hero\'s biological and cultural heritage',
              icon: Icons.family_restroom,
              color: HeroTheme.getStepColor('ancestry'),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Ancestry Selection
                  ancestriesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, st) => Text('Error: $e',
                        style: TextStyle(color: theme.colorScheme.error)),
                    data: (ancestries) {
                      ancestries = List.of(ancestries)
                        ..sort((a, b) => a.name.compareTo(b.name));
                      return InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Choose Ancestry',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _selectedAncestryId,
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('— Choose ancestry —')),
                              ...ancestries.map((a) =>
                                  DropdownMenuItem<String?>(
                                      value: a.id, child: Text(a.name))),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedAncestryId = val;
                                _selectedTraitIds.clear();
                                _dirty = true;
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),

                  // Show ancestry details if selected
                  if (_selectedAncestryId != null) ...[
                    const SizedBox(height: 16),
                    _buildAncestryDetails(selectedAncestry, traitsForSelected,
                        remaining, points, traitsList),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameSuggestions() {
    final ancestriesAsync = ref.watch(componentsByTypeProvider('ancestry'));
    return ancestriesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
      data: (ancestries) {
        final selectedAncestry = ancestries.firstWhere(
          (a) => a.id == _selectedAncestryId,
          orElse: () =>
              model.Component(id: '', type: 'ancestry', name: 'Unknown'),
        );
        if (selectedAncestry.id.isEmpty) return const SizedBox.shrink();
        return _buildExampleNamesForAncestry(selectedAncestry);
      },
    );
  }

  Widget _buildExampleNamesForAncestry(model.Component ancestry) {
    final data = ancestry.data;
    final exampleNames =
        (data['exampleNames'] as Map?)?.cast<String, dynamic>();
    // Special-case: Revenant shows a note instead of name picker
    if ((ancestry.name).toLowerCase() == 'revenant') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Text(
          'Revenants often keep their names from life; new names reflect their reasons or culture.',
          style: TextStyle(
              color: Colors.grey.shade600, fontStyle: FontStyle.italic),
        ),
      );
    }

    if (exampleNames == null || exampleNames.isEmpty)
      return const SizedBox.shrink();

    final exampleLists = <String, List<String>>{};
    final groupLabels = <String, String>{
      'examples': 'Examples',
      'feminine': 'Feminine',
      'masculine': 'Masculine',
      'genderNeutral': 'Gender Neutral',
      'epithets': 'Epithets',
      'surnames': 'Surnames',
    };

    for (final key in groupLabels.keys) {
      final list =
          (exampleNames[key] as List?)?.map((e) => e.toString()).toList() ??
              const <String>[];
      if (list.isNotEmpty) exampleLists[key] = list.cast<String>();
    }

    if (exampleLists.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Example names from ${ancestry.name}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...exampleLists.entries.map((entry) {
          final groupLabel = groupLabels[entry.key] ?? entry.key;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(groupLabel,
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final n in entry.value.take(8))
                    ActionChip(
                      label: Text(n),
                      onPressed: () {
                        final current = _nameCtrl.text.trim();
                        setState(() {
                          final isSurname = entry.key == 'surnames';
                          final isTimeRaiderEpithet =
                              (ancestry.name).toLowerCase() == 'time raider' &&
                                  entry.key == 'epithets';
                          if ((isSurname || isTimeRaiderEpithet) &&
                              current.isNotEmpty) {
                            _nameCtrl.text = '$current $n';
                          } else {
                            _nameCtrl.text = n;
                          }
                          _dirty = true;
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAncestryDetails(
      model.Component ancestry,
      model.Component traitsComp,
      int remaining,
      int totalPoints,
      List<Map> traitList) {
    final data = ancestry.data;
    final shortDesc = (data['short_description'] as String?) ?? '';
    final height = (data['height'] as Map?)?.cast<String, dynamic>();
    final weight = (data['weight'] as Map?)?.cast<String, dynamic>();
    final life = (data['life_expectancy'] as Map?)?.cast<String, dynamic>();
    final size = data['size'];
    final speed = data['speed'];
    final stability = data['stability'];

    final exampleNames =
        (data['exampleNames'] as Map?)?.cast<String, dynamic>();
    final exampleLists = <String, List<String>>{};
    for (final key in [
      'examples',
      'feminine',
      'masculine',
      'genderNeutral',
      'epithets',
      'surnames'
    ]) {
      final list =
          (exampleNames?[key] as List?)?.map((e) => e.toString()).toList() ??
              const <String>[];
      if (list.isNotEmpty) exampleLists[key] = list.cast<String>();
    }

    final signature =
        (traitsComp.data['signature'] as Map?)?.cast<String, dynamic>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (shortDesc.isNotEmpty) ...[
          Text(shortDesc,
              style: TextStyle(color: Colors.grey.shade300, height: 1.3)),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (height != null)
              _chip('Height: ${height['min']}–${height['max']}', Colors.blue),
            if (weight != null)
              _chip('Weight: ${weight['min']}–${weight['max']}', Colors.green),
            if (life != null)
              _chip('Lifespan: ${life['min']}–${life['max']}', Colors.purple),
            _chip('Size: $size', Colors.orange),
            _chip('Speed: $speed', Colors.teal),
            _chip('Stability: $stability', Colors.redAccent),
          ],
        ),
        const SizedBox(height: 16),
        if (signature != null) ...[
          Text('Signature: ${signature['name'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          if ((signature['description'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(signature['description'] as String,
                style: const TextStyle(height: 1.3)),
          ],
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Chip(label: Text('Points: $totalPoints')),
            const SizedBox(width: 8),
            Chip(label: Text('Remaining: $remaining')),
          ],
        ),
        const SizedBox(height: 8),
        ...traitList.map((t) {
          final id = (t['id'] ?? t['name']).toString();
          final name = (t['name'] ?? id).toString();
          final desc = (t['description'] ?? '').toString();
          final cost = (t['cost'] as int?) ?? 0;
          final selected = _selectedTraitIds.contains(id);
          final canSelect = selected || remaining - cost >= 0;
          return CheckboxListTile(
            value: selected,
            onChanged: canSelect
                ? (v) {
                    setState(() {
                      if (v == true) {
                        _selectedTraitIds.add(id);
                      } else {
                        _selectedTraitIds.remove(id);
                      }
                      _dirty = true;
                    });
                  }
                : null,
            title: Text(name),
            subtitle: Text(desc),
            secondary: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$cost'),
            ),
            contentPadding: EdgeInsets.zero,
          );
        }),
      ],
    );
  }

  Widget _chip(String text, Color color) => Chip(
        label: Text(text),
        backgroundColor: color.withOpacity(0.1),
        side: BorderSide(color: color.withOpacity(0.6), width: 1),
      );

  // --- Culture section ---
  String? _envId;
  String? _orgId;
  String? _upId;

  Widget _buildLanguageDropdown(List<model.Component> languages) {
    // Group languages by language_type
    final groups = <String, List<model.Component>>{
      'human': [],
      'ancestral': [],
      'dead': [],
    };

    for (final lang in languages) {
      final languageType = lang.data['language_type'] as String? ?? 'human';
      if (groups.containsKey(languageType)) {
        groups[languageType]!.add(lang);
      }
    }

    // Sort each group alphabetically
    for (final group in groups.values) {
      group.sort((a, b) => a.name.compareTo(b.name));
    }

    final groupLabels = {
      'human': 'Human Languages',
      'ancestral': 'Ancestral Languages',
      'dead': 'Dead Languages',
    };

    // Validate the selected language exists in the available languages
    final validSelectedLanguageId = _selectedLanguageId != null &&
            languages.any((lang) => lang.id == _selectedLanguageId)
        ? _selectedLanguageId
        : null;

    final theme = Theme.of(context);
    const languageColor = Color(0xFF9C27B0); // Purple for languages

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: languageColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        color: languageColor.withValues(alpha: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and title
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
              color: languageColor.withValues(alpha: 0.1),
            ),
            child: Row(
              children: [
                Icon(Icons.language, color: languageColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Language',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: languageColor,
                  ),
                ),
              ],
            ),
          ),
          // Dropdown content
          Padding(
            padding: const EdgeInsets.all(12),
            child: InputDecorator(
              decoration: InputDecoration(
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  isExpanded: true,
                  hint: const Text('Select Language'),
                  value: validSelectedLanguageId,
                  items: [
                    for (final groupKey in ['human', 'ancestral', 'dead'])
                      if (groups[groupKey]!.isNotEmpty) ...[
                        DropdownMenuItem<String?>(
                          enabled: false,
                          value: '__lang_group__' + groupKey,
                          child: Text(
                            groupLabels[groupKey]!,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                        for (final lang in groups[groupKey]!)
                          DropdownMenuItem<String?>(
                            value: lang.id,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: Text(lang.name),
                            ),
                          ),
                      ]
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedLanguageId = value;
                      _dirty = true;
                    });
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCultureSection(String? ancestryName) {
    final envAsync = ref.watch(componentsByTypeProvider('culture_environment'));
    final orgAsync =
        ref.watch(componentsByTypeProvider('culture_organisation'));
    final upAsync = ref.watch(componentsByTypeProvider('culture_upbringing'));
    final langsAsync = ref.watch(componentsByTypeProvider('language'));
    final skillsAsync = ref.watch(componentsByTypeProvider('skill'));

    // Show suggestion from asset for selected ancestry; only refresh the Future when ancestry changes
    final ancestryNameHint = ancestryName;
    if (_lastAncestryNameForSuggestion != ancestryNameHint) {
      _lastAncestryNameForSuggestion = ancestryNameHint;
      _suggestionFuture = _getSuggestionFor(ancestryNameHint);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: HeroTheme.sectionCardElevation,
        shape: const RoundedRectangleBorder(borderRadius: HeroTheme.cardRadius),
        child: Column(
          children: [
            HeroTheme.buildSectionHeader(
              context,
              title: 'Culture',
              subtitle: 'Your hero\'s upbringing and environment',
              icon: Icons.public,
              color: HeroTheme.getStepColor('culture'),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_selectedAncestryId != null) ...[
                    const SizedBox(height: 6),
                    FutureBuilder<Map<String, String>?>(
                      future: _suggestionFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          // Only show a very light placeholder to avoid flicker
                          return const SizedBox.shrink();
                        }
                        final s = snapshot.data;
                        if (s == null) return const SizedBox.shrink();
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Icon(Icons.tips_and_updates,
                                  size: 16, color: Colors.blueGrey),
                              Text('Suggested:',
                                  style: TextStyle(
                                      color: Colors.blueGrey.shade700,
                                      fontWeight: FontWeight.w600)),
                              ActionChip(
                                label: Text('Language: ${s['language']}'),
                                onPressed: () {
                                  langsAsync.maybeWhen(
                                    data: (langs) {
                                      final found = langs
                                          .where(
                                            (l) =>
                                                l.name.toLowerCase() ==
                                                (s['language'] ?? '')
                                                    .toLowerCase(),
                                          )
                                          .toList();
                                      if (found.isEmpty) return;
                                      setState(() {
                                        _selectedLanguageId = found.first.id;
                                        _dirty = true;
                                      });
                                    },
                                    orElse: () {},
                                  );
                                },
                              ),
                              ActionChip(
                                label: Text('Environment: ${s['environment']}'),
                                onPressed: () {
                                  envAsync.maybeWhen(
                                    data: (envs) {
                                      final found = envs
                                          .where(
                                            (e) =>
                                                e.name.toLowerCase() ==
                                                (s['environment'] ?? '')
                                                    .toLowerCase(),
                                          )
                                          .toList();
                                      if (found.isEmpty) return;
                                      setState(() {
                                        _envId = found.first.id;
                                        _envSkillId =
                                            null; // reset skill when culture changes
                                        _dirty = true;
                                      });
                                    },
                                    orElse: () {},
                                  );
                                },
                              ),
                              ActionChip(
                                label:
                                    Text('Organization: ${s['organization']}'),
                                onPressed: () {
                                  orgAsync.maybeWhen(
                                    data: (orgs) {
                                      final found = orgs
                                          .where(
                                            (o) =>
                                                o.name.toLowerCase() ==
                                                (s['organization'] ?? '')
                                                    .toLowerCase(),
                                          )
                                          .toList();
                                      if (found.isEmpty) return;
                                      setState(() {
                                        _orgId = found.first.id;
                                        _orgSkillId = null;
                                        _dirty = true;
                                      });
                                    },
                                    orElse: () {},
                                  );
                                },
                              ),
                              ActionChip(
                                label: Text('Upbringing: ${s['upbringing']}'),
                                onPressed: () {
                                  upAsync.maybeWhen(
                                    data: (ups) {
                                      final found = ups
                                          .where(
                                            (u) =>
                                                u.name.toLowerCase() ==
                                                (s['upbringing'] ?? '')
                                                    .toLowerCase(),
                                          )
                                          .toList();
                                      if (found.isEmpty) return;
                                      setState(() {
                                        _upId = found.first.id;
                                        _upSkillId = null;
                                        _dirty = true;
                                      });
                                    },
                                    orElse: () {},
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Language selection
                  langsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, st) => Text('Failed to load languages: $e'),
                    data: (langs) => _buildLanguageDropdown(langs),
                  ),
                  // Environment with its skill picker
                  _cultureDropdown(
                      'Environment',
                      Icons.park,
                      envAsync,
                      (v) => setState(() {
                            _envId = v;
                            _envSkillId = null;
                            _dirty = true;
                          })),
                  const SizedBox(height: 8),
                  skillsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (e, st) => const SizedBox.shrink(),
                    data: (allSkills) => envAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (e, st) => const SizedBox.shrink(),
                      data: (envs) => _cultureSkillDropdown(
                        label: 'Environment Skill',
                        selectedCultureId: _envId,
                        cultureItems: envs,
                        allSkills: allSkills,
                        selectedSkillId: _envSkillId,
                        onChanged: (v) => setState(() {
                          _envSkillId = v;
                          _dirty = true;
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Organization with its skill picker
                  _cultureDropdown(
                      'Organization',
                      Icons.apartment,
                      orgAsync,
                      (v) => setState(() {
                            _orgId = v;
                            _orgSkillId = null;
                            _dirty = true;
                          })),
                  const SizedBox(height: 8),
                  skillsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (e, st) => const SizedBox.shrink(),
                    data: (allSkills) => orgAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (e, st) => const SizedBox.shrink(),
                      data: (orgs) => _cultureSkillDropdown(
                        label: 'Organization Skill',
                        selectedCultureId: _orgId,
                        cultureItems: orgs,
                        allSkills: allSkills,
                        selectedSkillId: _orgSkillId,
                        onChanged: (v) => setState(() {
                          _orgSkillId = v;
                          _dirty = true;
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Upbringing with its skill picker
                  _cultureDropdown(
                      'Upbringing',
                      Icons.family_restroom,
                      upAsync,
                      (v) => setState(() {
                            _upId = v;
                            _upSkillId = null;
                            _dirty = true;
                          })),
                  const SizedBox(height: 8),
                  skillsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (e, st) => const SizedBox.shrink(),
                    data: (allSkills) => upAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (e, st) => const SizedBox.shrink(),
                      data: (ups) => _cultureSkillDropdown(
                        label: 'Upbringing Skill',
                        selectedCultureId: _upId,
                        cultureItems: ups,
                        allSkills: allSkills,
                        selectedSkillId: _upSkillId,
                        onChanged: (v) => setState(() {
                          _upSkillId = v;
                          _dirty = true;
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCareerLanguageDropdown({
    required List<model.Component> languages,
    required String? value,
    required Set<String?> exclude,
    required String label,
    required ValueChanged<String?> onChanged,
  }) {
    // Reuse grouping like culture
    final groups = <String, List<model.Component>>{
      'human': [],
      'ancestral': [],
      'dead': [],
    };
    for (final lang in languages) {
      final languageType = lang.data['language_type'] as String? ?? 'human';
      if (groups.containsKey(languageType)) groups[languageType]!.add(lang);
    }
    for (final group in groups.values) {
      group.sort((a, b) => a.name.compareTo(b.name));
    }
    final groupLabels = {
      'human': 'Human Languages',
      'ancestral': 'Ancestral Languages',
      'dead': 'Dead Languages',
    };

    // Validate current value and filter out excluded ids
    final allIds = languages.map((e) => e.id).toSet();
    final validValue = (value != null && allIds.contains(value)) ? value : null;

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: validValue,
          items: [
            const DropdownMenuItem<String?>(
                value: null, child: Text('— Choose language —')),
            for (final groupKey in ['human', 'ancestral', 'dead'])
              if (groups[groupKey]!.isNotEmpty) ...[
                DropdownMenuItem<String?>(
                  enabled: false,
                  value: '__lang_group__' + groupKey,
                  child: Text(
                    groupLabels[groupKey]!,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700),
                  ),
                ),
                for (final lang in groups[groupKey]!)
                  if (!exclude.contains(lang.id))
                    DropdownMenuItem<String?>(
                      value: lang.id,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(lang.name),
                      ),
                    ),
              ],
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _cultureDropdown(
      String label,
      IconData icon,
      AsyncValue<List<model.Component>> asyncList,
      ValueChanged<String?> onChanged) {
    final theme = Theme.of(context);
    final sectionColor = HeroTheme.getCultureSubsectionColor(label);

    return asyncList.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, st) => Text('Failed to load $label: $e',
          style: TextStyle(color: theme.colorScheme.error)),
      data: (items) {
        items = List.of(items)..sort((a, b) => a.name.compareTo(b.name));

        // Get the current selected value
        final selectedValue = label == 'Environment'
            ? _envId
            : label == 'Organization'
                ? _orgId
                : _upId;

        // Validate the selected value exists in the items list
        final validSelectedValue = selectedValue != null &&
                items.any((item) => item.id == selectedValue)
            ? selectedValue
            : null;

        final selectedItem = validSelectedValue == null
            ? null
            : items.firstWhere((i) => i.id == validSelectedValue,
                orElse: () => items.first);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sectionColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
            color: sectionColor.withValues(alpha: 0.05),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon and title
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(11)),
                  color: sectionColor.withValues(alpha: 0.1),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: sectionColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: sectionColor,
                      ),
                    ),
                  ],
                ),
              ),
              // Dropdown content
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InputDecorator(
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        isDense: true,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: validSelectedValue,
                          isExpanded: true,
                          hint: Text('Choose $label'),
                          items: [
                            const DropdownMenuItem<String?>(
                                value: null, child: Text('— Choose —')),
                            ...items.map((c) => DropdownMenuItem<String?>(
                                value: c.id, child: Text(c.name))),
                          ],
                          onChanged: onChanged,
                        ),
                      ),
                    ),
                    if (selectedItem != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        (selectedItem.data['description'] as String?) ?? '',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Career section ---
  String? _careerId;
  final Set<String> _careerChosenSkillIds = <String>{};
  final Set<String> _careerChosenPerkIds = <String>{};
  String? _careerIncidentName;
  // Career language choices (N dropdowns based on grant)
  List<String?> _careerLanguageIds = <String?>[];

  Widget _buildCareerSection() {
    final careersAsync = ref.watch(componentsByTypeProvider('career'));
    final skillsAsync = ref.watch(componentsByTypeProvider('skill'));
    final perksAsync = ref.watch(componentsByTypeProvider('perk'));
    final langsAsync = ref.watch(componentsByTypeProvider('language'));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: HeroTheme.sectionCardElevation,
        shape: const RoundedRectangleBorder(borderRadius: HeroTheme.cardRadius),
        child: Column(
          children: [
            HeroTheme.buildSectionHeader(
              context,
              title: 'Career',
              subtitle: 'Your hero\'s profession and background',
              icon: Icons.work,
              color: HeroTheme.getStepColor('career'),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  careersAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, st) => Text('Failed to load careers: $e'),
                    data: (careers) {
                      careers = List.of(careers)
                        ..sort((a, b) => a.name.compareTo(b.name));
                      final selected = careers.firstWhere(
                        (c) => c.id == _careerId,
                        orElse: () => careers.isNotEmpty
                            ? careers.first
                            : model.Component(
                                id: '', type: 'career', name: '—'),
                      );

                      final data = selected.data;
                      final int skillsNumber =
                          (data['skills_number'] as int?) ?? 0;
                      final List<String> skillGroups =
                          ((data['skill_groups'] as List?) ?? const <dynamic>[])
                              .map((e) => e.toString())
                              .toList();
                      final List<String> grantedSkills =
                          ((data['granted_skills'] as List?) ??
                                  const <dynamic>[])
                              .map((e) => e.toString())
                              .toList();
                      final String skillGrantDescription =
                          (data['skill_grant_description'] as String?) ?? '';
                      final int languagesGrant =
                          (data['languages'] as int?) ?? 0;
                      final int renown = (data['renown'] as int?) ?? 0;
                      final int wealth = (data['wealth'] as int?) ?? 0;
                      final int projectPoints =
                          (data['project_points'] as int?) ?? 0;
                      final String perkType =
                          (data['perk_type'] as String?) ?? '';
                      final int perksNumber =
                          (data['perks_number'] as int?) ?? 0;
                      final List<Map<String, dynamic>> incidents =
                          ((data['inciting_incidents'] as List?) ??
                                  const <dynamic>[])
                              .map((e) => Map<String, dynamic>.from(e as Map))
                              .toList();

                      // derive chosen skills remaining (career picks only), excluding granted
                      final chosenCareerSkills = _careerChosenSkillIds;
                      final neededFromGroups =
                          (skillsNumber - grantedSkills.length).clamp(0, 99);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Career picker
                          InputDecorator(
                            decoration: const InputDecoration(
                                labelText: 'Career',
                                prefixIcon: Icon(Icons.work_outline)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: _careerId,
                                isExpanded: true,
                                items: [
                                  const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('— Choose career —')),
                                  ...careers.map((c) =>
                                      DropdownMenuItem<String?>(
                                          value: c.id, child: Text(c.name))),
                                ],
                                onChanged: (v) {
                                  setState(() {
                                    _careerId = v;
                                    _careerChosenSkillIds.clear();
                                    _careerChosenPerkIds.clear();
                                    _careerIncidentName = null;
                                    _careerLanguageIds = <String?>[];
                                    _dirty = true;
                                  });
                                },
                              ),
                            ),
                          ),
                          if (_careerId != null && selected.id.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            // Career description
                            if ((data['description'] as String?)?.isNotEmpty ==
                                true)
                              Text(
                                data['description'] as String,
                                style: TextStyle(
                                    color: Colors.grey.shade300, height: 1.3),
                              ),
                            const SizedBox(height: 12),
                            // Summary chips
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _chip('Grants $languagesGrant languages',
                                    Colors.blueGrey),
                                _chip('Renown +$renown', Colors.orange),
                                _chip('Wealth +$wealth', Colors.green),
                                _chip('Project Points +$projectPoints',
                                    Colors.blue),
                                _chip(
                                    'Perks: $perksNumber${perkType.isNotEmpty ? ' ($perkType)' : ''}',
                                    Colors.purple),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Languages pickers (N dropdowns like Culture)
                            if (languagesGrant > 0)
                              langsAsync.when(
                                loading: () => const LinearProgressIndicator(),
                                error: (e, st) =>
                                    Text('Failed to load languages: $e'),
                                data: (allLangs) {
                                  // Ensure slots length matches grant in state
                                  final currentLen = _careerLanguageIds.length;
                                  if (currentLen != languagesGrant) {
                                    // Adjust length without causing overflow; safe to setState during build is not ideal, but infrequent
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      setState(() {
                                        var list = List<String?>.from(
                                            _careerLanguageIds);
                                        if (list.length > languagesGrant) {
                                          list = list
                                              .take(languagesGrant)
                                              .toList();
                                        } else {
                                          while (list.length < languagesGrant)
                                            list.add(null);
                                        }
                                        _careerLanguageIds = list;
                                      });
                                    });
                                  }
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.language, size: 18),
                                          const SizedBox(width: 8),
                                          Text('Languages ($languagesGrant)',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      for (int i = 0;
                                          i < languagesGrant;
                                          i++) ...[
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 8.0),
                                          child: _buildCareerLanguageDropdown(
                                            languages: allLangs,
                                            value: i < _careerLanguageIds.length
                                                ? _careerLanguageIds[i]
                                                : null,
                                            exclude: {
                                              for (int j = 0;
                                                  j < _careerLanguageIds.length;
                                                  j++)
                                                if (j != i)
                                                  _careerLanguageIds[j]
                                            },
                                            label: 'Language ${i + 1}',
                                            onChanged: (val) {
                                              setState(() {
                                                // Ensure length
                                                if (_careerLanguageIds.length >
                                                    languagesGrant) {
                                                  _careerLanguageIds =
                                                      _careerLanguageIds
                                                          .take(languagesGrant)
                                                          .toList();
                                                } else {
                                                  while (_careerLanguageIds
                                                          .length <
                                                      languagesGrant) {
                                                    _careerLanguageIds
                                                        .add(null);
                                                  }
                                                }
                                                _careerLanguageIds[i] = val;
                                                _dirty = true;
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              ),
                            const SizedBox(height: 12),
                            if (skillGrantDescription.isNotEmpty)
                              Text(skillGrantDescription,
                                  style: TextStyle(
                                      color: Colors.amber.shade700,
                                      fontStyle: FontStyle.italic)),
                            const SizedBox(height: 8),
                            // Granted skills list
                            if (grantedSkills.isNotEmpty)
                              Text(
                                  'Granted Skills: ${grantedSkills.join(', ')}'),
                            const SizedBox(height: 8),
                            // Skill pickers from groups
                            skillsAsync.when(
                              loading: () => const LinearProgressIndicator(),
                              error: (e, st) =>
                                  Text('Failed to load skills: $e'),
                              data: (allSkills) {
                                // eligible by groups
                                final eligible = allSkills
                                    .where((s) => skillGroups
                                        .contains(s.data['group']?.toString()))
                                    .where((s) =>
                                        !grantedSkills.contains(s.name) &&
                                        !grantedSkills.contains(s.id))
                                    .toList()
                                  ..sort((a, b) => a.name.compareTo(b.name));
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.school_outlined,
                                            size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                            'Choose $neededFromGroups skill(s) from groups: ${skillGroups.map((e) => e[0].toUpperCase() + e.substring(1)).join(', ')}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600)),
                                        const Spacer(),
                                        Text(
                                            '${chosenCareerSkills.length}/$neededFromGroups selected',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        for (final s in eligible)
                                          FilterChip(
                                            selected: _careerChosenSkillIds
                                                .contains(s.id),
                                            onSelected: (sel) {
                                              setState(() {
                                                if (sel) {
                                                  if (neededFromGroups <= 0) {
                                                    return;
                                                  }
                                                  if (!_careerChosenSkillIds
                                                      .contains(s.id)) {
                                                    if (_careerChosenSkillIds
                                                            .length >=
                                                        neededFromGroups) {
                                                      final oldest =
                                                          _careerChosenSkillIds
                                                                  .isNotEmpty
                                                              ? _careerChosenSkillIds
                                                                  .first
                                                              : null;
                                                      if (oldest != null) {
                                                        _careerChosenSkillIds
                                                            .remove(oldest);
                                                      }
                                                    }
                                                    _careerChosenSkillIds
                                                        .add(s.id);
                                                  }
                                                } else {
                                                  _careerChosenSkillIds
                                                      .remove(s.id);
                                                }
                                                _dirty = true;
                                              });
                                            },
                                            label: Text(s.name),
                                          ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            // Perk pickers filtered by group name contained in perkType (e.g., "Exploration perk")
                            perksAsync.when(
                              loading: () => const LinearProgressIndicator(),
                              error: (e, st) =>
                                  Text('Failed to load perks: $e'),
                              data: (allPerks) {
                                // Extract perk group from perk_type (e.g., "Intrigue perk" -> "intrigue")
                                String? perkGroup;
                                if (perkType.isNotEmpty) {
                                  final normalized = perkType.toLowerCase();
                                  // Check for each known perk group
                                  final knownGroups = [
                                    'exploration',
                                    'interpersonal',
                                    'intrigue',
                                    'lore',
                                    'supernatural'
                                  ];
                                  for (final group in knownGroups) {
                                    if (normalized.contains(group)) {
                                      perkGroup = group;
                                      break;
                                    }
                                  }
                                }

                                final eligible = allPerks
                                    .where((p) =>
                                        perkGroup == null ||
                                        p.data['group']?.toString() ==
                                            perkGroup)
                                    .toList()
                                  ..sort((a, b) => a.name.compareTo(b.name));
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.star_border, size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                            'Choose $perksNumber perk(s)${perkGroup != null ? ' from $perkGroup' : ''}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600)),
                                        const Spacer(),
                                        Text(
                                            '${_careerChosenPerkIds.length}/$perksNumber selected',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        for (final p in eligible)
                                          FilterChip(
                                            selected: _careerChosenPerkIds
                                                .contains(p.id),
                                            onSelected: (sel) {
                                              setState(() {
                                                if (sel) {
                                                  if (perksNumber <= 0) {
                                                    return;
                                                  }
                                                  if (!_careerChosenPerkIds
                                                      .contains(p.id)) {
                                                    if (_careerChosenPerkIds
                                                            .length >=
                                                        perksNumber) {
                                                      final oldest =
                                                          _careerChosenPerkIds
                                                                  .isNotEmpty
                                                              ? _careerChosenPerkIds
                                                                  .first
                                                              : null;
                                                      if (oldest != null) {
                                                        _careerChosenPerkIds
                                                            .remove(oldest);
                                                      }
                                                    }
                                                    _careerChosenPerkIds
                                                        .add(p.id);
                                                  }
                                                } else {
                                                  _careerChosenPerkIds
                                                      .remove(p.id);
                                                }
                                                _dirty = true;
                                              });
                                            },
                                            label: Text(p.name),
                                          ),
                                      ],
                                    ),
                                    // Show descriptions for selected perks
                                    if (_careerChosenPerkIds.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      ...eligible
                                          .where((p) => _careerChosenPerkIds
                                              .contains(p.id))
                                          .map((p) => Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 6.0),
                                                child: Text(
                                                  '${p.name}: ${(p.data['description'] as String?) ?? ''}',
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12),
                                                ),
                                              )),
                                    ],
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            // Inciting incident
                            InputDecorator(
                              decoration: const InputDecoration(
                                  labelText: 'Inciting Incident',
                                  prefixIcon: Icon(Icons.bolt_outlined)),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  value: _careerIncidentName,
                                  isExpanded: true,
                                  items: [
                                    const DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text('— Choose incident —')),
                                    ...incidents.map((inc) =>
                                        DropdownMenuItem<String?>(
                                            value: inc['name'] as String?,
                                            child: Text(
                                                inc['name'] as String? ?? ''))),
                                  ],
                                  onChanged: (v) => setState(() {
                                    _careerIncidentName = v;
                                    _dirty = true;
                                  }),
                                ),
                              ),
                            ),
                            // Selected incident description
                            if (_careerIncidentName != null)
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 12, top: 4),
                                child: Text(
                                  () {
                                    final inc = incidents.firstWhere(
                                      (e) =>
                                          (e['name'] as String?) ==
                                          _careerIncidentName,
                                      orElse: () => const <String, dynamic>{},
                                    );
                                    return (inc['description'] as String?) ??
                                        '';
                                  }(),
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                              ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cultureSkillDropdown({
    required String label,
    required String? selectedCultureId,
    required List<model.Component> cultureItems,
    required List<model.Component> allSkills,
    required String? selectedSkillId,
    required ValueChanged<String?> onChanged,
  }) {
    if (selectedCultureId == null) return const SizedBox.shrink();
    final selected = cultureItems.firstWhere(
      (c) => c.id == selectedCultureId,
      orElse: () => cultureItems.isNotEmpty
          ? cultureItems.first
          : model.Component(id: '', type: '', name: ''),
    );
    if (selected.id.isEmpty) return const SizedBox.shrink();
    // Build eligible skill list from groups and specifics
    final groups =
        ((selected.data['skillGroups'] as List?) ?? const <dynamic>[])
            .map((e) => e.toString())
            .toSet();
    final specifics =
        ((selected.data['specificSkills'] as List?) ?? const <dynamic>[])
            .map((e) => e.toString())
            .toSet();
    final eligible = <model.Component>{};
    for (final s in allSkills) {
      final g = s.data['group']?.toString();
      if (g != null && groups.contains(g)) eligible.add(s);
      if (specifics.contains(s.name) || specifics.contains(s.id))
        eligible.add(s);
    }
    // Group eligible skills by their group
    final skillGroups = <String, List<model.Component>>{};
    final ungrouped = <model.Component>[];

    for (final skill in eligible) {
      final group = skill.data['group']?.toString();
      if (group != null && group.isNotEmpty) {
        skillGroups.putIfAbsent(group, () => []).add(skill);
      } else {
        ungrouped.add(skill);
      }
    }

    // Sort groups and skills within groups
    final sortedGroupKeys = skillGroups.keys.toList()..sort();
    for (final group in skillGroups.values) {
      group.sort((a, b) => a.name.compareTo(b.name));
    }
    ungrouped.sort((a, b) => a.name.compareTo(b.name));

    final helper = (selected.data['skillDescription'] as String?) ?? '';
    // Ensure selected value exists in eligible skills, otherwise use null
    final validSelectedSkillId =
        selectedSkillId != null && eligible.any((s) => s.id == selectedSkillId)
            ? selectedSkillId
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.school_outlined, size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        if (helper.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            helper,
            style: TextStyle(
                color: Colors.grey.shade600, fontSize: 12, height: 1.3),
            softWrap: true,
          ),
        ],
        const SizedBox(height: 8),
        if (sortedGroupKeys.isNotEmpty)
          ...sortedGroupKeys.map((groupKey) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(groupKey,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final skill in skillGroups[groupKey]!)
                        FilterChip(
                          selected: validSelectedSkillId == skill.id,
                          onSelected: (sel) => onChanged(sel ? skill.id : null),
                          label: Text(skill.name),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              )),
        if (ungrouped.isNotEmpty) ...[
          Text('Other',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final skill in ungrouped)
                FilterChip(
                  selected: validSelectedSkillId == skill.id,
                  onSelected: (sel) => onChanged(sel ? skill.id : null),
                  label: Text(skill.name),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
