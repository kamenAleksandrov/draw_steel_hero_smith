import json
import re
from pathlib import Path
from typing import Dict, List, Any, Tuple

# Define the compendium and output paths
COMPENDIUM_PATH = Path("hero_smith/data_unused/compendium/Abilities")
OUTPUT_PATH = Path("hero_smith/data/abilities/class_abilities_simplified")

# Ensure output directory exists
OUTPUT_PATH.mkdir(parents=True, exist_ok=True)


def extract_level_from_folder(folder_name: str) -> int:
    """Extract a level number from folder names like '1st-Level Features'."""
    match = re.search(r"(\d+)", folder_name)
    if match:
        try:
            return int(match.group(1))
        except ValueError:
            pass
    return 1  # Default to 1 if the folder name does not contain a level number


def parse_cost_string(cost: str) -> Tuple[str, int]:
    """Parse a textual cost like '3 Ferocity' into resource name and numeric value."""
    if not cost:
        return "", 0

    match = re.match(r"\s*(\d+)\s+(.+)$", cost)
    if match:
        amount = match.group(1)
        resource = match.group(2)
        try:
            return resource.strip(), int(amount)
        except ValueError:
            pass

    return cost.strip(), 0


def normalize_level(metadata_level: Any, fallback_level: int) -> int:
    """Determine the ability level, preferring metadata and falling back to folder info."""
    if metadata_level is not None:
        if isinstance(metadata_level, int):
            return metadata_level
        if isinstance(metadata_level, float):
            return int(metadata_level)
        if isinstance(metadata_level, str):
            match = re.search(r"(\d+)", metadata_level)
            if match:
                try:
                    return int(match.group(1))
                except ValueError:
                    pass
    return fallback_level


def resolve_resource_fields(ability_data: Dict[str, Any], metadata: Dict[str, Any]) -> Tuple[str, int]:
    """Resolve resource name and value from metadata or cost fields."""
    resource_name = metadata.get("cost_resource", "")
    resource_value = metadata.get("cost_amount", 0)

    # Normalise possible string numeric values
    if isinstance(resource_value, str):
        try:
            resource_value = int(resource_value)
        except ValueError:
            resource_value = 0
    elif resource_value is None:
        resource_value = 0

    if not resource_name or resource_value == 0:
        parsed_name, parsed_value = parse_cost_string(ability_data.get("cost", ""))
        if parsed_name and not resource_name:
            resource_name = parsed_name
        if parsed_value and not resource_value:
            resource_value = parsed_value

    # Mark Signature abilities when they have no explicit cost
    if not resource_name and resource_value == 0 and metadata.get("ability_type") == "Signature":
        resource_name = "Signature"

    return resource_name, resource_value


def format_keywords(keywords: List[str]) -> str:
    """Convert keyword list to slash-separated string"""
    if not keywords:
        return ""
    return "/".join(keywords)


def convert_ability(ability_data: Dict[str, Any], fallback_level: int) -> Dict[str, Any]:
    """Convert a compendium ability record to the simplified format."""

    metadata = ability_data.get("metadata", {})
    level = normalize_level(metadata.get("level"), fallback_level)
    resource_name, resource_value = resolve_resource_fields(ability_data, metadata)

    simplified = {
        "type": "ability",
        "id": metadata.get("item_id", ""),
        "name": ability_data.get("name", ""),
        "level": level,
        "resource": resource_name,
        "resource_value": resource_value,
        "story_text": ability_data.get("flavor", ""),
        "keywords": format_keywords(ability_data.get("keywords", [])),
        "action_type": ability_data.get("usage", "").lower(),
        "trigger_text": ability_data.get("trigger", ""),
        "distance": ability_data.get("distance", ""),
        "targets": ability_data.get("target", ""),
        "power_roll": "",
        "tier_effects": [],
        "effect": "",
        "special_effect": ability_data.get("special", "")
    }

    effects = ability_data.get("effects", [])
    collected_effect_texts: List[str] = []

    for effect_entry in effects:
        if "roll" in effect_entry:
            simplified["power_roll"] = effect_entry.get("roll", "")

        tier_entry = {
            key: value
            for key, value in effect_entry.items()
            if key.startswith("tier") and value
        }
        if tier_entry:
            simplified["tier_effects"].append(tier_entry)

        if "effect" in effect_entry and effect_entry.get("effect"):
            collected_effect_texts.append(effect_entry["effect"])

    if collected_effect_texts:
        simplified["effect"] = "\n\n".join(collected_effect_texts)

    return simplified


def process_class_folder(class_name: str, class_path: Path) -> List[Dict[str, Any]]:
    """Process all abilities for a given class"""
    abilities = []
    
    # Handle Common abilities (organized by action type)
    if class_name == "Common":
        action_folders = ["Main Actions", "Maneuvers", "Move Actions"]
        for action_folder in action_folders:
            action_path = class_path / action_folder
            if action_path.exists():
                for json_file in action_path.glob("*.json"):
                    try:
                        with open(json_file, 'r', encoding='utf-8') as f:
                            ability_data = json.load(f)
                            simplified = convert_ability(ability_data, 1)  # Common abilities are level 1
                            abilities.append(simplified)
                            print(f"  ✓ Converted {json_file.name}")
                    except Exception as e:
                        print(f"  ✗ Error processing {json_file}: {e}")
    else:
        # Handle class abilities (organized by level)
        for level_folder in class_path.iterdir():
            if level_folder.is_dir():
                level = extract_level_from_folder(level_folder.name)
                
                for json_file in level_folder.glob("*.json"):
                    try:
                        with open(json_file, 'r', encoding='utf-8') as f:
                            ability_data = json.load(f)
                            simplified = convert_ability(ability_data, level)
                            abilities.append(simplified)
                            print(f"  ✓ Converted {json_file.name} (Level {level})")
                    except Exception as e:
                        print(f"  ✗ Error processing {json_file}: {e}")
    
    return abilities


def main():
    """Main conversion script"""
    print("Starting ability conversion from compendium to simplified format...")
    print(f"Reading from: {COMPENDIUM_PATH}")
    print(f"Writing to: {OUTPUT_PATH}\n")
    
    # Process each class folder
    for class_folder in COMPENDIUM_PATH.iterdir():
        if class_folder.is_dir():
            class_name = class_folder.name
            print(f"Processing {class_name}...")
            
            abilities = process_class_folder(class_name, class_folder)
            
            if abilities:
                # Write to output file
                output_file = OUTPUT_PATH / f"{class_name.lower()}_abilities.json"
                with open(output_file, 'w', encoding='utf-8') as f:
                    json.dump(abilities, f, indent=2, ensure_ascii=False)
                
                print(f"✓ Wrote {len(abilities)} abilities to {output_file.name}\n")
            else:
                print(f"⚠ No abilities found for {class_name}\n")
    
    print("Conversion complete!")


if __name__ == "__main__":
    main()
