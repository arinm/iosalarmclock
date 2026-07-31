#!/usr/bin/env python3
"""Punctual icon set - EXACTLY the geometry approved on the board.

Do not "improve" this. Two things are deliberately not what a fresh pass would
produce, and both were chosen on the board:
  * the OUTER sound arc is SHORTER than the inner one, not longer;
  * the mark is inset to 74% of the tile, matching how it was previewed.
"""
import subprocess, pathlib, math

# --- dial ---------------------------------------------------------------
CX, CY, R, SW = 512, 556, 244, 54
GAP_PCT = 7          # the missing hour
GAP_ROT = -19        # puts the cut at ~2 o'clock, where the hour hand points

# Dash lengths must be in USER UNITS: cairosvg ignores pathLength, which
# silently turned the single cut into ~16 gaps too small to see.
C     = 2 * math.pi * R
GAP   = C * GAP_PCT / 100
DRAWN = C - GAP

INSET = 0.74         # the mark occupied 74% of the tile on the board

def mark(color):
    return f'''
  <g transform="translate(512 512) scale({INSET}) translate(-512 -512)">
    <g fill="none" stroke="{color}" stroke-linecap="round">
      <!-- bells -->
      <g stroke-width="{SW}">
        <path d="M340 384 A 100 100 0 0 1 266 286"/>
        <path d="M684 384 A 100 100 0 0 0 758 286"/>
      </g>
      <!-- sound -->
      <g stroke-width="36">
        <path d="M203 458 A 320 320 0 0 0 203 654"/>
        <path d="M821 458 A 320 320 0 0 1 821 654"/>
      </g>
      <g stroke-width="30" opacity=".72">
        <path d="M132 500 A 386 386 0 0 0 132 612"/>
        <path d="M892 500 A 386 386 0 0 1 892 612"/>
      </g>
      <!-- dial, one hour missing -->
      <circle cx="{CX}" cy="{CY}" r="{R}" stroke-width="{SW}"
              stroke-dasharray="{DRAWN:.1f} {GAP:.1f}"
              transform="rotate({GAP_ROT} {CX} {CY})"/>
      <!-- hands -->
      <g stroke-width="44">
        <path d="M{CX} {CY} L{CX} {CY-164}"/>
        <path d="M{CX} {CY} L{CX+102} {CY-62}"/>
      </g>
    </g>
    <circle cx="{CX}" cy="{CY}" r="34" fill="{color}"/>
  </g>'''

def tile(c, top, bottom):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs><linearGradient id="g" x1="0" y1="0" x2="0.42" y2="1">
    <stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/>
  </linearGradient></defs>
  <rect width="1024" height="1024" fill="url(#g)"/>{mark(c)}
</svg>'''

def transparent(c):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
{mark(c)}
</svg>'''

def png(svg, out, size):
    pathlib.Path(out).parent.mkdir(parents=True, exist_ok=True)
    tmp = pathlib.Path("/tmp/_icon.svg"); tmp.write_text(svg)
    subprocess.run(["cairosvg", str(tmp), "-o", out, "-W", str(size), "-H", str(size)], check=True)

# colourways: (asset name, mark, tile top, tile bottom) - board tile was #2A1B22 -> #101019
WAYS = [
    ("AppIcon",          "#FFA98A", "#2A1B22", "#101019"),
    ("AppIcon-Ocean",    "#66AEFF", "#16243A", "#0A0E18"),
    ("AppIcon-Forest",   "#66C795", "#152A20", "#0A1410"),
    ("AppIcon-Grape",    "#B38CFA", "#241A38", "#100C1A"),
    ("AppIcon-Sunset",   "#FF8590", "#331820", "#170A10"),
    ("AppIcon-Graphite", "#A8B3C1", "#1E222A", "#0C0E13"),
]
ROOT = "/Users/test/Project/alarm"
SCRATCH = "/private/tmp/claude-501/-Users-test-Project-alarm/68885d27-01d7-40d4-9d9d-cfc7a7269270/scratchpad"

for name, c, top, bot in WAYS:
    png(tile(c, top, bot), f"{ROOT}/App/Assets.xcassets/{name}.appiconset/{name}.png", 1024)
png(tile("#FFB396", "#17111A", "#08080D"), f"{ROOT}/App/Assets.xcassets/AppIcon.appiconset/AppIcon-Dark.png", 1024)
png(transparent("#FFFFFF"), f"{ROOT}/App/Assets.xcassets/AppIcon.appiconset/AppIcon-Tinted.png", 1024)
png(transparent("#FFFFFF"), f"{ROOT}/App/Assets.xcassets/PunctualMark.imageset/PunctualMark.png", 512)
for s in (64, 180):
    png(tile("#FFA98A", "#2A1B22", "#101019"), f"{ROOT}/docs/assets/icon-{s}.png", s)
for s in (180, 120, 87, 60, 40, 29):
    png(tile("#FFA98A", "#2A1B22", "#101019"), f"{SCRATCH}/proof-{s}.png", s)
print("done")
