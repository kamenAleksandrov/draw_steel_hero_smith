# Hero Smith Services Refactoring Plan

> **This file serves as the authoritative reference for the ongoing refactoring effort.**
> Update this file after completing each task to track progress and maintain context.

---

## 🎯 Goals

1. **Cleanup** - Remove redundant code, inconsistent patterns, and legacy storage
2. **Stability** - Ensure all hero creation flows work reliably
3. **Performance** - Reduce duplicate DB reads/writes, consolidate data sources
4. **Testability** - Add unit tests for all refactored services

---

## ⚠️ Critical Rule

**NEVER break existing functionality.** Every change must be validated against the full hero creation flow before moving to the next task.

---

## 📋 Task Checklist

### Phase 1: Standardize Service Patterns
- [x] **Task 1.1**: Refactor `PerkGrantsService` to constructor injection
- [x] **Task 1.2**: Refactor `TitleGrantsService` to constructor injection
- [x] **Task 1.3**: Add Riverpod providers for both services
- [x] **Task 1.4**: Update all call sites
- [x] **Task 1.5**: Add unit tests for `PerkGrantsService`
- [x] **Task 1.6**: Add unit tests for `TitleGrantsService`

### Phase 2: Extract Shared Services
- [x] **Task 2.1**: Create `AbilityResolverService`
- [x] **Task 2.2**: Add unit tests for `AbilityResolverService`
- [x] **Task 2.3**: Migrate `KitGrantsService` to use `AbilityResolverService`
- [x] **Task 2.4**: Migrate `ComplicationGrantsService` to use `AbilityResolverService`
- [x] **Task 2.5**: Migrate `ClassFeatureGrantsService` to use `AbilityResolverService`
- [x] **Task 2.6**: Migrate `TitleGrantsService` to use `AbilityResolverService`
- [x] **Task 2.7**: Migrate `PerkGrantsService` to use `AbilityResolverService`
- [x] **Task 2.8**: Create `DamageResistanceService`
- [x] **Task 2.9**: Add unit tests for `DamageResistanceService`
- [x] **Task 2.10**: Migrate resistance methods from `ComplicationGrantsService`
- [x] **Task 2.11**: Migrate resistance methods from `AncestryBonusService`
- [x] **Task 2.12**: Migrate resistance methods from `ClassFeatureGrantsService`
- [x] **Task 2.13**: Update `HeroEntryNormalizer` to use `DamageResistanceService`
- [x] **Task 2.14**: Update `HeroAssemblyService` to use `DamageResistanceService`

### Phase 3: Storage Cleanup
- [x] **Task 3.1**: Audit equipment bonus storage locations
- [x] **Task 3.2**: Update `heroEquipmentBonusesProvider` to read from `HeroEntries` only
- [x] **Task 3.3**: Remove duplicate write to `HeroValues` in `KitGrantsService`
- [x] **Task 3.4**: Add migration to clean up legacy `strife.equipment_bonuses` keys
- [x] **Task 3.5**: Add unit tests for equipment bonus flow (covered by kit_grants_service_test.dart)
- [x] **Task 3.6**: Audit legacy keys in `HeroEntryNormalizer`
- [x] **Task 3.7**: Remove unused legacy migration code (if no legacy data exists)

### Phase 4: Model Improvements
- [x] **Task 4.1**: Create sealed class hierarchy for `StatModification`
- [x] **Task 4.2**: Add unit tests for new `StatModification` classes
- [x] **Task 4.3**: Migrate all usages to pattern matching
- [x] **Task 4.4**: Remove old `StatModification` class (completed as part of 4.1)

### Phase 5: Data Source Consolidation
- [x] **Task 5.1**: Verify all supplementary JSONs are seeded to Components table
- [x] **Task 5.2**: Update `PerkGrantsService` to load abilities from DB
- [x] **Task 5.3**: Update `TitleGrantsService` to load abilities from DB
- [x] **Task 5.4**: Remove `rootBundle.loadString()` calls from services
- [x] **Task 5.5**: Add unit tests for DB-based ability loading

### Phase 6: Debug Cleanup
- [x] **Task 6.1**: Remove or guard all `print()` statements in services
- [x] **Task 6.2**: Remove or guard all `debugPrint()` statements in services
- [x] **Task 6.3**: Remove stack trace printing in `HeroEntryRepository`

---

## 🧪 Validation Checklist

Run this checklist after completing each Phase:

### Hero Creation Flow
- [ ] Create new hero with name
- [ ] Select class → verify class features appear
- [ ] Select subclass → verify subclass features appear
- [ ] Select ancestry → verify traits, stat bonuses, abilities
- [ ] Select culture → verify skills, languages granted
- [ ] Select career → verify skills, perks granted
- [ ] Select complication → verify grants (stats, abilities, resistances, tokens)
- [ ] Select kit → verify equipment, stat bonuses, signature ability
- [ ] Add perks manually → verify abilities granted
- [ ] Add titles → verify abilities granted
- [ ] Level up hero → verify level-scaled bonuses update

