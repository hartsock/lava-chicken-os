#!/usr/bin/env bash
# Shared helpers for day-zero provisioning. Source me; don't run me.
# Used identically by the Bazzite first-boot unit and SteamOS bootstrap.
set -euo pipefail

PAYLOAD_ROOT="${PAYLOAD_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
STAMP_DIR="/var/lib/lava-chicken"

plog()  { printf '\033[1;33m[lava-chicken:provision]\033[0m %s\n' "$*"; }
pwarn() { printf '\033[1;31m[lava-chicken:provision]\033[0m %s\n' "$*" >&2; }

have() { command -v "$1" >/dev/null 2>&1; }

# Create group $1, preferring GID $2 but falling back to ANY free GID if that
# GID is already taken. The exact GID is not load-bearing — every consumer looks
# the group up by NAME — and base images vary in what occupies a given GID (on
# bazzite GID 971 is already used, which is why `groupadd -g 971` aborts a
# provision script under `set -e` when the group doesn't yet exist). Idempotent.
ensure_group() {  # $1=name  $2=preferred-gid
  getent group "$1" >/dev/null && return 0
  groupadd -g "$2" "$1" 2>/dev/null || groupadd "$1"
}

# The GitHub username whose public keys seed SSH access.
# Baked into the image (build.sh) or overridable via env for the SteamOS path.
github_user() {
  if [ -n "${LAVA_GITHUB_USER:-}" ]; then
    echo "$LAVA_GITHUB_USER"; return 0
  fi
  if [ -r /usr/share/lava-chicken/github-user ]; then
    tr -d '[:space:]' < /usr/share/lava-chicken/github-user; return 0
  fi
  if [ -r "$PAYLOAD_ROOT/github-user" ]; then
    tr -d '[:space:]' < "$PAYLOAD_ROOT/github-user"; return 0
  fi
  return 1
}

# The primary human user (first real login account, uid 1000 by convention on
# both Bazzite OOBE and SteamOS 'deck').
primary_user() {
  if [ -n "${LAVA_PRIMARY_USER:-}" ]; then echo "$LAVA_PRIMARY_USER"; return 0; fi
  getent passwd 1000 | cut -d: -f1
}

primary_home() {
  getent passwd "$(primary_user)" | cut -d: -f6
}

# Run a command as the primary user, with the env `systemctl --user` and
# `flatpak --user` need (XDG_RUNTIME_DIR must point at the user's runtime dir,
# which exists once lingering is enabled).
as_primary() {
  local u uid; u="$(primary_user)"; uid="$(id -u "$u")"
  if [ "$(id -un)" = "$u" ]; then
    "$@"
  else
    runuser -u "$u" -- env "XDG_RUNTIME_DIR=/run/user/$uid" "$@"
  fi
}

# True if newt is on the primary user's PATH (checks ~/.local/bin too).
primary_has_newt() {
  as_primary bash -lc 'PATH="$HOME/.local/bin:$PATH" command -v newt' >/dev/null 2>&1
}

# OS family: bazzite (Fedora Atomic/bootc) | steamos (Arch A/B) | <id> | unknown
os_id() {
  [ -r /etc/os-release ] || { echo unknown; return; }
  local ID="" ID_LIKE=""; . /etc/os-release
  case "${ID}:${ID_LIKE}" in
    bazzite*|*:*fedora*) echo bazzite ;;
    steamos*|*:*arch*)   echo steamos ;;
    *) echo "${ID:-unknown}" ;;
  esac
}

# --- nugget resident-agent identity (single source of truth) ----------------
# Pinned system-range account (<1000): never collides with the human (>=1000)
# and never shows in the SDDM user picker. The human logs in as themselves and
# only *attaches* nugget's tmux session.
NUGGET_USER="${LAVA_BOX_NAME:-nugget}"   # default box name AND agent user = nugget
NUGGET_UID=970
NUGGET_GID=970
NUGGET_HOME="/var/home/nugget"           # ostree: /home -> /var/home (persistent)
NUGGET_TUI_GROUP=nugget-tui              # attach-rights group (all human users)
NUGGET_TUI_GID=971
STATE=/var/lib/lava-chicken              # per-machine writable-persistent state
TMUX_SOCK=/run/nugget/tmux.sock

# Box + agent display name. Default "nugget"; setup may change it (e.g. arcade).
# NOTE (v0.0.1 scope): this sets the HOSTNAME and the agent's PRESENTED identity
# (persona name + GECOS). The underlying Unix service account stays `nugget` —
# a full account rename is a tracked follow-up (see docs/REMOTE-DAYZERO.md).
box_name() {
  if [ -n "${LAVA_BOX_NAME:-}" ]; then echo "$LAVA_BOX_NAME"; return; fi
  [ -r /usr/share/lava-chicken/box-name ] && { tr -d '[:space:]' < /usr/share/lava-chicken/box-name; return; }
  [ -r "$PAYLOAD_ROOT/box-name" ] && { tr -d '[:space:]' < "$PAYLOAD_ROOT/box-name"; return; }
  echo nugget
}

# Resolve a brand image from the baked payload (Bazzite) or the repo (SteamOS).
brand_image() {  # $1 = filename under brand/ (e.g. nugget-avatar.png)
  local f="$1" c
  for c in "/usr/share/lava-chicken/brand/$f" \
           "$PAYLOAD_ROOT/../assets/brand/$f" \
           "$PAYLOAD_ROOT/brand/$f"; do
    [ -r "$c" ] && { echo "$c"; return 0; }
  done
  return 1
}
