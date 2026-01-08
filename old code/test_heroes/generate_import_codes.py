#!/usr/bin/env python3
"""
Generate Hero Smith import codes from JSON test hero files.

This script reads the JSON hero files and converts them to the HERO: format
that can be imported into the Hero Smith app.

Usage:
    python generate_import_codes.py

Output:
    Creates .txt files with import codes for each hero JSON file.
"""

import json
import gzip
import base64
import os
from pathlib import Path


def generate_hero_code(hero_data: dict) -> str:
    """Generate a HERO: format import code from hero data."""
    # Convert to JSON string
    json_str = json.dumps(hero_data, separators=(',', ':'))
    
    # Gzip compress
    compressed = gzip.compress(json_str.encode('utf-8'))
    
    # Base64 encode
    encoded = base64.b64encode(compressed).decode('utf-8')
    
    # Add prefix
    return f"HERO:{encoded}"


def main():
    # Get the directory containing this script
    script_dir = Path(__file__).parent
    
    # Find all hero JSON files
    json_files = sorted(script_dir.glob("hero_*.json"))
    
    if not json_files:
        print("No hero JSON files found!")
        return
    
    print(f"Found {len(json_files)} hero files\n")
    
    # Create codes directory
    codes_dir = script_dir / "import_codes"
    codes_dir.mkdir(exist_ok=True)
    
    # Also create a combined file
    all_codes = []
    
    for json_file in json_files:
        try:
            # Read JSON
            with open(json_file, 'r', encoding='utf-8') as f:
                hero_data = json.load(f)
            
            # Get hero name
            hero_name = hero_data.get('hero', {}).get('name', 'Unknown Hero')
            
            # Generate code
            code = generate_hero_code(hero_data)
            
            # Save to individual file
            output_file = codes_dir / f"{json_file.stem}_code.txt"
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write(f"# {hero_name}\n")
                f.write(f"# Level {hero_data.get('values', [{}])[0].get('value', '?')}\n")
                f.write(f"# Import this code in Hero Smith\n\n")
                f.write(code)
            
            # Add to combined list
            all_codes.append(f"# {hero_name}\n{code}\n")
            
            print(f"✓ Generated code for: {hero_name}")
            print(f"  Code length: {len(code)} characters")
            print(f"  Saved to: {output_file.name}")
            print()
            
        except Exception as e:
            print(f"✗ Error processing {json_file.name}: {e}")
            print()
    
    # Save combined file
    combined_file = codes_dir / "ALL_HEROES_CODES.txt"
    with open(combined_file, 'w', encoding='utf-8') as f:
        f.write("# All Test Heroes Import Codes\n")
        f.write("# Copy and paste each code individually to import\n")
        f.write("=" * 50 + "\n\n")
        f.write("\n".join(all_codes))
    
    print(f"\n{'=' * 50}")
    print(f"All codes saved to: {codes_dir}")
    print(f"Combined file: {combined_file.name}")


if __name__ == "__main__":
    main()
