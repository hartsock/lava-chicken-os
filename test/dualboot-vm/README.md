# Dual-boot rehearsal VM (macOS host)

Rehearse the [dual-boot install](../../docs/INSTALL-DUALBOOT.md) in a VM before
touching the real Windows box — until the "leave Windows alone, install into free
space, reuse the ESP" flow in Blivet-GUI is muscle memory.

## What it does / doesn't prove

- ✅ Rehearses the **partitioning clicks** against a disk that looks like the real
  box: a real **EFI System Partition**, a stand-in "Windows" partition (`FAKEWIN`),
  and **unallocated free space**.
- ❌ Does **not** prove "Windows re-boots afterward" — `FAKEWIN` isn't a real
  Windows install. That guarantee comes from the firmware-boot-menu test on the
  real box (INSTALL-DUALBOOT.md, Step 5).

## Requirements (one-time)

- macOS + `brew install qemu`
- The **stock Bazzite x86_64 ISO** at `~/lava-chicken-vm/bazzite-stable-amd64.iso`
  (`curl -fL -o ~/lava-chicken-vm/bazzite-stable-amd64.iso https://download.bazzite.gg/bazzite-stable-amd64.iso`)

> **Heads-up:** your Mac is arm64 and Bazzite is x86_64, so the VM runs under
> **emulation — it will be slow** (multi-minute boots). That's expected; it's fine
> for rehearsing clicks a few times.

## Use

```bash
./make-fakebox.sh      # once: mint the synthetic fake-Windows disk (sparse)
./rehearse.sh          # boot the installer VM; resets the disk each run
```

In the VM: at **Installation Destination → Storage Configuration** choose
**Advanced Custom (Blivet-GUI)**, then practice —
- **don't** touch `FAKEWIN` or the `EFI` partition,
- create your `/boot` (ext4) + Btrfs (`/`, `/var`, `/var/home`) in the **free space**,
- set the existing **EFI** partition's mount point to `/boot/efi` with **reformat OFF**.

Close the window to quit; re-run `rehearse.sh` to start clean and do it again.

## Notes

- Big artifacts (ISO, disks) live in `~/lava-chicken-vm/` (override with
  `LACOS_VM_DIR`), **not** in the repo.
- Tunables: `FAKEBOX_GB` (disk size, default 60), `FAKEWIN_SIZE` (default 25G),
  `BAZZITE_ISO` (ISO path).
- This is a macOS/QEMU dev helper — not part of the OS image.
