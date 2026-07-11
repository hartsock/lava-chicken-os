#!/usr/bin/env bash
# Install the boot-sound WAV + system service. Called by scripts/22-boot-sound.sh
# (which renders the WAV) — NOT by first-boot, since there's no song yet at first
# boot. Root. Idempotent.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common/provision/lib-provision.sh
source "$HERE/lib-provision.sh"

install -d -m0755 "$STATE" /etc/lava-chicken

if [ -n "${LAVA_BOOT_WAV:-}" ] && [ -r "${LAVA_BOOT_WAV}" ]; then
  install -m0644 "$LAVA_BOOT_WAV" "$STATE/boot-sound.wav"
  plog "boot sound WAV -> $STATE/boot-sound.wav"
else
  pwarn "no WAV provided (LAVA_BOOT_WAV); unit stays inert until one exists"
fi

have aplay || pwarn "aplay (alsa-utils) missing; boot sound will silently skip"

case "$(os_id)" in
  bazzite)
    # Unit + wrapper are baked in the image (/usr/lib + /usr/share); preset
    # enabled the unit. Just reload in case this is a live re-run.
    systemctl daemon-reload || true
    ;;
  *)
    # SteamOS / unknown: /usr is read-only, so install the wrapper to /var and
    # the unit to persistent /etc, rewriting ExecStart to the /var wrapper path.
    install -d -m0755 "$STATE/bin"
    install -m0755 "$HERE/../bin/play-boot-sound" "$STATE/bin/play-boot-sound"
    sed 's#/usr/share/lava-chicken/bin/#'"$STATE"'/bin/#' \
      "$HERE/../systemd/lava-chicken-boot-sound.service" \
      > /etc/systemd/system/lava-chicken-boot-sound.service
    systemctl daemon-reload
    systemctl enable lava-chicken-boot-sound.service
    ;;
esac
plog "boot sound installed. Test: sudo systemctl start lava-chicken-boot-sound.service"
