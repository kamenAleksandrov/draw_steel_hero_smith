import 'package:flutter/material.dart';

import '../../core/models/component.dart';
import '../../core/theme/strife_theme.dart';
import '../deities/deity_card.dart';

class DeityDomainPickerCard extends StatefulWidget {
  const DeityDomainPickerCard({
    super.key,
    required this.deities,
    required this.selectedDeityId,
    required this.selectedDomainSlugs,
    required this.requiredDeityCount,
    required this.requiredDomainCount,
    required this.domainNameBySlug,
    required this.domainSlugsByDeityId,
    required this.availableDomainSlugs,
    required this.onDeityChanged,
    required this.onDomainChanged,
    this.selectedDomainName,
    this.selectedDomainSkills = const {},
    this.onDomainSkillChanged,
    this.domainFeatureData = const {},
    this.skillsByGroup = const {},
    this.wrapWithCard = true,
  });

  final List<Component> deities;
  final String? selectedDeityId;
  final Set<String> selectedDomainSlugs;
  final int requiredDeityCount;
  final int requiredDomainCount;
  final Map<String, String> domainNameBySlug;
  final Map<String, Set<String>> domainSlugsByDeityId;
  final Set<String> availableDomainSlugs;
  final ValueChanged<String?> onDeityChanged;
  final ValueChanged<Set<String>> onDomainChanged;
  final String? selectedDomainName;
  final Map<String, String> selectedDomainSkills;
  final void Function(String domainSlug, String skill)? onDomainSkillChanged;
  final Map<String, Map<String, dynamic>> domainFeatureData;
  final Map<String, List<String>> skillsByGroup;

  final bool wrapWithCard;

  @override
  State<DeityDomainPickerCard> createState() => _DeityDomainPickerCardState();
}

