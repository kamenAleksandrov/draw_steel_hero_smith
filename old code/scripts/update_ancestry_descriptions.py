#!/usr/bin/env python3
"""
Script to update ancestry_traits.json with descriptions from TypeScript source files.

This script:
1. Reads TypeScript ancestry files from data_unused/compendium/Ancestries/
2. Extracts signature feature descriptions and trait descriptions
3. Updates the corresponding entries in data/story/ancestries/ancestry_traits.json

Matching is done by name (case-insensitive).
"""

import os
import re
import json
from pathlib import Path

# Base paths
SCRIPT_DIR = Path(__file__).parent
TS_DIR = SCRIPT_DIR / "hero_smith" / "data_unused" / "compendium" / "Ancestries"
JSON_FILE = SCRIPT_DIR / "hero_smith" / "data" / "story" / "ancestries" / "ancestry_traits.json"

# Mapping of JSON ancestry IDs to TS file names
ANCESTRY_FILE_MAP = {
    "ancestry_devil": "devil.ts",
    "ancestry_dragon_knight": "dragon-knight.ts",
    "ancestry_dwarf": "dwarf.ts",
    "ancestry_wode_elf": "elf-wode.ts",
    "ancestry_high_elf": "elf-high.ts",
    "ancestry_hakaan": "hakaan.ts",
    "ancestry_human": "human.ts",
    "ancestry_memonek": "memonek.ts",
    "ancestry_orc": "orc.ts",
    "ancestry_polder": "polder.ts",
    "ancestry_revenant": "revenant.ts",
    "ancestry_time_raider": "time-raider.ts",
}


def extract_string_content(text: str, start_pos: int) -> tuple[str, int]:
    """
    Extract a string starting from start_pos.
    Returns (content, end_position).
    Handles single quotes, double quotes, and template literals.
    """
    if start_pos >= len(text):
        return "", start_pos
    
    char = text[start_pos]
    
    if char == '`':
        # Template literal - find closing backtick
        end_idx = start_pos + 1
        while end_idx < len(text):
            if text[end_idx] == '`':
                break
            if text[end_idx] == '\\' and end_idx + 1 < len(text):
                end_idx += 2
                continue
            end_idx += 1
        content = text[start_pos + 1:end_idx]
        # Clean up template literal
        content = content.strip()
        lines = [line.strip() for line in content.split('\n')]
        content = '\n'.join(lines)
        content = re.sub(r'\n{3,}', '\n\n', content)
        return content.strip(), end_idx + 1
    
    elif char in ("'", '"'):
        # Regular string
        end_idx = start_pos + 1
        while end_idx < len(text):
            if text[end_idx] == char:
                break
            if text[end_idx] == '\\' and end_idx + 1 < len(text):
                end_idx += 2
                continue
            end_idx += 1
        content = text[start_pos + 1:end_idx]
        # Handle escape sequences
        content = content.replace("\\'", "'").replace('\\"', '"').replace('\\n', '\n')
        return content, end_idx + 1
    
    return "", start_pos


def parse_ts_file(filepath: Path) -> dict:
    """
    Parse a TypeScript ancestry file and extract feature descriptions.
    
    Returns a dict with:
    - all_features: list of {name, description} for all features with descriptions
    """
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    all_features = []
    
    # Find all name/description pairs
    # Pattern: name: 'Something', ... description: 'Something else'
    # We'll scan through and find each name field, then look for its description
    
    # Find all occurrences of name: followed by a string
    name_pattern = re.compile(r"\bname:\s*(['\"`])")
    
    for name_match in name_pattern.finditer(content):
        # Extract the name value
        name_start = name_match.end() - 1
        name_value, name_end = extract_string_content(content, name_start)
        
        if not name_value:
            continue
        
        # Look for description: after this name within a reasonable range
        # Search within the next 2000 characters or until we hit another 'name:'
        search_start = name_end
        search_end = min(len(content), name_end + 2000)
        
        # Find the next 'name:' to limit our search
        next_name = content.find("name:", search_start)
        if next_name != -1 and next_name < search_end:
            search_end = next_name
        
        search_region = content[search_start:search_end]
        
        # Look for description:
        desc_match = re.search(r"\bdescription:\s*(['\"`])", search_region)
        if desc_match:
            desc_start = search_start + desc_match.end() - 1
            desc_value, _ = extract_string_content(content, desc_start)
            
            if desc_value:
                all_features.append({
                    "name": name_value,
                    "description": desc_value
                })
    
    return {"all_features": all_features}


