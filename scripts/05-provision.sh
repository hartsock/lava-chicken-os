#!/usr/bin/env bash
# SteamOS/first-run entrypoint: run the shared system-layer provisioning
# (SSH from GitHub, Sunshine, the nugget agent). On Bazzite the same
# common/provision/firstboot.sh runs from lava-chicken-firstboot.service instead.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

# Which GitHub account seeds SSH keys (human + nugget)?
GH="${LAVA_GITHUB_USER:-}"
if [ -z "$GH" ] && [ -r "$REPO_ROOT/common/github-user" ]; then
  GH="$(tr -d '[:space:]' < "$REPO_ROOT/common/github-user")"
fi
if [ -z "$GH" ]; then
  warn "Set your GitHub username so we can pull your public SSH keys:"
  warn "  LAVA_GITHUB_USER=yourhandle ./bootstrap.sh"
  warn "  (or:  echo yourhandle > common/github-user )"
  exit 1
fi

log "Provisioning remote access + resident nugget agent (needs sudo)..."
sudo env LAVA_GITHUB_USER="$GH" LAVA_PRIMARY_USER="$USER" \
  bash "$REPO_ROOT/common/provision/firstboot.sh"
