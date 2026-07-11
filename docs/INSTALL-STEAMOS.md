# Installing official SteamOS 3.8+ on the PC

Requirements: **AMD GPU** (NVIDIA is not supported by official SteamOS yet),
one dedicated disk (the installer formats the whole drive), UEFI boot.
No TPM needed.

1. Download the SteamOS installer image from Valve:
   https://store.steampowered.com/steamos — pick the generic PC/recovery image.
2. Write it to a ≥8 GB USB stick (Balena Etcher, Rufus, or `dd`).
3. BIOS/UEFI: disable Secure Boot, enable UEFI boot, put USB first.
4. Boot the stick → choose **Install SteamOS** (wipes the disk).
5. First boot: connect network, let it update, complete Steam login.
6. Switch to Desktop Mode (power menu), open Konsole:
   ```bash
   passwd                      # set a user password (needed for sudo)
   ```
7. Clone this repo and run `./bootstrap.sh`.

## SteamOS quirks the scripts already handle

- Root filesystem is **read-only** and replaced on updates. Everything we
  install goes to `$HOME` (Flatpak --user, SDKMAN, cargo, ollama tarball,
  systemd user units). Don't `steamos-readonly disable` — you don't need it.
- No compilers on the host → newt-agent is built inside a **distrobox**
  container; only the finished binary lands in `~/.local/bin`.
- If `distrobox`/`podman` are missing on your build, the script tells you and
  offers the Flatpak/brew alternates.