def normalize_name(name: str) -> str:
    """Normalize a name for comparison."""
    return name.lower().replace(" ", "").replace("-", "").replace("_", "").replace("'", "")


def find_matching_description(name: str, features: list) -> str | None:
    """Find a matching description by name."""
    normalized_target = normalize_name(name)
    for feature in features:
        if normalize_name(feature["name"]) == normalized_target:
            return feature["description"]
    return None


def update_json_with_descriptions():
    """Main function to update the JSON file with TS descriptions."""
    
    # Load the JSON file
    with open(JSON_FILE, 'r', encoding='utf-8') as f:
        json_data = json.load(f)
    
    updates_made = 0
    
    for ancestry_entry in json_data:
        ancestry_id = ancestry_entry.get("ancestry_id", "")
        
        if ancestry_id not in ANCESTRY_FILE_MAP:
            print(f"Warning: No TS file mapping for {ancestry_id}")
            continue
        
        ts_file = TS_DIR / ANCESTRY_FILE_MAP[ancestry_id]
        if not ts_file.exists():
            print(f"Warning: TS file not found: {ts_file}")
            continue
        
        print(f"\nProcessing {ancestry_id} from {ts_file.name}...")
        
        # Parse the TS file
        ts_data = parse_ts_file(ts_file)
        all_features = ts_data["all_features"]
        
        print(f"  Found {len(all_features)} features with descriptions")
        
        # Update signature description
        signature = ancestry_entry.get("signature", {})
        if signature and signature.get("name"):
            sig_name = signature["name"]
            # Handle combined names like "Shadowmeld & Small!"
            sig_parts = re.split(r'\s*[&,]\s*', sig_name)
            
            matching_desc = None
            for part in sig_parts:
                part = part.strip()
                desc = find_matching_description(part, all_features)
                if desc:
                    matching_desc = desc
                    break
            
            if matching_desc:
                old_desc = signature.get("description", "")
                if old_desc != matching_desc:
                    signature["description"] = matching_desc
                    updates_made += 1
                    print(f"  Updated signature '{sig_name}'")
        
        # Update trait descriptions
        for trait in ancestry_entry.get("traits", []):
            trait_name = trait.get("name", "")
            if not trait_name:
                continue
            
            matching_desc = find_matching_description(trait_name, all_features)
            if matching_desc:
                old_desc = trait.get("description", "")
                if old_desc != matching_desc:
                    trait["description"] = matching_desc
                    updates_made += 1
                    print(f"  Updated trait '{trait_name}'")
    
    # Write the updated JSON
    with open(JSON_FILE, 'w', encoding='utf-8') as f:
        json.dump(json_data, f, indent=2, ensure_ascii=False)
    
    print(f"\n\nDone! Made {updates_made} updates to {JSON_FILE}")


if __name__ == "__main__":
    print("=" * 60)
    print("Ancestry Traits Description Updater")
    print("=" * 60)
    print(f"\nTS Source: {TS_DIR}")
    print(f"JSON Target: {JSON_FILE}")
    print()
    
    if not TS_DIR.exists():
        print(f"Error: TS directory not found: {TS_DIR}")
        exit(1)
    
    if not JSON_FILE.exists():
        print(f"Error: JSON file not found: {JSON_FILE}")
        exit(1)
    
    update_json_with_descriptions()
