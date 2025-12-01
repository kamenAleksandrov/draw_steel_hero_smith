import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/providers.dart';
import '../../../../core/models/heroic_resource_progression.dart';
import '../../../../core/models/stat_modification_model.dart';
import '../../../../core/repositories/hero_repository.dart';
import '../../../../core/services/ancestry_bonus_service.dart';
import '../../../../core/services/heroic_resource_progression_service.dart';

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

/// Provider to load equipment bonuses that have been applied to the hero.
final heroEquipmentBonusesProvider =
    FutureProvider.family<Map<String, int>, String>((ref, heroId) async {
  final repo = ref.read(heroRepositoryProvider);
  return repo.getEquipmentBonuses(heroId);
});

/// Data class for hero progression context
class HeroProgressionContext {
  const HeroProgressionContext({
    required this.className,
    required this.subclassName,
    this.kitId,
  });

  final String? className;
  final String? subclassName;
  final String? kitId;
}

/// Provider to load hero progression context (class, subclass, kit)
final heroProgressionContextProvider =
    FutureProvider.family<HeroProgressionContext, String>((ref, heroId) async {
  final repo = ref.read(heroRepositoryProvider);
  HeroMainStats? stats;
  try {
    stats = await ref.watch(heroMainStatsProvider(heroId).future);
  } catch (_) {
    stats = null;
  }
  final hero = await repo.load(heroId);
  if (hero == null && stats == null) {
    return const HeroProgressionContext(className: null, subclassName: null);
  }

  String? normalizedClassName = hero?.className ?? stats?.classId;
  if (normalizedClassName != null) {
    normalizedClassName = normalizedClassName.trim();
    if (normalizedClassName.startsWith('class_')) {
      normalizedClassName = normalizedClassName.substring(6);
    }
  }

  // Get equipment IDs to find the kit
  final equipmentIds = await repo.getEquipmentIds(heroId);
  String? kitId;
  
  // Find the first stormwight kit in equipment
  for (final id in equipmentIds) {
    if (id != null && id.contains('kit_')) {
      // Check if it's a stormwight kit (boren, corven, raden, vulken)
      final normalizedId = id.toLowerCase();
      if (normalizedId.contains('boren') ||
          normalizedId.contains('corven') ||
          normalizedId.contains('raden') ||
          normalizedId.contains('vulken') ||
          normalizedId.contains('vuken')) {
        kitId = id;
        break;
      }
    }
  }

  return HeroProgressionContext(
    className: normalizedClassName,
    subclassName: hero?.subclass,
    kitId: kitId,
  );
});

/// Provider to load the heroic resource progression for a hero
final heroResourceProgressionProvider =
    FutureProvider.family<HeroicResourceProgression?, String>((ref, heroId) async {
  final context = await ref.watch(heroProgressionContextProvider(heroId).future);
  final service = HeroicResourceProgressionService();

  return service.getProgression(
    className: context.className,
    subclassName: context.subclassName,
    kitId: context.kitId,
  );
});
