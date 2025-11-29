import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/providers.dart';
import '../../../../core/models/component.dart' as model;
import '../../../../core/services/perk_grants_service.dart';
import '../../../../core/theme/hero_theme.dart';
import '../../../../widgets/abilities/ability_expandable_item.dart';

class StoryCareerSection extends ConsumerWidget {
  const StoryCareerSection({
    super.key,
    required this.heroId,
    required this.careerId,
    required this.chosenSkillIds,
    required this.chosenPerkIds,
    required this.incidentName,
    required this.careerLanguageIds,
    required this.primaryLanguageId,
    required this.selectedLanguageIds,
    required this.selectedSkillIds,
    required this.onCareerChanged,
    required this.onCareerLanguageSlotsChanged,
    required this.onCareerLanguageChanged,
    required this.onSkillSelectionChanged,
    required this.onPerkSelectionChanged,
    required this.onIncidentChanged,
    required this.onDirty,
  });

  final String heroId;
  final String? careerId;
  final Set<String> chosenSkillIds;
  final Set<String> chosenPerkIds;
  final String? incidentName;
  final List<String?> careerLanguageIds;
  final String? primaryLanguageId;
  final Set<String> selectedLanguageIds;
  final Set<String> selectedSkillIds;

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
                  heroId: heroId,
                  careers: careers,
                  careerId: careerId,
                  chosenSkillIds: chosenSkillIds,
                  chosenPerkIds: chosenPerkIds,
                  incidentName: incidentName,
                  careerLanguageIds: careerLanguageIds,
                  primaryLanguageId: primaryLanguageId,
                  selectedLanguageIds: selectedLanguageIds,
                  selectedSkillIds: selectedSkillIds,
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
    required this.heroId,
    required this.careers,
    required this.careerId,
    required this.chosenSkillIds,
    required this.chosenPerkIds,
    required this.incidentName,
    required this.careerLanguageIds,
    required this.primaryLanguageId,
    required this.selectedLanguageIds,
    required this.selectedSkillIds,
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

  final String heroId;
  final List<model.Component> careers;
  final String? careerId;
  final Set<String> chosenSkillIds;
  final Set<String> chosenPerkIds;
  final String? incidentName;
  final List<String?> careerLanguageIds;
  final String? primaryLanguageId;
  final Set<String> selectedLanguageIds;
  final Set<String> selectedSkillIds;

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

  List<String> _extractSkillGroups(Map<String, dynamic> data) {
    final results = <String>[];

    void addAll(dynamic value) {
      final parsed = _parseStringList(value);
      if (parsed.isEmpty) return;
      results.addAll(parsed);
    }

    addAll(data['skill_groups']);
    for (final entry in data.entries) {
      final key = entry.key.toString().toLowerCase();
      if (key.startsWith('skill_groups') && key != 'skill_groups') {
        addAll(entry.value);
      }
    }

    return results;
  }

