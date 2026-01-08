# Test Heroes for Hero Smith

This folder contains comprehensive test heroes that cover ALL game content scenarios for testing the app.

## How to Import

1. Open Hero Smith app
2. Go to Heroes page
3. Use Import Hero feature
4. Paste the hero code from the `.txt` files in `import_codes/` folder

## Test Heroes Coverage

| # | Hero | Class | Subclass | Level | Ancestry | Key Testing Focus |
|---|------|-------|----------|-------|----------|-------------------|
| 1 | Ragnar Stormfist | Fury | Berserker | 1 | Dwarf | Martial class, melee, kit bonuses |
| 2 | Sister Luminara | Conduit | Life/Protection | 3 | Human | Divine caster, domains, deity |
| 3 | Zephyr Shadowmend | Shadow | Harlequin Mask | 5 | Polder | Sneaky class, small size (1S) |
| 4 | Lord Maximilian | Tactician | Vanguard | 7 | High Elf | Leadership, multi-stat builds |
| 5 | Kira Mindshaper | Talent | Telepathy | 10 | Memonek | Psionic class, max level |
| 6 | Ashara Flameheart | Elementalist | Fire | 4 | Devil | Elemental magic, infernal |
| 7 | Thorne the Redeemed | Censor | Exorcist | 6 | Revenant | Wrath class, undead ancestry |
| 8 | Lyra Starwhisper | Troubadour | Virtuoso | 2 | Wode Elf | Performer class |
| 9 | Grimlock Nullbane | Null | Metakinetic | 8 | Time Raider | Psionics, exotic ancestry |
| 10 | Drakon Shieldscale | Fury | Stormwight | 5 | Dragon Knight | Heavy armor, equipment |
| 11 | Gorak Ironfist | Fury | Reaver | 4 | Orc | Dual wielder, outlaw |
| 12 | Yaroslav the Bold | Conduit | War/Storm | 3 | Hakaan | Large size (1L), rider |

## Content Coverage Summary

### Ancestries Covered (10 of 12)
- ✅ Devil, Dragon Knight, Dwarf, Hakaan, High Elf, Human, Memonek, Orc, Polder, Revenant, Time Raider, Wode Elf
- ❌ Not covered: None (all major ancestries covered)

### Classes & Subclasses Covered
| Class | Subclasses Covered |
|-------|-------------------|
| Censor | Exorcist |
| Conduit | Life, Protection, War, Storm (4 domains) |
| Elementalist | Fire |
| Fury | Berserker, Reaver, Stormwight (all 3!) |
| Null | Metakinetic |
| Shadow | Harlequin Mask |
| Tactician | Vanguard |
| Talent | Telepathy |
| Troubadour | Virtuoso |

### Levels Covered
- Level 1, 2, 3, 4, 5, 6, 7, 8, 10
- Echelon 1 (levels 1-3): ✅
- Echelon 2 (levels 4-6): ✅
- Echelon 3 (levels 7-9): ✅
- Echelon 4 (level 10): ✅

### Cultures Covered
- **Environments**: Rural, Urban, Wilderness, Secluded, Nomadic (all 5!)
- **Organisations**: Communal, Bureaucratic (both!)
- **Upbringings**: Martial, Academic, Lawless, Noble, Creative, Labor (all 6!)

### Careers Covered
- Gladiator, Disciple, Criminal, Aristocrat, Sage, Mage's Apprentice, Soldier, Performer, Warden, Explorer, Laborer

### Kits Covered
- Mountain, Warrior Priest, Cloak and Dagger, Shining Armor, Battlemind, Spellsword, Sword and Board, Swashbuckler, Martial Artist, Guisarmier, Dual Wielder, Ranger

### Complications Covered
- Thrill Seeker, Vow of Duty, Secret Identity, Famous Relative, Psychic Eruption, Infernal Contract, Hunted, Feytouched, Lost in Time, Dragon Dreams, Outlaw, Hawk Rider

### Deities Covered
- **Gods**: Salorna, Nikros, Ord, Kul, Adûn
- **Saints**: Pentalion, Magnetar, Ripples, Cho'kassa

### Skills Covered
- From all 6 groups: Crafting, Exploration, Interpersonal, Intrigue, Lore

### Perks Covered (by category)
- **Exploration**: Brawny, Danger Sense, Camouflage Hunter, Monster Whisperer, Team Leader, Teamwork, Wood Wise, Put Your Back Into It
- **Interpersonal**: Dazzler, Engrossing Monologue, Harmonizer, Charming Liar, Power Player
- **Intrigue**: Master of Disguise, Forgettable Face, Criminal Contacts, Slipped Lead
- **Lore**: Polymath, Specialist, Eidetic Memory
- **Supernatural**: Ritualist, Psychic Whisper, Arcane Trick, Creature Sense, Invisible Force

### Titles Covered (by echelon)
- **Echelon 1**: Brawler, Local Hero, City Rat, Marshal, Ancient Loremaster, Elemental Dabbler, Mage Hunter, Monster Bane, Zombie Slayer, Troupe Leading Player, Presumed Dead, Dwarven Legionnaire, Wanted Dead or Alive, Faction Member
- **Echelon 2**: Heist Hero, Knight, Battlefield Commander, Master Librarian, Awakened, Undead Slain, Sworn Hunter, Giant Slayer
- **Echelon 3**: Planar Voyager
- **Echelon 4**: Enlightened, Tireless

### Size Variants Covered
- 1S (Small): Polder
- 1M (Medium): Most heroes
- 1L (Large): Hakaan

## Generating Import Codes

Run the Python script to generate import codes from the JSON files:

```bash
cd hero_smith/test_heroes
python generate_import_codes.py
```

This will create `.txt` files with the import codes in the `import_codes/` folder.

## Quick Import

You can find all codes in: `import_codes/ALL_HEROES_CODES.txt`
