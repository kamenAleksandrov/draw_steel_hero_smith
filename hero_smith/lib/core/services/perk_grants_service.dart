import 'dart:convert';

import 'package:flutter/services.dart';

import '../db/app_database.dart';
import '../models/component.dart' as model;

/// Represents a parsed perk grant
sealed class PerkGrant {
  const PerkGrant();
  
  /// Parse a grant from JSON data
  static PerkGrant? fromJson(dynamic json) {
    if (json == null) return null;
    
    // Handle list of grants (e.g., [{"ability": "Friend Catapult"}])
    if (json is List) {
      if (json.isEmpty) return null;
      // For now, handle single-item lists
      if (json.length == 1) {
        return fromJson(json.first);
      }
      // Multiple grants in a list
      final grants = json.map((e) => fromJson(e)).whereType<PerkGrant>().toList();
      if (grants.isEmpty) return null;
      if (grants.length == 1) return grants.first;
      return MultiGrant(grants);
    }
    
    if (json is! Map) return null;
    
    // Check for ability grant
    if (json.containsKey('ability')) {
      return AbilityGrant(json['ability'] as String);
    }
    
    // Check for creature grant (save for later)
    if (json.containsKey('creature')) {
      return CreatureGrant(json['creature'] as String);
    }
    
    // Check for skill grant
    if (json.containsKey('skill')) {
      final skillData = json['skill'];
      if (skillData is Map) {
        final group = skillData['group'] as String?;
        final count = skillData['count'];
        
        if (count == 'one_owned') {
          // User picks one skill they already have from that group
          return SkillFromOwnedGrant(group: group ?? '');
        } else {
          // User picks new skill(s) from that group
          final pickCount = count is int ? count : int.tryParse(count?.toString() ?? '1') ?? 1;
          return SkillPickGrant(group: group ?? '', count: pickCount);
        }
      }
    }
    
    // Check for languages grant
    if (json.containsKey('languages')) {
      final count = json['languages'];
      final pickCount = count is int ? count : int.tryParse(count?.toString() ?? '1') ?? 1;
      return LanguageGrant(count: pickCount);
    }
    
    return null;
  }
}

/// Grant that provides an ability
class AbilityGrant extends PerkGrant {
  final String abilityName;
  const AbilityGrant(this.abilityName);
}

/// Grant that provides a creature (e.g., Familiar) - for later implementation
class CreatureGrant extends PerkGrant {
  final String creatureName;
  const CreatureGrant(this.creatureName);
}

/// Grant that requires user to choose one skill they already own from a group
class SkillFromOwnedGrant extends PerkGrant {
  final String group;
  const SkillFromOwnedGrant({required this.group});
}

/// Grant that lets user pick new skill(s) from a group
class SkillPickGrant extends PerkGrant {
  final String group;
  final int count;
  const SkillPickGrant({required this.group, required this.count});
}

/// Grant that lets user pick new language(s)
class LanguageGrant extends PerkGrant {
  final int count;
  const LanguageGrant({required this.count});
}

/// Multiple grants in one perk
class MultiGrant extends PerkGrant {
  final List<PerkGrant> grants;
  const MultiGrant(this.grants);
}

/// Service to handle perk grant choices
class PerkGrantsService {
  PerkGrantsService._();
  
  static final PerkGrantsService _instance = PerkGrantsService._();
  factory PerkGrantsService() => _instance;
  
  List<Map<String, dynamic>>? _cachedSkills;
  List<Map<String, dynamic>>? _cachedLanguages;
  List<Map<String, dynamic>>? _cachedPerkAbilities;
  
  /// Load all skills from JSON
  Future<List<Map<String, dynamic>>> loadSkills() async {
    if (_cachedSkills != null) return _cachedSkills!;
    
    final raw = await rootBundle.loadString('data/story/skills.json');
    final decoded = json.decode(raw) as List;
    _cachedSkills = decoded.cast<Map<String, dynamic>>();
    return _cachedSkills!;
  }
  
  /// Load all languages from JSON
  Future<List<Map<String, dynamic>>> loadLanguages() async {
    if (_cachedLanguages != null) return _cachedLanguages!;
    
    final raw = await rootBundle.loadString('data/story/languages.json');
    final decoded = json.decode(raw) as List;
    _cachedLanguages = decoded.cast<Map<String, dynamic>>();
    return _cachedLanguages!;
  }
  
