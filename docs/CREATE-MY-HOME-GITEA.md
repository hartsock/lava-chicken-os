# Create Your Own Private `my_home` and Gitea on k3s

**Audience:** a parent or home-lab administrator

**Status:** pre-implementation operator blueprint and acceptance contract

**Scope:** private, home-LAN-only source hosting for Lava Chicken OS projects
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
keep it entirely off GitHub, and use any private home domain and address plan.

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
  +-- private HTTPS ingress
  +-- optional separately protected Git/SSH endpoint
  +-- encrypted off-cluster backup

allowed home-LAN LaCOS client ----> private Gitea
anonymous or external client ----X
```

Gitea is a collaboration and recovery service. It is not required to edit,
commit, build, test, or locally play a Minecraft project. A Gitea outage must
leave those local workflows working.

---

## 1. Security baseline

The first supported configuration is deliberately narrow:

- an existing k3s cluster owned by the household;
- web access from explicitly allowed home-LAN sources only;
- no public DNS record;
- no router/NAT port forward;
- no UPnP mapping;
- no public tunnel, Funnel, or reverse-proxy route;
- external IPv4 and IPv6 traffic denied;
- TLS from a household-controlled CA;
- registration disabled and sign-in required;
- parent-owned organization and separate non-admin child accounts;
- every repository private;
- repository migration, mirrors, webhooks, custom Git hooks, and Actions
  disabled for the first release;
- no Actions runner;
- no Gitea administrator credential on a child machine or in Nugget;
- exact chart and image versions;
- encrypted, off-cluster backups with a tested restore.

Private DNS is naming, not access control. k3s normally deploys Traefik through
ServiceLB, which can bind ports 80 and 443 on every eligible node. Restrict the
ingress nodes and addresses, then enforce the same private-source rule at the
ingress, node firewall, and router.

VPN access is outside this baseline. Add it only after a separate parent-owned
threat-model review. Never turn it into public access.

---

## 2. Prerequisites

Have these ready before creating anything:

- a working k3s cluster reachable only through an administrator-controlled
  path;
- `kubectl` configured for that cluster;
- Helm 3;
- a durable `StorageClass` suitable for PostgreSQL and Gitea;
- a private ingress address or private ingress node pool;
- control of internal DNS;
- a home CA and a server certificate plan;
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
| `REPLACE_PRIVATE_LAN_CIDR` | allowed home LAN source range |
| `REPLACE_GITEA_WEB_HOST` | internal-only Gitea web name |
| `REPLACE_GITEA_SSH_HOST` | internal-only Git/SSH name |
| `REPLACE_GITEA_SSH_PORT` | optional private Git/SSH port |
| `REPLACE_PRIVATE_INGRESS_IP` | private ingress address |
| `REPLACE_INGRESS_CLASS` | the household’s private ingress class |
| `REPLACE_STORAGE_CLASS` | durable k3s storage class |
| `REPLACE_BACKUP_DESTINATION` | encrypted off-cluster target |
| `REPLACE_PARENT_ADMIN_USER` | local break-glass administrator |
| `REPLACE_PARENT_PRIVATE_EMAIL` | parent-chosen local Gitea email |
| `REPLACE_MINECRAFT_ORG` | parent-owned Gitea organization |
| `REPLACE_GITEA_IMAGE_DIGEST_HEX` | raw hexadecimal part of the pinned rootless Gitea image digest |
| `REPLACE_POSTGRES_IMAGE_DIGEST_HEX` | raw hexadecimal part of the pinned PostgreSQL image digest |
| `REPLACE_TLS_SECRET_NAME` | Kubernetes TLS Secret name |
| `REPLACE_GITEA_SSH_HOST_KEY_SHA256` | complete pinned OpenSSH host-key fingerprint, including `SHA256:` |
| `REPLACE_TLS_CA_SHA256` | complete pinned SHA-256 fingerprint of the household’s public CA certificate |

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
```

Record the intended context name in the ignored local values. The deploy helper
must:

1. compare the active context with that intended value;
2. print the cluster API endpoint and node names;
3. show the selected storage and ingress classes;
4. show existing LoadBalancer, NodePort, and host-port exposure;
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
- no public ingress controller will accept the planned Gitea host.

---

## 7. Choose private DNS, TLS, and optional SSH

Use an internal-only name, for example:

```text
git.home.arpa
```

The example is not a required name. Put the chosen record only in the
household’s private DNS.

From a LAN client, the name must resolve to the private ingress address. From a
public resolver, it must return no address:

```bash
GITEA_WEB_HOST="git.home.arpa"
dig +short "${GITEA_WEB_HOST}" A
dig +short "${GITEA_WEB_HOST}" AAAA
dig +short @1.1.1.1 "${GITEA_WEB_HOST}" A
dig +short @1.1.1.1 "${GITEA_WEB_HOST}" AAAA
```

