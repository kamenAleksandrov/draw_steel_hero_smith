#!/usr/bin/env python3
"""
Convert compendium ability JSON files into the standardized class ability schema.

Reads every JSON file within data/compendium/Abilities and writes a transformed
version into data/abilities/class_abilities_new, preserving the relative
directory structure.
"""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional


ROOT = Path(__file__).resolve().parent.parent
SOURCE_DIR = ROOT / "data" / "compendium" / "Abilities"
TARGET_DIR = ROOT / "data" / "abilities" / "class_abilities_new"


DAMAGE_TYPES = [
    "acid",
    "cold",
    "corruption",
    "fire",
    "holy",
    "lightning",
    "poison",
    "psychic",
    "sonic",
]

CONDITION_KEYWORDS = [
    "bleeding",
    "dazed",
    "frightened",
    "grabbed",
    "prone",
    "restrained",
    "slowed",
    "taunted",
    "weakened",
]

ACTION_TYPE_MAP = {
    "main action": "Main action",
    "maneuver": "Maneuver",
    "move": "Move action",
    "move action": "Move action",
    "triggered": "Triggered action",
    "triggered action": "Triggered action",
    "free triggered": "Free triggered action",
    "free triggered action": "Free triggered action",
    "free maneuver": "Free maneuver",
    "free action": "Free maneuver",
    "no action": "No action",
}

AREA_LABELS = {
    "aura": "Aura",
    "burst": "Burst",
    "cube": "Cube",
    "line": "Line",
    "wall": "Wall",
}


@dataclass
class TierDetails:
    base_damage_value: Optional[int]
    characteristic_damage_options: Optional[str]
    damage_types: Optional[str]
    potencies: Optional[str]
    conditions: Optional[str]

    def to_dict(self) -> Dict[str, Optional[str]]:
        return {
            "base_damage_value": self.base_damage_value,
            "characteristic_damage_options": self.characteristic_damage_options,
            "damage_types": self.damage_types,
            "potencies": self.potencies,
            "conditions": self.conditions,
        }


def slugify(value: str) -> str:
    slug = re.sub(r"[^0-9a-z]+", "_", value.lower())
    slug = re.sub(r"_+", "_", slug)
    return slug.strip("_") or "ability"


def normalise_action_type(data: Dict) -> Optional[str]:
    candidates = [
        data.get("metadata", {}).get("action_type"),
        data.get("usage"),
    ]
    for candidate in candidates:
        if not candidate:
            continue
        key = candidate.strip().lower()
        mapped = ACTION_TYPE_MAP.get(key)
        if mapped:
            return mapped
    return candidates[0].strip() if candidates[0] else None


def parse_range(distance: Optional[str]) -> Dict[str, Optional[str]]:
    if not distance:
        return {"distance": None, "area": None, "range_value": None}

    original = distance.strip()
    lower = original.lower()
    distance_type: Optional[str] = None
    area: Optional[str] = None
    range_value: Optional[str] = None

    melee_or_ranged_match = re.match(r"melee\s*\d*\s*or\s*ranged", lower)
    if lower.startswith("melee or ranged") or melee_or_ranged_match:
        distance_type = "Melee or Ranged"
    elif lower.startswith("melee"):
        distance_type = "Melee"
    elif lower.startswith("ranged"):
        distance_type = "Ranged"
    elif lower.startswith("self"):
        distance_type = "Self"
    elif lower.startswith("special"):
        distance_type = "Special"

    if distance_type == "Melee or Ranged":
        melee_match = re.search(r"melee\s*(\d+)", lower)
        ranged_match = re.search(r"ranged\s*(\d+)", lower)
        if melee_match and ranged_match:
            range_value = f"Melee {melee_match.group(1)} or Ranged {ranged_match.group(1)}"
        else:
            range_value = original
    elif distance_type == "Melee":
        melee_match = re.search(r"melee\s*(\d+)", lower)
        if melee_match:
            range_value = int(melee_match.group(1))
    elif distance_type == "Ranged":
        ranged_match = re.search(r"ranged\s*(\d+)", lower)
        if ranged_match:
            range_value = int(ranged_match.group(1))
    elif distance_type == "Self":
        tail = original[4:].strip()
        range_value = tail or None
    elif distance_type == "Special":
        range_value = original

    # Detect area component (aura, burst, cube, line, wall)
    for key, label in AREA_LABELS.items():
        if key in lower:
            area = label
            break

    def _extract_area_size() -> Optional[str]:
        if not area:
            return None
        if area == "Line":
            match = re.search(r"(\d+)\s*x\s*(\d+)\s*line", lower)
            if match:
                return f"{match.group(1)} x {match.group(2)}"
        match = re.search(r"(\d+)\s*" + area.lower(), lower)
        if match:
            return match.group(1)
        return None

    area_size = _extract_area_size()
    within_match = re.search(r"within\s+(\d+)", lower)

    if area:
        area_range_parts: List[str] = []
        if area_size:
            area_range_parts.append(area_size)
        if within_match:
            area_range_parts.append(f"within {within_match.group(1)}")
        if area_range_parts:
            range_suffix = " ".join(area_range_parts)
            range_value = range_suffix if not range_value else f"{range_value} ({range_suffix})"
        if not distance_type or distance_type == "Special":
            distance_type = "Ranged" if within_match else "Self"

    if isinstance(range_value, str):
        range_value = range_value.strip()

    return {
        "distance": distance_type,
        "area": area,
        "range_value": range_value,
    }


