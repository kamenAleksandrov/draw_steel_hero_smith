part of 'class_features_widget.dart';

class _OptionsSection extends StatelessWidget {
  const _OptionsSection({
    required this.feature,
    required this.details,
    required this.optionsContext,
    required this.originalSelections,
    required this.widget,
    this.isGrantsFeature = false,
  });

  final Feature feature;
  final Map<String, dynamic>? details;
  final _FeatureOptionsContext optionsContext;
  final Set<String> originalSelections;
  final ClassFeaturesWidget widget;
  
  /// If true, this feature uses 'grants' instead of 'options'.
  /// All matching grants should be auto-displayed (no user choice needed).
  final bool isGrantsFeature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selectionLimit = optionsContext.selectionLimit;
    final minimumRequired = optionsContext.minimumRequired;
    final allowMultiple = selectionLimit != 1;
    final effectiveSelections = optionsContext.selectedKeys;
    final canEdit = widget.onSelectionChanged != null && optionsContext.allowEditing && !isGrantsFeature;
    final isAutoApplied = _isAutoAppliedSelection();

    final grantType = widget.grantTypeByFeatureName[feature.name.toLowerCase().trim()] ?? '';
    final isPickFeature = grantType == 'pick';
    final hasOptions = optionsContext.options.isNotEmpty;
    // For grants, we don't need user selection - they're all auto-applied
    final needsSelection = !isGrantsFeature && isPickFeature && hasOptions &&
        effectiveSelections.length < (minimumRequired <= 0 ? 1 : minimumRequired);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Selection prompt for pick features (not for grants) - animated to prevent layout jumps
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: (needsSelection && !isAutoApplied)
                ? _SelectionPrompt(
                    selectionLimit: selectionLimit,
                    minimumRequired: minimumRequired,
                  )
                : const SizedBox.shrink(),
          ),
        ),

        // Info messages (skip "Pick" messages for grants features since they're auto-applied)
        for (final message in optionsContext.messages)
          if (!isGrantsFeature || !message.toLowerCase().contains('pick'))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _InfoMessage(message: message),
            ),

        // For grants: display all matching as auto-applied content
        if (isGrantsFeature && optionsContext.options.isNotEmpty) ...[
          Text(
            OptionsSectionText.grantedFeaturesTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          ...optionsContext.options.map((option) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _AutoAppliedContent(
              option: option,
              widget: widget,
              featureId: feature.id,
            ),
          )),
        ]
        // For options: use existing behavior
        else if (isAutoApplied && optionsContext.options.isNotEmpty)
          _AutoAppliedContent(
            option: optionsContext.options.first,
            widget: widget,
            featureId: feature.id,
          )
        else if (optionsContext.options.isNotEmpty) ...[
          Text(
            _headingText(selectionLimit),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          ...optionsContext.options.map((option) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _OptionTile(
                  key: ValueKey(ClassFeatureDataService.featureOptionKey(option)),
                  option: option,
                  feature: feature,
                  isSelected: effectiveSelections
                      .contains(ClassFeatureDataService.featureOptionKey(option)),
                  isRecommended: _optionMatchesActiveSubclass(option),
                  allowMultiple: allowMultiple,
                  canEdit: canEdit,
                  needsSelection: needsSelection,
                  onChanged: (selected) => _handleOptionChanged(option, selected),
                  widget: widget,
                ),
              )),
        ],
      ],
    );
  }

  String _headingText(int selectionLimit) {
    if (selectionLimit == 1) return OptionsSectionText.chooseOneHeading;
    if (selectionLimit == 2) return OptionsSectionText.chooseTwoHeading;
    if (selectionLimit > 1 && selectionLimit < 99) {
      return '${OptionsSectionText.selectUpToPrefix}$selectionLimit';
    }
    return OptionsSectionText.selectOptionsHeading;
  }

  bool _isAutoAppliedSelection() {
    if (optionsContext.allowEditing) return false;
    if (optionsContext.requiresExternalSelection) return false;
    if (optionsContext.options.length != 1) return false;
    return true;
  }

  bool _optionMatchesActiveSubclass(Map<String, dynamic> option) {
    if (widget.activeSubclassSlugs.isEmpty) return false;
    for (final key in ClassFeaturesWidget._widgetSubclassOptionKeys) {
      final value = option[key]?.toString().trim();
      if (value == null || value.isEmpty) continue;
      final variants = ClassFeatureDataService.slugVariants(value);
      if (variants.intersection(widget.activeSubclassSlugs).isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  void _handleOptionChanged(Map<String, dynamic> option, bool selected) {
    if (widget.onSelectionChanged == null) return;
    final key = ClassFeatureDataService.featureOptionKey(option);
    final updated = Set<String>.from(optionsContext.selectedKeys);

    final selectionLimit = optionsContext.selectionLimit;

    if (selectionLimit != 1) {
      if (selected) {
        updated.add(key);
        if (selectionLimit > 0 && updated.length > selectionLimit) {
          for (final opt in optionsContext.options) {
            final optKey = ClassFeatureDataService.featureOptionKey(opt);
            if (optKey == key) continue;
            if (updated.contains(optKey)) {
              updated.remove(optKey);
              break;
            }
          }
        }
      } else {
        updated.remove(key);
      }
    } else {
      updated.clear();
      if (selected) updated.add(key);
    }

    final clamped = ClassFeatureDataService.clampSelectionKeys(
      updated,
      details,
    );

    widget.onSelectionChanged!(feature.id, clamped);
  }
}

class _SelectionPrompt extends StatelessWidget {
  const _SelectionPrompt({
    required this.selectionLimit,
    required this.minimumRequired,
  });

  final int selectionLimit;
  final int minimumRequired;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.touch_app_rounded, color: Colors.orange, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  OptionsSectionText.selectionRequiredTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _promptText(),
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _promptText() {
    final requiredCount = minimumRequired <= 0 ? 1 : minimumRequired;

    if (selectionLimit == 1) return OptionsSectionText.promptChooseOne;
    if (selectionLimit == 2) {
      return requiredCount >= 2
          ? OptionsSectionText.promptChooseTwo
          : OptionsSectionText.promptChooseUpToTwo;
    }

    if (selectionLimit > 1 && selectionLimit < 99) {
      if (requiredCount >= selectionLimit) {
        return '${OptionsSectionText.promptChooseCountPrefix}$selectionLimit${OptionsSectionText.promptChooseCountSuffix}';
      }
      return '${OptionsSectionText.promptChooseUpToPrefix}$selectionLimit${OptionsSectionText.promptChooseUpToSuffix}';
    }

    return OptionsSectionText.promptChooseOneOrMore;
  }
}

class _InfoMessage extends StatelessWidget {
  const _InfoMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AutoAppliedContent extends StatelessWidget {
  const _AutoAppliedContent({
    required this.option,
    required this.widget,
    required this.featureId,
  });

  final Map<String, dynamic> option;
  final ClassFeaturesWidget widget;
  final String featureId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final abilities = _resolveAbilities();
    final textSections = _extractOptionTextSections(option);
    final skillGroup = option['skill_group']?.toString().trim();
    final hasSkillGroup = skillGroup != null && skillGroup.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, size: 18, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                OptionsSectionText.autoAppliedLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          if (textSections.isNotEmpty) ...[
            const SizedBox(height: 10),
            _OptionTextContent(
              sections: textSections,
              textColor: scheme.onSurfaceVariant,
              titleColor: scheme.primary,
            ),
          ],
          if (abilities.isNotEmpty) ...[
            for (final ability in abilities) ...[
              const SizedBox(height: 12),
              AbilityExpandableItem(
                component: _abilityMapToComponent(ability),
              ),
            ],
          ],
          // Skill group picker section
          if (hasSkillGroup) ...[
            const SizedBox(height: 12),
            _SkillGroupPicker(
              option: option,
              featureId: featureId,
              featuresWidget: widget,
            ),
          ],
        ],
      ),
    );
  }

  /// Resolves abilities from the option - handles both single ability strings
  /// and arrays of ability names (e.g., ["Moonlight Sonata", "Radical Fantasia"])
  List<Map<String, dynamic>> _resolveAbilities() {
    final abilities = <Map<String, dynamic>>[];
    
    // Check for ability_id first (single ID)
    String? id = option['ability_id']?.toString().trim();
    if (id != null && id.isNotEmpty) {
      final ability = widget.abilityDetailsById[id];
      if (ability != null) {
        abilities.add(ability);
        return abilities;
      }
      final slugId = ClassFeatureDataService.slugify(id);
      final slugAbility = widget.abilityDetailsById[slugId];
      if (slugAbility != null) {
        abilities.add(slugAbility);
        return abilities;
      }
    }

    // Check for ability field - can be a string or a list
    final abilityField = option['ability'];
    if (abilityField == null) return abilities;
    
    // Handle array of ability names
    if (abilityField is List) {
      for (final item in abilityField) {
        final abilityName = item?.toString().trim();
        if (abilityName != null && abilityName.isNotEmpty) {
          final resolved = _resolveAbilityByName(abilityName);
          if (resolved != null) {
            abilities.add(resolved);
          }
        }
      }
      return abilities;
    }
    
    // Handle single ability name string
    final abilityName = abilityField.toString().trim();
    if (abilityName.isNotEmpty) {
      final resolved = _resolveAbilityByName(abilityName);
      if (resolved != null) {
        abilities.add(resolved);
      }
    }
    
    return abilities;
  }
  
  Map<String, dynamic>? _resolveAbilityByName(String abilityName) {
    final slug = ClassFeatureDataService.slugify(abilityName);
    final resolvedId = widget.abilityIdByName[slug] ?? slug;
    return widget.abilityDetailsById[resolvedId];
  }

  Component _abilityMapToComponent(Map<String, dynamic> abilityData) {
    return Component(
      id: abilityData['id']?.toString() ?? abilityData['resolved_id']?.toString() ?? '',
      type: abilityData['type']?.toString() ?? 'ability',
      name: abilityData['name']?.toString() ?? '',
      data: abilityData,
      source: 'seed',
    );
  }
}