  /// Load perk abilities from JSON
  Future<List<Map<String, dynamic>>> loadPerkAbilities() async {
    if (_cachedPerkAbilities != null) return _cachedPerkAbilities!;
    
    final raw = await rootBundle.loadString('data/abilities/perk_abilities.json');
    final decoded = json.decode(raw) as List;
    _cachedPerkAbilities = decoded.cast<Map<String, dynamic>>();
    return _cachedPerkAbilities!;
  }
  
  /// Get skills by group
  Future<List<Map<String, dynamic>>> getSkillsByGroup(String group) async {
    final skills = await loadSkills();
    return skills.where((s) => 
      (s['group'] as String?)?.toLowerCase() == group.toLowerCase()
    ).toList();
  }
  
  /// Normalize ability names for comparisons (handles punctuation differences)
  String _normalizeAbilityName(String value) {
    final lower = value.trim().toLowerCase();
    return lower
        .replaceAll('\u2019', "'") // apostrophe right
        .replaceAll('\u2018', "'") // apostrophe left
        .replaceAll('\u201C', '"')
        .replaceAll('\u201D', '"');
  }

  /// Get a perk ability by name
  Future<Map<String, dynamic>?> getPerkAbilityByName(String name) async {
    final abilities = await loadPerkAbilities();
    final normalizedTarget = _normalizeAbilityName(name);

    for (final ability in abilities) {
      final abilityName = ability['name'];
      if (abilityName is! String) continue;
      if (_normalizeAbilityName(abilityName) == normalizedTarget) {
        return ability;
      }
    }
    return null;
  }
  
  // --- Hero-specific grant choice storage ---
  
  /// Key format: perk_grant.<perk_id>.<grant_type>
  static String _grantChoiceKey(String perkId, String grantType) =>
    'perk_grant.$perkId.$grantType';
  
  /// Save a perk grant choice for a hero
  Future<void> saveGrantChoice({
    required AppDatabase db,
    required String heroId,
    required String perkId,
    required String grantType,
    required List<String> chosenIds,
  }) async {
    final key = _grantChoiceKey(perkId, grantType);
    await db.upsertHeroValue(
      heroId: heroId,
      key: key,
      jsonMap: {'list': chosenIds},
    );
  }
  
  /// Get a perk grant choice for a hero
  Future<List<String>> getGrantChoice({
    required AppDatabase db,
    required String heroId,
    required String perkId,
    required String grantType,
  }) async {
    final key = _grantChoiceKey(perkId, grantType);
    final values = await db.getHeroValues(heroId);
    
    for (final value in values) {
      if (value.key == key) {
        final jsonStr = value.jsonValue;
        if (jsonStr != null) {
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          if (map['list'] is List) {
            return (map['list'] as List).cast<String>();
          }
        }
      }
    }
    return [];
  }
  
  /// Get all grant choices for a hero (for a specific perk)
  Future<Map<String, List<String>>> getAllGrantChoicesForPerk({
    required AppDatabase db,
    required String heroId,
    required String perkId,
  }) async {
    final prefix = 'perk_grant.$perkId.';
    final values = await db.getHeroValues(heroId);
    final result = <String, List<String>>{};
    
    for (final value in values) {
      if (value.key.startsWith(prefix)) {
        final grantType = value.key.substring(prefix.length);
        final jsonStr = value.jsonValue;
        if (jsonStr != null) {
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          if (map['list'] is List) {
            result[grantType] = (map['list'] as List).cast<String>();
          }
        }
      }
    }
    return result;
  }
  
  /// Get hero's current skills
  Future<List<String>> getHeroSkillIds({
    required AppDatabase db,
    required String heroId,
  }) async {
    return await db.getHeroComponentIds(heroId, 'skill');
  }
  
  /// Get hero's current languages
  Future<List<String>> getHeroLanguageIds({
    required AppDatabase db,
    required String heroId,
  }) async {
    return await db.getHeroComponentIds(heroId, 'language');
  }
  
