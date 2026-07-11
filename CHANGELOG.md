# Changelog

All notable changes to lava-chicken-os are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
this project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

We iterate `v0.0.1 → v0.0.99` during bring-up, then cut **v0.1.0** as the first
release we believe works end-to-end on real hardware of *both* bases (Bazzite +
SteamOS). See [docs/REMOTE-DAYZERO.md](docs/REMOTE-DAYZERO.md) for the design.

## [Unreleased]

### Added
- **Original boot chime + movie** ship as defaults — the owner's own
  `boot-sound.wav` (greeter-time ALSA) + `boot-movie.webm` (Steam Game Mode
  startup movie); Game Mode defaults to the movie so the chime doesn't clip it.
- **2nd-boot setup wizard** (#15) — `lacos setup` interviews the box ("Do you use
  Tailscale? A home DNS?") and configures name, admin keys, Tailscale, split-DNS,
  and streaming from the answers; non-secret answers persist to
  `/etc/lava-chicken/site.conf`; idempotent, whiptail TUI + `read` fallback, runs
  local or over SSH. Admin desktop launcher + a login nudge until done. Keeps the
  image generic and secret-free. See docs/SETUP-WIZARD.md.
- **Multi-user accounts** (#1) — kid users (`josiah`/`joshua`) created passwordless
  (click-to-switch), never in `wheel`/sudoers; admin = the OOBE primary user;
  SDDM autologins into a default kid session (KDE fast-user-switch to change).
  Configurable via `LAVA_KID_USERS` / `LAVA_AUTOLOGIN_USER`.
- **First-boot LLM model pre-load** (#2) — `lava-chicken-models.service` pulls
  `qwen2.5-coder:7b` + `nomic-embed-text` on first boot with progress (stamped on
  success, retries otherwise), so the agent is instant. Re-run/check with
  `lacos models`; override the set in `/etc/lava-chicken/models.conf`.

## [0.0.1] — bring-up

### Added
- **Day-zero remote access** — key-only SSH seeded from `github.com/<user>.keys`,
  Sunshine/Moonlight preserved and firewalled to LAN + WireGuard.
- **Bootc image pipeline** — custom Bazzite image built in GitHub Actions → GHCR,
  Anaconda install ISO artifact; SteamOS parity via first-boot `bootstrap.sh`.
- **Boot sound** — "Steve's Lava Chicken" plays at greeter time via a system
  ALSA service (desktop boots) plus the existing Steam startup movie (Game Mode).
- **`nugget` agent — one persona, two modes.** *Per-user:* a "nugget" desktop
  icon (every user) launches `newt --no-splash --full-access` **as that user**,
  in their own account — full newt tools bounded by the user's own permissions,
  so kids get a usable agent with **no path to root**. *Resident:* a dedicated
  `nugget` account runs a persistent tmux session for **remote admin**, attachable
  by **admins only** (`nugget-tui` = `wheel`); kids are kept out of that path
  until newt OCAP can make it safe. newt is installed to a shared dir so all
  users can run it.
- **newt-agent install** — pulls the latest GitHub release (`linux-x86_64`
  tarball) rather than building from source.
- **Nugget mascot + boot splash** — the flaming-nugget mascot
  (`assets/brand/nugget.png`) drives a Plymouth boot theme (`lava-chicken`) with
  a pre-rendered "Lava Chicken OS" title, and is the `nugget` account avatar
  (`.face` + AccountsService). Plymouth is baked on Bazzite; SteamOS is
  best-effort (read-only rootfs).
- **LaCOS branding + `lacos` command** — a single branded entrypoint
  (`lacos status | attach | agent … | version`), and os-release rebranded to
  "Lava Chicken OS (LaCOS)" so `neofetch` shows it (Bazzite image).
- **Configurable box name** — `LAVA_BOX_NAME` (default `nugget`) sets the
  hostname and the agent's presented identity (persona name + GECOS), e.g.
  `kajiblet`. The underlying Unix service account stays `nugget` in this pass;
  full account rename is a tracked follow-up.

### Security notes
- `nugget` uses a **propose-&-approve** sudo posture: the agent account has **no
  passwordless sudo and isn't in `wheel`** (locked password → it cannot `sudo` at
  all); privileged actions are proposed by the agent and run by a human. Full
  autonomous root is **deferred until newt OCAP** (newt-agent#1090). Per-user
  nugget instances inherit each user's own (unprivileged) permissions. Guardrails:
  sudo audit logging, systemd kill switch, ollama on loopback, `authorized_keys`
  root-owned (`hartsock` = public keys only; nothing shells out as him).
