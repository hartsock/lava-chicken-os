---
name: create-usb-stick
description: Make a bootable USB install stick for Lava Chicken OS — help the user pick the right ISO (stock Bazzite for dual-boot, the LaCOS installer for a dedicated PC, or official SteamOS), download it, identify the USB stick SAFELY, and write it via scripts/make-usb.sh. Destructive operation — never picks a disk on its own.
argument-hint: "[bazzite|lacos|steamos] [--disk diskN]"
---

# /create-usb-stick — make an install stick, safely

You are helping someone (often a parent, not a sysadmin — see INSTALL.md's
audience) create a bootable USB stick. Writing an image **destroys everything
on the target disk**, so this skill is procedure-first and paranoid about disk
selection. The three hard rules:

1. **Never choose the target disk yourself.** List candidates, describe them
   (size, name, bus), and make the human name the disk.
2. **Never bypass the script's own confirmation.** `scripts/make-usb.sh` makes
   the user type the disk name back — do not wrap it in `yes |` or heredocs.
3. **Refuse internal disks**, even if asked. The script enforces this too.

## Step 1 — Which ISO? (ask, don't assume)

| They want | ISO | Where |
|---|---|---|
| Dual-boot: **keep Windows** on the kids' PC (most common — INSTALL.md Path A) | **stock Bazzite** (Desktop → KDE → AMD/Intel) | [bazzite.gg](https://bazzite.gg) download picker |
| Dedicate the whole PC to LaCOS (Path B) | **LaCOS installer** | latest green `build-image` run on `main` → artifact `lava-chicken-os-installer` (`gh run download` below), or the ISO attached to a GitHub Release (v0.1.0+) |
| Genuine **SteamOS** for a whole-disk AMD box | official **SteamOS 3.8+** | [store.steampowered.com/steamos](https://store.steampowered.com/steamos/) — note it's single-boot only (erases the drive) and AMD-GPU only |

If they answer "for the kids' PC and we're keeping Windows" → Bazzite. When in
doubt, walk them through INSTALL.md's "pick your path" table first.

Fetch commands you can run for them:

```bash
# LaCOS installer artifact (needs gh auth):
RID=$(gh run list --repo hartsock/lava-chicken-os --workflow build-image.yml \
      --branch main --status success --limit 1 --json databaseId --jq '.[0].databaseId')
gh run download "$RID" --repo hartsock/lava-chicken-os -n lava-chicken-os-installer -D ~/Downloads/lacos-iso
# (fork users: swap the repo)

# SteamOS: user downloads from the store page; if it arrives as *.img.bz2:
bunzip2 ~/Downloads/steamos-*.img.bz2     # make-usb.sh writes raw .img fine
```

Bazzite's picker is interactive — give the user the link and the three answers
(Desktop, KDE, AMD/Intel), then ask where the file landed.

Before writing, sanity-check the download: file exists, size is plausible
(Bazzite/LaCOS ISOs are several GB; a few-hundred-KB file is an error page).

## Step 2 — Find the stick (macOS primary; Linux below)

```bash
diskutil list external physical
```

Show the user the output. For each candidate confirm: size matches their stick
(16 GB stick ≈ "15.x GB"), and the description sounds right (e.g. "SanDisk").
**Ask them to confirm the diskN name.** If `external physical` lists nothing,
the stick isn't detected — stop and troubleshoot (try another port; some hubs
hide sticks).

If there's any hint the "stick" is actually a backup drive (hundreds of GB,
Time Machine volume names), stop and double-check with the user.

Linux: `lsblk -d -o NAME,SIZE,RM,TRAN,MODEL` — candidates have `RM = 1`.

Windows: don't drive disk writes from here — point the user at
[Rufus](https://rufus.ie) (pick ISO, pick stick, defaults, Start), per
INSTALL.md's Windows section.

## Step 3 — Write it

Always via the repo script (it re-verifies external/removable and requires the
typed confirmation):

```bash
scripts/make-usb.sh --iso <path-to-iso-or-img> --disk <diskN-they-confirmed>
```

The write takes several minutes for a multi-GB image (Ctrl-T shows progress on
macOS). When the script says done, the stick is ejected and ready.

## Step 4 — Hand off

Tell the user which INSTALL.md step is next:

- Bazzite stick → INSTALL.md **Step 2** (prepare the PC: BitLocker, shrink,
  firmware) then **Step 3 Path A**.
- LaCOS stick → INSTALL.md **Step 2** (firmware) then **Step 3 Path B**.
- SteamOS stick → it erases the whole target drive; that box loses Windows.
  Confirm they know, then it's Valve's installer from here.

## If make-usb.sh is unavailable

(e.g. the user only downloaded INSTALL.md): clone the repo first —
`git clone https://github.com/hartsock/lava-chicken-os && cd lava-chicken-os` —
or, as a last resort, guide them to balenaEtcher (GUI, cross-platform) rather
than hand-rolling `dd`. Do not improvise raw `dd` invocations for a lay user.
