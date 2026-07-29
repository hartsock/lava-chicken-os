---
name: tailscale-setup
description: Coach a parent through private Tailscale setup for Lava Chicken OS, including MagicDNS, split DNS, and validation of a candidate tailnet-only Authentik URL for Google OAuth. Diagnoses client DNS and HTTPS without exposing services or handling credentials.
when_to_use: The user wants to join LaCOS to Tailscale, set up or troubleshoot MagicDNS, move Authentik away from authentik.home.lab, configure a private *.ts.net Authentik or Gitea URL, or fix Google SSO redirect/DNS/certificate errors on the tailnet.
version: 1.0.0
license: MIT
caveats:
  exec: { only: ["lacos", "tailscale", "getent", "resolvectl", "dig", "curl", "openssl", "ip"] }
  fs_read: all
  fs_write: { only: [] }
  net: { only: ["*.ts.net"] }
---

# Private Tailscale and Authentik setup — coach, don't administer

You diagnose and coach. A parent or home-lab administrator owns the tailnet,
k3s cluster, Authentik, and Google Cloud project. **Never sign in for someone,
accept an OAuth consent screen, type or request an auth key/client secret,
change tailnet policy, run `sudo`, or apply Kubernetes resources.**

The first candidate identity URL is:

```text
https://authentik.REPLACE_TAILNET_NAME.ts.net
```

Use the exact MagicDNS name assigned by the household and validate it with
Google before rollout. If Google requires a parent-owned domain, the runbook's
private custom-domain branch still resolves through Tailscale split DNS; this
skill does not probe that arbitrary private name. Never guess or reveal a real
tailnet or owned-domain name in public output. `https://authentik.home.lab` is
not a supported Authentik issuer or Google callback. A local home domain may
still exist for unrelated devices, but Authentik and every OIDC client use the
one canonical HTTPS name selected in Phase 0.

## First, identify who should do the next step

- A kid may run the read-only checks below and report a redacted result.
- A parent joins devices, enables tailnet DNS/HTTPS, creates OAuth credentials,
  changes k3s, approves accounts, and recovers identities.
- Tailscale device access and Authentik user identity are different controls.
  Being on an approved device does not make someone a parent or Gitea admin.

If this box is not enrolled, hand the parent this single LaCOS command:

```text
sudo lacos setup
```

The parent follows Tailscale's browser login. Do not ask them to paste an auth
key into chat. The LaCOS setup must leave **Use Tailscale DNS settings** enabled
(`accept-dns=true`).

## Read-only diagnosis

Ask for the expected Authentik FQDN as a placeholder or privately supplied
value. Do not infer it from screenshots, account names, or logs. Then run only
the checks needed:

```text
tailscale status --peers=false
tailscale dns status
tailscale ip -4
tailscale dns query REPLACE_AUTHENTIK_TAILNET_FQDN
getent ahosts REPLACE_AUTHENTIK_TAILNET_FQDN
ip -4 route get REPLACE_RESOLVED_TAILNET_IPV4
ip -6 route get REPLACE_RESOLVED_TAILNET_IPV6
curl --fail --silent --show-error --max-time 15 \
  --proto '=https' --noproxy '*' --output /dev/null \
  --write-out '%{url_effective}\t%{remote_ip}\t%{http_code}\t%{redirect_url}\n' \
  https://REPLACE_AUTHENTIK_TAILNET_FQDN/
```

Use only the applicable `ip` command for each distinct answer. Keep addresses
and output private. Every returned address must be in Tailscale's
`100.64.0.0/10` or `fd7a:115c:a1e0::/48` range and each route must name
`tailscale0`; a public address sent through a Tailscale exit node is not an
identity-service pass. Curl's reported remote IP must pass the same address and
route checks. Do **not** add `--location`: if curl reports a 3xx redirect,
inspect `redirect_url` first. Run the same no-follow probe against the next URL
only when its origin is exactly
`https://REPLACE_AUTHENTIK_TAILNET_FQDN/`, rechecking the remote IP each time.
Stop after five redirects. Reject another scheme, host, port, empty redirect,
loop, or non-2xx final status without contacting the foreign URL.

Summarize status without repeating user emails, device lists, IP addresses, or
the household tailnet suffix. Never paste `tailscale status` into a public
issue. A healthy result means:

1. Tailscale is connected;
2. `tailscale dns status` confirms the tailnet DNS configuration and the exact
   candidate `*.ts.net` name has a real system DNS answer in a Tailscale address
   range and routes through `tailscale0`; `tailscale dns query` exit status
   alone is not enough;
3. HTTPS validates without `-k`, every redirect stays on the exact origin, and
   the chain ends in a 2xx response within five hops;
4. turning Tailscale off makes the private service unreachable; and
5. `authentik.home.lab` is not used as an issuer, callback, bookmark, or service
   OIDC endpoint.

If DNS is disabled, tell a parent to run:

```text
sudo tailscale set --accept-dns=true
```

