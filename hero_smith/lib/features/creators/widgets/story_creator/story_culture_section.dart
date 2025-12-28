import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/providers.dart';
import '../../../../core/models/component.dart' as model;
import '../../../../core/theme/hero_theme.dart';
import '../../../../core/text/creators/widgets/story_creator/story_culture_section_text.dart';
import '../../../../core/utils/selection_guard.dart';

class _SearchOption<T> {
  const _SearchOption({
    required this.label,
    required this.value,
    this.subtitle,
  });

  final String label;
  final T? value;
  final String? subtitle;
}

class _PickerSelection<T> {
  const _PickerSelection({required this.value});

  final T? value;
}

Future<_PickerSelection<T>?> _showSearchablePicker<T>({
  required BuildContext context,
  required String title,
  required List<_SearchOption<T>> options,
  T? selected,
}) {
  return showDialog<_PickerSelection<T>>(
    context: context,
    builder: (dialogContext) {
      final controller = TextEditingController();
      var query = '';

      return StatefulBuilder(
        builder: (context, setState) {
          final normalizedQuery = query.trim().toLowerCase();
          final List<_SearchOption<T>> filtered = normalizedQuery.isEmpty
              ? options
              : options
                  .where(
                    (option) =>
                        option.label.toLowerCase().contains(normalizedQuery) ||
                        (option.subtitle?.toLowerCase().contains(
                              normalizedQuery,
                            ) ??
                            false),
                  )
                  .toList();

          return Dialog(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
                maxWidth: 500,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: TextField(
                      controller: controller,
                      autofocus: false,
                      decoration: const InputDecoration(
                        hintText: StoryCultureSectionText.searchHint,
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          query = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: filtered.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                                child: Text(
                                    StoryCultureSectionText.noMatchesFound)),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final option = filtered[index];
                              final isSelected = option.value == selected ||
                                  (option.value == null && selected == null);
                              return ListTile(
                                title: Text(option.label),
                                subtitle: option.subtitle != null
                                    ? Text(option.subtitle!)
                                    : null,
                                trailing: isSelected
                                    ? const Icon(Icons.check)
                                    : null,
                                onTap: () => Navigator.of(context).pop(
                                  _PickerSelection<T>(value: option.value),
                                ),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(StoryCultureSectionText.cancelLabel),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class StoryCultureSection extends ConsumerWidget {
  const StoryCultureSection({
    super.key,
    required this.selectedAncestryId,
    required this.environmentId,
    required this.organisationId,
    required this.upbringingId,
    required this.selectedLanguageId,
    required this.reservedLanguageIds,
    required this.environmentSkillId,
    required this.organisationSkillId,
    required this.upbringingSkillId,
    required this.reservedSkillIds,
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
  final Set<String> reservedLanguageIds;
  final String? environmentSkillId;
  final String? organisationSkillId;
  final String? upbringingSkillId;
  final Set<String> reservedSkillIds;

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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: HeroTheme.sectionCardElevation,
        shape: const RoundedRectangleBorder(borderRadius: HeroTheme.cardRadius),
        child: Column(
          children: [
            HeroTheme.buildSectionHeader(
              context,
              title: StoryCultureSectionText.sectionTitle,
              subtitle: StoryCultureSectionText.sectionSubtitle,
              icon: Icons.public,
              color: HeroTheme.getStepColor('culture'),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
  
                  langsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text(
                        '${StoryCultureSectionText.failedToLoadLanguagesPrefix}$e'),
                    data: (langs) => _LanguageDropdown(
                      languages: langs,
                      selectedLanguageId: selectedLanguageId,
                      reservedLanguageIds: reservedLanguageIds,
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
                          label: StoryCultureSectionText.environmentLabel,
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
                                label:
                                    StoryCultureSectionText.environmentSkillLabel,
                                selectedCultureId: environmentId,
                                cultureItems: envs,
                                selectedSkillId: environmentSkillId,
                                reservedSkillIds: reservedSkillIds,
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
                          label: StoryCultureSectionText.organizationLabel,
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
                                label:
                                    StoryCultureSectionText.organizationSkillLabel,
                                selectedCultureId: organisationId,
                                cultureItems: orgs,
                                selectedSkillId: organisationSkillId,
                                reservedSkillIds: reservedSkillIds,
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
                          label: StoryCultureSectionText.upbringingLabel,
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
                                label:
                                    StoryCultureSectionText.upbringingSkillLabel,
                                selectedCultureId: upbringingId,
                                cultureItems: ups,
                                selectedSkillId: upbringingSkillId,
                                reservedSkillIds: reservedSkillIds,
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

class _LanguageDropdown extends StatelessWidget {
  const _LanguageDropdown({
    required this.languages,
    required this.selectedLanguageId,
    required this.reservedLanguageIds,
    required this.onChanged,
  });

  final List<model.Component> languages;
  final String? selectedLanguageId;
  final Set<String> reservedLanguageIds;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final filteredLanguages = ComponentSelectionGuard.filterAllowed(
      options: languages,
      reservedIds: reservedLanguageIds,
      idSelector: (lang) => lang.id,
      currentId: selectedLanguageId,
    );

    if (filteredLanguages.isEmpty) {
      return const SizedBox.shrink();
    }

    final groups = <String, List<model.Component>>{
      'human': [],
      'ancestral': [],
      'dead': [],
    };
    for (final lang in filteredLanguages) {
      final type = lang.data['language_type'] as String? ?? 'human';
      if (groups.containsKey(type)) {
        groups[type]!.add(lang);
      }
    }
    for (final list in groups.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }
    final selected = selectedLanguageId != null &&
            filteredLanguages.any((lang) => lang.id == selectedLanguageId)
        ? selectedLanguageId
        : null;

    const languageColor = Color(0xFF9C27B0);

    final enabledBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: languageColor, width: 1.4),
    );

    Future<void> openSearch() async {
      final options = <_SearchOption<String?>>[
        const _SearchOption<String?>(
          label: StoryCultureSectionText.chooseLanguageOption,
          value: null,
        ),
      ];

      for (final key in ['human', 'ancestral', 'dead']) {
        for (final lang in groups[key]!) {
          options.add(
            _SearchOption<String?>(
              label: lang.name,
              value: lang.id,
              subtitle: _languageGroupTitle(key),
            ),
          );
        }
      }

      final result = await _showSearchablePicker<String?>(
        context: context,
        title: StoryCultureSectionText.selectLanguageTitle,
        options: options,
        selected: selected,
      );

      if (result == null) return;
      onChanged(result.value);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: openSearch,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: StoryCultureSectionText.languageLabel,
            labelStyle: const TextStyle(
              color: languageColor,
              fontWeight: FontWeight.w600,
            ),
            prefixIcon: const Icon(Icons.language, color: languageColor),
            suffixIcon: const Icon(Icons.search, color: languageColor),
            border: enabledBorder,
            enabledBorder: enabledBorder,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          child: Text(
            selected != null
                ? filteredLanguages.firstWhere((l) => l.id == selected).name
                : StoryCultureSectionText.chooseLanguagePlaceholder,
            style: TextStyle(
              fontSize: 16,
              color: selected != null
                  ? Theme.of(context).textTheme.bodyLarge?.color
                  : Theme.of(context).hintColor,
            ),
          ),
        ),
      ),
    );
  }

  String _languageGroupTitle(String key) {
    switch (key) {
      case 'ancestral':
        return StoryCultureSectionText.ancestralLanguagesGroup;
      case 'dead':
        return StoryCultureSectionText.deadLanguagesGroup;
      default:
        return StoryCultureSectionText.humanLanguagesGroup;
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
      error: (e, _) => Text(
          '${StoryCultureSectionText.failedToLoadLabelPrefix}$label${StoryCultureSectionText.failedToLoadLabelSeparator}$e',
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

        Future<void> openSearch() async {
          final options = <_SearchOption<String?>>[
            const _SearchOption<String?>(
              label: StoryCultureSectionText.chooseOption,
              value: null,
            ),
            ...items.map(
              (item) => _SearchOption<String?>(
                label: item.name,
                value: item.id,
              ),
            ),
          ];

          final result = await _showSearchablePicker<String?>(
            context: context,
            title:
                '${StoryCultureSectionText.selectLabelPrefix}$label',
            options: options,
            selected: validSelected,
          );

          if (result == null) return;
          onChanged(result.value);
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: openSearch,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: label,
                    labelStyle: TextStyle(
                      color: sectionColor,
                      fontWeight: FontWeight.w600,
                    ),
                    prefixIcon: Icon(icon, color: sectionColor),
                    suffixIcon: Icon(Icons.search, color: sectionColor),
                    border: border,
                    enabledBorder: border,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  child: Text(
                    selectedItem != null
                        ? selectedItem.name
                        : StoryCultureSectionText.choosePlaceholder,
                    style: TextStyle(
                      fontSize: 16,
                      color: selectedItem != null
                          ? theme.textTheme.bodyLarge?.color
                          : theme.hintColor,
                    ),
                  ),
                ),
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
    required this.reservedSkillIds,
    required this.onChanged,
  });

  final String label;
  final String? selectedCultureId;
  final List<model.Component> cultureItems;
  final List<model.Component> allSkills;
  final String? selectedSkillId;
  final Set<String> reservedSkillIds;
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

    final allowedSkills = ComponentSelectionGuard.filterAllowed(
      options: eligible,
      reservedIds: reservedSkillIds,
      idSelector: (skill) => skill.id,
      currentId: selectedSkillId,
    );

    if (allowedSkills.isEmpty) return const SizedBox.shrink();

    final helper = (selected.data['skillDescription'] as String?) ?? '';
    final skillGroups = <String, List<model.Component>>{};
    final ungrouped = <model.Component>[];

    for (final skill in allowedSkills) {
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

    final validSelected = selectedSkillId != null &&
            allowedSkills.any((s) => s.id == selectedSkillId)
        ? selectedSkillId
        : null;

    final accent = Theme.of(context).colorScheme.secondary;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: accent.withOpacity(0.6), width: 1.4),
    );

    Future<void> openSearch() async {
      final options = <_SearchOption<String?>>[
        const _SearchOption<String?>(
          label: StoryCultureSectionText.chooseSkillOption,
          value: null,
        ),
      ];

      for (final groupKey in sortedGroupKeys) {
        for (final skill in skillGroups[groupKey]!) {
          options.add(
            _SearchOption<String?>(
              label: skill.name,
              value: skill.id,
              subtitle: groupKey,
            ),
          );
        }
      }

      for (final skill in ungrouped) {
        options.add(
          _SearchOption<String?>(
            label: skill.name,
            value: skill.id,
            subtitle: StoryCultureSectionText.otherGroupLabel,
          ),
        );
      }

      final result = await _showSearchablePicker<String?>(
        context: context,
        title: label,
        options: options,
        selected: validSelected,
      );

      if (result == null) return;
      onChanged(result.value);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: openSearch,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              border: border,
              enabledBorder: border,
              suffixIcon: const Icon(Icons.search),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          child: Text(
            validSelected != null
                ? eligible
                    .firstWhere((s) => s.id == validSelected)
                    .name
                : StoryCultureSectionText.chooseSkillPlaceholder,
            style: TextStyle(
              fontSize: 16,
              color: validSelected != null
                  ? Theme.of(context).textTheme.bodyLarge?.color
                    : Theme.of(context).hintColor,
              ),
            ),
          ),
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
