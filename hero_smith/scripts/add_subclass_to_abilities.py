#!/usr/bin/env python3
"""
Script to add subclass field to class abilities JSON files.

This script takes a mapping of ability names to subclass names and updates
all class ability JSON files, adding a "subclass" field after the "level" field.
"""

import json
import os
from pathlib import Path
from typing import Dict, Optional

# =============================================================================
# CONFIGURATION: Map ability names to their subclass
# =============================================================================
# Format: "Ability Name": "Subclass Name"
# Leave empty string "" or None for abilities that don't belong to a subclass
# =============================================================================

ABILITY_TO_SUBCLASS: Dict[str, Optional[str]] = {
    # Example entries (replace with your actual data):
    # "Arrest": "Inquisitor",
    # "Faithful Friend": "Oracle",
    # "Grave Speech": "Exorcist",

    # censor abilities
    "It Is Justice You Fear": "Exorcist",
    "Revelator": "Exorcist",
    "Prescient Grace": "Oracle",
    "With My Blessing": "Oracle",
    "Blessing of the Faithful": "Paragon",
    "Sentenced": "Paragon",
    "Begone!": "Exorcist",
    "Pain of Your Own Making": "Exorcist",
    "Burden of Evil": "Oracle",
    "Edict of Peace": "Oracle",
    "Congregation": "Paragon",
    "Intercede": "Paragon",
    "Banish": "Exorcist",
    "Terror Manifest": "Exorcist",
    "Blessing and a Curse": "Oracle",
    "Fulfill Your Destiny": "Oracle",
    "Apostate": "Paragon",
    "Edict of Unyielding Resolve": "Paragon",

    #conduit abilities
    "Statue of Power": "Creation",
    "Reap": "Death",
    "Blessing of Fate and Destiny": "Fate",
    "The Gods Command You Obey": "Knowledge",
    "Wellspring of Grace": "Life",
    "Our Hearts Your Strength": "Love",
    "Nature Judges Thee": "Nature",
    "Sacred Bond": "Protection",
    "Saint’s Tempest": "Storm",
    "Morning Light": "Sun",
    "Divine Comedy": "Trickery",
    "Blessing of Insight": "War",
    "Gods’ Machine": "Creation",
    "Aura of Souls": "Death",
    "Your Story Ends Here": "Fate",
    "Invocation of Undoing": "Knowledge",
    "Revitalizing Grace": "Life",
    "Lauded by God": "Love",
    "Spirit Stampede": "Nature",
    "Cuirass of the Gods": "Protection",
    "Lightning Lord": "Storm",
    "Blessing of the Midday Sun": "Sun",
    "Invocation of Mystery": "Trickery",
    "Blade of the Heavens": "War",
    "Divine Dragon": "Creation",
    "Word of Final Redemption": "Death",
    "Bend Fate": "Fate",
    "Word of Weakening": "Knowledge",
    "Radiance of Grace": "Life",
    "Alacrity of the Heart": "Love",
    "Thorn Cage": "Nature",
    "Blessing of the Fortress": "Protection",
    "Godstorm": "Storm",
    "Solar Flare": "Sun",
    "Night Falls": "Trickery",
    "Righteous Phalanx": "War",

    # fury abilities
    "Special Delivery": "Berserker",
    "Wrecking Ball": "Berserker",
    "Death ... Death!": "Reaver",
    "Phalanx-Breaker": "Reaver",
    "Apex Predator": "Stormwight",
    "Visceral Roar": "Stormwight",
    "Avalanche Impact": "Berserker",
    "Force of Storms": "Berserker",
    "Death Strike": "Reaver",
    "Seek and Destroy": "Reaver",
    "Pounce": "Stormwight",
    "Riders on the Storm": "Stormwight",
    "Death Comes for You All!": "Berserker",
    "Primordial Vortex": "Berserker",
    "Primordial Bane": "Reaver",
    "Shower of Blood": "Reaver",
    "Death Rattle": "Stormwight",
    "Deluge": "Stormwight",

    # null subclass abilities
    "Blur": "Chronokinetic",
    "Force Redirected": "Chronokinetic",
    "Entropic Field": "Cryokinetic",
    "Heat Sink": "Cryokinetic",
    "Gravitic Strike": "Metakinetic",
    "Kinetic Shield": "Metakinetic",
    "Interphase": "Chronokinetic",
    "Phase Step": "Chronokinetic",
    "Ice Pillars": "Cryokinetic",
    "Wall of Ice": "Cryokinetic",
    "Gravitic Charge": "Metakinetic",
    "Iron Body": "Metakinetic",
    "Arrestor Cycle": "Chronokinetic",
    "Time Loop": "Chronokinetic",
    "Absolute Zero": "Cryokinetic",
    "Heat Drain": "Cryokinetic",
    "Inertial Absorption": "Metakinetic",
    "Realitas": "Metakinetic",

    # shadow abilities
    "In a Puff of Ash": "Black Ash",
    "Too Slow": "Black Ash",
    "Sticky Bomb": "Caustic Alchemy",
    "Stink Bomb": "Caustic Alchemy",
    "Machinations of Sound": "Harlequin Mask",
    "So Gullible": "Harlequin Mask",
    "Black Ash Eruption": "Black Ash",
    "Cinderstorm": "Black Ash",
    "One Vial Makes You Better": "Caustic Alchemy",
    "One Vial Makes You Faster": "Caustic Alchemy",
    "Look!": "Harlequin Mask",
    "Puppet Strings": "Harlequin Mask",
    "Cacophony of Cinders": "Black Ash",
    "Demon Door": "Black Ash",
    "Chain Reaction": "Caustic Alchemy",
    "To the Stars": "Caustic Alchemy",
    "I Am You": "Harlequin Mask",
    "It Was Me All Along": "Harlequin Mask",

    # tactician abilities
    "Fog of War": "Insurgent",
    "Try Me Instead": "Insurgent",
    "I’ve Got Your Back": "Mastermind",
    "Targets of Opportunity": "Mastermind",
    "No Dying on My Watch": "Vanguard",
    "Squad! On Me!": "Vanguard",
    "Coordinated Execution": "Insurgent",
    "Panic in Their Lines": "Insurgent",
    "Battle Plan": "Mastermind",
    "Hustle!": "Mastermind",
    "Instant Retaliation": "Vanguard",
    "To Me Squad!": "Vanguard",
    "Squad! Hit and Run!": "Insurgent",
    "Their Lack of Focus Is Their Undoing": "Insurgent",
    "Blot Out the Sun!": "Mastermind",
    "Counterstrategy": "Mastermind",
    "No Escape": "Vanguard",
    "That One Is Mine!": "Vanguard",

    # talent abilities
    "Applied Chronometrics": "Chronopathy",
    "Slow": "Chronopathy",
    "Gravitic Burst": "Telekinesis",
    "Levity and Gravity": "Telekinesis",
    "Overwhelm": "Telepathy",
    "Synaptic Override": "Telepathy",
    "Fate": "Chronopathy",
    "Slow": "Chronopathy",
    "Gravitic Well": "Telekinesis",
    "Greater Kinetic Grip": "Telekinesis",
    "Synaptic Conditioning": "Telepathy",
    "Synaptic Dissipation": "Telepathy",
    "Acceleration Field": "Chronopathy",
    "Borrow From the Future": "Chronopathy",
    "Fulcrum": "Telekinesis",
    "Gravitic Nova": "Telekinesis",
    "Resonant Mind Spike": "Telepathy",
    "Synaptic Terror": "Telepathy",

    # troubadour abilities
    "Guest Star": "Auteur",
    "Twist at the End": "Auteur",
    "Classic Chandelier Stunt": "Duelist",
    "En Garde!": "Duelist",
    "Encore": "Virtuoso",
    "Tough Crowd": "Virtuoso",
    "Here’s How Your Story Ends": "Auteur",
    "You’re All My Understudies": "Auteur",
    "Blood on the Stage": "Duelist",
    "Fight Choreography": "Duelist",
    "Feedback": "Virtuoso",
    "Legendary Drum Fill": "Virtuoso",
    "Epic": "Auteur",
    "Rising Tension": "Auteur",
    "Expert Fencer": "Duelist",
    "Renegotiated Contract": "Duelist",
    "Jam Session": "Virtuoso",
    "Melt Their Faces": "Virtuoso",

}