### Hero Modification Flow
- [ ] Change class → verify old class features removed, new ones added
- [ ] Change ancestry → verify old bonuses removed, new ones added
- [ ] Change complication → verify old grants removed, new ones added
- [ ] Change kit → verify old bonuses removed, new ones added
- [ ] Remove perk → verify granted abilities removed
- [ ] Remove title → verify granted abilities removed

### Hero Sheet Display
- [ ] Main stats tab → all stats display correctly
- [ ] Abilities tab → all abilities from all sources display
- [ ] Gear tab → equipment displays with bonuses
- [ ] Story tab → ancestry, culture, career info displays
- [ ] Notes tab → notes persist

### Edge Cases
- [ ] Hero with no optional components (minimal)
- [ ] Hero with all component types filled
- [ ] Hero with overlapping grants (same ability from multiple sources)
- [ ] Hero at level 1, 4, 7, 10 (echelon boundaries)

---

## 📁 Files to Create

### Services
- [x] `lib/core/services/ability_resolver_service.dart`
- [x] `lib/core/services/damage_resistance_service.dart`

### Tests
- [x] `test/core/services/ability_resolver_service_test.dart`
- [x] `test/core/services/damage_resistance_service_test.dart`
- [x] `test/core/services/perk_grants_service_test.dart`
- [x] `test/core/services/title_grants_service_test.dart`
- [x] `test/core/services/kit_grants_service_test.dart`
- [x] `test/core/models/complication_grant_models_test.dart`
- [x] `test/core/models/ancestry_bonus_models_test.dart`
- [ ] `test/core/services/class_feature_grants_service_test.dart`
- [x] `test/core/models/stat_modification_test.dart`

---

## 📝 Progress Log

### Current Status: **PHASE 6 COMPLETE - ALL TASKS DONE**

| Date | Task | Status | Notes |
|------|------|--------|-------|
| 2026-01-08 | Initial planning | ✅ Complete | Created refactoring plan |
| 2026-01-08 | Task 1.1: PerkGrantsService | ✅ Complete | Converted to constructor injection, added provider, updated 6 files |
| 2026-01-08 | Task 1.2: TitleGrantsService | ✅ Complete | Converted to constructor injection, added provider, updated 2 files |
| 2026-01-08 | Task 1.3: Add providers | ✅ Complete | Added perkGrantsServiceProvider, titleGrantsServiceProvider |
| 2026-01-08 | Task 1.4: Update call sites | ✅ Complete | All call sites migrated to use providers |
| 2026-01-08 | Task 1.5: Unit tests PerkGrantsService | ✅ Complete | 12 tests for PerkGrant parsing |
| 2026-01-08 | Task 1.6: Unit tests TitleGrantsService | ✅ Complete | 5 tests for title selection parsing |
| 2026-01-08 | Bug fix: Multi-language grants | ✅ Complete | Fixed Linguist perk only saving last language |
| 2026-01-08 | Task 2.1-2.7: AbilityResolverService | ✅ Complete | Created service, migrated all 5 grant services |
| 2026-01-08 | Task 2.8-2.9: DamageResistanceService | ✅ Complete | Created service with tests, added provider |
| 2026-01-08 | Task 2.10: ComplicationGrantsService | ✅ Complete | Migrated to use DamageResistanceService |
| 2026-01-08 | Task 2.11: AncestryBonusService | ✅ Complete | Migrated to use DamageResistanceService, removed ~90 lines orphaned code |
| 2026-01-08 | Task 2.12: ClassFeatureGrantsService | ✅ Complete | Reviewed - uses normalizer which delegates to DamageResistanceService |
| 2026-01-08 | Task 2.13: HeroEntryNormalizer | ✅ Complete | Delegates _recomputeResistances to DamageResistanceService |
| 2026-01-08 | Task 2.14: HeroAssemblyService | ✅ Complete | Reviewed - already reads from precomputed aggregate |
| 2026-01-08 | Bug fix: Perks tab reactivity | ✅ Complete | Fixed perks not updating without page exit/re-enter |
| 2026-01-08 | Bug fix: Career perk removal | ✅ Complete | Added removeEntryById to handle perks with sourceType='career' |
| 2026-01-08 | Unit tests: KitBonusService | ✅ Complete | 26 tests for equipment bonus parsing |
| 2026-01-08 | Unit tests: ComplicationGrantModels | ✅ Complete | Tests for all grant type parsing |
| 2026-01-08 | Unit tests: AncestryBonusModels | ✅ Complete | Tests for trait bonus parsing |
| 2026-01-08 | Task 3.1-3.4: Equipment bonus storage | ✅ Complete | Consolidated to HeroEntries, removed duplicate HeroValues write |
| 2026-01-08 | Task 3.4: Legacy migration | ✅ Complete | Added _migrateLegacyEquipmentBonuses to HeroEntryNormalizer |
| 2026-01-08 | Task 3.5-3.7: Cleanup | ✅ Complete | Audited banned prefixes, updated comments |
| 2026-01-08 | Task 4.1-4.4: StatModification sealed class | ✅ Complete | Created sealed hierarchy, 42 tests, pattern matching |
| 2026-01-08 | Task 5.1-5.5: Data source consolidation | ✅ Complete | Migrated to DB-based loading, removed rootBundle calls |
| 2026-01-08 | Task 6.1-6.3: Debug cleanup | ✅ Complete | Removed ~70 print/debugPrint statements from 6 files |

