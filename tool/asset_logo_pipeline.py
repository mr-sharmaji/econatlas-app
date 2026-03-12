#!/usr/bin/env python3
"""Generate deterministic pictogram SVG logos + manifest files for tracked assets."""

from __future__ import annotations

import json
import re
from collections import OrderedDict
from pathlib import Path
from typing import Callable

ROOT = Path(__file__).resolve().parent.parent
LOGOS_DIR = ROOT / "assets" / "asset_logos"
MANIFEST_JSON_PATH = LOGOS_DIR / "manifest.json"
MANIFEST_DART_PATH = ROOT / "lib" / "core" / "asset_logo_manifest.dart"
PALETTE_TOKENS_PATH = LOGOS_DIR / "palette_tokens.json"

FOREGROUND = "#F8FAFC"
ICON_STROKE = 3

METAL_ASSETS = {"gold", "silver", "platinum", "palladium", "copper"}
ENERGY_ASSETS = {"crude_oil", "natural_gas"}
BOND_KEYWORDS = ("bond_yield", "treasury_yield")

CLASS_PALETTES = {
    "index": {"background": "#1E4F8A", "accent": "#6EB6FF"},
    "bond": {"background": "#3E4D73", "accent": "#A5B4FC"},
    "currency": {"background": "#2A4D72", "accent": "#9FC5FF"},
    "commodity_metals": {"background": "#6A5A2F", "accent": "#E8C56B"},
    "commodity_energy": {"background": "#3B2A21", "accent": "#F59E0B"},
    "fallback": {"background": "#4A4F57", "accent": "#A0A8B5"},
}

ASSET_OVERRIDES = {
    "nifty_50": {"background": "#16498A", "accent": "#76B7FF"},
    "sensex": {"background": "#0F667A", "accent": "#7DE0E9"},
    "india_vix": {"background": "#5F3B78", "accent": "#D3A7F7"},
    "gift_nifty": {"background": "#7A4B12", "accent": "#F8B461"},
    "nifty_500": {"background": "#2F4F93", "accent": "#8CB8FF"},
    "nifty_bank": {"background": "#2E516D", "accent": "#9EC6E4"},
    "nifty_it": {"background": "#1C5570", "accent": "#7CC8EE"},
    "nifty_midcap_150": {"background": "#475781", "accent": "#A8B7E7"},
    "nifty_smallcap_250": {"background": "#5D4A81", "accent": "#BFA8F2"},
    "nifty_auto": {"background": "#37556E", "accent": "#91C2E1"},
    "nifty_pharma": {"background": "#2F6A5A", "accent": "#8DE0C0"},
    "nifty_metal": {"background": "#60656D", "accent": "#B7C0CC"},
    "s_p500": {"background": "#254B7B", "accent": "#91BEFF"},
    "nasdaq": {"background": "#284B89", "accent": "#8FBCFF"},
    "nasdaq_100": {"background": "#2A3F82", "accent": "#9CC5FF"},
    "dow_jones": {"background": "#2E5A74", "accent": "#8FCEE7"},
    "cboe_vix": {"background": "#6A4B74", "accent": "#D6A3E7"},
    "s_p_500_tech": {"background": "#2D5480", "accent": "#88C5F7"},
    "s_p_500_financials": {"background": "#445E7B", "accent": "#A6C0DD"},
    "s_p_500_energy": {"background": "#7A4F2A", "accent": "#F1AE69"},
    "ftse_100": {"background": "#335B78", "accent": "#91C0E2"},
    "dax": {"background": "#385472", "accent": "#9CB9D9"},
    "cac_40": {"background": "#2E5A7F", "accent": "#9ECDF6"},
    "euro_stoxx_50": {"background": "#335F8A", "accent": "#9DCBFF"},
    "nikkei_225": {"background": "#6E4455", "accent": "#F0B5C5"},
    "topix": {"background": "#67496E", "accent": "#D9ADE7"},
    "india_10y_bond_yield": {"background": "#3F546F", "accent": "#A8C4E3"},
    "us_10y_treasury_yield": {"background": "#445872", "accent": "#B6CAE3"},
    "us_2y_treasury_yield": {"background": "#4A5970", "accent": "#C0D0E5"},
    "germany_10y_bond_yield": {"background": "#42566A", "accent": "#B6C7DA"},
    "japan_10y_bond_yield": {"background": "#4F4F70", "accent": "#C8C8EB"},
    "gold": {"background": "#8A6A22", "accent": "#FFD166"},
    "silver": {"background": "#6B7682", "accent": "#DCE3EA"},
    "platinum": {"background": "#5B6676", "accent": "#D4DCE6"},
    "palladium": {"background": "#5D717C", "accent": "#D7E5EE"},
    "copper": {"background": "#8A4D2A", "accent": "#E88B5B"},
    "crude_oil": {"background": "#3A281F", "accent": "#C7771E"},
    "natural_gas": {"background": "#1F4F63", "accent": "#7ED7FF"},
}

