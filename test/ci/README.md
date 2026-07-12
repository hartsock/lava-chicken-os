# CI integration-test fixtures (`test/ci/`)

Fixtures for the two **post-merge** integration tiers that run against the
**pushed** GHCR image (`ghcr.io/<owner>/lava-chicken-os:stable`) — never on PRs.
See [`docs/TEST-PLAN.md`](../../docs/TEST-PLAN.md) Tiers 1 (L1b) and 2 (L2).

Both workflows trigger on `workflow_run(build-image succeeded on main)` +
`workflow_dispatch` + a nightly `schedule`. They only fire from the copy of the
file on the **default branch** — nothing runs until merged; test via **Run
workflow** (dispatch) first.

## L1b — KVM boot smoke (`.github/workflows/test-boot.yml`)

Rebuilds the pushed image into a qcow2 with a throwaway SSH user, boots it
headless under KVM/UEFI, SSHes in, and runs the in-guest health checks.

| File | Role |
|---|---|
| `vm-user.toml.tmpl` | kickstart-**free** bib config; `__PUBKEY__` is replaced with an ephemeral per-run key. Separate from `bazzite/image.toml` because a `[[customizations.user]]` block and a `[customizations.installer.kickstart]` block are mutually exclusive in bib, and the CI user must never ship. Also drops a **CI-only** `/etc/sudoers.d/99-cismoke` NOPASSWD fragment so root-only checks (`bootc status`, clean `poweroff`) work over the BatchMode SSH pipe; it lives only in this CI config and never reaches a released artifact. |
| `smoke-assert.sh` | in-guest assertions (run over SSH as `cismoke`). Asserts only image-baked, non-networked facts; **does not** gate on `lava-chicken-firstboot` (networked, minutes long, fragile on CI NAT — reported as INFO only). Ends with the `L1b smoke: ALL PASS` **completion sentinel** the workflow greps for, so a truncated script can't false-pass. |

If `/dev/kvm` is absent the job **FAILS LOUDLY** (it does *not* skip green): this
tier's only purpose is to prove the image boots, so a KVM-less no-op would assert
nothing. Software TCG is too slow/flaky for a full desktop boot to be a fallback.
QEMU is fully detached (`setsid`, `-monitor none -display none`, stdio redirected,
`-pidfile`) so it survives across steps and is reaped by its real pid.

## L2 — dual-boot safety (`.github/workflows/test-dualboot.yml`)

Three-layer harness; strongest catch gates, cheap checks never flake.

| Layer | File(s) | Proves |
|---|---|---|
| **A** static | `dualboot.ks` | Shipped ISO stays interactive (`image.toml` `contents=""`); the L2 kickstart is provably **unattended** (`text --non-interactive`) and free-space-only (`clearpart --none`, ESP `--noformat`, disk-pinned, no `--all/--linux/--initlabel/autopart`). No VM. |
| **B** anaconda | `dualboot.ks`, `fabricate-neighbor-disk.sh`, `verify-neighbor-untouched.sh` | The real byte-proof: rebuild the anaconda-iso with the test kickstart, install **unattended under KVM** against a synthetic `[ESP][fake-Windows][free space]` disk, then assert the neighbour partition is **byte-identical** and LaCOS actually landed (an ostree payload) in the free space. Exercises Anaconda's partitioner — the true dual-boot hazard. A **neighbour-changed** verdict fails hard and is **never retried**; only an install-didn't-run verdict is retried once. |
| **C** bootc | `fabricate-neighbor-disk.sh`, `verify-neighbor-untouched.sh` | Fallback when `/dev/kvm` is absent: `bootc install to-filesystem` into a btrfs we pre-create in the free space. Same neighbour byte-proof, deterministic without KVM, and it requires a **positive ostree payload** written by bootc (not the pre-created partition) so a no-op install can't green it. **Lower fidelity** (loud `::warning`) — it sidesteps the partitioner, so it proves "bootc content-install never touches a neighbour", not "Anaconda's partitioning won't". |

The neighbour is fingerprinted as the sha256 of the raw **partition device** (the
whole device is filled with known random bytes), so any byte change anywhere is
caught with no filesystem driver. The ESP is **expected** to change (LaCOS writes
`\EFI\fedora` next to the seeded `\EFI\Microsoft`), so L2 asserts loader
**survival + addition**, never ESP byte-equality.

`verify-neighbor-untouched.sh` returns distinct exit codes so the workflow can
tell a **safety regression** from an **infra flake**: `0` pass, `2` neighbour
modified (fail hard, never retry), `3` install-incomplete (retryable).
