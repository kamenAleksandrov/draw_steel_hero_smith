import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/providers.dart';
import '../../../../core/models/component.dart' as model;
import '../../../../core/theme/hero_theme.dart';

class StoryCareerSection extends ConsumerWidget {
  const StoryCareerSection({
    super.key,
    required this.careerId,
    required this.chosenSkillIds,
    required this.chosenPerkIds,
    required this.incidentName,
    required this.careerLanguageIds,
    required this.primaryLanguageId,
    required this.onCareerChanged,
    required this.onCareerLanguageSlotsChanged,
    required this.onCareerLanguageChanged,
    required this.onSkillSelectionChanged,
    required this.onPerkSelectionChanged,
    required this.onIncidentChanged,
    required this.onDirty,
  });

  final String? careerId;
  final Set<String> chosenSkillIds;
  final Set<String> chosenPerkIds;
  final String? incidentName;
  final List<String?> careerLanguageIds;
  final String? primaryLanguageId;

  final ValueChanged<String?> onCareerChanged;
  final ValueChanged<int> onCareerLanguageSlotsChanged;
  final void Function(int index, String? value) onCareerLanguageChanged;
  final void Function(Set<String> skillIds) onSkillSelectionChanged;
  final void Function(Set<String> perkIds) onPerkSelectionChanged;
  final ValueChanged<String?> onIncidentChanged;
  final VoidCallback onDirty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              child: careersAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Failed to load careers: $e'),
                data: (careers) => _CareerContent(
                  careers: careers,
                  careerId: careerId,
                  chosenSkillIds: chosenSkillIds,
                  chosenPerkIds: chosenPerkIds,
                  incidentName: incidentName,
                  careerLanguageIds: careerLanguageIds,
                  primaryLanguageId: primaryLanguageId,
                  skillsAsync: skillsAsync,
                  perksAsync: perksAsync,
                  langsAsync: langsAsync,
                  onCareerChanged: onCareerChanged,
                  onCareerLanguageSlotsChanged: onCareerLanguageSlotsChanged,
                  onCareerLanguageChanged: onCareerLanguageChanged,
                  onSkillSelectionChanged: onSkillSelectionChanged,
                  onPerkSelectionChanged: onPerkSelectionChanged,
                  onIncidentChanged: onIncidentChanged,
                  onDirty: onDirty,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CareerContent extends StatefulWidget {
  const _CareerContent({
    required this.careers,
    required this.careerId,
    required this.chosenSkillIds,
    required this.chosenPerkIds,
    required this.incidentName,
    required this.careerLanguageIds,
    required this.primaryLanguageId,
    required this.skillsAsync,
    required this.perksAsync,
    required this.langsAsync,
    required this.onCareerChanged,
    required this.onCareerLanguageSlotsChanged,
    required this.onCareerLanguageChanged,
    required this.onSkillSelectionChanged,
    required this.onPerkSelectionChanged,
    required this.onIncidentChanged,
    required this.onDirty,
  });

  final List<model.Component> careers;
  final String? careerId;
  final Set<String> chosenSkillIds;
  final Set<String> chosenPerkIds;
  final String? incidentName;
  final List<String?> careerLanguageIds;
  final String? primaryLanguageId;

  final AsyncValue<List<model.Component>> skillsAsync;
  final AsyncValue<List<model.Component>> perksAsync;
  final AsyncValue<List<model.Component>> langsAsync;

  final ValueChanged<String?> onCareerChanged;
  final ValueChanged<int> onCareerLanguageSlotsChanged;
  final void Function(int index, String? value) onCareerLanguageChanged;
  final void Function(Set<String> skillIds) onSkillSelectionChanged;
  final void Function(Set<String> perkIds) onPerkSelectionChanged;
  final ValueChanged<String?> onIncidentChanged;
  final VoidCallback onDirty;

  @override
  State<_CareerContent> createState() => _CareerContentState();
}

class _CareerContentState extends State<_CareerContent> {
  late List<model.Component> _careers;
  int? _lastEmittedLanguageSlots;

  @override
  void initState() {
    super.initState();
    _careers = List.of(widget.careers)
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  void didUpdateWidget(covariant _CareerContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.careers, widget.careers)) {
      _careers = List.of(widget.careers)
        ..sort((a, b) => a.name.compareTo(b.name));
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCareer = _careers.firstWhere(
      (c) => c.id == widget.careerId,
      orElse: () => _careers.isNotEmpty
          ? _careers.first
          : const model.Component(id: '', type: 'career', name: '—'),
    );

    final data = selectedCareer.data;
    final skillsNumber = (data['skills_number'] as int?) ?? 0;
    final skillGroups = ((data['skill_groups'] as List?) ?? const <dynamic>[])
        .map((e) => e.toString())
        .toList();
    final grantedSkills =
        ((data['granted_skills'] as List?) ?? const <dynamic>[])
            .map((e) => e.toString())
            .toList();
    final skillGrantDescription =
        (data['skill_grant_description'] as String?) ?? '';
    final languagesGrant = (data['languages'] as int?) ?? 0;
    if (_lastEmittedLanguageSlots != languagesGrant) {
      _lastEmittedLanguageSlots = languagesGrant;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onCareerLanguageSlotsChanged(languagesGrant);
      });
    }
    final renown = (data['renown'] as int?) ?? 0;
    final wealth = (data['wealth'] as int?) ?? 0;
    final projectPoints = (data['project_points'] as int?) ?? 0;
    final perkType = (data['perk_type'] as String?) ?? '';
    final perksNumber = (data['perks_number'] as int?) ?? 0;
    final incidents =
        ((data['inciting_incidents'] as List?) ?? const <dynamic>[])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

    final chosenCareerSkills = widget.chosenSkillIds;
    final neededFromGroups = (skillsNumber - grantedSkills.length).clamp(0, 99);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Career',
            prefixIcon: Icon(Icons.work_outline),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: widget.careerId,
              isExpanded: true,
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('— Choose career —'),
                ),
                ..._careers.map(
                  (c) => DropdownMenuItem<String?>(
                    value: c.id,
                    child: Text(c.name),
                  ),
                ),
              ],
              onChanged: (value) {
                widget.onCareerChanged(value);
                widget.onDirty();
              },
            ),
          ),
        ),
        if (widget.careerId != null && selectedCareer.id.isNotEmpty) ...[
          const SizedBox(height: 8),
          if ((data['description'] as String?)?.isNotEmpty == true) ...[
            Text(data['description'] as String,
                style: TextStyle(height: 1.3, color: Colors.grey.shade800)),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (renown > 0)
                Chip(
                  label: Text('+${renown.toString()} Renown'),
                  avatar: const Icon(Icons.stars, size: 18),
                ),
              if (wealth > 0)
                Chip(
                  label: Text('+${wealth.toString()} Wealth'),
                  avatar: const Icon(Icons.attach_money, size: 18),
                ),
              if (projectPoints > 0)
                Chip(
                  label: Text('+${projectPoints.toString()} Project Points'),
                  avatar: const Icon(Icons.engineering, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (languagesGrant > 0)
            widget.langsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Failed to load languages: $e'),
              data: (languages) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < languagesGrant; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CareerLanguageDropdown(
                        languages: languages,
                        value: i < widget.careerLanguageIds.length
                            ? widget.careerLanguageIds[i]
                            : null,
                        exclude: {
                          if (widget.primaryLanguageId != null)
                            widget.primaryLanguageId,
                          for (var j = 0;
                              j < widget.careerLanguageIds.length;
                              j++)
                            if (j != i) widget.careerLanguageIds[j],
                        },
                        label: 'Bonus Language ${i + 1}',
                        onChanged: (val) {
                          widget.onCareerLanguageChanged(i, val);
                          widget.onDirty();
                        },
                      ),
                    ),
                ],
              ),
            ),
          if (skillGrantDescription.isNotEmpty) ...[
            Text(
              skillGrantDescription,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (grantedSkills.isNotEmpty)
            Text('Granted Skills: ${grantedSkills.join(', ')}'),
          const SizedBox(height: 8),
          widget.skillsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Failed to load skills: $e'),
            data: (skills) {
              final eligible = skills.where((skill) {
                final group = skill.data['group']?.toString();
                return skillGroups.contains(group) ||
                    skillGroups.contains(skill.name);
              }).toList();
              eligible.sort((a, b) => a.name.compareTo(b.name));

              final selectedCount = chosenCareerSkills.length;
              final remaining = (neededFromGroups - selectedCount).clamp(0, 99);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (neededFromGroups > 0)
                    Text(
                      'Choose $neededFromGroups skill${neededFromGroups == 1 ? '' : 's'} from the groups below.',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final skill in eligible)
                        FilterChip(
                          label: Text(skill.name),
                          selected: widget.chosenSkillIds.contains(skill.id),
                          onSelected: (value) {
                            final updated =
                                LinkedHashSet<String>.of(widget.chosenSkillIds);
                            if (value) {
                              if (neededFromGroups <= 0) return;
                              if (!updated.contains(skill.id)) {
                                updated.add(skill.id);
                                if (updated.length > neededFromGroups) {
                                  updated.remove(updated.first);
                                }
                              }
                            } else {
                              updated.remove(skill.id);
                            }
                            widget.onSkillSelectionChanged(updated);
                            widget.onDirty();
                          },
                        ),
                    ],
                  ),
                  if (remaining > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                        '$remaining pick${remaining == 1 ? '' : 's'} remaining.'),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          widget.perksAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Failed to load perks: $e'),
            data: (perks) {
              final filtered = perks.where((perk) {
                final type = perk.data['perk_type']?.toString().toLowerCase();
                return perkType.isEmpty ||
                    (type != null && perkType.toLowerCase().contains(type));
              }).toList()
                ..sort((a, b) => a.name.compareTo(b.name));
              final remaining =
                  (perksNumber - widget.chosenPerkIds.length).clamp(0, 99);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (perksNumber > 0)
                    Text(
                      'Choose $perksNumber perk${perksNumber == 1 ? '' : 's'} of type $perkType.',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final perk in filtered)
                        FilterChip(
                          label: Text(perk.name),
                          selected: widget.chosenPerkIds.contains(perk.id),
                          onSelected: (value) {
                            final updated =
                                LinkedHashSet<String>.of(widget.chosenPerkIds);
                            if (value) {
                              if (perksNumber <= 0) return;
                              if (!updated.contains(perk.id)) {
                                updated.add(perk.id);
                                if (updated.length > perksNumber) {
                                  updated.remove(updated.first);
                                }
                              }
                            } else {
                              updated.remove(perk.id);
                            }
                            widget.onPerkSelectionChanged(updated);
                            widget.onDirty();
                          },
                        ),
                    ],
                  ),
                  if (remaining > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                        '$remaining pick${remaining == 1 ? '' : 's'} remaining.'),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          if (incidents.isNotEmpty)
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Inciting Incident',
                prefixIcon: Icon(Icons.auto_fix_high_outlined),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: widget.incidentName,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('— Choose incident —'),
                    ),
                    ...incidents.map(
                      (incident) => DropdownMenuItem<String?>(
                        value: incident['name']?.toString(),
                        child: Text(incident['name']?.toString() ?? 'Unknown'),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    widget.onIncidentChanged(value);
                    widget.onDirty();
                  },
                ),
              ),
            ),
          if (widget.incidentName != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                incidents
                        .firstWhere(
                          (incident) => incident['name'] == widget.incidentName,
                          orElse: () => const <String, dynamic>{},
                        )['description']
                        ?.toString() ??
                    '',
                style: TextStyle(color: Colors.grey.shade700, height: 1.3),
              ),
            ),
        ],
      ],
    );
  }
}

class _CareerLanguageDropdown extends StatelessWidget {
  const _CareerLanguageDropdown({
    required this.languages,
    required this.value,
    required this.exclude,
    required this.label,
    required this.onChanged,
  });

  final List<model.Component> languages;
  final String? value;
  final Set<String?> exclude;
  final String label;
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
    for (final group in groups.values) {
      group.sort((a, b) => a.name.compareTo(b.name));
    }

    final validValue =
        value != null && languages.any((language) => language.id == value)
            ? value
            : null;

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
              value: null,
              child: Text('— Choose language —'),
            ),
            for (final key in ['human', 'ancestral', 'dead'])
              if (groups[key]!.isNotEmpty) ...[
                DropdownMenuItem<String?>(
                  enabled: false,
                  value: '__group_$key',
                  child: Text(
                    _titleForGroup(key),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                for (final lang in groups[key]!)
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
          onChanged: (value) {
            if (value != null && value.startsWith('__group_')) return;
            onChanged(value);
          },
        ),
      ),
    );
  }

  String _titleForGroup(String key) {
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
