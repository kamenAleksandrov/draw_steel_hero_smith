import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/providers.dart';
import '../../core/models/component.dart' as model;
import '../../core/services/perk_grants_service.dart';
import '../abilities/ability_expandable_item.dart';

/// Provider for loading perk grant choices for a specific hero and perk
final perkGrantChoicesProvider = FutureProvider.family<
    Map<String, List<String>>,
    ({String heroId, String perkId})>((ref, args) async {
  final db = ref.read(appDatabaseProvider);
  return PerkGrantsService().getAllGrantChoicesForPerk(
    db: db,
    heroId: args.heroId,
    perkId: args.perkId,
  );
});

/// Callback for perk selection changes
typedef PerksSelectionChanged = void Function(Set<String> selectedPerkIds);

/// A reusable widget for selecting perks.
///
/// This widget can be used:
/// 1. In the story creator's career section (with perkType filter and pickCount)
/// 2. In the hero sheet's perks tab (showing all hero perks and allowing additions)
/// 3. In the strife creator (with class-specific perk allowances)
class PerksSelectionWidget extends ConsumerStatefulWidget {
  const PerksSelectionWidget({
    super.key,
    required this.heroId,
    this.selectedPerkIds = const {},
    this.reservedPerkIds = const {},
    this.perkType,
    this.allowedGroups,
    this.pickCount,
    this.onSelectionChanged,
    this.onDirty,
    this.languages = const [],
    this.skills = const [],
    this.reservedLanguageIds = const {},
    this.reservedSkillIds = const {},
    this.showHeader = true,
    this.headerTitle = 'Perks',
    this.headerSubtitle,
    this.allowAddingNew = false,
    this.emptyStateMessage = 'No perks selected.',
    this.persistToDatabase = false,
  });

  /// The hero ID for grant choice persistence
  final String heroId;

  /// Currently selected perk IDs
  final Set<String> selectedPerkIds;

  /// Perk IDs that are reserved (e.g., from other sources) and should be excluded
  final Set<String> reservedPerkIds;

  /// Optional perk type filter (e.g., "crafting", "exploration")
  final String? perkType;

  /// Optional allowed perk groups; takes priority over [perkType] when provided.
  final Set<String>? allowedGroups;

  /// Number of perks to pick. If null, shows all selected perks (view mode)
  final int? pickCount;

  /// Callback when selection changes
  final PerksSelectionChanged? onSelectionChanged;

  /// Callback when data is modified (for dirty tracking)
  final VoidCallback? onDirty;

  /// Available languages for grant selection
  final List<model.Component> languages;

  /// Available skills for grant selection
  final List<model.Component> skills;

  /// Language IDs reserved by other sources
  final Set<String> reservedLanguageIds;

  /// Skill IDs reserved by other sources
  final Set<String> reservedSkillIds;

  /// Whether to show the header
  final bool showHeader;

  /// Title for the header
  final String headerTitle;

  /// Subtitle for the header
  final String? headerSubtitle;

  /// Whether to allow adding new perks (shows an "Add Perk" button)
  final bool allowAddingNew;

  /// Message shown when no perks are selected
  final String emptyStateMessage;

  /// Whether to persist selection changes directly to the database.
  /// Set to true when this widget manages ALL of a hero's perks (e.g., in hero sheet).
  /// Set to false when this widget manages only a subset (e.g., career perks in story creator).
  final bool persistToDatabase;

  @override
  ConsumerState<PerksSelectionWidget> createState() =>
      _PerksSelectionWidgetState();
}