# =============================================================================
# SCRIPT LOGIC
# =============================================================================

def get_class_abilities_dir() -> Path:
    """Get the path to the class_abilities_simplified directory."""
    script_dir = Path(__file__).parent
    return script_dir.parent / "data" / "abilities" / "class_abilities_simplified"


def add_subclass_to_ability(ability: dict, subclass_map: Dict[str, Optional[str]]) -> bool:
    """
    Add subclass field to an ability if it's in the mapping.
    
    Returns True if the ability was modified, False otherwise.
    """
    ability_name = ability.get("name", "")
    
    if ability_name in subclass_map:
        subclass_value = subclass_map[ability_name]
        
        # Create a new ordered dict to maintain field order
        # We want "subclass" to appear right after "level"
        new_ability = {}
        for key, value in ability.items():
            new_ability[key] = value
            if key == "level":
                new_ability["subclass"] = subclass_value if subclass_value else None
        
        # Update the original dict
        ability.clear()
        ability.update(new_ability)
        return True
    
    return False


def process_abilities_file(file_path: Path, subclass_map: Dict[str, Optional[str]]) -> int:
    """
    Process a single abilities JSON file.
    
    Returns the number of abilities modified.
    """
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            abilities = json.load(f)
    except (json.JSONDecodeError, IOError) as e:
        print(f"  Error reading {file_path.name}: {e}")
        return 0
    
    if not isinstance(abilities, list):
        print(f"  Skipping {file_path.name}: not a list of abilities")
        return 0
    
    modified_count = 0
    for ability in abilities:
        if isinstance(ability, dict) and add_subclass_to_ability(ability, subclass_map):
            modified_count += 1
    
    if modified_count > 0:
        try:
            with open(file_path, 'w', encoding='utf-8') as f:
                json.dump(abilities, f, indent=2, ensure_ascii=False)
            print(f"  Modified {modified_count} abilities in {file_path.name}")
        except IOError as e:
            print(f"  Error writing {file_path.name}: {e}")
            return 0
    else:
        print(f"  No matching abilities in {file_path.name}")
    
    return modified_count


