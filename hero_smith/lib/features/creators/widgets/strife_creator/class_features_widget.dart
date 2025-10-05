import 'package:flutter/material.dart';

import 'package:hero_smith/core/models/feature.dart';
import 'package:hero_smith/core/models/subclass_models.dart';
import 'package:hero_smith/core/repositories/feature_repository.dart';
import 'package:hero_smith/core/services/class_feature_data_service.dart';

typedef FeatureSelectionChanged = void Function(
  String featureId,
  Set<String> selections,
);

class ClassFeaturesWidget extends StatelessWidget {
  const ClassFeaturesWidget({
    super.key,
    required this.level,
    required this.features,
    required this.featureDetailsById,
    this.selectedOptions = const {},
    this.onSelectionChanged,
    this.domainLinkedFeatureIds = const {},
    this.deityLinkedFeatureIds = const {},
    this.selectedDomainSlugs = const {},
    this.selectedDeitySlugs = const {},
    this.abilityDetailsById = const {},
    this.abilityIdByName = const {},
    this.activeSubclassSlugs = const {},
    this.subclassLabel,
    this.subclassSelection,
  });

  final int level;
  final List<Feature> features;
  final Map<String, Map<String, dynamic>> featureDetailsById;
  final Map<String, Set<String>> selectedOptions;
  final FeatureSelectionChanged? onSelectionChanged;
  final Set<String> domainLinkedFeatureIds;
  final Set<String> deityLinkedFeatureIds;
  final Set<String> selectedDomainSlugs;
  final Set<String> selectedDeitySlugs;
  final Map<String, Map<String, dynamic>> abilityDetailsById;
  final Map<String, String> abilityIdByName;
  final Set<String> activeSubclassSlugs;
  final String? subclassLabel;
  final SubclassSelectionResult? subclassSelection;

  static const List<String> _widgetSubclassOptionKeys = [
    'subclass',
    'subclass_name',
    'tradition',
    'order',
    'doctrine',
    'mask',
    'path',
    'circle',
    'college',
    'element',
    'role',
    'discipline',
    'oath',
    'school',
    'guild',
    'domain',
    'name',
  ];

  static const List<String> _widgetDeityOptionKeys = [
    'deity',
    'deity_name',
    'patron',
    'pantheon',
    'god',
  ];

  @override
  Widget build(BuildContext context) {
    if (features.isEmpty) {
      return const SizedBox.shrink();
    }

    final grouped = FeatureRepository.groupFeaturesByLevel(features);
    final levels = FeatureRepository.getSortedLevels(grouped);

    final children = <Widget>[];

    for (final levelNumber in levels) {
      final levelFeatures = grouped[levelNumber];
      if (levelFeatures == null || levelFeatures.isEmpty) {
        continue;
      }
      children.add(_buildLevelSection(context, levelNumber, levelFeatures));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildLevelSection(
    BuildContext context,
    int levelNumber,
    List<Feature> levelFeatures,
  ) {
    final theme = Theme.of(context);
    final children = <Widget>[];
    for (var i = 0; i < levelFeatures.length; i++) {
      children.add(_buildFeatureTile(context, levelFeatures[i]));
      if (i < levelFeatures.length - 1) {
        children.add(const Divider(height: 1));
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('class_features_level_$levelNumber'),
          initiallyExpanded: levelNumber <= level,
          title: Text(
            'Level $levelNumber',
            style: theme.textTheme.titleMedium,
          ),
          childrenPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          children: children,
        ),
      ),
    );
  }

  Widget _buildFeatureTile(BuildContext context, Feature feature) {
    final theme = Theme.of(context);
    final details = featureDetailsById[feature.id];
    final description = _coalesceDescription(feature, details);
    final allOptions = _extractOptions(details);
    final originalSelections = selectedOptions[feature.id] ?? const <String>{};
    final isDomainLinked = domainLinkedFeatureIds.contains(feature.id);
    final isDeityLinked = deityLinkedFeatureIds.contains(feature.id);

    final optionsContext = _prepareFeatureOptions(
      feature: feature,
      allOptions: allOptions,
      currentSelections: originalSelections,
    );

    final tags = <Widget>[];
    if (feature.isSubclassFeature) {
      tags.add(
        _buildTagChip(
          context,
          subclassLabel?.isNotEmpty == true
              ? '${subclassLabel!.trim()} Feature'
              : 'Subclass Feature',
          leading: const Icon(Icons.star, size: 16),
        ),
      );
    }
    if (isDomainLinked) {
      tags.add(
        _buildTagChip(
          context,
          'Domain Linked',
          leading: const Icon(Icons.account_tree, size: 16),
        ),
      );
    }
    if (isDeityLinked) {
      tags.add(
        _buildTagChip(
          context,
          'Deity Linked',
          leading: const Icon(Icons.church, size: 16),
        ),
      );
    }

    final selectedLabels =
        _deriveSelectionLabels(optionsContext.selectedKeys, allOptions);

    final children = <Widget>[
      Text(
        feature.name,
        style: theme.textTheme.titleMedium,
      ),
    ];

    if (tags.isNotEmpty) {
      children.add(const SizedBox(height: 8));
      children.add(
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: tags,
        ),
      );
    }

    if (selectedLabels.isNotEmpty) {
      children.add(const SizedBox(height: 8));
      children.add(
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: selectedLabels
              .map(
                (label) => Chip(
                  label: Text(label),
                  avatar: const Icon(Icons.check, size: 16),
                ),
              )
              .toList(),
        ),
      );
    }

