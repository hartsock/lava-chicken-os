# Private Tailscale, Authentik, and Household SSO

**Audience:** a parent or home-lab administrator

**Status:** pre-implementation operator blueprint and acceptance contract

**Scope:** tailnet-only Authentik for a household k3s cluster, Google sign-in,
invited child accounts, and OIDC for Gitea and other private services

**Last reviewed:** July 29, 2026

This runbook replaces `https://authentik.home.lab/` with one canonical,
tailnet-only HTTPS name resolved consistently through Tailscale DNS. The first
candidate is the name supplied by Tailscale MagicDNS:

```text
https://authentik.REPLACE_TAILNET_NAME.ts.net
```

Phase 0 below must prove Google accepts that exact callback. If Google requires
a domain the household owns, select the documented private custom-domain
branch instead. The exact tailnet suffix or owned name is private household
configuration. Do not commit it to this public repository, paste it into a
public issue, or copy another household's value.

The target is private:

```text
approved family device
  |
  | Tailscale + selected private DNS + HTTPS
  v
Selected private Tailscale Ingress / Gateway
  |
  +-- ClusterIP Authentik
  |     +-- invited local child accounts
  |     +-- Google OAuth source
  |     +-- parent-managed groups and OIDC providers
  |
  +-- ClusterIP Gitea and other household services

device outside the tailnet -------------------------------X
Tailscale Funnel / public ingress / router forwarding ----X
```

Tailscale controls which device can reach the private network. Authentik
controls which person can sign in and what applications that person may use.
Neither control replaces the other.

> **Current implementation boundary:** this document is the reviewed design
> contract for the Minecraft Lab Epic. The public repository does not yet ship
> a pinned Authentik stack, Tailscale Operator release bundle, or rendered
> `my_home` manifests. Pin and review those artifacts in the implementation
> phase before treating the command and manifest shapes below as deployable.

---

## 1. Non-negotiable design decisions

1. **One canonical Authentik URL selected in Phase 0.** Authentik, Google,
   Gitea, and every other OIDC client use the same exact scheme and host.
2. **Tailscale DNS stays enabled.** LaCOS clients join with
   `--accept-dns=true`. Household LAN zones are Tailscale split-DNS routes;
   clients do not opt out of tailnet DNS.
3. **No public application ingress.** Authentik and Gitea backends remain
   `ClusterIP` workloads exposed only by the selected private Tailscale
   `Ingress` or custom-domain Gateway. The owned-domain Gateway may use a
   `loadBalancerClass: tailscale` frontend; no ordinary/public LoadBalancer is
   allowed.
4. **No Funnel.** The `tailscale.com/funnel` annotation is absent. A value of
   `"false"` is not the policy; absence plus a policy test is.
5. **Authentik is the identity broker.** Applications trust Authentik, not
   Google directly.
6. **Email is not identity.** The household principal and OIDC subject are
   stable. Email addresses and display names may change.
7. **No open enrollment or email-based auto-merge.** A parent invites or
   approves each child and explicitly approves every external-account link.
8. **Local recovery remains possible.** Authentik and Gitea each retain a
   parent-owned break-glass administrator that is not used day to day.

Do not retain `authentik.home.lab` as a second issuer, callback, or alternate
login URL. Mixed hosts cause redirect, cookie, discovery, certificate, and
issuer validation failures. Retire old bookmarks and redirect the old name to
the new one only during a short, parent-run migration; then remove it.

### Phase 0: select exactly one Tailscale-resolved name

Before production deployment, household enrollment, or any relying-party
configuration, run an isolated candidate spike:

1. create a disposable candidate namespace/configuration, a separate Google
   test client, a parent break-glass account, and only the named supervised
   test user;
2. follow sections 4–9 to deploy the pinned Authentik candidate and obtain the
   exact `https://authentik.REPLACE_TAILNET_NAME.ts.net` Ingress address;
3. register that exact callback and complete the full Google round trip;
4. if it passes, record the MagicDNS name as canonical and promote the
   candidate only after backup and negative-exposure tests;
5. if Google rejects or cannot verify it, remove the candidate callback and
   source, remove the test user, tear down the candidate Ingress, then deploy
   and test Tailscale's reviewed custom-domain Kubernetes Gateway pattern with
   private authoritative DNS, Tailscale split DNS, and a parent-owned name;
6. record a name as canonical only after that branch completes the same login,
   issuer, in-cluster reachability, and negative-exposure tests.

