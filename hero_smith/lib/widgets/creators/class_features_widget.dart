import 'package:flutter/material.dart';

import '../../core/models/feature.dart';
import '../../core/theme/strife_theme.dart';

class ClassFeaturesWidget extends StatelessWidget {
  const ClassFeaturesWidget({
    super.key,
    required this.level,
    required this.classMetadata,
    required this.features,
    required this.featureDetailsById,
    required this.selectedOptions,
    required this.onSelectionChanged,
    this.domainLinkedFeatureIds = const {},
    this.selectedDomainSlugs = const {},
    this.abilityDetailsById = const {},
    this.abilityIdByName = const {},
    this.onAbilityPreviewRequested,
    this.activeSubclassSlugs = const {},
    this.subclassLabel,
    this.wrapWithCard = true,
  });

  final int level;
  final Map<String, dynamic>? classMetadata;
  final List<Feature> features;
  final Map<String, Map<String, dynamic>> featureDetailsById;
  final Map<String, Set<String>> selectedOptions;
  final void Function(String featureId, Set<String> selections)
      onSelectionChanged;
  final Set<String> domainLinkedFeatureIds;
  final Set<String> selectedDomainSlugs;
  final Map<String, Map<String, dynamic>> abilityDetailsById;
  final Map<String, String> abilityIdByName;
  final void Function(Map<String, dynamic> ability)? onAbilityPreviewRequested;
  final Set<String> activeSubclassSlugs;
  final String? subclassLabel;
  final bool wrapWithCard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final levelGroups = _buildLevelGroups();
    if (levelGroups.isEmpty) {
      return const SizedBox.shrink();
    }

