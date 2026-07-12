#!/usr/bin/env bash
# Two things:
#  1. The RESIDENT nugget tmux session (for REMOTE ADMIN) — attachable only by
#     ADMINS. Kids are deliberately kept OUT of this path (it reaches the
#     nugget account) until newt OCAP can make shared access safe.
#  2. The PER-USER "nugget" agent — a launcher + persona in every human's own
#     account, so anyone (admins AND kids) gets their own newt running as
#     themselves, with no root exposure. THIS is what the desktop icon runs.
# Root. Idempotent. Runs after 40-nugget-user.sh.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common/provision/lib-provision.sh
source "$HERE/lib-provision.sh"

OS="$(os_id)"

# --- nugget-tui = ADMINS ONLY -----------------------------------------------
# Only wheel (admin) users may attach the resident nugget tmux. Kids are NOT
# enrolled — the per-user icon (below) is their access. Revisit once OCAP ships.
getent group "$NUGGET_TUI_GROUP" >/dev/null || groupadd -g "$NUGGET_TUI_GID" "$NUGGET_TUI_GROUP"
for name in $(getent group wheel | cut -d: -f4 | tr ',' ' '); do
  [ -n "$name" ] && [ "$name" != nugget ] || continue
  gpasswd -a "$name" "$NUGGET_TUI_GROUP" >/dev/null && plog "nugget-tui += $name (admin)"
done

install_unit() {  # $1 = unit filename ; rewrites /usr/share -> /var on SteamOS
  [ "$OS" = bazzite ] && return 0
  sed 's#/usr/share/lava-chicken/#'"$STATE"'/#' "$HERE/../systemd/$1" > "/etc/systemd/system/$1"
}

# tmpfiles: setgid socket dir + sudo-io audit + killswitch dir. Materialize now.
if [ "$OS" = bazzite ]; then TMPF=/usr/lib/tmpfiles.d/lava-chicken.conf
else TMPF=/etc/tmpfiles.d/lava-chicken.conf; install -D -m0644 "$HERE/../tmpfiles/lava-chicken.conf" "$TMPF"; fi
systemd-tmpfiles --create "$TMPF" 2>/dev/null || pwarn "tmpfiles --create failed; /run/nugget may be missing"

if [ "$OS" != bazzite ]; then
  # SteamOS: /usr is read-only -> stage code under persistent /var, units in /etc.
  install -d -m0755 "$STATE/bin" "$STATE/libexec" "$STATE/persona"
  for b in nugget-agent-run nugget-agent-loop attach-nugget nugget-agentctl lacos nugget \
           lacos-pull-models lacos-install-apps lacos-setup; do
    install -m0755 "$HERE/../bin/$b" "$STATE/bin/$b"
  done
  install -D -m0644 "$HERE/../desktop/lacos-setup.desktop" /etc/skel/.local/share/applications/lacos-setup.desktop
  ln -sf "$STATE/bin/lacos"  /usr/local/bin/lacos  2>/dev/null || true
  ln -sf "$STATE/bin/nugget" /usr/local/bin/nugget 2>/dev/null || true
  install -m0755 "$HERE/../libexec/nugget-grant-tui" /usr/libexec/nugget-grant-tui 2>/dev/null \
    || install -m0755 "$HERE/../libexec/nugget-grant-tui" "$STATE/libexec/nugget-grant-tui"
  install -D -m0644 "$HERE/../polkit/50-nugget-tui.rules" /etc/polkit-1/rules.d/50-nugget-tui.rules
  install -D -m0644 "$HERE/../profile.d/lava-chicken.sh" /etc/profile.d/lava-chicken.sh
  install_unit nugget-agent-tmux.service
  install_unit nugget-agent-grant@.service
fi

systemctl daemon-reload || true
# NEVER block provisioning on a service start (#27): v0.0.1's `enable --now`
# waited on a start job that never completed and wedged all of first boot.
systemctl enable nugget-agent-tmux.service 2>/dev/null \
  || pwarn "couldn't enable nugget-agent-tmux.service"
systemctl start --no-block nugget-agent-tmux.service \
  || pwarn "nugget-agent-tmux.service didn't start — check 'systemctl status nugget-agent-tmux'"