ASSET_ICON_OVERRIDES = {
    "nifty_50": "line_up",
    "sensex": "candles",
    "india_vix": "pulse",
    "gift_nifty": "bolt",
    "nifty_500": "pie",
    "nifty_bank": "bank",
    "nifty_it": "chip",
    "nifty_midcap_150": "bars",
    "nifty_smallcap_250": "line_up",
    "nifty_auto": "car",
    "nifty_pharma": "capsule",
    "nifty_metal": "factory",
    "s_p500": "shield",
    "nasdaq": "wave",
    "nasdaq_100": "line_up",
    "dow_jones": "bars",
    "cboe_vix": "pulse",
    "s_p_500_tech": "chip",
    "s_p_500_financials": "bank",
    "s_p_500_energy": "flame",
    "ftse_100": "line_up",
    "dax": "line_up",
    "cac_40": "line_up",
    "euro_stoxx_50": "star",
    "nikkei_225": "sun",
    "topix": "compass",
    "india_10y_bond_yield": "yield_curve",
    "us_10y_treasury_yield": "yield_curve",
    "us_2y_treasury_yield": "yield_curve",
    "germany_10y_bond_yield": "yield_curve",
    "japan_10y_bond_yield": "yield_curve",
    "gold": "coin_stack",
    "silver": "coin_stack",
    "platinum": "gem",
    "palladium": "gem",
    "copper": "anvil",
    "crude_oil": "drop",
    "natural_gas": "flame",
}

CLASS_ICON_DEFAULTS = {
    "index": "line_up",
    "bond": "percent",
    "currency": "globe",
    "commodity_metals": "gem",
    "commodity_energy": "drop",
    "fallback": "spark",
}


def _normalize_asset_key(asset: str) -> str:
    safe = re.sub(r"[^a-z0-9]+", "_", asset.strip().lower())
    safe = re.sub(r"_+", "_", safe)
    return safe.strip("_")


def _bucket_for_asset(asset_key: str) -> str:
    if "_inr" in asset_key:
        return "currency"
    if any(token in asset_key for token in BOND_KEYWORDS):
        return "bond"
    if asset_key in ENERGY_ASSETS:
        return "commodity_energy"
    if asset_key in METAL_ASSETS:
        return "commodity_metals"
    return "index"


def _pick_colors(asset_key: str, bucket: str) -> dict[str, str]:
    return ASSET_OVERRIDES.get(asset_key, CLASS_PALETTES.get(bucket, CLASS_PALETTES["fallback"]))


def _pick_icon(asset_key: str, bucket: str) -> str:
    return ASSET_ICON_OVERRIDES.get(asset_key, CLASS_ICON_DEFAULTS.get(bucket, "spark"))


