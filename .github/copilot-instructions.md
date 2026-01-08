# Hero Smith - AI Coding Instructions

## Project Overview
Hero Smith is a Flutter app for creating and managing heroes for the Draw Steel TTRPG system. Heroes are assembled from modular **Components** (classes, ancestries, kits, abilities, perks, skills, etc.) stored in JSON data files and seeded into a Drift SQLite database.

## Architecture

### Core Layers (`hero_smith/lib/core/`)
- **`db/`** - Drift database (`AppDatabase`) with tables: `Components`, `Heroes`, `HeroEntries`, `HeroValues`, `HeroConfig`
- **`models/`** - Domain models. Key ones: `Component` (generic building block), `HeroModel` (legacy), `HeroAssembly` (authoritative unified hero view)
- **`repositories/`** - Database access. `HeroEntryRepository` manages all hero content ownership
- **`services/`** - Business logic. Each grant type has a service (see detailed analysis below)
- **`seed/`** - `AssetSeeder` loads JSON from `data/` into Components table on first run

### Feature Layers (`hero_smith/lib/features/`)
- **`creators/hero_creators/`** - Multi-tab hero creation wizard (story → strength → strife)
- **`heroes_sheet/`** - View/edit hero: main stats, abilities, gear, story, notes tabs
- **`main_pages/`** - Top-level navigation (heroes list, gear, story, strife, downtime)

### Data Flow
1. JSON files (`hero_smith/data/`) → seeded to `Components` table
2. User picks components → stored in `HeroEntries` with `sourceType`/`sourceId` tracking
3. `HeroAssemblyService.assemble()` merges `HeroValues` + `HeroEntries` + `HeroConfig` → `HeroAssembly`
4. Riverpod providers (`core/db/providers.dart`) expose reactive streams

---

## Services Architecture (Detailed Analysis)

### Grant Services Overview
Each source type has a dedicated service that handles parsing grants and writing to the DB:

| Service | Source Type | Responsibilities |
|---------|-------------|------------------|
| `ComplicationGrantsService` | `complication` | Stats, abilities, skills, resistances, tokens, treasures, languages, features |
| `AncestryBonusService` | `ancestry` | Stats, resistances, condition immunities, abilities |
| `ClassFeatureGrantsService` | `class_feature` | Skills, abilities, stat bonuses, resistances |
| `KitGrantsService` | `kit` | Equipment, abilities, stat bonuses, features |
| `PerkGrantsService` | `perk` | Abilities, skills, languages |
| `TitleGrantsService` | `title` | Abilities |

### Common Grant Service Pattern
All grant services follow a similar structure:
```dart
class XxxGrantsService {
  final AppDatabase _db;
  final HeroEntryRepository _entries;  // Writes to hero_entries
  final HeroConfigService _config;     // Writes to hero_config (choices)
  
  Future<void> applyGrants(heroId, grants, heroLevel) async { ... }
  Future<void> removeGrants(heroId) async { ... }
  Future<T> loadGrants(heroId) async { ... }
}
```

### Storage Destinations
| Data Type | Storage | Key/Entry Type |
|-----------|---------|----------------|
| Numeric stats (stamina, speed, etc.) | `HeroValues` | `stats.*`, `stamina.*` |
| Stat modifications with sources | `HeroValues` | `*.stat_mods` (JSON with source tracking) |
| Content grants (abilities, skills) | `HeroEntries` | `entryType` + `sourceType`/`sourceId` |
| User selections/choices | `HeroConfig` | `configKey` → JSON value |
| Damage resistances (aggregate) | `HeroValues` | `resistances.damage` |
| Resistance entries (per-source) | `HeroEntries` | `entryType='resistance'` |

---

## Identified Issues & Refactoring Opportunities

### 1. **Inconsistent Service Instantiation Patterns**
- `ComplicationGrantsService` / `AncestryBonusService` / `KitGrantsService` / `ClassFeatureGrantsService` - constructor takes `AppDatabase`, creates internal `HeroEntryRepository`
- `PerkGrantsService` / `TitleGrantsService` - **singleton pattern** (`._()` private constructor, static `_instance`)
- `DynamicModifiersService` - takes `AppDatabase` in constructor

**Recommendation:** Standardize on constructor injection. Singletons make testing harder and hide dependencies.

### 2. **Redundant Resistance Storage**
- `ComplicationGrantsService.saveDamageResistances()` writes to `HeroValues._kDamageResistances`
- `AncestryBonusService.loadDamageResistances()` reads same key
- `HeroEntryNormalizer._recomputeResistances()` rebuilds from `HeroEntries`
- Multiple services have nearly identical `loadDamageResistances()` / `watchDamageResistances()` methods

**Recommendation:** Extract a `DamageResistanceService` that owns all resistance read/write logic.

