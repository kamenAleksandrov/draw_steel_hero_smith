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
    final theme = Theme.of(context);
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
            Text(
              data['description'] as String,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.3),
            ),
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

              final picksNeeded = neededFromGroups;
              if (picksNeeded <= 0) {
                return const SizedBox.shrink();
              }

              final skillMap = {
                for (final skill in eligible) skill.id: skill,
              };
              final currentSelections =
                  widget.chosenSkillIds.where(skillMap.containsKey).toList();

              final grouped = <String, List<model.Component>>{};
              final ungrouped = <model.Component>[];
              for (final skill in eligible) {
                final group = skill.data['group']?.toString();
                if (group != null && group.isNotEmpty) {
                  grouped.putIfAbsent(group, () => []).add(skill);
                } else {
                  ungrouped.add(skill);
                }
              }
              final sortedGroups = grouped.keys.toList()..sort();
              for (final list in grouped.values) {
                list.sort((a, b) => a.name.compareTo(b.name));
              }
              ungrouped.sort((a, b) => a.name.compareTo(b.name));

              List<DropdownMenuItem<String?>> buildDropdownItems() {
                final items = <DropdownMenuItem<String?>>[
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('— Choose skill —'),
                  ),
                ];

                for (final groupKey in sortedGroups) {
                  items.add(
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
                  for (final skill in grouped[groupKey]!) {
                    items.add(
                      DropdownMenuItem<String?>(
                        value: skill.id,
                        enabled: true,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Text(skill.name),
                        ),
                      ),
                    );
                  }
                }

                if (ungrouped.isNotEmpty) {
                  items.add(
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
                    items.add(
                      DropdownMenuItem<String?>(
                        value: skill.id,
                        enabled: true,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Text(skill.name),
                        ),
                      ),
                    );
                  }
                }

                return items;
              }

              List<String?> currentSlots() {
                final slots = List<String?>.filled(picksNeeded, null);
                for (var i = 0;
                    i < picksNeeded && i < currentSelections.length;
                    i++) {
                  slots[i] = currentSelections[i];
                }
                return slots;
              }

              final accent = Theme.of(context).colorScheme.primary;
              final border = OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: accent.withOpacity(0.6), width: 1.4),
              );
              final focusedBorder = OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: accent, width: 2),
              );

              final slots = currentSlots();
              final remaining = slots.where((value) => value == null).length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose $picksNeeded skill${picksNeeded == 1 ? '' : 's'} from the approved list.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  for (var index = 0; index < picksNeeded; index++) ...[
                    DropdownButtonFormField<String?>(
                      value: slots[index],
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Skill pick ${index + 1}',
                        border: border,
                        enabledBorder: border,
                        focusedBorder: focusedBorder,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      items: buildDropdownItems(),
                      onChanged: (value) {
                        if (value != null && value.startsWith('__group_')) {
                          return;
                        }
                        final updated = currentSlots();
                        updated[index] = value;
                        if (value != null) {
                          for (var i = 0; i < updated.length; i++) {
                            if (i != index && updated[i] == value) {
                              updated[i] = null;
                            }
                          }
                        }
                        final next = LinkedHashSet<String>();
                        for (final pick in updated) {
                          if (pick != null) {
                            next.add(pick);
                          }
                        }
                        widget.onSkillSelectionChanged(next);
                        widget.onDirty();
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (remaining > 0)
                    Text(
                        '$remaining pick${remaining == 1 ? '' : 's'} remaining.'),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          widget.perksAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Failed to load perks: $e'),
            data: (perks) {
              String? normalizePerkType(String? value) {
                if (value == null) return null;
                final cleaned = value
                    .toLowerCase()
                    .replaceAll('perk', '')
                    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
                    .trim();
                return cleaned.isEmpty ? null : cleaned;
              }

              String formatGroupLabel(String? raw) {
                final value = raw?.trim();
                if (value == null || value.isEmpty) {
                  return 'General';
                }
                return value
                    .replaceAll('_', ' ')
                    .replaceAll('-', ' ')
                    .split(RegExp(r'\s+'))
                    .where((segment) => segment.isNotEmpty)
                    .map((segment) =>
                        '${segment[0].toUpperCase()}${segment.substring(1).toLowerCase()}')
                    .join(' ');
              }

              final requiredType = normalizePerkType(perkType);

              var filtered = perks.where((perk) {
                final rawType = (perk.data['perk_type'] ??
                        perk.data['perkType'] ??
                        perk.data['group'])
                    ?.toString();
                final normalizedType = normalizePerkType(rawType);
                if (requiredType == null || requiredType.isEmpty) {
                  return true;
                }
                if (normalizedType == null || normalizedType.isEmpty) {
                  return false;
                }
                return normalizedType == requiredType ||
                    normalizedType.contains(requiredType) ||
                    requiredType.contains(normalizedType);
              }).toList()
                ..sort((a, b) => a.name.compareTo(b.name));

              if (filtered.isEmpty &&
                  requiredType != null &&
                  requiredType.isNotEmpty) {
                filtered = perks.toList()
                  ..sort((a, b) => a.name.compareTo(b.name));
              }
              if (perksNumber <= 0) {
                return const SizedBox.shrink();
              }

              final perkMap = {
                for (final perk in filtered) perk.id: perk,
              };
              final currentSelections =
                  widget.chosenPerkIds.where(perkMap.containsKey).toList();

              final grouped = <String, List<model.Component>>{};
              for (final perk in filtered) {
                final rawType = (perk.data['group'] ??
                        perk.data['perk_type'] ??
                        perk.data['perkType'])
                    ?.toString();
                final key = formatGroupLabel(rawType);
                grouped.putIfAbsent(key, () => []).add(perk);
              }

              final sortedGroupKeys = grouped.keys.toList()..sort();
              for (final list in grouped.values) {
                list.sort((a, b) => a.name.compareTo(b.name));
              }

              final borderColor = Theme.of(context).colorScheme.tertiary;
              final border = OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: borderColor.withOpacity(0.6), width: 1.4),
              );
              final focusedBorder = OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor, width: 2),
              );

              List<String?> currentSlots() {
                final slots = List<String?>.filled(perksNumber, null);
                for (var i = 0;
                    i < perksNumber && i < currentSelections.length;
                    i++) {
                  slots[i] = currentSelections[i];
                }
                return slots;
              }

              List<DropdownMenuItem<String?>> buildItems() {
                final items = <DropdownMenuItem<String?>>[
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('— Choose perk —'),
                  ),
                ];
                for (final key in sortedGroupKeys) {
                  items.add(
                    DropdownMenuItem<String?>(
                      value: '__group_$key',
                      enabled: false,
                      child: Text(
                        key,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  );
                  for (final perk in grouped[key]!) {
                    items.add(
                      DropdownMenuItem<String?>(
                        value: perk.id,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Text(perk.name),
                        ),
                      ),
                    );
                  }
                }
                return items;
              }

              final slots = currentSlots();
              final remaining = slots.where((value) => value == null).length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Choose $perksNumber perk${perksNumber == 1 ? '' : 's'}${perkType.isNotEmpty ? ' of type $perkType' : ''}.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  for (var index = 0; index < perksNumber; index++) ...[
                    DropdownButtonFormField<String?>(
                      value: slots[index],
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Perk pick ${index + 1}',
                        border: border,
                        enabledBorder: border,
                        focusedBorder: focusedBorder,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      items: buildItems(),
                      onChanged: (value) {
                        if (value != null && value.startsWith('__group_')) {
                          return;
                        }
                        final updated = currentSlots();
                        updated[index] = value;
                        if (value != null) {
                          for (var i = 0; i < updated.length; i++) {
                            if (i != index && updated[i] == value) {
                              updated[i] = null;
                            }
                          }
                        }
                        final next = LinkedHashSet<String>();
                        for (final pick in updated) {
                          if (pick != null) {
                            next.add(pick);
                          }
                        }
                        widget.onPerkSelectionChanged(next);
                        widget.onDirty();
                      },
                    ),
                    if (slots[index] != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: borderColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: borderColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              perkMap[slots[index]]!.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: borderColor,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              perkMap[slots[index]]!
                                      .data['description']
                                      ?.toString() ??
                                  'No description available',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                  if (remaining > 0)
                    Text(
                        '$remaining pick${remaining == 1 ? '' : 's'} remaining.'),
                  const SizedBox(height: 8),
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
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
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