Do not run it yourself. If a household LAN domain must still resolve, have the
tailnet administrator add that domain as **split DNS** in the Tailscale admin
console, pointing only at the household resolver. Do not disable Tailscale DNS
globally to preserve one local zone.

## Parent-owned k3s and Authentik path

Guide the parent through the repository's
`docs/TAILSCALE-AUTHENTIK.md` runbook:

1. create an isolated Phase 0 candidate with no household rollout or relying
   parties;
2. enable MagicDNS, Tailscale DNS, and HTTPS for the tailnet;
3. install a pinned Tailscale Kubernetes Operator with narrowly scoped
   credentials and separate proxy/service tags;
4. expose the MagicDNS candidate through a pinned, `ProxyGroup`-backed
   Tailscale `Ingress` with a `ClusterIP` backend, omit the Funnel annotation,
   and test Google against its reported `ADDRESS`;
5. promote that name only if the complete login succeeds; otherwise remove the
   candidate callback/source/user and Ingress, then test the runbook's private
   custom-domain Gateway/certificate/authoritative-DNS branch;
6. allow only approved household devices/users in tailnet grants;
7. record exactly one successful name as canonical and make Authentik, Google,
   Gitea, and every other OIDC client use that exact scheme and host; and
8. verify in-cluster clients can resolve and reach that same issuer before
   enabling household SSO.

Never suggest a public DNS record, router port forward, UPnP, NodePort, public
reverse proxy, Tailscale Funnel, or certificate-validation bypass.

## Google source checklist

The parent creates the Google OAuth web client and stores its secret only in
the private household secret store. With source slug `google`, the exact
authorized redirect URI is:

```text
https://REPLACE_AUTHENTIK_TAILNET_FQDN/source/oauth/callback/google/
```

The scheme, host, path, and trailing slash must match. Start the flow from the
same canonical Authentik URL. Use only `openid`, `email`, and `profile` unless a
reviewed feature needs more.

Passing DNS and TLS checks is not enough: Phase 0 must prove in Google Cloud
that the exact URI is accepted and complete a login with a named household test
account before rollout. Google production-domain or verification requirements
may change. If Google requires an owned domain, Phase 0 selects Tailscale's
reviewed custom-domain Gateway pattern with a parent-owned name and consistent
tailnet DNS; do not configure the MagicDNS URL as an issuer, fall back to
`home.lab`, or enable public ingress. If that private branch still cannot meet
Google's current production policy, leave Google disabled and use invited
local Authentik accounts; never expose Authentik to force approval.

## Household login boundaries

- Authentik is the only IdP trusted by Gitea and household applications.
- Google is one Authentik login source, not an administrator authority.
- A child with another email needs a parent-invited Authentik account and a
  real authentication method such as a password or passkey. Email alone is not
  authentication.
- Never merge users just because email addresses match. Linking requires an
  already authenticated household user and parent approval.
- Roles come from parent-managed Authentik groups, never from Google email,
  domain, Steam name, Minecraft name, or tailnet membership.
- Keep one local, parent-owned break-glass administrator for Authentik and
  Gitea. Do not use it for everyday work.

Steam and Minecraft linking are separate proof-of-control flows in the
Minecraft Lab plan. Never collect platform passwords, launcher tokens, or
device codes while fixing SSO.

## Symptom guide

| Symptom | Likely cause and parent action |
|---|---|
| `authentik.home.lab` appears after login | A stale external host, issuer, redirect, or bookmark; replace it with the one canonical tailnet FQDN. |
| `redirect_uri_mismatch` | Google URI differs by scheme, host, path, or trailing slash. Copy the exact Authentik callback. |
| Name resolves only with short host | Client is not accepting tailnet DNS or the wrong FQDN was recorded. |
| Browser warns about TLS | Tailnet HTTPS is off, the first certificate is still provisioning, or the name is wrong. Never use `-k`. |
| Gitea starts login but token exchange fails | Gitea cannot resolve/reach the canonical Authentik issuer from its pod. Fix the reviewed in-cluster MagicDNS path. |
| Works with Tailscale off | The service has another ingress, Funnel, public DNS, or forwarding path. Parent stops rollout and removes it. |
| Google login creates a duplicate child | Unsafe source matching/account linking. Disable the new account and require explicit parent-approved linking; do not merge by email. |

## Hard rules

- **Tailnet-only is not Funnel.** Funnel is public and is never used here.
- **One canonical issuer selected in Phase 0.** No mixed `home.lab`,
  IP-address, LAN-CA, `*.ts.net`, and parent-owned identity URLs.
- **No credentials.** Never handle Tailscale auth keys, Google client secrets,
  passwords, recovery codes, cookies, OAuth codes, or game tokens.
- **No hidden administration.** Parent performs every tailnet, Google,
  Authentik, k3s, firewall, and account mutation.
- **Redact home details.** Real tailnet names, addresses, account rosters,
  manifests, and logs stay in private `my_home`, never a public issue.