### 3. **Duplicated Ability Resolution Logic**
Each service has its own `_resolveAbilityId()` implementation:
- `KitGrantsService._resolveAbilityId(abilityName)` - looks up by name, slugifies
- `PerkGrantsService._resolveAbilityIds(names)` - checks DB then perk_abilities.json
- `TitleGrantsService._resolveAbilityId(abilitySlug)` - checks title_abilities.json
- `ComplicationGrantsService` - inline lookup by name

**Recommendation:** Create shared `AbilityResolverService` with standardized name→ID lookup.

### 4. **Inconsistent JSON Loading**
- `PerkGrantsService` / `TitleGrantsService` - load from `rootBundle.loadString()` with caching
- `ComplicationGrantsService` / `AncestryBonusService` - load from `_db.getAllComponents()`
- Some services mix both approaches

**Recommendation:** All runtime data should come from the seeded `Components` table, not JSON files.

### 5. **Legacy/Duplicate Storage Keys**
`HeroEntryNormalizer` has extensive lists of banned prefixes, indicating historical storage inconsistencies:
- `_bannedValueKeysPrefixes` (96 prefixes to migrate away from)
- `_bannedConfigKeys` (legacy config patterns)

**Recommendation:** Complete the migration and remove legacy handling code.

### 6. **Stat Modification Model Complexity**
`StatModification` supports multiple scaling modes that are checked everywhere:
- `value` (static)
- `dynamicValue == 'level'` (scales with level)
- `perEchelon` + `valuePerEchelon` (scales with echelon)

**Recommendation:** Consider a sealed class hierarchy for different scaling types.

### 7. **Debug Print Statements**
Multiple services have extensive `print()` / `debugPrint()` statements:
- `HeroEntryRepository.addEntry()` - prints all ability/skill additions with stack traces
- `KitGrantsService` - extensive debug logging
- `AncestryBonusService` - parsing debug logs

**Recommendation:** Use a proper logging framework with log levels.

### 8. **Equipment Bonuses Stored Twice**
`KitGrantsService._storeEquipmentBonuses()` writes to BOTH:
- `HeroEntries` (as `equipment_bonuses` entry)
- `HeroValues` (as `strife.equipment_bonuses`)

**Recommendation:** Pick one source of truth.

---

## Key Patterns

### Component Grant System
Complications, perks, kits, classes, and features can grant bonuses via `"grants"` in JSON:
```json
"grants": {
  "increase_total": { "stat": "weakness", "type": "corruption", "value": 5 },
  "skills": [{ "group": "intrigue", "count": 1 }],
  "abilities": [{ "name": "Corrupt Spirit" }]
}
```
Each grant type is processed by its `*_grants_service.dart`. Stats go to `HeroValues`, content to `HeroEntries`.

### HeroEntry Source Tracking
All hero content uses `sourceType`/`sourceId` to track origin:
- `sourceType`: `"class"`, `"ancestry"`, `"complication"`, `"kit"`, `"perk"`, `"title"`, `"manual_choice"`, `"class_feature"`
- `sourceId`: The component ID that granted it
This enables cleanup when a source is removed (e.g., changing class removes class-granted abilities).

### Widgets
- Reusable cards in `lib/widgets/` organized by content type
- `ExpandableCard` with `AutomaticKeepAliveClientMixin` for scroll persistence
- Theme colors/emojis via `DsTheme` extension (`core/theme/ds_theme.dart`)

---

## Data Files

### Simplified Abilities Format (PRIMARY)
Located in `data/abilities/class_abilities_simplified/`. Flat structure:
```json
{ "id": "back-3-ferocity", "name": "Back!", "resource": "Ferocity", "resource_value": 3, "keywords": "Area/Melee/Weapon", "tier_effects": [...] }
```
Legacy `class_abilities/` folder is **skipped** during seeding.

### Class Definitions
Per-class JSON in `data/classes_levels_and_stats/` (e.g., `fury.json`). Contains:
- `starting_characteristics`, `stamina_per_level`, `baseRecoveries`
- `levels[]` with features and `new_abilities` counts per cost tier

---

## Commands

### Build & Run
```powershell
cd hero_smith
flutter pub get
flutter run  # or flutter run -d windows
```

### Code Generation (Drift)
```powershell
dart run build_runner build --delete-conflicting-outputs
```

### Database Reset
Delete `hero_smith.db` or uninstall app. See [DATABASE_RESET_GUIDE.md](../DATABASE_RESET_GUIDE.md).

---

## Development Notes

### State Management
Uses Riverpod with `StreamProvider` for reactive DB watches. Avoid `AsyncValue.when` nesting that causes flicker—use `valueOrNull` for stale-while-revalidate pattern.

### Planning Documents
`draw_steel_hero_smith_app_plan/` contains Obsidian markdown specs:
- `objects/` - Data model definitions
- `systems/` - Level-up, power rolls, bonuses
- `bugs/` - Known issues and priorities

### Test Directory
`hero_smith/test/` exists but is currently empty. Tests should override `autoSeedEnabledProvider` to `false`.
