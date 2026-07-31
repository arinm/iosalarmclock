#!/bin/bash
# Convert App Store screenshots to the 6.5" slot (1284 x 2778).
#
# Our design exports are 1290 x 2796 (the 6.9" slot). The two aspect ratios are
# near-identical, so this resamples to 1284 wide and trims ~5px of height -
# it never stretches. Works on 2x exports (2580 x 5592) too.
#
#   ./to-65-inch.sh ~/Downloads/Slice*.png
#
# Converted copies land in ./6.5-inch/ next to this script; originals untouched.
set -euo pipefail

W=1284
H=2778
OUT="$(cd "$(dirname "$0")" && pwd)/6.5-inch"
mkdir -p "$OUT"

[ $# -gt 0 ] || { echo "usage: $(basename "$0") <image.png> [...]"; exit 1; }

for src in "$@"; do
  [ -f "$src" ] || { echo "skip (not a file): $src"; continue; }
  dst="$OUT/$(basename "$src")"
  cp "$src" "$dst"

  before=$(sips -g pixelWidth -g pixelHeight "$dst" | tail -2 | awk '{printf "%s", $2}' | paste -sd'x' -)
  sips --resampleWidth "$W" "$dst" >/dev/null
  h=$(sips -g pixelHeight "$dst" | tail -1 | awk '{print $2}')

  if [ "$h" -lt "$H" ]; then
    echo "!! $(basename "$src"): resampled height ${h}px is under ${H}px."
    echo "   Its aspect ratio is too wide to crop - re-export taller, or it will letterbox."
    rm "$dst"; continue
  fi

  sips --cropToHeightWidth "$H" "$W" "$dst" >/dev/null
  echo "$(basename "$src"): $before -> ${W}x${H}  (trimmed $((h - H))px)"
done

echo
echo "Ready in: $OUT"