def main():
    """Main entry point."""
    if not ABILITY_TO_SUBCLASS:
        print("WARNING: ABILITY_TO_SUBCLASS mapping is empty!")
        print("Please add your ability-to-subclass mappings to the script.")
        print("\nExample format:")
        print('ABILITY_TO_SUBCLASS = {')
        print('    "Arrest": "Inquisitor",')
        print('    "Faithful Friend": "Oracle",')
        print('    "Grave Speech": "Exorcist",')
        print('}')
        return
    
    abilities_dir = get_class_abilities_dir()
    
    if not abilities_dir.exists():
        print(f"Error: Directory not found: {abilities_dir}")
        return
    
    print(f"Processing class abilities in: {abilities_dir}")
    print(f"Mapping {len(ABILITY_TO_SUBCLASS)} abilities to subclasses\n")
    
    total_modified = 0
    json_files = list(abilities_dir.glob("*_abilities.json"))
    
    if not json_files:
        print("No ability files found!")
        return
    
    for file_path in sorted(json_files):
        modified = process_abilities_file(file_path, ABILITY_TO_SUBCLASS)
        total_modified += modified
    
    print(f"\n{'='*50}")
    print(f"Total abilities modified: {total_modified}")
    
    # Report any abilities in the map that weren't found
    found_abilities = set()
    for file_path in json_files:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                abilities = json.load(f)
                for ability in abilities:
                    if isinstance(ability, dict):
                        found_abilities.add(ability.get("name", ""))
        except:
            pass
    
    not_found = set(ABILITY_TO_SUBCLASS.keys()) - found_abilities
    if not_found:
        print(f"\nWARNING: The following abilities from the map were not found:")
        for name in sorted(not_found):
            print(f"  - {name}")


if __name__ == "__main__":
    main()