    if (description != null && description.isNotEmpty) {
      children.add(const SizedBox(height: 12));
      children.add(
        Text(
          description,
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    children.addAll(_buildDetailSections(context, details));

    if (allOptions.isNotEmpty || optionsContext.messages.isNotEmpty) {
      children.add(const SizedBox(height: 12));
      children.add(
        _buildOptionsSection(
          context: context,
          feature: feature,
          details: details,
          optionsContext: optionsContext,
          originalSelections: originalSelections,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildOptionsSection({
    required BuildContext context,
    required Feature feature,
    required Map<String, dynamic>? details,
    required _FeatureOptionsContext optionsContext,
    required Set<String> originalSelections,
  }) {
    final theme = Theme.of(context);
    final allowMultiple =
        _inferAllowMultiple(feature.id, details, originalSelections);
    final effectiveSelections = optionsContext.selectedKeys;
    final canEdit = onSelectionChanged != null && optionsContext.allowEditing;
    final groupValue = allowMultiple || effectiveSelections.isEmpty
        ? null
        : effectiveSelections.first;

    final optionTiles = <Widget>[];
    for (final option in optionsContext.options) {
      final key = ClassFeatureDataService.featureOptionKey(option);
      final label = ClassFeatureDataService.featureOptionLabel(option);
      final selected = effectiveSelections.contains(key);
      final recommended = _optionMatchesActiveSubclass(option);
      final ability = _resolveAbility(option);
      final subtitleWidgets = _buildOptionDetails(context, option, ability);

      Widget tile;
      if (allowMultiple) {
        tile = CheckboxListTile(
          value: selected,
          onChanged: canEdit
              ? (value) {
                  final updated = Set<String>.from(effectiveSelections);
                  if (value ?? false) {
                    updated.add(key);
                  } else {
                    updated.remove(key);
                  }
                  onSelectionChanged?.call(feature.id, updated);
                }
              : null,
          title: Text(label),
          subtitle: subtitleWidgets.isEmpty
              ? null
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: _withSpacing(subtitleWidgets),
                ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          controlAffinity: ListTileControlAffinity.leading,
        );
      } else {
        tile = RadioListTile<String>(
          value: key,
          groupValue: selected ? key : groupValue,
          onChanged: canEdit
              ? (value) {
                  if (value == null) {
                    onSelectionChanged?.call(feature.id, <String>{});
                    return;
                  }
                  onSelectionChanged?.call(feature.id, {value});
                }
              : null,
          title: Text(label),
          subtitle: subtitleWidgets.isEmpty
              ? null
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: _withSpacing(subtitleWidgets),
                ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        );
      }

      optionTiles.add(
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: recommended
                ? theme.colorScheme.secondaryContainer.withOpacity(0.35)
                : theme.colorScheme.surfaceVariant.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
            ),
          ),
          child: tile,
        ),
      );
    }

    final content = <Widget>[];

    for (var i = 0; i < optionsContext.messages.length; i++) {
      content.add(_buildInfoMessage(context, optionsContext.messages[i]));
      if (i < optionsContext.messages.length - 1) {
        content.add(const SizedBox(height: 8));
      }
    }

    if (optionTiles.isNotEmpty) {
      if (content.isNotEmpty) {
        content.add(const SizedBox(height: 12));
      }
      content.add(Text('Options', style: theme.textTheme.titleSmall));
      content.add(const SizedBox(height: 8));
      content.add(Column(children: optionTiles));
    }

    if (content.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: content,
    );
  }

  _FeatureOptionsContext _prepareFeatureOptions({
    required Feature feature,
    required List<Map<String, dynamic>> allOptions,
    required Set<String> currentSelections,
  }) {
    var filteredOptions = List<Map<String, dynamic>>.from(allOptions);
    var allowEditing = true;
    final messages = <String>[];
    var requiresExternalSelection = false;

    void applyFilter(_OptionFilterResult result) {
      filteredOptions = result.options;
      allowEditing = allowEditing && result.allowEditing;
      messages.addAll(result.messages);
      requiresExternalSelection =
          requiresExternalSelection || result.requiresExternalSelection;
    }

    if (domainLinkedFeatureIds.contains(feature.id)) {
      final result = _applyDomainFilter(filteredOptions, feature.id);
      applyFilter(result);
      if (filteredOptions.isEmpty && result.requiresExternalSelection) {
        return _FeatureOptionsContext(
          options: filteredOptions,
          selectedKeys: const <String>{},
          allowEditing: false,
          messages: messages,
          requiresExternalSelection: true,
        );
      }
    }

    if (deityLinkedFeatureIds.contains(feature.id)) {
      final result = _applyDeityFilter(filteredOptions);
      applyFilter(result);
      if (filteredOptions.isEmpty && result.requiresExternalSelection) {
        return _FeatureOptionsContext(
          options: filteredOptions,
          selectedKeys: const <String>{},
          allowEditing: false,
          messages: messages,
          requiresExternalSelection: true,
        );
      }
    }

    if (feature.isSubclassFeature) {
      final result = _applySubclassFilter(filteredOptions);
      applyFilter(result);
    }

    final filteredKeys = filteredOptions
        .map((option) => ClassFeatureDataService.featureOptionKey(option))
        .toSet();

    final selectedKeys = currentSelections.where(filteredKeys.contains).toSet();

    return _FeatureOptionsContext(
      options: filteredOptions,
      selectedKeys: selectedKeys,
      allowEditing: allowEditing,
      messages: messages,
      requiresExternalSelection: requiresExternalSelection,
    );
  }

  _OptionFilterResult _applyDomainFilter(
    List<Map<String, dynamic>> currentOptions,
    String featureId,
  ) {
    if (selectedDomainSlugs.isEmpty) {
      return const _OptionFilterResult(
        options: <Map<String, dynamic>>[],
        allowEditing: false,
        messages: ['Choose domains above to unlock this feature.'],
        requiresExternalSelection: true,
      );
    }

    final allowedKeys = ClassFeatureDataService.domainOptionKeysFor(
      featureDetailsById,
      featureId,
      selectedDomainSlugs,
    );

    if (allowedKeys.isEmpty) {
      return const _OptionFilterResult(
        options: <Map<String, dynamic>>[],
        allowEditing: false,
        messages: ['No options match your selected domains.'],
      );
    }

    final filtered = currentOptions
        .where(
          (option) => allowedKeys
              .contains(ClassFeatureDataService.featureOptionKey(option)),
        )
        .toList();

    if (filtered.isEmpty) {
      return const _OptionFilterResult(
        options: <Map<String, dynamic>>[],
        allowEditing: false,
        messages: ['No options match your selected domains.'],
      );
    }

    final allowEditing = selectedDomainSlugs.length > 1 && filtered.length > 1;
    final messages = allowEditing
        ? const <String>[
            'Pick the option that fits your chosen domains.',
          ]
        : const <String>[
            'Automatically applied for your domain.',
          ];

    return _OptionFilterResult(
      options: filtered,
      allowEditing: allowEditing,
      messages: messages,
    );
  }

  _OptionFilterResult _applyDeityFilter(
    List<Map<String, dynamic>> currentOptions,
  ) {
    if (selectedDeitySlugs.isEmpty) {
      return const _OptionFilterResult(
        options: <Map<String, dynamic>>[],
        allowEditing: false,
        messages: ['Choose a deity above to unlock this feature.'],
        requiresExternalSelection: true,
      );
    }

    final filtered = <Map<String, dynamic>>[];
    var hasTaggedOption = false;
    for (final option in currentOptions) {
      final slugs = _optionDeitySlugs(option);
      if (slugs.isEmpty) continue;
      hasTaggedOption = true;
      if (slugs.intersection(selectedDeitySlugs).isNotEmpty) {
        filtered.add(option);
      }
    }

    if (!hasTaggedOption) {
      return _OptionFilterResult(
        options: currentOptions,
        allowEditing: true,
      );
    }

    if (filtered.isEmpty) {
      return const _OptionFilterResult(
        options: <Map<String, dynamic>>[],
        allowEditing: false,
        messages: ['No options match your chosen deity.'],
      );
    }

    final allowEditing = filtered.length > 1;
    final deityName = subclassSelection?.deityName?.trim();
    final message = allowEditing
        ? 'Pick the option that matches your deity.'
        : (deityName == null || deityName.isEmpty
            ? 'Automatically applied for your deity.'
            : 'Automatically applied for $deityName.');

    return _OptionFilterResult(
      options: filtered,
      allowEditing: allowEditing,
      messages: message == null ? const [] : <String>[message],
    );
  }

  _OptionFilterResult _applySubclassFilter(
    List<Map<String, dynamic>> currentOptions,
  ) {
    if (activeSubclassSlugs.isEmpty) {
      return const _OptionFilterResult(
        options: <Map<String, dynamic>>[],
        allowEditing: false,
        messages: ['Choose a subclass above to unlock this feature.'],
        requiresExternalSelection: true,
      );
    }

    final filtered = <Map<String, dynamic>>[];
    var hasTaggedOption = false;
    for (final option in currentOptions) {
      final slugs = _optionSubclassSlugs(option);
      if (slugs.isEmpty) continue;
      hasTaggedOption = true;
      if (slugs.intersection(activeSubclassSlugs).isNotEmpty) {
        filtered.add(option);
      }
    }

    if (!hasTaggedOption) {
      return _OptionFilterResult(
        options: currentOptions,
        allowEditing: true,
      );
    }

    if (filtered.isEmpty) {
      return const _OptionFilterResult(
        options: <Map<String, dynamic>>[],
        allowEditing: false,
        messages: ['No options match your selected subclass.'],
      );
    }

    final allowEditing = filtered.length > 1;
    final subclassName = subclassSelection?.subclassName?.trim();
    final message = allowEditing
        ? 'Pick the option that fits your subclass.'
        : (subclassName == null || subclassName.isEmpty
            ? 'Automatically applied for your subclass.'
            : 'Automatically applied for $subclassName.');

    return _OptionFilterResult(
      options: filtered,
      allowEditing: allowEditing,
      messages: message == null ? const [] : <String>[message],
    );
  }

  List<String> _deriveSelectionLabels(
    Set<String> selectedKeys,
    List<Map<String, dynamic>> allOptions,
  ) {
    if (selectedKeys.isEmpty) {
      return const [];
    }

    final labels = <String>[];
    for (final option in allOptions) {
      final key = ClassFeatureDataService.featureOptionKey(option);
      if (!selectedKeys.contains(key)) continue;
      labels.add(ClassFeatureDataService.featureOptionLabel(option));
    }
    return labels;
  }

  Widget _buildInfoMessage(BuildContext context, String message) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Set<String> _optionSubclassSlugs(Map<String, dynamic> option) {
    return _extractOptionSlugs(option, _widgetSubclassOptionKeys);
  }

  Set<String> _optionDeitySlugs(Map<String, dynamic> option) {
    return _extractOptionSlugs(option, _widgetDeityOptionKeys);
  }

  Set<String> _extractOptionSlugs(
    Map<String, dynamic> option,
    List<String> keys,
  ) {
    final slugs = <String>{};
    for (final key in keys) {
      final value = option[key];
      if (value == null) continue;
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) continue;
        slugs.addAll(ClassFeatureDataService.slugVariants(trimmed));
      } else if (value is List) {
        for (final entry in value.whereType<String>()) {
          final trimmed = entry.trim();
          if (trimmed.isEmpty) continue;
          slugs.addAll(ClassFeatureDataService.slugVariants(trimmed));
        }
      }
    }
    return slugs;
  }

  List<Widget> _buildDetailSections(
    BuildContext context,
    Map<String, dynamic>? details,
  ) {
    if (details == null || details.isEmpty) {
      return const [];
    }

    final sections = <Widget>[];
    void addSection(String title, dynamic value) {
      if (value == null) return;
      String? content;
      if (value is String) {
        content = value.trim();
      } else if (value is Map<String, dynamic>) {
        final name = value['name']?.toString().trim();
        final description = value['description']?.toString().trim();
        final pieces = <String>[];
        if (name != null && name.isNotEmpty) pieces.add(name);
        if (description != null && description.isNotEmpty) {
          pieces.add(description);
        }
        content = pieces.join('\n\n');
      }
      if (content == null || content.isEmpty) return;
      sections.add(const SizedBox(height: 12));
      sections.add(_buildDetailBlock(context, title, content));
    }

    addSection('In Combat', details['in_combat']);
    addSection('Out of Combat', details['out_of_combat']);
    addSection('Special', details['special']);
    addSection('Notes', details['notes']);

    return sections;
  }

  Widget _buildDetailBlock(BuildContext context, String title, String content) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(
            content,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _extractOptions(Map<String, dynamic>? details) {
    final raw = details?['options'];
    if (raw is! List) return const [];
    final options = <Map<String, dynamic>>[];
    for (final entry in raw) {
      if (entry is Map<String, dynamic>) {
        options.add(entry);
      } else if (entry is Map) {
        options.add(entry.cast<String, dynamic>());
      }
    }
    return options;
  }

  bool _inferAllowMultiple(
    String featureId,
    Map<String, dynamic>? details,
    Set<String> selections,
  ) {
    if (domainLinkedFeatureIds.contains(featureId)) {
      return true;
    }
    if (selections.length > 1) {
      return true;
    }
    final allowMultiple = details?['allow_multiple'];
    if (allowMultiple is bool) {
      return allowMultiple;
    }
    final maxSel = details?['max_selections'] ?? details?['select_count'];
    if (maxSel is num) {
      return maxSel > 1;
    }
    return false;
  }

  List<Widget> _buildOptionDetails(
    BuildContext context,
    Map<String, dynamic> option,
    Map<String, dynamic>? ability,
  ) {
    final theme = Theme.of(context);
    final details = <Widget>[];

    final description = option['description']?.toString().trim();
    if (description != null && description.isNotEmpty) {
      details.add(Text(description, style: theme.textTheme.bodyMedium));
    }

    final benefit = option['benefit']?.toString().trim();
    if (benefit != null && benefit.isNotEmpty) {
      details.add(Text(benefit, style: theme.textTheme.bodyMedium));
    }

    final skill = option['skill']?.toString().trim();
    final skillGroup = option['skill_group']?.toString().trim();
    final domainName = option['domain']?.toString().trim();
    final chips = <Widget>[];
    if (skill != null && skill.isNotEmpty) {
      chips.add(_buildTagChip(context, 'Skill: $skill'));
    }
    if (skillGroup != null && skillGroup.isNotEmpty) {
      chips.add(_buildTagChip(context, 'Skill Group: $skillGroup'));
    }
    if (domainName != null && domainName.isNotEmpty) {
      chips.add(
        _buildTagChip(
          context,
          domainName,
          leading: const Icon(Icons.account_tree, size: 16),
        ),
      );
    }
    if (chips.isNotEmpty) {
      details.add(
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: chips,
        ),
      );
    }

    final nestedFeatures = option['features'];
    if (nestedFeatures is List) {
      final featureWidgets = <Widget>[];
      for (final entry in nestedFeatures) {
        if (entry is! Map) continue;
        final map = entry.cast<String, dynamic>();
        final name = map['name']?.toString().trim();
        final desc = map['description']?.toString().trim();
        if (name == null || name.isEmpty) continue;
        featureWidgets.add(
          Text(
            '• $name',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        );
        if (desc != null && desc.isNotEmpty) {
          featureWidgets.add(
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4, bottom: 8),
              child: Text(desc, style: theme.textTheme.bodyMedium),
            ),
          );
        }
      }
      if (featureWidgets.isNotEmpty) {
        details.add(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: featureWidgets,
          ),
        );
      }
    }

