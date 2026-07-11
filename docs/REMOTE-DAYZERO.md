# Day-zero remote access + resident agent

Design for the "clean USB stick → sit down once → walk-away with a machine I can
SSH into and stream from" story, plus a resident newt-agent persona that
permanently lives on the box.

> **Revision 2026-07-11b — supersedes the "Resident newt persona" section below.**
> The resident agent now runs as a **dedicated `nugget` account** (default
> hostname + username `nugget`), **separate** from the human login, and it **has
> sudo** for sysadmin. Persona defaults: *do no harm; ask frequently before
> acting; teach rather than do; act as monitor/mentor.* A persistent **tmux
> session** holds its conversational window, opened by a **button** (KDE launcher
> + Steam Gaming Mode shortcut) that attaches over a shared socket — the human
> does not need root each time. Boot sound target: **earliest reliable, both
> modes** (Steam startup movie for Game Mode + a system sound service at the
> greeter for desktop). Versioning: **v0.0.1 → v0.0.99 → v0.1.0** when it works.
> Exact mechanisms (sysusers vs first-boot useradd; sudoers policy; socket perms;
> boot-sound ordering) are being pinned by research/verify workflow `wf_334f61fb`
> — this section is updated once that lands.
>
> **Refinements (2026-07-11c):**
> - **Launcher is system-wide / all users** — `/usr/share/applications/nugget.desktop`
>   (baked in image; system path on SteamOS), labeled "nugget". Every user's
>   desktop/menu shows it.
> - **All users can attach** to nugget's tmux (shared socket, group = all human
>   users). Blast radius acknowledged; security verifier is weighing it.
> - **Resident command = `newt --full-access --no-splash`** in a respawn loop
>   that RESTARTS whenever newt exits — including the `/end` command or the user
>   leaving the screen. The session never dies. ⚠️ `--full-access` removes newt's
>   OWN permission gating, so with nugget's sudo the *only* in-agent brake is the
>   persona — making the prompt-INDEPENDENT OS guardrails (restricted sudoers,
>   remote-access config immutable-to-nugget, systemd kill switch, audit log)
>   the real safety layer, not optional. Loop needs crash-backoff so a failing
>   newt doesn't busy-spin. (`--full-access`/`--no-splash` are owner-specified
>   flags — VERIFY against the installed newt.)
>   **Roadmap:** `--full-access` is a deliberate TEMPORARY escape hatch until
>   newt's OCAP (object-capability) work matures; it will eventually be
>   deprecated to a no-op ("OCAP is mature enough; this flag does nothing"). We
>   pass it UNCONDITIONALLY so that deprecation needs no change here. The OS
>   guardrails below are the interim safety layer AND remain worthwhile post-OCAP
>   — OCAP confines what *newt* can do; sudoers/immutability confine what the
>   *nugget OS account* can do (a different boundary). See newt OCAP wave.
> - **newt install = pull latest RELEASE, not source build.** Public repo
>   `Gilamonster-Foundation/newt-agent`, no token needed. `releases/latest` asset
>   convention (confirmed 2026-07-11): `newt-agent-v<VER>-linux-x86_64.tar.gz`
>   (use this → `~nugget/.local/bin`), plus `.rpm`/`.deb`/Homebrew `newt.rb`.
>   Owner is cutting a fresh release from main so latest == top of tree.
>   **First target release: v0.7.2** (in flight; latest was v0.7.1).
> - **v0.1.0** = the release cut once we believe it works as intended (burn-down
>   target from v0.0.x).

Decisions locked (2026-07-11):

- **Delivery:** custom **bootc image** for Bazzite, built in **GitHub Actions →
  GHCR**; **first-boot bootstrap** parity path for SteamOS. Same end state,
  two triggers.
- **Base OS parity:** Bazzite and SteamOS both reach the same end state.
- **Provisioning source:** your GitHub account — public keys from
  `https://github.com/<user>.keys`, username as the box identity.
- **Remote desktop:** preserve Sunshine/Moonlight, firewalled into the existing
  homelab scheme (LAN + WireGuard `10.10.0.0/24`, split-DNS `home.lab`).
- **Newt:** persona **+** resident systemd user service **+** SSH remote
  entrypoint (no extra network port).

---

## The parity principle

There is exactly **one payload** and **one set of provisioning scripts**. Only
the *trigger* differs per base OS:

| Layer | What | Bazzite | SteamOS |
|---|---|---|---|
| **System layer** | sshd config, Sunshine, firewall, packages, payload under `/usr/share/lava-chicken`, first-boot unit | baked into the bootc **image** at CI build time | applied by `bootstrap.sh` (writes to `/etc`, which persists on SteamOS) |
| **`$HOME` layer** | `~/.ssh/authorized_keys`, newt persona in `~/.config`, user systemd services | applied by a **first-boot service** the image ships | applied by `bootstrap.sh` on first run |
| **Provisioning logic** | `common/provision/*.sh` | called by the first-boot unit | called by `bootstrap.sh` |

