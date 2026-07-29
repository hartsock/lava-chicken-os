# Create Your Own Private `my_home` and Gitea on k3s

**Audience:** a parent or home-lab administrator

**Status:** pre-implementation operator blueprint and acceptance contract

**Scope:** private, tailnet-only source hosting and Authentik SSO for Lava
Chicken OS projects
**Last reviewed:** July 29, 2026

This guide does not require the project maintainer’s GitHub account, private
repositories, SSH keys, home domain, network, or Gitea. You create a new local
infrastructure repository, conventionally named `my_home`, and deploy your own
Gitea to your own existing k3s cluster.

> **Current implementation boundary:** the blank local repository bootstrap in
> section 3 works now. The deployable manifests, policy checker, and helper
> scripts are Phase 1A deliverables in the Minecraft Lab Epic and are not in the
> repository yet. Sections 4–19 specify the reviewed operator workflow those
> artifacts must implement; do not deploy from empty placeholder files.

`my_home` is only a suggested name. It is your repository. You may rename it,
keep it entirely off GitHub, and use your own private address plan. A local
domain may still serve unrelated LAN devices, but Authentik's issuer and
callbacks use only the Tailscale-resolved name selected by the runbook.

The target result is:

```text
parent-owned admin workstation
  |
  | kubectl + pinned Helm chart
  v
your private k3s cluster
  |
  +-- PostgreSQL + durable storage
  +-- Gitea + durable storage
  +-- Tailscale Operator + private HTTPS MagicDNS ingress
  +-- Authentik OIDC + parent-approved household identities
  +-- optional separately protected Git/SSH endpoint
  +-- encrypted off-cluster backup

approved tailnet LaCOS client ----------> private Gitea
          |                                  |
          +-- browser OIDC redirects --------+
          v                                  |
       Authentik <--- discovery/code exchange+

off-tailnet or unapproved client ----------------X
```

Authentik brokers identity; it is not in the application data path. Normal
Gitea page and Git traffic goes directly to Gitea. Only browser OIDC redirects
and Gitea's discovery/code exchange go to Authentik.

Gitea is a collaboration and recovery service. It is not required to edit,
commit, build, test, or locally play a Minecraft project. A Gitea outage must
leave those local workflows working.

---

## 1. Security baseline

The first supported configuration is deliberately narrow:

- an existing k3s cluster owned by the household;
- web access through Tailscale from explicitly allowed household devices only;
- MagicDNS and Tailscale DNS accepted by every client;
- Authentik on the one canonical, tailnet-only HTTPS name selected by the
  runbook's Google compatibility gate and resolved through Tailscale DNS;
- Gitea on a separate tailnet-only HTTPS `*.ts.net` name;
- native Authentik OIDC for Gitea, with a local parent-owned break-glass
  administrator;
- no public A/AAAA/CNAME service record or internet route;
- no router/NAT port forward;
- no UPnP mapping;
- no public tunnel, Funnel, or reverse-proxy route;
- external IPv4 and IPv6 traffic denied;
- publicly trusted TLS provisioned by the Tailscale Ingress, without making the
  service public;
- local username/password registration disabled, approved Authentik OIDC
  provisioning only, and sign-in required;
- invitation/approval-only Authentik enrollment, a parent-owned organization,
  and separate non-admin child principals;
- every repository private;
- repository migration, mirrors, webhooks, custom Git hooks, and Actions
  disabled for the first release;
- no Actions runner;
- no Gitea administrator credential on a child machine or in Nugget;
- exact chart and image versions;
- encrypted, off-cluster backups with a tested restore.

MagicDNS is naming, not the only access control. Tailnet grants, Authentik
policy, Kubernetes NetworkPolicy, node policy, and negative external tests all
remain required. k3s normally deploys Traefik through ServiceLB, which can bind
ports 80 and 443 on every eligible node; Gitea and Authentik must not be routed
through that ordinary ingress.

Tailscale access is the baseline private transport. It is not permission to use
Funnel, a public reverse proxy, or any other internet ingress.

---

## 2. Prerequisites

Have these ready before creating anything:

- a working k3s cluster reachable only through an administrator-controlled
  path;
- a household-owned Tailscale tailnet with MagicDNS and HTTPS enabled;
- the pinned Tailscale Kubernetes Operator and narrowly scoped operator OAuth
  credentials stored outside Git;
- a pinned private Authentik deployment, canonical tailnet FQDN, and tested
  recovery path as described in
  [Private Tailscale, Authentik, and Household SSO](TAILSCALE-AUTHENTIK.md);
- `kubectl` configured for that cluster;
- Helm 3;
- a durable `StorageClass` suitable for PostgreSQL and Gitea;
- a tailnet policy granting only approved household devices access to the
  identity and Gitea service tags;
- a reviewed in-cluster MagicDNS path so Gitea can validate and reach the same
  Authentik issuer;
- a password manager;
- k3s Secrets encryption at rest whenever Kubernetes Secret objects are used,
  or a secret-injection mechanism proven never to persist plaintext in the
  Kubernetes API or datastore;
- backup storage on different media or a different node from the cluster;
- a second, isolated namespace or disposable cluster for restore drills;
- access to the home router/firewall;
- a phone hotspot or other genuinely external network for exposure tests.

The default k3s local-path provisioner stores data on one node. That may be
acceptable for a lab, but it is not a backup and it does not survive every node
failure. Decide this before selecting the storage class.

If k3s Secrets encryption is not already enabled, follow the official k3s
procedure for your exact installed version. Do not improvise key rotation:
incorrect sequencing can corrupt access to existing Secrets.

---

## 3. Initialize a blank local `my_home`

Start locally. Do not create a GitHub repository first.

