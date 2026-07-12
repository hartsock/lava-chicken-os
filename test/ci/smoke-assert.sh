#!/usr/bin/env bash
# L1b — in-guest health smoke for a booted LaCOS VM (run over SSH by test-boot.yml).
#
# Proves the baked LaCOS SYSTEM layer is healthy WITHOUT waiting on the slow,
# networked first-boot to finish. first-boot (lava-chicken-firstboot.service)
# pulls GitHub keys, installs newt, pulls ollama models and rpm-ostree-layers
# apps — networked, minutes long, and it can stage a new deployment / reboot and
# drop our SSH session. So this tier asserts ONLY image-baked, non-networked
# facts and treats a still-churning (or even failed) first-boot as out of scope.
#
# Runs as cismoke, who has a CI-only NOPASSWD sudoers drop-in (vm-user.toml.tmpl),
# so root-only queries (bootc status, root journalctl) work over the BatchMode
# SSH pipe.
#
# Fail-fast, one clear message per check, with diagnostics dumped on failure so a
# red CI run is debuggable from the log alone. The final 'L1b smoke: ALL PASS'
# line is a COMPLETION SENTINEL the caller greps for — an empty/truncated copy of
# this script must not be able to false-pass on a bare exit 0.
set -uo pipefail

fail() {
  echo "FAIL: $*" >&2
  echo "----- diagnostics (failed units, recent errors) -----" >&2
  # cismoke has NOPASSWD sudo; use it so the diagnostics are actually populated
  # (a non-root journalctl only sees its own messages).
  sudo systemctl --failed --no-legend 2>/dev/null >&2 || true
  sudo journalctl -b -p err --no-pager 2>/dev/null | tail -n 40 >&2 || true
  exit 1
}
ok() { echo "PASS: $*"; }

# 1. os-release rebranded to Lava Chicken OS (matches PRETTY_NAME or VARIANT,
#    both written by bazzite/build.sh into /usr/lib/os-release -> /etc/os-release).
grep -Eq '="?Lava Chicken OS' /etc/os-release \
  || fail "os-release not rebranded to Lava Chicken OS"
ok "os-release branded: $(. /etc/os-release; echo "$PRETTY_NAME")"

# 2a. lacos: installed, executable, and actually runs. SAFE to execute — the
#     `version` subcommand just cats /etc/lava-chicken/version and exits 0.
[ -x /usr/bin/lacos ] || fail "/usr/bin/lacos missing or not executable"
lv=$(/usr/bin/lacos version 2>&1) || fail "lacos version exited nonzero: $lv"
ok "lacos version -> $lv"

# 2b. nugget: present + executable ONLY. Do NOT run it — its last line is
#     `exec newt --full-access ...`, which launches the resident agent and hangs.
[ -x /usr/bin/nugget ] || fail "/usr/bin/nugget missing or not executable"
bash -n /usr/bin/nugget || fail "/usr/bin/nugget failed bash -n syntax check"
ok "/usr/bin/nugget present (not executed by design)"

# 3. Booted an ostree/bootc deployment. Two independent signals:
#    (a) ROOT-FREE: /run/ostree-booted exists and the kernel cmdline carries an
#        ostree= root — this alone proves a bootc/ostree deployment booted, and
#        needs no privilege.  (b) bootc's own view of the booted image, via
#        `sudo bootc status` — bootc status REQUIRES root (bootc-dev/bootc#409),
#        which cismoke's NOPASSWD drop-in provides. Prefer the JSON parse over
#        grepping human text (schema is stabler than the pretty output).
[ -f /run/ostree-booted ] \
  || fail "/run/ostree-booted absent — not an ostree/bootc deployment boot"
grep -q 'ostree=' /proc/cmdline \
  || fail "/proc/cmdline lacks ostree= (image did not boot via an ostree deployment)"
ok "ostree deployment booted (/run/ostree-booted + ostree= on cmdline)"

command -v bootc >/dev/null 2>&1 || fail "bootc not on PATH"
sudo bootc status >/dev/null 2>&1 || fail "sudo bootc status errored"
sudo bootc status --format json 2>/dev/null | python3 -c '
import json,sys
d=json.load(sys.stdin)
booted=(d.get("status",{}) or {}).get("booted") or {}
img=(booted.get("image") or {}).get("image")
sys.exit(0 if img else 1)' || fail "bootc reports no booted image"
ok "bootc: booted image present"

