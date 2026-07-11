#!/usr/bin/env bash
# Runs INSIDE the Containerfile build. Bakes the SYSTEM layer only — no network
# calls, no per-user state (that's first-boot's job). The shared payload was
# synced to /usr/share/lava-chicken by CI before build.
set -euo pipefail
PAY=/usr/share/lava-chicken
echo "[lava-chicken build] baking system layer for user '${LAVA_GITHUB_USER:-hartsock}'"

# Record the GitHub username the box pulls SSH keys from at first boot.
mkdir -p "$PAY"
echo "${LAVA_GITHUB_USER:-hartsock}" > "$PAY/github-user"
# Box + agent name (default nugget; e.g. kajiblet). Sets hostname + agent identity.
echo "${LAVA_BOX_NAME:-nugget}" > "$PAY/box-name"
# VERSION is synced into $PAY by CI; also surface it for `bootc`/support.
[ -r "$PAY/VERSION" ] && install -D -m0644 "$PAY/VERSION" /etc/lava-chicken/version || true

# Payload executables must be executable in the image.
chmod +x "$PAY"/provision/*.sh "$PAY"/bin/* "$PAY"/libexec/* 2>/dev/null || true

# bootc-image-builder depsolves the image's dnf repos when generating the ISO/
# qcow2; Bazzite's Terra repos reference GPG keys not present in the image, which
# breaks the depsolve ("Failed to retrieve GPG key for repo 'terra-mesa'"). Drop
# them — a bootc image updates by rebasing (not dnf), and mesa is already baked in.
rm -f /etc/yum.repos.d/terra*.repo || true

# aplay for the pre-session boot sound (Bazzite may already ship alsa-utils).
rpm-ostree install --idempotent alsa-utils 2>/dev/null \
  || dnf install -y alsa-utils 2>/dev/null || true

# --- Plymouth boot splash (nugget + "Lava Chicken OS") ----------------------
# Install the theme and make it the default. Regenerating the initramfs (-R) in
# a bootc build depends on dracut being available here. VERIFY on a real build;
# if -R can't run at build time, a first-boot `plymouth-set-default-theme -R` or
# an initramfs rebuild in the image pipeline is the fallback.
if [ -d "$PAY/plymouth/lava-chicken" ]; then
  install -d -m0755 /usr/share/plymouth/themes/lava-chicken
  cp -f "$PAY"/plymouth/lava-chicken/* /usr/share/plymouth/themes/lava-chicken/
  plymouth-set-default-theme -R lava-chicken 2>/dev/null \
    || plymouth-set-default-theme lava-chicken 2>/dev/null \
    || echo "[lava-chicken build] VERIFY: set plymouth theme + rebuild initramfs on-box"
fi

# Place payload files into their system locations.
install -D -m0644 "$PAY/sysusers/nugget.conf"            /usr/lib/sysusers.d/nugget.conf
install -D -m0644 "$PAY/tmpfiles/lava-chicken.conf"      /usr/lib/tmpfiles.d/lava-chicken.conf
install -D -m0644 "$PAY/polkit/50-nugget-tui.rules"      /etc/polkit-1/rules.d/50-nugget-tui.rules
install -D -m0644 "$PAY/desktop/nugget-agent.desktop"    /usr/share/applications/nugget-agent.desktop
install -D -m0755 "$PAY/libexec/nugget-grant-tui"        /usr/libexec/nugget-grant-tui
install -D -m0755 "$PAY/bin/nugget-agentctl"             /usr/bin/nugget-agentctl
install -D -m0755 "$PAY/bin/lacos"                       /usr/bin/lacos
install -D -m0755 "$PAY/bin/nugget"                      /usr/bin/nugget
# lacos-pull-models / lacos-install-apps / lacos-setup already live under
# $PAY/bin (= /usr/share/lava-chicken/bin) from the payload sync — no install
# needed (installing onto themselves errors "same file"). The units + find_bin
# reference them there directly.
install -D -m0644 "$PAY/desktop/lacos-setup.desktop"     /usr/share/applications/lacos-setup.desktop
install -D -m0644 "$PAY/profile.d/lava-chicken.sh"       /etc/profile.d/lava-chicken.sh
# Default wallpaper: bake to a standard KDE location + a first-login autostart
# that applies it once (so it's the default for every user, incl. the kids).
[ -r "$PAY/brand/wallpaper.png" ] && install -D -m0644 "$PAY/brand/wallpaper.png" /usr/share/wallpapers/lava-chicken/wallpaper.png
install -D -m0644 "$PAY/autostart/lava-chicken-wallpaper.desktop" /etc/skel/.config/autostart/lava-chicken-wallpaper.desktop
for u in lava-chicken-boot-sound.service nugget-agent-tmux.service nugget-agent-grant@.service \
         lava-chicken-models.service lava-chicken-apps.service; do
  install -D -m0644 "$PAY/systemd/$u" "/usr/lib/systemd/system/$u"
done

# Enable system services.
#  - sshd + firstboot: enabled directly (their /etc symlinks are committed).
#  - boot-sound + nugget-agent-tmux: via the baked 80-lava-chicken.preset, which
#    `systemctl preset` applies here (preferred over enable for baked units).
systemctl enable sshd.service
systemctl enable lava-chicken-firstboot.service
systemctl preset lava-chicken-boot-sound.service nugget-agent-tmux.service \
  lava-chicken-models.service lava-chicken-apps.service 2>/dev/null || true

# --- LaCOS branding in os-release (neofetch / `cat /etc/os-release` flex) ----
# Rebrand PRETTY_NAME + add LaCOS fields; keep ID (Bazzite-derived) so nothing
# downstream breaks. /usr/lib/os-release is the source; /etc/os-release links it.
OSR=/usr/lib/os-release
[ -f "$OSR" ] || OSR=/etc/os-release
if [ -f "$OSR" ]; then
  sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="Lava Chicken OS (LaCOS)"/' "$OSR" || true
  grep -q '^VARIANT_ID=lacos' "$OSR" || {
    printf 'VARIANT="Lava Chicken OS"\nVARIANT_ID=lacos\nLACOS_VERSION="%s"\n' \
      "$(cat "$PAY/VERSION" 2>/dev/null || echo 0.0.1)" >> "$OSR"
  }
fi

echo "[lava-chicken build] system layer done"