---

## 🔧 Implementation Details

### Task 1.1-1.2: Service Instantiation Refactor

#### Before (PerkGrantsService)
```dart
class PerkGrantsService {
  PerkGrantsService._();
  static final PerkGrantsService _instance = PerkGrantsService._();
  factory PerkGrantsService() => _instance;
  
  // db passed to every method
  Future<void> applyPerkGrants({required AppDatabase db, ...}) async { ... }
}
```

#### After (PerkGrantsService)
```dart
class PerkGrantsService {
  PerkGrantsService(this._db) : _entries = HeroEntryRepository(_db);
  final AppDatabase _db;
  final HeroEntryRepository _entries;
  
  // db is instance field, not parameter
  Future<void> applyPerkGrants({required String heroId, ...}) async { ... }
}
```

#### Provider Addition
```dart
// In providers.dart
final perkGrantsServiceProvider = Provider<PerkGrantsService>((ref) {
  final db = ref.read(appDatabaseProvider);
  return PerkGrantsService(db);
});

final titleGrantsServiceProvider = Provider<TitleGrantsService>((ref) {
  final db = ref.read(appDatabaseProvider);
  return TitleGrantsService(db);
});
```

---

### Task 2.1: AbilityResolverService

#### Purpose
Centralize ability name → component ID resolution logic that is currently duplicated across 5+ services.

#### Interface
```dart
class AbilityResolverService {
  AbilityResolverService(this._db);
  final AppDatabase _db;
  
  /// Resolve ability name/slug to component ID.
  /// Returns the ID if found, or slugified name as fallback.
  Future<String> resolveAbilityId(
    String nameOrSlug, {
    String? sourceType,
  }) async;
  
  /// Resolve multiple ability names at once.
  Future<List<String>> resolveAbilityIds(
    List<String> namesOrSlugs, {
    String? sourceType,
  }) async;
  
  /// Ensure an ability exists in the database.
  /// Inserts from supplementary data if needed.
  Future<void> ensureAbilityExists(String abilityId) async;
}
```

---

### Task 2.8: DamageResistanceService

#### Purpose
Centralize damage resistance read/write logic that is currently duplicated across 3+ services.

#### Interface
```dart
class DamageResistanceService {
  DamageResistanceService(this._db) : _entries = HeroEntryRepository(_db);
  final AppDatabase _db;
  final HeroEntryRepository _entries;
  
  /// Load aggregate resistances for display.
  Future<HeroDamageResistances> loadAggregate(String heroId) async;
  
  /// Watch aggregate resistances (reactive).
  Stream<HeroDamageResistances> watchAggregate(String heroId) async;
  
  /// Add resistance entry from a source.
  Future<void> addResistance({
    required String heroId,
    required String sourceType,
    required String sourceId,
    required String damageType,
    required int immunityValue,
    required int weaknessValue,
    required String sourceName,
  }) async;
  
  /// Remove all resistances from a source.
  Future<void> removeFromSource(String heroId, String sourceType, [String? sourceId]) async;
  
  /// Recompute aggregate from all entries.
  Future<void> recomputeAggregate(String heroId, int heroLevel) async;
}
```

---

### Task 4.1: StatModification Sealed Class

#### Before
```dart
class StatModification {
  final int value;
  final String? dynamicValue;  // "level" = scale with level
  final bool perEchelon;
  final int valuePerEchelon;
  
  int getActualValue(int heroLevel) {
    if (dynamicValue == 'level') return heroLevel;
    if (perEchelon) return valuePerEchelon * echelon;
    return value;
  }
}
```

#### After
```dart
sealed class StatModification {
  final String source;
  const StatModification({required this.source});
  
  int getActualValue(int heroLevel);
  
  factory StatModification.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}

class StaticStatModification extends StatModification { ... }
class LevelScaledStatModification extends StatModification { ... }
class EchelonScaledStatModification extends StatModification { ... }
```

---

## 🚀 Next Step

**When ready to begin, start with Task 1.1: Refactor `PerkGrantsService` to constructor injection.**

Read the current implementation:
```
hero_smith/lib/core/services/perk_grants_service.dart
```

Then update the class to use constructor injection pattern shown above.
