#!/usr/bin/env bash
# Render the owner's song to a PCM WAV and install the greeter-time boot sound.
# User step (Desktop Mode) — needs the copied song + ffmpeg. Coexists with the
# Steam startup movie (Game Mode) from scripts/20-boot-video.sh.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

require_audio
AUDIO="$(find_audio)"
FFMPEG="$(ffmpeg_cmd)" || exit 1

LEN="${LAVA_BOOTSOUND_SECONDS:-8}"     # keep short: aplay holds the hw PCM this long
mkdir -p "$GEN_OUT"
OUT="$GEN_OUT/boot-sound.wav"

# aplay decodes WAV/raw PCM only, so pre-render; plughw handles rate conversion.
log "Rendering ${LEN}s boot sound (48kHz stereo PCM)..."
"$FFMPEG" -y -i "$AUDIO" -t "$LEN" -ac 2 -ar 48000 -c:a pcm_s16le "$OUT"

log "Installing boot sound service (needs sudo)..."
sudo env LAVA_BOOT_WAV="$OUT" bash "$REPO_ROOT/common/provision/05-boot-sound.sh"
log "Done. Optional tuning in /etc/lava-chicken/boot-sound.conf:"
log "  LAVA_BOOTSOUND_CARD=plughw:1,0   # pin the output (avoid HDMI TV)"
log "  LAVA_BOOTSOUND_GAMEMODE=0        # let the Steam movie carry Game Mode"
