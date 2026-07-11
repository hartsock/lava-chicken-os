#!/usr/bin/env bash
# Shared helpers. Source me; don't run me.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
USER_ASSETS="$REPO_ROOT/assets/user"
GEN_OUT="$REPO_ROOT/assets/generated/out"

log()  { printf '\033[1;33m[lava-chicken]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;31m[lava-chicken]\033[0m %s\n' "$*" >&2; }

detect_os() {
  # echoes: steamos | bazzite | other
  local id=""
  [ -r /etc/os-release ] && id="$(. /etc/os-release; echo "${ID:-}")"
  case "$id" in
    steamos) echo steamos ;;
    bazzite) echo bazzite ;;
    *)       echo other ;;
  esac
}

have() { command -v "$1" >/dev/null 2>&1; }

# Find the user's lava chicken audio file, any common extension.
find_audio() {
  local ext
  for ext in mp3 m4a ogg opus wav flac; do
    if [ -f "$USER_ASSETS/lava-chicken.$ext" ]; then
      echo "$USER_ASSETS/lava-chicken.$ext"
      return 0
    fi
  done
  return 1
}

require_audio() {
  find_audio || {
    warn "No audio found. Put your copy of the song at:"
    warn "  $USER_ASSETS/lava-chicken.mp3  (or .m4a/.ogg/.opus/.wav/.flac)"
    warn "See docs/LEGAL-ASSETS.md for why we don't ship it."
    exit 1
  }
}

# ffmpeg on immutable OSes: host binary, brew, or flatpak shim.
ffmpeg_cmd() {
  if have ffmpeg; then echo ffmpeg; return; fi
  if have brew && brew list ffmpeg >/dev/null 2>&1; then echo ffmpeg; return; fi
  if have brew; then
    warn "Installing ffmpeg via Homebrew..."
    brew install ffmpeg >&2 && { echo ffmpeg; return; }
  fi
  warn "ffmpeg not found. Options:"
  warn "  Bazzite:  brew install ffmpeg"
  warn "  SteamOS:  distrobox create -n lava --image archlinux:latest && distrobox enter lava -- sudo pacman -S ffmpeg"
  warn "  Either:   run this step on another machine and copy the .webm over"
  return 1
}