Issue a server certificate containing the private name as a SAN. Keep the home
CA root private key encrypted and off-cluster. Put only the server certificate
and key in the Kubernetes TLS Secret, and distribute only the public CA
certificate to trusted clients.

Never use:

```text
curl -k
GIT_SSL_NO_VERIFY=true
StrictHostKeyChecking=no
blind ssh-keyscan as trust establishment
```

The Helm baseline keeps both Gitea Services at `ClusterIP`. Standard HTTP
Ingress does not carry SSH.

For the first deployment, HTTPS Git through the private ingress is sufficient.
If you add Git/SSH, expose it through a separate private load-balancer or TCP
route with a private address and a source allowlist. Persist the Gitea SSH host
keys and enroll their fingerprints through the parent-run trust flow. Do not
open a broad NodePort merely because it is convenient.

---

## 8. Create Secrets without putting values in Git

The baseline needs:

- a Gitea break-glass administrator username and password;
- a PostgreSQL administrator password;
- a PostgreSQL Gitea-user password;
- the TLS server certificate and key;
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
mechanism. Keep the age decryption key and CA root key outside both Git and the
cluster.

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
      DOMAIN: "REPLACE_GITEA_WEB_HOST"
      ROOT_URL: "https://REPLACE_GITEA_WEB_HOST/"
      PUBLIC_URL_DETECTION: never
      DISABLE_SSH: true
      START_SSH_SERVER: false

    security:
      INSTALL_LOCK: true
      DISABLE_GIT_HOOKS: true
      DISABLE_WEBHOOKS: true

    service:
      DISABLE_REGISTRATION: true
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

    session:
      COOKIE_SECURE: true
      SAME_SITE: strict

valkey-cluster:
  enabled: false

valkey:
  enabled: false
```

Do not paste database or administrator passwords into this file.

The policy checker has separate public-fixture and household modes. Both modes
must reject:

- any remaining `REPLACE_` value;
- any Secret outside an exact, chart-versioned allowlist;
- any credential, token, password, private key, or kubeconfig embedded in
  allowlisted chart-generated configuration or init-script Secrets;
- NodePort or public LoadBalancer services;
- public ingress hosts;
- privileged pods or host mounts;
- automatic service-account tokens;
- an Actions runner or enabled Actions repository unit;
- any mutable or unpinned image used by a container, init container, hook, job,
  or Helm test;
- a GitHub remote or mirror;
- maintainer names, domains, addresses, or keys.

Public-fixture CI uses only reserved synthetic values and also rejects any real
household literal. Household mode permits the schema-defined non-secret site
values—such as the private hostname, LAN range, and parent-selected local
email—only at exact, chart-versioned key paths where the pinned chart requires
them. It rejects those values everywhere else. Rendered household manifests and
checker evidence remain private and are never uploaded to public CI or issues.

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
9. configure private DNS and the TLS Secret;
10. add the private-ingress allowance immediately before applying the private
    HTTPS ingress;
11. configure the ingress/node/router source restrictions;
12. optionally add the separately protected Git/SSH policy and path;
13. add the backup allowance only when the backup job is configured;
14. run the complete privacy test matrix.

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

- the selected private ingress controller to Gitea HTTP;
- Gitea to PostgreSQL;
- Gitea and PostgreSQL to cluster DNS;
- explicitly required Gitea internal traffic;
- the parent-controlled backup job to the database, Gitea data, and backup
  target;
- the optional private SSH entry path to Gitea SSH.

NetworkPolicy is defense in depth. It does not replace host or router policy.

---

## 12. Bootstrap household identities

Use the chart-created break-glass administrator only for recovery and
bootstrap. At first login:

1. satisfy the forced password reset;
2. enable a second factor or passkey if supported by the household;
3. create a separate everyday parent account;
4. create a private parent-owned organization for Minecraft projects;
5. make the everyday parent an organization owner;
6. create one separate, non-admin account per child;
7. grant each child write access only to explicitly assigned repositories or
   teams;
8. keep organization and repository settings parent-owned;
9. create one empty private test repository per intended workflow;
10. verify a child’s organization-creation attempts fail through both the UI
    and API, and that the child cannot create a public repository, mirror,
    webhook, custom hook, or Actions workflow.

Do not depend on the maintainer’s username, email, GitHub OAuth, or organization.
The baseline needs no external identity provider.

A Minecraft friend does not need source access merely to join the game server.

---

## 13. Run the privacy acceptance matrix

Do not declare the service ready until all rows pass:

| Actor/path | Expected result |
|---|---|
| Authenticated child on allowed LAN | Can sign in and clone/pull/push an assigned private test repository |
| Anonymous LAN browser/API/Git | Cannot enumerate or read users, organizations, repositories, API data, or a known private repository |
| Different child account | Cannot read or write a sibling’s unassigned repository |
| Child settings and API | Cannot create an organization, make a repository public, add a mirror/webhook, enable Actions, or administer the organization |
| Revoked child | Loses web and Git access; the child’s local clone remains intact |
| CA or SSH pin mismatch | Fails closed |
| Gitea outage | Local commit/build/test/play still works; sync reports an offline warning |
| Pod/node restart | Repositories, database, TLS identity, and optional SSH identity persist |
| External IPv4 and IPv6 | Cannot reach HTTPS or optional SSH |

From inside the LAN:

- verify TLS without bypass flags;
- inspect `kubectl get service --all-namespaces`;
- inspect every Ingress/Gateway/TCP route;
- inspect node listening ports;
- inspect router forwarding and UPnP state;
- confirm no public tunnel or Funnel is running.

From a genuinely external network:

- query a public resolver for both A and AAAA records;
- test the router’s public IPv4 using the private Gitea Host/SNI name;
- test every globally routed IPv6 address that could reach an ingress node;
- test the optional SSH port;
- confirm all attempts fail before application authentication.

Testing from another Wi-Fi device on the same LAN is not an external test.

Keep addresses, scans, screenshots, and logs in the private `my_home`, not in a
public issue.

---

## 14. Enroll Lava Chicken OS without an admin token

The planned Epic adds a versioned, non-secret site contract. A household-owned
example is:

```json
{
  "schema": "org.lavachicken.minecraft-git",
  "contract_version": 1,
  "policy": "lan-only-private-v1",
  "web_url": "https://git.home.arpa/",
  "ssh": {
    "enabled": false,
    "host": "git.home.arpa",
    "port": 2222,
    "host_key_sha256": "REPLACE_GITEA_SSH_HOST_KEY_SHA256"
  },
  "organization": "minecraft-lab",
  "tls_ca_sha256": "REPLACE_TLS_CA_SHA256"
}
```

This contains no password, token, private key, account roster, repository list,
kubeconfig, or Gitea administrator endpoint.

The planned parent-run command is:

```bash
sudo lacos minecraft site enroll \
  site/lacos-minecraft-site.local.json \
  --ca /path/to/public-home-ca.crt