# 4. systemd health is INFORMATIONAL ONLY in this tier. 'degraded'/'starting' is
#    EXPECTED here — first-boot is a long networked oneshot and optional units may
#    still be inactive. We deliberately do NOT gate on lava-chicken-firstboot's
#    result: its sub-steps (Sunshine firewall, ollama/newt download, rpm-ostree
#    app layering) are networked and fragile inside an ephemeral slirp-NAT CI VM,
#    so a firstboot failure/churn here says nothing about the IMAGE LAYER this
#    tier asserts. First-boot completion is Tier 2's job (see footer).
state=$(systemctl is-system-running 2>/dev/null || true)
echo "INFO: systemctl is-system-running = ${state:-unknown} (degraded/starting is OK mid-firstboot)"
sudo systemctl --failed --no-legend 2>/dev/null || true
fbstate=$(systemctl is-failed lava-chicken-firstboot.service 2>/dev/null || true)
echo "INFO: lava-chicken-firstboot.service state = ${fbstate:-unknown} (NOT gated in L1b — networked, may still be running or have flaked on CI NAT)"

# 5. The units that MUST be baked + statically enabled (they run day zero,
#    independent of first-boot): firstboot itself and key-only sshd. THIS is the
#    image-layer guarantee that replaces the old runtime first-boot gate.
for u in lava-chicken-firstboot sshd; do
  systemctl cat "${u}.service" >/dev/null 2>&1 || fail "${u}.service not installed"
  systemctl is-enabled --quiet "${u}.service" || fail "${u}.service not enabled"
  ok "${u}.service present + enabled"
done

# 6. The remaining baked units must at least be INSTALLED (they are preset-enabled
#    in build.sh; presence is the image-layer guarantee, activation is runtime).
for u in nugget-agent-tmux lava-chicken-boot-sound lava-chicken-models lava-chicken-apps; do
  systemctl cat "${u}.service" >/dev/null 2>&1 || fail "${u}.service not installed"
  ok "${u}.service installed"
done

# 7. The nugget SYSTEM user is baked via /usr/lib/sysusers.d/nugget.conf (created
#    at boot by systemd-sysusers, NOT by first-boot), so it is safe to assert here.
id nugget >/dev/null 2>&1 || fail "nugget system user missing (sysusers.d not applied)"
ok "nugget system user present"

# COMPLETION SENTINEL — the caller greps for this exact line. Reaching it means
# every check above ran and passed; an empty/truncated script cannot emit it.

# ── firstboot must COMPLETE (#27/#29) ────────────────────────────────────────
# The v0.0.1 wedge (firstboot hung forever, no stamp, re-hang every boot) sailed
# through CI because nothing waited for provisioning. Steps are now
# timeout-bounded and always stamp, so CI can require convergence.
echo "--- waiting for first-boot provisioning to complete (max 8 min) ---"
fb_ok=0
for i in $(seq 1 96); do
  if [ -f /var/lib/lava-chicken/firstboot.done ]; then fb_ok=1; break; fi
  sleep 5
done
if [ "$fb_ok" != 1 ]; then
  echo "FAIL: firstboot.done never appeared — provisioning did not converge"
  sudo systemctl status lava-chicken-firstboot.service --no-pager | head -15 || true
  sudo journalctl -u lava-chicken-firstboot.service --no-pager | tail -40 || true
  exit 1
fi
echo "PASS: first-boot provisioning completed"
if [ -s /var/lib/lava-chicken/firstboot.failed-steps ]; then
  echo "FAIL: provisioning completed but steps FAILED: $(tr '\n' ' ' < /var/lib/lava-chicken/firstboot.failed-steps)"
  sudo journalctl -u lava-chicken-firstboot.service --no-pager | tail -60 || true
  exit 1
fi
echo "PASS: all provisioning steps succeeded"

# ── ollama is baked + serving (#28) ──────────────────────────────────────────
test -x /usr/bin/ollama || { echo "FAIL: /usr/bin/ollama not baked"; exit 1; }
ol_ok=0
for i in $(seq 1 24); do
  systemctl is-active ollama.service >/dev/null 2>&1 && { ol_ok=1; break; }
  sleep 5
done
[ "$ol_ok" = 1 ] || { echo "FAIL: ollama.service not active"; sudo journalctl -u ollama --no-pager | tail -20 || true; exit 1; }
curl -fsS --max-time 5 http://127.0.0.1:11434/api/version >/dev/null \
  && echo "PASS: ollama baked, active, answering on loopback" \
  || { echo "FAIL: ollama not answering on 127.0.0.1:11434"; exit 1; }

echo "L1b smoke: ALL PASS"

# ── OUT OF SCOPE for this tier (first-boot / networked — do NOT assert here) ──
#   primary human user + $HOME provisioning, `ollama list` model preload,
#   flatpak app layering, Sunshine pairing, /run/nugget/tmux.sock live session,
#   /var/lib/lava-chicken/firstboot.done stamp, AND first-boot success/failure.
#   Those belong to Tier 2 (acceptance, nightly), which is allowed to wait on
#   first-boot completion. Gating the boot smoke on them makes it slow + flaky.
