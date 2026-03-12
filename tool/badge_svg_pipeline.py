#!/usr/bin/env python3
"""Generate local square SVG badges for currency flags and category boxes."""

from __future__ import annotations

import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BADGE_DIR = ROOT / "assets" / "badge_svgs"
FLAGS_DIR = BADGE_DIR / "flags"
CATEGORIES_DIR = BADGE_DIR / "categories"
PALETTE_PATH = BADGE_DIR / "palette_tokens.json"

CURRENCY_TO_COUNTRY = {
    "USD": "US",
    "EUR": "EU",
    "GBP": "GB",
    "JPY": "JP",
    "AUD": "AU",
    "CAD": "CA",
    "CHF": "CH",
    "NZD": "NZ",
    "CNY": "CN",
    "SGD": "SG",
    "HKD": "HK",
    "KRW": "KR",
    "TWD": "TW",
    "THB": "TH",
    "MYR": "MY",
    "IDR": "ID",
    "PHP": "PH",
    "VND": "VN",
    "BDT": "BD",
    "LKR": "LK",
    "PKR": "PK",
    "NPR": "NP",
    "AED": "AE",
    "SAR": "SA",
    "QAR": "QA",
    "KWD": "KW",
    "BHD": "BH",
    "OMR": "OM",
    "ILS": "IL",
    "SEK": "SE",
    "NOK": "NO",
    "DKK": "DK",
    "PLN": "PL",
    "TRY": "TR",
    "BRL": "BR",
    "MXN": "MX",
    "ZAR": "ZA",
}

REQUIRED_COUNTRY_CODES = sorted({"IN", "US", "JP", "EU", *CURRENCY_TO_COUNTRY.values()})

CATEGORY_STYLE_TO_KEY = {
    "global": "global",
    "asia": "asia",
    "middle_east": "middle_east",
    "americas": "americas",
    "africa": "africa",
    "currencies_other": "currencies_other",
    "metals": "metals",
    "energy": "energy",
    "fallback": "fallback",
}

CATEGORY_STYLE_SPEC = {
    "global": ("#244A6D", "#9FC5FF", "globe"),
    "asia": ("#7B3E6B", "#D8A8F0", "compass"),
    "middle_east": ("#2B5D64", "#9EE0E9", "crescent"),
    "americas": ("#2C5C45", "#9FE1BF", "mountain"),
    "africa": ("#7A5520", "#F3C88E", "sun"),
    "currencies_other": ("#355D7E", "#B8D3EF", "currency"),
    "metals": ("#6A5A2F", "#E9CF8A", "gem"),
    "energy": ("#3B2A21", "#F3A64C", "flame"),
    "fallback": ("#4A4F57", "#B3BAC5", "spark"),
}


def rect(x: float, y: float, w: float, h: float, fill: str) -> str:
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}"/>'


def circle(cx: float, cy: float, r: float, fill: str) -> str:
    return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}"/>'


def polygon(points: list[tuple[float, float]], fill: str) -> str:
    pts = " ".join(f"{x},{y}" for x, y in points)
    return f'<polygon points="{pts}" fill="{fill}"/>'


def path(d: str, fill: str | None = None, stroke: str | None = None, stroke_width: float | None = None,
         stroke_linecap: str | None = None, stroke_linejoin: str | None = None, opacity: float | None = None) -> str:
    attrs = [f'd="{d}"']
    attrs.append(f'fill="{fill}"' if fill is not None else 'fill="none"')
    if stroke is not None:
        attrs.append(f'stroke="{stroke}"')
    if stroke_width is not None:
        attrs.append(f'stroke-width="{stroke_width}"')
    if stroke_linecap is not None:
        attrs.append(f'stroke-linecap="{stroke_linecap}"')
    if stroke_linejoin is not None:
        attrs.append(f'stroke-linejoin="{stroke_linejoin}"')
    if opacity is not None:
        attrs.append(f'opacity="{opacity}"')
    return f'<path {" ".join(attrs)}/>'


def star(cx: float, cy: float, outer_r: float, inner_r: float, fill: str, points: int = 5) -> str:
    pts: list[tuple[float, float]] = []
    for i in range(points * 2):
        angle = -math.pi / 2 + i * math.pi / points
        radius = outer_r if i % 2 == 0 else inner_r
        pts.append((cx + math.cos(angle) * radius, cy + math.sin(angle) * radius))
    return polygon(pts, fill)


def wrap_svg(code: str, elements: list[str]) -> str:
    body = "\n  ".join(elements)
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" role="img" aria-label="{code} square badge">\n'
        f'  {body}\n'
        '  <rect x="0.5" y="0.5" width="63" height="63" rx="12" fill="none" stroke="#FFFFFF" stroke-opacity="0.12"/>\n'
        '</svg>\n'
    )


