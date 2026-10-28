#!/usr/bin/env bash
# Strips TrueType hinting from the bundled Nanum fonts (CoreText ignores it; ~1.2 MB saved).
# Input: the original Nanum Myeongjo / Nanum Gothic TTFs (OFL, https://hangeul.naver.com/font)
# in $1; the unhinted originals in git history before 2026-10-27 work too.
set -euo pipefail
SRC="${1:?usage: subset.sh <dir with NanumMyeongjo/NanumGothic -Regular.ttf>}"
OUT="$(cd "$(dirname "$0")/../.." && pwd)/AmgiApp/Resources/Fonts"
for f in NanumMyeongjo NanumGothic; do
  uvx --quiet --from fonttools==4.* pyftsubset "$SRC/$f-Regular.ttf" --unicodes='*' --glyphs='*' \
    --layout-features='*' --no-hinting --name-IDs='*' --notdef-outline --output-file="$OUT/$f-Regular.ttf"
done