class _SkillGroupPicker extends StatefulWidget {
  const _SkillGroupPicker({
    required this.option,
    required this.featureId,
    required this.featuresWidget,
  });

  final Map<String, dynamic> option;
  final String featureId;
  final ClassFeaturesWidget featuresWidget;

  @override
  State<_SkillGroupPicker> createState() => _SkillGroupPickerState();
}

class _SkillGroupPickerState extends State<_SkillGroupPicker> {
  final SkillDataService _skillDataService = SkillDataService();
  List<SkillOption>? _allSkills;
  bool _isLoadingSkills = false;

  @override
  void initState() {
    super.initState();
    _loadSkillsIfNeeded();
  }

  void _loadSkillsIfNeeded() async {
    final skillGroup = widget.option['skill_group']?.toString().trim();
    if (skillGroup == null || skillGroup.isEmpty) return;

    setState(() {
      _isLoadingSkills = true;
    });

    try {
      final skills = await _skillDataService.loadSkills();
      if (mounted) {
        setState(() {
          _allSkills = skills;
          _isLoadingSkills = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingSkills = false;
        });
      }
    }
  }

  String get _grantKey => ClassFeatureDataService.optionGrantKey(widget.option);

  String? _getCurrentSkillId() {
    final featureSelections =
        widget.featuresWidget.skillGroupSelections[widget.featureId];
    if (featureSelections == null) return null;
    return featureSelections[_grantKey];
  }