  /// Ensure all perk grants are applied for a hero.
  /// This is useful when viewing the abilities sheet to make sure any
  /// perk-granted abilities are properly registered in the hero's abilities.
  Future<void> ensureAllPerkGrantsApplied({
    required AppDatabase db,
    required String heroId,
  }) async {
    // Get all perk IDs for this hero
    final perkIds = await db.getHeroComponentIds(heroId, 'perk');
    if (perkIds.isEmpty) return;
    
    // Get all perk components
    final allComponents = await db.getAllComponents();
    final perkComponents = allComponents
        .where((c) => c.type == 'perk' && perkIds.contains(c.id))
        .toList();
    
    // Apply grants for each perk
    for (final perkComp in perkComponents) {
      try {
        Map<String, dynamic> data = {};
        if (perkComp.dataJson != null && perkComp.dataJson.isNotEmpty) {
          data = jsonDecode(perkComp.dataJson) as Map<String, dynamic>;
        }
        final grantsJson = data['grants'];
        if (grantsJson != null) {
          await applyPerkGrants(
            db: db,
            heroId: heroId,
            perkId: perkComp.id,
            grantsJson: grantsJson,
          );
        }
      } catch (_) {
        // Skip if perk data is invalid
      }
    }
  }
  
  // =========================================================================
  // Methods to persist perk grants to hero component collections
  // =========================================================================
  
  /// Apply all grants from a perk when it is selected.
  /// This adds any ability grants to the hero's ability components.
  Future<void> applyPerkGrants({
    required AppDatabase db,
    required String heroId,
    required String perkId,
    required dynamic grantsJson,
  }) async {
    final grant = PerkGrant.fromJson(grantsJson);
    if (grant == null) return;
    
    final abilityNames = <String>[];
    _collectAbilityNames(grant, abilityNames);
    
    if (abilityNames.isEmpty) return;
    
    // Find ability IDs from the database or perk_abilities.json
    final abilityIds = await _resolveAbilityIds(db, abilityNames);
    if (abilityIds.isEmpty) return;
    
    // Track which abilities came from this perk
    await _savePerkAbilityGrants(db, heroId, perkId, abilityIds);
    
    // Add to hero's ability components (merge with existing)
    await _addToHeroAbilities(db, heroId, abilityIds);
  }
  
  /// Remove all grants from a perk when it is deselected.
  Future<void> removePerkGrants({
    required AppDatabase db,
    required String heroId,
    required String perkId,
  }) async {
    // Get the abilities that were granted by this perk
    final grantedAbilityIds = await _loadPerkAbilityGrants(db, heroId, perkId);
    
    // Remove the ability grant tracking
    await _clearPerkAbilityGrants(db, heroId, perkId);
    
    // Get languages/skills granted by this perk
    final grantedLanguageIds = await getGrantChoice(
      db: db, heroId: heroId, perkId: perkId, grantType: 'language',
    );
    final grantedSkillPickIds = await getGrantChoice(
      db: db, heroId: heroId, perkId: perkId, grantType: 'skill_pick',
    );
    
    // Clear all grant choices for this perk
    await _clearAllGrantChoicesForPerk(db, heroId, perkId);
    
    // Remove abilities from hero (only if not granted by other perks)
    if (grantedAbilityIds.isNotEmpty) {
      await _removeFromHeroAbilities(db, heroId, grantedAbilityIds, perkId);
    }
    
    // Remove languages from hero
    if (grantedLanguageIds.isNotEmpty) {
      await _removeFromHeroLanguages(db, heroId, grantedLanguageIds, perkId);
    }
    
    // Remove skill picks from hero (not skill_owned, those are already owned)
    if (grantedSkillPickIds.isNotEmpty) {
      await _removeFromHeroSkills(db, heroId, grantedSkillPickIds, perkId);
    }
  }
  
  /// Save a perk grant choice and also update hero components.
  Future<void> saveGrantChoiceAndApply({
    required AppDatabase db,
    required String heroId,
    required String perkId,
    required String grantType,
    required List<String> chosenIds,
  }) async {
    // Get previous choices to determine what to remove
    final previousChoices = await getGrantChoice(
      db: db, heroId: heroId, perkId: perkId, grantType: grantType,
    );
    
    // Save the new choices
    await saveGrantChoice(
      db: db, heroId: heroId, perkId: perkId, grantType: grantType, chosenIds: chosenIds,
    );
    
    // Determine what was added and removed
    final added = chosenIds.where((id) => !previousChoices.contains(id)).toList();
    final removed = previousChoices.where((id) => !chosenIds.contains(id)).toList();
    
    // Apply changes to hero components
    if (grantType == 'language') {
      if (removed.isNotEmpty) {
        await _removeFromHeroLanguages(db, heroId, removed, perkId);
      }
      if (added.isNotEmpty) {
        await _addToHeroLanguages(db, heroId, added);
      }
    } else if (grantType == 'skill_pick') {
      // New skills being learned
      if (removed.isNotEmpty) {
        await _removeFromHeroSkills(db, heroId, removed, perkId);
      }
      if (added.isNotEmpty) {
        await _addToHeroSkills(db, heroId, added);
      }
    }
    // skill_owned doesn't add new skills, just tracks selection
  }
  
