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

        // Info messages
        for (final message in optionsContext.messages)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _InfoMessage(message: message),
          ),

        // For grants: display all matching as auto-applied content
        if (isGrantsFeature && optionsContext.options.isNotEmpty) ...[
          Text(
            'Granted Features',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          ...optionsContext.options.map((option) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _AutoAppliedContent(option: option, widget: widget),
          )),
        ]
        // For options: use existing behavior
        else if (isAutoApplied && optionsContext.options.isNotEmpty)
          _AutoAppliedContent(option: optionsContext.options.first, widget: widget)
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
    if (selectionLimit == 1) return 'Choose One';
    if (selectionLimit == 2) return 'Choose Two';
    if (selectionLimit > 1 && selectionLimit < 99) {
      return 'Select up to $selectionLimit';
    }
    return 'Select Options';
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
                  'Selection Required',
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

    if (selectionLimit == 1) return 'Choose one option below';
    if (selectionLimit == 2) {
      return requiredCount >= 2
          ? 'Choose two options below'
          : 'Choose up to two options below';
    }

    if (selectionLimit > 1 && selectionLimit < 99) {
      if (requiredCount >= selectionLimit) {
        return 'Choose $selectionLimit options below';
      }
      return 'Choose up to $selectionLimit options below';
    }

    return 'Choose one or more options below';
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
  const _AutoAppliedContent({required this.option, required this.widget});

  final Map<String, dynamic> option;
  final ClassFeaturesWidget widget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final description = option['description']?.toString().trim();
    final ability = _resolveAbility();

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
                'Automatically Applied',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          if (description?.isNotEmpty ?? false) ...[
            const SizedBox(height: 10),
            Text(
              description!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (ability != null) ...[
            const SizedBox(height: 12),
            AbilityExpandableItem(
              component: _abilityMapToComponent(ability),
            ),
          ],
        ],
      ),
    );
  }

  Map<String, dynamic>? _resolveAbility() {
    String? id = option['ability_id']?.toString().trim();
    if (id != null && id.isNotEmpty) {
      final ability = widget.abilityDetailsById[id];
      if (ability != null) return ability;
      final slugId = ClassFeatureDataService.slugify(id);
      final slugAbility = widget.abilityDetailsById[slugId];
      if (slugAbility != null) return slugAbility;
    }

    final abilityName = option['ability']?.toString().trim();
    if (abilityName != null && abilityName.isNotEmpty) {
      final slug = ClassFeatureDataService.slugify(abilityName);
      final resolvedId = widget.abilityIdByName[slug] ?? slug;
      return widget.abilityDetailsById[resolvedId];
    }
    return null;
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
    final description = widget.option['description']?.toString().trim();
    final ability = _resolveAbility();
    final hasDetails = (description?.isNotEmpty ?? false) || ability != null;

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
              bottom: _isExpanded ? Radius.zero : const Radius.circular(12),
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
                              'Matches your subclass',
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
                      tooltip: _isExpanded ? 'Collapse' : 'Expand',
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
                              if (description?.isNotEmpty ?? false) ...[
                                Text(
                                  description!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.5,
                                  ),
                                ),
                                if (ability != null) const SizedBox(height: 12),
                              ],
                              if (ability != null)
                                AbilityExpandableItem(
                                  component: _abilityMapToComponent(ability),
                                ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ),
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

  Map<String, dynamic>? _resolveAbility() {
    String? id = widget.option['ability_id']?.toString().trim();
    if (id != null && id.isNotEmpty) {
      final ability = widget.widget.abilityDetailsById[id];
      if (ability != null) return ability;
      final slugId = ClassFeatureDataService.slugify(id);
      final slugAbility = widget.widget.abilityDetailsById[slugId];
      if (slugAbility != null) return slugAbility;
    }

    final abilityName = widget.option['ability']?.toString().trim();
    if (abilityName != null && abilityName.isNotEmpty) {
      final slug = ClassFeatureDataService.slugify(abilityName);
      final resolvedId = widget.widget.abilityIdByName[slug] ?? slug;
      return widget.widget.abilityDetailsById[resolvedId];
    }
    return null;
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