  List<SkillOption> _getFilteredSkills() {
    if (_allSkills == null) return [];

    final skillGroup = widget.option['skill_group']?.toString().trim();
    if (skillGroup == null || skillGroup.isEmpty) return [];

    final normalizedGroup = skillGroup.toLowerCase();
    final currentSkillId = _getCurrentSkillId();

    final excludedIds = <String>{
      ...widget.featuresWidget.reservedSkillIds,
    };

    for (final entry in widget.featuresWidget.skillGroupSelections.entries) {
      for (final skillEntry in entry.value.entries) {
        if (entry.key == widget.featureId && skillEntry.key == _grantKey) {
          continue;
        }
        if (skillEntry.value.isNotEmpty) {
          excludedIds.add(skillEntry.value);
        }
      }
    }

    return _allSkills!.where((skill) {
      if (skill.group.toLowerCase() != normalizedGroup) return false;
      if (ComponentSelectionGuard.isBlocked(
        skill.id,
        excludedIds,
        currentId: currentSkillId,
      )) {
        return false;
      }
      return true;
    }).toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> _showSkillPicker() async {
    final filteredSkills = _getFilteredSkills();
    final currentSkillId = _getCurrentSkillId();

    final options = <_SearchOption<String?>>[
      const _SearchOption<String?>(
        label: OptionsSectionText.chooseSkillOption,
        value: null,
      ),
      ...filteredSkills.map(
        (skill) => _SearchOption<String?>(
          label: skill.name,
          value: skill.id,
          subtitle: skill.group,
        ),
      ),
    ];

    final result = await _showSearchablePicker<String?>(
      context: context,
      title: OptionsSectionText.selectSkillTitle,
      options: options,
      selected: currentSkillId,
    );

    if (result == null) return;

    widget.featuresWidget.onSkillGroupSelectionChanged?.call(
      widget.featureId,
      _grantKey,
      result.value,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final skillGroup = widget.option['skill_group']?.toString().trim();
    if (skillGroup == null || skillGroup.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentSkillId = _getCurrentSkillId();
    final hasCallback = widget.featuresWidget.onSkillGroupSelectionChanged != null;
    final needsSelection = currentSkillId == null || currentSkillId.isEmpty;

    String? currentSkillName;
    if (currentSkillId != null && _allSkills != null) {
      final skill = _allSkills!.firstWhere(
        (s) => s.id == currentSkillId,
        orElse: () => SkillOption(id: '', name: '', group: '', description: ''),
      );
      if (skill.id.isNotEmpty) {
        currentSkillName = skill.name;
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: needsSelection
            ? Colors.orange.withValues(alpha: 0.1)
            : scheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: needsSelection
              ? Colors.orange.withValues(alpha: 0.4)
              : scheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.psychology_alt,
                size: 18,
                color: needsSelection ? Colors.orange : scheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${OptionsSectionText.skillFromGroupPrefix}$skillGroup',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color:
                        needsSelection ? Colors.orange.shade700 : scheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isLoadingSkills)
            const LinearProgressIndicator()
          else if (hasCallback)
            InkWell(
              onTap: _showSkillPicker,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: OptionsSectionText.chooseSkillLabel,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: const Icon(Icons.search),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  fillColor: scheme.surface,
                  filled: true,
                ),
                child: Text(
                  currentSkillName ?? OptionsSectionText.selectSkillPlaceholder,
                  style: TextStyle(
                    fontSize: 16,
                    color: currentSkillName != null
                        ? theme.textTheme.bodyLarge?.color
                        : theme.hintColor,
                  ),
                ),
              ),
            )
          else
            Text(
              currentSkillName ?? OptionsSectionText.noSkillSelected,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontStyle: currentSkillName == null ? FontStyle.italic : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _OptionTextSection {
  const _OptionTextSection({this.title, required this.text});

  final String? title;
  final String text;
}

String? _normalizeOptionText(dynamic value) {
  if (value == null) return null;
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (value is List) {
    final parts = value
        .whereType<String>()
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts.join('\n\n');
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

List<_OptionTextSection> _extractOptionTextSections(
  Map<String, dynamic> option,
) {
  final sections = <_OptionTextSection>[];
  final description = _normalizeOptionText(option['description']);
  if (description != null) {
    sections.add(_OptionTextSection(text: description));
  }
  final piety = _normalizeOptionText(option['piety']);
  if (piety != null) {
    sections.add(_OptionTextSection(
      title: OptionsSectionText.pietyTitle,
      text: piety,
    ));
  }
  final prayerEffect =
      _normalizeOptionText(option['prayer_effect'] ?? option['prayerEffect']);
  if (prayerEffect != null) {
    sections.add(_OptionTextSection(
      title: OptionsSectionText.prayerEffectTitle,
      text: prayerEffect,
    ));
  }
  return sections;
}

class _OptionTextContent extends StatelessWidget {
  const _OptionTextContent({
    required this.sections,
    required this.textColor,
    this.titleColor,
    this.spacing = 8,
  });

  final List<_OptionTextSection> sections;
  final Color textColor;
  final Color? titleColor;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: titleColor ?? textColor,
      fontWeight: FontWeight.w600,
    );
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      color: textColor,
      height: 1.5,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) SizedBox(height: spacing),
          if (sections[i].title != null) ...[
            Text(sections[i].title!, style: labelStyle),
            const SizedBox(height: 4),
          ],
          Text(sections[i].text, style: bodyStyle),
        ],
      ],
    );
  }
}

/// Searchable picker dialog for skill selection
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
                        hintText: OptionsSectionText.searchHint,
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
                                child: Text(OptionsSectionText.noMatchesFound)),
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
                      child: const Text(OptionsSectionText.cancelLabel),
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

