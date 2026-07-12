#!/usr/bin/env bash
# L2 helper — THE PROOF. After an install has run against the synthetic disk,
# assert (a) the neighbour partition is byte-identical to before, AND (b) the
# install actually happened (so a no-op / failed install cannot false-PASS the
# "neighbour unchanged" check).
#
# Usage: verify-neighbor-untouched.sh <disk.raw> <mode>
#   mode = anaconda   the full Anaconda/kickstart install (Layer B) ran; new
#                     partitions were created by the installer in the free space.
#   mode = bootc      `bootc install to-filesystem` (Layer C) ran into a btrfs
#                     partition WE pre-created (vda3) in the free space.
#
# EXIT CODES (the caller distinguishes a SAFETY regression from an infra flake):
#   0  neighbour untouched AND LaCOS provably landed in the free space.
#   2  SAFETY VIOLATION — the neighbour bytes / its GPT entry / the seeded
#      Windows loader changed. This is the regression L2 exists to catch; the
#      caller MUST fail hard and NEVER retry (a retry could hide a flaky/
#      intermittent neighbour corruption).
#   3  INSTALL INCOMPLETE — neighbour is fine but there is no positive evidence
#      LaCOS installed (no new partition, no ostree payload). Looks like the
#      install never ran; the caller MAY retry this as an infrastructure flake.
#
# Reads the fingerprints written by fabricate-neighbor-disk.sh:
#   <disk>.neighbor.before  <disk>.esp-entry.before  <disk>.neigh-entry.before
set -uo pipefail

DISK="${1:?usage: verify-neighbor-untouched.sh <disk.raw> <anaconda|bootc>}"
MODE="${2:?mode: anaconda|bootc}"

BEFORE="$(cat "${DISK}.neighbor.before")"

# Two independent failure classes. A SAFETY violation always wins over an
# install-incomplete verdict.
SAFETY=0     # neighbour/ESP-loader/GPT changed  -> exit 2, never retry
INCOMPLETE=0 # no evidence the install landed     -> exit 3, retryable
safety()     { echo "SAFETY-FAIL: $*" >&2; SAFETY=1; }
incomplete() { echo "INSTALL-INCOMPLETE: $*" >&2; INCOMPLETE=1; }

LOOP="$(sudo losetup -Pf --show "$DISK" || true)"
[ -n "$LOOP" ] || { echo "INSTALL-INCOMPLETE: could not attach $DISK via losetup (infra)" >&2; exit 3; }
mnt="$(mktemp -d)"
mnt2="$(mktemp -d)"
cleanup() {
  sudo umount "$mnt" 2>/dev/null || true
  sudo umount "$mnt2" 2>/dev/null || true
  sudo losetup -d "$LOOP" 2>/dev/null || true
  rmdir "$mnt" "$mnt2" 2>/dev/null || true
}
trap cleanup EXIT
sudo udevadm settle 2>/dev/null || true
echo "[verify] re-attached $DISK as $LOOP"
sgdisk -p "$DISK" || true

# ── 1. THE NEIGHBOUR MUST BE BYTE-IDENTICAL (safety) ──────────────────────────
AFTER="$(sudo sha256sum "${LOOP}p2" | awk '{print $1}')"
if [ "$BEFORE" = "$AFTER" ]; then
  echo "PASS: neighbour partition unchanged ($AFTER)"
else
  safety "neighbour partition MODIFIED: $BEFORE -> $AFTER"
fi

# ── 2. The GPT entries for ESP + neighbour must not have moved/resized (safety)
if diff -u "${DISK}.esp-entry.before" <(sgdisk -i 1 "$DISK") >/dev/null; then
  echo "PASS: ESP GPT entry unchanged"
else
  safety "ESP GPT entry changed (partition moved/resized)"
fi
if diff -u "${DISK}.neigh-entry.before" <(sgdisk -i 2 "$DISK") >/dev/null; then
  echo "PASS: neighbour GPT entry unchanged"
else
  safety "neighbour GPT entry changed (partition moved/resized)"
fi

# ── 3. The seeded Windows loader must have SURVIVED (removal = safety) ─────────
# (The ESP itself is EXPECTED to change — LaCOS writes \EFI\fedora next to it — so
#  we assert survival + addition, NOT byte-equality of the ESP.)
if sudo mount "${LOOP}p1" "$mnt" 2>/dev/null; then
  if sudo test -f "$mnt/EFI/Microsoft/Boot/bootmgfw.efi"; then
    echo "PASS: Windows EFI loader (\\EFI\\Microsoft\\...\\bootmgfw.efi) survived"
  else
    safety "Windows EFI loader was REMOVED from the ESP"
  fi
  echo "[verify] ESP contents:"; sudo ls -R "$mnt/EFI" 2>/dev/null || true
  if sudo ls "$mnt/EFI" 2>/dev/null | grep -Eiq 'fedora|BOOT'; then
    echo "PASS: a LaCOS/bootc loader was added to the ESP"
  else
    # A missing LaCOS loader is NOT a neighbour-safety problem — it means the
    # install did not finish. Classify by mode: fatal-as-incomplete for Anaconda
    # (which must write the loader), tolerated for bootc to-filesystem (bootupd
    # may defer the ESP write; the ostree-payload check below is the real proof).
    if [ "$MODE" = anaconda ]; then
      incomplete "no LaCOS loader added to the ESP (Anaconda install did not complete?)"
    else
      echo "WARN: no LaCOS loader dir seen in ESP (mode=bootc; bootupd may not have written one)"
    fi
  fi
  sudo umount "$mnt"
