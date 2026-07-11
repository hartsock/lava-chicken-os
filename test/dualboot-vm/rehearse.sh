#!/usr/bin/env bash
# Boot the Bazzite installer in a VM against the synthetic "fake Windows" disk, to
# rehearse the dual-boot partitioning safely. macOS + QEMU host.
#
# The M4 is arm64 and Bazzite is x86_64, so this runs under EMULATION (no hardware
# acceleration) — expect it to be SLOW (multi-minute boots, sluggish UI). That's
# fine for rehearsing the Blivet-GUI clicks a few times.
#
# Each run RESETS the fake disk from the pristine copy, so you can practice
# repeatedly. When Anaconda's storage screen appears, pick "Advanced Custom
# (Blivet-GUI)" and rehearse: leave FAKEWIN + EFI alone, install into free space.
set -euo pipefail

WORKDIR="${LACOS_VM_DIR:-$HOME/lava-chicken-vm}"
ISO="${BAZZITE_ISO:-$WORKDIR/bazzite-stable-amd64.iso}"
PRISTINE="$WORKDIR/fakebox-pristine.raw"
WORK="$WORKDIR/fakebox.raw"
VARS="$WORKDIR/OVMF_VARS.fd"
CODE="${OVMF_CODE:-/opt/homebrew/share/qemu/edk2-x86_64-code.fd}"
VARS_TMPL="${OVMF_VARS_TMPL:-/opt/homebrew/share/qemu/edk2-i386-vars.fd}"

command -v qemu-system-x86_64 >/dev/null || { echo "qemu missing: brew install qemu" >&2; exit 1; }
[ -r "$ISO" ]      || { echo "Bazzite ISO not found at $ISO (still downloading?)" >&2; exit 1; }
[ -r "$PRISTINE" ] || { echo "fake disk missing — run: test/dualboot-vm/make-fakebox.sh" >&2; exit 1; }
[ -r "$CODE" ]     || { echo "OVMF firmware not found at $CODE" >&2; exit 1; }

echo "[rehearse] resetting fake disk from pristine (APFS clone = instant)..."
rm -f "$WORK"; cp -c "$PRISTINE" "$WORK" 2>/dev/null || cp "$PRISTINE" "$WORK"
cp -f "$VARS_TMPL" "$VARS"

echo "[rehearse] launching VM — emulated x86_64, EXPECT IT TO BE SLOW. Close the"
echo "           window to end. Re-run this script to reset and rehearse again."
exec qemu-system-x86_64 \
  -machine q35 -accel tcg -m 4096 -smp 4 \
  -drive if=pflash,format=raw,readonly=on,file="$CODE" \
  -drive if=pflash,format=raw,file="$VARS" \
  -drive file="$WORK",format=raw,if=virtio,cache=writeback \
  -cdrom "$ISO" \
  -boot menu=on \
  -vga virtio -display cocoa \
  -device usb-ehci -device usb-tablet \
  -name "LaCOS dual-boot rehearsal"
