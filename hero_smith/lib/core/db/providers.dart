import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'database_maintenance.dart';
import '../seed/asset_seeder.dart';
import '../repositories/component_drift_repository.dart';
import '../repositories/hero_repository.dart';
import '../repositories/downtime_repository.dart';
import '../models/component.dart' as model;
import '../services/perk_grants_service.dart';

// Core singletons
final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase.instance);
final componentRepositoryProvider = Provider<ComponentDriftRepository>((ref) {
  final db = ref.read(appDatabaseProvider);
  return ComponentDriftRepository(db);
});

final heroRepositoryProvider = Provider<HeroRepository>((ref) {
  final db = ref.read(appDatabaseProvider);
  return HeroRepository(db);
});

final downtimeRepositoryProvider = Provider<DowntimeRepository>((ref) {
  final db = ref.read(appDatabaseProvider);
  return DowntimeRepository(db);
});

// Toggle for auto-seeding on startup. Tests can override this to false.
final autoSeedEnabledProvider = Provider<bool>((ref) => true);

// Seed once on startup if DB is empty. Safe to call repeatedly.
final seedOnStartupProvider = FutureProvider<void>((ref) async {
  final enabled = ref.read(autoSeedEnabledProvider);
  if (!enabled) return;
  final db = ref.read(appDatabaseProvider);
  await AssetSeeder.seedFromManifestIfEmpty(db);
  // Always reseed perks to ensure all perks are available
  // This fixes cases where perks.json was updated after initial DB creation
  await DatabaseMaintenance.reseedPerks(db);
});

// Data streams
final allComponentsProvider = StreamProvider<List<model.Component>>((ref) {
  final repo = ref.read(componentRepositoryProvider);
  return repo.watchAll();
});

final componentsByTypeProvider = StreamProvider.family<List<model.Component>, String>((ref, type) {
  final repo = ref.read(componentRepositoryProvider);
  return repo.watchByType(type);
});

// Heroes data streams
final allHeroesProvider = StreamProvider((ref) {
  final repo = ref.read(heroRepositoryProvider);
  return repo.watchAllHeroes();
});

// Enriched hero summaries for the list page
final heroSummariesProvider = StreamProvider<List<HeroSummary>>((ref) {
  final repo = ref.read(heroRepositoryProvider);
  return repo.watchSummaries();
});

// Provider to fetch an ability by name (used for perk grants lookup)
final abilityByNameProvider = FutureProvider.family<model.Component?, String>((ref, rawName) async {
  final name = rawName.trim();
  if (name.isEmpty) return null;

  final abilities = await ref.read(componentsByTypeProvider('ability').future);

  // Try exact match first
  final exactMatch = _findAbility(abilities, (c) => c.name == name);
  if (exactMatch != null && exactMatch.id.isNotEmpty) {
    return exactMatch;
  }

  // Try normalized (case/punctuation-insensitive) match
  final normalizedTarget = _normalizeAbilityName(name);
  final normalizedMatch = _findAbility(
    abilities,
    (c) => _normalizeAbilityName(c.name) == normalizedTarget,
  );
  if (normalizedMatch != null && normalizedMatch.id.isNotEmpty) {
    return normalizedMatch;
  }

  // Fallback to perk_abilities.json entries
  final perkAbilityMap = await PerkGrantsService().getPerkAbilityByName(name);
  if (perkAbilityMap == null) {
    return null;
  }
  return _perkAbilityToComponent(perkAbilityMap, name);
});

model.Component? _findAbility(
  List<model.Component> abilities,
  bool Function(model.Component ability) predicate,
) {
  for (final ability in abilities) {
    if (predicate(ability)) {
      return ability;
    }
  }
  return null;
}

String _normalizeAbilityName(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('\u2019', "'")
      .replaceAll('\u2018', "'")
      .replaceAll('\u201C', '"')
      .replaceAll('\u201D', '"');
}

model.Component _perkAbilityToComponent(Map<String, dynamic> raw, String fallbackName) {
  final data = Map<String, dynamic>.from(raw);
  final rawId = data.remove('id')?.toString();
  final type = data.remove('type')?.toString() ?? 'ability';
  final name = data.remove('name')?.toString() ?? fallbackName;
  final safeId = (rawId == null || rawId.isEmpty) ? _slugify(name) : rawId;
  final componentId = safeId.startsWith('perk_ability_') ? safeId : 'perk_ability_$safeId';

  return model.Component(
    id: componentId,
    type: type,
    name: name,
    data: data,
    source: 'perk_ability',
  );
}

String _slugify(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll('\u2019', '')
      .replaceAll('\u2018', '')
      .replaceAll('\u201C', '')
      .replaceAll('\u201D', '');
  final slug = normalized.replaceAll(RegExp('[^a-z0-9]+'), '_').replaceAll(RegExp('_+'), '_');
  final trimmed = slug.replaceAll(RegExp(r'^_+|_+$'), '');
  return trimmed.isEmpty ? 'ability' : trimmed;
}