The parent-owned-domain branch brings its own private Gateway, certificate, and
DNS design; a Tailscale L7 Ingress certificate for `*.ts.net` cannot serve that
name.

Both branches remain tailnet-only. Do not configure both hosts, use a bare DNS
alias, enable Funnel/public ingress, or treat `home.lab` as a fallback.
Domain-verification or ACME DNS-01 TXT records and Certificate Transparency
may reveal the generic hostname, but there must be no public A/AAAA/CNAME
service record or internet route.
Throughout this document, `REPLACE_AUTHENTIK_TAILNET_FQDN` means the one FQDN
selected here. Manifest examples that use a Tailscale L7 Ingress apply to the
MagicDNS branch; the owned-domain branch must use the pinned custom-domain
Gateway design.

---

## 2. Public/private repository boundary

Public `lava-chicken-os` may contain:

- this generic runbook;
- placeholder-only Kubernetes, Authentik blueprint, and policy examples;
- schema and negative-exposure tests;
- the `tailscale-setup` coaching skill;
- no live household values.

Private `my_home` owns:

- the real tailnet name, tags, groups, grants, and device policy;
- rendered Tailscale Operator, Authentik, Gitea, DNS, and NetworkPolicy
  configuration;
- Google client ID and secret;
- Authentik secret key, database credentials, recovery material, SMTP
  credentials, and bootstrap password;
- child email roster, parent approvals, groups, account-link records, audit
  evidence, and recovery evidence;
- real addresses, hostnames, certificates, logs, screenshots, and backups.

A suggested private layout is:

```text
my_home/
  clusters/home/
    tailscale/
      operator-values.example.yaml
      operator-values.local.yaml
      authentik-ingress.yaml
      gitea-ingress.yaml
      policy-notes.private.md
    identity/
      authentik-values.example.yaml
      authentik-values.local.yaml
      blueprints/
      networkpolicy/
    gitea/
  secrets/
    README.md
    plaintext/                 # ignored, mode 0700; optional staging only
  docs/
    identity-recovery.private.md
    identity-acceptance.private.md
```

The example files are secret-free. Local overlays, rendered output, and
evidence are ignored or encrypted. A public issue may record only a policy
version and pass/fail result.

---

## 3. Parent prerequisites

Have these before deployment:

- a household-owned Tailscale tailnet;
- a parent/admin account for its DNS, access controls, machines, and trust
  credentials;
- MagicDNS and tailnet HTTPS enabled;
- an existing private k3s cluster and confirmed `kubectl` context;
- Helm 3 and a durable storage plan;
- a reviewed, pinned Tailscale Kubernetes Operator chart and image set;
- a reviewed, pinned Authentik chart and image set;
- Kubernetes Secrets encryption at rest or a proven secret-injection design;
- an encrypted parent password manager and protected off-cluster recovery
  copy;
- a separate Google Cloud project for this household identity service;
- a genuinely external device/network for negative-exposure tests.

Do not reuse a Gmail API automation client as the Authentik Google OAuth
client. Create a separate web application client with only the identity scopes
required here.

---

## 4. Configure the tailnet first

### 4.1 Enable MagicDNS and HTTPS

In the Tailscale admin console:

1. open **DNS** and enable MagicDNS;
2. enable HTTPS certificate support for the tailnet;
3. keep the assigned tailnet DNS name private in `my_home`;
4. add any household resolver as split DNS for its exact private zone, such as
   `home.arpa`, rather than as a global resolver unless that is intentional;
5. make that resolver a tailnet node or expose it through an approved subnet
   route and grant, then test it from a tailnet client off the household LAN;
6. require approved devices and remove stale devices.

Every LaCOS client must report that it is accepting Tailscale DNS. The
parent-run repair command is:

```bash
sudo tailscale set --accept-dns=true
```

The LaCOS setup wizard now uses this setting by default.

### 4.2 Define purpose-specific tags and grants

Use separate, household-chosen tags for:

- the k3s operator;
- the ingress `ProxyGroup`;
- the private identity Tailscale Service;
- the private source-hosting Tailscale Service;
- optionally parent devices and child devices.

The operator tag may create only the proxy and service tags it owns. The
`ProxyGroup` tag identifies the proxies that advertise services; it is not the
per-application access target. Add narrowly scoped
`autoApprovers.services` entries so only that proxy tag can advertise the
identity and Gitea service tags. Tailnet grants should allow approved
household identities/devices to reach those service tags on TCP 443 and deny
everyone else by omission.

The private policy has this relationship:

