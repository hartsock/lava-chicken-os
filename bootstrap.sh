#!/usr/bin/env bash
# lava-chicken-os bootstrap: run all steps in order.
# Safe to re-run. Individual steps: scripts/NN-*.sh
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source=scripts/lib.sh
source scripts/lib.sh

OS="$(detect_os)"
log "Detected base OS: $OS"
if [ "$OS" = other ]; then
  warn "This isn't SteamOS or Bazzite. Continuing, but paths may differ."
fi

log "lava-chicken-os v$(cat "$(dirname "$0")/VERSION" 2>/dev/null || echo '?')"

# Note: on Bazzite from the bootc image, system provisioning (05) runs at first
# boot via lava-chicken-firstboot.service; running it here is harmless
# (idempotent). On SteamOS this is the only path — set LAVA_GITHUB_USER first.
# 05-provision covers SSH-from-GitHub, Sunshine, and the resident nugget agent
# (nugget user + sudo + tmux + button + newt); 40-ollama installs the model
# backend the agent uses.
STEPS=(
  scripts/40-ollama.sh          # model backend first (nugget agent needs it)
  scripts/05-provision.sh       # remote access + resident nugget agent
  scripts/10-theme-wallpapers.sh
  scripts/20-boot-video.sh      # Game Mode startup movie
  scripts/22-boot-sound.sh      # greeter-time boot sound (desktop)
  scripts/30-login-sound.sh
  scripts/60-modding-tools.sh
)

for step in "${STEPS[@]}"; do
  log "==> $step"
  if ! bash "$step"; then
    warn "$step failed — fix and re-run it directly, then re-run bootstrap.sh"
    warn "(already-completed steps are idempotent and will fast-skip)"
    exit 1
  fi
done

log "Done. Finishing touches:"
log "  1. Gaming Mode -> Settings -> Customization -> Startup Movie -> 'Lava Chicken'"
log "  2. Remote in from another box:  ssh $USER@\$(hostname -I | awk '{print \$1}')"
log "  3. Talk to the resident agent:  click the 'nugget' desktop icon (all users)"
log "  4. Pair Moonlight: browse https://<box>:47990, then Moonlight -> PIN"
log "  5. Agent off-switch:  sudo nugget-agentctl {pause|disable|resume|status}"
log "  6. Try a mod build: cd ~/mods/fabric-example-mod && ./gradlew build"
