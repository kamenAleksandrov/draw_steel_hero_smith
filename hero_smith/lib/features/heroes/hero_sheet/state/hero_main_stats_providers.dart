import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/providers.dart';
import '../../../../core/repositories/hero_repository.dart';

final heroMainStatsProvider =
    StreamProvider.family<HeroMainStats, String>((ref, heroId) {
  final repo = ref.watch(heroRepositoryProvider);
  return repo.watchMainStats(heroId);
});