  // --- Private helpers for ability grants ---
  
  void _collectAbilityNames(PerkGrant grant, List<String> names) {
    switch (grant) {
      case AbilityGrant(:final abilityName):
        names.add(abilityName);
      case MultiGrant(:final grants):
        for (final g in grants) {
          _collectAbilityNames(g, names);
        }
      default:
        break;
    }
  }
  
  Future<List<String>> _resolveAbilityIds(AppDatabase db, List<String> names) async {
    final ids = <String>[];
    final allComponents = await db.getAllComponents();
    
    for (final name in names) {
      final normalizedName = _normalizeAbilityName(name);
      
      // First try to find in database
      final dbMatch = allComponents.where((c) {
        if (c.type != 'ability') return false;
        return _normalizeAbilityName(c.name) == normalizedName;
      }).firstOrNull;
      
      if (dbMatch != null) {
        ids.add(dbMatch.id);
        continue;
      }
      
      // Try to find in perk_abilities.json
      final perkAbility = await getPerkAbilityByName(name);
      if (perkAbility != null) {
        final id = perkAbility['id'] as String?;
        if (id != null && id.isNotEmpty) {
          ids.add(id);
          // Ensure this ability exists in the database
          await _ensurePerkAbilityInDb(db, perkAbility);
        }
      }
    }
    return ids;
  }
  
  Future<void> _ensurePerkAbilityInDb(AppDatabase db, Map<String, dynamic> abilityData) async {
    final id = abilityData['id'] as String?;
    if (id == null || id.isEmpty) return;
    
    // Check if already exists
    final existing = await db.getComponentById(id);
    if (existing != null) return;
    
    // Create the component
    final component = model.Component(
      id: id,
      type: 'ability',
      name: abilityData['name'] as String? ?? id,
      data: Map<String, dynamic>.from(abilityData),
    );
    await db.insertComponent(component);
  }
  
  static const _kPerkAbilitiesPrefix = 'perk_abilities.';
  
  Future<void> _savePerkAbilityGrants(
    AppDatabase db, String heroId, String perkId, List<String> abilityIds,
  ) async {
    await db.upsertHeroValue(
      heroId: heroId,
      key: '$_kPerkAbilitiesPrefix$perkId',
      jsonMap: {'list': abilityIds},
    );
  }
  
  Future<List<String>> _loadPerkAbilityGrants(
    AppDatabase db, String heroId, String perkId,
  ) async {
    final values = await db.getHeroValues(heroId);
    for (final value in values) {
      if (value.key == '$_kPerkAbilitiesPrefix$perkId') {
        final jsonStr = value.jsonValue;
        if (jsonStr != null) {
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          if (map['list'] is List) {
            return (map['list'] as List).cast<String>();
          }
        }
      }
    }
    return [];
  }
  
  Future<void> _clearPerkAbilityGrants(
    AppDatabase db, String heroId, String perkId,
  ) async {
    await db.deleteHeroValue(heroId: heroId, key: '$_kPerkAbilitiesPrefix$perkId');
  }
  
  Future<void> _clearAllGrantChoicesForPerk(
    AppDatabase db, String heroId, String perkId,
  ) async {
    final prefix = 'perk_grant.$perkId.';
    final values = await db.getHeroValues(heroId);
    for (final value in values) {
      if (value.key.startsWith(prefix)) {
        await db.deleteHeroValue(heroId: heroId, key: value.key);
      }
    }
  }
  
  // --- Private helpers for hero components ---
  
  Future<void> _addToHeroAbilities(AppDatabase db, String heroId, List<String> abilityIds) async {
    final current = await db.getHeroComponentIds(heroId, 'ability');
    final merged = {...current, ...abilityIds}.toList();
    await db.setHeroComponentIds(heroId: heroId, category: 'ability', componentIds: merged);
  }
  