```text
tag:REPLACE_OPERATOR_TAG
  owns -> tag:REPLACE_INGRESS_PROXY_TAG
  owns -> tag:REPLACE_IDENTITY_SERVICE_TAG
  owns -> tag:REPLACE_GITEA_SERVICE_TAG

autoApprovers.services
  tag:REPLACE_IDENTITY_SERVICE_TAG <- tag:REPLACE_INGRESS_PROXY_TAG
  tag:REPLACE_GITEA_SERVICE_TAG    <- tag:REPLACE_INGRESS_PROXY_TAG

grants
  approved household users/devices -> identity and Gitea service tags:tcp:443
```

Use the current policy schema and editor for the pinned operator release.
Do not derive a parent/admin application role from any Tailscale tag; it is a
network policy input only.

Keep the real policy private. Validate it in the Tailscale policy editor before
rollout. Do not start from an allow-all policy and call Authentik the network
boundary.

### 4.3 Create narrowly scoped operator credentials

Follow the current Tailscale Operator installation guide. The operator OAuth
client needs only the documented write scopes for Services, Devices/Core, and
Keys/Auth Keys, constrained by the operator tag.

Do not:

- create a reusable human auth key for the cluster;
- pass the OAuth secret on a recorded command line;
- place it in tracked Helm values;
- reuse the Google OAuth secret;
- grant all tailnet API scopes.

Create the credential through a parent session and inject it through the
secret mechanism reviewed for the pinned chart. Protect and rotate it as a
cluster credential.

---

## 5. Install the Tailscale Kubernetes Operator

Before installing:

1. vendor the stable chart version into private `my_home`;
2. record its SHA-256 and every rendered image digest;
3. inspect its CRDs, RBAC, ServiceAccounts, Secrets, hooks, and security
   contexts;
4. confirm the OAuth secret path supported by that exact chart;
5. render and policy-check the complete output;
6. require explicit confirmation of the kube context and node names.

The official Helm repository is:

```text
https://pkgs.tailscale.com/helmcharts
```

Do not use the unstable repository or a floating chart/image version for the
household identity path. The installed operator should create the `tailscale`
IngressClass but should not expose any application until its policy and
negative tests are ready.

For production ingress, use the current recommended high-availability
`ProxyGroup` model rather than a separate standalone proxy for every
application. The generic shape is:

```yaml
apiVersion: tailscale.com/v1alpha1
kind: ProxyGroup
metadata:
  name: household-ingress-proxies
spec:
  type: ingress
  replicas: 2
  tags:
    - "tag:REPLACE_INGRESS_PROXY_TAG"
```

The operator tag must own `REPLACE_INGRESS_PROXY_TAG`. The private tailnet
policy must also approve that proxy tag as an advertiser for each application
service tag. Do not enable a `ProxyClass` static-endpoint option: that can
create NodePort Services and is outside this private baseline.

On operator releases that support `ProxyGroupPolicy`, restrict the Authentik
and Gitea namespaces to the one approved ingress group so a workload cannot
select an arbitrary proxy group. Review and pin the exact admission-policy
behavior before relying on it.

Acceptance checks:

```bash
kubectl get namespace tailscale
kubectl --namespace tailscale get deployment,pod
kubectl get ingressclass tailscale
kubectl get crd | grep tailscale.com
```

Also verify in the private Tailscale Machines view that the operator has only
the intended tag. Keep output containing tailnet or device details private.

---

## 6. Deploy Authentik behind `ClusterIP`

Deploy Authentik and its supported database/cache dependencies using pinned
artifacts. Its HTTP service remains `ClusterIP`. Do not enable the chart's
ordinary public/LAN ingress, `LoadBalancer`, NodePort, host networking, or
router-facing proxy.

Create and protect:

- the Authentik secret key;
- database credentials;
- parent break-glass bootstrap credentials;
- SMTP credentials if invitation email is enabled;
- Google OAuth client credentials later in this runbook;
- signing/encryption and recovery material required by the pinned release.

Apply a namespace default-deny policy and add only:

- cluster DNS;
- Authentik-to-database/cache traffic;
- Authentik worker traffic documented by the pinned chart;
- the Tailscale ingress proxy to the Authentik HTTP service;
- required outbound HTTPS for Google OAuth token/user-info endpoints;
- narrowly scoped SMTP egress, when used;
- parent-controlled backup traffic.

