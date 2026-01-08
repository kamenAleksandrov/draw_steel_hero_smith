# Services Layer Refactoring Plan

> **CRITICAL RULE**: All refactoring MUST preserve existing functionality. Each step should be validated before moving to the next.

## Overview

This plan addresses 8 identified issues in the services layer, ordered by dependency and risk level. We'll refactor in phases, with each phase building on the previous.

---

## Phase 1: Foundation (Low Risk, Enables Future Work)

### 1.1 Add Logging Framework
**Issue:** Debug print spam throughout services  
**Risk:** Low - additive change, no behavior modification  
**Time:** ~2 hours

#### Current State
```dart
// HeroEntryRepository.addEntry()
print('[HeroEntryRepository] addEntry(ability): heroId=$heroId, entryId=$entryId...');
print(StackTrace.current);

// KitGrantsService
debugPrint('[KitGrantsService] applyKitGrants called: heroId=$heroId...');
```

#### Target State
```dart
import '../utils/logger.dart';

class HeroEntryRepository {
  static final _log = AppLogger('HeroEntryRepository');
  
  Future<void> addEntry(...) {
    _log.debug('addEntry(ability): heroId=$heroId, entryId=$entryId...');
    // No stack trace in production
  }
}
```

#### Implementation Steps
1. Create `lib/core/utils/logger.dart`:
   ```dart
   import 'package:flutter/foundation.dart';
   
   enum LogLevel { debug, info, warn, error }
   
   class AppLogger {
     final String tag;
     static LogLevel minLevel = kDebugMode ? LogLevel.debug : LogLevel.warn;
     
     AppLogger(this.tag);
     
     void debug(String message) {
       if (minLevel.index <= LogLevel.debug.index) {
         debugPrint('[$tag] $message');
       }
     }
     
     void info(String message) { ... }
     void warn(String message) { ... }
     void error(String message, [Object? error, StackTrace? stack]) { ... }
   }
   ```

2. Replace all `print()` and `debugPrint()` calls in services:
   - `HeroEntryRepository` (~10 calls)
   - `ComplicationGrantsService` (~15 calls)
   - `AncestryBonusService` (~12 calls)
   - `KitGrantsService` (~20 calls)
   - `ClassFeatureGrantsService` (~8 calls)

3. **Validation:** Run app, verify no console errors, check logs appear in debug mode only

---

### 1.2 Standardize Service Instantiation
**Issue:** Inconsistent patterns (constructor injection vs singleton)  
**Risk:** Low-Medium - requires updating call sites  
**Time:** ~3 hours

#### Current State
```dart
// Constructor injection (GOOD)
class ComplicationGrantsService {
  ComplicationGrantsService(this._db);
  final AppDatabase _db;
}

// Singleton (PROBLEMATIC)
class PerkGrantsService {
  PerkGrantsService._();
  static final PerkGrantsService _instance = PerkGrantsService._();
  factory PerkGrantsService() => _instance;
  
  // No _db field - passed to every method!
  Future<void> applyPerkGrants({required AppDatabase db, ...}) async { ... }
}
```

#### Target State
```dart
// ALL services use constructor injection
class PerkGrantsService {
  PerkGrantsService(this._db) : _entries = HeroEntryRepository(db);
  final AppDatabase _db;
  final HeroEntryRepository _entries;
  
  Future<void> applyPerkGrants({required String heroId, ...}) async { ... }
}
```

#### Implementation Steps