Why the `$HOME` split: an image has no `$HOME` — the user account doesn't exist
until first boot (OOBE on Bazzite, `deck` on SteamOS). So `$HOME`-scoped state
(SSH keys, user services, `~/.config/newt`) is *always* provisioned on the
running machine, never baked. This is also why the existing `$HOME`-first design
rule survives intact.

```
USB (Bazzite ISO from CI)                USB (SteamOS recovery)
        │                                        │
   Anaconda OOBE: create user               OOBE: `deck` user
        │                                        │
   first boot → lava-chicken-firstboot.service   first boot → `./bootstrap.sh`
        │                                        │
        └──────────────┬─────────────────────────┘
                       ▼
         common/provision/*.sh  (identical)
         ├─ 10-ssh-github.sh   keys + sshd
         ├─ 20-sunshine.sh     enable + firewall
         └─ 30-newt-persona.sh persona + service + entrypoint
```

---

## Repo layout (added by this work)

```
.github/workflows/build-image.yml   CI: build bootc image → GHCR, build install ISO
bazzite/
  Containerfile                     FROM ghcr.io/ublue-os/bazzite:stable, layer payload
  build.sh                          image-build steps (run inside Containerfile)
  system_files/                     files copied verbatim into the image rootfs
    usr/share/lava-chicken/         the shared payload (mirror of common/)
    usr/lib/systemd/system/lava-chicken-firstboot.service
    etc/ssh/sshd_config.d/10-lava-chicken.conf
  image.toml                        bootc-image-builder config (ISO/user defaults)
common/                             SINGLE SOURCE OF TRUTH (consumed by both paths)
  provision/
    lib-provision.sh                github keys, hostname, primary-user detection
    10-ssh-github.sh                pull keys → authorized_keys; enable/harden sshd
    20-sunshine.sh                  enable Sunshine; open firewall (LAN + WG)
    30-newt-persona.sh              install persona; enable service; install entrypoint
  persona/
    lava-chicken.persona.md         the OS-level persona (system prompt)
    newt.config.toml                newt config: ollama endpoint, model, persona ref
  sunshine/
    apps.json                       Sunshine app entries (Desktop, Steam Big Picture)
    ports.env                       canonical port list (from the gnuc runbook)
  systemd/
    newt-agent.service              resident newt daemon (user service)
  bin/
    newt-box                        SSH remote entrypoint → attach to resident persona
scripts/
  00-remote-access.sh              SteamOS/first-run wrapper → common/provision/10 + hostname
  25-sunshine.sh                   wrapper → common/provision/20
  70-newt-persona.sh               wrapper → common/provision/30
docs/
  REMOTE-DAYZERO.md                this doc
  INSTALL-BAZZITE-IMAGE.md         how to flash the CI-built image + first-boot flow
```

`bazzite/system_files/usr/share/lava-chicken/` is a copy (or CI-time sync) of
`common/`, so the image and the SteamOS bootstrap run byte-identical scripts.

---

## GitHub Actions pipeline

Two jobs, standard uBlue/bootc pattern:

1. **build-image** — `buildah build` the `bazzite/Containerfile`, tag
   `ghcr.io/hartsock/lava-chicken-os:stable` (+ date tag), cosign-sign, push to
   GHCR. Free hosting; `bootc upgrade` on the box pulls updates automatically.
2. **build-iso** — run `bootc-image-builder` against the pushed image to emit an
   `anaconda-iso` installer artifact, uploaded to the workflow run (and attached
   to a release on tags).

Triggers: `push` to `main` (rebuild image), weekly `schedule` (pick up Bazzite
base + package updates), `workflow_dispatch` (manual, with a `github_user`
input so forkers set their own keys source without editing files).

The GitHub username that seeds SSH keys is a **build input / repo variable**
(`LAVA_GITHUB_USER`, default `hartsock`), written to
`/usr/share/lava-chicken/github-user` in the image. The first-boot script reads
it and pulls `https://github.com/<user>.keys`. Forkers change one repo variable,
nothing else.

> CI action/tool versions (buildah-build, bootc-image-builder image tag,
> cosign) must be pinned and verified against current uBlue docs before the
> first green run — marked `# VERIFY` in the workflow.

---

## Remote access design

### SSH from GitHub (`10-ssh-github.sh`)
- `curl -fsSL https://github.com/<user>.keys` → `~/.ssh/authorized_keys`
  (mode 0600, `~/.ssh` 0700, owned by the primary user). Idempotent: replace a
  managed block delimited by `# >>> lava-chicken github:<user>` markers so
  hand-added keys survive.
- sshd: enable the **system** `sshd.service`. Drop-in
  `sshd_config.d/10-lava-chicken.conf`: `PasswordAuthentication no`,
  `PermitRootLogin no`, `KbdInteractiveAuthentication no`. Key-only from day zero.