Set `AUTHENTIK_LISTEN__TRUSTED_PROXY_CIDRS` for the pinned Authentik release to
the smallest stable CIDR set from which the approved Tailscale ingress proxies
actually connect. Authentik's RFC1918-wide defaults are too broad for this
threat model. When Kubernetes addressing makes a pod CIDR unavoidable, pair it
with a label/namespace-selected NetworkPolicy that permits ingress only from
the approved `ProxyGroup`; never use `0.0.0.0/0` or `::/0`.

Verify that the real ingress preserves the selected HTTPS host and client
address, then send spoofed forwarding headers from a disposable, unapproved
pod. That direct request must be blocked by NetworkPolicy or its proxy headers
must be ignored. Record the chosen CIDRs and test evidence privately.

First prove Authentik through a local parent-only port-forward. Create the
break-glass parent, store its recovery material, and take a protected backup
before exposing the service to the tailnet.

---

## 7. Expose Authentik only to the tailnet (MagicDNS candidate)

To test or promote the Phase 0 MagicDNS candidate, use this reviewed manifest
shape:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: authentik-tailnet
  namespace: authentik
  annotations:
    tailscale.com/proxy-group: "household-ingress-proxies"
    tailscale.com/tags: "tag:REPLACE_IDENTITY_SERVICE_TAG"
    # Required for the reviewed in-cluster MagicDNS/OIDC path. This Operator
    # feature is experimental, so pin and test its exact release.
    tailscale.com/experimental-forward-cluster-traffic-via-ingress: "true"
spec:
  ingressClassName: tailscale
  tls:
    - hosts:
        - authentik
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: REPLACE_AUTHENTIK_SERVICE
                port:
                  number: REPLACE_AUTHENTIK_HTTP_PORT
```

There is deliberately no `tailscale.com/funnel` annotation.

The service tag on this Ingress is the tailnet grant target. The separate
`ProxyGroup` tag authorizes the proxies to advertise that service through the
private `autoApprovers.services` policy.

After applying the private manifest, wait for the operator to publish the
address:

```bash
kubectl --namespace authentik get ingress authentik-tailnet
```

Record the exact `ADDRESS` as:

```text
REPLACE_AUTHENTIK_TAILNET_FQDN
```

Do not synthesize the suffix, assume the short name, or copy a value from this
guide. The Ingress may take time to provision its certificate on the first
connection.

From an approved tailnet client:

```bash
AUTHENTIK_FQDN="REPLACE_AUTHENTIK_TAILNET_FQDN"
resolvectl query "${AUTHENTIK_FQDN}"
curl --fail --silent --show-error --max-time 15 \
  --output /dev/null \
  "https://${AUTHENTIK_FQDN}/"
