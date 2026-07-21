#!/usr/bin/env bash
# Minecraft Java Edition mod-dev toolchain, all in $HOME:
#   SDKMAN -> Temurin JDK 21 + Gradle
#   Flatpak (--user) -> IntelliJ IDEA Community, Prism Launcher
#   MCreator (visual mod maker; not on Flathub) -> ~/Applications/MCreator
#   Starter templates -> ~/mods/
set -euo pipefail
source "$(dirname "$0")/lib.sh"

# --- JDK + Gradle via SDKMAN (needs only bash/curl/unzip/zip) ---------------
if [ ! -d "$HOME/.sdkman" ]; then
  log "Installing SDKMAN..."
  curl -fsS "https://get.sdkman.io" | bash
fi
set +u
# shellcheck source=/dev/null
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install java 21-tem || true      # Temurin 21: required for MC 1.20.5+
sdk install gradle || true
set -u

# --- IDE + launcher via user-level Flatpak ----------------------------------
if have flatpak; then
  flatpak remote-add --user --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo
  flatpak install --user -y flathub com.jetbrains.IntelliJ-IDEA-Community || warn "IDEA install failed"
  flatpak install --user -y flathub org.prismlauncher.PrismLauncher || warn "Prism install failed"
else
  warn "flatpak missing (unexpected on SteamOS/Bazzite); skipping IDE/launcher."
fi

# --- MCreator — the no-code first rung (#65) --------------------------------
# Not on Flathub; the shared installer holds the version pin + sha256 and
# installs the official self-contained build per-user (here: whoever runs
# bootstrap). On Bazzite the apps service does this for every user instead.
# Via `bash` so it also works from a checkout with lost exec bits (zip dl).
bash "$(dirname "$0")/../common/bin/lacos-install-mcreator" || warn "MCreator install failed"

# --- Mod starter templates ---------------------------------------------------
MODS="$HOME/mods"
mkdir -p "$MODS"
if [ ! -d "$MODS/fabric-example-mod" ]; then
  git clone https://github.com/FabricMC/fabric-example-mod "$MODS/fabric-example-mod"
fi
if [ ! -d "$MODS/neoforge-mdk" ]; then
  git clone https://github.com/NeoForgeMDKs/MDK-1.21-NeoGradle "$MODS/neoforge-mdk" \
    || warn "NeoForge MDK clone failed — check current MDK repo name for your target MC version."
fi

log "Smoke test (downloads Gradle wrapper + deps, takes a while):"
log "  cd ~/mods/fabric-example-mod && ./gradlew build"
log "See templates/MODDING.md for the workflow."