def _format_condition_phrase(text: str) -> str:
    text = text.strip()
    if not text:
        return text

    def _replace(match: re.Match) -> str:
        word = match.group(0)
        return word.capitalize()

    return re.sub(r"^[a-z]+", _replace, text, count=1)


def parse_tier_text(text: Optional[str]) -> Optional[TierDetails]:
    if not text:
        return None

    working = text.strip()
    if not working:
        return None

    remaining = working
    base_damage_value: Optional[int] = None
    characteristic_damage_options: Optional[str] = None
    damage_types: Optional[str] = None
    potencies: Optional[str] = None
    condition_phrases: List[str] = []

    base_match = re.match(r"\s*(\d+)", remaining)
    if base_match:
        base_damage_value = int(base_match.group(1))
        remaining = remaining[base_match.end():]

    char_pattern = re.compile(
        r"\+\s*([MARIP](?:\s*,\s*[MARIP])*(?:\s*,?\s*or\s*[MARIP])?)\s*(?:[a-z\s]+)?damage",
        re.IGNORECASE,
    )
    char_match = char_pattern.search(remaining)
    if char_match:
        letters_segment = re.sub(r"\bor\b", "", char_match.group(1), flags=re.IGNORECASE)
        letters = re.findall(r"[MARIP]", letters_segment, flags=re.IGNORECASE)
        if letters:
            letters = [letter.upper() for letter in letters]
            if len(letters) == 1:
                characteristic_damage_options = f"{letters[0]} damage"
            else:
                characteristic_damage_options = "/".join(letters) + " damage"
        remaining = char_pattern.sub("", remaining, count=1)

    found_damage_types: List[str] = []
    for dtype in DAMAGE_TYPES:
        if re.search(r"\b" + dtype + r"\b", working, re.IGNORECASE):
            found_damage_types.append(dtype)
            remaining = re.sub(r"\b" + dtype + r"\b", "", remaining, flags=re.IGNORECASE)
    if found_damage_types:
        # Preserve original ordering by first occurrence in text
        order: List[str] = []
        for match in re.finditer(
            r"\b(" + "|".join(re.escape(dt) for dt in found_damage_types) + r")\b",
            working,
            flags=re.IGNORECASE,
        ):
            token = match.group(1).lower()
            if token not in order:
                order.append(token)
        damage_types = "/".join(order)

    pot_pattern = re.compile(r"([MARIP])\s*<\s*(WEAK|AVERAGE|STRONG)", re.IGNORECASE)
    pot_match = pot_pattern.search(remaining)
    if pot_match:
        potencies = f"{pot_match.group(1).upper()} < {pot_match.group(2).upper()}"
        remaining = pot_pattern.sub("", remaining, count=1)

    for cond in CONDITION_KEYWORDS:
        cond_pattern = re.compile(r"\b" + cond + r"(?:\s*\(save ends\))?", re.IGNORECASE)
        cond_matches = cond_pattern.findall(remaining)
        for match_text in cond_matches:
            formatted = _format_condition_phrase(match_text)
            condition_phrases.append(formatted)
            remaining = cond_pattern.sub("", remaining, count=1)

    # Remove leftover keywords that are not helpful noise
    remaining = re.sub(r"\bdamage\b", "", remaining, flags=re.IGNORECASE)
    remaining = re.sub(r"[+;,]", " ", remaining)
    remaining = re.sub(r"\s+", " ", remaining).strip(" .")
    if remaining:
        condition_phrases.append(remaining)

    if condition_phrases:
        seen = set()
        deduped = []
        for phrase in condition_phrases:
            key = phrase.lower()
            if key not in seen:
                seen.add(key)
                deduped.append(phrase)
        conditions = "; ".join(deduped)
    else:
        conditions = None

    return TierDetails(
        base_damage_value=base_damage_value,
        characteristic_damage_options=characteristic_damage_options,
        damage_types=damage_types,
        potencies=potencies,
        conditions=conditions,
    )