class _PerksSelectionWidgetState extends ConsumerState<PerksSelectionWidget> {
  bool _appliedInitialGrants = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _ensureExistingPerkGrants());
  }

  @override
  void didUpdateWidget(covariant PerksSelectionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.heroId != widget.heroId ||
        !setEquals(oldWidget.selectedPerkIds, widget.selectedPerkIds)) {
      _appliedInitialGrants = false;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _ensureExistingPerkGrants());
    }
  }

  @override
  Widget build(BuildContext context) {
    final perksAsync = ref.watch(componentsByTypeProvider('perk'));

    return perksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed to load perks: $e')),
      data: (perks) => _buildContent(context, perks),
    );
  }

  Widget _buildContent(BuildContext context, List<model.Component> allPerks) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.tertiary;
    final normalizedAllowedGroups =
        _normalizeAllowedGroups(widget.allowedGroups);

    // Filter perks by type if specified
    final filteredPerks = _filterPerksByType(
      allPerks,
      widget.perkType,
      allowedGroups: normalizedAllowedGroups,
    );

    final hasFilters = normalizedAllowedGroups.isNotEmpty ||
        (widget.perkType?.isNotEmpty ?? false);
    if (filteredPerks.isEmpty && hasFilters) {
      // Fallback to all perks if no perks match the type
      return _buildPerkSelector(context, allPerks, borderColor);
    }

    return _buildPerkSelector(context, filteredPerks, borderColor);
  }

  Set<String> _normalizeAllowedGroups(Set<String>? groups) {
    if (groups == null) return const {};
    return groups
        .map(_normalizePerkType)
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  List<model.Component> _filterPerksByType(
    List<model.Component> perks,
    String? perkType, {
    Set<String> allowedGroups = const {},
  }) {
    if ((perkType == null || perkType.isEmpty) && allowedGroups.isEmpty) {
      return perks..sort((a, b) => a.name.compareTo(b.name));
    }

    final normalizedType = _normalizePerkType(perkType);
    final normalizedAllowed = allowedGroups
        .map(_normalizePerkType)
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet();
    if (normalizedType == null && normalizedAllowed.isEmpty) {
      return perks..sort((a, b) => a.name.compareTo(b.name));
    }

    final filtered = perks.where((perk) {
      final rawType = (perk.data['perk_type'] ??
              perk.data['perkType'] ??
              perk.data['group'])
          ?.toString();
      final normalizedPerkType = _normalizePerkType(rawType);
      if (normalizedPerkType == null || normalizedPerkType.isEmpty) {
        return false;
      }
      if (normalizedAllowed.isNotEmpty) {
        return normalizedAllowed.any(
          (group) =>
              normalizedPerkType == group ||
              normalizedPerkType.contains(group) ||
              group.contains(normalizedPerkType),
        );
      }
      if (normalizedType == null || normalizedType.isEmpty) {
        return true;
      }
      return normalizedPerkType == normalizedType ||
          normalizedPerkType.contains(normalizedType) ||
          normalizedType.contains(normalizedPerkType);
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return filtered;
  }

  String? _normalizePerkType(String? value) {
    if (value == null) return null;
    final cleaned = value
        .toLowerCase()
        .replaceAll('perk', '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  String _formatGroupLabel(String? raw) {
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

  Widget _buildPerkSelector(
    BuildContext context,
    List<model.Component> perks,
    Color borderColor,
  ) {
    final pickCount = widget.pickCount;

    // Group perks by type
    final grouped = <String, List<model.Component>>{};
    for (final perk in perks) {
      final rawType = (perk.data['group'] ??
              perk.data['perk_type'] ??
              perk.data['perkType'])
          ?.toString();
      final key = _formatGroupLabel(rawType);
      grouped.putIfAbsent(key, () => []).add(perk);
    }
    final sortedGroupKeys = grouped.keys.toList()..sort();
    for (final list in grouped.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }

    // Create perk map for lookup
    final perkMap = {for (final perk in perks) perk.id: perk};

    // Get current selections
    final currentSelections =
        widget.selectedPerkIds.where(perkMap.containsKey).toList();

    // If pickCount is null, show all selected perks (view mode)
    if (pickCount == null) {
      return _buildViewMode(context, currentSelections, perkMap, borderColor,
          grouped, sortedGroupKeys);
    }

    // Build selection mode
    return _buildSelectionMode(
      context,
      pickCount,
      currentSelections,
      perkMap,
      borderColor,
      grouped,
      sortedGroupKeys,
    );
  }

  Widget _buildViewMode(
    BuildContext context,
    List<String> currentSelections,
    Map<String, model.Component> perkMap,
    Color borderColor,
    Map<String, List<model.Component>> grouped,
    List<String> sortedGroupKeys,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHeader) ...[
          Row(
            children: [
              Icon(Icons.stars, color: borderColor, size: 20),
              const SizedBox(width: 8),
              Text(
                widget.headerTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: borderColor,
                ),
              ),
              const Spacer(),
              if (widget.allowAddingNew)
                TextButton.icon(
                  onPressed: () => _openAddPerkPicker(
                    context,
                    currentSelections,
                    perkMap,
                    grouped,
                    sortedGroupKeys,
                    borderColor,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Perk'),
                ),
            ],
          ),
          if (widget.headerSubtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.headerSubtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
        if (currentSelections.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                widget.emptyStateMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
          )
        else
          ...currentSelections.asMap().entries.map((entry) {
            final index = entry.key;
            final perkId = entry.value;
            final perk = perkMap[perkId]!;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < currentSelections.length - 1 ? 12 : 0,
              ),
              child: _buildPerkDisplay(context, perk, borderColor,
                  showRemove: widget.allowAddingNew),
            );
          }),
      ],
    );
  }

  Widget _buildSelectionMode(
    BuildContext context,
    int pickCount,
    List<String> currentSelections,
    Map<String, model.Component> perkMap,
    Color borderColor,
    Map<String, List<model.Component>> grouped,
    List<String> sortedGroupKeys,
  ) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: borderColor.withOpacity(0.6), width: 1.4),
    );

    List<String?> currentSlots() {
      final slots = List<String?>.filled(pickCount, null);
      for (var i = 0; i < pickCount && i < currentSelections.length; i++) {
        slots[i] = currentSelections[i];
      }
      return slots;
    }

    final slots = currentSlots();
    final remaining = slots.where((value) => value == null).length;
    final perkTypeLabel = widget.perkType?.isNotEmpty == true
        ? ' of type ${widget.perkType}'
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHeader) ...[
          const SizedBox(height: 8),
          Text(
            'Choose $pickCount perk${pickCount == 1 ? '' : 's'}$perkTypeLabel.',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
        ],
        for (var index = 0; index < pickCount; index++) ...[
          InkWell(
            onTap: () => _openSearchForPerkIndex(
              context,
              index,
              slots,
              perkMap,
              grouped,
              sortedGroupKeys,
              borderColor,
            ),
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
            _buildPerkDisplay(context, perkMap[slots[index]]!, borderColor),
          ],
          const SizedBox(height: 12),
        ],
        if (remaining > 0)
          Text('$remaining pick${remaining == 1 ? '' : 's'} remaining.'),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildPerkDisplay(
    BuildContext context,
    model.Component perk,
    Color borderColor, {
    bool showRemove = false,
  }) {
    final grantsRaw = perk.data['grants'];
    final grants =
        grantsRaw is List ? grantsRaw : (grantsRaw is Map ? [grantsRaw] : null);

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
          Row(
            children: [
              Expanded(
                child: Text(
                  perk.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: borderColor,
                    fontSize: 15,
                  ),
                ),
              ),
              if (showRemove)
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: borderColor),
                  onPressed: () => _removePerk(perk.id, perk.name),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            perk.data['description']?.toString() ?? 'No description available',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
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
            const SizedBox(height: 8),
            _PerkGrantsDisplay(
              heroId: widget.heroId,
              perkId: perk.id,
              grants: grants,
              accentColor: borderColor,
              languages: widget.languages,
              skills: widget.skills,
              reservedLanguageIds: widget.reservedLanguageIds,
              reservedSkillIds: widget.reservedSkillIds,
              onDirty: widget.onDirty ?? () {},
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _removePerk(String perkId, String perkName) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Perk'),
        content: Text('Are you sure you want to remove "$perkName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final newSelection = Set<String>.from(widget.selectedPerkIds)
      ..remove(perkId);
    await _applySelectionChange(newSelection, {perkId}, perkMap: null);
  }

  Future<void> _openSearchForPerkIndex(
    BuildContext context,
    int index,
    List<String?> currentSlots,
    Map<String, model.Component> perkMap,
    Map<String, List<model.Component>> grouped,
    List<String> sortedGroupKeys,
    Color borderColor,
  ) async {
    final options = _buildSearchOptionsForPerkIndex(
      index,
      currentSlots,
      perkMap,
      grouped,
      sortedGroupKeys,
    );

    final result = await showSearchablePicker<String?>(
      context: context,
      title: 'Select Perk',
      options: options,
      selected: currentSlots[index],
    );

    if (result == null) return;

    final updated = List<String?>.from(currentSlots);
    updated[index] = result.value;

    // Remove duplicates
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
    final removed = Set<String>.from(widget.selectedPerkIds)..removeAll(next);
    await _applySelectionChange(next, removed, perkMap: perkMap);
  }

  Future<void> _openAddPerkPicker(
    BuildContext context,
    List<String> currentSelections,
    Map<String, model.Component> perkMap,
    Map<String, List<model.Component>> grouped,
    List<String> sortedGroupKeys,
    Color borderColor,
  ) async {
    final excludedIds = <String>{
      ...widget.reservedPerkIds,
      ...currentSelections,
    };

    final options = <SearchOption<String?>>[
      const SearchOption<String?>(
        label: '— Choose perk —',
        value: null,
      ),
    ];

    for (final key in sortedGroupKeys) {
      for (final perk in grouped[key]!) {
        if (excludedIds.contains(perk.id)) {
          continue;
        }
        options.add(
          SearchOption<String?>(
            label: perk.name,
            value: perk.id,
            subtitle: key,
          ),
        );
      }
    }

    final result = await showSearchablePicker<String?>(
      context: context,
      title: 'Add Perk',
      options: options,
      selected: null,
    );

    if (result == null || result.value == null) return;

    final newSelection = Set<String>.from(widget.selectedPerkIds)
      ..add(result.value!);
    await _applySelectionChange(newSelection, const {}, perkMap: perkMap);
  }

  List<SearchOption<String?>> _buildSearchOptionsForPerkIndex(
    int currentIndex,
    List<String?> slots,
    Map<String, model.Component> perkMap,
    Map<String, List<model.Component>> grouped,
    List<String> sortedGroupKeys,
  ) {
    final options = <SearchOption<String?>>[
      const SearchOption<String?>(
        label: '— Choose perk —',
        value: null,
      ),
    ];

    final excludedIds = <String>{...widget.reservedPerkIds};
    for (var i = 0; i < slots.length; i++) {
      if (i == currentIndex) continue;
      final pick = slots[i];
      if (pick != null) {
        excludedIds.add(pick);
      }
    }

    for (final key in sortedGroupKeys) {
      for (final perk in grouped[key]!) {
        if (_isBlocked(perk.id, excludedIds, currentId: slots[currentIndex])) {
          continue;
        }
        options.add(
          SearchOption<String?>(
            label: perk.name,
            value: perk.id,
            subtitle: key,
          ),
        );
      }
    }

    return options;
  }

  bool _isBlocked(String id, Set<String> blocked, {String? currentId}) {
    if (id == currentId) return false;
    return blocked.contains(id);
  }

  Future<void> _ensureExistingPerkGrants() async {
    if (_appliedInitialGrants) return;
    // Only apply grants if persistToDatabase is enabled
    if (!widget.persistToDatabase) {
      _appliedInitialGrants = true;
      return;
    }
    if (widget.heroId.isEmpty) return;
    if (widget.selectedPerkIds.isEmpty) {
      _appliedInitialGrants = true;
      return;
    }

    final db = ref.read(appDatabaseProvider);
    for (final perkId in widget.selectedPerkIds) {
      final component = await _loadPerkComponent(perkId, null, db);
      if (component == null) continue;
      await PerkGrantsService().applyPerkGrants(
        db: db,
        heroId: widget.heroId,
        perkId: perkId,
        grantsJson: component.data['grants'],
      );
    }
    _appliedInitialGrants = true;
  }

  Future<void> _applySelectionChange(
    Set<String> next,
    Set<String> removed, {
    Map<String, model.Component>? perkMap,
  }) async {
    final added = next.difference(widget.selectedPerkIds);

    // Only persist to database and apply grants if persistToDatabase is enabled
    if (widget.persistToDatabase && widget.heroId.isNotEmpty) {
      final db = ref.read(appDatabaseProvider);

      // Persist the current perk list
      await db.setHeroComponentIds(
        heroId: widget.heroId,
        category: 'perk',
        componentIds: next.toList(),
      );

      // Apply grants for newly added perks (abilities)
      for (final perkId in added) {
        final component = await _loadPerkComponent(perkId, perkMap, db);
        if (component == null) continue;
        await PerkGrantsService().applyPerkGrants(
          db: db,
          heroId: widget.heroId,
          perkId: perkId,
          grantsJson: component.data['grants'],
        );
      }

      // Remove grants from removed perks
      for (final perkId in removed) {
        await PerkGrantsService().removePerkGrants(
          db: db,
          heroId: widget.heroId,
          perkId: perkId,
        );
      }
    }

    widget.onSelectionChanged?.call(next);
    widget.onDirty?.call();
  }

  Future<model.Component?> _loadPerkComponent(
    String perkId,
    Map<String, model.Component>? perkMap,
    dynamic db,
  ) async {
    if (perkMap != null && perkMap.containsKey(perkId)) {
      return perkMap[perkId];
    }
    final row = await db.getComponentById(perkId);
    if (row == null) return null;
    Map<String, dynamic> data = {};
    if (row.dataJson != null && row.dataJson.isNotEmpty) {
      data = jsonDecode(row.dataJson) as Map<String, dynamic>;
    } else if (row.data != null) {
      data = Map<String, dynamic>.from(row.data as Map);
    }
    return model.Component(
      id: row.id,
      type: row.type,
      name: row.name,
      data: data,
    );
  }
}

/// A widget that displays the granted abilities/skills/languages for a perk.
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
          _buildGrantItem(
              context, ref, grant, textColor, languageMap, skillMap),
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
        child: Text('• ${grant.toString()}',
            style: TextStyle(fontSize: 12, color: textColor)),
      );
    }

    if (grant.containsKey('ability')) {
      return _buildAbilityGrant(
          context, ref, grant['ability'] as String?, textColor);
    }

    if (grant.containsKey('languages')) {
      final count = _parseCount(grant['languages']);
      return _buildLanguageGrant(context, ref, count, textColor, languageMap);
    }

    if (grant.containsKey('skill')) {
      final skillData = grant['skill'];
      if (skillData is Map) {
        return _buildSkillGrant(context, ref,
            Map<String, dynamic>.from(skillData), textColor, skillMap);
      }
    }

    final formatted =
        grant.entries.map((e) => '${e.key}: ${e.value}').join(', ');
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
      return _buildGrantRow(
          'Choose ${count == 1 ? 'a' : count} new language${count == 1 ? '' : 's'}.',
          textColor);
    }

    final choicesAsync =
        ref.watch(perkGrantChoicesProvider((heroId: heroId, perkId: perkId)));
    return choicesAsync.when(
      data: (choices) {
        final selected = List<String>.from(choices['language'] ?? const []);
        final widgets = <Widget>[];
        for (var index = 0; index < count; index++) {
          final selectedId = index < selected.length ? selected[index] : null;
          final label =
              count == 1 ? 'Language Choice' : 'Language Choice ${index + 1}';
          widgets.add(
            _buildPickerField(
              context: context,
              label: label,
              placeholder: '— Choose language —',
              selectedName:
                  selectedId != null ? languageMap[selectedId]?.name : null,
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
        return Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
      },
      loading: () => _buildLoadingRow(textColor, 'Loading languages...'),
      error: (e, _) =>
          _buildGrantRow('Failed to load languages: $e', textColor),
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

    return _buildSkillPickGrant(
        context, ref, group, count, textColor, skillMap);
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
      return skillGroup == normalizedGroup &&
          reservedSkillIds.contains(skill.id);
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (owned.isEmpty) {
      return _buildGrantRow(
          'No ${_capitalize(group)} skills known yet.', textColor);
    }

    final choicesAsync =
        ref.watch(perkGrantChoicesProvider((heroId: heroId, perkId: perkId)));
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
      return skillGroup == normalizedGroup &&
          !reservedSkillIds.contains(skill.id);
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (available.isEmpty) {
      return _buildGrantRow(
          'No ${_capitalize(group)} skills available to learn.', textColor);
    }

    final choicesAsync =
        ref.watch(perkGrantChoicesProvider((heroId: heroId, perkId: perkId)));
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
              selectedName:
                  selectedId != null ? skillMap[selectedId]?.name : null,
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
        return Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            suffixIcon: const Icon(Icons.search),
          ),
          child: Text(
            selectedName ?? placeholder,
            style: TextStyle(
              fontSize: 14,
              color: selectedName != null
                  ? theme.textTheme.bodyLarge?.color
                  : hintColor,
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
    final result = await showSearchablePicker<String?>(
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
    final result = await showSearchablePicker<String?>(
      context: context,
      title: 'Select ${_capitalize(group)} Skill',
      options: options,
      selected: currentSelectedId,
    );
    if (result == null) return;
    final updated = _updatedChoiceList(currentChoices, slotIndex, result.value);
    await _saveGrantChoice(ref, grantType, updated);
  }

  List<SearchOption<String?>> _buildLanguageOptions(
      Set<String> exclude, String? currentSelectedId) {
    final grouped = <String, List<model.Component>>{};
    for (final lang in languages) {
      final type =
          (lang.data['language_type'] as String?)?.toLowerCase() ?? 'human';
      grouped.putIfAbsent(type, () => []).add(lang);
    }
    for (final group in grouped.values) {
      group.sort((a, b) => a.name.compareTo(b.name));
    }

    final options = <SearchOption<String?>>[
      const SearchOption<String?>(label: '— Choose language —', value: null),
    ];

    for (final entry in grouped.entries) {
      for (final lang in entry.value) {
        if (lang.id != currentSelectedId && exclude.contains(lang.id)) {
          continue;
        }
        options.add(
          SearchOption<String?>(
            label: lang.name,
            value: lang.id,
            subtitle: _languageGroupTitle(entry.key),
          ),
        );
      }
    }
    return options;
  }

  List<SearchOption<String?>> _buildSkillOptions({
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
      return !reservedSkillIds.contains(skill.id) ||
          skill.id == currentSelectedId;
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final options = <SearchOption<String?>>[
      const SearchOption<String?>(label: '— Choose skill —', value: null),
    ];

    for (final skill in source) {
      if (skill.id != currentSelectedId && exclude.contains(skill.id)) continue;
      options.add(SearchOption<String?>(label: skill.name, value: skill.id));
    }
    return options;
  }

  List<String> _updatedChoiceList(
      List<String> currentChoices, int slotIndex, String? newValue) {
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
    ref.invalidate(perkGrantChoicesProvider((heroId: heroId, perkId: perkId)));
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
            child:
                CircularProgressIndicator(strokeWidth: 1.5, color: accentColor),
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

// ============================================================================
// Searchable Picker - Reusable component
// ============================================================================

/// Represents an option in the searchable picker
class SearchOption<T> {
  const SearchOption({
    required this.label,
    required this.value,
    this.subtitle,
  });

  final String label;
  final T? value;
  final String? subtitle;
}

/// Result of a picker selection
class PickerSelection<T> {
  const PickerSelection({required this.value});

  final T? value;
}

/// Shows a searchable picker dialog
Future<PickerSelection<T>?> showSearchablePicker<T>({
  required BuildContext context,
  required String title,
  required List<SearchOption<T>> options,
  T? selected,
}) {
  return showDialog<PickerSelection<T>>(
    context: context,
    builder: (dialogContext) {
      final controller = TextEditingController();
      var query = '';

      return StatefulBuilder(
        builder: (context, setState) {
          final normalizedQuery = query.trim().toLowerCase();
          final List<SearchOption<T>> filtered = normalizedQuery.isEmpty
              ? options
              : options
                  .where(
                    (option) =>
                        option.label.toLowerCase().contains(normalizedQuery) ||
                        (option.subtitle
                                ?.toLowerCase()
                                .contains(normalizedQuery) ??
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
                                trailing:
                                    isSelected ? const Icon(Icons.check) : null,
                                onTap: () => Navigator.of(context).pop(
                                  PickerSelection<T>(value: option.value),
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