def _icon_line_up(fg: str, accent: str) -> list[str]:
    return [
        f'<path d="M14 48H50" stroke="{fg}" stroke-width="{ICON_STROKE}" stroke-linecap="round"/>',
        f'<path d="M16 40L27 32L35 36L47 23" stroke="{fg}" stroke-width="{ICON_STROKE}" stroke-linecap="round" stroke-linejoin="round" fill="none"/>',
        f'<path d="M42 23H47V28" stroke="{fg}" stroke-width="{ICON_STROKE}" stroke-linecap="round" stroke-linejoin="round" fill="none"/>',
        f'<circle cx="47" cy="23" r="2.6" fill="{accent}"/>',
    ]


def _icon_candles(fg: str, accent: str) -> list[str]:
    return [
        f'<line x1="20" y1="18" x2="20" y2="46" stroke="{fg}" stroke-width="2.6" stroke-linecap="round"/>',
        f'<line x1="32" y1="16" x2="32" y2="44" stroke="{fg}" stroke-width="2.6" stroke-linecap="round"/>',
        f'<line x1="44" y1="22" x2="44" y2="48" stroke="{fg}" stroke-width="2.6" stroke-linecap="round"/>',
        f'<rect x="16" y="25" width="8" height="12" rx="2" fill="{accent}"/>',
        f'<rect x="28" y="20" width="8" height="11" rx="2" fill="{accent}"/>',
        f'<rect x="40" y="30" width="8" height="10" rx="2" fill="{accent}"/>',
    ]


def _icon_bars(fg: str, accent: str) -> list[str]:
    return [
        f'<rect x="16" y="31" width="8" height="17" rx="2" fill="{fg}"/>',
        f'<rect x="28" y="24" width="8" height="24" rx="2" fill="{accent}"/>',
        f'<rect x="40" y="17" width="8" height="31" rx="2" fill="{fg}"/>',
    ]


def _icon_pie(fg: str, accent: str) -> list[str]:
    return [
        f'<circle cx="32" cy="32" r="15" fill="none" stroke="{fg}" stroke-width="3"/>',
        f'<path d="M32 32L32 17A15 15 0 0 1 45 25Z" fill="{accent}"/>',
        f'<path d="M32 32L45 25A15 15 0 0 1 38 46Z" fill="{fg}" opacity="0.42"/>',
    ]


def _icon_bank(fg: str, accent: str) -> list[str]:
    return [
        f'<path d="M14 26L32 16L50 26Z" fill="{accent}"/>',
        f'<rect x="16" y="28" width="4" height="15" rx="1" fill="{fg}"/>',
        f'<rect x="24" y="28" width="4" height="15" rx="1" fill="{fg}"/>',
        f'<rect x="32" y="28" width="4" height="15" rx="1" fill="{fg}"/>',
        f'<rect x="40" y="28" width="4" height="15" rx="1" fill="{fg}"/>',
        f'<rect x="14" y="45" width="36" height="4" rx="2" fill="{fg}"/>',
    ]


def _icon_chip(fg: str, accent: str) -> list[str]:
    return [
        f'<rect x="20" y="20" width="24" height="24" rx="5" fill="none" stroke="{fg}" stroke-width="3"/>',
        f'<rect x="26" y="26" width="12" height="12" rx="2" fill="{accent}"/>',
        f'<line x1="18" y1="26" x2="12" y2="26" stroke="{fg}" stroke-width="2" stroke-linecap="round"/>',
        f'<line x1="18" y1="32" x2="12" y2="32" stroke="{fg}" stroke-width="2" stroke-linecap="round"/>',
        f'<line x1="18" y1="38" x2="12" y2="38" stroke="{fg}" stroke-width="2" stroke-linecap="round"/>',
        f'<line x1="46" y1="26" x2="52" y2="26" stroke="{fg}" stroke-width="2" stroke-linecap="round"/>',
        f'<line x1="46" y1="32" x2="52" y2="32" stroke="{fg}" stroke-width="2" stroke-linecap="round"/>',
        f'<line x1="46" y1="38" x2="52" y2="38" stroke="{fg}" stroke-width="2" stroke-linecap="round"/>',
    ]


