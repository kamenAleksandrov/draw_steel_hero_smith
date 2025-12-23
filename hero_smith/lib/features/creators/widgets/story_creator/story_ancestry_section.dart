import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/providers.dart';
import '../../../../core/models/component.dart' as model;
import '../../../../core/theme/hero_theme.dart';
import '../../../../core/theme/text/creators/widgets/story_creator/story_ancestry_section_text.dart';

class StoryAncestrySection extends ConsumerWidget {
  const StoryAncestrySection({
    super.key,
    required this.selectedAncestryId,
    required this.selectedTraitIds,
    required this.traitChoices,
    required this.onAncestryChanged,
    required this.onTraitSelectionChanged,
    required this.onTraitChoiceChanged,
    required this.onDirty,
  });

  final String? selectedAncestryId;
  final Set<String> selectedTraitIds;
  final Map<String, String> traitChoices;
  final ValueChanged<String?> onAncestryChanged;
  final void Function(String traitId, bool isSelected) onTraitSelectionChanged;
  final void Function(String traitOrSignatureId, String choiceValue) onTraitChoiceChanged;
  final VoidCallback onDirty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ancestriesAsync = ref.watch(componentsByTypeProvider('ancestry'));
    final ancestryTraitsAsync = ref.watch(componentsByTypeProvider('ancestry_trait'));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: HeroTheme.sectionCardElevation,
        shape: const RoundedRectangleBorder(borderRadius: HeroTheme.cardRadius),
        child: Column(
          children: [
            HeroTheme.buildSectionHeader(
              context,
              title: StoryAncestrySectionText.sectionTitle,
              subtitle: StoryAncestrySectionText.sectionSubtitle,
              icon: Icons.family_restroom,
              color: HeroTheme.getStepColor('ancestry'),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ancestriesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text(
                        '${StoryAncestrySectionText.errorPrefix}$e',
                        style: TextStyle(color: theme.colorScheme.error)),
                    data: (ancestries) => _buildAncestryDropdown(
                      context,
                      theme,
                      ancestries,
                      ancestryTraitsAsync,
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

  Widget _buildAncestryDropdown(
    BuildContext context,
    ThemeData theme,
    List<model.Component> ancestries,
    AsyncValue<List<model.Component>> traitsAsync,
  ) {
    ancestries = List.of(ancestries)..sort((a, b) => a.name.compareTo(b.name));
    final selectedAncestry = ancestries.firstWhere(
      (a) => a.id == selectedAncestryId,
      orElse: () => ancestries.isNotEmpty
          ? ancestries.first
          : const model.Component(
              id: '',
              type: 'ancestry',
              name: StoryAncestrySectionText.unknownAncestryName,
            ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InputDecorator(
          decoration: InputDecoration(
            labelText: StoryAncestrySectionText.chooseAncestryLabel,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?> (
              value: selectedAncestryId,
              isExpanded: true,
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text(StoryAncestrySectionText.chooseAncestryOption),
                ),
                ...ancestries.map(
                  (a) => DropdownMenuItem<String?>(
                    value: a.id,
                    child: Text(a.name),
                  ),
                ),
              ],
              onChanged: (value) {
                onAncestryChanged(value);
                onDirty();
              },
            ),
          ),
        ),
        if (selectedAncestryId != null) ...[
          const SizedBox(height: 16),
          traitsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(
                '${StoryAncestrySectionText.errorLoadingTraitsPrefix}$e'),
            data: (traitsComps) {
              final traitsForSelected = traitsComps.firstWhere(
                (t) => t.data['ancestry_id'] == selectedAncestryId,
                orElse: () => traitsComps.firstWhere(
                  (t) => t.data['ancestry_id'] == selectedAncestry.id,
                  orElse: () => traitsComps.isNotEmpty
                      ? traitsComps.first
                      : const model.Component(
                          id: '', type: 'ancestry_trait', name: ''),
                ),
              );
              return _AncestryDetails(
                ancestry: selectedAncestry,
                traitsComp: traitsForSelected,
                selectedTraitIds: selectedTraitIds,
                traitChoices: traitChoices,
                onTraitSelectionChanged: onTraitSelectionChanged,
                onTraitChoiceChanged: onTraitChoiceChanged,
                onDirty: onDirty,
              );
            },
          ),
        ],
      ],
    );
  }
}

class _AncestryDetails extends StatelessWidget {
  const _AncestryDetails({
    required this.ancestry,
    required this.traitsComp,
    required this.selectedTraitIds,
    required this.traitChoices,
    required this.onTraitSelectionChanged,
    required this.onTraitChoiceChanged,
    required this.onDirty,
  });

