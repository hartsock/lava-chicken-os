# `lacos setup` — the 2nd-boot setup wizard (spec)

The OS image ships **generic** — no site particulars, no secrets. First boot does
the universal stuff (users, agent, boot sound, models, apps). **Everything
site-specific is a *second-boot* concern**, collected by an interactive wizard
that *interviews the box* — "Do you have Tailscale? A home DNS?" — and configures
from the answers. Run it when you're ready; nothing here is baked or automatic.

## Principles

- **2nd boot, owner-initiated.** Not first-boot, not the image. `lacos setup`.
- **Interview, don't assume.** Each capability is a yes/no gate; a "no" skips it
  cleanly. A machine with no home domain never sees a DNS question it must answer.
- **Idempotent + re-runnable.** Answers persist to `/etc/lava-chicken/site.conf`
  (KEY=VALUE, `0644`, **no secrets**); re-running pre-fills them. Secrets
  (Tailscale auth key) are used once and **not stored**.
- **Applies as it goes**, each step reversible/re-entrant. Stamps
  `/etc/lava-chicken/setup.done` when finished.

## The interview (conditional steps)

| Step | Question | If yes → applies |
|---|---|---|
| **Name** | Machine name? *(default `nugget`)* | `hostnamectl set-hostname`; writes `LAVA_BOX_NAME` |
| **Admin keys** | GitHub user for admin SSH keys? *(default: the primary user)* | refetch `github.com/<u>.keys` → root-owned `authorized_keys` |
| **Tailscale** | **Do you use Tailscale?** | install (rpm-ostree/official script), `tailscale up --accept-routes --hostname=<name>` — paste an **auth key** *or* open the login URL; `--accept-dns=false` if a home DNS is set |
| **Home DNS** | **Do you have a home DNS / custom LAN domain?** → domain (e.g. `home.arpa`) + your DNS server IP | systemd-resolved split-DNS drop-in routing `<domain>` → that server; prints the `dnsmasq` line to add on your DNS server |
| **Streaming** | Low-latency game streaming over WireGuard? | show this box's WG pubkey to add on the hub (`wg-add-peer.sh`); paste the peer config. (Sunshine itself is already set up — reminds you to pair once.) |
| **Kids** | Kid usernames + autologin target? *(default: none; e.g. `kid1 kid2`, autologin first)* | reconcile accounts + SDDM autologin |
| **Models** | Model set? *(default `qwen2.5-coder:7b` + `nomic-embed-text`)* | write `/etc/lava-chicken/models.conf`; `lacos models` |

Unknown/`no` answers are recorded so a re-run doesn't re-ask what you've settled.

## Delivery

- **Command:** `lacos setup` (whiptail/dialog TUI; plain-`read` fallback headless).
- **Desktop launcher:** "Set up LaCOS" on the admin desktop.
- **Nudge:** if `setup.done` is absent, a login MOTD / notification says
  *"Run `lacos setup` to finish configuring this box."* — never auto-runs.
- **Remote:** works over SSH (the admin shells in and runs it) — matching the
  "day-zero remote" story; secrets are typed into the owner's own session.

## How this maps to the roadmap

This wizard is the **delivery mechanism for site-specific setup** (Tailscale,
split-DNS, streaming): each becomes an optional wizard *step*, and the cross-host
DNS line is one the wizard **prints for you to apply** on your own DNS server. The
wizard keeps the image free of any one network's particulars.

## Out of scope (for the first cut)

- No unattended/answer-file mode (interactive only; a `site.conf` seed can come later).
- No auto-detection of Tailscale/DNS — it *asks*; detection is a nicety, not v1.
- Secrets never persist to disk beyond what the underlying tool stores itself
  (e.g. Tailscale's own state).
