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

KIDS="${LAVA_KID_USERS:-josiah joshua}"
AUTOLOGIN="${LAVA_AUTOLOGIN_USER:-}"

for kid in $KIDS; do
  if ! getent passwd "$kid" >/dev/null; then
    useradd -m -s /bin/bash -c "$kid" "$kid"
    plog "created kid user: $kid"
  fi
  # Passwordless local login (click-to-switch). sshd is key-only + password-auth
  # off, so this is not a remote-login hole.
  passwd -d "$kid" >/dev/null 2>&1 || true
  # Belt-and-suspenders: kids are NEVER admins.
  gpasswd -d "$kid" wheel >/dev/null 2>&1 || true
  [ -z "$AUTOLOGIN" ] && AUTOLOGIN="$kid"   # default autologin target = first kid
done

# Autologin into a default session; KDE fast-user-switching changes users.
# VERIFY the session name for this Bazzite variant (plasma vs plasmawayland).
if [ -n "$AUTOLOGIN" ] && getent passwd "$AUTOLOGIN" >/dev/null; then
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
