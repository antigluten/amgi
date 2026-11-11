#!/usr/bin/env bash
# Renders the alternate app icons as flat PNG .appiconsets from the Icon Composer
# sources in scripts/icons (solid fill + mark.svg). Default/Dark/Tinted, same layout
# as Handwritten.appiconset. Needs rsvg-convert, magick, jq.
# The .icon bundles must stay out of the app target: actool renders each one as
# three ~1 MB flat ARGB images (~2.6 MB per icon).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/scripts/icons"
CAT="$ROOT/AmgiApp/Resources/Assets.xcassets"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

for name in ${@:-DeepTeal Midnight Celadon Persimmon}; do
  hex=$(jq -r '.fill.solid' "$SRC/$name.icon/icon.json" | sed 's/srgb://' \
    | awk -F, '{printf "#%02X%02X%02X", $1*255+.5, $2*255+.5, $3*255+.5}')
  out="$CAT/$name.appiconset"; mkdir -p "$out"
  rsvg-convert -w 1024 -h 1024 "$SRC/$name.icon/Assets/mark.svg" -o "$TMP/mark.png"
  light() { magick "$TMP/mark.png" -channel RGB -evaluate set "$1" +channel png:-; }
  render() { # $1 background, $2 mark source on stdin-or-file, $3 out
    magick -size 1024x1024 "xc:$1" "$2" -composite -alpha off -define png:compression-level=9 -strip "$3"; }
  render "$hex" "$TMP/mark.png" "$out/AppIcon-1024.png"
  light 96% > "$TMP/dark.png";   render black "$TMP/dark.png"   "$out/AppIcon-Dark-1024.png"
  light 100% > "$TMP/tint.png";  render black "$TMP/tint.png"   "$out/AppIcon-Tinted-1024.png"
  cp "$CAT/Handwritten.appiconset/Contents.json" "$out/Contents.json"
done
