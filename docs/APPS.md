# Apps on Lava Chicken OS

The creative + gaming stack installs on first boot (background) via
`lava-chicken-apps.service`, so every user — including the kids — gets it:
**system Flatpaks**, plus **MCreator** (not on Flathub — the official build
installs per-user, see below). The service re-converges once per image version,
so an app added to the default lineup reaches existing boxes on the next
upgrade + reboot — no manual step. Re-run or check with `lacos apps`; override
the Flatpak set in `/etc/lava-chicken/apps.conf`.

## What's installed

| Use | Apps | Notes |
|---|---|---|
| **Art** | Krita, GIMP, Inkscape | Krita is the strong native pick for digital art/painting |
| **Streaming / recording** | OBS Studio | AMD hardware encode via **VAAPI** (see below) |
| **Video editing** | Kdenlive, Shotcut | FFmpeg-based — native H.264/AAC in **and** out; the default for YouTube |
| **Minecraft** | Prism Launcher, MCreator | MCreator = visual mod maker (below); the code toolchain (JDK/Gradle) is in `scripts/60-modding-tools.sh` |
| **Games** | Steam | ships with Bazzite; AMD is first-class |

## 🧱 MCreator — mod making without (or with) code

[MCreator](https://mcreator.net/) isn't on Flathub, so it's the one default app
that doesn't install as a Flatpak. LaCOS installs the official self-contained
build (bundled JDK) **per user** into `~/Applications/MCreator` — it needs a
writable install dir — pinned and sha256-verified from the official MCreator
GitHub releases. Launch it from the menu (**MCreator**); mod workspaces live in
`~/MCreatorWorkspaces` and survive app refreshes. Accounts created after first
boot (kids added via `lacos setup`) get it automatically on their next boot; a
kid can also (re)install their own copy without an admin: `lacos mcreator`.
Heads-up: creating the first
workspace downloads the Gradle/NeoForge toolchain (several GB, needs network);
budget ~5–10 GB per active modder. It's a desktop IDE — desktop mode, not Game
Mode.

## 🅰️ Adobe — use the Windows side

**Adobe Creative Cloud (Photoshop, Illustrator, Premiere, Lightroom) has no Linux
build**, and Wine/Bottles is not reliable enough to hand a kid. If you need real
Adobe, **boot the Windows side** (this is a concrete reason the
[dual-boot](INSTALL-DUALBOOT.md) matters). For everyday work on Linux:
Krita/GIMP/Inkscape, or **Photopea** (browser, opens `.psd`, zero install).

## 🎬 Video editing — Kdenlive/Shotcut are the default (not DaVinci)

**DaVinci Resolve *free* on Linux cannot import or export H.264/H.265 (MP4/MOV)
and can't decode AAC at all** — which breaks the usual phone/OBS → YouTube
pipeline. Even paid Studio still lacks AAC on Linux, and an older AMD GPU may fall
outside ROCm and refuse Resolve's OpenCL. So **Kdenlive/Shotcut are the default**
— they handle H.264/AAC natively and export with VAAPI. Reserve Resolve for color
grading (install via `ujust install-resolve`) and transcode sources to DNxHR/WAV
first if you go that route.

## 📺 OBS hardware encode (AMD)

OBS on Linux has **no AMF encoder** (AMF is Windows-only in OBS). The AMD path is
**VAAPI** — we install the `gstreamer-vaapi` Flatpak runtime so "VAAPI H.264/H.265"
appears as an encoder. Very old AMD cards may only offer H.264 VAAPI (fine for
1080p YouTube); x264 CPU encode is always a fallback.
