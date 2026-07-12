# Installing Lava Chicken OS — a guide for parents

You have an old PC and kids who want to game, make YouTube videos, mod
Minecraft, and draw. This guide turns that PC into their machine: a
Steam-console-style gaming box that's also a video/art studio, with a friendly
on-box AI helper named **Nugget** — no subscriptions, no cloud accounts for the
kids, and you can check on the machine from your own laptop.

It's free and open source. Expect **about an hour or two**, most of it waiting.

> ⚠️ Only do this to an old computer that's headed for the trash — this process might turn it into a paperweight. But if you've got an old junker collecting dust, this can breathe a few more years of life into it. No warranty, no take-backs. Back up anything you care about first.

---

## First, pick your path

| | **Path A — Keep Windows** (recommended) | **Path B — All-in** |
|---|---|---|
| What happens | Windows stays; LaCOS installs alongside it. Kids get both worlds | The PC becomes 100% LaCOS |
| Good when | You still need Windows (Adobe apps, certain anti-cheat games) — most families | The PC is spare / you're done with Windows |
| Risk | Low, and reversible at every step | The chosen disk is erased |

Then pick the **vibe** — you can switch anytime later, so don't agonize:

- **Game console** (`:deck`) — power on → straight into Steam's Game Mode,
  exactly like a Steam Deck / SteamOS machine. Desktop is one menu away.
- **Desktop** (`:stable`) — power on → a normal desktop (KDE), with Steam and
  everything else a click away. Better if the box is homework-first.

Once LaCOS is on the box, switching is one friendly command — no tags or
registries to remember:

```bash
sudo lacos mode console    # Game-Mode boot, like a Steam Deck
sudo lacos mode desktop    # normal desktop boot
```

## What you need

- [ ] **The kids' PC** — with an **AMD graphics card** (most important thing),
      8 GB+ RAM, and either a spare disk or ~100 GB you can free up
