# Build plan

Target machine: old Windows 10 desktop, no TPM, AMD GPU.

## Phase 0 — Prep (on any machine)
- [ ] Back up anything worth keeping from the Windows install (it will be erased).
- [ ] Check the AMD GPU generation. ROCm/ollama dropped gfx900/gfx906 (Vega 10/20);
      RDNA1+ (RX 5000+) is the comfortable floor for GPU inference. Older cards:
      ollama falls back to CPU, or use llama.cpp Vulkan.
- [ ] Download installer image:
      - SteamOS 3.8+ recovery/installer from Valve (AMD GPU only, wipes the whole disk), or
      - Bazzite (pick **Desktop → KDE → AMD**; the `-dx` developer variant is nice-to-have).
- [ ] Write to USB with Ventoy/Etcher/Fedora Media Writer.
- [ ] Acquire your personal copy of *Steve's Lava Chicken* (audio) and any
      wallpapers you're licensed to use.

## Phase 1 — Base OS install
- BIOS: disable Secure Boot (SteamOS; Bazzite handles it but enrolling keys is extra work),
  set USB first in boot order. No TPM needed.
- Install, create user, connect network, update, reboot into Desktop Mode.

## Phase 2 — lava-chicken bootstrap (this repo)
Order matters only loosely; `bootstrap.sh` runs them in sequence:

| Step | Script | What |
|---|---|---|
| 10 | `theme-wallpapers` | Apply wallpaper (user-supplied or generated) via `plasma-apply-wallpaperimage` |
| 20 | `boot-video` | ffmpeg: your audio + a still/animation → VP9/Opus `.webm` → `~/.steam/root/config/uioverrides/movies/` |
| 30 | `login-sound` | systemd user unit plays the audio at `graphical-session.target` |
| 40 | `ollama` | ROCm tarball into `~/.local/share/ollama`, systemd user unit, pull a starter model |
| 50 | `newt-agent` | rustup in `$HOME`; build in distrobox if no host toolchain; config → ollama endpoint |
| 60 | `modding-tools` | SDKMAN → Temurin JDK 21 + Gradle; Flatpaks: IntelliJ IDEA CE, Prism Launcher; clone Fabric/NeoForge templates |

## Phase 3 — Manual finishing touches
- Gaming Mode → Settings → Customization → select the Lava Chicken startup movie.
- Ollama model choice: `qwen2.5-coder:7b` default; go bigger if VRAM allows.
- newt-agent: verify `newt --help`, point router at `http://127.0.0.1:11434/v1`.
- Test a mod build: `cd ~/mods/fabric-example-mod && ./gradlew build`.

## Phase 4 — Publish
- Verify `assets/user/` is empty in git (`git status --ignored`).
- shellcheck all scripts.
- Push to github.com/hartsock/lava-chicken-os.

## Known constraints
- **SteamOS**: read-only rootfs; `steamos-readonly disable` exists but changes are
  wiped by updates — that's why everything here installs to `$HOME` (Flatpak,
  SDKMAN, cargo, ollama tarball, systemd *user* units).
- **SteamOS**: no host compiler toolchain — newt-agent builds inside a distrobox.
- **Bazzite**: immutable too (rpm-ostree), but ships Homebrew, Distrobox, and
  Flatpak out of the box; the same $HOME-first approach just works.
- **Boot chain reality check**: the *first* thing you see/hear is firmware →
  Plymouth splash (silent, rootfs-owned) → then Steam's startup movie, which is
  where our sound lives. True BIOS-level sound isn't practical; the startup
  movie is the boot sound.
