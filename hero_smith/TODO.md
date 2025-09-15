<!-- Reminder: finish projects and finalize titles across data sets -->

# TODO

## Legend
Priority: P1 (high), P2 (medium), P3 (low)
Tags: [data], [schema], [refactor], [ux], [perf]

## High Priority
- [P1][data] Finish defining project points usage and finalize any unfinished project-related data structures. (ID: T001)
- [P1][data] Complete and polish all project entries (names, descriptions, costs). (ID: T002)
- [P1][data] Standardize all item, ability, ancestry, career, and feature titles (capitalization + naming rules). (ID: T003)
- [P1][data] Ensure all complication entries have final benefit/drawback/both parsing (grants already present). (ID: T004)

## Medium Priority
- [P2][schema] Add JSON Schema files (abilities, ancestries, careers, complications, skills, languages). (ID: T005)
- [P2][data] Add stable slug ids to skills and languages (kebab-case). (ID: T006)
- [P2][refactor] Build derived indexes (abilities by damage type; languages by type/region; skills by group). (ID: T007)

## Low Priority
- [P3][ux] Draft chip renderer spec (damage types, conditions, potencies). (ID: T008)
- [P3][data] Add localization key scaffolding for all text fields. (ID: T009)
- [P3][perf] Precompute search index (names, keywords, tags). (ID: T010)

## Backlog
- [schema] Validation script: every ancestry has full min/max physical ranges. (ID: T011)
- [schema] Validation script: each feature referenced in grants exists. (ID: T012)
- [refactor] Normalize treasure rarity & echelon mapping table. (ID: T013)

## Done
- Flatten skills list (`data/story/skills.json`) (2025-09-16)
- Extract benefit/drawback/both for complications (2025-09-16)
- Normalize abilities schema (initial pass) (2025-09-15)

## Notes
- IDs (T###) can be referenced in inline code comments: `// TODO T006: add slugs once naming rules locked`.
- Keep this file short; move long-term strategy items to an issue tracker if adopted later.
