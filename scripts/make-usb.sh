#!/usr/bin/env bash
# make-usb.sh — write a boot stick for LaCOS hardware day. macOS + Linux.
#
#   scripts/make-usb.sh --lacos            # fetch the latest CI installer ISO, then write it
#   scripts/make-usb.sh --iso <path>       # write an ISO you already have (e.g. stock Bazzite)
#   scripts/make-usb.sh ... --disk disk4   # target device (bare name; see `diskutil list external`)
#
# WHICH ISO GOES ON THE STICK (see docs/INSTALL-DUALBOOT.md):
#   * Dual-boot box you are KEEPING WINDOWS on -> a STOCK Bazzite ISO (--iso ...),
#     install into free space interactively, then `bootc switch` to LaCOS.
#   * Wipeable/scratch box -> the LaCOS installer ISO (--lacos), the one-and-done path.
#
# Safety: refuses internal disks, requires the target to be explicitly named,
# and makes you type the disk name to confirm before a single byte is written.
set -euo pipefail

REPO="hartsock/lava-chicken-os"
ARTIFACT="lava-chicken-os-installer"

usage() { grep '^#' "$0" | sed -n '2,12p' | sed 's/^# \{0,1\}//'; exit 1; }

ISO="" DISK="" FETCH=0
while [ $# -gt 0 ]; do
  case "$1" in
    --lacos) FETCH=1 ;;
    --iso)   ISO="${2:?--iso needs a path}"; shift ;;
    --disk)  DISK="${2:?--disk needs a device name like disk4 or sdb}"; shift ;;
    -h|--help) usage ;;
    *) echo "unknown arg: $1"; usage ;;
  esac
  shift
done

# ── 1. Get the ISO ────────────────────────────────────────────────────────────
if [ "$FETCH" = 1 ]; then
  command -v gh >/dev/null || { echo "FAIL: gh CLI required for --lacos"; exit 1; }
  RID=$(gh run list --repo "$REPO" --workflow build-image.yml --branch main \
        --status success --limit 1 --json databaseId --jq '.[0].databaseId')
  [ -n "$RID" ] || { echo "FAIL: no successful build-image run found on main"; exit 1; }
  DL="${TMPDIR:-/tmp}/lacos-iso"
  echo "==> downloading artifact '$ARTIFACT' from run $RID (several GB — check disk space)"
  rm -rf "$DL"; mkdir -p "$DL"
  gh run download "$RID" --repo "$REPO" -n "$ARTIFACT" -D "$DL"
  ISO=$(find "$DL" -name '*.iso' | head -1)
fi
[ -n "$ISO" ] && [ -f "$ISO" ] || { echo "FAIL: no ISO (use --lacos or --iso <path>)"; usage; }
echo "==> ISO: $ISO ($(du -h "$ISO" | cut -f1))"

# ── 2. Pick + vet the target disk ─────────────────────────────────────────────
OS="$(uname -s)"
if [ -z "$DISK" ]; then
  echo; echo "No --disk given. Candidate targets:"
  if [ "$OS" = Darwin ]; then diskutil list external physical || true
  else lsblk -d -o NAME,SIZE,RM,TRAN,MODEL | awk 'NR==1 || $3==1'; fi
  echo; echo "Re-run with:  --disk <name>   (macOS: diskN, Linux: sdX)"; exit 1
fi