  Future<void> _removeFromHeroAbilities(
    AppDatabase db, String heroId, List<String> abilityIds, String excludePerkId,
  ) async {
    // Check if any of these abilities are granted by other perks
    final values = await db.getHeroValues(heroId);
    final stillGranted = <String>{};
    
    for (final value in values) {
      if (value.key.startsWith(_kPerkAbilitiesPrefix) && 
          value.key != '$_kPerkAbilitiesPrefix$excludePerkId') {
        final jsonStr = value.jsonValue;
        if (jsonStr != null) {
          try {
            final map = jsonDecode(jsonStr) as Map<String, dynamic>;
            if (map['list'] is List) {
              stillGranted.addAll((map['list'] as List).cast<String>());
            }
          } catch (_) {}
        }
      }
    }
    
    // Only remove abilities not granted by other perks
    final toRemove = abilityIds.where((id) => !stillGranted.contains(id)).toSet();
    if (toRemove.isEmpty) return;
    
    final current = await db.getHeroComponentIds(heroId, 'ability');
    final updated = current.where((id) => !toRemove.contains(id)).toList();
    await db.setHeroComponentIds(heroId: heroId, category: 'ability', componentIds: updated);
  }
  
  Future<void> _addToHeroLanguages(AppDatabase db, String heroId, List<String> languageIds) async {
    final current = await db.getHeroComponentIds(heroId, 'language');
    final merged = {...current, ...languageIds}.toList();
    await db.setHeroComponentIds(heroId: heroId, category: 'language', componentIds: merged);
  }
  
  Future<void> _removeFromHeroLanguages(
    AppDatabase db, String heroId, List<String> languageIds, String excludePerkId,
  ) async {
    // Check if any of these languages are granted by other perks
    final values = await db.getHeroValues(heroId);
    final stillGranted = <String>{};
    
    for (final value in values) {
      if (value.key.startsWith('perk_grant.') && 
          value.key.endsWith('.language') &&
          !value.key.startsWith('perk_grant.$excludePerkId.')) {
        final jsonStr = value.jsonValue;
        if (jsonStr != null) {
          try {
            final map = jsonDecode(jsonStr) as Map<String, dynamic>;
            if (map['list'] is List) {
              stillGranted.addAll((map['list'] as List).cast<String>());
            }
          } catch (_) {}
        }
      }
    }
    
    // Only remove languages not granted by other perks
    final toRemove = languageIds.where((id) => !stillGranted.contains(id)).toSet();
    if (toRemove.isEmpty) return;
    
    final current = await db.getHeroComponentIds(heroId, 'language');
    final updated = current.where((id) => !toRemove.contains(id)).toList();
    await db.setHeroComponentIds(heroId: heroId, category: 'language', componentIds: updated);
  }
  
  Future<void> _addToHeroSkills(AppDatabase db, String heroId, List<String> skillIds) async {
    final current = await db.getHeroComponentIds(heroId, 'skill');
    final merged = {...current, ...skillIds}.toList();
    await db.setHeroComponentIds(heroId: heroId, category: 'skill', componentIds: merged);
  }
  
  Future<void> _removeFromHeroSkills(
    AppDatabase db, String heroId, List<String> skillIds, String excludePerkId,
  ) async {
    // Check if any of these skills are granted by other perks
    final values = await db.getHeroValues(heroId);
    final stillGranted = <String>{};
    
    for (final value in values) {
      if (value.key.startsWith('perk_grant.') && 
          value.key.endsWith('.skill_pick') &&
          !value.key.startsWith('perk_grant.$excludePerkId.')) {
        final jsonStr = value.jsonValue;
        if (jsonStr != null) {
          try {
            final map = jsonDecode(jsonStr) as Map<String, dynamic>;
            if (map['list'] is List) {
              stillGranted.addAll((map['list'] as List).cast<String>());
            }
          } catch (_) {}
        }
      }
    }
    
    // Only remove skills not granted by other perks
    final toRemove = skillIds.where((id) => !stillGranted.contains(id)).toSet();
    if (toRemove.isEmpty) return;
    
    final current = await db.getHeroComponentIds(heroId, 'skill');
    final updated = current.where((id) => !toRemove.contains(id)).toList();
    await db.setHeroComponentIds(heroId: heroId, category: 'skill', componentIds: updated);
  }
}
