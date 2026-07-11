# Installing Bazzite on the PC

Bazzite is the better fit if you ever swap in an NVIDIA card, want dual-boot,
or want the `-dx` developer variant. No TPM needed.

1. https://bazzite.gg → **Download** → answer the picker:
   - Device: Desktop/PC
   - Desktop: KDE (matches SteamOS look; our wallpaper scripts assume Plasma)
   - GPU: AMD
   - Boot into: **Gaming Mode (steam)** for the console feel, or Desktop if
     this is primarily a dev box. The `-dx` variants add dev tooling.
2. Write ISO to USB (Fedora Media Writer/Etcher), boot it, install.
   Secure Boot: either disable it, or enroll the key when the installer offers
   (`ublue-os` key, password `universalblue`).
3. First boot → Desktop Mode → terminal → clone this repo → `./bootstrap.sh`.

## Bazzite niceties the scripts use when present

- `brew` (Homebrew) is preinstalled — used for ffmpeg/shell tools if missing.
- `ujust` recipes and Distrobox are preinstalled.
- Same $HOME-first install strategy as SteamOS, so nothing breaks on
  `rpm-ostree`/bootc updates.