```

The request must validate without `curl -k`, a custom home CA, or a hosts-file
entry.

The generic `authentik` service label is intentional. Tailscale HTTPS
certificate names are recorded in public Certificate Transparency logs even
though the service remains unreachable outside the tailnet. Do not put a
child's name, street address, or another sensitive household fact in the
Ingress hostname or tailnet DNS name.

From a device with Tailscale disconnected, the same URL must be unreachable.
Also prove there is no:

- non-Tailscale Ingress for Authentik;
- public `LoadBalancer`, NodePort, or host port;
- Funnel annotation or CLI Funnel process;
- public A/AAAA record;
- router/NAT forward or UPnP mapping;
- globally routable IPv6 path.

---

## 8. Make the selected private name canonical

Set Authentik's external/browser URL according to the pinned Authentik release
so redirects, cookies, generated URLs, WebAuthn/passkey RP ID, and OIDC issuer
all use:

```text
https://REPLACE_AUTHENTIK_TAILNET_FQDN
```

Do not invent an environment variable from this planning guide; use the
supported setting documented by the exact pinned release and verify the
rendered result.

Acceptance:

1. opening a protected Authentik page never redirects to `home.lab`, an IP
   address, an internal Kubernetes name, or HTTP;
2. authentication cookies are Secure and scoped to the canonical host;
3. the OIDC discovery document advertises only the canonical host;
4. passkey setup, if used, records the intended tailnet RP ID;
5. logout and recovery links return to the same host.

Retire `authentik.home.lab` from DNS, ingress, proxy headers, bookmarks, Google
configuration, and OIDC clients after migration.

---

## 9. Configure Google as an Authentik source

### 9.1 Prove the callback is accepted before rollout

For Authentik source slug `google`, register this exact authorized redirect URI
on a Google OAuth **Web application**, substituting the candidate FQDN being
evaluated in Phase 0:

```text
https://REPLACE_AUTHENTIK_TAILNET_FQDN/source/oauth/callback/google/
```

The scheme, hostname, path, and trailing slash must match exactly. Google
requires HTTPS, a non-IP hostname, and a host suffix on the Public Suffix List.
Tailscale's `ts.net` is on that list, but Google may impose additional domain
ownership, branding, audience, or production-verification requirements.

Treat Google compatibility as a Phase 0 gate:

1. create a separate Google Cloud project;
2. configure an external audience when household Gmail accounts are used;
3. add only named parent/child test users while the app is in testing;
4. register the exact callback above;
5. request only `openid`, `email`, and `profile`;
6. start login from the candidate Authentik URL on a tailnet-connected browser;
7. complete authorization with one supervised household test account;
8. confirm the browser returns to the exact selected callback;
9. verify the resulting Authentik user and source subject;
10. only after success, record that FQDN as canonical with redacted pass/fail
    evidence in private `my_home`.

Do not claim rollout complete merely because Google saves the URI.

For a production audience, review Google's current OAuth domain-ownership and
brand-verification rules. If Google requires a domain the household owns,
Phase 0 must select Tailscale's reviewed custom-domain Gateway pattern with a
parent-owned HTTPS name and consistent tailnet DNS. Gate its certificate,
routing, and negative exposure exactly as strictly as the MagicDNS path. Do
not keep the failed `*.ts.net` candidate as an alternate issuer, create a bare
DNS alias, fall back to `home.lab`, or make Authentik public to satisfy OAuth.

The owned-domain branch proves DNS ownership and private routing; it does not
guarantee Google production approval. If current Google policy still requires
a public application/homepage or another condition the household will not
meet, fail the Google gate and leave that source disabled. Use invitation-only
local Authentik accounts until the policy can be met without exposing
Authentik or Gitea.

### 9.2 Configure the Authentik source safely

Create a Google OAuth source with slug `google` and the private client
credential. Bind it to a restricted household enrollment/authentication flow.

Policy requirements:

- no open self-enrollment;
- allow only a parent-maintained Google account allowlist or invitation/approval
  flow;
- set the Google source user matching mode to `email_deny` (or its reviewed
  current-release equivalent), never `email_link`;
- do not assign parent/admin groups from Google claims;
- do not merge or link users because email addresses match;
- retain Google's stable subject for the source identity;
- require an already authenticated household account and parent approval for
  a deliberate link;
- map `email_verified` from verified evidence rather than hardcoding it true;
- log create/link/unlink/deny decisions without tokens or authorization codes.

The Google client secret stays in the private secret system and is never
placed in Git, an issue, a screenshot, Nugget context, a shell-history
argument, or a generated LaCOS project.

---

## 10. Support children without Gmail

An arbitrary email address is a contact/login label, not proof that the person
owns the account. For a child who does not use Google:

1. a parent first checks the case-normalized address and intended username
   against active and disabled users;
2. the parent creates a short-lived, single-use Authentik invitation whose
   fixed data contains that email and a unique parent-chosen username;
3. an expression policy requires `invitation_in_effect`, compares submitted
   data to the invitation's fixed data, and denies a changed recipient;
4. Authentik's documented case-insensitive unique-email expression policy is
   bound before the User Write stage;
5. the User Write stage creates the account inactive in the child path;
6. an Email stage proves control of the fixed recipient and activates the
   account only on success;
7. the child creates a local password or passkey under parent supervision;
8. the account enters only the child baseline group;
9. the parent explicitly assigns each application group later.

Authentik does not require unique email addresses by default. Email sign-in is
allowed only after the pinned enrollment, profile-edit, and administrator
flows all enforce the same case-insensitive uniqueness policy. Configure the
Identification stage for case-insensitive email/username matching and never
let an unreviewed flow bypass the policy. Serialize parent-issued enrollment
and audit immediately after User Write because a policy check is not a
database uniqueness constraint.

If the pinned release cannot enforce fixed-recipient verification and
case-insensitive uniqueness on every write path, use Authentik's unique
username for local sign-in and keep email as a parent-managed contact field.
Do not claim arbitrary-email sign-in is supported in that deployment.

Negative tests must cover:

- an active or disabled account already using the same email with different
  case;
- an expired invitation;
- replay of a consumed invitation;
- changing the invitation's fixed email or using it as the wrong recipient;
- profile editing to another user's email;
- revoking the account while an invitation or verification token remains
  outstanding.

Do not publish an enrollment URL, create a shared family password, or give
children the Authentik admin interface. Parent and child accounts are separate.

Recommended groups:

```text
household-users
household-parents
household-kids
gitea-users
gitea-parents
minecraft-players
minecraft-source-contributors
```

Groups are local authorization facts. Google domain, tailnet membership, email
domain, Steam name, and Minecraft name never grant a parent role.

---

## 11. Connect Gitea and other services to Authentik

Create a separate Authentik Application and confidential OIDC provider for
each service. Use:

- one exact callback per service;
- Authentik's default per-provider issuer mode;
- Authorization Code flow;
- minimal scopes;
- short sessions appropriate for children;
- a required application claim derived only from parent-managed local groups;
- no wildcard redirects;
- no shared client secret between services.

For Gitea, the reviewed contract is:

```text
Gitea URL:
  https://REPLACE_GITEA_TAILNET_FQDN