class _DeityDomainPickerCardState extends State<DeityDomainPickerCard> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summaryText = _summaryLine();

    // Group deities by category
    final gods = <Component>[];
    final saints = <Component>[];
    final others = <Component>[];

    for (final deity in widget.deities) {
      final category = (deity.data['category'] as String?) ?? 'other';
      switch (category) {
        case 'god':
          gods.add(deity);
          break;
        case 'saint':
          saints.add(deity);
          break;
        default:
          others.add(deity);
          break;
      }
    }

    // Sort each group
    gods.sort((a, b) => a.name.compareTo(b.name));
    saints.sort((a, b) => a.name.compareTo(b.name));
    others.sort((a, b) => a.name.compareTo(b.name));

    final availableChoices = _domainChoicesFor(widget.selectedDeityId).toList()
      ..sort((a, b) => _displayDomain(a).compareTo(_displayDomain(b)));
    final selectedDeity = _resolveDeity(widget.selectedDeityId);

    final hasDeityData = widget.deities.isNotEmpty;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String?>(
          value: widget.selectedDeityId,
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('-- Choose deity --'),
            ),
            if (gods.isNotEmpty) ..._buildDeitySection('Gods', gods),
            if (saints.isNotEmpty) ..._buildDeitySection('Saints', saints),
            if (others.isNotEmpty) ..._buildDeitySection('Others', others),
          ],
          onChanged: hasDeityData
              ? (value) {
                  if (value != null && value.startsWith('__section_header_')) {
                    return;
                  }
                  widget.onDeityChanged(value);
                }
              : null,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.auto_awesome),
            labelText: 'Deity',
          ),
        ),
        if (!hasDeityData && widget.requiredDeityCount > 0) ...[
          const SizedBox(height: 12),
          Text(
            'Deity data is not available yet.',
            style: theme.textTheme.bodySmall,
          ),
        ],
        if (selectedDeity != null) ...[
          const SizedBox(height: 16),
          DeityCard(deity: selectedDeity),
        ],
        if (widget.requiredDomainCount > 0 ||
            widget.availableDomainSlugs.isNotEmpty ||
            widget.selectedDomainSlugs.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Available Domains',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (availableChoices.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: availableChoices.map((slug) {
                final isSelected = widget.selectedDomainSlugs.contains(slug);
                return FilterChip(
                  label: Text(_displayDomain(slug)),
                  selected: isSelected,
                  onSelected: (selected) {
                    final orderedSelection =
                        List<String>.from(widget.selectedDomainSlugs);
                    if (selected) {
                      if (!orderedSelection.contains(slug)) {
                        orderedSelection.add(slug);
                        if (orderedSelection.length >
                                widget.requiredDomainCount &&
                            widget.requiredDomainCount > 0) {
                          orderedSelection.removeAt(0);
                        }
                      }
                    } else {
                      orderedSelection.remove(slug);
                    }
                    widget.onDomainChanged(orderedSelection.toSet());
                  },
                );
              }).toList(),
            ),
          ] else ...[
            Text(
              'No domains available for this deity.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
        if (widget.selectedDomainSlugs.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Domain features',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...widget.selectedDomainSlugs
              .map((slug) => _buildDomainSkillCard(context, slug)),
        ],
      ],
    );

    if (!widget.wrapWithCard) {
      return body;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        shape: const RoundedRectangleBorder(
          borderRadius: StrifeTheme.cardRadius,
        ),
        elevation: StrifeTheme.cardElevation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StrifeTheme.sectionHeader(
              context,
              title: 'Deity & Domains',
              subtitle:
                  '$summaryText Domain features update automatically based on your choices.',
              icon: Icons.auto_awesome_outlined,
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

  Widget _buildDomainSkillCard(BuildContext context, String domainSlug) {
    final theme = Theme.of(context);
    final domainName = _displayDomain(domainSlug);
    final domainData = widget.domainFeatureData[domainSlug];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 16, color: theme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  domainName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (domainData != null) ...[
              const SizedBox(height: 8),
              Text(
                domainData['name'] ?? 'Domain Feature',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                domainData['description'] ?? '',
                style: theme.textTheme.bodySmall,
              ),
              if (domainData['skill_group'] != null &&
                  widget.skillsByGroup[domainData['skill_group']] != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Select a skill from ${_titleCase(domainData['skill_group'])}:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: widget.skillsByGroup[domainData['skill_group']]!
                      .map((skill) {
                    final isSelected =
                        widget.selectedDomainSkills[domainSlug] == skill;
                    return FilterChip(
                      label: Text(skill),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected && widget.onDomainSkillChanged != null) {
                          widget.onDomainSkillChanged!(domainSlug, skill);
                        }
                      },
                      showCheckmark: false,
                    );
                  }).toList(),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Component? _resolveDeity(String? id) {
    if (id == null) return null;
    for (final deity in widget.deities) {
      if (deity.id == id) return deity;
    }
    final lower = id.toLowerCase();
    for (final deity in widget.deities) {
      if (deity.id.toLowerCase() == lower) return deity;
    }
    return null;
  }

  Set<String> _domainChoicesFor(String? deityId) {
    final available = widget.availableDomainSlugs;
    if (deityId == null) {
      return available.isEmpty ? _domainSetFor(null) : available;
    }
    final allowed = _domainSetFor(deityId);
    if (available.isEmpty) return allowed;
    if (allowed.isEmpty) return available;
    return allowed.intersection(available);
  }

  Set<String> _domainSetFor(String? deityId) {
    if (deityId == null) {
      final result = <String>{};
      for (final set in widget.domainSlugsByDeityId.values) {
        result.addAll(set);
      }
      return result;
    }
    return widget.domainSlugsByDeityId[deityId] ??
        widget.domainSlugsByDeityId[deityId.toLowerCase()] ??
        <String>{};
  }

  String _summaryLine() {
    final parts = <String>[];
    if (widget.requiredDeityCount > 0) {
      parts.add(
        'Pick ${widget.requiredDeityCount} ${widget.requiredDeityCount == 1 ? 'deity' : 'deities'}',
      );
    }
    if (widget.requiredDomainCount > 0) {
      parts.add(
        'Pick ${widget.requiredDomainCount} ${widget.requiredDomainCount == 1 ? 'domain' : 'domains'}',
      );
    }
    if (parts.isEmpty) {
      return 'Select a deity and an optional domain.';
    }
    return parts.join(' • ');
  }

  String _displayDomain(String slug) =>
      widget.domainNameBySlug[slug] ?? _titleCaseFromSlug(slug);

  String _titleCase(String text) =>
      text.substring(0, 1).toUpperCase() +
      (text.length > 1 ? text.substring(1).toLowerCase() : '');

  String _titleCaseFromSlug(String slug) {
    final parts = slug
        .split('_')
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return slug;
    return parts
        .map(
          (part) =>
              part.substring(0, 1).toUpperCase() +
              (part.length > 1 ? part.substring(1) : ''),
        )
        .join(' ');
  }

  List<DropdownMenuItem<String?>> _buildDeitySection(
    String sectionTitle,
    List<Component> deities,
  ) {
    return [
      // Section header (disabled item for visual separation)
      DropdownMenuItem<String?>(
        enabled: false,
        value: '__section_header_${sectionTitle.toLowerCase()}__',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            sectionTitle,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ),
      ),
      // Deity items
      ...deities.map(
        (deity) => DropdownMenuItem<String?>(
          value: deity.id,
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(deity.name),
          ),
        ),
      ),
    ];
  }
}
