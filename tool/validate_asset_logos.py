#!/usr/bin/env python3
"""Validate generated asset logo SVGs for textless pictogram policy and palette safety."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOGOS_DIR = ROOT / "assets" / "asset_logos"
PALETTE_TOKENS_PATH = LOGOS_DIR / "palette_tokens.json"
HEX_TOKEN_RE = re.compile(r"#[0-9A-Fa-f]{6}")


def _load_allowed_colors() -> set[str]:
    if not PALETTE_TOKENS_PATH.exists():
        raise FileNotFoundError(
            f"Missing palette file: {PALETTE_TOKENS_PATH.relative_to(ROOT)}"
        )
    payload = json.loads(PALETTE_TOKENS_PATH.read_text(encoding="utf-8"))
    colors = payload.get("approved_hex_colors", [])
    if not isinstance(colors, list):
        raise ValueError("Invalid palette_tokens.json: approved_hex_colors must be a list")
    return {str(token).upper() for token in colors}


def main() -> int:
    allowed_colors = _load_allowed_colors()
    errors: list[str] = []

    for svg_path in sorted(LOGOS_DIR.glob("*.svg")):
        content = svg_path.read_text(encoding="utf-8")
        lower = content.lower()

        if "<text" in lower:
            errors.append(f"{svg_path.name}: contains disallowed <text> node")

        found_tokens = {token.upper() for token in HEX_TOKEN_RE.findall(content)}
        disallowed = sorted(token for token in found_tokens if token not in allowed_colors)
        if disallowed:
            errors.append(
                f"{svg_path.name}: contains non-approved colors {', '.join(disallowed)}"
            )

    if errors:
        print("Asset logo validation failed:")
        for item in errors:
            print(f"- {item}")
        return 1

    print(
        f"Asset logo validation passed for {len(list(LOGOS_DIR.glob('*.svg')))} SVG files"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