def _icon_car(fg: str, accent: str) -> list[str]:
    return [
        f'<path d="M16 39L20 29C21 26 23 25 26 25H39C42 25 44 26 45 29L48 39" fill="none" stroke="{fg}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>',
        f'<rect x="15" y="34" width="34" height="9" rx="4" fill="{accent}"/>',
        f'<circle cx="22" cy="43" r="4" fill="{fg}"/>',
        f'<circle cx="42" cy="43" r="4" fill="{fg}"/>',
    ]


def _icon_capsule(fg: str, accent: str) -> list[str]:
    return [
        f'<rect x="16" y="24" width="32" height="16" rx="8" fill="{accent}"/>',
        f'<path d="M32 24V40" stroke="{fg}" stroke-width="3" stroke-linecap="round"/>',
        f'<path d="M18 32H30" stroke="{fg}" stroke-width="2" stroke-linecap="round" opacity="0.7"/>',
        f'<path d="M34 32H46" stroke="{fg}" stroke-width="2" stroke-linecap="round" opacity="0.7"/>',
    ]


def _icon_factory(fg: str, accent: str) -> list[str]:
    return [
        f'<rect x="16" y="30" width="32" height="16" rx="2" fill="{fg}"/>',
        f'<path d="M16 30L24 25L30 30L36 25L42 30" fill="{accent}"/>',
        f'<rect x="42" y="21" width="6" height="11" rx="2" fill="{accent}"/>',
        f'<rect x="20" y="35" width="5" height="7" rx="1" fill="{accent}"/>',
        f'<rect x="28" y="35" width="5" height="7" rx="1" fill="{accent}"/>',
        f'<rect x="36" y="35" width="5" height="7" rx="1" fill="{accent}"/>',
    ]


def _icon_pulse(fg: str, accent: str) -> list[str]:
    return [
        f'<path d="M14 34H22L27 24L33 42L38 30H50" stroke="{fg}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" fill="none"/>',
        f'<circle cx="27" cy="24" r="2.3" fill="{accent}"/>',
        f'<circle cx="33" cy="42" r="2.3" fill="{accent}"/>',
    ]


def _icon_bolt(fg: str, accent: str) -> list[str]:
    return [
        f'<path d="M34 14L20 34H30L26 50L44 28H34L38 14Z" fill="{accent}"/>',
        f'<path d="M34 14L20 34H30L26 50L44 28H34L38 14Z" fill="none" stroke="{fg}" stroke-width="2" stroke-linejoin="round"/>',
    ]


def _icon_shield(fg: str, accent: str) -> list[str]:
    return [
        f'<path d="M32 14L46 20V31C46 40 40 47 32 50C24 47 18 40 18 31V20Z" fill="{accent}"/>',
        f'<path d="M32 14L46 20V31C46 40 40 47 32 50C24 47 18 40 18 31V20Z" fill="none" stroke="{fg}" stroke-width="3" stroke-linejoin="round"/>',
        f'<path d="M32 19V45" stroke="{fg}" stroke-width="2.4" stroke-linecap="round"/>',
    ]


def _icon_star(fg: str, accent: str) -> list[str]:
    return [
        f'<polygon points="32,17 36.3,27 47,28.1 39,35.1 41.4,45.5 32,39.8 22.6,45.5 25,35.1 17,28.1 27.7,27" fill="{accent}"/>',
        f'<circle cx="46" cy="18" r="3" fill="{fg}"/>',
        f'<circle cx="19" cy="45" r="2.2" fill="{fg}"/>',
    ]


def _icon_sun(fg: str, accent: str) -> list[str]:
    return [
        f'<circle cx="32" cy="32" r="10" fill="{accent}"/>',
        f'<circle cx="32" cy="32" r="15" fill="none" stroke="{fg}" stroke-width="2.5"/>',
        f'<line x1="32" y1="13" x2="32" y2="8" stroke="{fg}" stroke-width="2.2" stroke-linecap="round"/>',
        f'<line x1="32" y1="56" x2="32" y2="51" stroke="{fg}" stroke-width="2.2" stroke-linecap="round"/>',
        f'<line x1="13" y1="32" x2="8" y2="32" stroke="{fg}" stroke-width="2.2" stroke-linecap="round"/>',
        f'<line x1="56" y1="32" x2="51" y2="32" stroke="{fg}" stroke-width="2.2" stroke-linecap="round"/>',
    ]


