#!/usr/bin/env bash
# Boot splash, the ostree way (#31). Build-time `plymouth-set-default-theme -R`
# doesn't survive to real hardware (initramfs regen in the container doesn't
# take), so set the theme + enable local initramfs regeneration here. Takes
# effect from the NEXT boot (rpm-ostree stages a new deployment). Bazzite only;
# idempotent; bounded by firstboot's per-step timeout.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common/provision/lib-provision.sh
source "$HERE/lib-provision.sh"

[ "$(os_id)" = bazzite ] || { plog "not bazzite — skipping plymouth"; exit 0; }
have plymouth-set-default-theme || { pwarn "plymouth tooling missing"; exit 0; }
[ -d /usr/share/plymouth/themes/lava-chicken ] || { pwarn "lava-chicken theme not baked"; exit 0; }

cur="$(plymouth-set-default-theme 2>/dev/null || true)"
if [ "$cur" != lava-chicken ]; then
  plymouth-set-default-theme lava-chicken || pwarn "couldn't set plymouth theme"
fi
# Regenerate initramfs locally so the theme is actually IN it (staged; next boot).
if rpm-ostree initramfs 2>/dev/null | grep -qi 'Initramfs regeneration: enabled'; then
  plog "initramfs regeneration already enabled"
else
  rpm-ostree initramfs --enable 2>&1 | tail -1 || pwarn "couldn't enable initramfs regen"
fi
plog "splash: lava-chicken (visible from next boot)"
