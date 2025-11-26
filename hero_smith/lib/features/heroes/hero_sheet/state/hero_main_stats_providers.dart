import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/providers.dart';
import '../../../../core/models/stat_modification_model.dart';
import '../../../../core/repositories/hero_repository.dart';
import '../../../../core/services/ancestry_bonus_service.dart';

final heroMainStatsProvider =
    StreamProvider.family<HeroMainStats, String>((ref, heroId) {
  final repo = ref.watch(heroRepositoryProvider);
  return repo.watchMainStats(heroId);
});

/// Provider to load ancestry stat modifications with their sources.
final heroAncestryStatModsProvider =
    FutureProvider.family<HeroStatModifications, String>((ref, heroId) async {
  final service = ref.watch(ancestryBonusServiceProvider);
  return service.loadAncestryStatMods(heroId);
});
