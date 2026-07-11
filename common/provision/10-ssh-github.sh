#!/usr/bin/env bash
# Populate the primary user's authorized_keys from their GitHub account, and
# make sure key-only sshd is running. Idempotent: the GitHub keys live in a
# managed block so any hand-added keys are preserved.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common/provision/lib-provision.sh
source "$HERE/lib-provision.sh"

USER_NAME="$(primary_user)"
HOME_DIR="$(primary_home)"
SSH_DIR="$HOME_DIR/.ssh"
AUTH="$SSH_DIR/authorized_keys"

GH_USER="$(github_user)" || {
  pwarn "No GitHub user configured. Set LAVA_GITHUB_USER or write /usr/share/lava-chicken/github-user."
  pwarn "Skipping key import; sshd will still be enabled (no keys = no remote login yet)."
  GH_USER=""
}

# --- fetch keys -------------------------------------------------------------
if [ -n "$GH_USER" ]; then
  plog "Fetching public keys for github.com/$GH_USER ..."
  keys="$(curl -fsSL "https://github.com/${GH_USER}.keys")" || {
    pwarn "Could not fetch https://github.com/${GH_USER}.keys — network? bad user?"
    keys=""
  }
  if [ -z "${keys//[$'\n\r\t ']/}" ]; then
    pwarn "GitHub returned no keys for '$GH_USER'. Add an SSH key to that account and re-run."
  else
    install -d -m 0700 -o "$USER_NAME" -g "$USER_NAME" "$SSH_DIR"
    touch "$AUTH"
    # Replace only our managed block; keep everything else.
    begin="# >>> lava-chicken github:${GH_USER} >>>"
    end="# <<< lava-chicken github:${GH_USER} <<<"
    tmp="$(mktemp)"
    awk -v b="$begin" -v e="$end" '
      $0==b {skip=1} !skip {print} $0==e {skip=0}
    ' "$AUTH" > "$tmp"
    { printf '%s\n' "$begin"; printf '%s\n' "$keys"; printf '%s\n' "$end"; } >> "$tmp"
    install -m 0600 -o "$USER_NAME" -g "$USER_NAME" "$tmp" "$AUTH"
    rm -f "$tmp"
    n="$(printf '%s\n' "$keys" | grep -c 'ssh-\|ecdsa-\|sk-' || true)"
    plog "Installed $n key(s) for $USER_NAME from github.com/$GH_USER"
  fi
fi

# --- key-only sshd drop-in --------------------------------------------------
# Baked into the image on Bazzite (bazzite/system_files/etc/ssh/...); on SteamOS
# and unknown bases, write it here (was previously scripts/00-remote-access.sh).
if [ "$(os_id)" != bazzite ]; then
  install -d -m0755 /etc/ssh/sshd_config.d
  cat > /etc/ssh/sshd_config.d/10-lava-chicken.conf <<'EOF'
# lava-chicken-os: key-only SSH from day zero.
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
EOF
  plog "installed key-only sshd drop-in"
fi

# --- enable key-only sshd ---------------------------------------------------
if have systemctl; then
  # service is 'sshd' on Fedora/Bazzite/SteamOS-Arch
  systemctl enable --now sshd.service 2>/dev/null || \
    systemctl enable --now ssh.service 2>/dev/null || \
    pwarn "Could not enable sshd — enable it manually."
  plog "sshd enabled (key-only)."
else
  pwarn "systemctl not found; enable sshd yourself."
fi

plog "Remote login: ssh ${USER_NAME}@<box-ip>   (keys from github.com/${GH_USER:-<unset>})"
