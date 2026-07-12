#!/usr/bin/env bash
# L2 helper — fabricate the synthetic dual-boot target disk and fingerprint the
# neighbour BEFORE any install runs.
#
# Layout produced (GPT):
#   vda1  512 MiB  EFI System Partition (FAT32), seeded with a stand-in
#                  \EFI\Microsoft\Boot\bootmgfw.efi (the "Windows" loader)
#   vda2    8 GiB  "Basic data partition", filled with KNOWN random bytes — this
#                  is the NEIGHBOUR we prove is never modified
#   (tail)         unallocated FREE SPACE — where LaCOS is expected to install
#
# The neighbour is fingerprinted as the sha256 of the raw PARTITION DEVICE (not a
# file inside it), so ANY byte change anywhere in it is caught, no filesystem
# driver required. Nothing here ever points at a real disk — the disk is a fresh
# sparse file in the workspace.
#
# Usage: fabricate-neighbor-disk.sh <disk.raw>
# Writes fingerprints next to the disk: <disk>.neighbor.before / .esp-entry.before
# / .neigh-entry.before  and prints DISK=... / NEIGHBOR_BEFORE=... for the caller.
set -euo pipefail

DISK="${1:?usage: fabricate-neighbor-disk.sh <disk.raw>}"

echo "[fabricate] creating 40G sparse target disk at $DISK"
truncate -s 40G "$DISK"

# GPT: p1 ESP (ef00), p2 neighbour (0700 = Microsoft basic data), rest = free.
sgdisk -og "$DISK"
sgdisk -n 1:2048:+512M -t 1:ef00 -c 1:"EFI System Partition"  "$DISK"
sgdisk -n 2:0:+8G      -t 2:0700 -c 2:"Basic data partition"  "$DISK"

LOOP="$(sudo losetup -Pf --show "$DISK")"
echo "[fabricate] attached $LOOP (p1=ESP, p2=neighbour)"
cleanup() { sudo losetup -d "$LOOP" 2>/dev/null || true; }
trap cleanup EXIT

# ── Seed the ESP with a stand-in Windows loader ──────────────────────────────
sudo mkfs.vfat -F32 -n ESP "${LOOP}p1" >/dev/null
mnt="$(mktemp -d)"
sudo mount "${LOOP}p1" "$mnt"
sudo mkdir -p "$mnt/EFI/Microsoft/Boot"
# 1 MiB of known bytes standing in for bootmgfw.efi; its SURVIVAL is asserted.
sudo dd if=/dev/urandom of="$mnt/EFI/Microsoft/Boot/bootmgfw.efi" \
  bs=1M count=1 status=none
sudo sync
sudo umount "$mnt"
rmdir "$mnt"

# ── Fill the ENTIRE neighbour with KNOWN bytes and fingerprint it ────────────
# Fill to ENOSPC (drop `count`) so coverage is the WHOLE partition regardless of
# its size — a `count=$((SZ/4194304))` only covered a whole-4MiB multiple and
# would silently shrink coverage if the neighbour size ever became a non-multiple.
# The `|| true` swallows the expected ENOSPC at the end of the device.
SZ="$(sudo blockdev --getsize64 "${LOOP}p2")"
echo "[fabricate] filling entire neighbour (${SZ} bytes) with known random data"
sudo dd if=/dev/urandom of="${LOOP}p2" bs=4M status=none || true
sudo sync

BEFORE="$(sudo sha256sum "${LOOP}p2" | awk '{print $1}')"
echo "$BEFORE" > "${DISK}.neighbor.before"
# Snapshot the GPT entries too (catches a table-level move even if bytes match).
sgdisk -i 1 "$DISK" > "${DISK}.esp-entry.before"
sgdisk -i 2 "$DISK" > "${DISK}.neigh-entry.before"

echo "[fabricate] neighbour sha256 (before) = $BEFORE"
sudo losetup -d "$LOOP"; trap - EXIT
echo "DISK=$DISK"
echo "NEIGHBOR_BEFORE=$BEFORE"