- Hostname set to `lava-chicken-<something>` (or the GitHub handle) so it's
  findable; advertised on `home.lab` via the existing dnsmasq if desired.

### Sunshine / Moonlight (`20-sunshine.sh`)
Preserve, don't reinvent. On the AMD gaming box Sunshine captures the real
Gaming Mode surface (KMS/Wayland) — no headless Xorg-dummy dance needed (that
was gnuc-specific; see `my_home/docs/runbooks/sunshine-moonlight-gnuc.md`).
- **Bazzite** ships Sunshine: enable it (`ujust setup-sunshine` equivalent /
  the Sunshine user service) rather than installing from scratch.
- **SteamOS**: install the LizardByte Sunshine (Flatpak `dev.lizardbyte.app.Sunshine`
  or `$HOME`-scoped), enable the user service.
- Firewall: open the canonical ports (`common/sunshine/ports.env`, lifted from
  the runbook) to `192.168.0.0/24` **and** the WG subnet `10.10.0.0/24`:

  | 47984/tcp 47989/tcp 47990/tcp 48010/tcp | 47998/udp 47999/udp 48000/udp 48002/udp |

- Pairing stays a one-time manual step (Sunshine PIN via web UI at
  `https://<box>:47990`, reached over the SSH tunnel or LAN). Documented, not
  automated — pairing is a security boundary.

---

## Resident newt persona

"A custom OS-level persona permanently living on the box," delivered as three parts.

### 1. Persona config (`common/persona/`)
- `lava-chicken.persona.md` — the system prompt / identity for *this box's*
  agent: who it is, what it's for (local coding on the lava-chicken box against
  local ollama), guardrails.
- `newt.config.toml` — points newt at `http://127.0.0.1:11434/v1`, model
  `qwen2.5-coder:7b` (override), and references the persona.
- Installed to `~/.config/newt/` by `30-newt-persona.sh`.

> newt's exact config schema is version-dependent (memory: summarizer.toml /
> cap pinning open items). Keep this minimal and mark it `# VERIFY against newt
> --help` — same caveat as the existing `50-newt-agent.sh`.

### 2. Resident service (`common/systemd/newt-agent.service`)
- A **user** systemd service (`WantedBy=default.target`, needs
  `loginctl enable-linger <user>` so it survives logout) that keeps newt running
  as the box's resident agent, bound to **localhost only**.
- Depends on `ollama.service` (After/Wants) so the model backend is up first.

### 3. Remote entrypoint (`common/bin/newt-box`)
- **SSH is the only transport.** No newt TCP port is exposed to the network —
  the resident service binds loopback; you reach it *through* the SSH session
  your GitHub keys already authorize.
- `newt-box` is a small wrapper: SSH in → run `newt-box` → it attaches you to
  the resident persona session (or starts a scoped one with the persona
  preloaded). Optionally set as the login command for a dedicated `agent` SSH
  key so `ssh agent@box` drops straight into the agent.
- Rationale: an agentic executor reachable on an open network port is a real
  attack surface. Gating it behind key-only SSH keeps the blast radius to
  "someone who already holds your private key."

---

## Security notes (deliberate constraints)

- **ollama** binds `127.0.0.1:11434` only (already true in `40-ollama.sh`). The
  resident newt talks to it locally; neither is network-exposed.
- **sshd** is key-only from first boot; no password path ever opens.
- **newt** is never bound to a TCP port; remote access is SSH-gated.
- **Sunshine** is the one intentionally network-listening service; it's scoped
  by firewall to LAN + WG and gated by Moonlight PIN pairing.
- **No secrets in the image or repo.** The image bakes only a public GitHub
  *username*; actual keys are pulled at first boot from GitHub's public
  `.keys` endpoint. Media/asset gitignore rules are unchanged.

---

## Open items / to verify before first green build

1. Bazzite base image tag + variant (KDE desktop, AMD) — confirm
   `ghcr.io/ublue-os/bazzite:stable` is the right ref.
2. `bootc-image-builder` invocation + `image.toml` schema for the
   `anaconda-iso` type and any baked user defaults.
3. Whether to bake the primary user in the image or let Anaconda OOBE create it
   (default: **OOBE creates it**; first-boot fills keys/persona for the primary
   user — most robust, matches SteamOS `deck`).
4. newt config schema + the resident/attach model (does newt support a
   long-running attachable session, or does `newt-box` just launch a persona'd
   REPL each SSH login?). Verify against the installed newt.
5. SteamOS Sunshine delivery (Flatpak vs `$HOME` tarball) and whether its user
   service can capture the Gamescope session without extra glue.
6. Firewall backend per OS (Bazzite = firewalld; SteamOS = iptables/no-ufw) —
   `20-sunshine.sh` must branch, not assume `ufw` like the gnuc runbook.
```