class _OptionTile extends StatefulWidget {
  const _OptionTile({
    super.key,
    required this.option,
    required this.feature,
    required this.isSelected,
    required this.isRecommended,
    required this.allowMultiple,
    required this.canEdit,
    required this.needsSelection,
    required this.onChanged,
    required this.widget,
  });

  final Map<String, dynamic> option;
  final Feature feature;
  final bool isSelected;
  final bool isRecommended;
  final bool allowMultiple;
  final bool canEdit;
  final bool needsSelection;
  final ValueChanged<bool> onChanged;
  final ClassFeaturesWidget widget;

  @override
  State<_OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<_OptionTile>
    with AutomaticKeepAliveClientMixin {
  bool _isExpanded = false;
  bool _initialized = false;

  @override
  bool get wantKeepAlive => true;

  String get _storageKey => 'option_tile_expanded_${widget.feature.id}_${ClassFeatureDataService.featureOptionKey(widget.option)}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final bucket = PageStorage.of(context);
      final stored = bucket.readState(context, identifier: _storageKey);
      if (stored is bool) {
        _isExpanded = stored;
      }
    }
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      PageStorage.of(context).writeState(context, _isExpanded, identifier: _storageKey);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = ClassFeatureDataService.featureOptionLabel(widget.option);
    final abilities = _resolveAbilities();
    final textSections = _extractOptionTextSections(widget.option);
    final skillGroup = widget.option['skill_group']?.toString().trim();
    final showSkillPicker =
        widget.isSelected && skillGroup != null && skillGroup.isNotEmpty;
    final hasDetails = textSections.isNotEmpty || abilities.isNotEmpty;
    final hasExtraContent = _isExpanded || showSkillPicker;

