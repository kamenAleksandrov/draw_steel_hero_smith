import 'package:flutter/material.dart';

import 'package:hero_smith/core/models/feature.dart';
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
    this.classMetadata,
    required this.features,
    required this.featureDetailsById,
    this.selectedOptions = const {},
    this.onSelectionChanged,
    this.domainLinkedFeatureIds = const {},
    this.selectedDomainSlugs = const {},
    this.abilityDetailsById = const {},
    this.abilityIdByName = const {},
    this.activeSubclassSlugs = const {},
    this.subclassLabel,
  });

  final int level;
  final Map<String, dynamic>? classMetadata;
  final List<Feature> features;
  final Map<String, Map<String, dynamic>> featureDetailsById;
  final Map<String, Set<String>> selectedOptions;
  final FeatureSelectionChanged? onSelectionChanged;
  final Set<String> domainLinkedFeatureIds;
  final Set<String> selectedDomainSlugs;
  final Map<String, Map<String, dynamic>> abilityDetailsById;
  final Map<String, String> abilityIdByName;
  final Set<String> activeSubclassSlugs;
  final String? subclassLabel;

  @override
  Widget build(BuildContext context) {
    if (features.isEmpty) {
      return const SizedBox.shrink();
    }

    final grouped = FeatureRepository.groupFeaturesByLevel(features);
    final levels = FeatureRepository.getSortedLevels(grouped);

    final header = _buildHeaderCard(context);
    final children = <Widget>[if (header != null) header];

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

  Widget? _buildHeaderCard(BuildContext context) {
    final theme = Theme.of(context);
    final metadata = classMetadata;
    final title = metadata == null
        ? 'Class Features'
        : (metadata['name']?.toString().trim().isNotEmpty == true
            ? metadata['name'].toString().trim()
            : 'Class Features');

    final subtitleParts = <String>['Level $level'];
    if (subclassLabel != null && subclassLabel!.trim().isNotEmpty) {
      subtitleParts.add(subclassLabel!.trim());
    }
    final subtitle = subtitleParts.join(' · ');

    final domainChips = selectedDomainSlugs
        .map(
          (slug) => _buildTagChip(
            context,
            _humanizeSlug(slug),
            leading: const Icon(Icons.account_tree, size: 16),
          ),
        )
        .toList();
    final metadataSummary = metadata == null
        ? null
        : _buildMetadataSummary(context, metadata);

    if (metadata == null && domainChips.isEmpty) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (domainChips.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: domainChips,
              ),
            ],
            if (metadataSummary != null) ...[
              const SizedBox(height: 12),
              metadataSummary,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataSummary(
    BuildContext context,
    Map<String, dynamic> metadata,
  ) {
    final theme = Theme.of(context);
    final starting = metadata['starting_characteristics'];
    Map<String, dynamic>? startingMap;
    if (starting is Map<String, dynamic>) {
      startingMap = starting;
    } else if (starting is Map) {
      startingMap = starting.cast<String, dynamic>();
    }

    final heroicResource =
        startingMap?['heroicResourceName']?.toString().trim();
    final motto = startingMap?['motto']?.toString().trim();

    final chips = <Widget>[];
    if (heroicResource != null && heroicResource.isNotEmpty) {
      chips.add(
        _buildTagChip(
          context,
          'Heroic Resource: $heroicResource',
          leading: const Icon(Icons.auto_awesome, size: 16),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (chips.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: chips,
          ),
        if (motto != null && motto.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            motto,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
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
    final options = _extractOptions(details);
    final selections = selectedOptions[feature.id] ?? const <String>{};
    final isDomainLinked = domainLinkedFeatureIds.contains(feature.id);

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

    final selectedLabels = <String>[];
    for (final option in options) {
      final key = ClassFeatureDataService.featureOptionKey(option);
      final label = ClassFeatureDataService.featureOptionLabel(option);
      if (selections.contains(key)) {
        selectedLabels.add(label);
      }
    }

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

    if (options.isNotEmpty) {
      children.add(const SizedBox(height: 12));
      children.add(
        _buildOptionsList(
          context,
          feature,
          details,
          options,
          selections,
          isDomainLinked,
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

  Widget _buildOptionsList(
    BuildContext context,
    Feature feature,
    Map<String, dynamic>? details,
    List<Map<String, dynamic>> options,
    Set<String> selections,
    bool isDomainLinked,
  ) {
    final theme = Theme.of(context);
    final allowMultiple =
        _inferAllowMultiple(feature.id, details, selections);
    final canEdit = onSelectionChanged != null &&
        (!isDomainLinked || selectedDomainSlugs.isEmpty);
    final groupValue = allowMultiple || selections.isEmpty
        ? null
        : selections.first;

    final optionTiles = <Widget>[];
    for (final option in options) {
      final key = ClassFeatureDataService.featureOptionKey(option);
      final label = ClassFeatureDataService.featureOptionLabel(option);
      final selected = selections.contains(key);
      final recommended = _optionMatchesActiveSubclass(option);
      final ability = _resolveAbility(option);
      final subtitleWidgets =
          _buildOptionDetails(context, option, ability);

      Widget tile;
      if (allowMultiple) {
        tile = CheckboxListTile(
          value: selected,
          onChanged: canEdit
              ? (value) {
                  final updated = Set<String>.from(selections);
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Options', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Column(children: optionTiles),
        if (isDomainLinked && selectedDomainSlugs.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Selections are managed automatically from your chosen domains.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
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
        details.add(Text('Ability ID: $abilityId', style: theme.textTheme.bodySmall));
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

  String _humanizeSlug(String slug) {
    final tokens = slug
        .split(RegExp(r'[_\-]+'))
        .where((token) => token.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return slug;
    return tokens
        .map((token) => token[0].toUpperCase() + token.substring(1))
        .join(' ');
  }
}
