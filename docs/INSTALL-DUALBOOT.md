# Dual-boot LaCOS alongside Windows 10

**Read this whole page once before touching the machine.** This installs Lava
Chicken OS (a custom **Bazzite** / Fedora Atomic image) *next to* your existing
Windows 10 on the **same disk**, by shrinking Windows to make room. Windows and
your files survive **only if you follow the manual-partitioning steps exactly.**
A backup is not optional.

> **Why this path:** you install **stock Bazzite** from bazzite.gg, then switch
> the machine to LaCOS with one reversible command (`bootc switch`). You do
> **NOT** use this project's CI-built `anaconda-iso` for the first install — see
> *Danger 2*. Dual-boot is **Bazzite only** (SteamOS installs whole-disk); you
> still get Steam Game Mode.

---

## STOP — do these BEFORE you start

- [ ] **Back up irreplaceable files** to an external drive or cloud. Assume the disk could be lost.
- [ ] **Confirm UEFI/GPT**: in Windows run `msinfo32` → *BIOS Mode* must say **UEFI**. If it says *Legacy*/MBR, stop — the steps differ.
- [ ] **Turn off BitLocker** (Control Panel → BitLocker → *Turn off*) and **wait for decryption to finish**. Note your recovery key location regardless.
- [ ] **Turn off Fast Startup** (Power Options → *Choose what the power buttons do* → uncheck **Turn on fast startup**).
- [ ] **Full shutdown** afterward (Shut down, *not* Restart) — clears the NTFS "dirty"/hibernation flag so Linux can read the disk safely.
- [ ] **Write your board's one-time boot-menu key on paper** (often F12/F11/F8/Esc) and the setup key (Del/F2). **This key is your primary, always-works way back into Windows.**
- [ ] **Make a Windows recovery USB** (Windows: *Create a recovery drive*), in case the bootloader ever needs repair.
- [ ] **Rehearse in a VM first** (see *VM pre-flight* below) if you've never driven Blivet-GUI.

---

## The two things most likely to destroy Windows

> ### ⚠️ Danger 1 — Accepting Anaconda's *automatic* storage
> The stock Bazzite installer **can also wipe Windows** — its default guided/auto
> storage will reclaim the whole disk. Safety comes entirely from **you** picking
> **Advanced Custom (Blivet-GUI)** and working *only* in the unallocated free
> space. **If the Storage screen offers no manual/Blivet-GUI option, STOP and
> reboot — do not proceed.**

> ### ⚠️ Danger 2 — Don't use this repo's CI `anaconda-iso` (yet)
> `bootc-image-builder --type anaconda-iso` is, per its own docs, *"an unattended
> installer that installs to the first disk found"* → on the Windows box that's a
> **silent whole-disk wipe**. Use **stock Bazzite** for the install and
> `bootc switch` for LaCOS. Only trial the CI ISO later, **in a VM**, after
> confirming it drops into interactive Blivet-GUI (it must ship an *empty-string*
> kickstart, not an absent one — see [image.toml](../bazzite/image.toml)).

---

## Step 1 — Prepare Windows (in Windows)

1. Back up (again — really).
2. BitLocker off + decrypted; Fast Startup off (above).
3. **Shrink Windows from within Windows** — right-click Start → **Disk Management**
   → right-click `C:` → **Shrink Volume** → free **100+ GB**. Windows' own shrinker
   respects NTFS metadata; the Linux-side resizer is riskier, so we don't use it.
   If it won't shrink far enough: disable pagefile + System Restore for `C:`,
   reboot, and try again.
4. **Leave the freed space UNALLOCATED** — do not create a new Windows volume in it.
5. **Full shutdown.**

---

## Step 2 — Make the USB (on your Mac)

Download the stock **Bazzite (Desktop, AMD)** ISO from <https://bazzite.gg> (~8 GB).
Write it to an **≥ 16 GB** USB stick:

```bash
diskutil list                       # find your USB's diskN — GET THIS RIGHT
diskutil unmountDisk /dev/diskN
sudo dd if=~/Downloads/bazzite-stable-amd64.iso of=/dev/rdiskN bs=4m status=progress
```

⚠️ A wrong `diskN` overwrites the wrong drive. Double-check with `diskutil list`.
(Or use **balenaEtcher** — friendlier, picks the target for you. Or **Ventoy**:
format the stick once, then just drop the ISO onto it.)

---

## Step 3 — Boot the installer + BIOS

1. Insert the USB, power on, tap the **setup key** (Del/F2).
2. Ensure **UEFI** boot (not Legacy/CSM). Set the USB first, or use the one-time
   **boot-menu key**.
3. **Secure Boot**: Bazzite is signed, so you can leave it **on** — on first
   reboot you may be asked to **enroll a MOK key**; **accept it** (this is
   expected, not an attack). If enrollment is fussy on old firmware, disabling
   Secure Boot is a fine pragmatic fallback (Windows 10 boots either way).