```bash
umask 077
MY_HOME_DIR="${HOME}/my_home"
install -d -m 0700 "${MY_HOME_DIR}"
cd "${MY_HOME_DIR}"
git init -b main
git config user.name "YOUR NAME"
git config user.email "YOUR PRIVATE GIT EMAIL"
git remote -v
```

The last command must print nothing.

The Epic will ship an account-neutral starter at:

```text
/usr/share/lava-chicken/templates/my_home/
```

and as a versioned release artifact. Until that starter ships, you may reserve
this empty local structure. It is not a deployable Gitea stack:

```text
my_home/
  README.md
  .gitignore
  versions.lock
  vendor/
  clusters/
    home/
      gitea/
        values.example.yaml
        values.local.yaml
        private-ingress.yaml
        network-policy.yaml
        backup/
  site/
    lacos-minecraft-site.example.json
    lacos-minecraft-site.local.json
  secrets/
    README.md
    plaintext/
  scripts/
    preflight
    render
    deploy
    test-private
    backup
    restore-drill
    upgrade
    teardown-check
  docs/
    THREAT-MODEL.md
    BACKUP-RESTORE.md
    UPGRADING.md
    TEARDOWN.md
```

For the manual fallback, create every path before continuing. These commands
do not overwrite an existing file:

```bash
MY_HOME_DIR="${MY_HOME_DIR:-${HOME}/my_home}"
cd "${MY_HOME_DIR}"

install -d -m 0700 \
  vendor \
  clusters/home/gitea/backup \
  site \
  secrets/plaintext \
  scripts \
  docs

for tracked_file in \
  README.md \
  .gitignore \
  versions.lock \
  vendor/.gitkeep \
  clusters/home/gitea/values.example.yaml \
  clusters/home/gitea/values.local.yaml \
  clusters/home/gitea/private-ingress.yaml \
  clusters/home/gitea/network-policy.yaml \
  clusters/home/gitea/backup/.gitkeep \
  site/lacos-minecraft-site.example.json \
  site/lacos-minecraft-site.local.json \
  secrets/README.md \
  docs/THREAT-MODEL.md \
  docs/BACKUP-RESTORE.md \
  docs/UPGRADING.md \
  docs/TEARDOWN.md
do
  test -e "${tracked_file}" ||
    install -m 0600 /dev/null "${tracked_file}"
done

for helper in \
  preflight \
  render \
  deploy \
  test-private \
  backup \
  restore-drill \
  upgrade \
  teardown-check
do
  test -e "scripts/${helper}" ||
    install -m 0700 /dev/null "scripts/${helper}"
done
```

The empty helper files reserve the public starter’s interface; they are not
implemented commands and must not be run. Follow the explicit commands in this
guide as a reviewable blueprint until the versioned starter replaces them.
Populate `.gitignore` with the rules below before the first commit, then stop
before the deployment sections.

`values.example.yaml` and the example enrollment contract are tracked.
`values.local.yaml` and the local contract are household-specific and ignored,
unless you deliberately encrypt them with SOPS/age before committing.

Use at least these `.gitignore` rules:

```gitignore
# Local topology and rendered output
**/*.local.yaml
**/*.local.json
rendered/
tmp/

# Credentials and administrative access
secrets/plaintext/
*.key
*.pem
*.p12
*.kubeconfig
kubeconfig*

# Backups and database dumps
backups/
*.dump
*.sql
*.tar
*.tar.gz
*.zip

# Local tooling
.DS_Store
```

Do not treat `.gitignore` as secret encryption. It is only a last line of
defense.

Make the first local commit before adding a remote:

```bash
MY_HOME_DIR="${MY_HOME_DIR:-${HOME}/my_home}"
cd "${MY_HOME_DIR}"
git add README.md .gitignore versions.lock clusters site secrets scripts docs
git add vendor/.gitkeep
git diff --cached --check
git commit -m "chore: initialize private home configuration"
test -z "$(git remote)"
```

---

## 4. Use explicit placeholders

Tracked example files use obvious, non-secret placeholders:

| Placeholder | Meaning |
|---|---|
| `REPLACE_AUTHENTIK_TAILNET_FQDN` | exact private Authentik FQDN selected by the runbook's Google Phase 0 gate and resolved through Tailscale DNS |
| `REPLACE_GITEA_TAILNET_FQDN` | exact private Gitea MagicDNS FQDN reported by its Tailscale Ingress |
| `REPLACE_IDENTITY_SERVICE_TAG` | parent-defined tailnet tag for Authentik ingress |
| `REPLACE_GITEA_SERVICE_TAG` | parent-defined tailnet tag for Gitea ingress |
| `REPLACE_GITEA_OIDC_CLIENT_ID` | non-secret Gitea OIDC client identifier |
| `REPLACE_GITEA_OIDC_SECRET_NAME` | private Secret reference containing the Gitea OIDC client secret |
| `REPLACE_GITEA_SSH_HOST` | optional tailnet-only Git/SSH name |
| `REPLACE_GITEA_SSH_PORT` | optional private Git/SSH port |
| `REPLACE_STORAGE_CLASS` | durable k3s storage class |
| `REPLACE_BACKUP_DESTINATION` | encrypted off-cluster target |
| `REPLACE_PARENT_ADMIN_USER` | local break-glass administrator |
| `REPLACE_PARENT_PRIVATE_EMAIL` | parent-chosen local Gitea email |
| `REPLACE_MINECRAFT_ORG` | parent-owned Gitea organization |
| `REPLACE_GITEA_IMAGE_DIGEST_HEX` | raw hexadecimal part of the pinned rootless Gitea image digest |
| `REPLACE_POSTGRES_IMAGE_DIGEST_HEX` | raw hexadecimal part of the pinned PostgreSQL image digest |
| `REPLACE_GITEA_SSH_HOST_KEY_SHA256` | complete pinned OpenSSH host-key fingerprint, including `SHA256:` |

