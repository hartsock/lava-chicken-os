#!/usr/bin/env bash
# Mint a synthetic "fake Windows" disk for the dual-boot rehearsal VM.
# macOS host only (uses hdiutil + diskutil). Layout:
#   [ real EFI System Partition ]  +  [ ExFAT "FAKEWIN" = stand-in Windows ]  +
#   [ unallocated FREE SPACE ]
# so you can rehearse "leave FAKEWIN + EFI alone, install into free space, reuse
# the EFI for /boot/efi" — the exact Blivet-GUI dance from docs/INSTALL-DUALBOOT.md.
# The image is SPARSE: it costs ~nothing until the VM writes to it.
set -euo pipefail

WORKDIR="${LACOS_VM_DIR:-$HOME/lava-chicken-vm}"
DISK_GB="${FAKEBOX_GB:-60}"
FAKEWIN_SIZE="${FAKEWIN_SIZE:-25G}"       # size of the stand-in "Windows" partition
PRISTINE="$WORKDIR/fakebox-pristine.raw"  # rehearse.sh resets from this each run
mkdir -p "$WORKDIR"

echo "[fakebox] creating ${DISK_GB}G sparse image at $PRISTINE ..."
rm -f "$PRISTINE"
dd if=/dev/zero of="$PRISTINE" bs=1 count=0 seek=$(( DISK_GB * 1024 * 1024 * 1024 )) 2>/dev/null

DEV="$(hdiutil attach -nomount -imagekey diskimage-class=CRawDiskImage "$PRISTINE" | head -1 | awk '{print $1}')"
cleanup() { hdiutil detach "$DEV" >/dev/null 2>&1 || true; }
trap cleanup EXIT
echo "[fakebox] attached $DEV; partitioning (auto-EFI + FAKEWIN + free space)..."

# diskutil auto-adds a real EFI System Partition first; a trailing "Free Space"
# entry fills the remainder as UNALLOCATED (that's where you'll install).
diskutil partitionDisk "$DEV" GPT \
  ExFAT FAKEWIN "$FAKEWIN_SIZE" \
  "Free Space" gap 1G >/dev/null

diskutil list "$DEV" | sed -n '1,10p'
cleanup; trap - EXIT
echo "[fakebox] ready. Rehearse with: test/dualboot-vm/rehearse.sh"