    final summary = _FeatureSummary(levelGroups: levelGroups);
    final picksFilledText = summary.totalRequiredPicks > 0
        ? '${summary.completedPicks} of ${summary.totalRequiredPicks} feature pick${summary.totalRequiredPicks == 1 ? '' : 's'} filled'
        : 'All feature selections are automatic at level $level';

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          picksFilledText,
          style: theme.textTheme.bodyMedium,
        ),
        if (summary.lockedSubclassPicks > 0) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.lock, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  summary.lockedSubclassPicks == 1
                      ? '1 subclass-dependent choice shown below.'
                      : '${summary.lockedSubclassPicks} subclass-dependent choices shown below.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        ..._buildLevelSections(theme, levelGroups),
      ],
    );

    if (!wrapWithCard) {
      return body;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: StrifeTheme.cardElevation,
        shape: const RoundedRectangleBorder(
          borderRadius: StrifeTheme.cardRadius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StrifeTheme.sectionHeader(
              context,
              title: 'Level features',
              subtitle: 'Review class features unlocked up to level $level.',
              icon: Icons.military_tech,
              accent: StrifeTheme.featuresAccent,
            ),
            Padding(
              padding: StrifeTheme.cardPadding,
              child: body,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLevelSections(
    ThemeData theme,
    List<_FeatureLevelGroup> levelGroups,
  ) {
    return levelGroups
        .map(
          (group) => Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: ValueKey('feature_level_${group.level}'),
              title: Text('Level ${group.level}'),
              subtitle: Text(
                '${group.configs.length} feature${group.configs.length == 1 ? '' : 's'}',
                style: theme.textTheme.bodySmall,
              ),
              initiallyExpanded: group.level == levelGroups.first.level,
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              maintainState: true,
              children: group.configs
                  .map((config) => _buildFeatureCard(theme, config))
                  .toList(),
            ),
          ),
        )
        .toList();
  }

  Widget _buildFeatureCard(ThemeData theme, _FeatureConfig config) {
    final accent = config.feature.isSubclassFeature
        ? theme.colorScheme.tertiary
        : StrifeTheme.featuresAccent;
    final subtitle =
        config.feature.isSubclassFeature && config.feature.subclassName != null
            ? 'Subclass: ${config.feature.subclassName}'
            : null;

    final details = config.details;
    final description =
        (details?['description'] ?? config.feature.description)?.toString();
    final sections = _extractAdditionalSections(details);

    final children = <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              config.feature.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ),
          if (config.feature.isSubclassFeature)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: accent.withValues(alpha: 0.16),
                border: Border.all(color: accent.withValues(alpha: 0.32)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Subclass',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
      if (description != null && description.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(
          description,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    ];

    final selectionInfo = config.selectionInfo;
    if (selectionInfo != null) {
      children
        ..add(const SizedBox(height: 12))
        ..add(_buildSelectionSection(theme, config, selectionInfo));
    }

    if (sections.isNotEmpty) {
      children
        ..add(const SizedBox(height: 12))
        ..addAll(sections);
    }

    final directAbilityName = details?['ability']?.toString();
    final directAbility = directAbilityName == null
        ? null
        : _resolveAbilityByName(directAbilityName);
    final directAbilityLabel = directAbilityName?.trim();
    if (directAbility != null && onAbilityPreviewRequested != null) {
      children
        ..add(const SizedBox(height: 12))
        ..add(
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => onAbilityPreviewRequested!(directAbility),
              icon: const Icon(Icons.menu_book_outlined),
              label: Text(
                directAbilityLabel == null || directAbilityLabel.isEmpty
                    ? 'View ability'
                    : 'View $directAbilityLabel',
              ),
            ),
          ),
        );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: accent.withValues(alpha: 0.08),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildSelectionSection(
    ThemeData theme,
    _FeatureConfig config,
    _FeatureSelectionInfo selectionInfo,
  ) {
    if (selectionInfo.subclassLocked) {
      final resolved = _resolveSubclassOption(selectionInfo.options);
      if (resolved == null) {
        return Text(
          'Choose a subclass to finalize this feature option.',
          style: theme.textTheme.bodySmall,
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOptionSummary(theme, resolved, selected: true, locked: true),
          const SizedBox(height: 8),
          Text(
            subclassLabel == null
                ? 'Subclass-dependent feature.'
                : 'Locked to $subclassLabel.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      );
    }

    if (selectionInfo.options.isEmpty) {
      final message = selectionInfo.restrictionMessage ??
          (selectionInfo.domainRestricted
              ? 'Select a domain above to view available options.'
              : 'No choices required. This feature is granted automatically.');
      return Text(
        message,
        style: theme.textTheme.bodySmall,
      );
    }

    final selected = selectionInfo.selected;
    final maxSelections = selectionInfo.count;
    final domainNotice = selectionInfo.domainRestricted
        ? Text(
            'Options limited by your chosen domains.',
            style: theme.textTheme.bodySmall,
          )
        : null;

    if (maxSelections <= 1) {
      final items = <DropdownMenuItem<String?>>[
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('— Choose option —'),
        ),
        ...selectionInfo.options.map(
          (option) => DropdownMenuItem<String?>(
            value: option.key,
            child: Text(option.label),
          ),
        ),
      ];

      final selectedKey = selected.isEmpty ? null : selected.first;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (domainNotice != null) ...[
            domainNotice,
            const SizedBox(height: 8),
          ],
          DropdownButtonFormField<String?>(
            value: selectedKey,
            items: items,
            onChanged: (value) => _handleSingleSelection(
              config.feature.id,
              value,
            ),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.check_circle_outlined),
              labelText: 'Choose one option',
            ),
          ),
          const SizedBox(height: 12),
          ...selectionInfo.options.map(
            (option) => _buildOptionSummary(
              theme,
              option,
              selected: option.key == selectedKey,
            ),
          ),
        ],
      );
    }

    final remaining = maxSelections - selected.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (domainNotice != null) ...[
          domainNotice,
          const SizedBox(height: 8),
        ],
        Text(
          'Select up to $maxSelections option${maxSelections == 1 ? '' : 's'}.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: selectionInfo.options.map((option) {
            final isSelected = selected.contains(option.key);
            return FilterChip(
              label: Text(option.label),
              selected: isSelected,
              onSelected: (value) => _handleMultiSelection(
                config.feature.id,
                option.key,
                value,
                selectionInfo,
              ),
            );
          }).toList(),
        ),
        if (remaining > 0) ...[
          const SizedBox(height: 8),
          Text(
            '$remaining pick${remaining == 1 ? '' : 's'} remaining.',
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 12),
        ...selectionInfo.options.map(
          (option) => _buildOptionSummary(
            theme,
            option,
            selected: selected.contains(option.key),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionSummary(
    ThemeData theme,
    _FeatureOption option, {
    required bool selected,
    bool locked = false,
  }) {
    final abilityDetails =
        option.abilityId == null ? null : abilityDetailsById[option.abilityId!];

    final chips = <Widget>[];
    if (option.domain != null) {
      chips.add(_buildSmallChip(theme, Icons.public, option.domain!));
    }
    if (option.skill != null) {
      chips.add(_buildSmallChip(theme, Icons.psychology, option.skill!));
    }
    if (option.skillGroup != null) {
      chips
          .add(_buildSmallChip(theme, Icons.folder_shared, option.skillGroup!));
    }
    final rows = <Widget>[
      Row(
        children: [
          Icon(
            locked
                ? Icons.lock
                : selected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
            size: 18,
            color: selected
                ? StrifeTheme.featuresAccent
                : theme.colorScheme.outline,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              option.label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ];

    if (option.description != null && option.description!.isNotEmpty) {
      rows
        ..add(const SizedBox(height: 6))
        ..add(Text(option.description!, style: theme.textTheme.bodySmall));
    }

    if (option.benefit != null && option.benefit!.isNotEmpty) {
      rows
        ..add(const SizedBox(height: 8))
        ..add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.star, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  option.benefit!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        );
    }

    if (chips.isNotEmpty) {
      rows
        ..add(const SizedBox(height: 8))
        ..add(Wrap(
          spacing: 8,
          runSpacing: 6,
          children: chips,
        ));
    }

    if (option.abilityName != null &&
        abilityDetails != null &&
        onAbilityPreviewRequested != null) {
      rows
        ..add(const SizedBox(height: 8))
        ..add(
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => onAbilityPreviewRequested!(abilityDetails),
              icon: const Icon(Icons.menu_book_outlined),
              label: Text('View ${option.abilityName!.trim()}'),
            ),
          ),
        );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: selected
            ? StrifeTheme.featuresAccent.withValues(alpha: 0.12)
            : theme.colorScheme.surfaceVariant.withValues(alpha: 0.2),
        border: Border.all(
          color: selected
              ? StrifeTheme.featuresAccent.withValues(alpha: 0.35)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }

  Widget _buildSmallChip(ThemeData theme, IconData icon, String label) {
    return Chip(
      label: Text(label),
      avatar: Icon(icon, size: 16),
      side: BorderSide(color: theme.colorScheme.outlineVariant),
      backgroundColor: theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
    );
  }

  List<Widget> _extractAdditionalSections(Map<String, dynamic>? details) {
    if (details == null) return const [];
    final sections = <Widget>[];
    void addSection(String title, dynamic value) {
      if (value is Map<String, dynamic>) {
        final description = value['description']?.toString();
        if (description != null && description.trim().isNotEmpty) {
          sections.add(_FeatureNarrativeSection(
            title: value['name']?.toString() ?? title,
            description: description,
          ));
        }
      }
    }

    addSection('In combat', details['in_combat']);
    addSection('Out of combat', details['out_of_combat']);
    addSection('Montage', details['montage']);
    addSection('Downtime', details['downtime']);

    return sections;
  }

  Map<String, dynamic>? _resolveAbilityByName(String abilityName) {
    final slug = _slugify(abilityName);
    final id = abilityIdByName[slug];
    if (id == null) return null;
    return abilityDetailsById[id];
  }

  _FeatureOption? _resolveSubclassOption(List<_FeatureOption> options) {
    if (activeSubclassSlugs.isEmpty) return null;
    for (final option in options) {
      final matchValue = option.orderName ?? option.label;
      final keySlugs = _slugVariants(matchValue);
      if (keySlugs.any(activeSubclassSlugs.contains)) {
        return option;
      }
    }
    return null;
  }

  void _handleSingleSelection(String featureId, String? selectedKey) {
    final selections = <String>{};
    if (selectedKey != null && selectedKey.isNotEmpty) {
      selections.add(selectedKey);
    }
    onSelectionChanged(featureId, selections);
  }

  void _handleMultiSelection(
    String featureId,
    String optionKey,
    bool isSelected,
    _FeatureSelectionInfo info,
  ) {
    final current = <String>{...info.selected};
    if (isSelected) {
      if (current.length >= info.count) return;
      current.add(optionKey);
    } else {
      current.remove(optionKey);
    }
    onSelectionChanged(featureId, current);
  }

  List<_FeatureLevelGroup> _buildLevelGroups() {
    final groups = <_FeatureLevelGroup>[];
    final entriesByLevel = _metadataEntriesByLevel();

    final featuresByLevel = <int, List<Feature>>{};
    for (final feature in features) {
      if (feature.level > level) continue;
      featuresByLevel.putIfAbsent(feature.level, () => <Feature>[])
        ..add(feature);
    }

    final sortedLevels = featuresByLevel.keys.toList()..sort();
    for (final levelNumber in sortedLevels) {
      final levelFeatures = featuresByLevel[levelNumber]!
        ..sort(
          (a, b) => a.name.compareTo(b.name),
        );
      final configs = levelFeatures
          .map(
            (feature) => _FeatureConfig(
              feature: feature,
              details: featureDetailsById[feature.id],
              selectionInfo: _buildSelectionInfo(
                feature,
                entriesByLevel[levelNumber] ?? const <Map<String, dynamic>>[],
              ),
            ),
          )
          .toList();
      groups.add(_FeatureLevelGroup(level: levelNumber, configs: configs));
    }

    return groups;
  }

  _FeatureSelectionInfo? _buildSelectionInfo(
    Feature feature,
    List<Map<String, dynamic>> metadataEntries,
  ) {
    final details = featureDetailsById[feature.id];
    final options = _extractOptions(details);
    final isDomainLinked = domainLinkedFeatureIds.contains(feature.id);

    List<_FeatureOption> filteredOptions = options;
    bool domainRestricted = false;
    String? restrictionMessage;

    if (isDomainLinked) {
      domainRestricted = true;
      if (selectedDomainSlugs.isEmpty) {
        filteredOptions = const <_FeatureOption>[];
        restrictionMessage =
            'Select at least one domain above to unlock this feature option.';
      } else {
        filteredOptions = options.where((option) {
          final domain = option.domain;
          if (domain == null || domain.trim().isEmpty) return false;
          final slug = _slugify(domain);
          return selectedDomainSlugs.contains(slug);
        }).toList();
        if (filteredOptions.isEmpty) {
          restrictionMessage =
              'Your current domains do not grant this feature option.';
        }
      }
    }

    if (filteredOptions.isEmpty) {
      if (!domainRestricted) {
        return null;
      }
    }

    final metadataEntry = metadataEntries.firstWhere(
      (entry) =>
          entry['name']?.toString().trim().toLowerCase() ==
          feature.name.trim().toLowerCase(),
      orElse: () => const {},
    );

    var count = 1;
    var subclassLocked = false;
    if (metadataEntry.isNotEmpty) {
      final typeValue = metadataEntry['type']?.toString().toLowerCase() ?? '';
      final parsedCount = _parsePickCount(typeValue);
      if (parsedCount != null) {
        count = parsedCount;
      }
      if (typeValue.contains('subclass')) {
        subclassLocked = true;
      }
    }

    if (!subclassLocked && options.any((option) => option.orderName != null)) {
      subclassLocked = true;
    }

    if (filteredOptions.isNotEmpty && count > filteredOptions.length) {
      count = filteredOptions.length;
    }

    final optionKeys = filteredOptions.map((option) => option.key).toSet();
    final selected = selectedOptions[feature.id] ?? const <String>{};
    final filteredSelected =
        selected.where((key) => optionKeys.contains(key)).toSet();

    return _FeatureSelectionInfo(
      count: count,
      options: filteredOptions,
      selected: filteredSelected,
      subclassLocked: subclassLocked,
      domainRestricted: domainRestricted,
      restrictionMessage: restrictionMessage,
    );
  }

  Map<int, List<Map<String, dynamic>>> _metadataEntriesByLevel() {
    final start = classMetadata?['starting_characteristics'];
    if (start is! Map<String, dynamic>) {
      return const <int, List<Map<String, dynamic>>>{};
    }
    final levels = start['levels'];
    if (levels is! List) {
      return const <int, List<Map<String, dynamic>>>{};
    }

    final result = <int, List<Map<String, dynamic>>>{};
    for (final entry in levels) {
      if (entry is! Map<String, dynamic>) continue;
      final levelNumber = (entry['level'] as num?)?.toInt();
      if (levelNumber == null || levelNumber > level) continue;
      final featureEntries = entry['features'];
      if (featureEntries is! List) continue;
      final list = <Map<String, dynamic>>[];
      for (final feature in featureEntries) {
        if (feature is Map<String, dynamic>) {
          list.add(feature);
        }
      }
      result[levelNumber] = list;
    }
    return result;
  }

  List<_FeatureOption> _extractOptions(Map<String, dynamic>? details) {
    if (details == null) return const [];
    final rawOptions = details['options'];
    if (rawOptions is! List) return const [];

    final result = <_FeatureOption>[];
    for (final entry in rawOptions) {
      if (entry is! Map<String, dynamic>) continue;
      final rawOrder = entry['order']?.toString().trim();
      final label = (rawOrder != null && rawOrder.isNotEmpty)
          ? rawOrder
          : _resolveOptionLabel(entry);
      final key = _slugify(label);
      String? abilityName;
      if (entry['ability'] != null && entry['ability'].toString().isNotEmpty) {
        abilityName = entry['ability'].toString();
      }
      final abilityId =
          abilityName == null ? null : abilityIdByName[_slugify(abilityName)];
      final benefit = entry['benefit']?.toString();
      result.add(
        _FeatureOption(
          key: key,
          label: label,
          description: entry['description']?.toString(),
          abilityName: abilityName,
          abilityId: abilityId,
          skill: entry['skill']?.toString(),
          skillGroup: entry['skill_group']?.toString(),
          domain: entry['domain']?.toString(),
          benefit: benefit?.trim(),
          orderName: rawOrder?.isNotEmpty == true ? rawOrder : null,
        ),
      );
    }

    result.sort((a, b) => a.label.compareTo(b.label));
    return result;
  }

  String _resolveOptionLabel(Map<String, dynamic> entry) {
    for (final key in ['name', 'title', 'domain']) {
      final value = entry[key]?.toString();
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    if (entry['skill'] != null) {
      return entry['skill'].toString();
    }
    if (entry['benefit'] != null) {
      return entry['benefit'].toString();
    }
    return 'Option';
  }

  int? _parsePickCount(String type) {
    final match = RegExp(r'pick\s+(\d+)').firstMatch(type);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  String _slugify(String value) {
    final normalized =
        value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final collapsed = normalized.replaceAll(RegExp(r'_+'), '_');
    return collapsed.replaceAll(RegExp(r'^_|_$'), '');
  }

  Set<String> _slugVariants(String value) {
    final base = _slugify(value);
    if (base.isEmpty) return const <String>{};
    final tokens = base
        .split('_')
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) return {base};
    final variants = <String>{base};

    final stopWords = {'the', 'of'};
    final trimmedAll =
        tokens.where((token) => !stopWords.contains(token)).join('_');
    if (trimmedAll.isNotEmpty) variants.add(trimmedAll);

    for (var i = 1; i < tokens.length; i++) {
      final suffix = tokens.sublist(i).join('_');
      if (suffix.isNotEmpty) variants.add(suffix);

      final trimmedSuffix = tokens
          .sublist(i)
          .where((token) => !stopWords.contains(token))
          .join('_');
      if (trimmedSuffix.isNotEmpty) variants.add(trimmedSuffix);
    }

    return variants;
  }
}

class _FeatureLevelGroup {
  _FeatureLevelGroup({
    required this.level,
    required this.configs,
  });

  final int level;
  final List<_FeatureConfig> configs;
}

class _FeatureConfig {
  _FeatureConfig({
    required this.feature,
    this.details,
    this.selectionInfo,
  });

  final Feature feature;
  final Map<String, dynamic>? details;
  final _FeatureSelectionInfo? selectionInfo;
}

class _FeatureSelectionInfo {
  _FeatureSelectionInfo({
    required this.count,
    required this.options,
    required this.selected,
    required this.subclassLocked,
    required this.domainRestricted,
    this.restrictionMessage,
  });

  final int count;
  final List<_FeatureOption> options;
  final Set<String> selected;
  final bool subclassLocked;
  final bool domainRestricted;
  final String? restrictionMessage;
}

class _FeatureOption {
  _FeatureOption({
    required this.key,
    required this.label,
    this.description,
    this.abilityName,
    this.abilityId,
    this.skill,
    this.skillGroup,
    this.domain,
    this.benefit,
    this.orderName,
  });

  final String key;
  final String label;
  final String? description;
  final String? abilityName;
  final String? abilityId;
  final String? skill;
  final String? skillGroup;
  final String? domain;
  final String? benefit;
  final String? orderName;
}

class _FeatureSummary {
  _FeatureSummary({required this.levelGroups});

  final List<_FeatureLevelGroup> levelGroups;

  int get totalRequiredPicks => levelGroups
      .map((group) => group.configs)
      .expand((configs) => configs)
      .map((config) => config.selectionInfo)
      .whereType<_FeatureSelectionInfo>()
      .where((info) => !info.subclassLocked)
      .fold<int>(0, (sum, info) => sum + info.count);

  int get lockedSubclassPicks => levelGroups
      .map((group) => group.configs)
      .expand((configs) => configs)
      .map((config) => config.selectionInfo)
      .whereType<_FeatureSelectionInfo>()
      .where((info) => info.subclassLocked)
      .length;

  int get completedPicks => levelGroups
      .map((group) => group.configs)
      .expand((configs) => configs)
      .map((config) => config.selectionInfo)
      .whereType<_FeatureSelectionInfo>()
      .where((info) => !info.subclassLocked)
      .fold<int>(
        0,
        (sum, info) => sum + info.selected.length.clamp(0, info.count),
      );
}

class _FeatureNarrativeSection extends StatelessWidget {
  const _FeatureNarrativeSection({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.25),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