The values policy already supplies the `sha256:` image-digest prefix. Replace
the two `_DIGEST_HEX` placeholders with hexadecimal characters only.

A preflight script must fail while any placeholder remains in a rendered
deployment.

Never put a real password, token, private key, kubeconfig, or recovery code in a
placeholder.

---

## 5. Pin the official Gitea chart

The remaining sections are the Phase 1A implementation and operator contract.
Command shapes are included for review, but they become runnable only when the
Epic ships the populated starter, rendered-policy checker, and versioned
release artifact. An empty skeleton from section 3 is not sufficient.

The official Gitea Kubernetes installation uses the official Helm chart.

The planning baseline verified on July 29, 2026 is:

```yaml
gitea_chart:
  repository: https://dl.gitea.com/charts/
  version: 12.7.0
  sha256: 5881ef9c59400bee2d5547e77c4cd0efb925143c2f5d93fb4f38446db76b0167
gitea:
  version: 1.27.0
```

Record this in `versions.lock`. Also record the exact Gitea rootless and
PostgreSQL image digests for the CPU architecture used by the cluster.

Do not copy an image digest from another architecture without verifying the
rendered image reference. Do not use `latest`, a floating major tag, or an
unbounded `helm upgrade`.

Vendor and verify the chart so Gitea can be rebuilt while Gitea itself is down:

```bash
MY_HOME_DIR="${MY_HOME_DIR:-${HOME}/my_home}"
cd "${MY_HOME_DIR}"
GITEA_CHART_VERSION="12.7.0"
GITEA_CHART_SHA256="5881ef9c59400bee2d5547e77c4cd0efb925143c2f5d93fb4f38446db76b0167"
GITEA_CHART_FILE="vendor/gitea-${GITEA_CHART_VERSION}.tgz"

curl --fail --location --proto '=https' \
  --output "${GITEA_CHART_FILE}" \
  "https://dl.gitea.com/charts/gitea-${GITEA_CHART_VERSION}.tgz"

printf '%s  %s\n' "${GITEA_CHART_SHA256}" "${GITEA_CHART_FILE}" \
  | sha256sum --check -
```

If your platform uses a different checksum tool, verify the same SHA-256 value
with that tool.

Before a future update, consult the official chart and Gitea release notes,
select new exact pins, and test a restored copy first.

---

## 6. Preflight the exact k3s target

Read the target before writing to it:

```bash
kubectl config current-context
kubectl cluster-info
kubectl get nodes -o wide
kubectl get storageclass
kubectl -n kube-system get service traefik -o wide
kubectl get service --all-namespaces
kubectl get ingressclass
kubectl --namespace tailscale get deployment,pod
```

Record the intended context name in the ignored local values. The deploy helper
must:

1. compare the active context with that intended value;
2. print the cluster API endpoint and node names;
3. show the selected storage and ingress classes;
4. show existing LoadBalancer, NodePort, host-port, ordinary Ingress, and
   Tailscale Ingress exposure;
5. stop for explicit parent confirmation.

Never let a script install to “whatever context is current.”

On a k3s server, verify Secrets encryption using the official command supported
by that k3s version:

```bash
sudo k3s secrets-encrypt status
```

If it is disabled, stop. Enabling or rotating it changes cluster-wide security
state and must follow the official k3s procedure separately.

Check that:

- every selected node address is private or otherwise explicitly firewalled;
- the storage class has the expected reclaim and binding policy;
- there is enough persistent capacity for repositories, LFS, attachments,
  releases, and PostgreSQL;
- the backup destination is not the same PVC, disk, or node;
- no ordinary or public ingress controller will accept the planned Gitea or
  Authentik host;
- the Tailscale Operator has only the intended tag and credential scopes;
- MagicDNS and HTTPS are enabled and the private service tags have explicit
  grants.

---

## 7. Choose canonical tailnet DNS, HTTPS, and optional SSH

First deploy Authentik using
[the tailnet identity runbook](TAILSCALE-AUTHENTIK.md). Record the exact
canonical address selected and verified by its Google Phase 0 gate:

```text
https://REPLACE_AUTHENTIK_TAILNET_FQDN
```

Do not use `authentik.home.lab`, an IP address, a Kubernetes Service name, or a
home-CA alias as the Authentik issuer.

Gitea gets its own Tailscale Ingress and exact MagicDNS address:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: gitea-tailnet
  namespace: gitea
  annotations:
    tailscale.com/proxy-group: "household-ingress-proxies"
    tailscale.com/tags: "tag:REPLACE_GITEA_SERVICE_TAG"
spec:
  ingressClassName: tailscale
  tls:
    - hosts:
        - gitea
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: gitea-http
                port:
                  number: 3000
```

There is deliberately no `tailscale.com/funnel` annotation. Keep the chart's
ordinary ingress disabled and the HTTP backend `ClusterIP`.

The runbook's pinned ingress `ProxyGroup` advertises this separate Gitea
service tag. The operator must own both tags, the private
`autoApprovers.services` policy must allow only that proxy tag to advertise
this service tag, and tailnet grants must allow only approved household users
to reach it. Do not enable a static-endpoint `ProxyClass`; that is outside the
no-NodePort baseline.

After the parent applies the private manifest:

```bash
kubectl --namespace gitea get ingress gitea-tailnet
```

Copy the exact `ADDRESS` into the ignored local values as
`REPLACE_GITEA_TAILNET_FQDN`. Do not synthesize it from the tailnet name. The
first HTTPS request may wait while the Tailscale Ingress provisions its
certificate.

From an approved client with Tailscale DNS enabled:

```bash
GITEA_FQDN="REPLACE_GITEA_TAILNET_FQDN"
resolvectl query "${GITEA_FQDN}"
curl --fail --silent --show-error --max-time 15 \
  "https://${GITEA_FQDN}/api/healthz"
