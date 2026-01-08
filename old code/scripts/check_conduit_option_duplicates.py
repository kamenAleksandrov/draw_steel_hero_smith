import json
import re
from collections import Counter
from pathlib import Path

path = Path("data/features/class_features/conduit_features.json")

def slugify(value: str) -> str:
    normalized = re.sub(r"[^a-z0-9]+", "_", value.strip().lower())
    collapsed = re.sub(r"_+", "_", normalized)
    return re.sub(r"^_|_$", "", collapsed)

def option_key(option: dict) -> str:
    for key in ("name", "title", "domain"):
        value = option.get(key)
        if isinstance(value, str) and value.strip():
            return slugify(value)
    if option.get("skill"):
        return slugify(str(option["skill"]))
    if option.get("benefit"):
        return slugify(str(option["benefit"]))
    return "option"

with path.open("r", encoding="utf-8") as f:
    data = json.load(f)

for entry in data:
    if not isinstance(entry, dict):
        continue
    feature_id = entry.get("id")
    options = entry.get("options")
    if not isinstance(options, list):
        continue
    counter = Counter()
    for option in options:
        if not isinstance(option, dict):
            continue
        counter[option_key(option)] += 1
    duplicates = {k: v for k, v in counter.items() if v > 1}
    if duplicates:
        print(feature_id, duplicates)
