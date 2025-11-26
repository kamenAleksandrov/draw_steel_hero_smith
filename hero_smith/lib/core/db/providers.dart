import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'database_maintenance.dart';
import '../seed/asset_seeder.dart';
import '../repositories/component_drift_repository.dart';
import '../repositories/hero_repository.dart';
import '../repositories/downtime_repository.dart';
import '../models/component.dart' as model;

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
