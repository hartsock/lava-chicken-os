#!/usr/bin/env bash
# Install the resident tmux service + the "nugget" button (all-user, system-wide)
# + the polkit grant. Enroll every human user in nugget-tui so ALL users can
# attach. Root. Idempotent. Runs after 40-nugget-user.sh.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common/provision/lib-provision.sh
source "$HERE/lib-provision.sh"

OS="$(os_id)"

# Enroll all human accounts (uid >= 1000, excluding nugget) into nugget-tui.
getent group "$NUGGET_TUI_GROUP" >/dev/null || groupadd -g "$NUGGET_TUI_GID" "$NUGGET_TUI_GROUP"
while IFS=: read -r name _ uid _; do
  [ "$uid" -ge 1000 ] && [ "$uid" -lt 65000 ] && [ "$name" != nugget ] || continue
  gpasswd -a "$name" "$NUGGET_TUI_GROUP" >/dev/null && plog "nugget-tui += $name"
done < <(getent passwd)

install_unit() {  # $1 = unit filename ; rewrites /usr/share -> /var on SteamOS
  local u="$1"
  if [ "$OS" = bazzite ]; then return 0; fi   # baked in image
  sed 's#/usr/share/lava-chicken/#'"$STATE"'/#' "$HERE/../systemd/$u" \
    > "/etc/systemd/system/$u"
}

# tmpfiles: setgid socket dir + sudo-io audit dirs + killswitch dir. Baked on
# Bazzite; written to /etc on SteamOS. Materialize now so the service can start.
if [ "$OS" = bazzite ]; then
  TMPF=/usr/lib/tmpfiles.d/lava-chicken.conf
else
  TMPF=/etc/tmpfiles.d/lava-chicken.conf
  install -D -m0644 "$HERE/../tmpfiles/lava-chicken.conf" "$TMPF"
fi
systemd-tmpfiles --create "$TMPF" 2>/dev/null || pwarn "tmpfiles --create failed; /run/nugget may be missing"

if [ "$OS" != bazzite ]; then
  # SteamOS: /usr is read-only -> stage code under persistent /var, units in /etc.
  install -d -m0755 "$STATE/bin" "$STATE/libexec" "$STATE/persona"
  install -m0755 "$HERE/../bin/nugget-agent-run"  "$STATE/bin/nugget-agent-run"
  install -m0755 "$HERE/../bin/nugget-agent-loop" "$STATE/bin/nugget-agent-loop"
  install -m0755 "$HERE/../bin/attach-nugget"     "$STATE/bin/attach-nugget"
  install -m0755 "$HERE/../bin/nugget-agentctl"   "$STATE/bin/nugget-agentctl"
  install -m0755 "$HERE/../bin/lacos"             "$STATE/bin/lacos"
  ln -sf "$STATE/bin/lacos" /usr/local/bin/lacos 2>/dev/null || true  # onto PATH if writable
  install -m0644 "$HERE/../persona/nugget-persona.md" "$STATE/persona/nugget-persona.md"
  install -m0755 "$HERE/../libexec/nugget-grant-tui" /usr/libexec/nugget-grant-tui 2>/dev/null \
    || install -m0755 "$HERE/../libexec/nugget-grant-tui" "$STATE/libexec/nugget-grant-tui"
  install -D -m0644 "$HERE/../polkit/50-nugget-tui.rules" /etc/polkit-1/rules.d/50-nugget-tui.rules
  install_unit nugget-agent-tmux.service
  install_unit nugget-agent-grant@.service
  plog "off-switch: sudo $STATE/bin/nugget-agentctl {pause|kill|disable|resume|status}"
fi

systemctl daemon-reload || true
systemctl enable --now nugget-agent-tmux.service \
  || pwarn "nugget-agent-tmux.service didn't start — check 'systemctl status nugget-agent-tmux'"

# --- the "nugget" button, on every user's desktop ---------------------------
BIN_PATH="/usr/share/lava-chicken/bin/attach-nugget"
[ "$OS" = bazzite ] || BIN_PATH="$STATE/bin/attach-nugget"

if [ "$OS" = bazzite ]; then
  : # /usr/share/applications/nugget-agent.desktop is baked; all users see it.
else
  # SteamOS: /usr read-only -> install per-user + /etc/skel for future users.
  render_desktop() { sed 's#/usr/share/lava-chicken/bin/attach-nugget#'"$BIN_PATH"'#' \
                       "$HERE/../desktop/nugget-agent.desktop"; }
  install -d -m0755 /etc/skel/.local/share/applications
  render_desktop > /etc/skel/.local/share/applications/nugget-agent.desktop
  while IFS=: read -r name _ uid _ _ home _; do
    [ "$uid" -ge 1000 ] && [ "$uid" -lt 65000 ] && [ -d "$home" ] || continue
    install -d -m0755 -o "$name" "$home/.local/share/applications"
    render_desktop > "$home/.local/share/applications/nugget-agent.desktop"
    chown "$name" "$home/.local/share/applications/nugget-agent.desktop"
  done < <(getent passwd)
fi

plog "resident nugget session + button installed (all human users enrolled)."
