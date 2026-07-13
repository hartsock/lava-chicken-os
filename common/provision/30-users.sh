#!/usr/bin/env bash
# Create the kid accounts + configure autologin (issue #1). Root. Idempotent.
# The ADMIN is the OOBE-created primary user (uid 1000, e.g. hartsock, in wheel) —
# we do NOT recreate it; its GitHub keys come from 10-ssh-github. Kids are standard,
# PASSWORDLESS (click-to-switch), never in wheel/sudoers. Runs before 45 so the
# per-user nugget icon + persona get distributed to the kids too.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common/provision/lib-provision.sh
source "$HERE/lib-provision.sh"

# Kid accounts are opt-in: set LAVA_KID_USERS="alice bob" (build arg or
# /etc/lava-chicken/site.conf) to create standard passwordless users. The
# default is empty — an admin-only box until an operator names kid users.
KIDS="${LAVA_KID_USERS:-}"
AUTOLOGIN="${LAVA_AUTOLOGIN_USER:-}"

for kid in $KIDS; do
  if ! getent passwd "$kid" >/dev/null; then
    useradd -m -s /bin/bash -c "$kid" "$kid"
    plog "created kid user: $kid"
  fi
  # Passwordless local login (click-to-switch). sshd is key-only + password-auth
  # off, so this is not a remote-login hole. An empty password ALONE is not
  # enough on Fedora/SDDM: PAM only waives the prompt for members of
  # `nopasswdlogin` (real-hardware finding — kids were prompted anyway).
  passwd -d "$kid" >/dev/null 2>&1 || true
  groupadd -rf nopasswdlogin 2>/dev/null || true
  gpasswd -a "$kid" nopasswdlogin >/dev/null 2>&1 || true
  # A passwordless kid must NOT get a screen locker: KDE's lock screen demands a
  # password to UNLOCK, which a nopasswdlogin account cannot supply — the kid
  # ends up trapped behind a lock they can't clear (real-hardware finding: a kid
  # session auto-locked over a dialog and could never get back in). Disable idle
  # auto-lock + lock-on-resume for each kid, owned by the kid so KDE honors it.
  khome="$(getent passwd "$kid" | cut -d: -f6)"
  if [ -n "$khome" ] && [ -d "$khome" ]; then
    mkdir -p "$khome/.config"
    printf '[Daemon]\nAutolock=false\nLockOnResume=false\nTimeout=0\n' \
      > "$khome/.config/kscreenlockerrc"
    chown "$kid" "$khome/.config" "$khome/.config/kscreenlockerrc" 2>/dev/null || true
  fi
  # Belt-and-suspenders: kids are NEVER admins.
  gpasswd -d "$kid" wheel >/dev/null 2>&1 || true
  [ -z "$AUTOLOGIN" ] && AUTOLOGIN="$kid"   # default autologin target = first kid
done

# Autologin into a default session; KDE fast-user-switching changes users.
# VERIFY the session name for this Bazzite variant (plasma vs plasmawayland).
# DECK VARIANT (#23): bazzite-deck owns session autologin (boots the gamescope
# Game Mode session itself) — writing Session=plasma here would defeat the
# whole point of the deck image, so skip the SDDM drop-in entirely.
VARIANT="$(cat "$HERE/../variant" 2>/dev/null || echo stable)"
if [ "$VARIANT" = deck ]; then
  plog "deck variant: leaving session autologin to bazzite-deck (no SDDM override)"
elif [ -n "$AUTOLOGIN" ] && getent passwd "$AUTOLOGIN" >/dev/null; then
  install -d -m0755 /etc/sddm.conf.d
  cat > /etc/sddm.conf.d/10-lava-chicken-autologin.conf <<EOF
# LaCOS: boot straight into a default session; fast-user-switch (KDE) to change.
[Autologin]
User=$AUTOLOGIN
Session=plasma
Relogin=false
EOF
  plog "autologin -> $AUTOLOGIN (SDDM; VERIFY session name on hardware)"
fi

plog "users ready: admin=$(primary_user 2>/dev/null || echo '<primary>'); kids: $KIDS"
