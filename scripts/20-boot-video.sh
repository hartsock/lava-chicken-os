#!/usr/bin/env bash
# Build a Steam Gaming Mode startup movie (VP9/Opus webm) from the user's
# audio + an image, and install it to Steam's uioverrides directory.
# Select it afterwards in Gaming Mode: Settings > Customization > Startup Movie.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

MOVIES_DIR="$HOME/.steam/root/config/uioverrides/movies"
mkdir -p "$MOVIES_DIR"
OUT="$MOVIES_DIR/lava-chicken.webm"

# 1) a ready-made movie wins — your own (assets/user) or the shipped brand one.
MOVIE=""
for f in "$USER_ASSETS"/boot-movie.webm "$USER_ASSETS"/boot-movie.mp4 \
         /usr/share/lava-chicken/brand/boot-movie.webm "$REPO_ROOT/assets/brand/boot-movie.webm"; do
  [ -f "$f" ] && MOVIE="$f" && break
done
if [ -n "$MOVIE" ]; then
  if [ "${MOVIE##*.}" = webm ]; then
    cp -f "$MOVIE" "$OUT"
  else
    FFMPEG="$(ffmpeg_cmd)" || exit 1
    "$FFMPEG" -y -i "$MOVIE" -c:v libvpx-vp9 -b:v 1M -c:a libopus -b:a 128k "$OUT"
  fi
  log "Startup movie installed: $OUT (from $(basename "$MOVIE"))"
  log "Now: Gaming Mode -> Settings -> Customization -> Startup Movie -> lava-chicken"
  exit 0
fi

# 2) otherwise build one from your audio + a still image.
require_audio
AUDIO="$(find_audio)"
FFMPEG="$(ffmpeg_cmd)" || exit 1
IMG=""
for f in "$USER_ASSETS"/boot-image.png "$USER_ASSETS"/boot-image.jpg; do
  [ -f "$f" ] && IMG="$f" && break
done
if [ -z "$IMG" ]; then
  mkdir -p "$GEN_OUT"
  python3 "$REPO_ROOT/assets/generated/make_wallpaper.py" --boot "$GEN_OUT/boot-image.png"
  IMG="$GEN_OUT/boot-image.png"
fi
DURATION="${LAVA_BOOT_SECONDS:-15}"
log "Encoding ${DURATION}s startup movie (VP9 + Opus, 1080p)..."
"$FFMPEG" -y -loop 1 -i "$IMG" -i "$AUDIO" -t "$DURATION" \
  -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black,format=yuv420p" \
  -c:v libvpx-vp9 -b:v 1M -r 30 -c:a libopus -b:a 128k -shortest "$OUT"
log "Installed: $OUT — select it in Gaming Mode -> Customization -> Startup Movie"
