# Apps on Lava Chicken OS

The creative + gaming stack installs as **system Flatpaks** on first boot
(background) via `lava-chicken-apps.service`, so every user — including the kids —
gets them. Re-run or check with `lacos apps`; override the set in
`/etc/lava-chicken/apps.conf`.

## What's installed

| Use | Apps | Notes |
|---|---|---|
| **Art** | Krita, GIMP, Inkscape | Krita is the strong native pick for digital art/painting |
| **Streaming / recording** | OBS Studio | AMD hardware encode via **VAAPI** (see below) |
| **Video editing** | Kdenlive, Shotcut | FFmpeg-based — native H.264/AAC in **and** out; the default for YouTube |
| **Minecraft** | Prism Launcher | mod dev toolchain (JDK/Gradle) is in `scripts/60-modding-tools.sh` |
| **Games** | Steam | ships with Bazzite; AMD is first-class |

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