  List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is String) {
      final tokens = value.split(RegExp(r',|/|\bor\b', caseSensitive: false));
      return tokens.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
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
    final skillGroups = _extractSkillGroups(data);
    final normalizedSkillGroups = skillGroups
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
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
        InkWell(
          onTap: () async {
            final options = <_SearchOption<String?>>[
              const _SearchOption<String?>(
                label: '— Choose career —',
                value: null,
              ),
              ..._careers.map(
                (c) => _SearchOption<String?>(
                  label: c.name,
                  value: c.id,
                ),
              ),
            ];
            final result = await _showSearchablePicker<String?>(
              context: context,
              title: 'Select Career',
              options: options,
              selected: widget.careerId,
            );
            if (result == null) return;
            widget.onCareerChanged(result.value);
            widget.onDirty();
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Career',
              prefixIcon: Icon(Icons.work_outline),
              suffixIcon: Icon(Icons.search),
            ),
            child: Text(
              widget.careerId != null
                  ? selectedCareer.name
                  : '— Choose career —',
              style: TextStyle(
                fontSize: 16,
                color: widget.careerId != null
                    ? theme.textTheme.bodyLarge?.color
                    : theme.hintColor,
              ),
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
                if (normalizedSkillGroups.isEmpty) return true;
                final group =
                    skill.data['group']?.toString().trim().toLowerCase();
                final nameKey = skill.name.trim().toLowerCase();
                return normalizedSkillGroups.contains(group) ||
                    normalizedSkillGroups.contains(nameKey);
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

              List<String?> currentSlots() {
                final slots = List<String?>.filled(picksNeeded, null);
                for (var i = 0;
                    i < picksNeeded && i < currentSelections.length;
                    i++) {
                  slots[i] = currentSelections[i];
                }
                return slots;
              }

              void applySelection(int index, String? value) {
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
              }

              List<_SearchOption<String?>> buildSearchOptionsForIndex(
                  int currentIndex, List<String?> slots) {
                final options = <_SearchOption<String?>>[
                  const _SearchOption<String?>(
                    label: '— Choose skill —',
                    value: null,
                  ),
                ];

                final excludedIds = <String>{};
                for (var i = 0; i < slots.length; i++) {
                  if (i == currentIndex) continue;
                  final pick = slots[i];
                  if (pick != null) {
                    excludedIds.add(pick);
                  }
                }

                for (final groupKey in sortedGroups) {
                  for (final skill in grouped[groupKey]!) {
                    final isCurrent = slots[currentIndex] == skill.id;
                    if (!isCurrent && excludedIds.contains(skill.id)) {
                      continue;
                    }
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
                  final isCurrent = slots[currentIndex] == skill.id;
                  if (!isCurrent && excludedIds.contains(skill.id)) {
                    continue;
                  }
                  options.add(
                    _SearchOption<String?>(
                      label: skill.name,
                      value: skill.id,
                      subtitle: 'Other',
                    ),
                  );
                }

                return options;
              }

              Future<void> openSearchForIndex(int index) async {
                final latestSlots = currentSlots();
                final result = await _showSearchablePicker<String?>(
                  context: context,
                  title: 'Select Skill',
                  options: buildSearchOptionsForIndex(index, latestSlots),
                  selected: latestSlots[index],
                );
                if (result == null) return;
                applySelection(index, result.value);
              }

              final accent = Theme.of(context).colorScheme.primary;
              final border = OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: accent.withOpacity(0.6), width: 1.4),
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
                    InkWell(
                      onTap: () => openSearchForIndex(index),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Skill pick ${index + 1}',
                          border: border,
                          enabledBorder: border,
                          suffixIcon: const Icon(Icons.search),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        child: Text(
                          slots[index] != null
                              ? skillMap[slots[index]]!.name
                              : '— Choose skill —',
                          style: TextStyle(
                            fontSize: 16,
                            color: slots[index] != null
                                ? Theme.of(context).textTheme.bodyLarge?.color
                                : Theme.of(context).hintColor,
                          ),
                        ),
                      ),
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

              List<String?> currentSlots() {
                final slots = List<String?>.filled(perksNumber, null);
                for (var i = 0;
                    i < perksNumber && i < currentSelections.length;
                    i++) {
                  slots[i] = currentSelections[i];
                }
                return slots;
              }

              List<_SearchOption<String?>> buildSearchOptionsForPerkIndex(
                  int currentIndex, List<String?> slots) {
                final options = <_SearchOption<String?>>[
                  const _SearchOption<String?>(
                    label: '— Choose perk —',
                    value: null,
                  ),
                ];

                final excludedIds = <String>{};
                for (var i = 0; i < slots.length; i++) {
                  if (i == currentIndex) continue;
                  final pick = slots[i];
                  if (pick != null) {
                    excludedIds.add(pick);
                  }
                }

                for (final key in sortedGroupKeys) {
                  for (final perk in grouped[key]!) {
                    final isCurrent = slots[currentIndex] == perk.id;
                    if (!isCurrent && excludedIds.contains(perk.id)) {
                      continue;
                    }
                    options.add(
                      _SearchOption<String?>(
                        label: perk.name,
                        value: perk.id,
                        subtitle: key,
                      ),
                    );
                  }
                }

                return options;
              }

              Future<void> openSearchForPerkIndex(int index) async {
                final latestSlots = currentSlots();
                final result = await _showSearchablePicker<String?>(
                  context: context,
                  title: 'Select Perk',
                  options: buildSearchOptionsForPerkIndex(index, latestSlots),
                  selected: latestSlots[index],
                );
                if (result == null) return;

                final updated = currentSlots();
                updated[index] = result.value;
                if (result.value != null) {
                  for (var i = 0; i < updated.length; i++) {
                    if (i != index && updated[i] == result.value) {
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
                    InkWell(
                      onTap: () => openSearchForPerkIndex(index),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Perk pick ${index + 1}',
                          border: border,
                          enabledBorder: border,
                          suffixIcon: const Icon(Icons.search),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        child: Text(
                          slots[index] != null
                              ? perkMap[slots[index]]!.name
                              : '— Choose perk —',
                          style: TextStyle(
                            fontSize: 16,
                            color: slots[index] != null
                                ? Theme.of(context).textTheme.bodyLarge?.color
                                : Theme.of(context).hintColor,
                          ),
                        ),
                      ),
                    ),
                    if (slots[index] != null) ...[
                      const SizedBox(height: 6),
                      Builder(
                        builder: (context) {
                          final perk = perkMap[slots[index]]!;
                          final grantsRaw = perk.data['grants'];
                          // Normalize grants to a List (can be Map or List)
                          final grants = grantsRaw is List 
                              ? grantsRaw 
                              : (grantsRaw is Map ? [grantsRaw] : null);
                          
                          return Container(
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
                                  perk.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: borderColor,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  perk.data['description']?.toString() ??
                                      'No description available',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                  ),
                                ),
                                // Display granted abilities if any
                                if (grants != null && grants.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Grants:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: borderColor,
                                    ),
                                  ),
                                  widget.langsAsync.when(
                                    loading: () => const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 8),
                                      child: LinearProgressIndicator(),
                                    ),
                                    error: (e, _) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Text('Failed to load languages: $e'),
                                    ),
                                    data: (languages) => widget.skillsAsync.when(
                                      loading: () => const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 8),
                                        child: LinearProgressIndicator(),
                                      ),
                                      error: (e, _) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: Text('Failed to load skills: $e'),
                                      ),
                                      data: (skills) => _PerkGrantsDisplay(
                                        heroId: widget.heroId,
                                        perkId: perk.id,
                                        grants: grants,
                                        accentColor: borderColor,
                                        languages: languages,
                                        skills: skills,
                                        reservedLanguageIds: widget.selectedLanguageIds,
                                        reservedSkillIds: widget.selectedSkillIds,
                                        onDirty: widget.onDirty,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
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
            InkWell(
              onTap: () async {
                final options = <_SearchOption<String?>>[
                  const _SearchOption<String?>(
                    label: '— Choose incident —',
                    value: null,
                  ),
                  ...incidents.map(
                    (incident) => _SearchOption<String?>(
                      label: incident['name']?.toString() ?? 'Unknown',
                      value: incident['name']?.toString(),
                    ),
                  ),
                ];
                final result = await _showSearchablePicker<String?>(
                  context: context,
                  title: 'Select Inciting Incident',
                  options: options,
                  selected: widget.incidentName,
                );
                if (result == null) return;
                widget.onIncidentChanged(result.value);
                widget.onDirty();
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Inciting Incident',
                  prefixIcon: Icon(Icons.auto_fix_high_outlined),
                  suffixIcon: Icon(Icons.search),
                ),
                child: Text(
                  widget.incidentName ?? '— Choose incident —',
                  style: TextStyle(
                    fontSize: 16,
                    color: widget.incidentName != null
                        ? theme.textTheme.bodyLarge?.color
                        : theme.hintColor,
                  ),
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

    Future<void> openSearch() async {
      final options = <_SearchOption<String?>>[
        const _SearchOption<String?>(
          label: '— Choose language —',
          value: null,
        ),
      ];

      for (final key in ['human', 'ancestral', 'dead']) {
        for (final lang in groups[key]!) {
          final isCurrent = lang.id == validValue;
          if (!isCurrent && exclude.contains(lang.id)) continue;
          options.add(
            _SearchOption<String?>(
              label: lang.name,
              value: lang.id,
              subtitle: _titleForGroup(key),
            ),
          );
        }
      }

      final selected = await _showSearchablePicker<String?>(
        context: context,
        title: label,
        options: options,
        selected: validValue,
      );

      if (selected == null) return;
      onChanged(selected.value);
    }

    return InkWell(
      onTap: openSearch,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          suffixIcon: const Icon(Icons.search),
        ),
        child: Text(
          validValue != null
              ? languages.firstWhere((l) => l.id == validValue).name
              : '— Choose language —',
          style: TextStyle(
            fontSize: 16,
            color: validValue != null
                ? Theme.of(context).textTheme.bodyLarge?.color
                : Theme.of(context).hintColor,
          ),
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
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search...',
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
                            child: Center(child: Text('No matches found')),
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
                      child: const Text('Cancel'),
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

/// A widget that displays the granted abilities for a perk.
/// This is a ConsumerWidget so it can access the abilityByNameProvider.
final _perkGrantChoicesProvider = FutureProvider.family<
    Map<String, List<String>>, ({String heroId, String perkId})>((ref, args) async {
  final db = ref.read(appDatabaseProvider);
  return PerkGrantsService().getAllGrantChoicesForPerk(
    db: db,
    heroId: args.heroId,
    perkId: args.perkId,
  );
});

class _PerkGrantsDisplay extends ConsumerWidget {
  const _PerkGrantsDisplay({
    required this.heroId,
    required this.perkId,
    required this.grants,
    required this.accentColor,
    required this.languages,
    required this.skills,
    required this.reservedLanguageIds,
    required this.reservedSkillIds,
    required this.onDirty,
  });

  final String heroId;
  final String perkId;
  final List<dynamic> grants;
  final Color accentColor;
  final List<model.Component> languages;
  final List<model.Component> skills;
  final Set<String> reservedLanguageIds;
  final Set<String> reservedSkillIds;
  final VoidCallback onDirty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textColor = scheme.onSurface;
    final languageMap = {for (final lang in languages) lang.id: lang};
    final skillMap = {for (final skill in skills) skill.id: skill};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final grant in grants)
          _buildGrantItem(context, ref, grant, textColor, languageMap, skillMap),
      ],
    );
  }

  Widget _buildGrantItem(
    BuildContext context,
    WidgetRef ref,
    dynamic grant,
    Color textColor,
    Map<String, model.Component> languageMap,
    Map<String, model.Component> skillMap,
  ) {
    if (grant is! Map) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text('• ${grant.toString()}', style: TextStyle(fontSize: 12, color: textColor)),
      );
    }

    if (grant.containsKey('ability')) {
      return _buildAbilityGrant(context, ref, grant['ability'] as String?, textColor);
    }

    if (grant.containsKey('languages')) {
      final count = _parseCount(grant['languages']);
      return _buildLanguageGrant(context, ref, count, textColor, languageMap);
    }

    if (grant.containsKey('skill')) {
      final skillData = grant['skill'];
      if (skillData is Map) {
        return _buildSkillGrant(context, ref, Map<String, dynamic>.from(skillData), textColor, skillMap);
      }
    }

    final formatted = grant.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    return _buildGrantRow('• $formatted', textColor);
  }

  Widget _buildAbilityGrant(
    BuildContext context,
    WidgetRef ref,
    String? abilityName,
    Color textColor,
  ) {
    if (abilityName == null || abilityName.isEmpty) {
      return _buildGrantRow('• Ability grant', textColor);
    }

    final abilityAsync = ref.watch(abilityByNameProvider(abilityName));
    return abilityAsync.when(
      data: (ability) {
        if (ability == null) {
          return _buildGrantRow('• Ability: $abilityName', textColor);
        }
        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: AbilityExpandableItem(component: ability),
        );
      },
      loading: () => _buildLoadingRow(textColor, 'Loading $abilityName...'),
      error: (e, _) => _buildGrantRow('• Ability: $abilityName', textColor),
    );
  }

  Widget _buildLanguageGrant(
    BuildContext context,
    WidgetRef ref,
    int count,
    Color textColor,
    Map<String, model.Component> languageMap,
  ) {
    if (heroId.isEmpty) {
      return _buildGrantRow('Choose ${count == 1 ? 'a' : count} new language${count == 1 ? '' : 's'}.', textColor);
    }

    final choicesAsync = ref.watch(_perkGrantChoicesProvider((heroId: heroId, perkId: perkId)));
    return choicesAsync.when(
      data: (choices) {
        final selected = List<String>.from(choices['language'] ?? const []);
        final widgets = <Widget>[];
        for (var index = 0; index < count; index++) {
          final selectedId = index < selected.length ? selected[index] : null;
          final label = count == 1 ? 'Language Choice' : 'Language Choice ${index + 1}';
          widgets.add(
            _buildPickerField(
              context: context,
              label: label,
              placeholder: '— Choose language —',
              selectedName: selectedId != null ? languageMap[selectedId]?.name : null,
              onTap: () => _openLanguagePicker(
                context: context,
                ref: ref,
                slotIndex: index,
                currentChoices: selected,
                currentSelectedId: selectedId,
              ),
            ),
          );
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
      },
      loading: () => _buildLoadingRow(textColor, 'Loading languages...'),
      error: (e, _) => _buildGrantRow('Failed to load languages: $e', textColor),
    );
  }

  Widget _buildSkillGrant(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> skillData,
    Color textColor,
    Map<String, model.Component> skillMap,
  ) {
    final group = (skillData['group'] as String?)?.trim();
    if (group == null || group.isEmpty) {
      return _buildGrantRow('Skill grant available', textColor);
    }

    final countData = skillData['count'];
    if (countData == 'one_owned') {
      return _buildSkillOwnedGrant(context, ref, group, textColor, skillMap);
    }

    final count = _parseCount(countData);
    if (count <= 0) {
      return _buildGrantRow('Choose a ${_capitalize(group)} skill.', textColor);
    }

    return _buildSkillPickGrant(context, ref, group, count, textColor, skillMap);
  }

  Widget _buildSkillOwnedGrant(
    BuildContext context,
    WidgetRef ref,
    String group,
    Color textColor,
    Map<String, model.Component> skillMap,
  ) {
    final normalizedGroup = group.toLowerCase();
    final owned = skills.where((skill) {
      final skillGroup = (skill.data['group'] as String?)?.toLowerCase();
      return skillGroup == normalizedGroup && reservedSkillIds.contains(skill.id);
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (owned.isEmpty) {
      return _buildGrantRow('No ${_capitalize(group)} skills known yet.', textColor);
    }

    final choicesAsync = ref.watch(_perkGrantChoicesProvider((heroId: heroId, perkId: perkId)));
    return choicesAsync.when(
      data: (choices) {
        final selected = List<String>.from(choices['skill_owned'] ?? const []);
        final selectedId = selected.isNotEmpty ? selected.first : null;
        final label = '${_capitalize(group)} Skill';
        return _buildPickerField(
          context: context,
          label: label,
          placeholder: '— Choose skill —',
          selectedName: selectedId != null ? skillMap[selectedId]?.name : null,
          onTap: () => _openSkillPicker(
            context: context,
            ref: ref,
            grantType: 'skill_owned',
            slotIndex: 0,
            currentChoices: selected,
            currentSelectedId: selectedId,
            group: group,
            allowOwnedOnly: true,
          ),
        );
      },
      loading: () => _buildLoadingRow(textColor, 'Loading skills...'),
      error: (e, _) => _buildGrantRow('Failed to load skills: $e', textColor),
    );
  }

  Widget _buildSkillPickGrant(
    BuildContext context,
    WidgetRef ref,
    String group,
    int count,
    Color textColor,
    Map<String, model.Component> skillMap,
  ) {
    final normalizedGroup = group.toLowerCase();
    final available = skills.where((skill) {
      final skillGroup = (skill.data['group'] as String?)?.toLowerCase();
      return skillGroup == normalizedGroup && !reservedSkillIds.contains(skill.id);
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (available.isEmpty) {
      return _buildGrantRow('No ${_capitalize(group)} skills available to learn.', textColor);
    }

    final choicesAsync = ref.watch(_perkGrantChoicesProvider((heroId: heroId, perkId: perkId)));
    return choicesAsync.when(
      data: (choices) {
        final selected = List<String>.from(choices['skill_pick'] ?? const []);
        final widgets = <Widget>[];
        for (var index = 0; index < count; index++) {
          final selectedId = index < selected.length ? selected[index] : null;
          final label = count == 1
              ? 'New ${_capitalize(group)} Skill'
              : 'New ${_capitalize(group)} Skill ${index + 1}';
          widgets.add(
            _buildPickerField(
              context: context,
              label: label,
              placeholder: '— Choose skill —',
              selectedName: selectedId != null ? skillMap[selectedId]?.name : null,
              onTap: () => _openSkillPicker(
                context: context,
                ref: ref,
                grantType: 'skill_pick',
                slotIndex: index,
                currentChoices: selected,
                currentSelectedId: selectedId,
                group: group,
                allowOwnedOnly: false,
              ),
            ),
          );
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
      },
      loading: () => _buildLoadingRow(textColor, 'Loading skills...'),
      error: (e, _) => _buildGrantRow('Failed to load skills: $e', textColor),
    );
  }

  Widget _buildPickerField({
    required BuildContext context,
    required String label,
    required String placeholder,
    required String? selectedName,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final hintColor = theme.hintColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            suffixIcon: const Icon(Icons.search),
          ),
          child: Text(
            selectedName ?? placeholder,
            style: TextStyle(
              fontSize: 14,
              color: selectedName != null ? theme.textTheme.bodyLarge?.color : hintColor,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openLanguagePicker({
    required BuildContext context,
    required WidgetRef ref,
    required int slotIndex,
    required List<String> currentChoices,
    required String? currentSelectedId,
  }) async {
    final exclude = <String>{
      ...reservedLanguageIds.where((id) => id.isNotEmpty),
      ...currentChoices.where((id) => id.isNotEmpty && id != currentSelectedId),
    };
    final options = _buildLanguageOptions(exclude, currentSelectedId);
    final result = await _showSearchablePicker<String?>(
      context: context,
      title: 'Select Language',
      options: options,
      selected: currentSelectedId,
    );
    if (result == null) return;
    final updated = _updatedChoiceList(currentChoices, slotIndex, result.value);
    await _saveGrantChoice(ref, 'language', updated);
  }

  Future<void> _openSkillPicker({
    required BuildContext context,
    required WidgetRef ref,
    required String grantType,
    required int slotIndex,
    required List<String> currentChoices,
    required String? currentSelectedId,
    required String group,
    required bool allowOwnedOnly,
  }) async {
    final exclude = currentChoices
        .where((id) => id.isNotEmpty && id != currentSelectedId)
        .toSet();
    if (!allowOwnedOnly) {
      exclude.addAll(reservedSkillIds);
    }
    final options = _buildSkillOptions(
      group: group,
      allowOwnedOnly: allowOwnedOnly,
      exclude: exclude,
      currentSelectedId: currentSelectedId,
    );
    final result = await _showSearchablePicker<String?>(
      context: context,
      title: 'Select ${_capitalize(group)} Skill',
      options: options,
      selected: currentSelectedId,
    );
    if (result == null) return;
    final updated = _updatedChoiceList(currentChoices, slotIndex, result.value);
    await _saveGrantChoice(ref, grantType, updated);
  }

  List<_SearchOption<String?>> _buildLanguageOptions(Set<String> exclude, String? currentSelectedId) {
    final grouped = <String, List<model.Component>>{};
    for (final lang in languages) {
      final type = (lang.data['language_type'] as String?)?.toLowerCase() ?? 'human';
      grouped.putIfAbsent(type, () => []).add(lang);
    }
    for (final group in grouped.values) {
      group.sort((a, b) => a.name.compareTo(b.name));
    }

    final options = <_SearchOption<String?>>[
      const _SearchOption<String?>(label: '— Choose language —', value: null),
    ];

    for (final entry in grouped.entries) {
      for (final lang in entry.value) {
        if (lang.id != currentSelectedId && exclude.contains(lang.id)) {
          continue;
        }
        options.add(
          _SearchOption<String?>(
            label: lang.name,
            value: lang.id,
            subtitle: _languageGroupTitle(entry.key),
          ),
        );
      }
    }
    return options;
  }

  List<_SearchOption<String?>> _buildSkillOptions({
    required String group,
    required bool allowOwnedOnly,
    required Set<String> exclude,
    required String? currentSelectedId,
  }) {
    final normalizedGroup = group.toLowerCase();
    final source = skills.where((skill) {
      final skillGroup = (skill.data['group'] as String?)?.toLowerCase();
      if (skillGroup != normalizedGroup) return false;
      if (allowOwnedOnly) {
        return reservedSkillIds.contains(skill.id);
      }
      return !reservedSkillIds.contains(skill.id) || skill.id == currentSelectedId;
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final options = <_SearchOption<String?>>[
      const _SearchOption<String?>(label: '— Choose skill —', value: null),
    ];

    for (final skill in source) {
      if (skill.id != currentSelectedId && exclude.contains(skill.id)) continue;
      options.add(_SearchOption<String?>(label: skill.name, value: skill.id));
    }
    return options;
  }

  List<String> _updatedChoiceList(List<String> currentChoices, int slotIndex, String? newValue) {
    final updated = List<String>.from(currentChoices);
    while (updated.length <= slotIndex) {
      updated.add('');
    }
    updated[slotIndex] = newValue?.trim() ?? '';
    return updated.where((value) => value.isNotEmpty).toList();
  }

  Future<void> _saveGrantChoice(
    WidgetRef ref,
    String grantType,
    List<String> chosenIds,
  ) async {
    final db = ref.read(appDatabaseProvider);
    await PerkGrantsService().saveGrantChoiceAndApply(
      db: db,
      heroId: heroId,
      perkId: perkId,
      grantType: grantType,
      chosenIds: chosenIds,
    );
    onDirty();
    ref.invalidate(_perkGrantChoicesProvider((heroId: heroId, perkId: perkId)));
  }

  Widget _buildGrantRow(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: TextStyle(fontSize: 12, color: color)),
    );
  }

  Widget _buildLoadingRow(Color color, String message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: accentColor),
          ),
          const SizedBox(width: 8),
          Text(message, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  int _parseCount(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
    return 0;
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

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }
}