Gitea callback:
  https://REPLACE_GITEA_TAILNET_FQDN/user/oauth2/authentik/callback

Authentik discovery:
  https://REPLACE_AUTHENTIK_TAILNET_FQDN/application/o/gitea/.well-known/openid-configuration

Authentik issuer:
  https://REPLACE_AUTHENTIK_TAILNET_FQDN/application/o/gitea/

Required claim:
  gitea_access = member
```

Gitea uses native OIDC, not browser forward-auth alone. Configure:

- an Authentik mapping that emits the literal `gitea_access=member` only for
  the local, parent-managed `gitea-users` group;
- Gitea's exact required claim name/value as `gitea_access` / `member`;
- external auto-registration only when that claim is present;
- Gitea automatic account linking off;
- parent-only site/organization administration;
- child accounts as ordinary restricted users;
- one local break-glass Gitea administrator;
- no role elevation from Google claims;
- no open registration, public repositories, mirrors, webhooks, or Actions for
  the initial Minecraft Lab policy.

Browser SSO does not authenticate Git SSH or Git HTTPS. Give each child a
separate SSH key or scoped Gitea token through a parent-owned enrollment flow.
Offboarding must disable the Gitea account and revoke its sessions, tokens, and
SSH keys in addition to disabling Authentik.

The implementation must provide one idempotent, parent-run offboarding
workflow and a scheduled drift reconciler. The security objective is complete
revocation within 15 minutes of the parent's recorded decision:

1. mark the household principal revoked and disable Authentik login;
2. invalidate Authentik sessions, outstanding invitations, recovery links,
   and verification tokens;
3. disable the Gitea user and revoke its browser sessions, PATs/OAuth grants,
   and SSH keys;
4. revoke Steam/Minecraft and other external-identity links without deleting
   the audit record;
5. remove a child-owned tailnet device when device admission is also being
   withdrawn.

The workflow records redacted object IDs, start/end timestamps, and pass/fail
checks in private `my_home`; it never records tokens or keys. A daily
reconciler is a backstop, not the 15-minute control. If an application is down,
keep it unreachable and apply the queued revocation before restoring access.
Acceptance must exercise an already-issued Authentik session, Gitea browser
session, PAT, and SSH key after the deadline.

### In-cluster issuer reachability

OIDC includes a server-to-server code exchange. Gitea and every other relying
party must resolve and reach the same canonical Authentik issuer from inside
k3s.

Pods do not automatically resolve tailnet MagicDNS names. In the MagicDNS
branch, use only the in-cluster design supported by the pinned Tailscale
Operator version: its `DNSConfig`, reviewed CoreDNS forwarding, and the
documented Ingress forwarding annotation. That feature and its image/version
must be pinned and tested before production.

In the parent-owned-domain branch, follow the custom-domain Gateway design:
CoreDNS conditionally forwards the exact owned private zone to the same
internal authoritative resolver used by tailnet split DNS, and resolves any
resulting `*.ts.net` target through the pinned `DNSConfig` path. The Gateway
terminates the certificate for the owned name. Never create a public record or
make pods use a Kubernetes-only issuer alias.

The current generic resource shape is:

```yaml
apiVersion: tailscale.com/v1alpha1
kind: DNSConfig
metadata:
  name: ts-dns
spec:
  nameserver:
    image:
      repo: tailscale/k8s-nameserver
      tag: REPLACE_PINNED_OPERATOR_COMPATIBLE_TAG