def parse_power_roll(effects: Iterable[Dict]) -> Optional[Dict[str, object]]:
    for effect in effects:
        roll = effect.get("roll")
        if not roll:
            continue
        characteristic_segment = roll.split("+", 1)[-1].strip()
        characteristic_segment = characteristic_segment.replace("Power Roll", "").strip()
        characteristic_segment = re.sub(r"^(\+|\band\b)\s*", "", characteristic_segment, flags=re.IGNORECASE)
        characteristics = re.sub(r"\s+", " ", characteristic_segment).strip()

        tiers = {
            "low": parse_tier_text(effect.get("tier1")),
            "mid": parse_tier_text(effect.get("tier2")),
            "high": parse_tier_text(effect.get("tier3")),
        }

        tier_payload = {}
        any_data = False
        for key, tier in tiers.items():
            if tier is None:
                tier_payload[key] = None
            else:
                any_data = True
                tier_payload[key] = tier.to_dict()

        return {
            "label": "Power roll",
            "characteristics": characteristics or None,
            "tiers": tier_payload if any_data else None,
        }
    return None


def split_effects(effects: Iterable[Dict]) -> Dict[str, Optional[str]]:
    main_effects: List[str] = []
    special_effects: List[str] = []

    for effect in effects:
        if effect.get("roll"):
            continue
        text = effect.get("effect")
        if not text:
            continue
        name = effect.get("name")
        if not name or name.lower() == "effect":
            main_effects.append(text.strip())
        else:
            special_effects.append(f"{name.strip()}: {text.strip()}")

    effect_text = "\n\n".join(main_effects) if main_effects else None
    special_text = "\n\n".join(special_effects) if special_effects else None

    return {"effect": effect_text, "special_effect": special_text}


def normalise_targets(value: Optional[str]) -> Optional[str]:
    if not value:
        return None
    return value.strip()


def normalise_keywords(value) -> List[str]:
    if isinstance(value, str):
        candidates = [value]
    elif isinstance(value, list):
        candidates = value
    else:
        candidates = []

    seen = set()
    keywords: List[str] = []
    for candidate in candidates:
        if isinstance(candidate, str):
            for token in candidate.split(","):
                keyword = token.strip()
                if keyword and keyword.lower() not in seen:
                    seen.add(keyword.lower())
                    keywords.append(keyword)
        else:
            keyword = str(candidate).strip()
            if keyword and keyword.lower() not in seen:
                seen.add(keyword.lower())
                keywords.append(keyword)
    return keywords


def transform_ability(source_path: Path, data: Dict) -> Dict[str, object]:
    metadata = data.get("metadata", {})

    action_type = normalise_action_type(data)
    range_data = parse_range(metadata.get("distance") or data.get("distance"))
    power_roll = parse_power_roll(data.get("effects", []))
    effects_payload = split_effects(data.get("effects", []))

    keywords = normalise_keywords(data.get("keywords") or metadata.get("keywords"))

    cost_amount = metadata.get("cost_amount")
    cost_resource = metadata.get("cost_resource")
    if (cost_amount is None or cost_resource is None) and data.get("cost"):
        cost_match = re.match(r"^\s*(\d+)\s+([A-Za-z]+)", data["cost"])
        if cost_match:
            if cost_amount is None:
                cost_amount = int(cost_match.group(1))
            if cost_resource is None:
                cost_resource = cost_match.group(2)
    costs = (
        {"resource": cost_resource, "amount": cost_amount}
        if cost_amount is not None or cost_resource is not None
        else None
    )

    id_source = data.get("name") or metadata.get("file_basename") or source_path.stem
    ability_id = slugify(id_source)

    transformed = {
        "type": "ability",
        "id": ability_id,
        "name": data.get("name"),
        "level": metadata.get("level"),
        "costs": costs,
        "story_text": data.get("flavor"),
        "keywords": keywords,
        "action_type": action_type,
        "trigger_text": data.get("trigger"),
        "range": range_data,
        "targets": normalise_targets(metadata.get("target") or data.get("target")),
        "power_roll": power_roll,
        "effect": effects_payload["effect"],
        "special_effect": effects_payload["special_effect"],
    }

    return transformed


def convert_files(overwrite: bool = True) -> int:
    if not SOURCE_DIR.exists():
        raise FileNotFoundError(f"Source directory not found: {SOURCE_DIR}")

    files = sorted(SOURCE_DIR.rglob("*.json"))
    if not files:
        return 0

    for file_path in files:
        relative_path = file_path.relative_to(SOURCE_DIR)
        target_path = TARGET_DIR / relative_path
        target_path.parent.mkdir(parents=True, exist_ok=True)

        with file_path.open("r", encoding="utf-8") as handle:
            data = json.load(handle)

        transformed = transform_ability(file_path, data)

        if target_path.exists() and not overwrite:
            continue

        with target_path.open("w", encoding="utf-8") as handle:
            json.dump(transformed, handle, indent=2, ensure_ascii=True)
            handle.write("\n")

    return len(files)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Convert compendium abilities to class ability schema.")
    parser.add_argument(
        "--no-overwrite",
        action="store_true",
        help="Do not overwrite existing files in the destination directory.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    count = convert_files(overwrite=not args.no_overwrite)
    print(f"Converted {count} ability files from {SOURCE_DIR} into {TARGET_DIR}")


if __name__ == "__main__":
    main()
