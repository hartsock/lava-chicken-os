#!/usr/bin/env bash
# Build a Steam Gaming Mode startup movie (VP9/Opus webm) from the user's
# audio + an image, and install it to Steam's uioverrides directory.
# Select it afterwards in Gaming Mode: Settings > Customization > Startup Movie.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

require_audio
AUDIO="$(find_audio)"
FFMPEG="$(ffmpeg_cmd)" || exit 1

# still frame: user image, else generate one
IMG=""
for f in "$USER_ASSETS"/boot-image.png "$USER_ASSETS"/boot-image.jpg; do
  [ -f "$f" ] && IMG="$f" && break
done
if [ -z "$IMG" ]; then
  mkdir -p "$GEN_OUT"
  python3 "$REPO_ROOT/assets/generated/make_wallpaper.py" --boot "$GEN_OUT/boot-image.png"
  IMG="$GEN_OUT/boot-image.png"
fi

MOVIES_DIR="$HOME/.steam/root/config/uioverrides/movies"
mkdir -p "$MOVIES_DIR"
OUT="$MOVIES_DIR/lava-chicken.webm"

DURATION="${LAVA_BOOT_SECONDS:-15}"   # keep boots snappy; override via env

log "Encoding $DURATION s startup movie (VP9 + Opus, 1080p)..."
"$FFMPEG" -y -loop 1 -i "$IMG" -i "$AUDIO" \
  -t "$DURATION" \
  -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black,format=yuv420p" \
  -c:v libvpx-vp9 -b:v 1M -r 30 \
  -c:a libopus -b:a 128k \
  -shortest "$OUT"

log "Installed: $OUT"
log "Now: Gaming Mode -> Settings -> Customization -> Startup Movie -> lava-chicken"
