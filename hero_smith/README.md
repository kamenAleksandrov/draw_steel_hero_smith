# Hero Smith

Assemble heroes from modular **Components** (classes, abilities, titles, perks, ancestry traits, etc.).

## Current Status
- Initial Flutter scaffold with empty home page.
- `Component` base model defined (extensible key-value payload).
- All JSON under `data/` declared as Flutter assets for seeding.

## Planned Data Flow
1. On first run: load every JSON file in `data/` as seed, flatten into a unified in-memory index of `Component`s.
2. Persist a merged local database file (e.g. `components.json`) inside app documents directory.
3. Subsequent launches: load local db first; optionally re-import new seeds if versions differ.
4. Provide CRUD for user-created or modified Components (never mutating original asset files).

## Tech Stack
- Flutter (Android / iOS / Windows)
- Riverpod state management
- Local storage via file system (can later upgrade to Hive/Isar if needed).

## Running
```bash
flutter pub get
flutter run
```

## Next Steps
- Implement ComponentRepository (seed loader + local persistence)
- Riverpod providers for repository + filters (by type)
- Hero profile model & builder UI scaffold
- Import versioning & conflict resolution

## Naming
"Components" is the generic umbrella for every functional hero part.

---
Feel free to request the next feature to implement.