    Color borderColor;
    Color bgColor;
    if (widget.isSelected) {
      borderColor = scheme.primary;
      bgColor = scheme.primary.withValues(alpha: 0.08);
    } else if (widget.needsSelection) {
      borderColor = Colors.orange.withValues(alpha: 0.5);
      bgColor = Colors.orange.withValues(alpha: 0.04);
    } else if (widget.isRecommended) {
      borderColor = scheme.secondary.withValues(alpha: 0.5);
      bgColor = scheme.secondary.withValues(alpha: 0.05);
    } else {
      borderColor = scheme.outlineVariant.withValues(alpha: 0.5);
      bgColor = scheme.surfaceContainerLow;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: bgColor,
        border: Border.all(
          color: borderColor,
          width: widget.isSelected ? 2 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main tile
          InkWell(
            onTap: widget.canEdit ? () => widget.onChanged(!widget.isSelected) : null,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(12),
              bottom: hasExtraContent ? Radius.zero : const Radius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Selection indicator
                  if (widget.allowMultiple)
                    _buildCheckbox(context)
                  else
                    _buildRadio(context),
                  const SizedBox(width: 14),
                  // Label
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: widget.isSelected
                                ? scheme.primary
                                : scheme.onSurface,
                          ),
                        ),
                        if (widget.isRecommended && !widget.isSelected)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              OptionsSectionText.matchesSubclassLabel,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.secondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Expand button
                  if (hasDetails)
                    IconButton(
                      icon: AnimatedRotation(
                        turns: _isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      onPressed: _toggleExpanded,
                      visualDensity: VisualDensity.compact,
                      tooltip: _isExpanded
                          ? OptionsSectionText.collapseTooltip
                          : OptionsSectionText.expandTooltip,
                    ),
                ],
              ),
            ),
          ),
          // Expanded details with animated size
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: (_isExpanded && hasDetails)
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(height: 1, color: borderColor.withValues(alpha: 0.3)),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (textSections.isNotEmpty) ...[
                                _OptionTextContent(
                                  sections: textSections,
                                  textColor: scheme.onSurfaceVariant,
                                  titleColor: scheme.primary,
                                ),
                                if (abilities.isNotEmpty) const SizedBox(height: 12),
                              ],
                              for (int i = 0; i < abilities.length; i++) ...[
                                if (i > 0) const SizedBox(height: 8),
                                AbilityExpandableItem(
                                  component: _abilityMapToComponent(abilities[i]),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          if (showSkillPicker) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_isExpanded && textSections.isNotEmpty) ...[
                    _OptionTextContent(
                      sections: textSections,
                      textColor: scheme.onSurfaceVariant,
                      titleColor: scheme.primary,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _SkillGroupPicker(
                    option: widget.option,
                    featureId: widget.feature.id,
                    featuresWidget: widget.widget,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCheckbox(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: widget.isSelected
            ? scheme.primary
            : Colors.transparent,
        border: Border.all(
          color: widget.isSelected
              ? scheme.primary
              : scheme.outline.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: widget.isSelected
          ? const Icon(Icons.check, size: 18, color: Colors.white)
          : null,
    );
  }

  Widget _buildRadio(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.transparent,
        border: Border.all(
          color: widget.isSelected
              ? scheme.primary
              : scheme.outline.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: widget.isSelected
          ? Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary,
                ),
              ),
            )
          : null,
    );
  }

  /// Resolves abilities from the option - handles both single ability strings
  /// and arrays of ability names (e.g., ["Moonlight Sonata", "Radical Fantasia"])
  List<Map<String, dynamic>> _resolveAbilities() {
    final abilities = <Map<String, dynamic>>[];
    
    // Check for ability_id first (single ID)
    String? id = widget.option['ability_id']?.toString().trim();
    if (id != null && id.isNotEmpty) {
      final ability = widget.widget.abilityDetailsById[id];
      if (ability != null) {
        abilities.add(ability);
        return abilities;
      }
      final slugId = ClassFeatureDataService.slugify(id);
      final slugAbility = widget.widget.abilityDetailsById[slugId];
      if (slugAbility != null) {
        abilities.add(slugAbility);
        return abilities;
      }
    }

    // Check for ability field - can be a string or a list
    final abilityField = widget.option['ability'];
    if (abilityField == null) return abilities;
    
    // Handle array of ability names
    if (abilityField is List) {
      for (final item in abilityField) {
        final abilityName = item?.toString().trim();
        if (abilityName != null && abilityName.isNotEmpty) {
          final resolved = _resolveAbilityByName(abilityName);
          if (resolved != null) {
            abilities.add(resolved);
          }
        }
      }
      return abilities;
    }
    
    // Handle single ability name string
    final abilityName = abilityField.toString().trim();
    if (abilityName.isNotEmpty) {
      final resolved = _resolveAbilityByName(abilityName);
      if (resolved != null) {
        abilities.add(resolved);
      }
    }
    
    return abilities;
  }
  
  Map<String, dynamic>? _resolveAbilityByName(String abilityName) {
    final slug = ClassFeatureDataService.slugify(abilityName);
    final resolvedId = widget.widget.abilityIdByName[slug] ?? slug;
    return widget.widget.abilityDetailsById[resolvedId];
  }

  Component _abilityMapToComponent(Map<String, dynamic> abilityData) {
    return Component(
      id: abilityData['id']?.toString() ?? abilityData['resolved_id']?.toString() ?? '',
      type: abilityData['type']?.toString() ?? 'ability',
      name: abilityData['name']?.toString() ?? '',
      data: abilityData,
      source: 'seed',
    );
  }
}
