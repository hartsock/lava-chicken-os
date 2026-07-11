#!/usr/bin/env bash
# Create/provision the dedicated `nugget` agent account: home, SSH keys, sudo.
# Root. Idempotent + re-entrant (safe to re-run every boot on SteamOS).
#
# Bazzite: identity is baked via sysusers.d; this fills $HOME/keys/sudo.
# SteamOS: no sysusers pass, so create the account here too.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common/provision/lib-provision.sh
source "$HERE/lib-provision.sh"

OS="$(os_id)"

# --- identity ---------------------------------------------------------------
if [ "$OS" = steamos ]; then
  getent group nugget            >/dev/null || groupadd -g "$NUGGET_GID" nugget
  getent group "$NUGGET_TUI_GROUP" >/dev/null || groupadd -g "$NUGGET_TUI_GID" "$NUGGET_TUI_GROUP"
  getent passwd nugget           >/dev/null || useradd -u "$NUGGET_UID" -g nugget \
    -d "$NUGGET_HOME" -m -s /bin/bash -c "Lava Chicken Nugget agent" nugget
  # Persist account + authz files across SteamOS atomic updates.
  install -d -m0755 /etc/atomic-update.conf.d
  cat > /etc/atomic-update.conf.d/lava-chicken.conf <<'EOF'
# Keep the nugget account + its sudo across SteamOS updates.
/etc/passwd
/etc/group
/etc/shadow
/etc/gshadow
/etc/subuid
/etc/subgid
/etc/sudoers.d/nugget
EOF
fi

install -d -m0700 -o nugget -g nugget "$NUGGET_HOME"
install -d -m0700 -o nugget -g nugget "$NUGGET_HOME/.ssh"

# --- SSH keys: PUBLIC keys only, fetched at provision, installed ROOT-OWNED ---
# Root-owned so the agent can't self-add keys to its own authorized_keys (R4).
GH="${LAVA_GH_USER:-${LAVA_PRIMARY_USER:-}}"
if [ -z "$GH" ]; then GH="$(github_user 2>/dev/null || true)"; fi
if [ -n "$GH" ]; then
  if curl -fsSL "https://github.com/${GH}.keys" -o "$NUGGET_HOME/.ssh/authorized_keys"; then
    chown root:nugget "$NUGGET_HOME/.ssh/authorized_keys"
    chmod 0640 "$NUGGET_HOME/.ssh/authorized_keys"
    plog "nugget authorized_keys <- github.com/${GH}.keys (root-owned)"
  else
    pwarn "could not fetch github.com/${GH}.keys; nugget has no SSH access yet"
  fi
else
  pwarn "no GitHub user (LAVA_GH_USER); skipping nugget SSH keys"
fi

have restorecon && restorecon -R "$NUGGET_HOME" || true   # SELinux relabel of /var/home

# --- sudo: validate BEFORE install so a bad drop-in can't lock out sudo ------
tmp="$(mktemp)"
cp "$HERE/../sudoers/nugget" "$tmp"
if visudo -cf "$tmp" >/dev/null 2>&1; then
  install -m0440 -o root -g root "$tmp" /etc/sudoers.d/nugget
  install -d -m0750 /var/log 2>/dev/null || true
  : > /var/log/nugget-sudo.log 2>/dev/null || true
  plog "installed /etc/sudoers.d/nugget (validated)"
else
  pwarn "sudoers/nugget FAILED visudo validation — NOT installing (would risk lockout)"
  rm -f "$tmp"; exit 1
fi
rm -f "$tmp"

# --- presented identity + avatar --------------------------------------------
# GECOS reflects the box name (default nugget; e.g. "kajiblet agent"). The Unix
# account name stays `nugget` in this pass (full rename is a tracked follow-up).
NAME="$(box_name)"
usermod -c "${NAME} agent" nugget 2>/dev/null || true

# Profile picture: the nugget mascot, as the account avatar (.face + AccountsService).
if AV="$(brand_image nugget-avatar.png)"; then
  install -m0644 -o nugget -g nugget "$AV" "$NUGGET_HOME/.face"
  install -D -m0644 "$AV" /var/lib/AccountsService/icons/nugget 2>/dev/null || true
  mkdir -p /var/lib/AccountsService/users 2>/dev/null || true
  cat > /var/lib/AccountsService/users/nugget 2>/dev/null <<'EOF' || true
[User]
Icon=/var/lib/AccountsService/icons/nugget
EOF
  plog "nugget avatar set from $(basename "$AV")"
else
  pwarn "no nugget-avatar.png found in payload/repo; skipping avatar"
fi

# nugget needs a running user manager for its systemd --user session (agent, etc.)
loginctl enable-linger nugget 2>/dev/null || true
plog "nugget account ready (uid $NUGGET_UID, home $NUGGET_HOME, NOPASSWD sudo, box '$NAME')"
