#!/usr/bin/env bash
# Install ollama (AMD/ROCm build) entirely under $HOME + systemd user unit.
# Survives SteamOS atomic updates and Bazzite rebases.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

OLLAMA_DIR="$HOME/.local/share/ollama"
BIN_DIR="$HOME/.local/bin"
mkdir -p "$OLLAMA_DIR" "$BIN_DIR"

if [ -x "$BIN_DIR/ollama" ]; then
  log "ollama already installed at $BIN_DIR/ollama ($("$BIN_DIR/ollama" --version 2>/dev/null || true))"
else
  log "Downloading ollama linux-amd64 + ROCm bundle..."
  curl -fL --progress-bar -o /tmp/ollama.tgz \
    https://ollama.com/download/ollama-linux-amd64.tgz
  tar -xzf /tmp/ollama.tgz -C "$OLLAMA_DIR"
  curl -fL --progress-bar -o /tmp/ollama-rocm.tgz \
    https://ollama.com/download/ollama-linux-amd64-rocm.tgz
  tar -xzf /tmp/ollama-rocm.tgz -C "$OLLAMA_DIR"
  rm -f /tmp/ollama.tgz /tmp/ollama-rocm.tgz
  ln -sf "$OLLAMA_DIR/bin/ollama" "$BIN_DIR/ollama"
fi

# PATH for future shells
if ! grep -qs '.local/bin' "$HOME/.bashrc"; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
fi

# systemd user unit
UNIT_DIR="$HOME/.config/systemd/user"
mkdir -p "$UNIT_DIR"
sed "s|@OLLAMA@|$OLLAMA_DIR/bin/ollama|" "$REPO_ROOT/systemd/ollama.service" \
  > "$UNIT_DIR/ollama.service"
systemctl --user daemon-reload
systemctl --user enable --now ollama.service

log "Waiting for ollama API..."
for _ in $(seq 1 20); do
  curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1 && break
  sleep 1
done

# Models are pulled by lava-chicken-models.service on first boot (with progress),
# or on demand via `lacos models` — not here, so there's a single source of truth.
log "ollama ready. Models pull on first boot (lava-chicken-models.service) or via: lacos models"

log "Check GPU use with: journalctl --user -u ollama | grep -i rocm"
warn "Note: very old AMD GPUs (Vega gfx900/gfx906) are unsupported by current"
warn "ollama ROCm builds — it will silently fall back to CPU on those."
