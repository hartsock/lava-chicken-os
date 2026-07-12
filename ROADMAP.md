# Lava Chicken OS — Roadmap

**`v0.0.1` → `v0.1.0`**  ·  created 2026-07-11 · updated 2026-07-12  ·  milestone
[`v0.1.0`](https://github.com/hartsock/lava-chicken-os/milestone/1)

We iterate `v0.0.1 … v0.0.99` (one reviewable PR per roadmap item); **`v0.1.0`**
is the gate we cut once it works end-to-end on real hardware of *both* bases.
This document follows newt-agent's `repository-roadmap` skill.

## Ground truth

> **GitHub issues are the state; this document is the map.** Every item carries
> an issue number. When the doc and GitHub disagree, **GitHub wins** — the doc
> may be stale, the issues cannot. Reconcile before trusting the prose:

```bash
gh issue list --repo hartsock/lava-chicken-os --milestone v0.1.0 --state all \
  --json number,title,state
gh issue view <N> --repo hartsock/lava-chicken-os --json number,title,state,closedAt
```

A **phase is done** when every issue in it is closed (or carries a comment
re-scoping it out of the milestone).

## Source plans

This roadmap *sequences* the design docs; it does not replace them.

- [docs/REMOTE-DAYZERO.md](docs/REMOTE-DAYZERO.md) — day-zero remote access + resident agent
- [docs/INSTALL-DUALBOOT.md](docs/INSTALL-DUALBOOT.md) — Bazzite-alongside-Windows dual-boot
- [docs/TEST-PLAN.md](docs/TEST-PLAN.md) — the tiered test plan (static → CI-VM → hardware)

---

## Phase 1 — Multi-user + smooth install

| Item | Issue | Exit |
|---|---|---|
| ✅ Provision admin (from GitHub keys) + optional kid users | [#1](https://github.com/hartsock/lava-chicken-os/issues/1) | admin + any `LAVA_KID_USERS`; kids non-`wheel`, not in `nugget-tui`; per-user `nugget` icon for all |
| ✅ First-boot auto-pull of LLM models (progress) | [#2](https://github.com/hartsock/lava-chicken-os/issues/2) | `ollama list` shows the models after first boot; newt starts with no download |

Also closed here: ✅ the 2nd-boot **setup wizard**
([#15](https://github.com/hartsock/lava-chicken-os/issues/15), `lacos setup`) —
it holds every site particular so the image stays generic.

## Phase 2 — Site integration (2nd-boot, via the wizard)

| Item | Issue | Exit |
|---|---|---|
| Join Tailscale (wizard step) | [#3](https://github.com/hartsock/lava-chicken-os/issues/3) | box on the tailnet, remote-manageable |
| Split-DNS + the print-a-DNS-line step | — (folded into [#15](https://github.com/hartsock/lava-chicken-os/issues/15), shipped) | `*.<domain>` resolves on-box; `<box>.<domain>` LAN-wide after the operator adds the printed line |

*(Two former tracking issues here carried site-specific detail and were removed;
the generic capability shipped inside the wizard. #3 remains to VERIFY the
Tailscale step on hardware.)*

## Phase 3 — Creative app stack

| Item | Issue | Exit |
|---|---|---|
| ✅ Art stack (Krita/GIMP/Inkscape) + Adobe→Windows doc | [#6](https://github.com/hartsock/lava-chicken-os/issues/6) | art apps installed all-users |
| ✅ OBS + VAAPI hardware encode | [#7](https://github.com/hartsock/lava-chicken-os/issues/7) | hardware-encoded record/stream to YouTube |
| ✅ Kdenlive/Shotcut default editor + Resolve caveat | [#8](https://github.com/hartsock/lava-chicken-os/issues/8) | kids export H.264 for YouTube |

## Phase 4 — CI testing

| Item | Issue | Exit |
|---|---|---|
| ✅ L1 image boot smoke test (KVM) | [#9](https://github.com/hartsock/lava-chicken-os/issues/9) | `test-boot.yml`: post-merge + nightly, boots the pushed image under KVM/UEFI + asserts the nugget layer in-guest |
| ✅ L2 dual-boot safety test | [#10](https://github.com/hartsock/lava-chicken-os/issues/10) | `test-dualboot.yml`: nightly byte-proof (sha256 of the fake-Windows partition unchanged; install provably landed) |

## Phase 5 — Hardware validation

| Item | Issue | Exit |
|---|---|---|
| ✅ Green the image + ISO/qcow2 build (pin versions) | [#11](https://github.com/hartsock/lava-chicken-os/issues/11) | `# VERIFY` pins resolved; CI green |
| On-hardware VERIFY sweep (Bazzite) | [#12](https://github.com/hartsock/lava-chicken-os/issues/12) | Tier-4 Bazzite checklist green |
| SteamOS parity pass | [#13](https://github.com/hartsock/lava-chicken-os/issues/13) | same end-state via `bootstrap.sh` |

## Release

| Item | Issue | Exit |
|---|---|---|
| Cut `v0.1.0` | [#14](https://github.com/hartsock/lava-chicken-os/issues/14) | Tier 0/1 green per-push, Tier 2 nightly, Tier 4 green on both bases; CHANGELOG + version bump |

---

## Deliberately out of v0.1.0

Considered and excluded; each names the condition to re-enter, so it isn't
silently re-litigated.

- **CI `anaconda-iso` as the dual-boot installer** — it's an unattended
  whole-disk installer by default; too dangerous next to Windows. Dual-boot uses
  **stock Bazzite + `bootc switch`**. Re-enters once the empty-string-kickstart
  interactive path is VM-verified.
- **Full autonomous `nugget` sudo (NOPASSWD)** and **kid access to the resident
  nugget tmux** — both deferred to newt **OCAP**
  ([newt-agent#1090](https://github.com/Gilamonster-Foundation/newt-agent/issues/1090)).
  Today: propose-&-approve sudo; kids get the per-user icon only.
- **Custom logos/graphics on box rename** — the hostname/agent name is
  configurable now; bespoke art per name is out.
- **DaVinci Resolve as the default editor** — codec tax on Linux; Kdenlive is the
  default. Re-enters if someone wants grading and accepts the transcode workflow.
