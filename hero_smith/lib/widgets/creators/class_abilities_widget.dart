import 'package:flutter/material.dart';

import '../../core/theme/strife_theme.dart';

const Set<String> _subclassStopWords = {'the', 'of'};

enum _AllowanceSource { base, subclass }

class ClassAbilitiesWidget extends StatefulWidget {
  const ClassAbilitiesWidget({
    super.key,
    required this.level,
    required this.classMetadata,
    required this.abilities,
    required this.abilityDetailsById,
    required this.selectedAbilityIds,
    required this.autoGrantedAbilityIds,
    required this.baselineAbilityIds,
    required this.activeSubclassSlugs,
    this.subclassLabel,
    required this.onSelectionChanged,
    this.abilitySummaryBuilder,
    this.onAbilityPreviewRequested,
    this.wrapWithCard = true,
  });

  final int level;
  final Map<String, dynamic>? classMetadata;
  final List<Map<String, dynamic>> abilities;
  final Map<String, Map<String, dynamic>> abilityDetailsById;
  final Set<String> selectedAbilityIds;
  final Set<String> autoGrantedAbilityIds;
  final Set<String> baselineAbilityIds;
  final Set<String> activeSubclassSlugs;
  final String? subclassLabel;
  final ValueChanged<Set<String>> onSelectionChanged;
  final String? Function(Map<String, dynamic> ability)? abilitySummaryBuilder;
  final void Function(Map<String, dynamic> ability)? onAbilityPreviewRequested;
  final bool wrapWithCard;

  @override
  State<ClassAbilitiesWidget> createState() => _ClassAbilitiesWidgetState();
}

