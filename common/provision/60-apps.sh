#!/usr/bin/env bash
# Queue the creative + gaming app install for first boot, in the background
# (issues #6/#7/#8). Root. Idempotent. Runs after the nugget agent is up.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common/provision/lib-provision.sh
source "$HERE/lib-provision.sh"

if [ "$(os_id)" != bazzite ]; then
  install -d -m0755 "$STATE/bin"
  install -m0755 "$HERE/../bin/lacos-install-apps" "$STATE/bin/lacos-install-apps"
  # the apps converge execs this sibling (MCreator isn't a Flatpak; #65)
  install -m0755 "$HERE/../bin/lacos-install-mcreator" "$STATE/bin/lacos-install-mcreator"
  # SteamOS has no baked /etc/lava-chicken/version — install it from the
  # checkout (repo root) or payload so the apps converge can version-key its
  # stamp instead of locking on "unknown" forever (#65). Re-provisioning from
  # a newer checkout bumps it, which re-arms one full converge.
  for v in "$HERE/../../VERSION" "$HERE/../VERSION"; do
    if [ -f "$v" ]; then install -D -m0644 "$v" /etc/lava-chicken/version; break; fi
  done
  sed 's#/usr/share/lava-chicken/#'"$STATE"'/#' \
    "$HERE/../systemd/lava-chicken-apps.service" \
    > /etc/systemd/system/lava-chicken-apps.service
  systemctl daemon-reload || true
fi
systemctl enable lava-chicken-apps.service 2>/dev/null || true
# Non-blocking: the multi-GB Flatpak install runs in the background on first boot.
systemctl start --no-block lava-chicken-apps.service 2>/dev/null \
  || pwarn "couldn't start app install — run 'lacos apps' later"

plog "creative apps queued (background install; check with 'lacos apps')"