  final model.Component ancestry;
  final model.Component traitsComp;
  final Set<String> selectedTraitIds;
  final Map<String, String> traitChoices;
  final void Function(String traitId, bool isSelected) onTraitSelectionChanged;
  final void Function(String traitOrSignatureId, String choiceValue) onTraitChoiceChanged;
  final VoidCallback onDirty;

  @override
  Widget build(BuildContext context) {
    final data = ancestry.data;
    final shortDesc = (data['short_description'] as String?) ?? '';
    final height = (data['height'] as Map?)?.cast<String, dynamic>();
    final weight = (data['weight'] as Map?)?.cast<String, dynamic>();
    final life = (data['life_expectancy'] as Map?)?.cast<String, dynamic>();
    final size = data['size'];
    final speed = data['speed'];
    final stability = data['stability'];

    final signature = (traitsComp.data['signature'] as Map?)?.cast<String, dynamic>();

    final points = (traitsComp.data['points'] as int?) ?? 0;
    final traitsList =
        (traitsComp.data['traits'] as List?)?.cast<Map>() ?? const <Map>[];

    final spent = selectedTraitIds.fold<int>(0, (sum, id) {
      final match = traitsList.firstWhere(
        (t) => (t['id'] ?? t['name']).toString() == id,
        orElse: () => const {},
      );
      return sum + (match.cast<String, dynamic>()['cost'] as int? ?? 0);
    });
    final remaining = points - spent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (shortDesc.isNotEmpty) ...[
          Text(shortDesc,
              style: TextStyle(color: Colors.grey.shade300, height: 1.3)),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (height != null)
              _chip(
                '${StoryAncestrySectionText.heightChipPrefix}${height['min']}–${height['max']}',
                Colors.blue,
              ),
            if (weight != null)
              _chip(
                '${StoryAncestrySectionText.weightChipPrefix}${weight['min']}–${weight['max']}',
                Colors.green,
              ),
            if (life != null)
              _chip(
                '${StoryAncestrySectionText.lifespanChipPrefix}${life['min']}–${life['max']}',
                Colors.purple,
              ),
            if (size != null)
              _chip(
                '${StoryAncestrySectionText.sizeChipPrefix}$size',
                Colors.orange,
              ),
            if (speed != null)
              _chip(
                '${StoryAncestrySectionText.speedChipPrefix}$speed',
                Colors.teal,
              ),
            if (stability != null)
              _chip(
                '${StoryAncestrySectionText.stabilityChipPrefix}$stability',
                Colors.redAccent,
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (signature != null) ...[
          Text(
              '${StoryAncestrySectionText.signatureLabelPrefix}${signature['name'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          if ((signature['description'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(signature['description'] as String,
                style: const TextStyle(height: 1.3)),
          ],
          // Show dropdown for signature immunity choice (e.g., Wyrmplate)
          if (_signatureHasImmunityChoice(signature)) ...[
            const SizedBox(height: 8),
            _buildImmunityDropdown(
              signatureId: 'signature_immunity',
              currentValue: traitChoices['signature_immunity'],
              excludedValues: const {}, // Signature has no exclusions
              onChanged: (value) {
                if (value != null) {
                  onTraitChoiceChanged('signature_immunity', value);
                  onDirty();
                }
              },
            ),
          ],
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Chip(
                label: Text(
                    '${StoryAncestrySectionText.pointsLabelPrefix}$points')),
            const SizedBox(width: 8),
            Chip(
                label: Text(
                    '${StoryAncestrySectionText.remainingLabelPrefix}$remaining')),
          ],
        ),
        const SizedBox(height: 8),
        ...traitsList.map((t) {
          final traitData = t.cast<String, dynamic>();
          final id = (traitData['id'] ?? traitData['name']).toString();
          final name = (traitData['name'] ?? id).toString();
          final desc = (traitData['description'] ?? '').toString();
          final cost = (traitData['cost'] as int?) ?? 0;
          final selected = selectedTraitIds.contains(id);
          final canSelect = selected || remaining - cost >= 0;
          
          // Check if this trait has choices
          final hasImmunityChoice = _traitHasImmunityChoice(traitData);
          final abilityOptions = _getAbilityOptions(traitData);
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckboxListTile(
                value: selected,
                onChanged: canSelect
                    ? (value) {
                        if (value == null) return;
                        onTraitSelectionChanged(id, value);
                        onDirty();
                      }
                    : null,
                title: Text(name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      softWrap: true,
                    ),
                  ],
                ),
                isThreeLine: true,
                secondary: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$cost'),
                ),
                contentPadding: EdgeInsets.zero,
              ),
              // Show immunity dropdown for traits like Prismatic Scales
              if (selected && hasImmunityChoice) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 40, right: 16, bottom: 8),
                  child: _buildImmunityDropdown(
                    signatureId: id,
                    currentValue: traitChoices[id],
                    // Exclude signature immunity and other trait immunity choices
                    excludedValues: _getExcludedImmunities(id, traitChoices),
                    onChanged: (value) {
                      if (value != null) {
                        onTraitChoiceChanged(id, value);
                        onDirty();
                      }
                    },
                  ),
                ),
              ],
              // Show ability dropdown for traits like Psionic Gift
              if (selected && abilityOptions.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 40, right: 16, bottom: 8),
                  child: _buildAbilityDropdown(
                    traitId: id,
                    options: abilityOptions,
                    currentValue: traitChoices[id],
                    onChanged: (value) {
                      if (value != null) {
                        onTraitChoiceChanged(id, value);
                        onDirty();
                      }
                    },
                  ),
                ),
              ],
            ],
          );
        }),
      ],
    );
  }

  /// Check if signature has immunity choice (type: "pick_one")
  bool _signatureHasImmunityChoice(Map<String, dynamic> signature) {
    final increaseTotal = signature['increase_total'] as Map?;
    if (increaseTotal == null) return false;
    return increaseTotal['type'] == 'pick_one' && increaseTotal['stat'] == 'immunity';
  }

  /// Check if trait has immunity choice
  bool _traitHasImmunityChoice(Map<String, dynamic> trait) {
    final increaseTotal = trait['increase_total'] as Map?;
    if (increaseTotal == null) return false;
    return increaseTotal['type'] == 'pick_one' && increaseTotal['stat'] == 'immunity';
  }

  /// Get ability options for pick_ability_name traits
  List<String> _getAbilityOptions(Map<String, dynamic> trait) {
    final options = trait['pick_ability_name'] as List?;
    if (options == null) return [];
    return options.cast<String>();
  }

  /// Get immunity types that should be excluded from a trait's dropdown.
  /// Excludes signature immunity and other traits' immunity choices.
  Set<String> _getExcludedImmunities(String currentTraitId, Map<String, String> choices) {
    final excluded = <String>{};
    
    // Exclude signature immunity choice
    final signatureImmunity = choices['signature_immunity'];
    if (signatureImmunity != null && signatureImmunity.isNotEmpty) {
      excluded.add(signatureImmunity);
    }
    
    // Exclude other traits' immunity choices (but not the current trait's choice)
    for (final entry in choices.entries) {
      if (entry.key == currentTraitId) continue;
      if (entry.key == 'signature_immunity') continue; // Already handled
      // Only add if it's likely an immunity type
      if (_immunityTypes.contains(entry.value.toLowerCase())) {
        excluded.add(entry.value.toLowerCase());
      }
    }
    
    return excluded;
  }

  static const List<String> _immunityTypes =
      StoryAncestrySectionText.immunityTypes;

  Widget _buildImmunityDropdown({
    required String signatureId,
    required String? currentValue,
    required Set<String> excludedValues,
    required ValueChanged<String?> onChanged,
  }) {
    // Filter out excluded immunity types (but keep current value if it was previously selected)
    final availableTypes = _immunityTypes.where((type) {
      if (type == currentValue) return true; // Always show current selection
      return !excludedValues.contains(type);
    }).toList();

    return DropdownButtonFormField<String>(
      value: currentValue,
      decoration: InputDecoration(
        labelText: StoryAncestrySectionText.immunityDropdownLabel,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        filled: true,
        fillColor: Colors.deepPurple.withOpacity(0.05),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text(StoryAncestrySectionText.immunityDropdownHint),
        ),
        ...availableTypes.map(
          (type) => DropdownMenuItem<String>(
            value: type,
            child: Text(type[0].toUpperCase() + type.substring(1)),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildAbilityDropdown({
    required String traitId,
    required List<String> options,
    required String? currentValue,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: currentValue,
      decoration: InputDecoration(
        labelText: StoryAncestrySectionText.abilityDropdownLabel,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        filled: true,
        fillColor: Colors.teal.withOpacity(0.05),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text(StoryAncestrySectionText.abilityDropdownHint),
        ),
        ...options.map(
          (ability) => DropdownMenuItem<String>(
            value: ability,
            child: Text(ability),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }

  Widget _chip(String text, Color color) => Chip(
        label: Text(text),
        backgroundColor: color.withOpacity(0.1),
        side: BorderSide(color: color.withOpacity(0.6), width: 1),
      );
}
