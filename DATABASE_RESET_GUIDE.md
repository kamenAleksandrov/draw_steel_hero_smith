# Database Reset Instructions

## Why Reset the Database?

The app has been updated to use a new simplified JSON format for abilities. To avoid seeing duplicate abilities in the Abilities page, you need to clear the old database and reseed with the new format.

## How to Reset

### Option 1: Delete the Database File (Recommended)

1. **Stop the app** if it's running
2. **Locate and delete the database file**:
   - **Android/iOS Simulator**: The easiest way is to uninstall and reinstall the app
   - **Desktop (Windows/Mac/Linux)**: Find and delete `hero_smith.db` in your app's data directory
   - **Web**: Clear browser storage for the app

3. **Restart the app** - it will automatically create a fresh database with the new simplified format

### Option 2: Use Database Maintenance (Programmatic)

Add this code temporarily to your app's initialization to clean up duplicates:

```dart
import 'package:hero_smith/core/db/database_maintenance.dart';
import 'package:hero_smith/core/db/app_database.dart';

// In your app initialization, before showing the UI:
final db = AppDatabase.instance;
await DatabaseMaintenance.removeDuplicateAbilities(db);
```

Or to completely clear and reseed:

```dart
final db = AppDatabase.instance;
await DatabaseMaintenance.clearAndReseed(db);
```

## What Changed

### Old Format (Legacy)
- Located in: `data/abilities/class_abilities/*.json`
- Structure: Complex nested objects with `costs`, `power_roll.tiers`, etc.
- **Now SKIPPED during seeding**

### New Format (Simplified)
- Located in: `data/abilities/class_abilities_simplified/*.json`
- Structure: Flat fields with `resource`, `roll`, `effects` array
- **Now the PRIMARY format**

### Data Changes

**Resource Costs:**
- Old: `"costs": { "resource": "Ferocity", "amount": 3 }`
- New: `"resource": "Ferocity 3"`

**Power Rolls:**
- Old: `"power_roll": { "characteristics": ["Might"], "tiers": {...} }`
- New: `"roll": "Power Roll + Might"` and `"effects": [{ "tier1": "...", "tier2": "...", "tier3": "..." }]`

**Empty Fields:**
- All empty fields (`""` or missing) are now handled gracefully - components won't display if the data is missing

## Verification

After resetting:

1. Open the **Abilities** page
2. You should see **NO duplicates** (only one "Back!", one "Brutal Slam", etc.)
3. Each ability should display properly with tiers if they have power rolls
4. Empty fields should be hidden (no blank sections)

## Troubleshooting

**Still seeing duplicates?**
- Make sure you fully deleted the database file and restarted the app
- Check that the old `class_abilities/*.json` files aren't being loaded (the seeder now skips them)

**Missing abilities?**
- Verify the simplified JSON files exist in `data/abilities/class_abilities_simplified/`
- Check the console for any parsing errors

**Data not displaying?**
- Empty fields are intentionally hidden - this is correct behavior
- If an ability has no tiers, power roll section won't show
- If there's no effect text, that section won't show