else
  # The ESP is a fixture we created; if it will not mount, something corrupted it.
  safety "could not mount the ESP (${LOOP}p1) — the fixture ESP appears damaged"
fi

# ── 4. ANTI-FALSE-PASS: LaCOS must ACTUALLY have landed in the free space ─────
# A failed / no-op install leaves the neighbour trivially unchanged and would
# false-PASS check 1. Require POSITIVE evidence that a real ostree deployment
# exists on a btrfs root in the free-space partitions (p3+). This is the check
# that makes both layers load-bearing:
#   * Anaconda (Layer B): the installer creates the partition AND writes ostree.
#   * bootc (Layer C): the HARNESS pre-creates the btrfs, so a bare "btrfs
#     present" / "partition count > 2" would be tautological — only an ostree
#     payload proves BOOTC itself wrote something (not the harness).
NPARTS="$(sgdisk -p "$DISK" | grep -cE '^[[:space:]]+[0-9]+' || true)"
echo "[verify] partition count now: $NPARTS (was 2)"
if [ "$MODE" = anaconda ] && [ "${NPARTS:-0}" -le 2 ]; then
  incomplete "no new partition beyond ESP+neighbour — Anaconda install appears to be a no-op"
fi

FOUND_OSTREE=0
for p in "${LOOP}"p3 "${LOOP}"p4 "${LOOP}"p5; do
  [ -e "$p" ] || continue
  sudo blkid "$p" 2>/dev/null | grep -q 'TYPE="btrfs"' || continue
  # Mount the btrfs TOP LEVEL (subvolid=5), not the default subvolume: Anaconda
  # deploys into a SUBVOLUME (root/ostree/...), so a plain top-level `test -d
  # /ostree` misses a successful install (runs 2/4 may have false-failed here).
  if sudo mount -o subvolid=5 "$p" "$mnt2" 2>/dev/null; then
    echo "[verify] $p top-level tree (subvolid=5, depth 2):"
    sudo find "$mnt2" -maxdepth 2 -print 2>/dev/null | head -30
    OSTREE_DIR="$(sudo find "$mnt2" -maxdepth 3 -type d -name ostree 2>/dev/null | head -1)"
    if [ -n "$OSTREE_DIR" ]; then
      echo "PASS: ostree deployment payload present on $p at ${OSTREE_DIR#"$mnt2"/} (LaCOS actually landed)"
      FOUND_OSTREE=1
    fi
    # Post-mortem: if anaconda copied its logs to the target, harvest them for
    # the workflow's artifact (var/log/anaconda may live inside a subvolume).
    ALOG="$(sudo find "$mnt2" -maxdepth 5 -type d -path '*var/log/anaconda' 2>/dev/null | head -1)"
    if [ -n "$ALOG" ]; then
      mkdir -p ./anaconda-target-logs
      sudo cp -r "$ALOG"/. ./anaconda-target-logs/ 2>/dev/null || true
      sudo chown -R "$(id -u):$(id -g)" ./anaconda-target-logs 2>/dev/null || true
      echo "[verify] harvested target-side anaconda logs -> ./anaconda-target-logs"
    fi
    sudo umount "$mnt2" 2>/dev/null || true
  fi
  [ "$FOUND_OSTREE" = 1 ] && break
done
if [ "$FOUND_OSTREE" != 1 ]; then
  if [ "$MODE" = bootc ]; then
    incomplete "bootc wrote NO ostree deployment into the target btrfs (no-op install?) — the pre-created partition is not proof by itself"
  else
    incomplete "no ostree deployment found on any free-space btrfs (Anaconda install did not complete?)"
  fi
fi

# ── verdict ──────────────────────────────────────────────────────────────────
if [ "$SAFETY" = 1 ]; then
  echo "----- L2 SAFETY VIOLATION: neighbour was NOT preserved -----" >&2
  echo "final partition table:" >&2; sgdisk -p "$DISK" >&2 || true
  sudo blkid "${LOOP}"p* 2>/dev/null >&2 || true
  exit 2
fi
if [ "$INCOMPLETE" = 1 ]; then
  echo "----- L2 INCONCLUSIVE: neighbour intact, but no proof LaCOS installed -----" >&2
  echo "final partition table:" >&2; sgdisk -p "$DISK" >&2 || true
  sudo blkid "${LOOP}"p* 2>/dev/null >&2 || true
  exit 3
fi
# COMPLETION SENTINEL — the caller greps for 'L2 PASS'; an empty/truncated copy
# of this script exits 0 without emitting it and must NOT be treated as a pass.
echo "L2 PASS ($MODE): neighbour untouched + LaCOS ostree payload present in free space"