```

The check must pass without:

```text
curl -k
GIT_SSL_NO_VERIFY=true
StrictHostKeyChecking=no
hosts-file overrides
```

Disconnect Tailscale and prove the same endpoint is unreachable. Also inspect
all ordinary Ingress, LoadBalancer, NodePort, host-port, public DNS, router,
UPnP, IPv4, and IPv6 paths.

The Helm baseline keeps both Gitea Services at `ClusterIP`. The first release
uses HTTPS Git through the private Tailscale Ingress. If Git/SSH is added later,
expose it as a separately tagged, tailnet-only Tailscale service with a narrow
grant. Persist its host keys and enroll fingerprints through a parent-run trust
flow. Do not open an ordinary LoadBalancer or broad NodePort.

---

## 8. Create Secrets without putting values in Git

The baseline needs:

- a Gitea break-glass administrator username and password;
- a PostgreSQL administrator password;
- a PostgreSQL Gitea-user password;
- a separate Gitea/Authentik OIDC client secret;
- Gitea-generated encryption and signing material that must survive restore.

Generate and store credentials in the parent’s password manager. If the
household does not yet use an external secret controller, put temporary source
files under `secrets/plaintext/` with mode `0600`, create Kubernetes Secrets
from those files, and keep the protected recovery copy outside this repository.

The chart’s administrator Secret must contain:

```text
username
password
```

Choose a household-specific username; Gitea’s chart does not allow the literal
username `admin`.

The PostgreSQL Secret used by the bundled chart must contain the key names
declared in the pinned PostgreSQL chart, normally:

```text
postgres-password
password
replication-password
```

Verify those names against the vendored chart before deployment.

Never pass a password with `--from-literal` in a saved shell history, and never
commit a rendered Secret. Do not paste secret output into an issue or build log.

For a durable installation, prefer SOPS/age-encrypted source manifests or a
parent-controlled secret manager. If either path creates Kubernetes Secret
objects, k3s datastore encryption at rest is still required because the API
stores their decrypted values. Treat a mechanism as an alternative only when
it mounts or injects secrets without ever persisting plaintext in the
Kubernetes API or datastore, and verify that the pinned chart supports that
mechanism. Keep the age decryption key, Authentik/Gitea recovery credentials,
and tailnet recovery material outside both Git and the cluster.

---

## 9. Define a private Gitea values policy

The exact starter values must match the pinned chart. This fragment shows the
required policy shape; replace every `REPLACE_...` value in the ignored local
overlay before rendering:

```yaml
global:
  storageClass: "REPLACE_STORAGE_CLASS"

replicaCount: 1

image:
  registry: docker.gitea.com
  repository: gitea
  tag: "1.27.0"
  digest: "sha256:REPLACE_GITEA_IMAGE_DIGEST_HEX"
  rootless: true
  pullPolicy: IfNotPresent

service:
  http:
    type: ClusterIP
    port: 3000
  ssh:
    type: ClusterIP
    port: 22

ingress:
  enabled: false

test:
  enabled: false

serviceAccount:
  create: true
  automountServiceAccountToken: false

podSecurityContext:
  fsGroup: 1000
  seccompProfile:
    type: RuntimeDefault

containerSecurityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
  privileged: false
  readOnlyRootFilesystem: true
  runAsGroup: 1000
  runAsNonRoot: true
  runAsUser: 1000

resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: "1"
    memory: 2Gi

persistence:
  enabled: true
  size: 20Gi
  accessModes: ["ReadWriteOnce"]
  storageClass: "REPLACE_STORAGE_CLASS"

postgresql-ha:
  enabled: false

postgresql:
  enabled: true
  global:
    postgresql:
      auth:
        username: gitea
        database: gitea
        existingSecret: gitea-postgresql
        secretKeys:
          adminPasswordKey: postgres-password
          userPasswordKey: password
          replicationPasswordKey: replication-password
  image:
    digest: "sha256:REPLACE_POSTGRES_IMAGE_DIGEST_HEX"
  primary:
    persistence:
      enabled: true
      storageClass: "REPLACE_STORAGE_CLASS"
      size: 10Gi

gitea:
  admin:
    existingSecret: gitea-admin
    passwordMode: initialOnlyRequireReset
    email: "REPLACE_PARENT_PRIVATE_EMAIL"

  config:
    server:
      DOMAIN: "REPLACE_GITEA_TAILNET_FQDN"
      ROOT_URL: "https://REPLACE_GITEA_TAILNET_FQDN/"
      PUBLIC_URL_DETECTION: never
      DISABLE_SSH: true
      START_SSH_SERVER: false

    security:
      INSTALL_LOCK: true
      DISABLE_GIT_HOOKS: true
      DISABLE_WEBHOOKS: true

    service:
      # Gitea must leave the registration pipeline enabled for OIDC
      # auto-provisioning, then restrict that pipeline to external sources.
      DISABLE_REGISTRATION: false
      ALLOW_ONLY_EXTERNAL_REGISTRATION: true
      SHOW_REGISTRATION_BUTTON: false
      REQUIRE_SIGNIN_VIEW: true
      DEFAULT_KEEP_EMAIL_PRIVATE: true
      DEFAULT_ALLOW_CREATE_ORGANIZATION: false
      DEFAULT_USER_IS_RESTRICTED: true
      DEFAULT_USER_VISIBILITY: private
      ALLOWED_USER_VISIBILITY_MODES: private
      DEFAULT_ORG_VISIBILITY: private
      DEFAULT_ORG_MEMBER_VISIBLE: false

    admin:
      DISABLE_REGULAR_ORG_CREATION: true

    repository:
      FORCE_PRIVATE: true
      DEFAULT_PRIVATE: private
      DEFAULT_PUSH_CREATE_PRIVATE: true
      ENABLE_PUSH_CREATE_USER: false
      ENABLE_PUSH_CREATE_ORG: false
      USER_MAX_CREATION_LIMIT: 0
      DISABLED_REPO_UNITS: "repo.actions"
      DEFAULT_REPO_UNITS: "repo.code,repo.releases,repo.issues,repo.pulls"
      DISABLE_MIGRATIONS: true

    mirror:
      ENABLED: false
      DISABLE_NEW_PULL: true
      DISABLE_NEW_PUSH: true

    actions:
      ENABLED: false

    federation:
      ENABLED: false

    openid:
      ENABLE_OPENID_SIGNIN: false
      ENABLE_OPENID_SIGNUP: false

    oauth2_client:
      ENABLE_AUTO_REGISTRATION: true
      USERNAME: userid
      ACCOUNT_LINKING: disabled
      REGISTER_EMAIL_CONFIRM: false

    session:
      COOKIE_SECURE: true
      # OIDC uses a top-level cross-site callback; Strict breaks its state cookie.
      SAME_SITE: lax