```

Wait for `dnsconfig.status.nameserver.ip`, then configure the k3s CoreDNS
customization mechanism to forward the exact `ts.net` zone to that address.
Do not copy a floating `unstable` image from an example. `DNSConfig` is a
singleton, and the current Ingress forwarding annotation remains
experimental; both are release gates, not invisible defaults.

The k3s CoreDNS custom-zone shape is:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns-custom
  namespace: kube-system
data:
  tailscale.server: |
    ts.net:53 {
      errors
      cache 30
      forward . REPLACE_DNSCONFIG_NAMESERVER_IP
    }
```

Confirm that the pinned k3s release imports `coredns-custom` before applying
this. Render, back up, and test the existing CoreDNS configuration first;
cluster DNS is shared infrastructure.

Do not work around a failure by:

- changing the issuer to the Kubernetes Service name;
- disabling TLS validation;
- overriding discovery endpoints to mixed hosts;
- adding a manually maintained pod `/etc/hosts`;
- exposing Authentik publicly.

Acceptance from a disposable pod:

```bash
curl --fail --silent --show-error \
  "https://REPLACE_AUTHENTIK_TAILNET_FQDN/application/o/gitea/.well-known/openid-configuration"
```

Verify the returned issuer and every endpoint use the same canonical FQDN.

---

## 12. Household principal and external game identities

One person has one opaque household principal anchored to Authentik's stable
OIDC issuer and subject. Keep external links in a private, access-controlled
link registry:

```text
person_id
provider
issuer
subject
display_name_snapshot
verification_method
verified_at
guardian_approved_at
revoked_at
```

Enforce uniqueness on `(provider, issuer, subject)`.

- Google email is a mutable label; Google's validated subject is the source
  identifier.
- Steam linking uses Steam's signed OpenID assertion and stores SteamID64.
- Minecraft Java linking uses a short-lived, single-use in-game code from an
  authenticated `online-mode=true` server and stores the Java UUID.
- Display names, gamertags, emails, and usernames never auto-link people.
- Steam/Minecraft claims are disclosed only to applications that need them,
  never broadly in Gitea tokens.

Never collect Steam passwords, Microsoft passwords/device codes, launcher
cookies, Xbox/XSTS tokens, Minecraft access tokens, or another launcher's
client ID.

The detailed implementation and replay/collision tests are in
[the Minecraft Lab plan](MINECRAFT-LAB-PLAN.md).

---

## 13. Migration from `authentik.home.lab`

Perform migration in a parent maintenance window:

1. back up Authentik, its database, signing/encryption material, and all client
   definitions;
2. inventory every old issuer, callback, redirect, cookie domain, proxy header,
   bookmark, passkey/RP setting, and service OIDC source;
3. deploy and verify the new tailnet Ingress;
4. prove client and in-cluster DNS, HTTPS, and negative exposure;
5. set the canonical Authentik external host;
6. add exact new callbacks to Google and every application;
7. update each relying party one at a time;
8. test parent, invited-child, and Google login;
9. revoke old sessions and credentials where the host/issuer changed;
10. remove the old callbacks and service configuration;
11. remove the old DNS/ingress route;
12. rerun recovery and privacy tests.

An OIDC issuer change may create a new external identity at a relying party.
Reconcile by stable, parent-reviewed account records. Never let Gitea or
Authentik merge accounts automatically by matching email.

Existing passkeys may be bound to the old RP ID and require supervised
re-enrollment. Keep break-glass access until the new path and restore drill pass.

---

## 14. Acceptance matrix

| Test | Expected result |
|---|---|
| Approved client with Tailscale DNS enabled | Canonical Authentik FQDN resolves and HTTPS validates |
| Authenticated but unapproved tailnet identity/device | TCP 443 is denied by the tailnet grant before Authentik |
| Same client with Tailscale disconnected | Authentik and Gitea are unreachable |
| Public DNS / external IPv4 / external IPv6 | No usable route to either service |
| Private exposure inspection | Selected MagicDNS Ingress or owned-domain Gateway only; no Funnel, ordinary ingress, or second identity host |
| Canonical redirect | No response contains `home.lab`, an IP, HTTP, or a Kubernetes name |
| Google callback | Exact Phase-0-selected URI is accepted and a named household test user completes login |
| Unapproved Google account | Enrollment/access denied without creating an authorized household user |
| Invited arbitrary-email child | Single-use invitation plus password/passkey succeeds |
| Duplicate-case email / edited recipient | Enrollment and profile write are denied |
| Expired, replayed, or revoked invitation | Enrollment is denied without creating or activating a user |
| Same email from another source | No automatic merge or link |
| Identity collision | Same external subject cannot link to two people |
| Gitea OIDC | Authorized child signs in; unassigned child and anonymous user are denied |
| Gitea Git access | Per-user SSH/scoped credential works; no Authentik token is used as a Git credential |
| Role claim tampering | Google/email/tailnet facts cannot create a parent/admin role |
| Child revoked | Existing Authentik/Gitea sessions, PATs, OAuth grants, SSH keys, invitations, and external links fail within 15 minutes |
| Authentik outage | Local Git/build/play continues; parent can use documented break-glass recovery |
| Restore drill | Users, groups, providers, signing material, and service links restore without public exposure |

