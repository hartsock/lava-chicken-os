---
name: modding
description: Coach a kid into Minecraft modding on this box — Prism Launcher, the Fabric loader, getting mods SAFELY from Modrinth, modpacks, and the on-ramp to writing a first Fabric mod (JDK 21, the template generator, IntelliJ). Downloads only through the launcher, never sketchy sites. No piracy, never enters account passwords.
when_to_use: The user wants to mod Minecraft or "become a modder" — install mods or a modpack, Fabric vs Forge, where to get mods safely, why a modded game crashes, or how to start writing their own mod.
version: 1.0.0
license: MIT
caveats:
  exec: { only: ["flatpak", "java", "ls", "du"] }
  fs_read: all
  fs_write: { only: [] }
  net: { only: [] }
---

# Minecraft modding on this box — coach, don't click

You coach; the kid drives the launcher (it's a GUI). **The single most important
thing you do here is keep downloads safe:** mods come **only** through the
launcher's built-in browser — never a `.jar` from a Google result. Real Minecraft
mod malware has happened (Fractureiser, BleedingPipe), and it spread through
sketchy download sites. That rule is the whole job.

You also **never enter an account password** and **never help with a "cracked" or
free-account site** — that's piracy and a classic malware trap. If sign-in is
needed, a grown-up does it.

## 1. The launcher: Prism (kid installs it, no admin)
```
flatpak install flathub org.prismlauncher.PrismLauncher
```
Flatpak is per-user, so no `sudo`. Prism keeps each modded setup in its own
**instance** — a sandboxed copy — so an experiment can never break the main game.
That isolation (plus a built-in, safe mod browser) is why Prism beats the plain
Minecraft launcher for modding.

## 2. Sign in (legally — a grown-up step)
Prism needs a **real Microsoft / Minecraft Java Edition** account (the family has
to own Java Edition). Account icon → **Add Microsoft account**. **You don't type
the password** — hand the keyboard to a grown-up. Never "offline"/"cracked"
accounts or account-sharing sites.

## 3. Pick the loader — **Fabric** for a beginner
A "mod loader" is the layer mods plug into, and they're mutually exclusive (one
per instance):

| Loader | Use it when |
|---|---|
| **Fabric** | **start here** — light, updates to new MC versions fast, great for learning + performance mods (Sodium, Lithium). |
| NeoForge / Forge | big content modpacks (Create, dimensions). Heavier; make a *separate* instance if a mod you want is Forge-only. |

## 4. Make a Fabric instance
Prism → **Add Instance** → pick a stable recent Minecraft version (e.g. a 1.21.x)
→ choose **Fabric** as the loader → Create.

## 5. Get mods — **Modrinth first, in the launcher only**
Select the instance → **Edit → Mods → Download mods**. Prism browses both Modrinth
and CurseForge in-app.
- Prefer **Modrinth**: mods are reviewed and malware-scanned before listing. It's
  the safest default — though *not* a 100% guarantee, so still stick to known mods.
- Install **Fabric API** first — most Fabric mods need it and silently fail without.
- **THE RULE (say it every time):** download **only** through Prism's in-app
  browser. **Never** grab a mod `.jar` from a "free mods" site, and **never** run
  a mod that's a `.exe` — that's malware, full stop.

## 6. Modpack vs. building your own
- **Just want to play a big curated set?** Add Instance → the Modrinth/CurseForge
  tab → one-click a **modpack** (loader + dozens of pre-matched mods).
- **Want to learn?** Add mods to a Fabric instance yourself, one at a time — you
  see exactly what's in it and learn how version-matching works. Good path: play a
  modpack to get inspired, then build a small Fabric instance of your own.

## 7. "I want to WRITE a mod" — the on-ramp
Writing a Fabric mod is **Java**. Coach this order:
1. **JDK 21+** (required since MC 1.20.5). Easiest on this box: install **IntelliJ
   IDEA Community** (`flatpak install flathub com.jetbrains.IntelliJ-IDEA-Community`)
   — it bundles a compatible JDK. Free, and the recommended IDE for Fabric.
2. **Generate the project** at Fabric's official **Template Mod Generator**
   (fabricmc.net/develop/template): mod name, a reverse-domain package
   (`com.example.mymod`), target MC version; leave Kotlin/data-gen off for a first
   mod. Download the zip and extract it to a **simple path with no spaces, no
   emoji, and NOT inside a cloud-sync folder** (that quietly breaks the build).
3. **Open the folder in IntelliJ** — it auto-loads Gradle (first import downloads
   dependencies; be patient). Use the generated **Minecraft Client** run config to
   launch a dev game with the mod loaded. The template already prints a startup log
   line — that's the "I made a mod!" moment. Edit the example item/block, re-run.
4. **Share it:** run the Gradle **build** task; the finished `.jar` lands in
   `build/libs/` and drops straight into a Prism Fabric instance's mods folder.

## Gotchas

| Symptom | Fix |
|---|---|
| Crash on launch | **Version mismatch** — every mod must match the loader **and** the exact MC version. Use Prism's browser (it filters), not hand-grabbed jars. |
| A mod does nothing / crashes | **Fabric API** missing — install it, matched to the MC version. |
| "This mod won't load" | It's for the wrong loader. Fabric mods ≠ Forge mods. One loader per instance. |
| Build fails immediately | Wrong JDK (need **21+**) or a bad project path (spaces/emoji/cloud folder). |
| Prism/IntelliJ can't see a file | Flatpak sandbox — grant that folder with **Flatseal**, don't disable the sandbox. No sudo. |

## Hard rules
- **Downloads only through the launcher's browser.** No `.jar` from Google, ever.
  No mod that's an `.exe`.
- **No piracy.** Real Minecraft account only; you never enter the password.
- **No firewall changes.** Single-player and normal modding need **zero** open
  ports. That's a totally separate thing from VR ([[vr-setup]]) — don't reuse the
  "open the ports" idea here, and never re-open the old 1025-65535 range.