valkey-cluster:
  enabled: false

valkey:
  enabled: false
```

Do not paste database or administrator passwords into this file.

The `openid` block above disables Gitea's legacy OpenID sign-in/sign-up
surface. Authentik is added as a native OAuth2/OpenID Connect authentication
source using the admin interface, pinned CLI, or a reviewed one-time bootstrap
job for the exact Gitea release. Do not put its client secret in `app.ini`,
tracked values, or a command-line argument.

`DISABLE_REGISTRATION` must remain `false` because Gitea otherwise permits only
an administrator to create accounts. `ALLOW_ONLY_EXTERNAL_REGISTRATION`,
`SHOW_REGISTRATION_BUTTON`, and the single reviewed Authentik authentication
source remove local self-signup; `ENABLE_AUTO_REGISTRATION` then creates a
restricted Gitea account only after that source accepts the parent-managed
claim. `USERNAME: userid` derives the immutable Gitea username from OIDC
`sub`, rather than mutable or collision-prone email. Do not add an
authentication source without the same required-claim review.

The Authentik source contract is:

```text
name: authentik
provider: OpenID Connect
discovery:
  https://REPLACE_AUTHENTIK_TAILNET_FQDN/application/o/gitea/.well-known/openid-configuration
callback:
  https://REPLACE_GITEA_TAILNET_FQDN/user/oauth2/authentik/callback
required claim name:
  gitea_access
required claim value:
  member
automatic account linking:
  disabled
```

Use a confidential client and Authentik's default per-provider issuer mode.
Create an Authentik property/scope mapping named `gitea_access` that returns
the literal string `member` only when the current user belongs to the local,
parent-managed `gitea-users` group; omit the claim otherwise. Configure
Gitea's sole OAuth source with exact `required-claim-name=gitea_access` and
`required-claim-value=member`. Do not configure automatic admin/restricted
group mapping. Google email/domain claims must not authorize registration or
elevation.

The policy checker has separate public-fixture and household modes. Both modes
must reject:

- any remaining `REPLACE_` value;
- any Secret outside an exact, chart-versioned allowlist;
- any credential, token, password, private key, or kubeconfig embedded in
  allowlisted chart-generated configuration or init-script Secrets;
- NodePort or public LoadBalancer services;
- any ordinary/public Ingress, any Funnel annotation, or a Tailscale Ingress
  outside the exact approved service/tag allowlist;
- privileged pods or host mounts;
- automatic service-account tokens;
- an Actions runner or enabled Actions repository unit;
- any mutable or unpinned image used by a container, init container, hook, job,
  or Helm test;
- a GitHub remote or mirror;
- maintainer names, domains, addresses, or keys.

Public-fixture CI uses only reserved synthetic values and also rejects any real
household literal. Household mode permits the schema-defined non-secret site
values—such as the private tailnet FQDNs, service tags, and parent-selected
local email—only at exact, chart-versioned key paths where the pinned chart
requires them. It rejects those values everywhere else. Rendered household
manifests and checker evidence remain private and are never uploaded to public
CI or issues.

Some security-context settings may require adjustment for a particular storage
driver. Make the smallest documented change, render it, and preserve
non-root/no-privilege-escalation as hard requirements.

---

## 10. Render before deploying

Render the complete chart locally:

```bash
MY_HOME_DIR="${MY_HOME_DIR:-${HOME}/my_home}"
cd "${MY_HOME_DIR}"
GITEA_NAMESPACE="gitea"
GITEA_CHART_FILE="vendor/gitea-12.7.0.tgz"

install -d -m 0700 rendered
helm template gitea "${GITEA_CHART_FILE}" \
  --namespace "${GITEA_NAMESPACE}" \
  --values clusters/home/gitea/values.example.yaml \
  --values clusters/home/gitea/values.local.yaml \
  > rendered/gitea.yaml
```

Before install:

- inspect every image reference;
- inspect every Service type and external address;
- inspect Ingress and Gateway resources;
- confirm the database is not internet-reachable;
- confirm no credential was rendered;
- confirm the namespace and storage classes;
- run the public policy checker supplied by the Epic.

Use a server-side dry run only after the kube-context confirmation:

```bash
MY_HOME_DIR="${MY_HOME_DIR:-${HOME}/my_home}"
GITEA_NAMESPACE="${GITEA_NAMESPACE:-gitea}"
cd "${MY_HOME_DIR}"
kubectl apply \
  --namespace "${GITEA_NAMESPACE}" \
  --server-side \
  --dry-run=server \
  --filename rendered/gitea.yaml