```

That command does not exist yet; it is an Epic deliverable. Until it ships, do
not work around it by baking a household endpoint or CA into the public image.

Enrollment must fail closed when:

- the contract or policy version is unsupported;
- the name resolves publicly or outside the approved private policy;
- TLS does not chain to the supplied CA;
- the CA fingerprint differs;
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
- organization, team, issue, and permission metadata;
- the pinned chart archive, `versions.lock`, rendered checksums, and private
  runbook;
- protected CA and Kubernetes-secret recovery material.

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
3. restore the expected TLS/SSH identity;
4. verify parent login and child authorization;
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
11. rerun LAN, anonymous, cross-user, external, backup, and LaCOS contract
    tests;
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
5. remove ingress, optional SSH exposure, and private DNS first;
6. verify the service is unreachable;
7. uninstall only the Gitea release;
8. preserve and inspect PVCs and their reclaim policies.

Deleting PVCs/PVs, CA keys, database dumps, or backup media is a separate,
irreversible parent-only decision. Do not use namespace deletion as the normal
uninstall path, and never uninstall k3s merely to remove Gitea; that cluster may
host other applications.

Keep local project clones. Remove only dedicated CA trust and host-key entries
that are no longer shared by another home service.

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
7. Authenticated LAN use succeeds; anonymous, cross-user, and external access
   fails.
8. A child cannot publish, mirror, add webhooks, enable Actions, or administer
   the service.
9. Pod/node restarts preserve the intended state.
10. Gitea downtime does not stop local Git/build/play.
11. Off-cluster material can rebuild and restore the full service without
    first accessing the failed Gitea.
12. Upgrade and teardown procedures preserve a verified recovery path.

---

## References

- [Official Gitea Kubernetes installation](https://docs.gitea.com/installation/install-on-kubernetes)
- [Official Gitea Helm chart repository](https://dl.gitea.com/charts/)
- [Gitea configuration cheat sheet](https://docs.gitea.com/administration/config-cheat-sheet)
- [Gitea access-control permissions](https://docs.gitea.com/usage/access-control/permissions)
- [Gitea Actions overview](https://docs.gitea.com/usage/actions/overview)
- [Gitea backup and restore](https://docs.gitea.com/usage/backup-and-restore)
- [k3s networking services and ServiceLB](https://docs.k3s.io/networking/networking-services)
- [k3s Secrets encryption](https://docs.k3s.io/security/secrets-encryption)
- [k3s backup and restore](https://docs.k3s.io/datastore/backup-restore)
