import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import '../seed/asset_seeder.dart';
import '../repository/component_drift_repository.dart';
import '../repository/hero_repository.dart';
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

// Toggle for auto-seeding on startup. Tests can override this to false.
final autoSeedEnabledProvider = Provider<bool>((ref) => true);

// Seed once on startup if DB is empty. Safe to call repeatedly.
final seedOnStartupProvider = FutureProvider<void>((ref) async {
  final enabled = ref.read(autoSeedEnabledProvider);
  if (!enabled) return;
  final db = ref.read(appDatabaseProvider);
  await AssetSeeder.seedFromManifestIfEmpty(db);
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