1. **Refactor `PerkGrantsService`:**
   - Add constructor with `AppDatabase` parameter
   - Add `_entries` field
   - Remove `db` parameter from all public methods
   - Keep JSON caching as static (that's fine)
   
2. **Refactor `TitleGrantsService`:**
   - Same pattern as above

3. **Add Riverpod providers** in `providers.dart`:
   ```dart
   final perkGrantsServiceProvider = Provider<PerkGrantsService>((ref) {
     final db = ref.read(appDatabaseProvider);
     return PerkGrantsService(db);
   });
   
   final titleGrantsServiceProvider = Provider<TitleGrantsService>((ref) {
     final db = ref.read(appDatabaseProvider);
     return TitleGrantsService(db);
   });
   ```

4. **Update all call sites** - search for:
   - `PerkGrantsService()` → `ref.read(perkGrantsServiceProvider)`
   - `TitleGrantsService()` → `ref.read(titleGrantsServiceProvider)`

5. **Validation:**
   - Test perk selection/deselection flow
   - Test title selection flow
   - Verify abilities granted by perks/titles appear correctly
   - Verify removal works when changing perks/titles

---

## Phase 2: Extract Shared Services (Medium Risk)

### 2.1 Create AbilityResolverService
**Issue:** 4+ duplicate `_resolveAbilityId()` implementations  
**Risk:** Medium - core functionality used everywhere  
**Time:** ~4 hours

#### Current Implementations
| Service | Method | Behavior |
|---------|--------|----------|
| `KitGrantsService` | `_resolveAbilityId(name)` | Looks up by name in DB, falls back to slugify |
| `PerkGrantsService` | `_resolveAbilityIds(names)` | Checks DB, then perk_abilities.json |
| `TitleGrantsService` | `_resolveAbilityId(slug)` | Checks title_abilities.json, ensures in DB |
| `ComplicationGrantsService` | inline in `_applyAbilityGrants` | Simple name→id lookup |
| `ClassFeatureGrantsService` | `_resolveAbilityId(name)` | Similar to kit |

#### Target State
```dart
/// lib/core/services/ability_resolver_service.dart
class AbilityResolverService {
  AbilityResolverService(this._db);
  final AppDatabase _db;
  
  /// Resolve ability name/slug to component ID.
  /// 
  /// Resolution order:
  /// 1. Exact ID match in Components table
  /// 2. Name match (case-insensitive, normalized punctuation)
  /// 3. Slugified name as fallback ID
  /// 
  /// If [ensureInDb] is true and ability not found, attempts to load
  /// from supplementary JSON files and insert into Components.
  Future<String> resolveAbilityId(
    String nameOrSlug, {
    bool ensureInDb = true,
    String? sourceType, // 'perk', 'title', 'kit', etc. for fallback lookup
  }) async {
    // 1. Check if it's already a valid component ID
    final existing = await _db.getComponentById(nameOrSlug);
    if (existing != null) return nameOrSlug;
    
    // 2. Search by normalized name
    final normalized = _normalizeAbilityName(nameOrSlug);
    final allAbilities = await _db.getComponentsByType('ability');
    final match = allAbilities.firstWhereOrNull(
      (c) => _normalizeAbilityName(c.name) == normalized,
    );
    if (match != null) return match.id;
    
    // 3. Try supplementary JSON based on source
    if (ensureInDb && sourceType != null) {
      final fromJson = await _loadFromSupplementaryJson(nameOrSlug, sourceType);
      if (fromJson != null) {
        await _ensureAbilityInDb(fromJson);
        return fromJson['id'] as String;
      }
    }
    
    // 4. Fallback to slugified name
    return _slugify(nameOrSlug);
  }
  
  /// Resolve multiple ability names at once (batch operation)
  Future<List<String>> resolveAbilityIds(
    List<String> namesOrSlugs, {
    bool ensureInDb = true,
    String? sourceType,
  }) async {
    final results = <String>[];
    for (final name in namesOrSlugs) {
      results.add(await resolveAbilityId(name, ensureInDb: ensureInDb, sourceType: sourceType));
    }
    return results;
  }
  
  String _normalizeAbilityName(String value) {
    return value.trim().toLowerCase()
        .replaceAll('\u2019', "'")
        .replaceAll('\u2018', "'")
        .replaceAll('\u201C', '"')
        .replaceAll('\u201D', '"');
  }
  
  String _slugify(String name) {
    return name.toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }
  
  Future<Map<String, dynamic>?> _loadFromSupplementaryJson(String name, String sourceType) async {
    // Load from perk_abilities.json, title_abilities.json, etc.
    // based on sourceType
  }
  
  Future<void> _ensureAbilityInDb(Map<String, dynamic> abilityData) async {
    // Insert if not exists
  }
}
```

#### Implementation Steps

1. Create `lib/core/services/ability_resolver_service.dart` with above code

2. Add provider:
   ```dart
   final abilityResolverProvider = Provider<AbilityResolverService>((ref) {
     final db = ref.read(appDatabaseProvider);
     return AbilityResolverService(db);
   });
   ```

3. **Migrate services one at a time** (in this order to minimize risk):
   - `KitGrantsService` - inject `AbilityResolverService`, replace `_resolveAbilityId`
   - `ComplicationGrantsService` - replace inline lookup
   - `ClassFeatureGrantsService` - replace `_resolveAbilityId`
   - `TitleGrantsService` - replace `_resolveAbilityId`
   - `PerkGrantsService` - replace `_resolveAbilityIds`

4. **Validation after each migration:**
   - Create new hero, select components that grant abilities
   - Verify abilities appear in hero's ability list
   - Verify abilities are removed when source is removed
   - Check ability cards display correctly (not showing ID as name)

---

### 2.2 Create DamageResistanceService
**Issue:** Duplicate resistance loading/watching methods across services  
**Risk:** Medium - affects stat display  
**Time:** ~4 hours

#### Current State
Nearly identical methods in 3+ services:
```dart
// In ComplicationGrantsService, AncestryBonusService, ClassFeatureGrantsService
Future<HeroDamageResistances> loadDamageResistances(String heroId) async {
  final values = await _db.getHeroValues(heroId);
  final value = values.firstWhereOrNull((v) => v.key == _kDamageResistances);
  // ... identical parsing logic
}

Stream<HeroDamageResistances> watchDamageResistances(String heroId) {
  return _db.watchHeroValues(heroId).map((values) {
    // ... identical parsing logic
  });
}
```

#### Target State
```dart
/// lib/core/services/damage_resistance_service.dart
class DamageResistanceService {
  DamageResistanceService(this._db) : _entries = HeroEntryRepository(db);
  final AppDatabase _db;
  final HeroEntryRepository _entries;
  
  static const _kAggregateKey = 'resistances.damage';
  
  /// Load aggregate resistances (computed from all sources)
  Future<HeroDamageResistances> loadAggregate(String heroId) async { ... }
  
  /// Watch aggregate resistances
  Stream<HeroDamageResistances> watchAggregate(String heroId) { ... }
  
  /// Load resistance entries by source
  Future<List<HeroEntry>> loadEntriesBySource(String heroId, String sourceType) async { ... }
  
  /// Watch resistance entries from all sources
  Stream<Map<String, DamageResistanceBonus>> watchBonusEntries(String heroId) { ... }
  
  /// Add resistance from a source
  Future<void> addResistance({
    required String heroId,
    required String sourceType,
    required String sourceId,
    required String damageType,
    required int immunityValue,
    required int weaknessValue,
    String? dynamicValue,
    bool perEchelon = false,
    int valuePerEchelon = 0,
    required String sourceName,
  }) async { ... }
  
  /// Remove all resistances from a source
  Future<void> removeResistancesFromSource(String heroId, String sourceType, [String? sourceId]) async { ... }
  
  /// Recompute aggregate from all entries (called by normalizer)
  Future<void> recomputeAggregate(String heroId, int heroLevel) async { ... }
}
```

#### Implementation Steps

1. Create `lib/core/services/damage_resistance_service.dart`

2. Add provider in `providers.dart`

3. **Migrate call sites:**
   - `ComplicationGrantsService` - inject service, replace resistance methods
   - `AncestryBonusService` - inject service, replace resistance methods  
   - `ClassFeatureGrantsService` - inject service, replace resistance methods
   - `HeroEntryNormalizer._recomputeResistances()` - delegate to service
   - `HeroAssemblyService` - use service for resistance loading

4. **Validation:**
   - Create hero with complication that grants weakness (e.g., Bereaved - corruption weakness 5)
   - Create hero with ancestry trait that grants immunity
   - Verify resistances display correctly on hero sheet
   - Change complication/ancestry - verify resistances update

---

## Phase 3: Storage Cleanup (Medium-High Risk)

### 3.1 Eliminate Duplicate Equipment Bonus Storage
**Issue:** `KitGrantsService` writes to both `HeroEntries` AND `HeroValues`  
**Risk:** Medium-High - affects stat calculations  
**Time:** ~3 hours

#### Current State
```dart
// KitGrantsService._storeEquipmentBonuses()
// Writes to BOTH locations:
await _entries.addEntry(
  heroId: heroId,
  entryType: 'equipment_bonuses',
  entryId: 'combined_equipment_bonuses',
  ...
);

await _db.upsertHeroValue(
  heroId: heroId,
  key: 'strife.equipment_bonuses',
  jsonMap: {...},
);
```

#### Target State
Single source of truth in `HeroEntries`:
```dart
// Only write to HeroEntries
await _entries.addEntry(
  heroId: heroId,
  entryType: 'equipment_bonuses',
  ...
);
```

#### Implementation Steps

1. **Identify all readers of `strife.equipment_bonuses`:**
   - Search codebase for `strife.equipment_bonuses`
   - Found in: `heroEquipmentBonusesProvider` in `providers.dart`

2. **Update `heroEquipmentBonusesProvider` to read from `HeroEntries`:**
   ```dart
   final heroEquipmentBonusesProvider = StreamProvider.family<EquipmentBonuses, String>((ref, heroId) {
     final entries = ref.read(heroEntryRepositoryProvider);
     return entries.watchEntriesByType(heroId, 'equipment_bonuses').map((entries) {
       if (entries.isEmpty) return EquipmentBonuses.empty;
       final entry = entries.first;
       if (entry.payload == null) return EquipmentBonuses.empty;
       return EquipmentBonuses.fromJson(jsonDecode(entry.payload!));
     });
   });
   ```

3. **Remove `HeroValues` write from `KitGrantsService._storeEquipmentBonuses()`**

4. **Add migration in `HeroEntryNormalizer`:**
   - If `strife.equipment_bonuses` exists in `HeroValues`, delete it
   - (Data is already in `HeroEntries` from dual-write)

5. **Validation:**
   - Create hero, select kit with stat bonuses
   - Verify stamina/speed/stability bonuses appear correctly
   - Change kit - verify bonuses update
   - Remove kit - verify bonuses reset to 0

---

### 3.2 Complete Legacy Key Migration
**Issue:** `HeroEntryNormalizer` has 96+ banned prefixes  
**Risk:** Low - cleanup only, data already migrated  
**Time:** ~2 hours

#### Current State
Extensive lists in `HeroEntryNormalizer`:
```dart
static const List<String> _bannedValueKeysPrefixes = [
  'basics.className',
  'basics.subclass',
  // ... 94 more
];
```

#### Target State
Remove legacy migration code, keep only:
- Active cleanup (dedupe, validation)
- Current-format normalization

#### Implementation Steps

1. **Audit current data:**
   ```dart
   // Add temporary debug method
   Future<void> auditLegacyKeys(String heroId) async {
     final values = await _db.getHeroValues(heroId);
     for (final v in values) {
       for (final prefix in _bannedValueKeysPrefixes) {
         if (v.key.startsWith(prefix)) {
           print('LEGACY KEY FOUND: ${v.key}');
         }
       }
     }
   }
   ```

2. **If legacy keys found in production data:**
   - Keep migration code
   - Run migration on app startup for one version
   - Remove in next version

3. **If no legacy keys found:**
   - Remove `_bannedValueKeysPrefixes` list
   - Remove migration methods
   - Keep `_removeBannedValues()` as no-op or remove entirely

4. **Validation:**
   - Test on fresh database
   - Test on existing database with real hero data

---

## Phase 4: Model Improvements (Lower Risk)

### 4.1 Refactor StatModification to Sealed Class Hierarchy
**Issue:** Single class with multiple modes checked via if/else  
**Risk:** Low-Medium - model change, many usages  
**Time:** ~4 hours

#### Current State
```dart
class StatModification {
  final int value;
  final String? dynamicValue;  // "level" means scale with level
  final bool perEchelon;
  final int valuePerEchelon;
  
  int getActualValue(int heroLevel) {
    if (dynamicValue == 'level') return heroLevel;
    if (perEchelon && valuePerEchelon > 0) {
      final echelon = ((heroLevel - 1) ~/ 3) + 1;
      return valuePerEchelon * echelon;
    }
    return value;
  }
}
```

#### Target State
```dart
sealed class StatModification {
  final String source;
  const StatModification({required this.source});
  
  int getActualValue(int heroLevel);
  
  factory StatModification.fromJson(Map<String, dynamic> json) {
    if (json['dynamicValue'] == 'level') {
      return LevelScaledStatModification.fromJson(json);
    } else if (json['perEchelon'] == true) {
      return EchelonScaledStatModification.fromJson(json);
    } else {
      return StaticStatModification.fromJson(json);
    }
  }
  
  Map<String, dynamic> toJson();
}

class StaticStatModification extends StatModification {
  final int value;
  const StaticStatModification({required this.value, required super.source});
  
  @override
  int getActualValue(int heroLevel) => value;
}

class LevelScaledStatModification extends StatModification {
  const LevelScaledStatModification({required super.source});
  
  @override
  int getActualValue(int heroLevel) => heroLevel;
}

class EchelonScaledStatModification extends StatModification {
  final int valuePerEchelon;
  const EchelonScaledStatModification({required this.valuePerEchelon, required super.source});
  
  @override
  int getActualValue(int heroLevel) {
    final echelon = ((heroLevel - 1) ~/ 3) + 1;
    return valuePerEchelon * echelon;
  }
}
```

#### Implementation Steps

1. Create sealed class hierarchy (keep old class temporarily)

2. Add `StatModification.fromJson()` factory that returns appropriate subtype

3. Update usages one at a time:
   - Use pattern matching: `switch (mod) { case StaticStatModification(): ... }`

4. Remove old class once all usages migrated

5. **Validation:**
   - Test complication with per-echelon grant (e.g., Elemental Inside: +3 stamina per echelon)
   - Test ancestry with level-scaled immunity (e.g., Mundane: immunity = level)
   - Verify values calculate correctly at levels 1, 4, 7, 10

---

## Phase 5: Consolidate JSON Loading (Lower Priority)

### 5.1 Move All Runtime Data to Components Table
**Issue:** Some services load from JSON, others from DB  
**Risk:** Low - data source change  
**Time:** ~3 hours

#### Current State
```dart
// PerkGrantsService - loads from JSON
final raw = await rootBundle.loadString('data/abilities/perk_abilities.json');

// ComplicationGrantsService - loads from DB
final allComponents = await _db.getAllComponents();
```

#### Target State
All services load from `_db.getAllComponents()` or type-specific queries.

#### Implementation Steps

1. **Ensure supplementary JSONs are seeded:**
   - `perk_abilities.json` → seeded as type='ability'
   - `title_abilities.json` → seeded as type='ability'
   - Verify in `AssetSeeder`

2. **Update services to use DB:**
   - `PerkGrantsService.loadPerkAbilities()` → `_db.getComponentsByType('ability')`
   - `TitleGrantsService.loadTitleAbilities()` → `_db.getComponentsByType('ability')`
   - Remove `rootBundle` imports

3. **Keep caching at DB level** (already exists via Drift)

4. **Validation:**
   - Test perk that grants ability (e.g., "Friend Catapult")
   - Test title that grants ability
   - Verify ability details display correctly

---

## Execution Order & Dependencies

```
Phase 1.1 (Logging) ─────────────────────────────────────────────────┐
                                                                     │
Phase 1.2 (Service Instantiation) ───────────────────────────────────┼──► Foundation Complete
                                                                     │
                    ┌────────────────────────────────────────────────┘
                    ▼
Phase 2.1 (AbilityResolverService) ──────────────────────────────────┐
                                                                     │
Phase 2.2 (DamageResistanceService) ─────────────────────────────────┼──► Shared Services Complete
                                                                     │
                    ┌────────────────────────────────────────────────┘
                    ▼
Phase 3.1 (Equipment Bonus Storage) ─────────────────────────────────┐
                                                                     │
Phase 3.2 (Legacy Key Cleanup) ──────────────────────────────────────┼──► Storage Cleanup Complete
                                                                     │
                    ┌────────────────────────────────────────────────┘
                    ▼
Phase 4.1 (StatModification Refactor) ───────────────────────────────┐
                                                                     │
Phase 5.1 (JSON Loading Consolidation) ──────────────────────────────┴──► Refactoring Complete
```

---

## Testing Strategy

### Before Each Phase
1. Create test heroes with relevant components
2. Document expected behavior (screenshots, stat values)
3. Export hero data for comparison

### After Each Phase
1. Verify all documented behaviors still work
2. Compare stat values to pre-refactor baseline
3. Test edge cases:
   - Hero with no components of that type
   - Hero with multiple overlapping sources
   - Changing components mid-session
   - Level up with dynamic scaling

### Regression Test Checklist
- [ ] Create new hero
- [ ] Select class (verify class features, abilities)
- [ ] Select ancestry (verify traits, bonuses)
- [ ] Select culture (verify skills, languages)
- [ ] Select career (verify skills, perks)
- [ ] Select complication (verify grants, resistances)
- [ ] Select kit (verify equipment, bonuses)
- [ ] Select perks (verify abilities)
- [ ] Select titles (verify abilities)
- [ ] Level up hero (verify scaling bonuses)
- [ ] Change each component (verify cleanup)
- [ ] View hero sheet (verify all data displays)

---

## Estimated Timeline

| Phase | Effort | Dependencies |
|-------|--------|--------------|
| 1.1 Logging | 2h | None |
| 1.2 Service Instantiation | 3h | None |
| 2.1 AbilityResolverService | 4h | 1.2 |
| 2.2 DamageResistanceService | 4h | 1.2 |
| 3.1 Equipment Bonus Storage | 3h | 2.2 |
| 3.2 Legacy Key Cleanup | 2h | 3.1 |
| 4.1 StatModification Refactor | 4h | 2.2 |
| 5.1 JSON Loading Consolidation | 3h | 2.1 |

**Total: ~25 hours** (recommend spreading over 2-3 weeks to allow proper testing)

---

## Rollback Strategy

Each phase should be committed separately. If issues arise:

1. **Immediate rollback:** `git revert HEAD` for latest phase
2. **Partial rollback:** Each service migration within a phase is also a separate commit
3. **Data rollback:** Database schema is unchanged, so no data migration needed

---

## Questions to Resolve Before Starting

1. **Logging:** Any existing logging preferences/packages already in use?
2. **Testing:** Should we add unit tests as part of each phase?
3. **Priority:** Which functionality is most critical and should be tested most thoroughly?
4. **Timeline:** Any deadlines or feature work that should take priority?