---

## Step 4 — Partition ALONGSIDE Windows (Blivet-GUI)

On **Installation Destination / Storage Configuration**, choose
**Advanced Custom (Blivet-GUI)**. (If only automatic/guided is offered, **STOP** —
reboot and use Bazzite's *Legacy* ISO variant, which exposes manual partitioning.)

Then, working **only in the unallocated free space** from Step 1:

- **Do NOT touch**: the Windows `C:` (NTFS), the Microsoft Reserved (MSR, ~16 MB),
  or the Windows Recovery partition. Never select, format, or delete these.
- **ESP (reuse the existing one)**: select the existing ~100 MB **FAT32 EFI System
  Partition**, set **Mount Point = `/boot/efi`**, and **leave "Reformat"
  UNCHECKED.** Bazzite writes its loader *next to* Windows' `\EFI\Microsoft`.
  (A 100 MB ESP is tight but normally fits one more bootloader; if the install
  complains about ESP space, that's the reason.)
- In the free space create: **`/boot`** ext4 (~1–2 GB), and a **Btrfs** partition
  filling the rest with subvolumes at **`/`**, **`/var`**, **`/var/home`**
  (Bazzite requires Btrfs for `/`).
- **Review the summary**: the **only** "Format" actions must be your new `/boot`
  and Btrfs partitions. If `C:`, MSR, Recovery, or the ESP show any reformat/
  delete — **abort**. Then install.

---

## Step 5 — How Windows stays bootable (important)

There are two ways back into Windows; know both:

1. **The UEFI firmware boot menu is your PRIMARY, always-works path.** As long as
   the shared ESP wasn't reformatted (Step 4), the *Windows Boot Manager* entry is
   still in firmware — tap your boot-menu key at power-on and pick it. This is
   independent of GRUB/ostree/bootc, so it survives OS updates. **Test it first.**
2. **GRUB menu (convenience).** After first boot into Bazzite, run
   `ujust regenerate-grub` to try to add a Windows entry to the boot menu. Treat
   this as best-effort: os-prober is disabled by default on Fedora Atomic and
   bootc's `bootupd` manages the ESP, so a Windows entry may or may not appear and
   may not survive updates. **Never rely on GRUB alone — the firmware menu is the
   guarantee.**

Reboot and **verify BOTH Windows and Bazzite boot** before doing anything else.

---

## Step 6 — Turn Bazzite into LaCOS

Once Bazzite works *and* Windows still boots, rebase to the LaCOS image:

```bash
sudo bootc switch ghcr.io/hartsock/lava-chicken-os:stable
sudo systemctl reboot
```

First boot runs `lava-chicken-firstboot.service` (SSH keys from GitHub, Sunshine,
the nugget agent, boot splash). If anything misbehaves:

```bash
sudo bootc rollback && sudo systemctl reboot   # back to stock Bazzite, non-destructive
```

`bootc switch` only changes the OS image — it does **not** repartition, so this
step can't touch Windows.

---

## VM pre-flight (rehearse risk-free first)

You do **not** have to practice on the real box. Rehearse the Blivet-GUI dance in
a VM on your Mac first — see [`test/dualboot-vm/`](../test/dualboot-vm/) for a
QEMU harness that boots the Bazzite ISO against a synthetic disk with a fake
Windows partition + free space. Do it a few times until the "leave `C:` alone,
reuse the ESP, install into free space" flow is muscle memory.

> The VM rehearses the *partitioning clicks*. It cannot prove "Windows re-boots"
> unless the VM has a real Windows install — that guarantee comes from the
> firmware-boot-menu test on the real box (Step 5). The rehearsal's job is to make
> you fluent with Blivet-GUI so you don't make a wrong click on the real disk.

---

## If something goes wrong

- **Can't boot Windows after install** → tap the firmware boot-menu key, pick
  *Windows Boot Manager*. If it's gone, boot the Windows recovery USB →
  *Startup Repair* / `bootrec /rebuildbcd`. Your data is intact if you didn't
  reformat `C:`.
- **Can't boot anything** → boot the Windows recovery USB or the Bazzite USB
  (rescue) and repair the bootloader; the firmware entries live in the ESP.
- **Only auto-partitioning offered** → wrong ISO/mode; use the Legacy Bazzite ISO.

## VERIFY-on-hardware (before trusting this end-to-end)

- [ ] `ujust regenerate-grub` actually adds Windows on *this* board (else rely on the firmware menu).
- [ ] Shared ~100 MB ESP has room for Bazzite's loader (watch for ESP-full errors).
- [ ] Secure Boot + MOK enrollment behaves on this old firmware.
- [ ] `bootc switch` to `ghcr.io/hartsock/lava-chicken-os:stable` succeeds and `bootc rollback` works.
