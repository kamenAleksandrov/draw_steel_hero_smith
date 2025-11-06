import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/providers.dart';
import '../../../../core/models/component.dart' as model;
import '../../../../core/models/story_creator_models.dart';
import '../../../../core/services/story_creator_service.dart';
import '../../../../core/theme/hero_theme.dart';

class StoryCultureSection extends ConsumerWidget {
  const StoryCultureSection({
    super.key,
    required this.selectedAncestryId,
    required this.environmentId,
    required this.organisationId,
    required this.upbringingId,
    required this.selectedLanguageId,
    required this.environmentSkillId,
    required this.organisationSkillId,
    required this.upbringingSkillId,
    required this.onLanguageChanged,
    required this.onEnvironmentChanged,
    required this.onOrganisationChanged,
    required this.onUpbringingChanged,
    required this.onEnvironmentSkillChanged,
    required this.onOrganisationSkillChanged,
    required this.onUpbringingSkillChanged,
    required this.onDirty,
  });

  final String? selectedAncestryId;
  final String? environmentId;
  final String? organisationId;
  final String? upbringingId;
  final String? selectedLanguageId;
  final String? environmentSkillId;
  final String? organisationSkillId;
  final String? upbringingSkillId;

  final ValueChanged<String?> onLanguageChanged;
  final ValueChanged<String?> onEnvironmentChanged;
  final ValueChanged<String?> onOrganisationChanged;
  final ValueChanged<String?> onUpbringingChanged;
  final ValueChanged<String?> onEnvironmentSkillChanged;
  final ValueChanged<String?> onOrganisationSkillChanged;
  final ValueChanged<String?> onUpbringingSkillChanged;
  final VoidCallback onDirty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final envAsync = ref.watch(componentsByTypeProvider('culture_environment'));
    final orgAsync =
        ref.watch(componentsByTypeProvider('culture_organisation'));
    final upAsync = ref.watch(componentsByTypeProvider('culture_upbringing'));
    final langsAsync = ref.watch(componentsByTypeProvider('language'));
    final skillsAsync = ref.watch(componentsByTypeProvider('skill'));
    final ancestriesAsync = ref.watch(componentsByTypeProvider('ancestry'));

