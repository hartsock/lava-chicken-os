#!/usr/bin/env bash
# Play the lava chicken audio when the desktop session starts,
# via a systemd *user* unit (survives OS updates on both bases).
set -euo pipefail
source "$(dirname "$0")/lib.sh"

require_audio
AUDIO="$(find_audio)"

# stage the audio somewhere stable
DEST="$HOME/.local/share/lava-chicken"
mkdir -p "$DEST"
cp -f "$AUDIO" "$DEST/login-sound.${AUDIO##*.}"
STAGED="$DEST/login-sound.${AUDIO##*.}"

UNIT_DIR="$HOME/.config/systemd/user"
mkdir -p "$UNIT_DIR"
sed "s|@AUDIO@|$STAGED|" "$REPO_ROOT/systemd/lava-chicken-login-sound.service" \
  > "$UNIT_DIR/lava-chicken-login-sound.service"

systemctl --user daemon-reload
systemctl --user enable lava-chicken-login-sound.service
log "Login sound enabled. Test now with:"
log "  systemctl --user start lava-chicken-login-sound.service"
