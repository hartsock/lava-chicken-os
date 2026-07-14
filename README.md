<p align="center">
  <img src="assets/brand/nugget.png" alt="Lava Chicken OS — Nugget mascot" width="360">
</p>

<h1 align="center">Lava Chicken OS 🐔🌋</h1>

<p align="center"><b>A Gamer's OS.</b> &nbsp;·&nbsp; <code>LaCOS</code> for short.</p>

<p align="center">
Turn an old Windows 10 PC (no TPM required — Linux doesn't care) into a
Minecraft-themed SteamOS / Bazzite gaming + local-AI + mod-dev machine —
with <b>Nugget</b>, a resident AI agent living on the box.
</p>

> *"That's a Spicy Lava Chicken!"* — your PC, every boot.

> **👨‍👩‍👧‍👦 Parents: start here → [INSTALL.md](INSTALL.md)** — how to set this up
> for your kids, in plain English: keep Windows or go all-in, make the USB
> stick from your Mac (or Windows), and what the AI helper will and won't do.
> Already running? **[UPGRADING.md](UPGRADING.md)** — how to keep it updated
> (and roll back if an update ever misbehaves).

> ⚠️ Only do this to an old computer that's headed for the trash — this process might turn it into a paperweight. But if you've got an old junker collecting dust, this can breathe a few more years of life into it. No warranty, no take-backs. Back up anything you care about first.

## What you get

- **SteamOS 3.8+ or Bazzite** as the base OS (AMD GPU: both work; NVIDIA: Bazzite only)
- **Gaming Mode boot video with sound** — you supply your own copy of
  *Steve's Lava Chicken*, our script turns it into a Steam startup movie
- **Desktop login sound** (same audio, systemd user service)
- **Minecraft-style wallpapers** — bring your own, or generate original blocky
  art with the included script
- **[ollama](https://ollama.com)** baked into the image, loopback-only (models
  live in `/var`, surviving atomic updates); ROCm on supported AMD GPUs, CPU
  inference on older cards (e.g. Polaris)
- **[newt-agent](https://github.com/Gilamonster-Foundation/newt-agent)** —
  small, fast, local-first agentic coder, pointed at your local ollama
- **Minecraft Java Edition mod toolchain** — JDK 21, Gradle (via SDKMAN),
  Fabric + NeoForge templates, IntelliJ IDEA CE + Prism Launcher (Flatpak); Nugget
  has a **`modding`** skill that coaches a kid from first mod to writing their own
- **Wireless VR** — `lacos vr doctor` / `sudo lacos vr setup` open just the two
  ports ALVR needs (9943-9944), not the "open everything" hack; Nugget's
  **`vr-setup`** skill walks through SteamVR + ALVR (or the easier WiVRn) to a Quest
- **Nugget boot splash** — a Plymouth theme with the mascot and *Lava Chicken OS*
- **Nugget, your resident agent** — a dedicated on-box account running
  [newt-agent](https://github.com/Gilamonster-Foundation/newt-agent) in a
  persistent session; a **"nugget" icon on every desktop** attaches you to it
- **Day-zero remote access** — key-only SSH seeded from your GitHub account, plus
  Sunshine/Moonlight game streaming, ready from first boot
- **Bootc image** — Bazzite builds in GitHub Actions → GHCR with an install ISO;
  SteamOS gets the same setup via `bootstrap.sh`

## Will it run on your PC? (hardware)

LaCOS is for old hardware headed for the recycling pile, so the honest yardstick
is **the reference machine it's built and tested on — "Nugget":**

| Part | Nugget — the reference machine (verified working) |
|---|---|
| **CPU** | Intel Core i7-4790 — 4-core / 8-thread, 2014-era Haswell (any 64-bit x86) |
| **RAM** | 16 GB |
| **GPU** | AMD Radeon RX 580 (Polaris, Vulkan via RADV) |
| **Storage** | 512 GB SSD |
| **Firmware** | UEFI — **no TPM** (yes, the PCs Windows 11 rejects) |
| **Network** | Gigabit Ethernet (no Wi-Fi) |
| **Ports** | USB 3.0 |

**If your machine is in that ballpark or better, LaCOS runs.** Concretely:

**Minimum**
- **64-bit x86 CPU**, ~4 cores, roughly 2013 (Haswell / AMD equivalent) or newer.
- **16 GB RAM.** This is the real floor, not a suggestion: the on-box AI's 7B
  model wants ~6–8 GB *on top of* the desktop and a running game. 8 GB will boot
  but the AI will crawl and swap.
- A **Vulkan-capable GPU**. **AMD is the smooth path** (RX 580 and up work out of
  the box); NVIDIA works on the Bazzite base only.
- A **256 GB SSD or larger.** An SSD, not a spinning disk — the OS image, the AI
  models (~5 GB), and games need the speed and the room.
- **UEFI firmware. No TPM required** — that's rather the point.

**Recommended / good to know**
- More RAM (32 GB) and more cores make the **local AI** noticeably snappier — it
  runs on the **CPU** on Polaris-class cards. A ROCm-capable AMD GPU (RDNA or
  newer) accelerates it a lot.
- Keep the box on **wired Ethernet** — also ideal when it's the VR streaming host.
- A **USB 3 port** for the install stick and wired VR headsets.
- **Game Mode (`:deck`) black-screens on Polaris GPUs (RX 5xx)** today
  ([#38](https://github.com/hartsock/lava-chicken-os/issues/38)) — use the desktop
  `:stable` variant with Steam Big Picture on those cards.
- NVIDIA GPUs are supported on the **Bazzite** base, not SteamOS.

## ⚠️ Read this before touching a USB stick

This project **erases disks, replaces operating systems, and asks you to change
firmware settings**. Done carefully it's reversible at nearly every step — done
carelessly, **use of this software may turn your computer into a paperweight.**
Per the [MIT license](LICENSE) it ships with **NO WARRANTY** of any kind.

What we do about it: the installer path is tested nightly with byte-level
checksums against a synthetic Windows disk, every image boots in CI before it
ships, `bootc rollback` undoes an OS switch, and the firmware boot menu always
survives. What *you* do about it: **back up anything you love first**, read the
prompts before typing yes, and never point a disk-writing command at a drive
you haven't triple-checked. If something goes wrong,
[tell us](https://github.com/hartsock/lava-chicken-os/issues) — but the risk is
yours.

## Status — honest, per feature (v0.0.x)

This project versions `v0.0.1 → v0.0.99` until a fresh install delivers every
promise end-to-end; **v0.1.0 is that gate**. Where things stand after the first
real-hardware install (2026-07-12):

| Feature | Status |
|---|---|
| Bootc image + `:stable`/`:deck` variants, CI-built & signed | ✅ builds + boots, CI-verified (`:stable`) |
| `:deck` Game Mode on **Polaris GPUs** (RX 5xx) | 🚧 black screen — upstream gamescope bug ([#38](https://github.com/hartsock/lava-chicken-os/issues/38)); use Steam **Big Picture** on `:stable` meanwhile |
| Day-zero remote access (GitHub-key SSH) | ✅ **verified on hardware** |
| `lacos mode console\|desktop` switching | ✅ verified on hardware |
| Dual-boot safety (installer can't touch Windows) | ✅ proven nightly in CI (byte-checksums) |
| Resident agent + ollama | 🔧 fixed — ollama now baked ([#27](https://github.com/hartsock/lava-chicken-os/issues/27), [#28](https://github.com/hartsock/lava-chicken-os/issues/28)); re-verify on hardware |
| First-boot provisioning (accounts, persona, skills, wallpaper) | 🔧 fixed — was wedging on v0.0.1 ([#27](https://github.com/hartsock/lava-chicken-os/issues/27)); CI now requires convergence ([#29](https://github.com/hartsock/lava-chicken-os/issues/29)) |
| Setup wizard: kid accounts + Tailscale | 🔧 fixed ([#30](https://github.com/hartsock/lava-chicken-os/issues/30)) |
| Boot splash, chime, Game-Mode movie | 🔧 fixed ([#31](https://github.com/hartsock/lava-chicken-os/issues/31)); visible from next boot after update |
| SteamOS-base parity (`bootstrap.sh`) | 🚧 designed, never hardware-tested ([#13](https://github.com/hartsock/lava-chicken-os/issues/13)) |

If a fresh install disagrees with this table, that is a bug —
[tell us](https://github.com/hartsock/lava-chicken-os/issues).

## Quick start

1. Install the OS — parents/first-timers: **[INSTALL.md](INSTALL.md)**;
   deep dives: [docs/INSTALL-STEAMOS.md](docs/INSTALL-STEAMOS.md) /
   [docs/INSTALL-BAZZITE.md](docs/INSTALL-BAZZITE.md).
2. Boot to Desktop Mode, open a terminal:

   ```bash
   git clone https://github.com/hartsock/lava-chicken-os
   cd lava-chicken-os
   ./bootstrap.sh          # runs all steps; or run scripts/NN-*.sh individually
   ```

3. Drop your audio/wallpaper files into `assets/user/` when prompted
   (see [assets/user/README.md](assets/user/README.md)).
4. In Gaming Mode: **Settings → Customization → Startup Movie → Lava Chicken**.

## Design rules

- **Everything lives in `$HOME`.** SteamOS's root filesystem is read-only and
  wiped on atomic updates; we never touch it. This also means the same scripts
  work unmodified on Bazzite.
- **No copyrighted assets in this repo.** The song, movie clips, and official
  Mojang art are yours to supply locally. See [docs/LEGAL-ASSETS.md](docs/LEGAL-ASSETS.md).
- **Idempotent scripts.** Re-run anything safely.

## Repo layout

```
bootstrap.sh              entry point — detects OS, runs all steps
scripts/                  numbered, independently runnable steps
assets/user/              your local media (gitignored)
assets/generated/         wallpaper generator (original art only)
systemd/                  user units (login sound, ollama)
templates/                Fabric / NeoForge mod starter notes
docs/                     install guides, plan, legal notes
```

## Status

Pre-alpha. Built and tested against SteamOS 3.8 and Bazzite (KDE, AMD).

## License

MIT (code and docs only — media assets are never part of this repo).
