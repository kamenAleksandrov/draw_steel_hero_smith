import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db/app_database.dart';
import '../core/repository/component_drift_repository.dart';
import '../core/models/component.dart' as model;

// Core singletons
final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase.instance);
final componentRepositoryProvider = Provider<ComponentDriftRepository>((ref) {
  final db = ref.read(appDatabaseProvider);
  return ComponentDriftRepository(db);
});

// Toggle for auto-seeding on startup. Tests can override this to false.
final autoSeedEnabledProvider = Provider<bool>((ref) => true);

// Seed once on startup if DB is empty. Safe to call repeatedly.
final seedOnStartupProvider = FutureProvider<void>((ref) async {
  final enabled = ref.read(autoSeedEnabledProvider);
  if (!enabled) return;
  final db = ref.read(appDatabaseProvider);
  await db.seedFromManifestIfEmpty();
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