if [ "$OS" = Darwin ]; then
  info="$(diskutil info "$DISK")" || { echo "FAIL: no such disk $DISK"; exit 1; }
  # macOS versions disagree on which field they emit: older ones print
  # "Internal: No", newer ones "Device Location: External" and only a
  # "Removable Media:" line. Refuse anything positively internal, then REQUIRE
  # positive external/removable evidence from whichever field is present
  # (the old check keyed on "Internal: No" alone and fail-closed on sticks
  # whose diskutil output omits that line).
  if echo "$info" | grep -qE 'Device Location: +Internal|Internal: +Yes'; then
    echo "FAIL: $DISK is an INTERNAL disk — refusing. (diskutil info $DISK)"; exit 1
  fi
  echo "$info" | grep -qE 'Device Location: +External|Internal: +No|Removable Media: +(Removable|Yes)' \
    || { echo "FAIL: can't confirm $DISK is external/removable — refusing. (diskutil info $DISK)"; exit 1; }
  DEV="/dev/r$DISK"          # raw device: dramatically faster dd on macOS
  PLAINDEV="/dev/$DISK"
  # Pull identity fields for the human-readable summary below (macOS labels).
  get() { printf '%s\n' "$info" | grep -m1 "$1" | sed 's/^[^:]*: *//'; }
  D_NAME="$(get 'Device / Media Name')"
  D_SIZE="$(get 'Disk Size' | sed 's/ (.*//')"
  D_PROTO="$(get 'Protocol')"
  D_LOC="$(get 'Device Location')"
  D_REM="$(get 'Removable Media')"
  D_LAYOUT="$(get 'Content (IOContent)')"
  D_PARTS="$(diskutil list "$DISK" 2>/dev/null | sed '1,2d')"   # partitions/labels
else
  DEV="/dev/$DISK"; PLAINDEV="$DEV"
  [ -b "$DEV" ] || { echo "FAIL: $DEV is not a block device"; exit 1; }
  [ "$(cat "/sys/block/$DISK/removable" 2>/dev/null)" = 1 ] \
    || { echo "FAIL: /sys/block/$DISK/removable != 1 — refusing non-removable disk"; exit 1; }
  D_NAME="$(lsblk -dno MODEL "$DEV" 2>/dev/null | xargs)"
  D_SIZE="$(lsblk -dno SIZE "$DEV" 2>/dev/null | xargs)"
  D_PROTO="$(lsblk -dno TRAN "$DEV" 2>/dev/null | xargs)"
  D_LOC="External"; D_REM="Removable"
  D_LAYOUT="$(lsblk -dno PTTYPE "$DEV" 2>/dev/null | xargs)"
  D_PARTS="$(lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "$DEV" 2>/dev/null)"
fi

bus="$D_PROTO"; [ -n "$D_LOC" ] && bus="${bus:+$bus · }$D_LOC"; [ -n "$D_REM" ] && bus="${bus:+$bus · }$D_REM"
cat <<SUMMARY

  ==================================================================
   TARGET DISK — writing will COMPLETELY ERASE everything on it
  ==================================================================
   Disk      $DISK   ($PLAINDEV)
   Name      ${D_NAME:-(unknown)}
   Size      ${D_SIZE:-(unknown)}
   Bus       ${bus:-(unknown)}
   Layout    ${D_LAYOUT:-(none)}
   Writing   $(basename "$ISO")

   Currently on this disk (all of it will be gone):
$(printf '%s\n' "$D_PARTS" | sed 's/^/     /')

   >> Make sure this is your USB STICK — not an external hard drive
      or a backup. There is no undo.
  ==================================================================
SUMMARY
printf '\nIf %s is the RIGHT disk, type its name to erase it and write the image.\n' "$DISK"
printf 'Anything else cancels. Confirm disk name: '
read -r ans
[ "$ans" = "$DISK" ] || { echo "Cancelled — you typed '$ans'. Nothing was written."; exit 1; }

# ── 3. Write ──────────────────────────────────────────────────────────────────
if [ "$OS" = Darwin ]; then
  diskutil unmountDisk "$PLAINDEV"
  echo "==> writing (Ctrl-T for progress)..."
  sudo dd if="$ISO" of="$DEV" bs=4m
  sync
  diskutil eject "$PLAINDEV" || true
else
  sudo umount "${DEV}"* 2>/dev/null || true
  echo "==> writing..."
  sudo dd if="$ISO" of="$DEV" bs=4M status=progress conv=fsync
  sudo eject "$DEV" 2>/dev/null || true
fi
echo "==> done. Stick is ready — see docs/INSTALL-DUALBOOT.md (keep-Windows box)"
echo "    or docs/INSTALL-BAZZITE-IMAGE.md (wipeable box) for the install flow."