def _icon_compass(fg: str, accent: str) -> list[str]:
    return [
        f'<circle cx="32" cy="32" r="15" fill="none" stroke="{fg}" stroke-width="3"/>',
        f'<path d="M28 36L36 28L34 38L26 36Z" fill="{accent}"/>',
        f'<circle cx="32" cy="32" r="2.5" fill="{fg}"/>',
    ]


def _icon_coin_stack(fg: str, accent: str) -> list[str]:
    return [
        f'<ellipse cx="32" cy="23" rx="12" ry="4" fill="{accent}"/>',
        f'<rect x="20" y="23" width="24" height="13" fill="{accent}"/>',
        f'<ellipse cx="32" cy="36" rx="12" ry="4" fill="{accent}"/>',
        f'<ellipse cx="32" cy="23" rx="12" ry="4" fill="none" stroke="{fg}" stroke-width="2.2"/>',
        f'<ellipse cx="32" cy="36" rx="12" ry="4" fill="none" stroke="{fg}" stroke-width="2.2"/>',
        f'<path d="M22 29H42" stroke="{fg}" stroke-width="2" stroke-linecap="round" opacity="0.7"/>',
    ]


def _icon_gem(fg: str, accent: str) -> list[str]:
    return [
        f'<polygon points="20,27 27,19 37,19 44,27 32,45" fill="{accent}"/>',
        f'<polygon points="20,27 27,19 37,19 44,27 32,45" fill="none" stroke="{fg}" stroke-width="2.5" stroke-linejoin="round"/>',
        f'<path d="M27 19L32 27L37 19" stroke="{fg}" stroke-width="2" fill="none" stroke-linejoin="round"/>',
    ]


def _icon_anvil(fg: str, accent: str) -> list[str]:
    return [
        f'<path d="M18 28H36C39 28 41 26 42 23H48C48 30 43 34 36 34H26L22 40H16L20 34H18Z" fill="{accent}"/>',
        f'<rect x="24" y="40" width="16" height="4" rx="2" fill="{fg}"/>',
        f'<path d="M18 28H36C39 28 41 26 42 23H48" stroke="{fg}" stroke-width="2.4" fill="none" stroke-linecap="round"/>',
    ]


def _icon_drop(fg: str, accent: str) -> list[str]:
    return [
        f'<path d="M32 14C32 14 21 28 21 35C21 41.6 26.4 47 33 47C39.6 47 45 41.6 45 35C45 28 32 14 32 14Z" fill="{accent}"/>',
        f'<path d="M32 14C32 14 21 28 21 35C21 41.6 26.4 47 33 47C39.6 47 45 41.6 45 35C45 28 32 14 32 14Z" fill="none" stroke="{fg}" stroke-width="2.6" stroke-linejoin="round"/>',
        f'<path d="M28 34C28 31 30 28 33 26" stroke="{fg}" stroke-width="2" stroke-linecap="round" opacity="0.8"/>',
    ]


def _icon_flame(fg: str, accent: str) -> list[str]:
    return [
        f'<path d="M35 15C35 22 28 24 28 31C28 35 31 39 35 39C40 39 43 35 43 31C43 25 39 22 39 16C39 16 37 17 35 15Z" fill="{accent}"/>',
        f'<path d="M29 32C29 39 34 45 41 45C47 45 52 40 52 33C52 26 47 22 43 17C41 22 37 24 37 28C37 31 39 34 42 34" fill="none" stroke="{fg}" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>' ,
        f'<path d="M24 33C24 27 29 22 33 17" stroke="{fg}" stroke-width="2.5" stroke-linecap="round"/>' ,
    ]