# --- per-user "nugget" persona, rendered once and dropped into every home ----
NAME="$(box_name)"; DISP="$(printf '%s' "$NAME" | sed 's/^./\U&/')"
install -d -m0755 "$STATE/persona"
sed "s/@AGENT_NAME@/$DISP/g" "$HERE/../persona/nugget-persona.md" > "$STATE/persona/nugget.md"
chmod 0644 "$STATE/persona/nugget.md"
install -D -m0644 "$STATE/persona/nugget.md" /etc/skel/.newt/personas/nugget.md
# Bundled newt SKILLS ride the same rails (#19): whole skill dirs copied to
# ~/.newt/skills/<name>/ (newt's per-user discovery path; sibling files ship
# too, per the skill format). Their frontmatter caveats (net: {only: []})
# DECLARE the prep-never-publish leash; newt currently PARSES caveats without
# enforcing them (upstream parse-only MVP), so today's boundary is the skill
# body + each user's own OS permissions — the caveats become load-bearing when
# newt's meet-enforcement lands.
SKILLS_SRC="$HERE/../newt-skills"
for sk in "$SKILLS_SRC"/*/; do
  [ -f "$sk/SKILL.md" ] || continue
  skn="$(basename "$sk")"
  install -d -m0755 "/etc/skel/.newt/skills/$skn"
  cp -a "$sk"/. "/etc/skel/.newt/skills/$skn/"
done
while IFS=: read -r uname _ uid _ _ uhome _; do
  [ "$uid" -ge 1000 ] && [ "$uid" -lt 65000 ] && [ -d "$uhome" ] || continue
  install -d -m0755 -o "$uname" "$uhome/.newt/personas"
  install -m0644 -o "$uname" "$STATE/persona/nugget.md" "$uhome/.newt/personas/nugget.md"
  for sk in "$SKILLS_SRC"/*/; do
    [ -f "$sk/SKILL.md" ] || continue
    skn="$(basename "$sk")"
    install -d -m0755 -o "$uname" "$uhome/.newt/skills/$skn"
    cp -a "$sk"/. "$uhome/.newt/skills/$skn/"
    chown -R "$uname" "$uhome/.newt/skills/$skn"
  done
  # default wallpaper on first login (Bazzite; SteamOS applies it via scripts/10)
  if [ "$OS" = bazzite ] && [ -r "$HERE/../autostart/lava-chicken-wallpaper.desktop" ]; then
    install -d -m0755 -o "$uname" "$uhome/.config/autostart"
    install -m0644 -o "$uname" "$HERE/../autostart/lava-chicken-wallpaper.desktop" \
      "$uhome/.config/autostart/lava-chicken-wallpaper.desktop"
  fi
  # Game-Mode startup movie (#31): per-user Steam uioverrides — used when the
  # box runs in console mode; harmless on desktop.
  if [ -r "$HERE/../brand/boot-movie.webm" ]; then
    install -d -o "$uname" "$uhome/.steam/root/config/uioverrides/movies" 2>/dev/null \
      && install -m0644 -o "$uname" "$HERE/../brand/boot-movie.webm" \
           "$uhome/.steam/root/config/uioverrides/movies/lava-chicken.webm" 2>/dev/null \
      || true
  fi
done < <(getent passwd)

# --- the "nugget" icon on every user's desktop (per-user launch) -------------
LAUNCH="/usr/bin/nugget"; [ "$OS" = bazzite ] || LAUNCH="$STATE/bin/nugget"
render_desktop() { sed 's#/usr/bin/nugget#'"$LAUNCH"'#' "$HERE/../desktop/nugget-agent.desktop"; }
if [ "$OS" = bazzite ]; then
  : # /usr/share/applications/nugget-agent.desktop is baked (Exec=/usr/bin/nugget)
else
  install -d -m0755 /etc/skel/.local/share/applications
  render_desktop > /etc/skel/.local/share/applications/nugget-agent.desktop
  while IFS=: read -r uname _ uid _ _ uhome _; do
    [ "$uid" -ge 1000 ] && [ "$uid" -lt 65000 ] && [ -d "$uhome" ] || continue
    install -d -m0755 -o "$uname" "$uhome/.local/share/applications"
    render_desktop > "$uhome/.local/share/applications/nugget-agent.desktop"
    chown "$uname" "$uhome/.local/share/applications/nugget-agent.desktop"
  done < <(getent passwd)
fi

plog "resident nugget = admin-only remote; per-user 'nugget' icon installed for all."
