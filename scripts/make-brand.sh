#!/usr/bin/env bash
# make-brand.sh — turn a mascot PNG (with transparency) into a newt brand art set:
#   <prefix>-ansi-{10,20,40,full,120,160}.txt  +  <prefix>-ascii-40.txt
# matched to newt-tui's splash logo widths (LOGO_*_COLS). newt reads these from
# NEWT_BRAND_LOGO_DIR at runtime (no recompile) — see common/bin/nugget.
#
# This is LaCOS's local, temporary stand-in for the upstream
# newt-branding-tools (Gilamonster-Foundation/newt-agent#1118). Run it at
# AUTHORING time and commit the output under common/newt-brand/; the image just
# ships the text files (no chafa dependency at build or boot).
#
#   scripts/make-brand.sh <mascot.png> [prefix] [outdir]
#
# Needs: chafa (`brew install chafa` / `dnf install chafa`).
set -euo pipefail

PNG="${1:?usage: make-brand.sh <mascot.png> [prefix=nugget] [outdir=common/newt-brand]}"
PREFIX="${2:-nugget}"
OUT="${3:-common/newt-brand}"

command -v chafa >/dev/null || { echo "FAIL: need chafa (brew/dnf install chafa)"; exit 1; }
[ -f "$PNG" ] || { echo "FAIL: no such file: $PNG"; exit 1; }
install -d "$OUT"

# stem -> width, matching newt-tui: ansi-full=80, ansi-120=126, ansi-160=166.
# We frame the art with a blank band underneath so the splash lays the wordmark
# + tagline into it (title-card look); newt falls back to side layout otherwise.
emit() {  # $1 stem  $2 width  $3 color|mono
  local stem="$1" w="$2" mode="$3"
  local f="$OUT/$PREFIX-$stem.txt"
  # force truecolor: chafa drops color when stdout isn't a TTY, but newt needs
  # 24-bit escapes (its blank-row detector greps for `8;2;`).
  local -a args=(--format symbols --colors full --size "${w}x" -t 0.5 --symbols block+space)
  [ "$mode" = mono ] && args=(--format symbols --colors none --size "${w}x" -t 0.5 --symbols ascii)
  { printf '\n'; chafa "${args[@]}" "$PNG"; printf '\n\n\n\n'; } > "$f"
  printf '  %-16s %3d cols  %2d rows\n' "$PREFIX-$stem.txt" "$w" "$(wc -l <"$f")"
}

echo "brand '$PREFIX'  <-  $PNG  ->  $OUT/"
emit ansi-10    10 color
emit ansi-20    20 color
emit ansi-40    40 color
emit ansi-full  80 color
emit ansi-120  126 color
emit ansi-160  166 color
emit ascii-40   40 mono
echo "done — preview in a color terminal:  cat $OUT/$PREFIX-ansi-40.txt"
