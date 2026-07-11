#!/usr/bin/env bash
# Day-zero provisioning orchestrator. Runs as root — from the Bazzite first-boot
# unit, or via `sudo` from SteamOS bootstrap (scripts/05-provision.sh). Delegates
# each concern to a numbered script, then stamps so it never re-runs unattended.
# Every step is idempotent, so you can also re-run any of them by hand.
#
# Boot sound (05) is NOT here — it needs the owner's copied song and runs from
# scripts/22-boot-sound.sh in Desktop Mode.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common/provision/lib-provision.sh
source "$HERE/lib-provision.sh"

STAMP="$STAMP_DIR/firstboot.done"
mkdir -p "$STAMP_DIR"

# Resolve the GitHub user once and pass it down (human SSH + nugget SSH keys).
GH="$(github_user 2>/dev/null || true)"
export LAVA_GH_USER="$GH"
NAME="$(box_name)"
plog "box: $NAME   primary user: $(primary_user 2>/dev/null || echo '<none>')   github: ${GH:-<none>}   os: $(os_id)"

# Set the machine hostname to the box name (default nugget; e.g. kajiblet).
if have hostnamectl; then
  hostnamectl set-hostname "$NAME" 2>/dev/null || pwarn "couldn't set hostname to $NAME"
else
  echo "$NAME" > /etc/hostname 2>/dev/null || true
fi

run_step() {
  local script="$1"
  plog "==> $script"
  if ! bash "$HERE/$script"; then
    pwarn "$script failed — fix and re-run: sudo bash $HERE/$script"
    return 1
  fi
}

rc=0
run_step 10-ssh-github.sh  || rc=1   # admin (primary) key-only SSH (Sunshine untouched)
run_step 20-sunshine.sh    || rc=1   # remote desktop preserved + firewalled
run_step 30-users.sh       || rc=1   # kid accounts (passwordless) + autologin
run_step 40-nugget-user.sh || rc=1   # dedicated nugget account (propose-&-approve)
run_step 45-nugget-tmux.sh || rc=1   # resident tmux + all-user button + killswitch
run_step 50-nugget-agent.sh|| rc=1   # ollama + latest newt release + persona + start

if [ "$rc" -eq 0 ]; then
  date -u +%FT%TZ > "$STAMP"
  plog "first-boot provisioning complete."
else
  pwarn "one or more steps failed; NOT stamping — will retry next boot."
  exit 1
fi
