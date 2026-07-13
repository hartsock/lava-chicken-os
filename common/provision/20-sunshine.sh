#!/usr/bin/env bash
# Preserve/enable Sunshine and firewall it to trusted LAN/VPN subnets only.
# Pairing stays a manual one-time step (security boundary).
#
# On this AMD gaming box Sunshine captures the real Gamescope/KMS surface, so the
# headless-server Xorg-dummy dance does NOT apply here. See docs/REMOTE-DAYZERO.md.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common/provision/lib-provision.sh
source "$HERE/lib-provision.sh"
# shellcheck source=common/sunshine/ports.env
source "$HERE/../sunshine/ports.env"

USER_NAME="$(primary_user)"
OS="$(os_id)"
# Per-box/site overrides (LAVA_SUNSHINE_ENCODER etc.) if the wizard wrote them.
# shellcheck disable=SC1091
[ -r /etc/lava-chicken/site.conf ] && . /etc/lava-chicken/site.conf

# --- make sure Sunshine is present + its user service is enabled ------------
# Where the shipped Sunshine config defaults live (build.sh syncs common/ ->
# /usr/share/lava-chicken; SteamOS stages under $STATE).
SUN_SHARE=/usr/share/lava-chicken/sunshine
[ -d "$SUN_SHARE" ] || SUN_SHARE="$HERE/../sunshine"

# Seed the user's Sunshine config from the shipped defaults, COPY-IF-ABSENT so an
# operator's own edits are never clobbered (#45). apps.json = the LaCOS app
# entries; sunshine.conf = per-box settings incl. the encoder. The encoder is
# CONFIG, not code: the shipped sunshine.conf defaults to `encoder = vaapi`
# (required on Polaris/older AMD, where the auto-probe SIGSEGVs in the vulkan
# encoder path), and LAVA_SUNSHINE_ENCODER (site.conf) overrides per box.
seed_sunshine_config() {
  local home cfgdir f enc
  home="$(getent passwd "$USER_NAME" | cut -d: -f6)"; [ -n "$home" ] || return 0
  cfgdir="$home/.config/sunshine"
  install -d -m0755 -o "$USER_NAME" "$cfgdir"
  for f in sunshine.conf apps.json; do
    [ -f "$cfgdir/$f" ] && continue                 # respect existing user config
    [ -r "$SUN_SHARE/$f" ] && install -m0644 -o "$USER_NAME" "$SUN_SHARE/$f" "$cfgdir/$f" \
      && plog "Sunshine: seeded $f"
  done
  # Optional per-box encoder override from site.conf.
  enc="${LAVA_SUNSHINE_ENCODER:-}"
  if [ -n "$enc" ] && [ -f "$cfgdir/sunshine.conf" ]; then
    if grep -qE '^[[:space:]]*encoder[[:space:]]*=' "$cfgdir/sunshine.conf"; then
      sed -i "s|^[[:space:]]*encoder[[:space:]]*=.*|encoder = $enc|" "$cfgdir/sunshine.conf"
    else
      printf 'encoder = %s\n' "$enc" >> "$cfgdir/sunshine.conf"
    fi
    chown "$USER_NAME" "$cfgdir/sunshine.conf"
    plog "Sunshine: encoder set to '$enc' (LAVA_SUNSHINE_ENCODER)"
  fi
}

enable_user_service() {
  # user services need lingering to run without an active login session
  loginctl enable-linger "$USER_NAME" 2>/dev/null || true
  as_primary systemctl --user daemon-reload 2>/dev/null || true
  seed_sunshine_config
  # The image ships LizardByte Sunshine natively; its user unit is
  # app-dev.lizardbyte.app.Sunshine.service (it carries Alias=sunshine.service,
  # but aliases do NOT appear in list-unit-files until the unit is enabled — the
  # old guard grepped '^sunshine.service' and never matched on a fresh box, so
  # first boot silently skipped the enable, #45). Match EITHER name and enable
  # the REAL unit; prefer the native LizardByte unit.
  local units unit
  units="$(as_primary systemctl --user list-unit-files --no-legend 2>/dev/null | awk '{print $1}')"
  unit="$(printf '%s\n' "$units" | grep -E '^app-dev\.lizardbyte\.app\.Sunshine\.service$' | head -1)"
  [ -n "$unit" ] || unit="$(printf '%s\n' "$units" | grep -E '^sunshine\.service$' | head -1)"
  if [ -n "$unit" ]; then
    as_primary systemctl --user enable --now "$unit" && \
      plog "Sunshine user service enabled ($unit)." && return 0
  fi
  return 1
}

case "$OS" in
  bazzite)
    # LaCOS ships LizardByte Sunshine NATIVELY in the image (/usr/bin/sunshine +
    # the app-dev.lizardbyte.app.Sunshine.service user unit). Enable THAT.
    # Do NOT use `ujust setup-sunshine`: it now installs a SECOND Sunshine via
    # Homebrew (homebrew.sunshine.service), which conflicts with the native one.
    enable_user_service || pwarn "Sunshine user unit not found — image may not ship it (check: systemctl --user list-unit-files | grep -i sunshine)."
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
