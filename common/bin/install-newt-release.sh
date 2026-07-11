#!/usr/bin/env bash
# Install the LATEST newt-agent GitHub release (linux x86_64 tarball) into a
# target user's ~/.local/bin. No Rust toolchain, no build. Public repo -> no
# token. Idempotent: re-run to upgrade to whatever releases/latest points at.
#
# Usage: install-newt-release.sh <target-user>
set -euo pipefail
REPO="${NEWT_REPO:-Gilamonster-Foundation/newt-agent}"
U="${1:?usage: install-newt-release.sh <user>}"
HOME_DIR="$(getent passwd "$U" | cut -d: -f6)"
BIN_DIR="$HOME_DIR/.local/bin"
API="https://api.github.com/repos/${REPO}/releases/latest"

command -v curl >/dev/null || { echo "curl required" >&2; exit 1; }

# Resolve the linux-x86_64 tarball asset URL from releases/latest.
# Asset naming (confirmed): newt-agent-v<VER>-linux-x86_64.tar.gz
url="$(curl -fsSL "$API" \
  | grep -oE '"browser_download_url": *"[^"]*linux-x86_64\.tar\.gz"' \
  | head -1 | sed -E 's/.*"(https[^"]*)"/\1/')"
if [ -z "$url" ]; then
  echo "[nugget] no linux-x86_64 tarball in ${REPO} releases/latest" >&2
  exit 1
fi
ver="$(printf '%s\n' "$url" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
echo "[nugget] installing newt ${ver:-latest} from $url"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
curl -fSL --progress-bar "$url" -o "$tmp/newt.tar.gz"
tar -xzf "$tmp/newt.tar.gz" -C "$tmp"

# Find the newt binary in the extracted tree.
bin="$(find "$tmp" -type f -name newt -perm -u+x 2>/dev/null | head -1)"
[ -z "$bin" ] && bin="$(find "$tmp" -type f -name newt 2>/dev/null | head -1)"
[ -z "$bin" ] && { echo "[nugget] no 'newt' binary in tarball" >&2; exit 1; }

install -d -m0755 -o "$U" "$BIN_DIR"
install -m0755 -o "$U" -g "$(id -gn "$U")" "$bin" "$BIN_DIR/newt"
echo "[nugget] installed -> $BIN_DIR/newt"
"$BIN_DIR/newt" --version 2>/dev/null || true