def _icon_percent(fg: str, accent: str) -> list[str]:
    return [
        f'<line x1="22" y1="42" x2="42" y2="22" stroke="{fg}" stroke-width="3" stroke-linecap="round"/>',
        f'<circle cx="23" cy="24" r="5" fill="none" stroke="{accent}" stroke-width="3"/>',
        f'<circle cx="41" cy="40" r="5" fill="none" stroke="{accent}" stroke-width="3"/>',
    ]


def _icon_yield_curve(fg: str, accent: str) -> list[str]:
    return [
        f'<path d="M14 46H50" stroke="{fg}" stroke-width="2.5" stroke-linecap="round"/>',
        f'<path d="M16 40C23 39 26 29 32 29C38 29 41 36 48 24" stroke="{fg}" stroke-width="3" fill="none" stroke-linecap="round"/>',
        f'<circle cx="48" cy="24" r="3" fill="{accent}"/>',
        f'<circle cx="32" cy="29" r="2.2" fill="{accent}" opacity="0.9"/>',
    ]


def _icon_globe(fg: str, accent: str) -> list[str]:
    return [
        f'<circle cx="32" cy="32" r="14" fill="none" stroke="{fg}" stroke-width="2.8"/>',
        f'<ellipse cx="32" cy="32" rx="6" ry="14" fill="none" stroke="{accent}" stroke-width="2"/>',
        f'<path d="M18 27H46" stroke="{accent}" stroke-width="2"/>',
        f'<path d="M18 37H46" stroke="{accent}" stroke-width="2"/>',
    ]


def _icon_wave(fg: str, accent: str) -> list[str]:
    return [
        f'<path d="M14 35C18 27 22 27 26 35C30 43 34 43 38 35C42 27 46 27 50 35" stroke="{fg}" stroke-width="3" fill="none" stroke-linecap="round"/>',
        f'<circle cx="50" cy="35" r="2.8" fill="{accent}"/>',
    ]


def _icon_spark(fg: str, accent: str) -> list[str]:
    return [
        f'<circle cx="32" cy="32" r="13" fill="none" stroke="{fg}" stroke-width="3"/>',
        f'<path d="M32 22L35 29L42 32L35 35L32 42L29 35L22 32L29 29Z" fill="{accent}"/>',
    ]


ICON_BUILDERS: dict[str, Callable[[str, str], list[str]]] = {
    "line_up": _icon_line_up,
    "candles": _icon_candles,
    "bars": _icon_bars,
    "pie": _icon_pie,
    "bank": _icon_bank,
    "chip": _icon_chip,
    "car": _icon_car,
    "capsule": _icon_capsule,
    "factory": _icon_factory,
    "pulse": _icon_pulse,
    "bolt": _icon_bolt,
    "shield": _icon_shield,
    "star": _icon_star,
    "sun": _icon_sun,
    "compass": _icon_compass,
    "coin_stack": _icon_coin_stack,
    "gem": _icon_gem,
    "anvil": _icon_anvil,
    "drop": _icon_drop,
    "flame": _icon_flame,
    "percent": _icon_percent,
    "yield_curve": _icon_yield_curve,
    "globe": _icon_globe,
    "wave": _icon_wave,
    "spark": _icon_spark,
}


def _render_svg(asset_label: str, background: str, accent: str, icon_name: str) -> str:
    builder = ICON_BUILDERS.get(icon_name, ICON_BUILDERS["spark"])
    icon_lines = builder(FOREGROUND, accent)
    icon_block = "\n  ".join(icon_lines)
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" role="img" aria-label="{asset_label} logo">\n'
        f'  <rect x="2" y="2" width="60" height="60" rx="14" fill="{background}"/>\n'
        f'  <rect x="2" y="2" width="60" height="60" rx="14" fill="none" stroke="#FFFFFF" stroke-opacity="0.14"/>\n'
        f'  <circle cx="48" cy="16" r="8" fill="{accent}" opacity="0.26"/>\n'
        f'  {icon_block}\n'
        "</svg>\n"
    )