    Future<StoryCultureSuggestion?>? suggestionFuture;
    ancestriesAsync.when(
      data: (ancestries) {
        final ancestry = ancestries.firstWhere(
          (a) => a.id == selectedAncestryId,
          orElse: () =>
              const model.Component(id: '', type: 'ancestry', name: ''),
        );
        if (ancestry.id.isNotEmpty) {
          final service = ref.read(storyCreatorServiceProvider);
          suggestionFuture = service.suggestionForAncestry(ancestry.name);
        }
      },
      loading: () {},
      error: (_, __) {},
    );

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
                  if (selectedAncestryId != null)
                    _SuggestionChips(
                      suggestionFuture: suggestionFuture,
                      langsAsync: langsAsync,
                      envAsync: envAsync,
                      orgAsync: orgAsync,
                      upAsync: upAsync,
                      onLanguageChanged: onLanguageChanged,
                      onEnvironmentChanged: (value) {
                        onEnvironmentChanged(value);
                        onEnvironmentSkillChanged(null);
                      },
                      onOrganisationChanged: (value) {
                        onOrganisationChanged(value);
                        onOrganisationSkillChanged(null);
                      },
                      onUpbringingChanged: (value) {
                        onUpbringingChanged(value);
                        onUpbringingSkillChanged(null);
                      },
                      onDirty: onDirty,
                    ),
                  const SizedBox(height: 16),
                  langsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Failed to load languages: $e'),
                    data: (langs) => _LanguageDropdown(
                      languages: langs,
                      selectedLanguageId: selectedLanguageId,
                      onChanged: (val) {
                        onLanguageChanged(val);
                        onDirty();
                      },
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color:
                              HeroTheme.getCultureSubsectionColor('environment')
                                  .withOpacity(0.5),
                          width: 3,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CultureDropdown(
                          label: 'Environment',
                          icon: Icons.park,
                          asyncList: envAsync,
                          selectedId: environmentId,
                          onChanged: (value) {
                            onEnvironmentChanged(value);
                            onEnvironmentSkillChanged(null);
                            onDirty();
                          },
                        ),
                        const SizedBox(height: 8),
                        skillsAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (skills) => envAsync.when(
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                            data: (envs) => _CultureSkillChooser(
                              label: 'Environment Skill',
                              selectedCultureId: environmentId,
                              cultureItems: envs,
                              selectedSkillId: environmentSkillId,
                              allSkills: skills,
                              onChanged: (value) {
                                onEnvironmentSkillChanged(value);
                                onDirty();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: HeroTheme.getCultureSubsectionColor(
                                  'organisation')
                              .withOpacity(0.5),
                          width: 3,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CultureDropdown(
                          label: 'Organization',
                          icon: Icons.apartment,
                          asyncList: orgAsync,
                          selectedId: organisationId,
                          onChanged: (value) {
                            onOrganisationChanged(value);
                            onOrganisationSkillChanged(null);
                            onDirty();
                          },
                        ),
                        const SizedBox(height: 8),
                        skillsAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (skills) => orgAsync.when(
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                            data: (orgs) => _CultureSkillChooser(
                              label: 'Organization Skill',
                              selectedCultureId: organisationId,
                              cultureItems: orgs,
                              selectedSkillId: organisationSkillId,
                              allSkills: skills,
                              onChanged: (value) {
                                onOrganisationSkillChanged(value);
                                onDirty();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color:
                              HeroTheme.getCultureSubsectionColor('upbringing')
                                  .withOpacity(0.5),
                          width: 3,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CultureDropdown(
                          label: 'Upbringing',
                          icon: Icons.family_restroom,
                          asyncList: upAsync,
                          selectedId: upbringingId,
                          onChanged: (value) {
                            onUpbringingChanged(value);
                            onUpbringingSkillChanged(null);
                            onDirty();
                          },
                        ),
                        const SizedBox(height: 8),
                        skillsAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (skills) => upAsync.when(
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                            data: (ups) => _CultureSkillChooser(
                              label: 'Upbringing Skill',
                              selectedCultureId: upbringingId,
                              cultureItems: ups,
                              selectedSkillId: upbringingSkillId,
                              allSkills: skills,
                              onChanged: (value) {
                                onUpbringingSkillChanged(value);
                                onDirty();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChips extends StatelessWidget {
  const _SuggestionChips({
    required this.suggestionFuture,
    required this.langsAsync,
    required this.envAsync,
    required this.orgAsync,
    required this.upAsync,
    required this.onLanguageChanged,
    required this.onEnvironmentChanged,
    required this.onOrganisationChanged,
    required this.onUpbringingChanged,
    required this.onDirty,
  });

  final Future<StoryCultureSuggestion?>? suggestionFuture;
  final AsyncValue<List<model.Component>> langsAsync;
  final AsyncValue<List<model.Component>> envAsync;
  final AsyncValue<List<model.Component>> orgAsync;
  final AsyncValue<List<model.Component>> upAsync;
  final ValueChanged<String?> onLanguageChanged;
  final ValueChanged<String?> onEnvironmentChanged;
  final ValueChanged<String?> onOrganisationChanged;
  final ValueChanged<String?> onUpbringingChanged;
  final VoidCallback onDirty;

  @override
  Widget build(BuildContext context) {
    if (suggestionFuture == null) return const SizedBox.shrink();
    return FutureBuilder<StoryCultureSuggestion?>(
      future: suggestionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final suggestion = snapshot.data;
        if (suggestion == null || suggestion.isEmpty) {
          return const SizedBox.shrink();
        }
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
              Text(
                'Suggested:',
                style: TextStyle(
                  color: Colors.blueGrey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (suggestion.language != null)
                ActionChip(
                  label: Text('Language: ${suggestion.language}'),
                  onPressed: () {
                    final languageName = suggestion.language!.toLowerCase();
                    langsAsync.maybeWhen(
                      data: (langs) {
                        final found = langs.firstWhere(
                          (l) => l.name.toLowerCase() == languageName,
                          orElse: () => const model.Component(
                              id: '', type: 'language', name: ''),
                        );
                        if (found.id.isEmpty) return;
                        onLanguageChanged(found.id);
                        onDirty();
                      },
                      orElse: () {},
                    );
                  },
                ),
              if (suggestion.environment != null)
                ActionChip(
                  label: Text('Environment: ${suggestion.environment}'),
                  onPressed: () {
                    final name = suggestion.environment!.toLowerCase();
                    envAsync.maybeWhen(
                      data: (items) {
                        final found = items.firstWhere(
                          (e) => e.name.toLowerCase() == name,
                          orElse: () => const model.Component(
                              id: '', type: 'culture_environment', name: ''),
                        );
                        if (found.id.isEmpty) return;
                        onEnvironmentChanged(found.id);
                        onDirty();
                      },
                      orElse: () {},
                    );
                  },
                ),
              if (suggestion.organization != null)
                ActionChip(
                  label: Text('Organization: ${suggestion.organization}'),
                  onPressed: () {
                    final name = suggestion.organization!.toLowerCase();
                    orgAsync.maybeWhen(
                      data: (items) {
                        final found = items.firstWhere(
                          (o) => o.name.toLowerCase() == name,
                          orElse: () => const model.Component(
                              id: '', type: 'culture_organisation', name: ''),
                        );
                        if (found.id.isEmpty) return;
                        onOrganisationChanged(found.id);
                        onDirty();
                      },
                      orElse: () {},
                    );
                  },
                ),
              if (suggestion.upbringing != null)
                ActionChip(
                  label: Text('Upbringing: ${suggestion.upbringing}'),
                  onPressed: () {
                    final name = suggestion.upbringing!.toLowerCase();
                    upAsync.maybeWhen(
                      data: (items) {
                        final found = items.firstWhere(
                          (u) => u.name.toLowerCase() == name,
                          orElse: () => const model.Component(
                              id: '', type: 'culture_upbringing', name: ''),
                        );
                        if (found.id.isEmpty) return;
                        onUpbringingChanged(found.id);
                        onDirty();
                      },
                      orElse: () {},
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _LanguageDropdown extends StatelessWidget {
  const _LanguageDropdown({
    required this.languages,
    required this.selectedLanguageId,
    required this.onChanged,
  });

  final List<model.Component> languages;
  final String? selectedLanguageId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<model.Component>>{
      'human': [],
      'ancestral': [],
      'dead': [],
    };
    for (final lang in languages) {
      final type = lang.data['language_type'] as String? ?? 'human';
      if (groups.containsKey(type)) {
        groups[type]!.add(lang);
      }
    }
    for (final list in groups.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }
    final selected = selectedLanguageId != null &&
            languages.any((lang) => lang.id == selectedLanguageId)
        ? selectedLanguageId
        : null;

    const languageColor = Color(0xFF9C27B0);

    final enabledBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: languageColor, width: 1.4),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: languageColor.withOpacity(0.9), width: 2),
    );

    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('— Choose language —'),
      ),
    ];

    for (final key in ['human', 'ancestral', 'dead']) {
      final grouped = groups[key]!;
      if (grouped.isEmpty) {
        continue;
      }
      items.add(
        DropdownMenuItem<String?>(
          enabled: false,
          value: '__group_$key',
          child: Text(
            _languageGroupTitle(key),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      );
      for (final lang in grouped) {
        items.add(
          DropdownMenuItem<String?>(
            value: lang.id,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(lang.name),
            ),
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String?>(
        value: selected,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Language',
          labelStyle: const TextStyle(
            color: languageColor,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: const Icon(Icons.language, color: languageColor),
          border: enabledBorder,
          enabledBorder: enabledBorder,
          focusedBorder: focusedBorder,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: items,
        onChanged: (value) {
          if (value != null && value.startsWith('__group_')) {
            return;
          }
          onChanged(value);
        },
      ),
    );
  }

  String _languageGroupTitle(String key) {
    switch (key) {
      case 'ancestral':
        return 'Ancestral Languages';
      case 'dead':
        return 'Dead Languages';
      default:
        return 'Human Languages';
    }
  }
}

class _CultureDropdown extends StatelessWidget {
  const _CultureDropdown({
    required this.label,
    required this.icon,
    required this.asyncList,
    required this.selectedId,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final AsyncValue<List<model.Component>> asyncList;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sectionColor = HeroTheme.getCultureSubsectionColor(label);

    return asyncList.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Failed to load $label: $e',
          style: TextStyle(color: theme.colorScheme.error)),
      data: (items) {
        items = List.of(items)..sort((a, b) => a.name.compareTo(b.name));
        final validSelected =
            selectedId != null && items.any((item) => item.id == selectedId)
                ? selectedId
                : null;
        final selectedItem = validSelected == null
            ? null
            : items.firstWhere((item) => item.id == validSelected,
                orElse: () => items.first);

        final border = OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              BorderSide(color: sectionColor.withOpacity(0.65), width: 1.4),
        );
        final focusedBorder = OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: sectionColor, width: 2),
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String?>(
                value: validSelected,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle: TextStyle(
                    color: sectionColor,
                    fontWeight: FontWeight.w600,
                  ),
                  prefixIcon: Icon(icon, color: sectionColor),
                  border: border,
                  enabledBorder: border,
                  focusedBorder: focusedBorder,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('— Choose —'),
                  ),
                  ...items.map(
                    (item) => DropdownMenuItem<String?>(
                      value: item.id,
                      child: Text(item.name),
                    ),
                  ),
                ],
                onChanged: onChanged,
              ),
              if (selectedItem != null) ...[
                const SizedBox(height: 6),
                Text(
                  (selectedItem.data['description'] as String?) ?? '',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CultureSkillChooser extends StatelessWidget {
  const _CultureSkillChooser({
    required this.label,
    required this.selectedCultureId,
    required this.cultureItems,
    required this.allSkills,
    required this.selectedSkillId,
    required this.onChanged,
  });

  final String label;
  final String? selectedCultureId;
  final List<model.Component> cultureItems;
  final List<model.Component> allSkills;
  final String? selectedSkillId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (selectedCultureId == null) {
      return const SizedBox.shrink();
    }
    final selected = cultureItems.firstWhere(
      (c) => c.id == selectedCultureId,
      orElse: () => cultureItems.isNotEmpty
          ? cultureItems.first
          : const model.Component(id: '', type: '', name: ''),
    );
    if (selected.id.isEmpty) return const SizedBox.shrink();

    final groups =
        ((selected.data['skillGroups'] as List?) ?? const <dynamic>[])
            .map((e) => e.toString())
            .toSet();
    final specifics =
        ((selected.data['specificSkills'] as List?) ?? const <dynamic>[])
            .map((e) => e.toString())
            .toSet();
    final eligible = <model.Component>{};
    for (final skill in allSkills) {
      final group = skill.data['group']?.toString();
      if (group != null && groups.contains(group)) {
        eligible.add(skill);
      }
      if (specifics.contains(skill.name) || specifics.contains(skill.id)) {
        eligible.add(skill);
      }
    }

    if (eligible.isEmpty) return const SizedBox.shrink();

    final helper = (selected.data['skillDescription'] as String?) ?? '';
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

    final sortedGroupKeys = skillGroups.keys.toList()..sort();
    for (final list in skillGroups.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }
    ungrouped.sort((a, b) => a.name.compareTo(b.name));

    final validSelected =
        selectedSkillId != null && eligible.any((s) => s.id == selectedSkillId)
            ? selectedSkillId
            : null;

    final dropdownItems = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('— Choose skill —'),
      ),
    ];

    for (final groupKey in sortedGroupKeys) {
      dropdownItems.add(
        DropdownMenuItem<String?>(
          value: '__group_$groupKey',
          enabled: false,
          child: Text(
            groupKey,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      );
      for (final skill in skillGroups[groupKey]!) {
        dropdownItems.add(
          DropdownMenuItem<String?>(
            value: skill.id,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(skill.name),
            ),
          ),
        );
      }
    }

    if (ungrouped.isNotEmpty) {
      dropdownItems.add(
        DropdownMenuItem<String?>(
          value: '__group_other',
          enabled: false,
          child: Text(
            'Other',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      );
      for (final skill in ungrouped) {
        dropdownItems.add(
          DropdownMenuItem<String?>(
            value: skill.id,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(skill.name),
            ),
          ),
        );
      }
    }

    final accent = Theme.of(context).colorScheme.secondary;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: accent.withOpacity(0.6), width: 1.4),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: accent, width: 2),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String?>(
          value: validSelected,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: label,
            border: border,
            enabledBorder: border,
            focusedBorder: focusedBorder,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: dropdownItems,
          onChanged: (value) {
            if (value != null && value.startsWith('__group_')) {
              return;
            }
            onChanged(value);
          },
        ),
        if (helper.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            helper,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              height: 1.3,
            ),
            softWrap: true,
          ),
        ],
      ],
    );
  }
}
