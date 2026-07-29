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
  (KEY=VALUE, `0644`, **no secrets**); re-running pre-fills them. Tailscale
  enrollment uses the owner's browser and never asks for an auth key.
- **Applies as it goes**, each step reversible/re-entrant. It stamps
  `/etc/lava-chicken/setup.done` only when every blocking readiness check
  passes; a pending Tailscale enrollment, invalid DNS answer, or failed child
  account provisioning removes a stale stamp and exits nonzero.

## The interview (conditional steps)

| Step | Question | If yes → applies |
|---|---|---|
| **Name** | Machine name? *(default `nugget`)* | `hostnamectl set-hostname`; writes `LAVA_BOX_NAME` |
| **Admin keys** | GitHub user for admin SSH keys? *(default: the primary user)* | refetch `github.com/<u>.keys` → root-owned `authorized_keys` |
| **Tailscale** | **Do you use Tailscale?** | install (rpm-ostree/official script), open browser enrollment with unflagged `tailscale up`, apply only the intended deltas with `tailscale set --accept-routes=true --accept-dns=true --hostname=<name>`, then verify connection and DNS before recording success; optionally require the canonical Authentik FQDN to resolve to an address routed through `tailscale0` and pass same-host HTTPS |
| **Home DNS** | **Do you have a home DNS / custom LAN domain?** → domain (e.g. `home.arpa`) + your DNS server IP | validates a qualified DNS zone and a routable resolver before changing systemd-resolved; prints the local `dnsmasq` and matching Tailscale split-DNS actions, and requires an off-LAN tailnet test |
| **Streaming** | Low-latency game streaming over WireGuard? | show this box's WG pubkey to add on the hub (`wg-add-peer.sh`); paste the peer config. (Sunshine itself is already set up — reminds you to pair once.) |
| **Kids** | Kid usernames + autologin target? *(default: none; e.g. `kid1 kid2`, autologin first)* | reconcile accounts + SDDM autologin |
| **Models** | Model set? *(default `qwen2.5-coder:7b` + `nomic-embed-text`)* | write `/etc/lava-chicken/models.conf`; `lacos models` |

Unknown/`no` answers are recorded so a re-run doesn't re-ask what you've settled.

> **Kid accounts must stay standard — never "Administrator."** Set kids up here
> (or leave them to first boot), *not* through KDE System Settings → Users: that
> panel's **Administrator** toggle silently drops the account into `wheel` (sudo),
> which also cascades into resident-agent access ([#53](https://github.com/hartsock/lava-chicken-os/issues/53)).
> Passwordless kid login comes from the `nopasswdlogin` group, **not** from admin.
> `lacos doctor` flags any kid found in `wheel`/`nugget-tui`; `sudo lacos doctor --fix` revokes it.

### Canonical identity DNS

When the household uses Authentik, start by testing the HTTPS MagicDNS name
assigned through the tailnet, for example:

```text
https://authentik.REPLACE_TAILNET_NAME.ts.net
```

Google compatibility is a gate, not an assumption. If Google requires a domain
the parent owns, the runbook selects its private custom-domain Gateway and
Tailscale split-DNS branch instead. Do not use `authentik.home.lab` as an
issuer, Google callback, service endpoint, or fallback alias. Every client
keeps Tailscale DNS enabled so browsers, Gitea, and the other OIDC clients
agree on the one selected issuer and certificate without making Authentik
public.

The optional wizard probe rejects the legacy `home.lab` identity suffix. It
requires at least one system DNS answer, requires every answer to be in
Tailscale's IPv4 or IPv6 address range and routed through `tailscale0`, then
connects without a proxy and checks that curl's actual remote IP is also a
tailnet address routed through `tailscale0`. Redirects are not followed
automatically: the wizard validates each `Location` against the exact canonical
HTTPS origin before making the next request, rechecks every remote IP, and
requires a 2xx response within five hops. This rules out a public address
merely routed through a Tailscale exit node or hidden in a redirect chain. A
successful `tailscale dns query` exit by itself is not treated as proof of a
working private route.

A split-DNS server for a separate `home.arpa`-style zone must itself be a
tailnet node or be reachable through an approved subnet route and grant. Test
the zone from a tailnet client that is not on the household LAN; an RFC1918
resolver address in the admin console is not sufficient by itself. The wizard
rejects `ts.net` and its subdomains as a custom LAN zone so that this step
cannot shadow MagicDNS. Choosing **no** reconciles that choice by removing the
LaCOS-managed systemd-resolved LAN drop-in and clearing both saved LAN values.
The managed-file write/removal, resolver restart, and saved-state update are
all checked; any failure leaves setup incomplete and tells the parent to rerun
instead of claiming success.

The wizard joins this machine to the tailnet. It does **not** administer the
tailnet, deploy Authentik, create Google credentials, or enroll children. A
parent follows [Private Tailscale, Authentik, and household SSO](TAILSCALE-AUTHENTIK.md)
for that work, or asks Nugget for “help me set up Tailscale” to invoke the
read-only `tailscale-setup` coaching skill.

## Delivery

- **Command:** `lacos setup` (whiptail/dialog TUI; plain-`read` fallback headless).
- **Desktop launcher:** "Set up LaCOS" on the admin desktop.
- **Nudge:** if `setup.done` is absent, a login MOTD / notification says
  *"Run `lacos setup` to finish configuring this box."* — never auto-runs.
- **Remote:** works over SSH (the admin shells in and runs it) — matching the
  "day-zero remote" story; Tailscale authorization stays in the owner's browser.

## How this maps to the roadmap

This wizard is the **delivery mechanism for site-specific setup** (Tailscale,
split-DNS, streaming): each becomes an optional wizard *step*, and the
cross-host DNS lines are ones the wizard **prints for you to apply** on your own
DNS server and tailnet. The wizard keeps the image free of any one network's
particulars.

## Out of scope (for the first cut)

- No unattended/answer-file mode (interactive only; a `site.conf` seed can come later).
- No auto-detection of Tailscale/DNS — it *asks*; detection is a nicety, not v1.
- Secrets never persist to disk beyond what the underlying tool stores itself
  (e.g. Tailscale's own state).