def h_stripes(colors: list[str]) -> list[str]:
    seg = 64 / len(colors)
    return [rect(0, i * seg, 64, seg + 0.4, c) for i, c in enumerate(colors)]


def v_stripes(colors: list[str]) -> list[str]:
    seg = 64 / len(colors)
    return [rect(i * seg, 0, seg + 0.4, 64, c) for i, c in enumerate(colors)]


def cross_flag(bg: str, cross: str, inner: str | None = None) -> list[str]:
    out = [rect(0, 0, 64, 64, bg)]
    if inner is not None:
        out.extend([rect(0, 26, 64, 12, inner), rect(24, 0, 12, 64, inner)])
        out.extend([rect(0, 29, 64, 6, cross), rect(27, 0, 6, 64, cross)])
    else:
        out.extend([rect(0, 28, 64, 8, cross), rect(26, 0, 8, 64, cross)])
    return out


def crescent(cx: float, cy: float, r_outer: float, r_inner: float, color: str, cut_color: str) -> list[str]:
    return [circle(cx, cy, r_outer, color), circle(cx + (r_outer - r_inner) * 0.9, cy, r_inner, cut_color)]


def flag_for_country(code: str) -> list[str]:
    c = code.upper()

    if c == "IN":
        return h_stripes(["#FF9933", "#FFFFFF", "#138808"]) + [
            circle(32, 32, 6.8, "none"),
            path("M32 25.2V38.8M25.2 32H38.8", stroke="#1A4C9A", stroke_width=1.6, stroke_linecap="round"),
            path("M32 25.2A6.8 6.8 0 1 1 31.99 25.2", stroke="#1A4C9A", stroke_width=1.4),
        ]

    if c == "US":
        bands = ["#B22234" if i % 2 == 0 else "#FFFFFF" for i in range(13)]
        elems = []
        band_h = 64 / 13
        for i, color in enumerate(bands):
            elems.append(rect(0, i * band_h, 64, band_h + 0.2, color))
        elems.append(rect(0, 0, 30, band_h * 7, "#3C3B6E"))
        for row in range(5):
            for col in range(4):
                elems.append(circle(4 + col * 6.4 + (row % 2) * 1.5, 4 + row * 5.4, 0.9, "#FFFFFF"))
        return elems

    if c == "JP":
        return [rect(0, 0, 64, 64, "#FFFFFF"), circle(32, 32, 14, "#BC002D")]

    if c == "EU":
        elems = [rect(0, 0, 64, 64, "#003399")]
        for i in range(12):
            ang = i * (2 * math.pi / 12) - math.pi / 2
            elems.append(circle(32 + math.cos(ang) * 16, 32 + math.sin(ang) * 16, 1.6, "#FFCC00"))
        return elems

    if c == "GB":
        elems = [rect(0, 0, 64, 64, "#012169")]
        elems += [rect(0, 26, 64, 12, "#FFFFFF"), rect(26, 0, 12, 64, "#FFFFFF")]
        elems += [rect(0, 29, 64, 6, "#C8102E"), rect(29, 0, 6, 64, "#C8102E")]
        return elems

    if c == "AU":
        return [
            rect(0, 0, 64, 64, "#012169"),
            star(45, 40, 6.5, 2.8, "#FFFFFF", points=7),
            star(16, 16, 4.5, 2.2, "#FFFFFF"),
        ]

    if c == "CA":
        return v_stripes(["#D52B1E", "#FFFFFF", "#D52B1E"]) + [
            polygon([(32, 18), (36, 28), (44, 28), (37, 34), (40, 44), (32, 38), (24, 44), (27, 34), (20, 28), (28, 28)], "#D52B1E"),
        ]

    if c == "CH":
        return [
            rect(0, 0, 64, 64, "#D52B1E"),
            rect(27, 16, 10, 32, "#FFFFFF"),
            rect(16, 27, 32, 10, "#FFFFFF"),
        ]

    if c == "NZ":
        return [
            rect(0, 0, 64, 64, "#00247D"),
            star(46, 20, 3.6, 1.6, "#FF0000"),
            star(50, 34, 3.6, 1.6, "#FF0000"),
            star(40, 44, 3.6, 1.6, "#FF0000"),
            star(34, 28, 3.6, 1.6, "#FF0000"),
        ]

    if c == "CN":
        return [
            rect(0, 0, 64, 64, "#DE2910"),
            star(17, 16, 6, 2.6, "#FFDE00"),
            star(28, 11, 2.6, 1.2, "#FFDE00"),
            star(31, 18, 2.6, 1.2, "#FFDE00"),
            star(30, 25, 2.6, 1.2, "#FFDE00"),
            star(24, 29, 2.6, 1.2, "#FFDE00"),
        ]

    if c == "SG":
        return h_stripes(["#EF3340", "#FFFFFF"]) + crescent(18, 16, 7, 5.2, "#FFFFFF", "#EF3340") + [
            star(25, 16, 2.3, 1.0, "#FFFFFF")
        ]

    if c == "HK":
        return [
            rect(0, 0, 64, 64, "#DE2910"),
            circle(32, 32, 11.5, "#FFFFFF"),
            circle(32, 32, 8.5, "#DE2910"),
            star(32, 20, 2.8, 1.1, "#FFFFFF"),
        ]

    if c == "KR":
        return [
            rect(0, 0, 64, 64, "#FFFFFF"),
            path("M32 20A12 12 0 0 1 32 44A12 12 0 0 1 32 20", fill="#CD2E3A"),
            path("M32 44A12 12 0 0 1 32 20A12 12 0 0 1 32 44", fill="#0047A0"),
            rect(10, 14, 8, 2, "#000000"),
            rect(46, 48, 8, 2, "#000000"),
        ]

    if c == "TW":
        return [
            rect(0, 0, 64, 64, "#FE0000"),
            rect(0, 0, 30, 30, "#000095"),
            star(15, 15, 6, 2.6, "#FFFFFF", points=12),
        ]

    if c == "TH":
        return h_stripes(["#A51931", "#FFFFFF", "#2D2A4A", "#FFFFFF", "#A51931"])

    if c == "MY":
        elems = []
        cols = ["#CC0001", "#FFFFFF"] * 7
        band_h = 64 / len(cols)
        for i, color in enumerate(cols):
            elems.append(rect(0, i * band_h, 64, band_h + 0.2, color))
        elems.append(rect(0, 0, 32, 34, "#010066"))
        elems += crescent(14, 17, 8, 6, "#FFCC00", "#010066")
        elems.append(star(22, 17, 5.2, 2.2, "#FFCC00", points=14))
        return elems

    if c == "ID":
        return h_stripes(["#CE1126", "#FFFFFF"])

    if c == "PH":
        return [
            rect(0, 0, 64, 32, "#0038A8"),
            rect(0, 32, 64, 32, "#CE1126"),
            polygon([(0, 0), (28, 32), (0, 64)], "#FFFFFF"),
            circle(9, 32, 4.2, "#FCD116"),
        ]

    if c == "VN":
        return [rect(0, 0, 64, 64, "#DA251D"), star(32, 32, 11, 4.8, "#FFFF00")]

    if c == "BD":
        return [rect(0, 0, 64, 64, "#006A4E"), circle(28, 32, 12.5, "#F42A41")]

    if c == "LK":
        return [
            rect(0, 0, 64, 64, "#FFB915"),
            rect(12, 6, 46, 52, "#8D153A"),
            rect(0, 0, 6, 64, "#006A4E"),
            rect(6, 0, 6, 64, "#FF9933"),
        ]

    if c == "PK":
        return [
            rect(0, 0, 64, 64, "#01411C"),
            rect(0, 0, 12, 64, "#FFFFFF"),
            *crescent(37, 30, 12, 9, "#FFFFFF", "#01411C"),
            star(42, 21, 4, 1.8, "#FFFFFF"),
        ]

    if c == "NP":
        return [
            rect(0, 0, 64, 64, "#003893"),
            polygon([(6, 6), (44, 20), (24, 32), (44, 44), (6, 58)], "#DC143C"),
            circle(23, 24, 3.8, "#FFFFFF"),
            star(23, 42, 4, 1.8, "#FFFFFF"),
        ]

    if c == "AE":
        return [
            rect(0, 0, 18, 64, "#FF0000"),
            rect(18, 0, 46, 21.4, "#00732F"),
            rect(18, 21.4, 46, 21.2, "#FFFFFF"),
            rect(18, 42.6, 46, 21.4, "#000000"),
        ]

    if c == "SA":
        return [
            rect(0, 0, 64, 64, "#006C35"),
            rect(14, 41, 36, 3, "#FFFFFF"),
            circle(46, 42.5, 1.8, "#FFFFFF"),
        ]

    if c == "QA":
        elems = [rect(0, 0, 64, 64, "#8D1B3D"), rect(0, 0, 18, 64, "#FFFFFF")]
        for i in range(8):
            elems.append(polygon([(18, i * 8), (24, i * 8 + 4), (18, i * 8 + 8)], "#8D1B3D"))
        return elems

    if c == "KW":
        return [
            rect(0, 0, 64, 21.4, "#007A3D"),
            rect(0, 21.4, 64, 21.2, "#FFFFFF"),
            rect(0, 42.6, 64, 21.4, "#CE1126"),
            polygon([(0, 0), (14, 8), (14, 56), (0, 64)], "#000000"),
        ]

    if c == "BH":
        elems = [rect(0, 0, 64, 64, "#CE1126"), rect(0, 0, 18, 64, "#FFFFFF")]
        for i in range(6):
            elems.append(polygon([(18, i * 10.67), (24, i * 10.67 + 5.3), (18, i * 10.67 + 10.67)], "#CE1126"))
        return elems

    if c == "OM":
        return [
            rect(0, 0, 16, 64, "#C8102E"),
            rect(16, 0, 48, 21.4, "#FFFFFF"),
            rect(16, 21.4, 48, 21.2, "#C8102E"),
            rect(16, 42.6, 48, 21.4, "#007A3D"),
        ]

    if c == "IL":
        return [
            rect(0, 0, 64, 64, "#FFFFFF"),
            rect(0, 7, 64, 8, "#0038B8"),
            rect(0, 49, 64, 8, "#0038B8"),
            polygon([(32, 18), (25, 31), (39, 31)], "none"),
            polygon([(32, 46), (25, 33), (39, 33)], "none"),
            path("M32 18L25 31H39Z M32 46L25 33H39Z", stroke="#0038B8", stroke_width=2.2),
        ]

    if c == "SE":
        return cross_flag("#006AA7", "#FECC00")

    if c == "NO":
        return cross_flag("#BA0C2F", "#00205B", inner="#FFFFFF")

    if c == "DK":
        return cross_flag("#C60C30", "#FFFFFF")

    if c == "PL":
        return h_stripes(["#FFFFFF", "#DC143C"])

    if c == "TR":
        return [
            rect(0, 0, 64, 64, "#E30A17"),
            *crescent(24, 32, 10, 7.2, "#FFFFFF", "#E30A17"),
            star(34.5, 32, 4.2, 1.8, "#FFFFFF"),
        ]

    if c == "BR":
        return [
            rect(0, 0, 64, 64, "#009C3B"),
            polygon([(32, 11), (52, 32), (32, 53), (12, 32)], "#FFDF00"),
            circle(32, 32, 8.5, "#002776"),
        ]

    if c == "MX":
        return v_stripes(["#006847", "#FFFFFF", "#CE1126"]) + [circle(32, 32, 4, "#B38B59")]

    if c == "ZA":
        return [
            rect(0, 0, 64, 32, "#DE3831"),
            rect(0, 32, 64, 32, "#002395"),
            polygon([(0, 0), (24, 20), (64, 20), (64, 28), (24, 28), (0, 8)], "#FFFFFF"),
            polygon([(0, 64), (24, 44), (64, 44), (64, 36), (24, 36), (0, 56)], "#FFFFFF"),
            polygon([(0, 6), (24, 24), (64, 24), (64, 40), (24, 40), (0, 58), (0, 48), (16, 32), (0, 16)], "#007A4D"),
            polygon([(0, 0), (16, 16), (16, 48), (0, 64)], "#000000"),
            polygon([(0, 6), (12, 18), (12, 46), (0, 58)], "#FFB81C"),
        ]

    # Deterministic fallback (should rarely be used)
    seed = sum(ord(ch) for ch in c)
    palette = ["#2A4D72", "#244A6D", "#7A5520", "#2B5D64", "#6A5A2F", "#4A4F57"]
    p1 = palette[seed % len(palette)]
    p2 = palette[(seed // 3) % len(palette)]
    p3 = palette[(seed // 7) % len(palette)]
    return h_stripes([p1, p2, p3])


def category_icon(category: str, fg: str, accent: str, background: str) -> list[str]:
    if category == "global":
        return [
            circle(32, 32, 15, "none"),
            path("M32 17V47M17 32H47", stroke=fg, stroke_width=2.4),
            path("M23 32C23 22 27 17 32 17C37 17 41 22 41 32C41 42 37 47 32 47C27 47 23 42 23 32Z", stroke=accent, stroke_width=2),
        ]
    if category == "asia":
        return [
            circle(32, 32, 14, "none"),
            path("M32 18L36 28L46 32L36 36L32 46L28 36L18 32L28 28Z", fill=accent),
            path("M32 18L36 28L46 32L36 36L32 46L28 36L18 32L28 28Z", stroke=fg, stroke_width=2),
        ]
    if category == "middle_east":
        return crescent(30, 32, 12, 9, fg, background) + [star(39, 32, 4, 1.7, accent)]
    if category == "americas":
        return [
            path("M14 42L24 28L32 38L40 24L50 42Z", fill=accent),
            path("M14 42L24 28L32 38L40 24L50 42Z", stroke=fg, stroke_width=2.2, stroke_linejoin="round"),
        ]
    if category == "africa":
        return [
            circle(32, 32, 9.5, accent),
            path("M32 14V20M32 44V50M14 32H20M44 32H50M20 20L24 24M44 44L40 40M20 44L24 40M44 20L40 24",
                 stroke=fg, stroke_width=2.4, stroke_linecap="round"),
        ]
    if category == "currencies_other":
        return [
            circle(32, 32, 14, "none"),
            path("M27 24C27 21 29 19 32 19C35 19 37 21 37 24C37 28 32 29 32 32C32 35 37 36 37 40C37 43 35 45 32 45C29 45 27 43 27 40",
                 stroke=fg, stroke_width=2.6, stroke_linecap="round"),
            path("M32 16V48", stroke=accent, stroke_width=1.8, stroke_linecap="round", opacity=0.9),
        ]
    if category == "metals":
        return [
            polygon([(20, 28), (27, 20), (37, 20), (44, 28), (32, 46)], accent),
            path("M20 28L27 20H37L44 28L32 46Z", stroke=fg, stroke_width=2.4, stroke_linejoin="round"),
            path("M27 20L32 28L37 20", stroke=fg, stroke_width=1.8, stroke_linejoin="round"),
        ]
    if category == "energy":
        return [
            path("M34 16C34 22 28 25 28 31C28 36 31.5 40 36 40C41 40 44 36 44 31C44 26 40 23 40 18", fill=accent),
            path("M24 33C24 26 29 22 33 17C36 24 41 26 41 33C41 40 36 46 30 46C26 46 24 41 24 33Z", stroke=fg, stroke_width=2.4, stroke_linejoin="round"),
        ]
    return [
        circle(32, 32, 13, "none"),
        star(32, 32, 7, 3, accent),
        path("M32 19V45M19 32H45", stroke=fg, stroke_width=2.2, opacity=0.8),
    ]


def category_svg(category: str, background: str, accent: str) -> str:
    fg = "#FFFFFF"
    elems = [
        rect(0, 0, 64, 64, background),
        circle(48, 16, 8, accent),
        *category_icon(category, fg, accent, background),
    ]
    return wrap_svg(category, elems)


def render_flags() -> set[str]:
    colors: set[str] = {"#FFFFFF"}
    for code in REQUIRED_COUNTRY_CODES:
        elements = flag_for_country(code)
        svg = wrap_svg(code, elements)
        (FLAGS_DIR / f"{code.lower()}.svg").write_text(svg, encoding="utf-8")
        for token in svg.replace("\n", " ").split("#"):
            if len(token) >= 6:
                maybe = "#" + token[:6]
                if len(maybe) == 7 and all(ch in "0123456789ABCDEFabcdef#" for ch in maybe):
                    colors.add(maybe.upper())
    return colors


def render_categories() -> set[str]:
    colors: set[str] = {"#FFFFFF"}
    for key in CATEGORY_STYLE_TO_KEY.values():
        bg, accent, _ = CATEGORY_STYLE_SPEC[key]
        svg = category_svg(key, bg, accent)
        (CATEGORIES_DIR / f"{key}.svg").write_text(svg, encoding="utf-8")
        for token in svg.replace("\n", " ").split("#"):
            if len(token) >= 6:
                maybe = "#" + token[:6]
                if len(maybe) == 7 and all(ch in "0123456789ABCDEFabcdef#" for ch in maybe):
                    colors.add(maybe.upper())
    return colors


def write_palette(colors: set[str]) -> None:
    payload = {
        "approved_hex_colors": sorted(colors),
        "required_country_codes": REQUIRED_COUNTRY_CODES,
        "required_category_keys": sorted(CATEGORY_STYLE_TO_KEY.values()),
        "notes": "Generated by tool/badge_svg_pipeline.py",
    }
    PALETTE_PATH.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    FLAGS_DIR.mkdir(parents=True, exist_ok=True)
    CATEGORIES_DIR.mkdir(parents=True, exist_ok=True)

    palette = set()
    palette.update(render_flags())
    palette.update(render_categories())
    write_palette(palette)

    print(f"Generated {len(REQUIRED_COUNTRY_CODES)} square flag SVGs")
    print(f"Generated {len(CATEGORY_STYLE_TO_KEY)} category square SVGs")
    print(f"Updated {PALETTE_PATH.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
