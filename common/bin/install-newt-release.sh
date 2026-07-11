#!/usr/bin/env bash
# Install the LATEST newt-agent GitHub release (linux x86_64) to a SHARED dir so
# EVERY user can run it (the per-user "nugget" agent needs newt on all accounts).
# Public repo -> no token. Idempotent: re-run to upgrade to releases/latest.
#
# Usage: install-newt-release.sh [target-dir]   (default /var/lib/lava-chicken/bin)
set -euo pipefail
REPO="${NEWT_REPO:-Gilamonster-Foundation/newt-agent}"
BIN_DIR="${1:-/var/lib/lava-chicken/bin}"
API="https://api.github.com/repos/${REPO}/releases/latest"

command -v curl >/dev/null || { echo "curl required" >&2; exit 1; }

# Asset naming (confirmed v0.7.2): newt-agent-v<VER>-linux-x86_64.tar.gz
url="$(curl -fsSL "$API" \
  | grep -oE '"browser_download_url": *"[^"]*linux-x86_64\.tar\.gz"' \
  | head -1 | sed -E 's/.*"(https[^"]*)"/\1/')"
[ -n "$url" ] || { echo "[nugget] no linux-x86_64 tarball in ${REPO} latest" >&2; exit 1; }
ver="$(printf '%s\n' "$url" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
echo "[nugget] installing newt ${ver:-latest} -> $BIN_DIR"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
curl -fSL --progress-bar "$url" -o "$tmp/newt.tar.gz"
tar -xzf "$tmp/newt.tar.gz" -C "$tmp"

bin="$(find "$tmp" -type f -name newt -perm -u+x 2>/dev/null | head -1)"
[ -z "$bin" ] && bin="$(find "$tmp" -type f -name newt 2>/dev/null | head -1)"
[ -n "$bin" ] || { echo "[nugget] no 'newt' binary in tarball" >&2; exit 1; }

install -d -m0755 "$BIN_DIR"
install -m0755 "$bin" "$BIN_DIR/newt"       # 0755 = world-executable (all users)
echo "[nugget] installed -> $BIN_DIR/newt"
"$BIN_DIR/newt" --version 2>/dev/null || true
