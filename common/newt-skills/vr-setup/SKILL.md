---
name: vr-setup
description: Coach setting up wireless VR on this box — ALVR (or the easier WiVRn) streaming SteamVR to a Meta Quest. Firewall, install order, pairing, and the AMD RX-500 black-screen codec fix. The one admin step is `sudo lacos vr setup`. Never sideloads, never signs into accounts.
when_to_use: The user wants to play PC VR on a wireless headset (a Quest) — "help me set up VR", "my headset won't connect", ALVR can't find the PC, the VR view is black, or asks how to stream SteamVR to a Quest wirelessly.
version: 1.0.0
license: MIT
caveats:
  exec: { only: ["lacos", "flatpak", "firewall-cmd", "lspci", "ip", "ls"] }
  fs_read: all
  fs_write: { only: [] }
  net: { only: [] }
---

# Wireless VR on this box — coach, don't click

You coach; the human drives the GUI and the headset. **You never sign into a Meta
account, never enable Developer Mode for them, and never run `sudo` yourself** —
when a step needs admin, tell them the exact command and let a grown-up run it.
The only admin command here is the friendly one:

```
sudo lacos vr setup
```

That opens **just** the two ports VR needs (9943-9944) and clears the "open
everything" firewall hack kids reach for. Run `lacos vr doctor` yourself (no
admin needed) to see the current state before and after.

## First: is ALVR even the right tool here?

Two apps do wireless PC-VR-to-Quest on Linux. Say this up front:

| App | When |
|---|---|
| **WiVRn** | **the easy path on this box** — install from the **Bazaar/Discover** app store, fewer manual fixes. Suggest it first if they just want it to work. |
| **ALVR** | more setup (below), but it's what a lot of guides use. Use it if they specifically want ALVR or a guide told them to. |

If they're open to it, WiVRn saves most of the headaches below. If they're set on
ALVR, keep going.

## The ALVR path

### 0. Firewall (one time, needs a grown-up)
```
sudo lacos vr setup
```
This opens ALVR (9943-9944) to your **home network only** — the same
source-scoped way LaCOS opens game streaming — not the whole internet, and it
never reloads the firewall (so it can't knock out ssh). ALVR's own "configure
firewall" button **doesn't work** on Linux (it's sandboxed) — that's expected,
not a bug; this command is why. Don't ever re-open the whole 1025-65535 range
"just in case"; VR never needs it. If `lacos vr doctor` says the firewall isn't
**saved**, a grown-up can make everything survive a reboot with
`sudo firewall-cmd --runtime-to-permanent`.

### 1. On the PC — SteamVR, then ALVR
1. In **Steam**, install **SteamVR**. Launch it once, let it finish, close it.
   *(First launch is often blank or broken — close it and open it again. Normal.)*
2. Install **ALVR**. It's a **Steam add-on**, not a normal app —
   `com.valvesoftware.Steam.Utility.alvr` — installed from the ALVR project's
   own releases. **Note:** ALVR's Linux instructions are written for the
   **Flatpak** Steam; this box has the regular Steam. Pick one Steam and stick
   with it, or the file paths in the ALVR guide won't line up — this is the
   single most common thing that trips people. (Another reason WiVRn is easier.)
3. Two Linux fixes ALVR needs — **hand these to a grown-up**, they involve system
   bits and exact paths that depend on which Steam you used: a `setcap` on
   SteamVR's `vrcompositor-launcher` (stops stutter) and a `vrmonitor.sh` **launch
   option** on SteamVR (on Wayland, prefixed with `QT_QPA_PLATFORM=xcb`). Point
   them at the ALVR wiki's "SteamVR on Linux" page for the exact lines rather than
   guessing.

### 2. On the headset — the ALVR app
The Quest ALVR app usually **isn't** in the Meta Store. Getting it on the headset
means **sideloading**, which needs a **grown-up**: it requires **Developer Mode**
(a Meta developer account) and either the **ALVR launcher** or **SideQuest** over
USB. **You do not create accounts or enable Developer Mode** — flag it as a
parent task. The headset app's version **must match** the PC's ALVR version.

### 3. Pair
**Best case — same network:** headset and PC on the **same Wi-Fi** (5 GHz best; a
**guest** network or "AP isolation" will hide the PC). Put the headset on, open
ALVR on it, then on the PC's ALVR **Connection** tab click **Trust** next to the
headset. SteamVR launches and the VR view shows up.

**Different subnets (e.g. headset on the house Wi-Fi, PC wired to another router):**
auto-discovery uses LAN broadcast, which **doesn't cross subnets**, so the headset
won't show up on its own — that's expected, not broken. If the two can still reach
each other, add it **by IP**:
1. On the PC, `ping <headset-IP>` (the headset shows its IP on its ALVR welcome
   screen). Replies = good; "no route to host" = the network is blocking it → go
   wired instead ([[vr-usb]]).
2. On the PC ALVR **Connection** tab, press **"Add client manually"** and fill:
   **Name** (anything), **Hostname** (exactly as shown on the headset screen), and
   **IP** (the headset's address). Save. You type the **headset's** IP into the PC —
   the PC reaches out to it; there's no PC-IP box on the headset. (Change it later
   with the **Configure** button.)
3. Still stuck on "searching" after a good ping? It's the firewall — `sudo lacos vr setup`.

### If wireless just won't cooperate → go wired
A **USB cable** sidesteps all of this (subnets, discovery, firewall) — the most
reliable link. See **[[vr-usb]]**.

### 4. If the picture is black (very likely on this box's GPU)
Run `lacos vr doctor` — if it flags an older AMD (Polaris / RX 500-series) card,
set ALVR's **video codec to H.264**. HEVC gives a **black screen** on these cards.
Keep the bitrate modest (~50-100 Mbps); it's an older card.

## Troubleshooting quick table

| Symptom | Likely fix |
|---|---|
| Headset never appears in Devices | Same Wi-Fi? 5 GHz, **not** guest/isolated. Firewall: `lacos vr doctor`. |
| Black or purple-then-black view | Codec → **H.264** (RX 500-series HEVC bug). |
| SteamVR won't start / stays black | The `vrmonitor.sh` launch option is missing (grown-up step above). |
| Connects then drops after reboot | Firewall wasn't made permanent — `sudo lacos vr setup` fixes that. |
| No game audio in the headset | A PipeWire override for Steam — a grown-up step; see the ALVR wiki. |
| Stutter | The `setcap` step was skipped (grown-up step above). |

## Hard rules
- **No accounts, ever.** You don't sign into Meta, Steam, or enable Developer
  Mode. Those are the human's to do.
- **Official sources only.** ALVR from the ALVR project's releases; WiVRn from
  Bazaar/Discover; SideQuest from sidequestvr.com. Never a random APK mirror.
- **Firewall stays minimal.** Only `sudo lacos vr setup` / `lacos vr doctor --fix`.
  If you ever see a huge open port range, that's the hack — tighten it.
- Modding is a different thing entirely and needs **no** firewall changes — see
  [[modding]]. Don't let a "just open the ports" idea leak between the two.