    final story = option['story']?.toString().trim();
    if (story != null && story.isNotEmpty) {
      details.add(
        Text(
          story,
          style: theme.textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    if (ability != null) {
      details.add(_buildAbilityPreview(context, ability));
    } else {
      final abilityName = option['ability']?.toString().trim();
      if (abilityName != null && abilityName.isNotEmpty) {
        details.add(Text('Ability: $abilityName'));
      }
      final abilityId = option['ability_id']?.toString().trim();
      if (abilityId != null && abilityId.isNotEmpty) {
        details.add(
            Text('Ability ID: $abilityId', style: theme.textTheme.bodySmall));
      }
    }

    return details;
  }

  Map<String, dynamic>? _resolveAbility(Map<String, dynamic> option) {
    String? id = option['ability_id']?.toString().trim();
    if (id != null && id.isNotEmpty) {
      final ability = abilityDetailsById[id];
      if (ability != null) return ability;
      final slugId = ClassFeatureDataService.slugify(id);
      final slugAbility = abilityDetailsById[slugId];
      if (slugAbility != null) return slugAbility;
    }

    final abilityName = option['ability']?.toString().trim();
    if (abilityName != null && abilityName.isNotEmpty) {
      final slug = ClassFeatureDataService.slugify(abilityName);
      final resolvedId = abilityIdByName[slug] ?? slug;
      final ability = abilityDetailsById[resolvedId];
      if (ability != null) return ability;
    }
    return null;
  }

  Widget _buildAbilityPreview(
    BuildContext context,
    Map<String, dynamic> ability,
  ) {
    final theme = Theme.of(context);
    final name = ability['name']?.toString().trim();
    final actionType = ability['action_type']?.toString().trim();
    final targets = ability['targets']?.toString().trim();
    final effect = ability['effect']?.toString().trim();
    final story = ability['story_text']?.toString().trim();

    String? range;
    final rangeValue = ability['range'];
    if (rangeValue is Map) {
      final map = rangeValue.cast<String, dynamic>();
      final pieces = <String>[];
      final distance = map['distance']?.toString().trim();
      final area = map['area']?.toString().trim();
      if (distance != null && distance.isNotEmpty) pieces.add(distance);
      if (area != null && area.isNotEmpty) pieces.add(area);
      if (pieces.isNotEmpty) {
        range = pieces.join(' · ');
      }
    } else if (rangeValue != null) {
      range = rangeValue.toString();
    }

    final keywords = ability['keywords'] is List
        ? ability['keywords']
            .whereType<String>()
            .map((keyword) => keyword.trim())
            .where((keyword) => keyword.isNotEmpty)
            .toList()
        : const <String>[];

    final costs = ability['costs'];
    String? costDescription;
    if (costs is Map) {
      final map = costs.cast<String, dynamic>();
      final signature = map['signature'] == true ? 'Signature' : null;
      final resource = map['resource']?.toString().trim();
      final amount = map['amount'];
      final pieces = <String>[];
      if (signature != null) pieces.add(signature);
      if (resource != null && resource.isNotEmpty) {
        if (amount is num) {
          pieces.add('$amount $resource');
        } else {
          pieces.add(resource);
        }
      }
      if (pieces.isNotEmpty) {
        costDescription = pieces.join(' · ');
      }
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name?.isNotEmpty == true
                ? name!
                : (ability['resolved_id']?.toString() ?? 'Ability'),
            style: theme.textTheme.titleSmall,
          ),
          if (keywords.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: keywords
                  .map(
                    (keyword) => Chip(
                      label: Text(keyword),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ],
          if (actionType != null && actionType.isNotEmpty)
            Text('Action: $actionType', style: theme.textTheme.bodySmall),
          if (range != null && range.isNotEmpty)
            Text('Range: $range', style: theme.textTheme.bodySmall),
          if (targets != null && targets.isNotEmpty)
            Text('Targets: $targets', style: theme.textTheme.bodySmall),
          if (costDescription != null && costDescription.isNotEmpty)
            Text('Cost: $costDescription', style: theme.textTheme.bodySmall),
          if (effect != null && effect.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(effect, style: theme.textTheme.bodyMedium),
          ],
          if (story != null && story.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              story,
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _optionMatchesActiveSubclass(Map<String, dynamic> option) {
    if (activeSubclassSlugs.isEmpty) return false;
    const keysToCheck = [
      'subclass',
      'subclass_name',
      'tradition',
      'order',
      'doctrine',
      'mask',
      'path',
      'circle',
      'college',
      'element',
      'role',
      'discipline',
      'oath',
      'school',
      'guild',
      'domain',
      'name',
    ];
    for (final key in keysToCheck) {
      final value = option[key]?.toString().trim();
      if (value == null || value.isEmpty) continue;
      final variants = ClassFeatureDataService.slugVariants(value);
      if (variants.intersection(activeSubclassSlugs).isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  Widget _buildTagChip(
    BuildContext context,
    String label, {
    Widget? leading,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            leading,
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _withSpacing(List<Widget> widgets) {
    if (widgets.isEmpty) return widgets;
    final spaced = <Widget>[];
    for (var i = 0; i < widgets.length; i++) {
      spaced.add(widgets[i]);
      if (i < widgets.length - 1) {
        spaced.add(const SizedBox(height: 8));
      }
    }
    return spaced;
  }

  String? _coalesceDescription(Feature feature, Map<String, dynamic>? details) {
    final detailDescription = details?['description'];
    final fromDetails = _normalizeText(detailDescription);
    if (fromDetails != null && fromDetails.isNotEmpty) {
      return fromDetails;
    }
    return _normalizeText(feature.description);
  }

  String? _normalizeText(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is List) {
      final parts = value
          .whereType<String>()
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();
      if (parts.isEmpty) return null;
      return parts.join('\n\n');
    }
    return value.toString();
  }
}

class _FeatureOptionsContext {
  const _FeatureOptionsContext({
    required this.options,
    required this.selectedKeys,
    required this.allowEditing,
    required this.messages,
    required this.requiresExternalSelection,
  });

  final List<Map<String, dynamic>> options;
  final Set<String> selectedKeys;
  final bool allowEditing;
  final List<String> messages;
  final bool requiresExternalSelection;
}

class _OptionFilterResult {
  const _OptionFilterResult({
    required this.options,
    required this.allowEditing,
    this.messages = const [],
    this.requiresExternalSelection = false,
  });

  final List<Map<String, dynamic>> options;
  final bool allowEditing;
  final List<String> messages;
  final bool requiresExternalSelection;
}