def _load_manifest_entries() -> OrderedDict[str, dict[str, str | None]]:
    payload = json.loads(MANIFEST_JSON_PATH.read_text(encoding="utf-8"))
    assets = payload.get("assets", {})
    if not isinstance(assets, dict):
        raise ValueError("Invalid manifest.json: missing assets object")
    ordered = OrderedDict()
    for key, meta in assets.items():
        if not isinstance(meta, dict):
            continue
        asset_key = str(meta.get("asset_key", "")).strip()
        if not asset_key:
            continue
        ordered[key] = {
            "asset_key": asset_key,
            "logo_path": f"assets/asset_logos/{key}.svg",
            "source_type": "custom_pictogram",
            "attribution": meta.get("attribution"),
        }
    return ordered


def _write_manifest_json(entries: OrderedDict[str, dict[str, str | None]]) -> None:
    payload = {"assets": entries}
    MANIFEST_JSON_PATH.write_text(
        json.dumps(payload, indent=2) + "\n",
        encoding="utf-8",
    )


def _escape_dart(value: str) -> str:
    return value.replace("\\", "\\\\").replace("'", "\\'")


def _write_manifest_dart(entries: OrderedDict[str, dict[str, str | None]]) -> None:
    lines: list[str] = [
        "class AssetLogoMeta {",
        "  final String assetKey;",
        "  final String logoPath;",
        "  final String sourceType;",
        "  final String? attribution;",
        "",
        "  const AssetLogoMeta({",
        "    required this.assetKey,",
        "    required this.logoPath,",
        "    required this.sourceType,",
        "    this.attribution,",
        "  });",
        "}",
        "",
        "const Map<String, AssetLogoMeta> assetLogoManifest = {",
    ]

    for key, meta in entries.items():
        lines.extend(
            [
                f"  '{_escape_dart(key)}': AssetLogoMeta(",
                f"    assetKey: '{_escape_dart(str(meta['asset_key']))}',",
                f"    logoPath: '{_escape_dart(str(meta['logo_path']))}',",
                f"    sourceType: '{_escape_dart(str(meta['source_type']))}',",
            ]
        )
        attribution = meta.get("attribution")
        if attribution:
            lines.append(f"    attribution: '{_escape_dart(str(attribution))}',")
        lines.append("  ),")

    lines.extend(["};", ""])
    MANIFEST_DART_PATH.write_text("\n".join(lines), encoding="utf-8")


def _write_palette_tokens(allowed_colors: set[str]) -> None:
    payload = {
        "approved_hex_colors": sorted(allowed_colors),
        "notes": "Generated by tool/asset_logo_pipeline.py",
    }
    PALETTE_TOKENS_PATH.write_text(
        json.dumps(payload, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    entries = _load_manifest_entries()
    allowed_colors = {FOREGROUND, "#FFFFFF"}

    for key, meta in entries.items():
        asset_key = str(meta["asset_key"])
        normalized = _normalize_asset_key(asset_key)
        bucket = _bucket_for_asset(normalized)
        color_spec = _pick_colors(normalized, bucket)
        icon_name = _pick_icon(normalized, bucket)

        background = color_spec["background"].upper()
        accent = color_spec["accent"].upper()
        allowed_colors.update({background, accent})

        svg_path = LOGOS_DIR / f"{key}.svg"
        svg_path.write_text(
            _render_svg(asset_key, background, accent, icon_name),
            encoding="utf-8",
        )

    _write_manifest_json(entries)
    _write_manifest_dart(entries)
    _write_palette_tokens(allowed_colors)

    print(f"Generated {len(entries)} asset logo SVGs")
    print(f"Updated {MANIFEST_JSON_PATH.relative_to(ROOT)}")
    print(f"Updated {MANIFEST_DART_PATH.relative_to(ROOT)}")
    print(f"Updated {PALETTE_TOKENS_PATH.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