```

A successful render is not proof of private networking.

---

## 11. Deploy privately in stages

Use this order:

1. confirm kube context and cluster identity;
2. create the dedicated namespace;
3. prove the cluster’s CNI enforces NetworkPolicy;
4. apply default-deny ingress/egress plus only the DNS,
   Gitea-to-PostgreSQL, and parent-diagnostic policies required for bootstrap;
5. apply the PostgreSQL and administrator Secrets;
6. install the pinned chart with both Services at `ClusterIP` and ingress off;
7. wait for PostgreSQL and Gitea;
8. test `/api/healthz` through a local `kubectl port-forward`;
9. create the separate Authentik Application/OIDC provider and private client
   Secret;
10. configure Gitea's native Authentik OIDC source and prove in-cluster
    discovery/issuer reachability;
11. add the Tailscale-proxy allowance immediately before applying the
    tailnet-only Gitea HTTPS Ingress;
12. configure tailnet grants and confirm no ordinary ingress/router path;
13. optionally add the separately tagged, tailnet-only Git/SSH policy and path;
14. add the backup allowance only when the backup job is configured;
15. run the complete privacy and identity test matrix.

The Helm install shape is:

```bash
MY_HOME_DIR="${MY_HOME_DIR:-${HOME}/my_home}"
GITEA_NAMESPACE="${GITEA_NAMESPACE:-gitea}"
GITEA_CHART_FILE="${GITEA_CHART_FILE:-${MY_HOME_DIR}/vendor/gitea-12.7.0.tgz}"
cd "${MY_HOME_DIR}"

helm upgrade --install gitea "${GITEA_CHART_FILE}" \
  --namespace "${GITEA_NAMESPACE}" \
  --create-namespace \
  --values clusters/home/gitea/values.example.yaml \
  --values clusters/home/gitea/values.local.yaml \
  --wait \
  --timeout 10m
```

Do not enable ingress in the same first step. First prove the application and
database through a port-forward:

```bash
GITEA_NAMESPACE="${GITEA_NAMESPACE:-gitea}"
kubectl --namespace "${GITEA_NAMESPACE}" \
  port-forward service/gitea-http 3000:3000
```

In a second terminal:

```bash
curl --fail http://127.0.0.1:3000/api/healthz
```

Apply the namespace default-deny rules and minimum bootstrap allowances before
installing a workload. Add later allowances immediately before enabling the
corresponding path. The final NetworkPolicies should allow only:

- the selected Tailscale ingress proxy to Gitea HTTP;
- Gitea to PostgreSQL;
- Gitea and PostgreSQL to cluster DNS;
- Gitea to the canonical Authentik issuer through the reviewed in-cluster
  MagicDNS path;
- explicitly required Gitea internal traffic;
- the parent-controlled backup job to the database, Gitea data, and backup
  target;
- the optional private SSH entry path to Gitea SSH.

NetworkPolicy is defense in depth. It does not replace host or router policy.

---

## 12. Bootstrap household identities

Authentik is the household identity broker. Gitea trusts only its dedicated
Authentik OIDC provider. Google is one Authentik login source; a child with
another email uses a parent-invited local Authentik account plus a password or
passkey. Email alone is not authentication.

Before exposing Gitea:

1. complete the Authentik backup/recovery and tailnet privacy tests;
2. create local `gitea-users` and `gitea-parents` groups;
3. create a separate confidential Authentik Application/OIDC provider for
   Gitea with the exact callback and a locally derived required group claim;
4. store the OIDC client secret in the private household secret mechanism;
5. prove a Gitea pod can resolve, validate, and reach the canonical Authentik
   discovery document;
6. configure Gitea's native Authentik authentication source with automatic
   account linking disabled;
7. enable external registration only for principals carrying the local
   `gitea-users` claim.

Use the chart-created local Gitea administrator only for bootstrap and
recovery. At first login:

1. satisfy the forced password reset and store the credential in the parent's
   password manager;
2. enable a second factor if supported by the recovery design;
3. sign in through Authentik as an everyday parent and verify that account is
   an ordinary Gitea user until explicitly made a site/organization owner;
4. create a private parent-owned organization for Minecraft projects;
5. make only approved everyday parents organization owners;
6. enroll each child through Google or a single-use Authentik invitation, then
   add the canonical household principal to `gitea-users`;
7. verify each child becomes a separate, non-admin Gitea account;
8. grant write access only to explicitly assigned repositories or teams;
9. keep organization and repository settings parent-owned;
10. create one empty private test repository per intended workflow;
11. verify a child's organization-creation attempts fail through both the UI
    and API, and that the child cannot create a public repository, mirror,
    webhook, custom hook, or Actions workflow.

Never merge or link accounts because email addresses match. Roles come from
parent-managed Authentik groups, not Google domain/email, Tailscale membership,
Steam identity, Minecraft identity, or display name. Keep the stable Authentik
issuer and subject as the application identity link.

Browser OIDC does not authenticate Git operations. Each child uses a separate
SSH key or a narrowly scoped Gitea credential. Disabling Authentik is not
complete offboarding: also disable the Gitea user and revoke Gitea sessions,
tokens, and SSH keys.

Do not depend on the maintainer's username, email, Google Cloud project,
GitHub OAuth, tailnet, or organization.

A Minecraft friend does not need source access merely to join the game server.

---

## 13. Run the privacy acceptance matrix

Do not declare the service ready until all rows pass:

| Actor/path | Expected result |
|---|---|
| Approved child on the tailnet | Can sign in with Authentik and clone/pull/push an assigned private test repository |
| Anonymous tailnet browser/API/Git | Cannot enumerate or read users, organizations, repositories, API data, or a known private repository |
| Different child account | Cannot read or write a sibling’s unassigned repository |
| Child settings and API | Cannot create an organization, make a repository public, add a mirror/webhook, enable Actions, or administer the organization |
| Approved household Google account | Completes the exact Phase-0-selected Authentik callback and maps to the intended principal |
| Unapproved Google account | Cannot enroll or receive a Gitea authorization claim |
| Invited child with another email | Single-use invitation plus password/passkey works; email alone does not |
| Same email from two sources | No automatic merge or account link |
| Revoked child | Authentik, Gitea web, token, and SSH access are revoked; the local clone remains intact |
| TLS or SSH pin mismatch | Fails closed |
| Gitea outage | Local commit/build/test/play still works; sync reports an offline warning |
| Pod/node restart | Repositories, database, TLS identity, and optional SSH identity persist |
| Tailscale disconnected | Cannot reach HTTPS or optional SSH |
| External IPv4 and IPv6 | Cannot reach HTTPS or optional SSH through any other path |

From an approved tailnet client:

- verify TLS without bypass flags;
- verify `tailscale set --accept-dns=true` behavior and the exact MagicDNS name;
- verify Authentik discovery/issuer and Gitea callback use no `home.lab` value;
- inspect `kubectl get service --all-namespaces`;
- inspect every Ingress/Gateway/TCP route;
- inspect node listening ports;
- inspect router forwarding and UPnP state;
- confirm no public tunnel or Funnel is running.

With Tailscale disconnected and from a genuinely external network:

- query a public resolver for both A and AAAA records;
- test the router’s public IPv4 using the private Gitea Host/SNI name;
- test every globally routed IPv6 address that could reach an ingress node;
- test the optional SSH port;
- confirm all attempts fail before application authentication.

Testing from another Wi-Fi device on the same LAN while it is still connected
to the tailnet is not an external test.

Keep addresses, scans, screenshots, and logs in the private `my_home`, not in a
public issue.

---

## 14. Enroll Lava Chicken OS without an admin token

The planned Epic adds a versioned, non-secret site contract. A household-owned
example is:

```json
{
  "schema": "org.lavachicken.minecraft-git",
  "contract_version": 2,
  "policy": "tailnet-authentik-private-v1",
  "web_url": "https://REPLACE_GITEA_TAILNET_FQDN/",
  "transport": {
    "type": "tailscale",
    "require_magic_dns": true
  },
  "identity": {
    "type": "oidc",
    "issuer": "https://REPLACE_AUTHENTIK_TAILNET_FQDN/application/o/gitea/",
    "subject_binding": "issuer-and-subject"
  },
  "ssh": {
    "enabled": false,
    "host": "REPLACE_GITEA_SSH_HOST",
    "port": 2222,
    "host_key_sha256": "REPLACE_GITEA_SSH_HOST_KEY_SHA256"
  },
  "organization": "minecraft-lab"
}
```

This contains no password, token, private key, account roster, repository list,
kubeconfig, or Gitea administrator endpoint.

The planned parent-run command is:

```bash
sudo lacos minecraft site enroll \
  site/lacos-minecraft-site.local.json
