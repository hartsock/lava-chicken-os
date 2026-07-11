#!/usr/bin/env bash
# Preserve/enable Sunshine and firewall it into the homelab scheme
# (LAN + WireGuard). Pairing stays a manual one-time step (security boundary).
#
# On this AMD gaming box Sunshine captures the real Gamescope/KMS surface, so the
# gnuc headless Xorg-dummy dance does NOT apply here. See docs/REMOTE-DAYZERO.md.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common/provision/lib-provision.sh
source "$HERE/lib-provision.sh"
# shellcheck source=common/sunshine/ports.env
source "$HERE/../sunshine/ports.env"

USER_NAME="$(primary_user)"
OS="$(os_id)"

# --- make sure Sunshine is present + its user service is enabled ------------
enable_user_service() {
  # user services need lingering to run without an active login session
  loginctl enable-linger "$USER_NAME" 2>/dev/null || true
  as_primary systemctl --user daemon-reload 2>/dev/null || true
  if as_primary systemctl --user list-unit-files 2>/dev/null | grep -q '^sunshine\.service'; then
    as_primary systemctl --user enable --now sunshine.service && \
      plog "Sunshine user service enabled." && return 0
  fi
  return 1
}

case "$OS" in
  bazzite)
    # Bazzite ships Sunshine. Prefer its own setup path, then enable the service.
    # VERIFY: `ujust setup-sunshine` may be interactive; enabling the user
    # service directly is the non-interactive route.
    enable_user_service || pwarn "Sunshine service not found — run 'ujust setup-sunshine' once, then re-run this."
    ;;
  steamos|*)
    # SteamOS (and unknown): install the LizardByte Sunshine Flatpak (user scope).
    # VERIFY: flatpak app id + that the Flatpak's service can capture Gamescope.
    if have flatpak; then
      flatpak remote-add --user --if-not-exists flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo || true
      as_primary flatpak install --user -y flathub dev.lizardbyte.app.Sunshine \
        || pwarn "Sunshine flatpak install failed — install manually."
      enable_user_service || pwarn "Enable Sunshine from its app once installed."
    else
      pwarn "flatpak missing; cannot install Sunshine automatically on this OS."
    fi
    ;;
esac

# --- firewall: open Sunshine ports to LAN + WireGuard only -------------------
open_firewalld() {
  have firewall-cmd || return 1
  local cidr port
  for cidr in $SUNSHINE_ALLOW_CIDRS; do
    for port in $SUNSHINE_TCP_PORTS; do
      firewall-cmd --permanent --add-rich-rule \
        "rule family=ipv4 source address=$cidr port port=$port protocol=tcp accept" || true
    done
    for port in $SUNSHINE_UDP_PORTS; do
      firewall-cmd --permanent --add-rich-rule \
        "rule family=ipv4 source address=$cidr port port=$port protocol=udp accept" || true
    done
  done
  firewall-cmd --reload || true
  return 0
}

open_iptables() {
  have iptables || return 1
  local cidr port
  for cidr in $SUNSHINE_ALLOW_CIDRS; do
    for port in $SUNSHINE_TCP_PORTS; do
      iptables -C INPUT -s "$cidr" -p tcp --dport "$port" -j ACCEPT 2>/dev/null || \
        iptables -A INPUT -s "$cidr" -p tcp --dport "$port" -j ACCEPT
    done
    for port in $SUNSHINE_UDP_PORTS; do
      iptables -C INPUT -s "$cidr" -p udp --dport "$port" -j ACCEPT 2>/dev/null || \
        iptables -A INPUT -s "$cidr" -p udp --dport "$port" -j ACCEPT
    done
  done
  # NOTE: SteamOS iptables rules are not persistent across reboot by default.
  # VERIFY: persist via a systemd unit or iptables-save if SteamOS wipes them.
  return 0
}

if open_firewalld; then
  plog "firewalld: Sunshine ports opened to $SUNSHINE_ALLOW_CIDRS"
elif open_iptables; then
  plog "iptables: Sunshine ports opened to $SUNSHINE_ALLOW_CIDRS"
else
  pwarn "No known firewall backend; open these yourself:"
  pwarn "  TCP $SUNSHINE_TCP_PORTS   UDP $SUNSHINE_UDP_PORTS   from $SUNSHINE_ALLOW_CIDRS"
fi

plog "Pair once: browse https://<box>:47990, then Moonlight -> PIN. (Manual, by design.)"