class _ClassAbilitiesWidgetState extends State<ClassAbilitiesWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final levelConfigs = _deriveLevelConfigs();
    final hasAllowances = levelConfigs.isNotEmpty;
    final totalSlots = levelConfigs.fold<int>(
      0,
      (sum, config) => sum + config.totalSlots,
    );
    final selectedSlots = widget.selectedAbilityIds.length.clamp(0, totalSlots);

    final remainingSelections = _sortedSelectedAbilityIds();
    final selectedAcrossSlots = widget.selectedAbilityIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    final levelTiles = <Widget>[];
    for (final config in levelConfigs) {
      levelTiles.add(
        _buildLevelTile(
          theme,
          config,
          remainingSelections,
          selectedAcrossSlots,
        ),
      );
    }

    final leftoverSelections = remainingSelections.toSet();

    final hasAutoGrants = widget.autoGrantedAbilityIds.isNotEmpty;
    final hasBaseline = widget.baselineAbilityIds.isNotEmpty;

    Widget buildEmptyBody() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No ability picks are available at level ${widget.level} yet.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Gain levels or select a subclass to unlock ability choices.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      );
    }

    Widget buildMainBody(List<String> summaryParts) {
      final body = <Widget>[];
      if (summaryParts.isNotEmpty) {
        body.add(Text(
          summaryParts.join(' | '),
          style: theme.textTheme.bodyMedium,
        ));
        body.add(const SizedBox(height: 12));
      }
      if (hasAutoGrants) {
        body.add(_buildAutoGrantedList(theme));
        body.add(const SizedBox(height: 12));
      }
      if (hasBaseline) {
        body.add(_buildBaselineNotice(theme));
        body.add(const SizedBox(height: 12));
      }
      if (levelTiles.isNotEmpty) {
        body.addAll(_withSpacing(levelTiles, const SizedBox(height: 12)));
      } else {
        body.add(Text(
          'No selectable ability picks yet. Advance to higher levels to unlock choices.',
          style: theme.textTheme.bodyMedium,
        ));
      }
      if (leftoverSelections.isNotEmpty) {
        body.add(const SizedBox(height: 16));
        body.add(_buildLeftoverSection(theme, leftoverSelections));
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: body,
      );
    }

    if (!hasAllowances && !hasAutoGrants && !hasBaseline) {
      final body = buildEmptyBody();
      if (!widget.wrapWithCard) {
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
                title: 'Class abilities',
                subtitle:
                    'No ability picks are available at level ${widget.level} yet.',
                icon: Icons.bolt,
                accent: StrifeTheme.abilitiesAccent,
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

    final summaryParts = <String>[];
    summaryParts.add('$selectedSlots of $totalSlots picks filled');
    if (widget.activeSubclassSlugs.isEmpty) {
      summaryParts.add('Subclass picks locked');
    }

    final body = buildMainBody(summaryParts);

    if (!widget.wrapWithCard) {
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
              title: 'Class abilities',
              subtitle: 'Assign abilities unlocked by your class progression.',
              icon: Icons.bolt,
              accent: StrifeTheme.abilitiesAccent,
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

  List<_AbilityLevelConfig> _deriveLevelConfigs() {
    final metadata = widget.classMetadata;
    if (metadata == null) return const [];
    final start = metadata['starting_characteristics'];
    if (start is! Map<String, dynamic>) return const [];
    final levels = start['levels'];
    if (levels is! List) return const [];

    final configs = <_AbilityLevelConfig>[];

    for (final entry in levels) {
      if (entry is! Map<String, dynamic>) continue;
      final levelNumber = (entry['level'] as num?)?.toInt();
      if (levelNumber == null || levelNumber > widget.level) continue;

      final allowances = <_AbilityAllowance>[];
      final newAbilities = entry['new_abilities'];
      if (newAbilities is Map<String, dynamic>) {
        for (final mapEntry in newAbilities.entries) {
          final allowance = _allowanceFromMapEntry(
            mapEntry.key,
            mapEntry.value,
            _AllowanceSource.base,
            requiresSubclass: false,
          );
          if (allowance != null) {
            allowances.add(allowance);
          }
        }
      }

      final newSubclassAbilities = entry['new_subclass_abilities'];
      if (newSubclassAbilities != null) {
        allowances.addAll(
          _parseSubclassAllowances(newSubclassAbilities),
        );
      }

      if (allowances.isNotEmpty) {
        configs.add(
          _AbilityLevelConfig(level: levelNumber, allowances: allowances),
        );
      }
    }

    return configs;
  }

  _AbilityAllowance? _allowanceFromMapEntry(
    String key,
    dynamic value,
    _AllowanceSource source, {
    required bool requiresSubclass,
  }) {
    final count = _toIntOrNull(value) ?? 0;
    if (count <= 0) return null;
    final lowered = key.toLowerCase();
    int? cost;
    if (lowered.contains('signature')) {
      cost = null;
    } else {
      final match = RegExp(r'(\d+)').firstMatch(lowered);
      cost = match != null ? int.tryParse(match.group(1)!) : null;
    }
    return _AbilityAllowance(
      source: source,
      count: count,
      cost: cost,
      requiresSubclass: requiresSubclass,
    );
  }

  List<_AbilityAllowance> _parseSubclassAllowances(dynamic data) {
    final results = <_AbilityAllowance>[];
    if (widget.activeSubclassSlugs.isEmpty) {
      // Still show the pickers, but they will be disabled until a subclass is chosen.
    }

    if (data is Map) {
      final map = data.cast<dynamic, dynamic>();
      final isDirect = map.values.every((value) => _toIntOrNull(value) != null);
      if (isDirect) {
        for (final entry in map.entries) {
          final allowance = _allowanceFromMapEntry(
            entry.key.toString(),
            entry.value,
            _AllowanceSource.subclass,
            requiresSubclass: true,
          );
          if (allowance != null) results.add(allowance);
        }
        return results;
      }

      for (final entry in map.entries) {
        final key = entry.key?.toString() ?? '';
        if (key.trim().isEmpty) continue;
        if (!_matchesSubclassKey(key)) continue;
        results.addAll(_parseSubclassAllowances(entry.value));
      }
      return results;
    }

    if (data is Iterable) {
      for (final item in data) {
        results.addAll(_parseSubclassAllowances(item));
      }
    }

    return results;
  }

  bool _matchesSubclassKey(String key) {
    if (widget.activeSubclassSlugs.isEmpty) return false;
    final variants = _slugVariants(key);
    return variants.any(widget.activeSubclassSlugs.contains);
  }

  Widget _buildLevelTile(
    ThemeData theme,
    _AbilityLevelConfig config,
    List<String> remainingSelections,
    Set<String> selectedAcrossSlots,
  ) {
    final allowanceWidgets = <Widget>[];
    final usedEarlier = <String>{};

    for (var index = 0; index < config.allowances.length; index++) {
      final allowance = config.allowances[index];
      final slotValues = <String?>[];
      for (var slot = 0; slot < allowance.count; slot++) {
        final assigned = _consumeMatchingSelection(
          remainingSelections,
          allowance,
        );
        if (assigned != null) {
          usedEarlier.add(assigned);
        }
        slotValues.add(assigned);
      }

      allowanceWidgets.add(
        _buildAllowanceCard(
          theme,
          config.level,
          allowance,
          slotValues,
          selectedAcrossSlots,
        ),
      );
      if (index < config.allowances.length - 1) {
        allowanceWidgets.add(const SizedBox(height: 8));
      }
    }

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: ValueKey('ability_level_${config.level}'),
        title: Text('Level ${config.level}'),
        subtitle: Text(
          '${config.totalSlots} pick${config.totalSlots == 1 ? '' : 's'} available',
          style: theme.textTheme.bodySmall,
        ),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        maintainState: true,
        children: allowanceWidgets,
      ),
    );
  }

  Widget _buildAllowanceCard(
    ThemeData theme,
    int level,
    _AbilityAllowance allowance,
    List<String?> slotValues,
    Set<String> selectedAcrossSlots,
  ) {
    final candidates = _candidateAbilitiesForAllowance(allowance);
    final requiresSubclass =
        allowance.requiresSubclass && widget.activeSubclassSlugs.isEmpty;
    final hasOptions = candidates.isNotEmpty;

    final usedInThisAllowance = <String>{};
    final slots = <Widget>[];

    for (var slotIndex = 0; slotIndex < slotValues.length; slotIndex++) {
      final currentId = slotValues[slotIndex];
      if (currentId != null) {
        usedInThisAllowance.add(currentId);
      }

      final takenElsewhere = selectedAcrossSlots.toSet()
        ..remove(currentId)
        ..removeAll(usedInThisAllowance.where((id) => id != currentId));

      final dropdownItems = <DropdownMenuItem<String?>>[
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('— Choose ability —'),
        ),
      ];

      for (final candidate in candidates) {
        final candidateId = _resolveAbilityId(candidate);
        if (candidateId == null) continue;
        if (takenElsewhere.contains(candidateId)) continue;
        dropdownItems.add(
          DropdownMenuItem<String?>(
            value: candidateId,
            child: Text(
              '${_abilityName(candidateId)} (${_costLabel(candidate)})',
            ),
          ),
        );
      }

      final ability = currentId != null ? _abilityById(currentId) : null;
      final summary =
          ability != null ? widget.abilitySummaryBuilder?.call(ability) : null;

      slots.add(
        Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.18),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pick ${slotIndex + 1}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                value: currentId,
                items: dropdownItems,
                onChanged: !requiresSubclass && hasOptions
                    ? (value) => _handleSlotChanged(currentId, value)
                    : null,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.menu_book_outlined),
                  labelText: requiresSubclass && widget.subclassLabel != null
                      ? 'Subclass ability'
                      : 'Choose ability',
                ),
              ),
              if (requiresSubclass && widget.activeSubclassSlugs.isEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Select a subclass to unlock this ability choice.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (!requiresSubclass && !hasOptions) ...[
                const SizedBox(height: 12),
                Text(
                  'No abilities of the required cost are available yet.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (summary != null && summary.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(summary, style: theme.textTheme.bodySmall),
              ],
              if ((ability != null &&
                      widget.onAbilityPreviewRequested != null) ||
                  currentId != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (ability != null &&
                        widget.onAbilityPreviewRequested != null)
                      TextButton.icon(
                        onPressed: () =>
                            widget.onAbilityPreviewRequested!(ability),
                        icon: const Icon(Icons.info_outline),
                        label: const Text('View details'),
                      ),
                    if (currentId != null)
                      TextButton.icon(
                        onPressed: () => _handleSlotChanged(currentId, null),
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear selection'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    }

    final sourceLabel =
        allowance.source == _AllowanceSource.subclass ? 'Subclass' : 'Class';
    final costLabel =
        allowance.cost == null ? 'Signature' : '${allowance.cost}-cost';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allowance.source == _AllowanceSource.subclass
                    ? Icons.auto_awesome
                    : Icons.bolt_outlined,
                size: 18,
                color: StrifeTheme.abilitiesAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$sourceLabel $costLabel ability · Level $level',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...slots,
        ],
      ),
    );
  }

  Widget _buildAutoGrantedList(ThemeData theme) {
    final entries = widget.autoGrantedAbilityIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList()
      ..sort((a, b) => _abilityName(a).compareTo(_abilityName(b)));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: StrifeTheme.abilitiesAccent.withValues(alpha: 0.08),
        border: Border.all(
          color: StrifeTheme.abilitiesAccent.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock, size: 18, color: StrifeTheme.abilitiesAccent),
              const SizedBox(width: 8),
              Text(
                'Automatically granted abilities',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: StrifeTheme.abilitiesAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final id in entries) ...[
            Text(
              _abilityName(id),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBaselineNotice(ThemeData theme) {
    final entries = widget.baselineAbilityIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList()
      ..sort();

    return Container(
      width: double.infinity,
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
            entries.length == 1
                ? '1 existing ability retained:'
                : '${entries.length} existing abilities retained:',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            entries.join(', '),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildLeftoverSection(
    ThemeData theme,
    Set<String> leftover,
  ) {
    final chips = leftover
        .map(
          (id) => InputChip(
            label: Text(_abilityName(id)),
            avatar: const Icon(Icons.warning_amber, size: 16),
            onDeleted: () => _handleSlotChanged(id, null),
          ),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Unassigned abilities',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'These abilities do not match any current allowance. Remove them or adjust your picks.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chips,
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _candidateAbilitiesForAllowance(
    _AbilityAllowance allowance,
  ) {
    final candidates = <Map<String, dynamic>>[];
    for (final ability in widget.abilities) {
      final abilityId = _resolveAbilityId(ability);
      if (abilityId == null) continue;
      if (!_matchesAllowance(abilityId, allowance)) continue;
      final resolved = _abilityById(abilityId) ?? ability;
      candidates.add(resolved);
    }
    candidates.sort((a, b) {
      final idA = _resolveAbilityId(a) ?? '';
      final idB = _resolveAbilityId(b) ?? '';
      return _abilityName(idA).compareTo(_abilityName(idB));
    });
    return candidates;
  }

  bool _matchesAllowance(String abilityId, _AbilityAllowance allowance) {
    final ability = _abilityById(abilityId);
    if (ability == null) return false;
    final isSignature = _isSignatureAbility(ability);
    final cost = _abilityCost(ability);
    if (allowance.cost == null) {
      if (!isSignature) return false;
    } else {
      if (isSignature) return false;
      if (cost != allowance.cost) return false;
    }

    final abilityLevel = _toIntOrNull(ability['level']) ?? 0;
    if (abilityLevel > widget.level) return false;

    final subclass = ability['subclass']?.toString().trim() ?? '';
    if (allowance.requiresSubclass) {
      if (widget.activeSubclassSlugs.isEmpty) return false;
      if (subclass.isEmpty) return false;
      final variants = _slugVariants(subclass);
      if (!variants.any(widget.activeSubclassSlugs.contains)) {
        return false;
      }
    } else {
      if (subclass.isNotEmpty) return false;
    }
    return true;
  }

  String? _resolveAbilityId(Map<String, dynamic> ability) {
    final resolved = ability['resolved_id']?.toString();
    if (resolved != null && resolved.isNotEmpty) return resolved;
    final rawId = ability['id']?.toString();
    if (rawId != null && rawId.isNotEmpty) return rawId;
    final name = ability['name']?.toString();
    if (name != null && name.isNotEmpty) return _slugify(name);
    return null;
  }

  Map<String, dynamic>? _abilityById(String abilityId) {
    final existing = widget.abilityDetailsById[abilityId];
    if (existing != null) return existing;
    for (final ability in widget.abilities) {
      if (_resolveAbilityId(ability) == abilityId) {
        return ability;
      }
    }
    return null;
  }

  String _abilityName(String abilityId) {
    final ability = _abilityById(abilityId);
    final name = ability?['name']?.toString();
    if (name != null && name.trim().isNotEmpty) return name.trim();
    return abilityId;
  }

  String _costLabel(Map<String, dynamic> ability) {
    if (_isSignatureAbility(ability)) {
      return 'Signature';
    }
    final cost = _abilityCost(ability);
    if (cost == null || cost <= 0) {
      final resource = ability['costs'];
      if (resource is Map<String, dynamic>) {
        final resourceName = resource['resource']?.toString();
        if (resourceName != null && resourceName.trim().isNotEmpty) {
          return '${resourceName.trim()} (free)';
        }
      }
      return 'No cost';
    }
    return '${cost}-cost';
  }

  bool _isSignatureAbility(Map<String, dynamic>? ability) {
    if (ability == null) return false;
    final costs = ability['costs'];
    if (costs is Map<String, dynamic>) {
      final signature = costs['signature'];
      if (signature is bool) return signature;
      if (signature is num) return signature != 0;
      if (signature is String) {
        final normalized = signature.trim().toLowerCase();
        if (normalized == 'true') return true;
        if (normalized == 'false') return false;
        return normalized == '1';
      }
    }
    return false;
  }

  int? _abilityCost(Map<String, dynamic> ability) {
    final direct = _toIntOrNull(ability['cost']);
    if (direct != null) return direct;
    final costs = ability['costs'];
    if (costs is Map<String, dynamic>) {
      final amount = _toIntOrNull(costs['amount']);
      if (amount != null) return amount;
    }
    return null;
  }

  int? _toIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      final match = RegExp(r'^-?\d+').firstMatch(value.trim());
      if (match != null) {
        return int.tryParse(match.group(0)!);
      }
    }
    return null;
  }

  String? _consumeMatchingSelection(
    List<String> remaining,
    _AbilityAllowance allowance,
  ) {
    for (var i = 0; i < remaining.length; i++) {
      final id = remaining[i];
      if (_matchesAllowance(id, allowance)) {
        remaining.removeAt(i);
        return id;
      }
    }
    return null;
  }

  List<String> _sortedSelectedAbilityIds() {
    final ids = widget.selectedAbilityIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    ids.sort((a, b) => _abilityName(a).compareTo(_abilityName(b)));
    return ids;
  }

  void _handleSlotChanged(String? currentId, String? newId) {
    final updated = widget.selectedAbilityIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (currentId != null) {
      updated.remove(currentId);
    }
    if (newId != null) {
      updated.remove(newId);
      updated.add(newId);
    }
    widget.onSelectionChanged(updated);
  }

  List<Widget> _withSpacing(List<Widget> children, Widget spacer) {
    if (children.length <= 1) return children;
    final result = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      result.add(children[i]);
      if (i < children.length - 1) {
        result.add(spacer);
      }
    }
    return result;
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

    final trimmedAll =
        tokens.where((token) => !_subclassStopWords.contains(token)).join('_');
    if (trimmedAll.isNotEmpty) variants.add(trimmedAll);

    for (var i = 1; i < tokens.length; i++) {
      final suffix = tokens.sublist(i).join('_');
      if (suffix.isNotEmpty) variants.add(suffix);

      final trimmedSuffix = tokens
          .sublist(i)
          .where((token) => !_subclassStopWords.contains(token))
          .join('_');
      if (trimmedSuffix.isNotEmpty) variants.add(trimmedSuffix);
    }

    return variants;
  }

  String _slugify(String value) {
    final normalized =
        value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final collapsed = normalized.replaceAll(RegExp(r'_+'), '_');
    return collapsed.replaceAll(RegExp(r'^_|_$'), '');
  }
}

class _AbilityLevelConfig {
  _AbilityLevelConfig({
    required this.level,
    required this.allowances,
  });

  final int level;
  final List<_AbilityAllowance> allowances;

  int get totalSlots =>
      allowances.fold<int>(0, (sum, allowance) => sum + allowance.count);
}

class _AbilityAllowance {
  _AbilityAllowance({
    required this.source,
    required this.count,
    required this.cost,
    required this.requiresSubclass,
  });

  final _AllowanceSource source;
  final int count;
  final int? cost;
  final bool requiresSubclass;
}
