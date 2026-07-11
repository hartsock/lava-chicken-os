# LaCOS Test Plan

Toward **v0.1.0**. Philosophy (borrowed from newt-agent): use the **cheapest tier
that proves the behavior**; reserve expensive tiers for what only they can catch.
Static → CI-VM → hardware. Ground truth for what's verified lives in the CI runs
and the on-hardware checklist, not in prose.

## Tiers & cadence

| Tier | What | Where | When |
|---|---|---|---|
| **0 — Static** | `shellcheck` + `bash -n` all scripts; `visudo -cf` sudoers; YAML lint; `ksvalidator` kickstart; markdown link check | GH Actions (no VM) | **every push / PR** |
| **1 — Image smoke** | build qcow2 → boot headless under **KVM** → assert the nugget layer → poweroff | GH Actions (x86_64, `/dev/kvm`) | **every push** |
| **2 — Acceptance (BAT/UAT)** | dual-boot safety, provision idempotency, per-user/no-root, model-preload, remote-access | GH Actions VM (where automatable) | **nightly** |
| **3 — VM rehearsal** | drive Blivet-GUI against the synthetic fake-Windows disk | local VM, [`test/dualboot-vm/`](../test/dualboot-vm/README.md) | pre-hardware |
| **4 — On-hardware** | the real box, both bases | manual checklist | **release gate (v0.1.0)** |

## Tier 0 — Static (seconds, gates every PR)
- `shellcheck -x` + `bash -n` on `bootstrap.sh`, `scripts/*.sh`, `common/**/*.sh`, `common/bin/*`.
- `visudo -cf common/sudoers/nugget` (a broken drop-in locks out sudo).
- `yamllint`/parse `.github/workflows/*.yml`; validate `bazzite/image.toml`.
- `ksvalidator` on any kickstart; link-check docs.

## Tier 1 — Image boot smoke (KVM CI, ~10 min, every push)
Boot the built qcow2 headless with KVM (a CI-only test user is baked via
`bootc-image-builder` `[[customizations.user]]` for SSH access), then assert:
- `bootc status` booted image present; `id nugget`; `test -x /usr/bin/nugget && /usr/bin/lacos`.
- `systemctl is-enabled nugget-agent-tmux boot-sound sshd`; `lava-chicken-firstboot` ran.
- os-release shows `Lava Chicken OS (LaCOS)`.
- **model preload:** `ollama list` shows the expected models (see Tier 2) with **no** first-boot download.

## Tier 2 — Acceptance (BAT/UAT, nightly)
| Test | Asserts |
|---|---|
| **Dual-boot safety [L2]** | kickstart install into free space; `sha256` of the neighbor (fake-Windows) partition is **UNCHANGED** before/after; both EFI entries present |
| **Provision idempotency** | run `firstboot.sh` twice — second run no-ops, no errors, no duplicate group/keys |
| **Per-user / no-kid-root** | as a non-`wheel` user: the `nugget` icon launches `newt` as them; they **cannot** attach the resident tmux; `sudo -n true` fails |
| **Remote access** | key-only sshd: pubkey login works, `PasswordAuthentication` refused; nugget `authorized_keys` is root-owned |
| **Model preload** | after install, `ollama list` contains `qwen2.5-coder:7b` + `nomic-embed-text` (+ summarizer); newt starts without pulling |
| **Sunshine** | service enabled; firewall ports open to LAN + WG only |

## Tier 3 — VM rehearsal (manual, pre-hardware)
[`test/dualboot-vm/rehearse.sh`](../test/dualboot-vm/) — drive Anaconda Blivet-GUI:
leave the neighbor partition + ESP alone, install into free space, reuse the ESP.
Repeat until fluent. (Proves the *clicks*, not "Windows re-boots".)

## Tier 4 — On-hardware VERIFY (release gate — real Bazzite + SteamOS)
- [ ] Plymouth splash + "Lava Chicken OS" shows; initramfs regen took.
- [ ] Boot sound plays at greeter (desktop) + Steam movie (Game Mode); doesn't clip the movie.
- [ ] `nugget` icon → per-user newt as each user; kids have no root path.
- [ ] Resident nugget attach over SSH (admin only); propose-&-approve sudo.
- [ ] Sunshine pairing + Moonlight stream (LAN + WireGuard).
- [ ] **Dual-boot: Windows still boots** via the firmware boot menu; `ujust regenerate-grub` best-effort.
- [ ] Homelab: `*.<your-home-domain>` resolves via your LAN DNS; box reachable on your VPN/tailnet.
- [ ] **Models present, first boot smooth** (no multi-GB download wait).
- [ ] SteamOS parity: `bootstrap.sh` reaches the same end-state.

## Release gate for v0.1.0
All of: Tier 0 + Tier 1 green on every push; Tier 2 green nightly; Tier 4 checklist
green on a real Bazzite box **and** a SteamOS box; CHANGELOG finalized; version
bumped `0.0.x → 0.1.0`. Until then we iterate `v0.0.1 … v0.0.99`.
