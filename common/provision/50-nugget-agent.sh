#!/usr/bin/env bash
# Stand up the resident agent for nugget: on-box ollama, latest newt release,
# persona, and (re)start the tmux session so the agent window is live. Root.
# Runs after 45-nugget-tmux.sh. Idempotent.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common/provision/lib-provision.sh
source "$HERE/lib-provision.sh"

# --- on-box ollama (loopback-only) ------------------------------------------
# Bind to 127.0.0.1 so neither ollama nor the agent is network-reachable.
if have ollama; then
  install -d -m0755 /etc/systemd/system/ollama.service.d 2>/dev/null || true
  cat > /etc/systemd/system/ollama.service.d/10-lava-chicken.conf 2>/dev/null <<'EOF' || true
[Service]
Environment=OLLAMA_HOST=127.0.0.1:11434
EOF
  systemctl daemon-reload || true
  systemctl enable --now ollama.service 2>/dev/null \
    || pwarn "couldn't enable ollama.service — install/enable ollama; see scripts/40-ollama.sh"
else
  pwarn "ollama not installed yet — run scripts/40-ollama.sh; the agent will retry."
fi

# --- newt: install the LATEST release for nugget (not a source build) --------
if bash "$HERE/../bin/install-newt-release.sh" nugget; then
  plog "newt (latest release) installed for nugget"
else
  pwarn "newt release install failed (no release / network?) — agent loop will retry."
fi

# --- persona (newt loads by name from ~/.newt/personas/nugget.md) ------------
# The identity name is templated from the box name (@AGENT_NAME@ -> Kajiblet);
# the persona is selected at launch with `--persona nugget`.
PERSONA_DIR="$NUGGET_HOME/.newt/personas"
install -d -m0755 -o nugget -g nugget "$PERSONA_DIR"
NAME="$(box_name)"
DISP="$(printf '%s' "$NAME" | sed 's/^./\U&/')"   # Capitalized display name
for src in "$HERE/../persona/nugget-persona.md" \
           /usr/share/lava-chicken/persona/nugget-persona.md \
           "$STATE/persona/nugget-persona.md"; do
  if [ -r "$src" ]; then
    sed "s/@AGENT_NAME@/$DISP/g" "$src" > "$PERSONA_DIR/nugget.md"
    chown nugget:nugget "$PERSONA_DIR/nugget.md"
    chmod 0644 "$PERSONA_DIR/nugget.md"
    break
  fi
done

# --- (re)start the resident session so it picks up newt + persona ------------
systemctl restart nugget-agent-tmux.service 2>/dev/null \
  || systemctl start nugget-agent-tmux.service 2>/dev/null \
  || pwarn "couldn't (re)start nugget-agent-tmux.service"

plog "resident nugget agent ready. Attach: the 'nugget' desktop button, or"
plog "  ssh <you>@<box> then: /usr/share/lava-chicken/bin/attach-nugget"
