# Changelog

All notable changes to lava-chicken-os are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
this project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

We iterate `v0.0.1 → v0.0.99` during bring-up, then cut **v0.1.0** as the first
release we believe works end-to-end on real hardware of *both* bases (Bazzite +
SteamOS). See [docs/REMOTE-DAYZERO.md](docs/REMOTE-DAYZERO.md) for the design.

## [Unreleased]

## [0.0.1] — bring-up

### Added
- **Day-zero remote access** — key-only SSH seeded from `github.com/<user>.keys`,
  Sunshine/Moonlight preserved and firewalled to LAN + WireGuard.
- **Bootc image pipeline** — custom Bazzite image built in GitHub Actions → GHCR,
  Anaconda install ISO artifact; SteamOS parity via first-boot `bootstrap.sh`.
- **Boot sound** — "Steve's Lava Chicken" plays at greeter time via a system
  ALSA service (desktop boots) plus the existing Steam startup movie (Game Mode).
- **Resident `nugget` agent** — dedicated sudo-capable account (default hostname
  + user `nugget`) running newt-agent in a persistent tmux session; a system-wide
  "Talk to Nugget" launcher on every user's desktop attaches to it; the session
  auto-restarts (`newt --full-access --no-splash`) on `/end` or exit.
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
- `nugget` ships with `NOPASSWD:ALL` sudo (owner's explicit choice). Guardrails
  that coexist with that: sudo audit logging, a systemd kill switch, ollama bound
  to loopback, `authorized_keys` installed root-owned, remote-access config flagged
  immutable-to-nugget. These are speed bumps + observability, not containment;
  newt OCAP is the eventual real boundary (see newt-agent#1090).