```

That command does not exist yet; it is an Epic deliverable. Until it ships, do
not work around it by baking a household endpoint, issuer, or tailnet into the
public image.

Enrollment must fail closed when:

- the contract or policy version is unsupported;
- the client is not connected to the expected private Tailscale transport or
  is not accepting MagicDNS;
- the web URL, discovery document, issuer, or callback uses a different host,
  `home.lab`, an IP address, HTTP, or a Kubernetes name;
- HTTPS does not chain to a publicly trusted root without a bypass;
- the service remains reachable with Tailscale disconnected;
- optional SSH host identity differs;
- the service reports anonymous or public policy.

For each child, LaCOS will create or show only a dedicated public key. The
parent adds that public key to the child’s non-admin Gitea account. LaCOS and
Nugget never receive an administrator token.

---

## 15. Push `my_home` only after Gitea passes

Once the service and policy tests pass:

1. create an empty private `my_home` repository in the parent-owned
   organization;
2. confirm it has no mirror;
3. add the household’s own Gitea as the only remote;
4. inspect the remote;
5. push the existing local history.

Example SSH form, only if the optional private SSH path is enabled and pinned:

```bash
MY_HOME_DIR="${MY_HOME_DIR:-${HOME}/my_home}"
cd "${MY_HOME_DIR}"
git remote add origin \
  "ssh://git@YOUR_PRIVATE_GITEA_HOST:YOUR_PRIVATE_SSH_PORT/YOUR_ORG/my_home.git"
