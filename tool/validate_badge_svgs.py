#!/usr/bin/env python3
"""Validate local square badge SVG assets."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BADGE_DIR = ROOT / "assets" / "badge_svgs"
FLAGS_DIR = BADGE_DIR / "flags"
CATEGORIES_DIR = BADGE_DIR / "categories"
PALETTE_PATH = BADGE_DIR / "palette_tokens.json"
HEX_RE = re.compile(r"#[0-9A-Fa-f]{6}")


def load_palette() -> tuple[set[str], set[str], set[str]]:
    payload = json.loads(PALETTE_PATH.read_text(encoding="utf-8"))
    colors = {str(v).upper() for v in payload.get("approved_hex_colors", [])}
    countries = {str(v).upper() for v in payload.get("required_country_codes", [])}
    categories = {str(v).strip() for v in payload.get("required_category_keys", [])}
    return colors, countries, categories


def main() -> int:
    if not PALETTE_PATH.exists():
        print("Missing assets/badge_svgs/palette_tokens.json")
        return 1

    approved_colors, required_countries, required_categories = load_palette()
    errors: list[str] = []

    for code in sorted(required_countries):
        path = FLAGS_DIR / f"{code.lower()}.svg"
        if not path.exists():
            errors.append(f"Missing flag svg: {path.relative_to(ROOT)}")

    for key in sorted(required_categories):
        path = CATEGORIES_DIR / f"{key}.svg"
        if not path.exists():
            errors.append(f"Missing category svg: {path.relative_to(ROOT)}")

    for svg_path in sorted(list(FLAGS_DIR.glob("*.svg")) + list(CATEGORIES_DIR.glob("*.svg"))):
        content = svg_path.read_text(encoding="utf-8")
        if "<text" in content.lower():
            errors.append(f"{svg_path.relative_to(ROOT)} contains disallowed <text>")
        tokens = {t.upper() for t in HEX_RE.findall(content)}
        bad = sorted(t for t in tokens if t not in approved_colors)
        if bad:
            errors.append(
                f"{svg_path.relative_to(ROOT)} contains non-approved colors: {', '.join(bad)}"
            )

    if errors:
        print("Badge SVG validation failed:")
        for err in errors:
            print(f"- {err}")
        return 1

    flag_count = len(list(FLAGS_DIR.glob("*.svg")))
    cat_count = len(list(CATEGORIES_DIR.glob("*.svg")))
    print(f"Badge SVG validation passed ({flag_count} flags, {cat_count} categories)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
