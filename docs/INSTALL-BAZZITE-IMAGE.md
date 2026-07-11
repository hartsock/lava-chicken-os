# Install the custom Bazzite image (day-zero, walk-away)

This is the **image** path — the "one and done" story. The install ISO is built
for you by GitHub Actions from your own fork; nothing is built on your laptop.
For the plain-Bazzite or SteamOS path, use `bootstrap.sh` instead
(see [INSTALL-BAZZITE.md](INSTALL-BAZZITE.md) / [INSTALL-STEAMOS.md](INSTALL-STEAMOS.md)).

## One-time setup (per fork)

1. Fork/own `github.com/<you>/lava-chicken-os`.
2. Set a repo **variable** `LAVA_GITHUB_USER` = the GitHub account whose public
   SSH keys should be allowed in (usually you). Repo → Settings → Secrets and
   variables → Actions → Variables. Defaults to the repo owner if unset.
3. Make sure that account has at least one SSH key
   (`https://github.com/<you>.keys` must return keys).

## Get the installer

- Push to `main` (or run the **build-image** workflow via *Run workflow*).
- The `build-image` job publishes `ghcr.io/<you>/lava-chicken-os:stable`.
- The `build-iso` job attaches a `lava-chicken-os-installer` artifact — download
  the `.iso`.
- Write it to a USB stick (Ventoy / Fedora Media Writer / Etcher).

## Install (sit down once)

1. BIOS: disable Secure Boot, USB first in boot order. No TPM needed.
2. Boot the USB → Anaconda installer.
3. Pick the disk, **create your user** — use your GitHub handle as the username
   if you want the box identity to match. Set a password (for local login;
   remote is key-only).
4. Reboot, remove USB. First boot runs `lava-chicken-firstboot.service`, which:
   - pulls `https://github.com/<LAVA_GITHUB_USER>.keys` → your `authorized_keys`,
   - enables key-only sshd,
   - enables + firewalls Sunshine (LAN + WireGuard `10.10.0.0/24`),
   - creates the dedicated `nugget` agent account (sudo), installs the latest
     newt release + persona, and starts its resident tmux session,
   - drops a system-wide **"nugget"** launcher on every user's desktop.
   Watch it: `journalctl -b -u lava-chicken-firstboot`.

## Walk away, then reconnect from any box on the network

```bash
ssh <you>@<box-ip>                          # key-only; your GitHub key just works
/usr/share/lava-chicken/bin/attach-nugget   # or click the "nugget" desktop icon
```

The first attach asks you to authenticate once (polkit), then joins the resident
agent's tmux session. Detach with `Ctrl-b d` — nugget keeps running. Off-switch:
`sudo nugget-agentctl {pause|disable|resume|status}`.

Moonlight: point it at `<box-ip>` (or `<box>.home.lab`), pair once with the PIN
shown in Sunshine's web UI at `https://<box-ip>:47990`.

## Updates

The image is bootc — updates arrive automatically via `bootc upgrade`
(rebased from `ghcr.io/<you>/lava-chicken-os:stable`, which CI rebuilds weekly
against the latest Bazzite base). `$HOME` and your provisioned state are
untouched by updates.

## What's baked vs. pulled

- **Baked into the image:** system packages, key-only sshd config, the shared
  payload under `/usr/share/lava-chicken`, the first-boot unit, and your public
  GitHub *username* (a handle, not a secret).
- **Pulled/created on first boot:** your SSH public keys (from GitHub), user
  services, newt persona in `~/.config`. No credentials ever live in the image
  or the repo.