- [ ] **A USB stick, 16 GB or bigger** — it gets erased
- [ ] **Your laptop** to make the stick (Mac instructions below; Windows too)
- [ ] **A free [GitHub](https://github.com) account** — this is the remote-access
      trick: the box pulls your account's *public* SSH keys at first boot, so
      *you* can log into it from your laptop to help. No passwords or secrets
      ever live in the installer
- [ ] Best-effort: an **ethernet cable** for first boot (it downloads the AI
      models, ~5 GB)

> **Not the project owner?** The prebuilt image ties remote access to the
> owner's GitHub account. Fork the repo and set one repository variable
> (`LAVA_GITHUB_USER` = your GitHub username) so the image builds for *your*
> keys — details in [docs/INSTALL-BAZZITE-IMAGE.md](docs/INSTALL-BAZZITE-IMAGE.md).
> Everything below works the same.

---

## Step 1 — Make the install stick

**Path A** wants a stock **Bazzite** ISO (the base OS; LaCOS layers on top in
Step 4). Download from [bazzite.gg](https://bazzite.gg) → Download → Desktop →
KDE → AMD/Intel.

**Path B** wants the **LaCOS installer ISO**: on the repo's
[Actions page](https://github.com/hartsock/lava-chicken-os/actions/workflows/build-image.yml),
open the newest green run on `main` and download the
`lava-chicken-os-installer` artifact (you need to be signed in to GitHub).
Releases also attach ISOs starting with v0.1.0.

### On a Mac

```bash
git clone https://github.com/hartsock/lava-chicken-os
cd lava-chicken-os
diskutil list external            # find your stick, e.g. disk4
scripts/make-usb.sh --iso ~/Downloads/<the>.iso --disk disk4
```

The script refuses internal disks and makes you type the disk name back before
it writes — read what it prints. (Prefer a GUI? [balenaEtcher](https://etcher.balena.io)
does the same job: pick ISO, pick stick, Flash.)

### On Windows

We're a Mac/Linux household, so this is by-the-book rather than by-experience —
apologies, and we hope it works smoothly for you: use
[Rufus](https://rufus.ie) — pick the ISO, pick the USB stick, keep the defaults
it suggests, press Start. balenaEtcher also works on Windows if Rufus looks
intimidating.

---

## Step 2 — Prepare the PC

### If you're keeping Windows (Path A), do this *inside Windows* first

1. **Check BitLocker** (disk encryption): Start → type "Manage BitLocker".
   If it's **On**, back up the recovery key (Microsoft account → "Recovery
   keys") before touching anything. Old no-TPM machines usually have it off.
2. **Make room**: Start → type "Disk Management" → right-click the big `C:`
   partition → **Shrink Volume** → free up **100 GB or more** (games are big).
   Leave the new space *unallocated* — don't format it.

### Firmware (both paths)

Reboot into the firmware/BIOS (usually mashing `Del`, `F2`, or `F12` at
power-on) and:

- **Disable Secure Boot**
- Know your **one-time boot menu key** (Dell `F12`, MSI `F11`, ASUS `F8`,
  Gigabyte `F12` — it's on the splash screen). You'll use it twice: once to
  boot the USB stick, and forever after to pick Windows when the kids let you.
- No TPM required — that's the point of using the old PC.

---

## Step 3 — Install

### Path A — alongside Windows

1. Plug in the stick, power on, hit the boot-menu key, pick the USB.
2. The Bazzite installer starts. When it asks about storage, choose
   **Custom / Manual partitioning** (Blivet-GUI). Then, carefully:
   - **Don't touch** the existing Windows partitions or the small
     "EFI System Partition".
   - In the **free space** you made, create two partitions: a **1 GB** one
     mounted at `/boot` (ext4), and the **rest** mounted at `/` (btrfs).
   - Select the *existing* EFI System Partition and set its mount point to
     `/boot/efi` — **do NOT check reformat**.
   - Unsure at any point? Stop and back out — nothing is written until you
     confirm the summary screen.
3. Create your (the parent's) user account when asked, then install and reboot
   (pull the stick).
4. **✅ Checkpoint — do this before anything else:** reboot again, hit the
   boot-menu key, pick **Windows**. It should start normally. (This exact
   flow — install into free space, Windows untouched — is what our CI proves
   with checksums on every nightly run, but trust-then-verify is the house
   style.)

### Path B — the whole PC

1. Boot the LaCOS installer stick the same way.
2. Follow the guided installer: pick the disk (**it will be erased**), create
   your parent account, install, reboot, pull the stick.
3. LaCOS is already baked in — skip to Step 5. Want the game-console vibe?
   After first boot: `sudo lacos mode console` and restart.

## Step 4 — Turn Bazzite into LaCOS (Path A only)

Log into the fresh Bazzite desktop, open a terminal (Konsole — it's in the
menu), and paste **one** of these (this is the only "raw" command in the whole
guide — plain Bazzite doesn't have our friendly tools yet):

```bash
sudo bootc switch ghcr.io/hartsock/lava-chicken-os:deck    # game console
#   ...or...
sudo bootc switch ghcr.io/hartsock/lava-chicken-os:stable  # desktop-first
systemctl reboot
```

From here on the box speaks parent: changed your mind about the vibe? It's
just `sudo lacos mode desktop` (or `console`). Want plain Bazzite back
entirely? `sudo bootc rollback`. It's that kind of reversible.

## Step 5 — First boot (the magic happens)

Leave it plugged into ethernet if you can and give it a few minutes. You'll
hear the **boot chime** 🐔, and behind the scenes it: pulls your GitHub keys
(remote access is live), starts the Nugget agent, and downloads the local AI
models (~5 GB — the one long wait).

**From your Mac**, prove the remote-access story:

```bash
ssh <your-username>@<the-box's-IP>     # your GitHub key just works, no password
lacos status                           # everything green? (also shows the boot mode)
lacos models                           # model download progress
```

(Find the IP in the box's network settings, or your router's device list.)

## Step 6 — Second boot: tell it about your family

On the box (or over SSH), run the friendly setup interview:

```bash
lacos setup
```

It asks simple questions — machine name? kids' usernames? Tailscale? home
DNS? — and skips anything you say no to. Kid accounts are **passwordless
click-to-switch** on the box, can't administrate anything, and are never
reachable from the network.

## Meet Nugget 🐔

Every user gets a **"nugget"** icon: their own AI helper, running entirely on
the box (local models — no cloud, no account, no data leaving the house). The
kids can ask it to *"get my recording ready for YouTube"* — it checks and
converts the video, then **hands the finished file back**. It never uploads,
never touches accounts, and can't get admin rights; publishing stays a
human's job, on purpose.

---

## Getting back to Windows

The **boot-menu key** at power-on always lists Windows (Path A). That's the
reliable way in — teach it to the kids.

## If something goes wrong

- **Windows won't boot after install** (shouldn't happen — see the Checkpoint):
  boot-menu key → Windows still missing? Boot the Windows recovery you have /
  Startup Repair. Then tell us — that's a serious bug we want to hear about.
- **Installer confused you** — backing out before the final confirmation
  changes nothing. Re-read Step 3 and try again.
- **No sound / no chime, models stuck, anything else** —
  [open an issue](https://github.com/hartsock/lava-chicken-os/issues); include
  `lacos status` output if you can get it.

## The safety fine print (for the security-minded parent)

Remote access is **key-only SSH** tied to *your* GitHub's public keys — no
passwords, nothing to phish. No secrets are baked into the image or this repo.
Kids' accounts hold no credentials and no admin rights; the AI helper runs as
whichever user launched it and inherits only their (non-admin) permissions.
The nightly test suite re-proves, with checksums, that our installer cannot
modify a neighboring Windows partition.