Keep test users, FQDNs, logs, screenshots, callbacks, tokens, and network output
in private `my_home`.

---

## 15. Definition of done

The household identity layer is ready when:

1. every LaCOS client accepts Tailscale DNS;
2. Authentik has one canonical, Tailscale-resolved HTTPS FQDN selected by the
   Google Phase 0 gate and no `home.lab` or failed-candidate identity path;
3. Authentik and Gitea are unreachable without Tailscale and have no Funnel or
   public ingress;
4. Google SSO passes the exact callback test with approved household accounts;
5. arbitrary-email children can use invitation-only local authentication;
6. email equality never merges accounts;
7. Gitea and each service use separate native Authentik OIDC providers and
   parent-managed role claims;
8. in-cluster clients validate and reach the same canonical issuer;
9. SteamID64 and Minecraft Java UUID links use separate proof-of-control flows
   with guardian approval;
10. the parent-run workflow and drift reconciler revoke application sessions,
    Git credentials, invitations, and external links within the defined
    15-minute objective as well as disabling Authentik access;
11. a tested backup restores identity configuration and signing material;
12. no public repository or issue contains household identity, topology, or
    secret material.

---

## References

- [Tailscale Kubernetes Operator installation](https://tailscale.com/docs/kubernetes-operator/install-operator)
- [Tailscale private L7 Ingress with `ProxyGroup`](https://tailscale.com/docs/kubernetes-operator/ingress/expose-workload-to-tailnet-l7)
- [Tailscale `ProxyGroup` concepts](https://tailscale.com/docs/kubernetes-operator/concepts/proxygroup)
- [Tailscale Operator permissions and service-tag policy](https://tailscale.com/docs/kubernetes-operator/reference/rbac)
- [Tailscale Operator Ingress limitations](https://tailscale.com/docs/kubernetes-operator/reference/limitations)
- [Tailscale client DNS preferences](https://tailscale.com/docs/features/client/manage-preferences)
- [Tailscale MagicDNS](https://tailscale.com/docs/features/magicdns)
- [Tailscale in-cluster MagicDNS `DNSConfig`](https://tailscale.com/docs/kubernetes-operator/concepts/dnsconfig)
- [Tailscale custom-domain Gateway pattern](https://tailscale.com/docs/solutions/kubernetes-operator-byod-gateway-api)
- [Tailscale Kubernetes Operator tags](https://tailscale.com/docs/kubernetes-operator/reference/tags)
- [Tailscale Funnel is public](https://tailscale.com/docs/features/tailscale-funnel)
- [Google OAuth redirect URI validation](https://support.google.com/cloud/answer/15549257)
- [Google OAuth domain and production policy](https://developers.google.com/identity/protocols/oauth2/production-readiness/policy-compliance)
- [Public Suffix List entry for `ts.net`](https://publicsuffix.org/list/public_suffix_list.dat)
- [Authentik Google OAuth source](https://docs.goauthentik.io/users-sources/sources/social-logins/google/cloud/)
- [Authentik OAuth source matching modes](https://docs.goauthentik.io/docs/developer-docs/api/reference/sources-oauth-create)
- [Authentik invitations](https://docs.goauthentik.io/users-sources/user/invitations/)
- [Authentik unique-email expression policy](https://docs.goauthentik.io/customize/policies/types/expression/unique_email/)
- [Authentik Identification stage](https://docs.goauthentik.io/add-secure-apps/flows-stages/stages/identification/)
- [Authentik Email stage](https://docs.goauthentik.io/add-secure-apps/flows-stages/stages/email/)
- [Authentik reverse-proxy and trusted-CIDR settings](https://docs.goauthentik.io/install-config/reverse-proxy/)
- [Authentik OAuth/OIDC providers and issuer modes](https://docs.goauthentik.io/add-secure-apps/providers/oauth2/)
- [Authentik Gitea integration](https://integrations.goauthentik.io/services/gitea/)
