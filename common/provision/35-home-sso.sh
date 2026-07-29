#!/usr/bin/env bash
# Home SSO provisioning (issue #69). Root. Idempotent.
#
# Site-specific, so it runs from `lacos setup` (2nd boot), NOT baked into the
# generic image. Two jobs:
#   1) Trust the home.lab CA so *.home.lab TLS is clean (no scary warnings for
#      the kids) in the system store and the Flatpak browsers.
#   2) Install the per-user `lacos-sso.service` login unit that keeps each kid's
#      home SSO session warm.
#
# Inputs (from env / site.conf):
#   LAVA_HOME_CA_SRC   path or URL to the home CA root cert (PEM). Optional.
#   LAVA_AUTHENTIK_URL used to auto-fetch the CA from the TLS chain if no src.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common/provision/lib-provision.sh
source "$HERE/lib-provision.sh"

CA_SRC="${LAVA_HOME_CA_SRC:-}"
AUTHENTIK="${LAVA_AUTHENTIK_URL:-}"
ANCHOR=/etc/pki/ca-trust/source/anchors/homelab-ca.crt

# --- 1) CA trust ------------------------------------------------------------
fetch_ca() {  # -> writes PEM to $1, or returns 1
  local out="$1"
  if [ -n "$CA_SRC" ]; then
    if [ -r "$CA_SRC" ]; then cp "$CA_SRC" "$out"; return 0; fi
    if [[ "$CA_SRC" =~ ^https?:// ]] && have curl; then curl -fsSL "$CA_SRC" -o "$out" && return 0; fi
  fi
  # Fallback: pull the server-presented chain and keep the top (root) cert.
  if [ -n "$AUTHENTIK" ] && have openssl; then
    local host="${AUTHENTIK#*://}"; host="${host%%/*}"
    openssl s_client -connect "${host}:443" -showcerts </dev/null 2>/dev/null \
      | awk '/BEGIN CERTIFICATE/{c++} c{print > "'"$out"'.part"c}' >/dev/null 2>&1 || true
    # highest-numbered part is the root/intermediate closest to root
    local last; last="$(ls "${out}".part* 2>/dev/null | sort -V | tail -1)"
    [ -n "$last" ] && { mv "$last" "$out"; rm -f "${out}".part*; return 0; }
  fi
  return 1
}

if [ -f "$ANCHOR" ]; then
  plog "home CA already trusted ($ANCHOR)"
else
  tmp="$(mktemp)"
  if fetch_ca "$tmp" && openssl x509 -in "$tmp" -noout >/dev/null 2>&1; then
    install -m0644 "$tmp" "$ANCHOR"
    update-ca-trust 2>/dev/null || true
    plog "installed home CA -> $ANCHOR (subject: $(openssl x509 -in "$ANCHOR" -noout -subject 2>/dev/null | sed 's/^subject=//'))"
  else
    pwarn "could not obtain the home CA (set LAVA_HOME_CA_SRC to a PEM path/URL). Skipping CA trust."
  fi
  rm -f "$tmp" "${tmp}".part* 2>/dev/null || true
fi

# Flatpak browsers are sandboxed; grant them the host CA bundle so they see it.
if have flatpak; then
  for app in com.google.Chrome org.mozilla.firefox; do
    flatpak override --system "$app" \
      --filesystem=/etc/pki/ca-trust/extracted/pem:ro \
      --filesystem=/etc/ssl/certs:ro 2>/dev/null \
      && plog "granted $app read access to the host CA store" || true
  done
fi

# --- 2) per-user login unit -------------------------------------------------
# Install as a user unit template enabled for every present kid (+ admin).
UNIT_SRC="$HERE/../systemd/lacos-sso.service"
UNIT_DST=/etc/systemd/user/lacos-sso.service
if [ -r "$UNIT_SRC" ]; then
  install -Dm0644 "$UNIT_SRC" "$UNIT_DST"
  plog "installed user unit -> $UNIT_DST"
  # Enable globally so it starts in every user session (harmless if unenrolled:
  # `lacos-sso refresh` is a clean no-op when not configured/offline).
  systemctl --global enable lacos-sso.service 2>/dev/null \
    && plog "enabled lacos-sso.service for all user sessions" || true
fi

# Desktop launcher for the one-time "Sign in to Home" step.
LAUNCHER_SRC="$HERE/../desktop/lacos-home-signin.desktop"
[ -r "$LAUNCHER_SRC" ] && install -Dm0644 "$LAUNCHER_SRC" \
  /usr/share/applications/lacos-home-signin.desktop \
  && plog "installed 'Sign in to Home' launcher"

plog "Home SSO provisioning done."
