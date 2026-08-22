#!/usr/bin/env python3
"""
Draw the App Store icon from the sword sprite itself.

WHY IT IS GENERATED AND NOT DRAWN
---------------------------------
The icon and the in-app sword were separate artefacts, and they drifted: the sword gained emeralds
in the crossguard, a white catchlight on the ruby, a jewel-tone green and one-light-source shading,
and the icon kept none of it. Anyone looking at the App Store listing and then the app was looking
at two different products.

So this reads `Shared/Pixels.swift` — the grid AND the palette — and renders from that. There is
now one definition of what the sword looks like, and the icon cannot fall behind it again.

    python3 tools/make_icon.py            # writes the appiconset
    python3 tools/make_icon.py --preview  # also writes /tmp/appicon-preview.png at 256px
"""

import argparse
import re
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    sys.exit("needs Pillow: python3 -m pip install --user Pillow")

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Shared" / "Pixels.swift"
OUT = ROOT / "SaleArmor" / "Assets.xcassets" / "AppIcon.appiconset" / "appicon.png"

SIZE = 1024
# 18 rows at 52px is 936 of 1024 — the sword nearly fills the tile. Apple masks the corners with a
# squircle, and the sprite is widest at the crossguard (its vertical middle), so a tall sprite loses
# nothing to the mask. Small is the failure mode for an icon; this one is deliberately close to the
# edge, top and bottom.
SCALE = 52


def palette():
    """Every `Px` colour, read out of the Swift rather than retyped here."""
    text = SOURCE.read_text()
    found = dict(re.findall(r"static let (\w+)\s*=\s*Color\(hex:\s*0x([0-9A-Fa-f]{6})\)", text))
    if "goldMetal" not in found:
        sys.exit("could not read the palette out of Pixels.swift — has it been restructured?")
    return {k: tuple(int(v[i:i + 2], 16) for i in (0, 2, 4)) for k, v in found.items()}


def art():
    """The sprite grid, taken from the `art` array."""
    text = SOURCE.read_text()
    block = re.search(r"private static let art: \[\[Character\]\] = \[(.*?)\n    \]", text, re.S)
    if not block:
        sys.exit("could not find the sword grid in Pixels.swift")
    rows = re.findall(r'"([^"]+)"', block.group(1))
    if not rows or len({len(r) for r in rows}) != 1:
        sys.exit(f"the grid is not rectangular: {[len(r) for r in rows]}")
    return rows


def colour_for(ch, px):
    """
    Mirrors `SwordSprite.colour(_:gleaming:lit:)` with gleaming false and lit false.

    Resting rather than lit on purpose: unlit is where the jewels are at their deepest — the
    emerald is the dark jewel tone that reads as a stone set into metal, and the lit variants are
    the highlights beside it. An icon showing the lit frame would be the sword mid-animation.
    """
    return {
        "=": px["silver"],
        "w": px["silverShade"],
        "H": px["goldShine"],
        "+": px["goldShade"],
        "*": px["rubyGlint"],
        "O": px["ruby"],
        "o": px["rubyShade"],
        "E": px["emerald"],
        "e": px["emeraldLit"],
    }.get(ch, px["goldMetal"])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", action="store_true")
    args = parser.parse_args()

    px, rows = palette(), art()
    w, h = len(rows[0]), len(rows)

    # No alpha anywhere. Apple rejects icons with transparency, and a flat opaque tile is also the
    # only way the near-black background stays the same colour on every home screen wallpaper.
    img = Image.new("RGB", (SIZE, SIZE), px["bg"])
    draw = ImageDraw.Draw(img)

    x0 = (SIZE - w * SCALE) // 2
    y0 = (SIZE - h * SCALE) // 2
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == ".":
                continue
            left, top = x0 + x * SCALE, y0 + y * SCALE
            draw.rectangle([left, top, left + SCALE - 1, top + SCALE - 1], fill=colour_for(ch, px))

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT)
    print(f"wrote {OUT}  ({w}x{h} sprite at {SCALE}px = {w * SCALE}x{h * SCALE} of {SIZE})")

    if args.preview:
        # 256 and 60 are where an icon actually lives. If the crossguard jewels turn to mud at 60,
        # they are decoration rather than design and the sprite needs changing, not the renderer.
        for size in (256, 60):
            img.resize((size, size), Image.NEAREST).save(f"/tmp/appicon-{size}.png")
        print("previews: /tmp/appicon-256.png /tmp/appicon-60.png")


if __name__ == "__main__":
    main()
