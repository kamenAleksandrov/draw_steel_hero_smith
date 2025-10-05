import json
import os
import re
from pathlib import Path

def slugify(value: str) -> str:
    normalized = re.sub(r"[^a-z0-9]+", "_", value.strip().lower())
    collapsed = re.sub(r"_+", "_", normalized)
    return re.sub(r"^_|_$", "", collapsed)

def feature_option_label(option: dict) -> str:
    for key in ("name", "title", "domain"):
        value = option.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    if option.get("skill"):
        return str(option["skill"])
    if option.get("benefit"):
        return str(option["benefit"])
    return "Option"

def option_key(option: dict) -> str:
    return slugify(feature_option_label(option))

def check_file(path: Path):
    with path.open("r", encoding="utf-8") as f:
        data = json.load(f)

    problems = []
    for entry in data:
        if not isinstance(entry, dict):
            continue
        feature_id = entry.get("id") or entry.get("name")
        options = entry.get("options")
        if not isinstance(options, list):
            continue
        seen = {}
        for option in options:
            if not isinstance(option, dict):
                continue
            key = option_key(option)
            if key in seen:
                problems.append(
                    {
                        "feature_id": feature_id,
                        "duplicate_key": key,
                        "first_name": seen[key],
                        "second_name": option.get("name"),
                    }
                )
            else:
                seen[key] = option.get("name")
    return problems

def main():
    root = Path("data/features/class_features")
    issues = {}
    for path in root.glob("*_features.json"):
        problems = check_file(path)
        if problems:
            issues[path.name] = problems

    if not issues:
        print("No duplicate option keys found.")
        return

    for filename, problems in issues.items():
        print(f"File: {filename}")
        for problem in problems:
            print(
                "  feature {feature_id} has duplicate key '{duplicate_key}' (names: {first_name} / {second_name})".format(
                    **problem
                )
            )

if __name__ == "__main__":
    main()
