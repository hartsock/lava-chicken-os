---
name: vr-usb
description: Coach a USB-cable (wired) ALVR connection between a Quest headset and this Bazzite PC — the rock-solid option that ignores WiFi/subnet problems entirely (everything rides 127.0.0.1 over the cable). Uses ALVR's built-in Wired Connection toggle; the only required admin step is a one-time udev rule. Never signs into any account.
when_to_use: Wireless VR won't connect (the headset can't find the PC, or they're on different WiFi/subnets), or the user wants the most reliable link — "connect the Quest by USB", "wired VR", ALVR over a cable, or anything about "USB debugging" / "adb" for VR. Sibling of [[vr-setup]] (wireless).
version: 1.0.0
license: MIT
caveats:
  exec: { only: ["lacos", "flatpak", "adb", "ls"] }
  fs_read: all
  fs_write: { only: [] }
  net: { only: [] }
---

# Wireless VR by USB cable — coach, don't click

You coach; the human drives the headset, the ALVR dashboard, and the one admin
command. **You never sign into a Meta account, never enable Developer Mode, never
run `sudo` yourself** — those are grown-up steps you hand over with the exact words.

## When to reach for USB

USB is the **rock-solid** path: the headset talks to the PC straight down the
cable over `127.0.0.1`, so **it does not care what WiFi or subnet anything is on**
— it sidesteps the whole "headset and PC are on different networks" problem. This
box is wired-only ethernet, which is exactly what ALVR wants for the PC side.

Try wireless first if it's easy ([[vr-setup]] — free, no cable, no Developer
Mode). Come here when wireless won't connect, or when you want the most reliable
link. The trade: a cable tethers the player, and a grown-up does a little one-time
setup.

## The one-time GROWN-UP setup (do these once)

1. **Developer Mode on the headset.** Only a grown-up, in the **Meta Horizon phone
   app**: tap the headset → **Headset Settings → Developer Mode → ON**, then reboot
   the headset. It needs a Meta account with 2FA (and a "developer organization").
   *You do not sign in or flip this — hand the tap-path to the grown-up.*
2. **One Linux permission rule (udev).** Linux blocks USB access by default, so
   *no* adb — not even the one ALVR bundles — can see the headset until this exists.
   Grown-up runs (Meta/Oculus USB vendor id is `2833`):
   ```
   sudo sh -c 'printf "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"2833\", MODE=\"0666\"\n" > /etc/udev/rules.d/50-oculus-meta.rules'
   sudo udevadm control --reload-rules && sudo udevadm trigger
   ```
   Then unplug and replug the headset. (No `plugdev` group and no `usermod` needed
   on this distro — `MODE="0666"` already grants access.)
3. **adb is usually NOT needed** — ALVR ships its own and forwards the ports for
   you. Only install a host adb if the fallback below is required.

## The KID steps

1. **Use a DATA cable — mind the catch.** Many USB cables are **charge-only**
   (power but no data), and a charge-only cable **will not work** — it's the #1
   reason wired VR fails. Use the cable that came with the headset, or one labeled
   **"USB 3" / "data."** Best of all for VR is a **"Y" cable (dual data + power)**:
   one leg sends data to the PC while the other takes **wall power**, so the
   headset keeps charging during long sessions instead of slowly draining on the
   PC port alone. Plug the *data* end into a blue USB-3 port if there is one.
2. **Put the headset ON.** A popup appears *inside the headset*: **"Allow USB
   debugging?"** Check **"Always allow from this computer"** and tap **Allow**.
   (Don't see it? Unplug, replug, look again with the headset on.)
3. On the PC open the **ALVR dashboard** (through Steam). Make sure SteamVR is
   installed and ALVR's setup wizard shows **green checks** first.
4. **Devices/Connection tab → turn ON "Wired Connection"** (ALVR v20.12+). A device
   at **`127.0.0.1`** appears → click **Trust / Connect**. ALVR runs its own adb and
   forwards the ports automatically.
5. Open the **ALVR app inside the headset** — it connects to `127.0.0.1` on its own.
   Put the headset on; SteamVR streams over the cable.

## If the Wired toggle sees nothing (GROWN-UP fallback)

Almost always it's the **cable** — swap to a known data cable first. If it still
sees nothing and a host adb is installed, authorize and forward the ports by hand
(**re-run after every replug/reboot** — the toggle normally does this for you):
```
adb devices                                        # headset should show as 'device', not 'unauthorized'
adb forward tcp:9943 tcp:9943 && adb forward tcp:9944 tcp:9944
```
If adb says "no permissions" after the udev rule: `adb kill-server && adb start-server`, then replug and re-accept the in-headset popup. Before the manual `127.0.0.1` connect, also set the headset's **Connection** settings: client discovery **OFF**, protocol **TCP**, WiFi still on; and check **Connection → "Wired Client Type"** matches how the ALVR app was installed (store build vs sideloaded apk) — a mismatch fails silently.

**Getting a host adb on Bazzite (only if truly needed):** don't install one if you
can help it (ALVR's bundled adb is enough). If you must: a **Distrobox** container
with `dnf install android-tools` is Bazzite's own no-reboot method, or download
Google's platform-tools zip. Layering (`rpm-ostree install android-tools`) needs a
reboot — last resort. **Do not** rely on `brew install android-platform-tools`; it's
a Homebrew cask that Homebrew-on-Linux often refuses — not a safe default.

## Gotchas

| Symptom | Fix |
|---|---|
| Wired toggle sees nothing / `adb devices` empty | **The cable** — most are charge-only. Use a USB-3 *data* cable (or a data+power "Y" cable). Then check the in-headset "Allow" popup. |
| Headset battery drains even while plugged in | Normal on PC-port power alone during heavy VR — use a **data+power "Y" cable** so the other leg feeds wall power. |
| Device shows "unauthorized" / "no permissions" | The udev rule (grown-up step 2), then replug and tap **Allow** in the headset. |
| Connects, but the headset view is **black** | Known **Bazzite + ALVR** issue (the flatpak is experimental; a SteamVR-on-Linux driver bug) — it can black-screen even with everything green. Set the codec to **H.264** (RX 500-series), and see ALVR's Linux troubleshooting wiki (SteamVR launch options). Not always leftover wizard items. |
| Client won't connect at all | Version mismatch — install the headset app **and** the PC streamer from the **same** github.com/alvr-org/ALVR release. |
| Manual `adb forward` stops working after unplugging | It's per-session — re-run it, or just use the Wired toggle (auto). |

## Hard safety rules

- **No accounts, ever.** You do not sign into Meta, enable 2FA, or flip Developer
  Mode — those are grown-up taps in the phone app.
- **Grown-up runs every `sudo`** (the udev rule) and the Developer-Mode toggle. Kid
  steps never need admin.
- **Official sources only** — ALVR from **github.com/alvr-org/ALVR/releases**, both
  ends from the *same* release. Never a random APK mirror.
- **Only connect the family's own devices.** The ALVR stream is unencrypted and a
  malicious client could drive the PC through SteamVR — don't leave the streamer
  running unattended, and never port-forward it to the internet.
- Wireless instead? That's [[vr-setup]]. The firewall bits there are `sudo lacos vr`;
  USB needs none of that (loopback is never firewalled).