git remote -v
git push --set-upstream origin main
```

For HTTPS Git, use the URL advertised by the private Gitea and store the
individual credential in the user’s credential manager. Do not put it in the
remote URL.

Do not add a GitHub mirror. Keep an encrypted off-cluster copy of the bootstrap
repository because storing Gitea’s only recovery instructions inside Gitea
creates a circular failure.

---

## 16. Back up and prove restore

High availability, replicated storage, PVC snapshots, k3s datastore snapshots,
and extra Git clones are useful, but none alone is a complete Gitea backup.

A recovery set must consistently include:

- the PostgreSQL database;
- Git repositories;
- LFS objects;
- attachments and releases;
- Gitea configuration;
- persistent SSH host keys, if SSH is enabled;
- Gitea encryption/signing material required to decrypt restored data;
- the Gitea Authentik authentication-source definition, client identity, group
  contract, and protected client-secret recovery or rotation procedure;
- organization, team, issue, and permission metadata;
- the pinned chart archive, `versions.lock`, rendered checksums, and private
  runbook;
- protected Kubernetes-secret, tailnet-policy, and break-glass recovery
  material.

Official Gitea guidance warns that the database and repository data can become
inconsistent if they change during a dump. Use a documented maintenance or
quiesce procedure and a native PostgreSQL dump. Encrypt the recovery set and
copy it to separate, off-cluster media inside the household trust boundary.

The k3s datastore also needs its own cluster-level backup. Follow the official
k3s instructions for the cluster’s datastore type and protect the k3s server
token required for recovery. That cluster backup does not replace the
application-level Gitea/PostgreSQL recovery set.

At least quarterly and before every upgrade:

1. restore into an isolated namespace or disposable cluster with no production
   ingress;
2. restore PostgreSQL and Gitea data as one recovery point;
3. restore the expected canonical FQDN, Authentik OIDC, and optional SSH
   identity;
4. verify break-glass recovery, everyday parent login, and child authorization;
5. verify organizations, teams, issues, releases, attachments, and LFS;
6. clone, commit, push, and pull a private test repository;
7. rerun the privacy policy tests;
8. record evidence privately.

A backup job is not complete until this drill succeeds.

---

## 17. Upgrade deliberately

Do not enable unattended chart, Gitea, PostgreSQL, or major k3s upgrades for
this service.

For each change:

1. read the chart, Gitea, and database breaking-change notes;
2. create and verify a fresh recovery set;
3. restore it in isolation;
4. download and verify the new pinned chart;
5. update one application or database pin at a time;
6. render and diff the complete Kubernetes output;
7. test the upgrade against the restored copy;
8. test rollback by restore, not only `helm rollback`;
9. schedule a maintenance window;
10. deploy;
11. rerun tailnet-DNS, OIDC, anonymous, cross-user, off-tailnet, backup, and
    LaCOS contract tests;
12. tag the known-good `my_home` commit.

Database migrations may make a Helm rollback insufficient. The tested recovery
set is the real rollback.

---

## 18. Teardown safely

Removing Gitea is not the same as deleting its data.

Before any teardown:

1. confirm the exact kube context and namespace;
2. take a final encrypted backup;
3. prove it can restore;
4. revoke application tokens and keys;
5. remove the Tailscale Ingress, optional SSH exposure, and service grant
   first;
6. verify the service is unreachable;
7. uninstall only the Gitea release;
8. preserve and inspect PVCs and their reclaim policies.

Deleting PVCs/PVs, CA keys, database dumps, or backup media is a separate,
irreversible parent-only decision. Do not use namespace deletion as the normal
uninstall path, and never uninstall k3s merely to remove Gitea; that cluster may
host other applications.

Keep local project clones. Remove only dedicated OIDC settings, scoped
credentials, and host-key entries that are no longer shared by another home
service.

---

## 19. Clean-room definition of done

The guide and starter are complete when a test can prove:

1. A fresh user with an empty home, no `gh` authentication, no maintainer key,
   and no private-repository access can initialize `my_home`.
2. Only installed or public artifacts are needed to render the deployment.
3. The new repository starts with no remote and later pushes only to the
   household’s own private Gitea.
4. No generated file contains a maintainer identity, home detail, GitHub
   remote, kubeconfig, or plaintext secret.
5. All chart and rendered workload, init, hook, job, and test image inputs are
   exact and verified.
6. The rendered baseline contains no public Service/Ingress, runner, Actions
   unit, privileged pod, host mount, unexpected Secret, or credential-bearing
   chart-generated Secret. Public fixtures contain no real household value;
   private household renders permit schema-defined non-secret site values only
   at exact, chart-versioned key paths.
7. Authenticated use from an approved tailnet client succeeds; anonymous,
   cross-user, off-tailnet, and external access fails.
8. Every client accepts Tailscale DNS; Authentik uses the exact
   Phase-0-selected FQDN and Gitea uses its canonical MagicDNS FQDN; no issuer,
   callback, or service setting uses `home.lab` or a failed candidate.
9. An approved Google account and an invited arbitrary-email child can sign in,
   while unapproved enrollment, duplicate/edited email, invitation replay, and
   email-based automatic linking fail.
10. Gitea uses native Authentik OIDC and local parent-managed authorization
    claims; Git uses separate per-user SSH/scoped credentials.
11. A child cannot publish, mirror, add webhooks, enable Actions, or administer
   the service.
12. Pod/node restarts preserve the intended state.
13. Gitea downtime does not stop local Git/build/play.
14. Off-cluster material can rebuild and restore the full service without
    first accessing the failed Gitea.
15. Upgrade and teardown procedures preserve a verified recovery path.

---

## References

- [Official Gitea Kubernetes installation](https://docs.gitea.com/installation/install-on-kubernetes)
- [Official Gitea Helm chart repository](https://dl.gitea.com/charts/)
- [Gitea configuration cheat sheet](https://docs.gitea.com/administration/config-cheat-sheet)
- [Gitea access-control permissions](https://docs.gitea.com/usage/access-control/permissions)
- [Gitea Actions overview](https://docs.gitea.com/usage/actions/overview)
- [Gitea backup and restore](https://docs.gitea.com/usage/backup-and-restore)
- [Authentik Gitea integration](https://integrations.goauthentik.io/services/gitea/)
- [Authentik Google OAuth source](https://docs.goauthentik.io/users-sources/sources/social-logins/google/cloud/)
- [Tailscale Kubernetes Operator installation](https://tailscale.com/docs/kubernetes-operator/install-operator)
- [Tailscale private Kubernetes Ingress](https://tailscale.com/docs/kubernetes-operator/ingress/expose-workload-to-tailnet-l7)
- [Tailscale custom-domain Gateway pattern](https://tailscale.com/docs/solutions/kubernetes-operator-byod-gateway-api)
- [Tailscale client DNS preferences](https://tailscale.com/docs/features/client/manage-preferences)
- [k3s networking services and ServiceLB](https://docs.k3s.io/networking/networking-services)
- [k3s Secrets encryption](https://docs.k3s.io/security/secrets-encryption)
- [k3s backup and restore](https://docs.k3s.io/datastore/backup-restore)
