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

# Set the machine hostname to the box name (default nugget; e.g. arcade).
if have hostnamectl; then
  hostnamectl set-hostname "$NAME" 2>/dev/null || pwarn "couldn't set hostname to $NAME"
else
  echo "$NAME" > /etc/hostname 2>/dev/null || true
fi

# HARDWARE-DAY fix (#27): every step is TIME-BOUNDED so no single step can
# wedge first boot forever (v0.0.1 hung on a service start and never finished,
# re-running + re-hanging every boot). 5 min is generous for any one step.
run_step() {
  local script="$1"
  plog "==> $script"
  if ! timeout --signal=TERM --kill-after=30 300 bash "$HERE/$script"; then
    local rc=$?
    [ "$rc" -ge 124 ] && pwarn "$script TIMED OUT after 5 min (killed)" \
                      || pwarn "$script failed (rc=$rc)"
    pwarn "re-run by hand: sudo bash $HERE/$script"
    echo "$script" >> "$STAMP_DIR/firstboot.failed-steps"
    return 1
  fi
}

rc=0
rm -f "$STAMP_DIR/firstboot.failed-steps"
run_step 10-ssh-github.sh  || rc=1   # admin (primary) key-only SSH (Sunshine untouched)
run_step 20-sunshine.sh    || rc=1   # remote desktop preserved + firewalled
run_step 30-users.sh       || rc=1   # kid accounts (passwordless) + autologin
run_step 40-nugget-user.sh || rc=1   # dedicated nugget account (propose-&-approve)
run_step 45-nugget-tmux.sh || rc=1   # resident tmux + all-user button + killswitch
run_step 50-nugget-agent.sh|| rc=1   # ollama config + latest newt release + persona
run_step 07-plymouth.sh    || rc=1   # splash theme + initramfs regen (next boot)
run_step 60-apps.sh        || rc=1   # creative + gaming apps (background install)

# ALWAYS stamp (#27): an unattended retry-next-boot loop is how a box wedges
# forever. Failed steps are recorded in firstboot.failed-steps, surfaced by
# `lacos status`, and each is safe to re-run by hand.
date -u +%FT%TZ > "$STAMP"
if [ "$rc" -eq 0 ]; then
  plog "first-boot provisioning complete."
else
  pwarn "provisioning finished WITH FAILURES: $(tr '\n' ' ' < "$STAMP_DIR/firstboot.failed-steps" 2>/dev/null)"
  pwarn "stamped anyway (no unattended retry loops); see 'lacos status'."
  exit 1
fi
