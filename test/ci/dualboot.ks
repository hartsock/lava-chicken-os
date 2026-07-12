# L2 dual-boot SAFETY test kickstart — CI FIXTURE ONLY. NOT the shipped installer.
#
# The shipped ISO (bazzite/image.toml) deliberately ships an EMPTY-STRING
# kickstart so Anaconda runs INTERACTIVELY (a human drives Blivet-GUI). We do NOT
# and MUST NOT drive the real dual-boot install from a kickstart. This file exists
# only to prove, in CI, that a free-space-targeted unattended install honours
# "clearpart --none" and never touches the neighbour partition — i.e. it validates
# the Anaconda+kickstart partitioning MECHANISM against a synthetic disk.
#
# PAYLOAD (resolved, take 2): bib DOES add the `ostreecontainer` payload — via
# indirection: the embedded /osbuild.ks begins with
# `%include /run/install/repo/osbuild-base.ks`, and THAT file carries
# `ostreecontainer --url=/run/install/repo/container --transport=oci` (run
# 29176715582, line-level dump). Runs 3-4 mis-probed this: grepping only the
# top-level ks file misses the %include. So this file carries NO payload line
# (a duplicate is redundant at best); the workflow probe asserts the payload
# exists across ALL *.ks files on the ISO. Layer A (ksvalidator + grep) checks
# the safety invariants before we ever boot.

# `--non-interactive` is REQUIRED for an unattended install: plain `text` still
# stops at the interactive hub ("Begin Installation") and waits for a human, so
# the guest would never install and never poweroff — the job would burn its full
# timeout. This matches bib's documented example and the RHEL image-mode docs.
text --non-interactive
lang en_US.UTF-8
keyboard us
timezone --utc UTC
network --bootproto=dhcp --hostname=lacos-ci

# A locked root + disabled firstboot make the install fully non-interactive: an
# unspecified root/users spoke can otherwise stall even `--non-interactive`. A
# locked root is fine for a throwaway L2 VM we only ever inspect offline.
rootpw --lock
firstboot --disable

# ── THE WHOLE POINT: never wipe anything ─────────────────────────────────────
# clearpart --none = do not remove ANY existing partition. The neighbour
# (vda2, the fake-Windows data partition) and the ESP (vda1) must survive
# byte-identical. NEVER use --all / --linux / --initlabel here.
clearpart --none

# Only ever look at the target disk (vda). The synthetic disk is the only disk
# the L2 VM is given, but pin it explicitly so a stray disk is never touched.
ignoredisk --only-use=vda

# ── REUSE the existing ESP, do not reformat it ───────────────────────────────
# LaCOS legitimately writes \EFI\fedora next to the seeded \EFI\Microsoft, so the
# ESP is EXPECTED to change — the L2 proof asserts the Windows loader SURVIVED and
# a LaCOS loader was ADDED, it does NOT byte-compare the ESP. --noformat keeps the
# existing filesystem (and the seeded bootmgfw.efi) intact.
part /boot/efi --onpart=vda1 --fstype=efi --noformat

# ── New OS lands ONLY in the trailing FREE SPACE ─────────────────────────────
# With clearpart --none, vda1 (ESP) and vda2 (neighbour) stay put; these new
# partitions are carved from the unallocated tail. --ondisk=vda keeps them on the
# target disk. If Anaconda ever could not fit these in free space it would error
# rather than reclaim vda2 — which is exactly the safety we are proving.
part /boot --fstype=ext4 --size=1024 --ondisk=vda
part /     --fstype=btrfs --grow    --ondisk=vda

# NO explicit `bootloader` line: this is a UEFI/OVMF q35 install, where the
# loader lives on the ESP and bootupd owns the \EFI\fedora entry. A BIOS-style
# MBR bootloader directive is an x86-BIOS notion that Anaconda under
# `--non-interactive` may reject on a GPT/EFI target, aborting the install (and
# leaving the partition count at 2 -> Layer B false-fails). Omitting the line
# lets bib/anaconda + bootupd default correctly for EFI.

# Power off (not reboot) so `qemu -no-reboot` exits cleanly when the install ends,
# letting the job re-attach the disk and run the byte-proof.
poweroff
