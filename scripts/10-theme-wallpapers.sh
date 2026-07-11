#!/usr/bin/env bash
# Apply Minecraft-style wallpaper to KDE Plasma desktop mode.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

WALLPAPER=""
# 1) user-supplied wallpaper wins
for f in "$USER_ASSETS"/wallpaper*.png "$USER_ASSETS"/wallpaper*.jpg; do
  [ -f "$f" ] && WALLPAPER="$f" && break
done

# 2) otherwise generate original blocky art
if [ -z "$WALLPAPER" ]; then
  log "No user wallpaper found; generating original blocky art..."
  mkdir -p "$GEN_OUT"
  python3 "$REPO_ROOT/assets/generated/make_wallpaper.py" "$GEN_OUT/lava-chicken-wall.png"
  WALLPAPER="$GEN_OUT/lava-chicken-wall.png"
fi

# copy somewhere stable (repo may move)
DEST="$HOME/.local/share/wallpapers/lava-chicken"
mkdir -p "$DEST"
cp -f "$WALLPAPER" "$DEST/"
WALLPAPER="$DEST/$(basename "$WALLPAPER")"

if have plasma-apply-wallpaperimage; then
  plasma-apply-wallpaperimage "$WALLPAPER"
  log "Wallpaper applied: $WALLPAPER"
else
  warn "plasma-apply-wallpaperimage not found (not KDE?). Wallpaper staged at:"
  warn "  $WALLPAPER — set it manually in your desktop settings."
fi
