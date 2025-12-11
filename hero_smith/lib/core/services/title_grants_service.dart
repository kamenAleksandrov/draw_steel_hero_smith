import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/services.dart';

import '../db/app_database.dart';
import '../repositories/hero_entry_repository.dart';

/// Service to handle title grant processing.
/// 
/// Titles can grant abilities through their selected benefit.
/// This service writes ability entries to hero_entries with sourceType='title'.
class TitleGrantsService {
  TitleGrantsService._();
  
  static final TitleGrantsService _instance = TitleGrantsService._();
  factory TitleGrantsService() => _instance;
  
  List<Map<String, dynamic>>? _cachedTitles;
  List<Map<String, dynamic>>? _cachedTitleAbilities;
  
  /// Load all titles from JSON
  Future<List<Map<String, dynamic>>> loadTitles() async {
    if (_cachedTitles != null) return _cachedTitles!;
    
    final raw = await rootBundle.loadString('data/story/titles.json');
    final decoded = json.decode(raw) as List;
    _cachedTitles = decoded.cast<Map<String, dynamic>>();
    return _cachedTitles!;
  }
  
  /// Load title abilities from JSON
  Future<List<Map<String, dynamic>>> loadTitleAbilities() async {
    if (_cachedTitleAbilities != null) return _cachedTitleAbilities!;
    
    try {
      final raw = await rootBundle.loadString('data/abilities/titles_abilities.json');
      final decoded = json.decode(raw) as List;
      _cachedTitleAbilities = decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      _cachedTitleAbilities = [];
    }
    return _cachedTitleAbilities!;
  }
  
  /// Get a title by ID
  Future<Map<String, dynamic>?> getTitleById(String titleId) async {
    final titles = await loadTitles();
    return titles.firstWhereOrNull((t) => t['id'] == titleId);
  }
  
  /// Get the ability ID for a title benefit, if it grants one
  Future<String?> getAbilityIdForBenefit(
    Map<String, dynamic> title, 
    int benefitIndex,
  ) async {
    final benefits = title['benefits'] as List?;
    if (benefits == null || benefitIndex >= benefits.length) return null;
    
    final benefit = benefits[benefitIndex] as Map<String, dynamic>?;
    if (benefit == null) return null;
    
    final abilityRef = benefit['ability'];
    if (abilityRef == null || abilityRef.toString().isEmpty) return null;
    
    final abilitySlug = abilityRef.toString();
    return await _resolveAbilityId(abilitySlug);
  }
  
  /// Apply title grants for a hero.
  /// 
  /// Takes a list of selected titles in format "titleId:benefitIndex"
  /// and writes any granted abilities to hero_entries.
  Future<void> applyTitleGrants({
    required AppDatabase db,
    required String heroId,
    required List<String> selectedTitleIds,
  }) async {
    final entries = HeroEntryRepository(db);
    
    // First clear all existing title-granted abilities
    await entries.removeEntriesFromSource(
      heroId: heroId,
      sourceType: 'title',
    );
    
    // Process each selected title
    for (final selection in selectedTitleIds) {
      final parts = selection.split(':');
      if (parts.length != 2) continue;
      
      final titleId = parts[0];
      final benefitIndex = int.tryParse(parts[1]) ?? 0;
      
      final title = await getTitleById(titleId);
      if (title == null) continue;
      
      final abilityId = await getAbilityIdForBenefit(title, benefitIndex);
      if (abilityId == null || abilityId.isEmpty) continue;
      
      // Ensure ability exists in database
      await _ensureAbilityInDb(db, abilityId);
      
      // Write ability entry with title as source
      await entries.addEntry(
        heroId: heroId,
        entryType: 'ability',
        entryId: abilityId,
        sourceType: 'title',
        sourceId: titleId,
        gainedBy: 'grant',
        payload: {
          'benefitIndex': benefitIndex,
          'titleName': title['name'],
        },
      );
    }
  }
  
  /// Remove all title grants for a hero.
  Future<void> removeTitleGrants({
    required AppDatabase db,
    required String heroId,
  }) async {
    final entries = HeroEntryRepository(db);
    await entries.removeEntriesFromSource(
      heroId: heroId,
      sourceType: 'title',
    );
  }
  
  /// Remove grants for a specific title.
  Future<void> removeTitleGrantsForTitle({
    required AppDatabase db,
    required String heroId,
    required String titleId,
  }) async {
    final entries = HeroEntryRepository(db);
    await entries.removeEntriesFromSource(
      heroId: heroId,
      sourceType: 'title',
      sourceId: titleId,
    );
  }
  
  /// Get all abilities granted by titles for a hero.
  Future<List<String>> getGrantedAbilities({
    required AppDatabase db,
    required String heroId,
  }) async {
    final entries = HeroEntryRepository(db);
    final all = await entries.listEntriesByType(heroId, 'ability');
    return all
        .where((e) => e.sourceType == 'title')
        .map((e) => e.entryId)
        .toList();
  }
  
  // Private helpers
  
  Future<String> _resolveAbilityId(String abilityRef) async {
    // First check title abilities
    final titleAbilities = await loadTitleAbilities();
    
    // Try by ID first
    final byId = titleAbilities.firstWhereOrNull(
      (a) => a['id']?.toString() == abilityRef,
    );
    if (byId != null) return byId['id'].toString();
    
    // Try by slug match
    final normalizedRef = _normalizeSlug(abilityRef);
    for (final ability in titleAbilities) {
      final id = ability['id']?.toString() ?? '';
      if (_normalizeSlug(id) == normalizedRef) return id;
      
      final name = ability['name']?.toString() ?? '';
      if (_normalizeSlug(name) == normalizedRef) return id;
    }
    
    // Fallback to the reference itself (might be an ID)
    return abilityRef;
  }
  
  String _normalizeSlug(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
  
  Future<void> _ensureAbilityInDb(AppDatabase db, String abilityId) async {
    // Check if already exists
    final existing = await db.getComponentById(abilityId);
    if (existing != null) return;
    
    // Try to find in title abilities
    final titleAbilities = await loadTitleAbilities();
    final ability = titleAbilities.firstWhereOrNull(
      (a) => a['id']?.toString() == abilityId,
    );
    
    if (ability != null) {
      await db.insertComponentRaw(
        id: abilityId,
        type: 'ability',
        name: ability['name']?.toString() ?? abilityId,
        data: Map<String, dynamic>.from(ability),
      );
    }
  }
}
