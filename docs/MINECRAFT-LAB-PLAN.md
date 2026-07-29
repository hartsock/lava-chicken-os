# Lava Chicken OS: Minecraft Modding, Multiplayer, and VR Lab

**Status:** Proposed execution plan

**Repository reviewed:** this repository, `main`, July 29, 2026

**Infrastructure dependency:** a user-owned private home-configuration
repository, conventionally named `my_home`

---

## Executive summary

Lava Chicken OS already contains most of the raw ingredients for a Minecraft programming machine:

- Prism Launcher
- MCreator
- JDK 21 and Gradle installation through SDKMAN
- Fabric and NeoForge starter repositories
- IntelliJ IDEA Community installation in the legacy bootstrap path
- a resident local coding agent, Nugget
- a Minecraft modding coaching skill
- ALVR/WiVRn-oriented wireless VR support
- firewall diagnostics and narrowly scoped ALVR rules

The project does **not** need a new collection of unrelated installers. It needs a coherent product layer that turns those ingredients into a repeatable path from:

> “I changed something in Minecraft” → “I wrote code, tested it, and my
> friends can play it.”

The recommended design is a **three-lane Minecraft Lab**:

1. **Paper plugin lane:** the fastest route from code to a multiplayer experience. Friends can join with an ordinary Java client because most experiments run on the server.
2. **Fabric mod lane:** the route for deeper changes such as custom blocks, items, mobs, rendering, and client behavior.
3. **Vivecraft VR lane:** a reproducible Prism profile that combines the Fabric lane with the OS’s existing Linux VR transport.

MCreator remains the visual first rung, but it should be treated as a bridge into code rather than the center of the platform.

All three lanes share a **local-first, private source-control foundation**:

```text
local project
  -> local Git commit
  -> authenticated private repository on the in-home Gitea
  -> no automatic public mirror
```

Each household creates its own `my_home` locally and deploys a pinned Gitea
release to its own k3s cluster, or enrolls an existing compatible private
Gitea. No maintainer account, private repository, GitHub login, hostname, or
network is a dependency. Lava Chicken OS supplies the generic client contract,
a versioned secret-free starter, and clean-room instructions. Each household
owns its live topology, identities, secrets, and backups. Editing, building,
and local playtesting must continue when Gitea is unavailable.

The most important architectural decision is to **pin complete, tested version sets**. As of July 2026, the newest Fabric and NeoForge documentation targets the Minecraft 26.x line and JDK 25, while Lava Chicken OS currently installs JDK 21 and clones 1.21-era examples. Both can be useful, but they must be separate named tracks:

- `classroom`: boring, tested, stable, optimized for successful learning sessions
- `experimental`: current ecosystem, allowed to break, used for porting and exploration

Never let a script silently substitute “latest.”

---

## 1. Product goal

Turn Lava Chicken OS into a kid-centered Minecraft software workshop where a child can:

1. create a project from a friendly launcher or command;
2. make one understandable code change;
3. build and launch it without manually wiring a toolchain;
4. invite friends into a parent-controlled server;
5. observe failures without destroying the working setup;
6. recover from mistakes;
7. commit work locally and push it to a private in-home repository;
8. optionally enter the same world in VR;
9. gradually move from visual logic to Java and real software-engineering habits.

The machine should feel less like a preconfigured Linux workstation and more like a **game-development console**.

The desired motivational loop is:

```text
idea
  -> small code change
  -> automatic build
  -> one-click playtest
  -> friends react
  -> inspect what happened
  -> commit
  -> make the next change
```

The social payoff matters. “My code made a chicken explode into harmless confetti when Alex said a command” is a much stronger lesson than “Gradle printed BUILD SUCCESSFUL.”

---

## 2. Current-state audit

### 2.1 What already exists

| Area | Current implementation | Assessment |
|---|---|---|
| Base OS | Bazzite/SteamOS-oriented immutable gaming OS | Good foundation |
| Launcher | Prism Launcher installed as a Flatpak | Correct choice for isolated modded instances |
| Visual authoring | MCreator installed per user | Useful first rung |
| Java development | JDK 21 and ambient Gradle via SDKMAN in `scripts/60-modding-tools.sh` | Works for the old bootstrap path, but needs multi-user and version-matrix work |
| IDE | IntelliJ IDEA Community in the legacy modding script | Good choice, but it is not in the system-wide default app set |
| Mod loaders | Fabric example clone and NeoForge MDK clone | Useful proof of concept, but unpinned moving repositories are not reproducible starter kits |
| Coaching | `common/newt-skills/modding/SKILL.md` | Strong safety-oriented player/modding guidance |
| Local AI | Nugget/newt-agent + Ollama | Potentially valuable if constrained to coaching and explainable edits |
| VR transport | `lacos vr`, ALVR firewall handling, WiVRn guidance | Good transport layer |
| VR game integration | None specific to Minecraft/Vivecraft | Major missing bridge |
| Multiplayer development | No managed Paper server or plugin starter | Major missing social-programming path |
| Private source hosting | No account-neutral clean-room bootstrap exists | Publish a blank `my_home` starter and own-k3s Gitea guide; support adopting an existing compatible service |
| Reproducible modpack | No checked-in profile manifest or lock | Major missing distribution path |
| Project UX | No `lacos minecraft` command family | Tools exist, but there is no coherent product surface |
| CI | General OS/install testing | No generated-project build matrix or Minecraft Lab smoke tests |

### 2.2 Important gaps

The current setup is approximately a shelf containing good tools. It is not yet a workshop.

The most important gaps are:

1. **No single source of truth for Minecraft, loader, Java, Vivecraft, and server versions.**
2. **No stable project generator.** Cloning the current upstream example is convenient but not reproducible.
3. **No multiplayer-first programming path.**
4. **No managed server lifecycle, whitelist, backup, or parent-control surface.**
5. **No generated Prism development and VR profiles.**
6. **No automatic deployment from a build into a local playtest environment.**
7. **No Minecraft-specific doctor command that checks the entire chain.**
8. **No CI job proving a newly generated project still builds.**
9. **The app model is inconsistent.** Prism and MCreator reach every user; JDKs and IntelliJ do not necessarily do so.
10. **The current modding skill is intentionally read-only.** A separate, narrowly sandboxed development skill is required if Nugget will edit code.
11. **There is no clean-room private project-hosting workflow.** A new household
    cannot initialize its own home repository and Gitea without maintainer
    context, and generated projects do not
    discover, authenticate to, push to, or recover from the in-home Gitea.
12. **The public/private repository boundary is undocumented.** Without an
    explicit contract, home infrastructure details or children’s projects could
    accidentally escape into this public repository or a GitHub mirror.

---

## 3. Recommended learning architecture

### 3.1 Lane A: Paper plugins, “make something friends can play”

This should be the default code-first lane.

Paper plugins are server-side Java components. For many ideas, friends can join the server using an unmodified Java Edition client. That removes the most discouraging part of early modding: convincing every friend to install an exact matching client mod set.

Good first projects include:

- `/chicken` spawns a named chicken
- stepping on a gold block launches fireworks
- a scoreboard tracks lava jumps
- sleeping starts a vote instead of immediately skipping night
- a treasure hunt command generates clues
- a “freeze tag” minigame
- a custom lobby rule
- a simple economy using only in-game points
- a cooperative boss event
- a server-side “Lava Chicken” game mode

This lane teaches:

- Java syntax
- events and callbacks
- commands
- state
- collections
- configuration
- permissions
- debugging
- server logs
- concurrency and the game tick
- deployment and versioning

It also produces the shortest path to the social reward.

### 3.2 Lane B: Fabric mods, “change the game itself”

Fabric should be the default client/mod lane.

Use it when a project needs:

- custom blocks or items
- custom entities or mobs
- rendering
- client keybindings
- new screens
- world generation
- changes that cannot be expressed as a server plugin
- deeper access to Minecraft behavior

Fabric is already the beginner recommendation in the current Nugget modding skill. Keep NeoForge as an optional compatibility lane for projects or modpacks that require it, not as an equal first choice. Supporting multiple loaders on day one multiplies failure modes before it multiplies learning.

### 3.3 Lane C: Vivecraft, “walk inside the thing you built”

Vivecraft should be a generated Prism instance based on the same pinned Fabric version as the stable mod lane.

The OS already handles the hard Linux-to-headset transport questions through WiVRn or ALVR. The missing layer is:

```text
Minecraft Java
  + pinned Fabric loader
  + Fabric API
  + Vivecraft
  + performance mods
  + the child’s current mod
  + a known-good Prism configuration
```

The VR lane should be a playtest target, not a separate development ecosystem.

### 3.4 Rung zero: MCreator

MCreator is appropriate for the first visible success:

- define an item
- define a block
- add a simple procedure
- export a JAR
- run it in a clean Prism instance

The educational danger is letting generated code become a magic swamp. The transition criterion should be explicit:

> When the child wants behavior that is awkward in visual procedures, open the generated Java, explain one method, and recreate a tiny version in a handwritten project.

MCreator is a launch ramp. It should not become the entire airport.

### 3.5 Optional pre-Java rung: data packs and command functions

A small data-pack lane can help children who are not yet ready for Java but want to write text rather than use visual blocks.

Data packs teach:

- folder structure
- namespaces
- JSON
- commands
- functions
- predicates
- recipes
- loot tables
- iteration through reload-and-test cycles

This lane should be optional. Do not let it delay the Paper path when the child is eager to program.

---

## 4. Version strategy

### 4.1 Do not have a “latest” configuration

Minecraft modding is a coupled version graph:

```text
Minecraft
  <-> Java
  <-> loader
  <-> mappings
  <-> loader API
  <-> Gradle plugin
  <-> Gradle wrapper
  <-> mods
  <-> Vivecraft
  <-> server implementation
  <-> plugin API
```

A single automatic upgrade can invalidate the entire graph.

Create a repository-owned manifest such as:

```text
common/minecraft/versions.toml
```

Example shape:

```toml
schema = 1

[tracks.classroom]
minecraft = "PIN_EXACT_VERSION"
java = 21
fabric_loader = "PIN_EXACT_VERSION"
fabric_api = "PIN_EXACT_VERSION"
fabric_loom = "PIN_EXACT_VERSION"
gradle = "PIN_EXACT_VERSION"
paper = "PIN_EXACT_VERSION"
vivecraft = "PIN_EXACT_VERSION"
sodium = "PIN_EXACT_VERSION"
status = "supported"

[tracks.experimental]
minecraft = "PIN_EXACT_CURRENT_VERSION"
java = 25
fabric_loader = "PIN_EXACT_VERSION"
fabric_api = "PIN_EXACT_VERSION"
fabric_loom = "PIN_EXACT_VERSION"
gradle = "PIN_EXACT_VERSION"
paper = "PIN_EXACT_VERSION"
vivecraft = "PIN_EXACT_VERSION"
sodium = "PIN_EXACT_VERSION"
status = "best-effort"
```

The values must be exact, not ranges.

### 4.2 Stable classroom track

The stable track should initially remain on a well-supported 1.21-era release with JDK 21, because:

- the existing LaCOS toolchain already expects JDK 21;
- the current starter material is 1.21-oriented;
- Vivecraft supports 1.21.x;
- many community mods and tutorials target that era;
- the point of a classroom lane is successful repetition, not release chasing.

Select one exact version after a hardware smoke test and pin every component around it.

### 4.3 Experimental track

The 2026 ecosystem has moved its newest development documentation to Minecraft 26.x and JDK 25. Support that as a separate track.

The experimental track exists to:

- learn new APIs;
- port projects;
- test future classroom upgrades;
- catch toolchain drift;
- keep Lava Chicken OS from fossilizing.

It must not replace the classroom track until it passes the full acceptance suite.

### 4.4 Upgrade ceremony

A track upgrade should be a pull request containing:

1. a manifest change;
2. regenerated lock files;
3. successful Fabric starter build;
4. successful Paper starter build;
5. successful test-server boot;
6. successful Prism instance import;
7. successful non-VR launch on the reference machine;
8. manual VR smoke test where hardware is available;
9. documented migration notes;
10. rollback confirmation.

This is a small-scale release train, not a version roulette wheel.

---

## 5. Proposed repository layout

```text
common/
  bin/
    lacos-minecraft
  minecraft/
    versions.toml
    profiles/
      classroom.toml
      experimental.toml
      vr.toml
    prism/
      instance-template/
      icons/
    server/
      container.env
      server.properties
      permissions/
    templates/
      paper-plugin/
      fabric-mod/
      datapack/
    curriculum/
      00-first-change.md
      10-paper-command.md
      20-paper-event.md
      30-fabric-item.md
      40-fabric-block.md
      50-multiplayer-release.md
      60-vr-playtest.md
  newt-skills/
    modding/
      SKILL.md
    minecraft-dev/
      SKILL.md
    minecraft-server/
      SKILL.md
    minecraft-vr/
      SKILL.md

docs/
  MINECRAFT-LAB.md
  MINECRAFT-LAB-PARENT-GUIDE.md
  MINECRAFT-LAB-TROUBLESHOOTING.md

test/
  minecraft/
    test-version-manifest.sh
    test-project-generation.sh
    test-paper-build.sh
    test-fabric-build.sh
    test-prism-profile.sh
    test-server-config.sh
```

Keep the user’s work outside the immutable image:

```text
~/MinecraftLab/
  projects/
    paper/
    fabric/
    datapacks/
  instances/
  exports/
  screenshots/
  lessons/
```

Server state should live in a managed state directory with backups, not inside a child’s project:

```text
/var/lib/lava-chicken/minecraft/
  server/
  backups/
  manifests/
```

---

## 6. The `lacos minecraft` product surface

Add a single command family and route it through the existing `lacos` dispatcher.

### 6.1 Proposed commands

```text
lacos minecraft status
lacos minecraft doctor
lacos minecraft doctor --json

lacos minecraft toolchain install
lacos minecraft toolchain status

lacos minecraft new paper <name>
lacos minecraft new fabric <name>
lacos minecraft new datapack <name>

lacos minecraft build [project]
lacos minecraft test [project]
lacos minecraft play [project]
lacos minecraft deploy [project]

lacos minecraft git status [project]
lacos minecraft git connect [project]
lacos minecraft git push [project]
lacos minecraft git clone <project>

lacos minecraft instance create classroom
lacos minecraft instance create vr
lacos minecraft instance reset <name>
lacos minecraft instance export <name>

lacos minecraft server up
lacos minecraft server down
lacos minecraft server status
lacos minecraft server logs
lacos minecraft server backup
lacos minecraft server restore <backup>
lacos minecraft server whitelist add <player>
lacos minecraft server whitelist remove <player>

lacos minecraft vr doctor
lacos minecraft vr setup
lacos minecraft vr play [project]

lacos minecraft lesson list
lacos minecraft lesson start <lesson>
lacos minecraft lesson status
```

### 6.2 Design rules

- Commands must be idempotent.
- Commands must explain what they changed.
- Destructive actions require an explicit confirmation or `--yes`.
- Child-facing commands must not require `sudo`.
- Parent-only actions should use the project’s existing polkit/sudo delegation pattern.
- `doctor --json` must exist so Nugget and CI can reason over structured results.
- The CLI should never ask for Microsoft, Steam, or Meta passwords.
- The CLI and Nugget must never receive or store a Gitea administrator token.
- Gitea endpoint, organization, and CA settings are non-secret site
  configuration supplied during parent-run setup; no home-specific value is
  baked into this public repository or image.
- `git connect` may add a verified remote and enroll a user-owned public key,
  but repository and account administration remain parent-owned.
- Local edit, commit, build, test, and play commands must work while Gitea is
  unavailable. A failed push is recoverable pending sync, not a failed project.
- No command automatically creates a GitHub remote or enables a public mirror.
- Network downloads must come from pinned official sources and be hash-verified.
- The CLI must distinguish:
  - project source;
  - build output;
  - Prism instance;
  - server deployment;
  - world data.

A child should not have to understand all five before making a first change.

---

## 7. Toolchain changes

### 7.1 Stop installing ambient Gradle

Use each project’s Gradle wrapper.

The current script installs Gradle globally through SDKMAN. That creates avoidable ambiguity:

- project expects one Gradle version;
- user’s ambient `gradle` points to another;
- a tutorial invokes the wrong one;
- the build fails in an educationally useless way.

Install JDKs, not ambient Gradle. Generated projects should always use:

```bash
./gradlew build
./gradlew runClient
```

### 7.2 Install both supported JDKs

The classroom and experimental tracks require different Java versions.

Provide:

- Temurin/OpenJDK 21
- Temurin/OpenJDK 25

Each generated project should declare its Java toolchain and include a local environment hint such as `.sdkmanrc` or an equivalent repository-owned selection file.

`lacos minecraft doctor` must report:

```text
PASS JDK 21 available
PASS JDK 25 available
PASS classroom Fabric template selects JDK 21
PASS experimental Fabric template selects JDK 25
```

Do not depend on whatever `java` happens to be first in `PATH`.

### 7.3 Make the toolchain multi-user

The current `scripts/60-modding-tools.sh` installs tools for the user who runs it. Lava Chicken OS is explicitly a family machine with separate kid accounts.

Choose one consistent model:

**Recommended model**

- system-wide Flatpaks for Prism and IntelliJ;
- per-user MCreator, as already implemented;
- verified shared JDK archives in an OS-managed location;
- per-user project directories;
- per-user Prism instances;
- shared read-only starter templates;
- child-owned source trees.

This avoids duplicating multiple gigabytes of JDKs while preserving user isolation.

### 7.4 Add IntelliJ to the converged app set

`lacos-install-apps` currently installs Prism but not IntelliJ, while the legacy modding script installs IntelliJ per user.

Converge the product behavior:

- add IntelliJ IDEA Community to the system Flatpak app set;
- preinstall or clearly automate the Minecraft Development plugin if licensing and Flatpak behavior permit;
- otherwise make plugin installation the first explicit IDE step and verify it in the doctor output;
- preconfigure access to `~/MinecraftLab`;
- do not broadly disable Flatpak sandboxing.

### 7.5 Replace moving clones with pinned starter kits

The current script clones:

- `FabricMC/fabric-example-mod`
- a 1.21 NeoForge MDK repository

Those branches can change beneath an installed OS.

Replace them with one of:

1. small repository-owned starter kits that contain no Minecraft binaries;
2. generated projects from pinned templates;
3. upstream templates fetched at a pinned commit and verified by hash.

The starter kits should be deliberately tiny. A child’s first project should not begin with an archaeological dig through thirty example classes.

---

## 8. Project generators

### 8.1 Paper starter

Generate:

```text
my-project/
  README.md
  build.gradle.kts
  settings.gradle.kts
  gradlew
  gradlew.bat
  gradle/wrapper/
  src/main/java/.../MyProjectPlugin.java
  src/main/resources/plugin.yml
  src/test/java/.../
  .gitignore
  .editorconfig
  .java-version
```

The starter behavior should be immediately visible:

- log a startup message;
- register `/lava-chicken`;
- reply with a friendly message;
- optionally spawn a chicken when run by a player.

Include comments only where they teach an immediate concept.

### 8.2 Fabric starter

Generate:

```text
my-mod/
  README.md
  build.gradle
  settings.gradle
  gradle.properties
  gradlew
  gradlew.bat
  gradle/wrapper/
  src/main/java/.../MyMod.java
  src/main/resources/fabric.mod.json
  src/main/resources/assets/<modid>/
  src/test/java/.../
  .gitignore
  .editorconfig
  .java-version
```

The starter should add one small visible object or behavior and include a GameTest or loader-aware unit test where practical.

### 8.3 Data-pack starter

Generate a namespaced data pack with:

- `pack.mcmeta`
- one function
- one recipe or advancement
- a test command
- a README that shows `/reload` and the invocation command

### 8.4 Naming validation

The generator should explain and enforce:

- display name versus project directory;
- mod/plugin ID;
- Java package;
- lowercase namespace rules;
- no spaces in IDs;
- no emoji in source paths;
- no cloud-sync directory;
- Git repository initialization.

It should propose a safe default package without pretending the family owns a public DNS domain. For example:

```text
family.lavachicken.<project>
```

If the project will be published, the package can be changed later.

---

## 9. Private in-home Gitea project hosting

### 9.1 Repository ownership boundary

Lava Chicken OS never owns or silently deploys a Git service. Support two
parent-operated paths:

1. initialize a new user-owned `my_home` from the public blank starter and
   deploy a new LAN-only Gitea to the household’s own k3s cluster; or
2. enroll and harden an existing compatible private Gitea.

`my_home` is a convention, not a repository that users clone from the
maintainer. A household may choose another name. The ownership boundary remains
the same:

| Responsibility | Owning repository |
|---|---|
| Generic blank-home starter, clean-room guide, local Git initialization, commits, remote setup, push/pull/clone UX, site-setting discovery, CA trust, SSH host verification, and doctor checks | public `lava-chicken-os` |
| Rendered Gitea configuration and version, database, storage, private DNS, TLS/CA, ingress, firewall, identity, authorization, organization/repository bootstrap, backups, disaster recovery, and any runners | that household’s private `my_home` |
| Children’s Minecraft source, issues, releases, and project history | private repositories on the in-home Gitea |

The public repository may contain generic, placeholder-only, secret-free Helm
or Kubernetes templates and policy tests. It must not contain a household’s
rendered values, hostname, IP address, subnet, username, account roster,
certificate or SSH private key, kubeconfig, credential, repository list,
backup, or diagnostic evidence.

Gitea is the collaboration and recovery plane, not a runtime dependency.
Projects remain ordinary local Git repositories. A cluster outage must not
prevent editing, committing, building, running a development client, or
playtesting on the local server.

### 9.2 Clean-room `my_home` bootstrap

Publish the [clean-room home Gitea guide](CREATE-MY-HOME-GITEA.md) and a
versioned starter under `templates/my_home/`. Package the starter in the
installed OS and release artifacts so a parent needs neither a source checkout
nor any GitHub account.

The clean-room workflow is:

1. create a mode-`0700` local directory;
2. copy the secret-free starter without a `.git` directory, remote, identity,
   or site value;
3. run `git init -b main` and confirm `git remote -v` is empty;
4. fill explicit placeholders using a gitignored local overlay or
   SOPS/age-encrypted values;
5. keep the decryption key, home-CA root key, and break-glass credentials
   off-cluster and outside Git;
6. preflight the selected kube context, node architecture/resources, storage
   class, secrets encryption, private ingress address, private DNS, TLS plan,
   and off-cluster backup target;
7. print the target cluster identity and require parent confirmation before
   any install;
8. render and inspect pinned Gitea and database artifacts;
9. deploy namespace, durable storage, database, Gitea, NetworkPolicies, private
   ingress/SSH, and backup jobs;
10. bootstrap a local break-glass administrator, parent owner, private
    organization, and separate non-admin child identities without an external
    identity-provider dependency;
11. prove authenticated LAN access and external denial;
12. enroll LaCOS with a versioned non-secret site contract;
13. create a private `my_home` repository on the new Gitea and push the local
    history only after the service passes its privacy tests;
14. keep an encrypted off-cluster bootstrap copy and prove restore, avoiding
    the circular dependency of storing Gitea’s only recovery source in Gitea.

Clean-room acceptance starts with an empty home directory, no `gh`
authentication, no maintainer SSH key, and no access to a maintainer-owned
private repository. Generated content must contain no maintainer account,
domain, address, key, or remote.

### 9.3 Private service posture

The first supported posture is **home-LAN only**:

- publish the web and Git/SSH endpoints only through private addressing and
  private DNS;
- keep Gitea’s HTTP and SSH Kubernetes Services at `ClusterIP`; route web
  traffic through an explicitly private ingress, and expose SSH only through a
  separately source-restricted private path;
- do not assume k3s’s default Traefik/ServiceLB placement is private—restrict
  eligible nodes/addresses and enforce node and router firewalls;
- do not create public DNS records, router/NAT forwarding, UPnP mappings,
  public tunnels, “funnel” features, or public reverse-proxy routes;
- deny anonymous browsing and API access;
- disable open registration;
- force every newly created or push-created repository to be private;
- require authentication for all project access;
- use TLS from the home CA and install that CA through a parent-run LaCOS setup
  step—never teach users to bypass certificate validation;
- pin the TLS CA and SSH host fingerprints through a trusted parent-run channel;
- use non-root workloads, dropped capabilities, no privilege escalation,
  default-deny NetworkPolicies, no automatic service-account token, durable
  storage, and resource limits;
- require k3s datastore encryption whenever runtime values enter Kubernetes
  Secret objects; an external mechanism is an alternative only when it never
  persists plaintext in the Kubernetes API or datastore;
- never put runtime secrets inline in tracked Helm values;
- pin Gitea and database images by immutable version or digest;
- verify reachability from an allowed home client and non-reachability from an
  external network over both IPv4 and globally routable IPv6 as separate
  acceptance tests.

VPN access is not part of the first milestone. If it is added later, it requires
a parent-approved threat-model change and an explicit source allowlist. It must
remain private and must not create a public ingress path.

### 9.4 Identity and repository model

Create a parent-owned organization for Minecraft Lab projects:

- parents are organization owners and recovery administrators;
- each child has an individual, non-admin account;
- children receive write access only to their own projects or explicitly shared
  team projects;
- coaches and siblings receive no access unless a parent grants it;
- Minecraft friends do not need source access merely to join a game server;
- regular users cannot create organizations through either the UI or API;
- repositories start private and remain private;
- automatic push mirrors to GitHub or any other public forge are prohibited for
  this repository class.

Use a separate per-user SSH key or an equivalently scoped credential. The
private half stays in that user’s account and is never copied to Gitea, Nugget,
the OS image, or either infrastructure repository. The parent enrolls only the
public key and keeps account-recovery authority. Pin the service host key so a
DNS or network mistake fails closed.

For the first vertical slice, a parent creates the user and empty private
repository. `lacos minecraft git connect` verifies the configured endpoint and
adds it as `origin`; it does not need service-admin credentials.

### 9.5 Actions runner boundary

Treat a workflow file as executable code. Kid-controlled repositories must not
run on a privileged or general-purpose home-lab runner.

Keep Gitea Actions disabled for Minecraft repositories in the first release.
Template builds can run in this public repository’s existing CI. If private
project CI is added later, `my_home` must provide a dedicated runner pool with:

- ephemeral jobs;
- no host mounts or home-lab administrator credentials;
- no access to the Kubernetes control plane;
- narrowly allowed network egress;
- CPU, memory, disk, and time limits;
- parent-controlled enrollment and workflow enablement;
- a documented compromise-and-rebuild procedure.

### 9.6 Backup and recovery

Git clones protect source history, but they do not protect Gitea issues,
permissions, releases, or database metadata. The private infrastructure plan
must back up the repository data and database as a consistent set and prove a
restore on disposable infrastructure.

Keep these recovery domains separate:

- Gitea source and metadata;
- Minecraft server worlds and deployment metadata;
- Prism profile manifests;
- project build artifacts;
- parent-owned identity and CA recovery.

Do not use a public GitHub mirror as the disaster-recovery mechanism for
children’s repositories. At least one parent-controlled recovery copy must
remain inside the home trust boundary.

### 9.7 Cross-repository acceptance contract

The boundary is ready when all of the following are demonstrated:

1. An authenticated child account on an allowed home client can clone, push,
   pull, and recover a private project.
2. Anonymous web and API requests cannot enumerate or read projects.
3. A probe from outside the approved private network cannot reach the web or
   SSH service.
4. Creating a repository through every allowed path yields a private
   repository with no mirror.
5. Removing a child’s access blocks both web and Git access without deleting
   the child’s local work.
6. LaCOS reports a useful offline state when Gitea is down while local
   edit/build/test/play remains functional.
7. A backup-and-restore drill recovers source plus Gitea metadata.
8. Neither public repository nor diagnostic output contains home topology or
   credentials.

---

## 10. Build, deploy, and playtest loop

### 10.1 Paper

```text
edit
  -> ./gradlew test
  -> ./gradlew build
  -> copy JAR into managed server plugins directory
  -> controlled server restart
  -> join server
  -> run command / trigger event
```

Do not teach `/reload` as the normal plugin deployment mechanism. It often leaves stale plugin state. Restart the test server.

`lacos minecraft play` should automate the safe sequence.

### 10.2 Fabric

```text
edit
  -> ./gradlew test
  -> ./gradlew build
  -> ./gradlew runClient
```

For a friend-playable release:

```text
build
  -> copy JAR into the managed Prism classroom instance
  -> validate loader and Minecraft version
  -> export a small pack manifest
  -> friends import the matching instance
```

### 10.3 Fast feedback

The CLI should parse common Gradle failures and translate them into useful categories:

- wrong Java version;
- dependency download failed;
- loader mismatch;
- mod ID invalid;
- compilation error;
- missing resource;
- test failure;
- server boot failure;
- port already in use.

Show the raw log path after the friendly explanation. Do not hide the machine’s actual words.

---

## 11. Multiplayer server design

### 11.1 Why the server belongs in the product

A managed server is the bridge between programming and friendship.

Without it, every project ends at “it works on my machine.” With it, a child learns:

- deployment;
- shared state;
- user identity;
- permissions;
- logs;
- operational safety;
- backups;
- compatibility;
- release discipline.

### 11.2 Recommended server mode

Start with Paper for the classroom track.

The server should run as:

- a dedicated unprivileged service account;
- preferably a rootless Podman container or equivalently isolated service;
- a pinned image or pinned server artifact;
- `online-mode=true`;
- whitelist enabled;
- RCON disabled or bound only to localhost;
- no host filesystem access beyond its state directory;
- no automatic internet exposure.

### 11.3 Network policy

Default:

- reachable only on the home LAN;
- port `25565` scoped to private network ranges;
- no router port forwarding;
- no UPnP;
- no public server listing.

Remote play is deferred outside the first Epic. A later parent-approved design
may use a private mesh VPN with explicit friend/device membership, a
source-scoped firewall, online authentication, and the whitelist still enabled.
It requires its own threat-model review and must not change the Gitea LAN-only
baseline.

Do not expose a child-operated development server directly to the public internet.

### 11.4 Parent-owned controls

Only a parent account should be able to:

- enable remote access;
- add or remove whitelist entries;
- grant operator privileges;
- restore backups;
- change the server track;
- install arbitrary third-party plugins;
- expose network ports.

Children should be able to:

- start and stop the local test server;
- deploy their own project;
- view filtered logs;
- join and play;
- create a backup before an experiment;
- roll back their own plugin/mod deployment.

### 11.5 Backups

Before every deployment:

1. ask the server to save;
2. create a timestamped snapshot;
3. record:
   - project commit;
   - artifact hash;
   - server version;
   - plugin list;
   - world snapshot;
4. retain a small rolling window;
5. allow a parent to pin important worlds.

A child should be able to learn destructive power without permanently deleting Saturday.

---

## 12. Reproducible Prism instances

### 12.1 Required instances

Generate at least three named instances:

1. **Lava Chicken Vanilla**
   - clean control instance;
   - no mods;
   - proves account and base game work.

2. **Lava Chicken Lab**
   - pinned classroom Minecraft version;
   - Fabric loader;
   - Fabric API;
   - known-good performance mods;
   - local project deployment folder.

3. **Lava Chicken VR**
   - same Minecraft/Fabric baseline as Lab;
   - Vivecraft;
   - performance configuration;
   - VR-specific options;
   - local project deployment folder.

Optionally:

4. **Lava Chicken Experimental**
   - current Minecraft/JDK/toolchain;
   - clearly labeled as breakable.

### 12.2 Pack manifest

Store a manifest with:

- exact Minecraft version;
- exact loader version;
- exact mod URLs or project IDs;
- exact file hashes;
- required/optional classification;
- license metadata where available;
- client/server side classification.

Prism’s UI can remain the child-facing interface, but the source of truth should be repository-owned and diffable.

### 12.3 Safe acquisition

Retain the current safety rule:

- use Prism’s integrated Modrinth/CurseForge browser for human-selected community mods;
- use official project APIs or releases for automated pinned profiles;
- verify hashes;
- never install a mod distributed as an executable;
- never fetch a JAR from an SEO download site;
- never use cracked launchers or account-sharing services.

Automated OS-managed profiles and child-added exploratory mods should remain visibly distinct.

---

## 13. Minecraft VR integration

### 13.1 What LaCOS already solves

The existing VR work covers the transport layer:

- WiVRn-first guidance;
- ALVR fallback;
- LAN-scoped ALVR firewall rules;
- diagnostics;
- older AMD/Polaris H.264 guidance;
- SteamVR and headset pairing guidance.

That is valuable, but it does not yet make Minecraft a VR application.

### 13.2 Add a Minecraft VR composition layer

`lacos minecraft vr setup` should:

1. run `lacos vr doctor`;
2. verify Steam and SteamVR;
3. verify either WiVRn or ALVR;
4. create/update the pinned **Lava Chicken VR** Prism instance;
5. install the pinned Fabric loader;
6. install Fabric API;
7. install Vivecraft;
8. install a known-good performance set;
9. copy the selected local mod into the instance;
10. validate Java and memory configuration;
11. print the exact launch order;
12. preserve the non-VR Lab instance untouched.

### 13.3 VR multiplayer

Basic Vivecraft can join ordinary multiplayer worlds.

For richer multiplayer representation:

- a Fabric server can run the appropriate Vivecraft server component; or
- a Paper server can use the compatible Vivecraft server extension so non-VR players can see VR head/hand movement.

Treat that extension as optional until its exact version is pinned and verified against the classroom server.

### 13.4 Reference-hardware expectations

The project’s reference RX 580 machine is near the practical floor for wireless PC VR.

Begin with conservative defaults:

- H.264 for ALVR on Polaris;
- 72 Hz;
- reduced render resolution;
- modest bitrate;
- no shaders;
- performance mods enabled;
- short render distance;
- seated mode for the first test;
- a simple world, not a giant modpack.

The product should say “best effort” rather than promising a buttery dragon ride from 2017 silicon.

### 13.5 VR safety and comfort

The parent guide should include:

- guardian/boundary setup;
- clear floor space;
- controller straps;
- seated mode first;
- snap turning;
- short first sessions;
- stop immediately for nausea, headache, eye strain, or disorientation;
- no room-scale jumping near furniture;
- adult-owned headset account and developer-mode decisions.

No automated agent should enable headset developer mode, sideload an APK, or enter an account credential.

---

## 14. Nugget as a programming coach

### 14.1 Keep the current safety skill

The current `modding` skill is strong for:

- choosing a loader;
- using Prism;
- safe mod downloads;
- MCreator guidance;
- avoiding piracy and credential handling.

Keep it focused on player-facing mod management.

### 14.2 Add a separate `minecraft-dev` skill

This skill should have narrowly scoped capabilities.

Suggested boundaries:

```yaml
fs_read:
  only:
    - "~/MinecraftLab/projects"
    - "~/MinecraftLab/lessons"
    - "/usr/share/lava-chicken/minecraft/templates"

fs_write:
  only:
    - "~/MinecraftLab/projects"

exec:
  only:
    - "git"
    - "java"
    - "./gradlew"
    - "lacos minecraft"

net:
  only: []
```

Do not give it general `curl`, shell, package-manager, credential, or server-administration access.

### 14.3 Coaching protocol

Nugget should follow a “predict, patch, prove, explain” cycle:

1. Ask the child what they expect the code to do.
2. Identify the smallest relevant file.
3. Explain the proposed change in one or two sentences.
4. Make or present a small diff.
5. Run the relevant test/build.
6. Show the result.
7. Ask the child to describe what changed.
8. Commit only after the child sees it work.

For a first lesson, the agent should not generate an entire feature forest. One understandable method beats a thousand-token fog bank.

### 14.4 AI honesty

Nugget must distinguish:

- “I know this from the checked-in project”
- “I inferred this from the error”
- “This API may have changed”
- “The build proved this”
- “A human must test this in VR”

The local model should not invent API names and then congratulate itself.

---

## 15. Curriculum

Each lesson should end with a playable artifact and a Git commit.

### Lesson 0: Change one thing

**Goal:** Build confidence in the loop.

- open a starter project;
- change a message;
- build;
- run;
- see the change;
- commit.

Concepts: source file, build, run, version control.

### Lesson 1: A command

**Paper project:** `/lava-chicken`

- parse a command;
- send a message;
- spawn a chicken;
- add a permission.

Concepts: functions, parameters, conditionals, APIs.

### Lesson 2: An event

- listen for a player stepping on magma;
- apply a temporary effect;
- log who triggered it;
- add configuration.

Concepts: events, objects, state, configuration.

### Lesson 3: Collections and a minigame

- maintain a set of tagged players;
- implement freeze tag or a treasure hunt;
- display a scoreboard.

Concepts: sets, maps, loops, game state.

### Lesson 4: A Fabric item

- register an item;
- add a texture;
- add localization;
- give it a simple use behavior.

Concepts: registries, resources, client/server boundaries.

### Lesson 5: A Fabric block

- register a block;
- add a recipe;
- react to interaction;
- write a GameTest.

Concepts: data, assets, tests.

### Lesson 6: Release to friends

- bump version;
- build;
- hash artifact;
- deploy to server or export Prism profile;
- write release notes;
- ask friends for one bug report and one idea.

Concepts: compatibility, packaging, feedback, release discipline.

### Lesson 7: VR playtest

- launch the same project in the VR instance;
- observe scale and interaction;
- identify one behavior that feels different in VR;
- record a short design note.

Concepts: human-computer interaction, embodied input, performance constraints.

### Lesson 8: Debugging day

Intentionally break:

- a Java type;
- a resource path;
- a version;
- a missing dependency.

Practice reading the first useful error instead of the last alarming paragraph.

---

## 16. Testing and CI

### 16.1 Version-manifest tests

Validate that:

- every field exists;
- versions are exact;
- hashes are present where required;
- Java versions are supported;
- classroom and experimental tracks are distinct;
- no dependency is labeled `latest`;
- URLs use approved domains.

### 16.2 Generator tests

For each starter:

1. generate into a temporary directory;
2. validate names and package structure;
3. run the wrapper;
4. run tests;
5. build;
6. inspect the produced JAR;
7. confirm metadata contains the generated ID and version.

### 16.3 Fabric tests

Use:

- ordinary unit tests for isolated logic;
- Fabric Loader JUnit for loader-aware logic;
- Minecraft GameTest for game behavior;
- a `runClient` smoke path where CI infrastructure permits.

### 16.4 Paper tests

Use:

- JUnit for isolated logic;
- API-level tests for command and event handlers;
- a boot smoke test against the pinned Paper server;
- a deployment test that verifies the plugin loads without errors.

### 16.5 Server tests

CI should verify:

- server configuration parses;
- whitelist is enabled;
- online mode is enabled;
- RCON is not externally exposed;
- the container/service runs unprivileged;
- only the expected port is published;
- a backup can be created and restored;
- a generated plugin loads;
- server stops cleanly.

### 16.6 Prism-profile tests

Validate:

- instance metadata;
- Java selection;
- exact Minecraft and loader versions;
- required mods;
- hashes;
- memory limits;
- separation between Lab and VR;
- no embedded account token or user data.

### 16.7 VR tests

Most VR behavior cannot be honestly proven in headless CI.

Automate:

- configuration validation;
- dependency presence;
- launch command generation;
- firewall checks;
- codec recommendation;
- instance composition.

Manual release test:

- headset connects;
- SteamVR/OpenXR path starts;
- Vivecraft reaches the main menu;
- a local world loads;
- classroom server join works;
- motion/controller input works;
- non-VR instance still works afterward.

Record manual results by OS version, GPU, headset, transport, and Minecraft track.

### 16.8 Cross-repository Gitea contract tests

The public LaCOS test suite should verify:

- the blank-home starter initializes with no remote, identity, topology, or
  secret;
- a clean-room render succeeds without maintainer or GitHub access;
- all external artifacts are pinned and checksummed;
- rendered public fixtures contain no real household literal, unexpected
  Secret, credential/token/key in allowlisted chart-generated
  configuration/init Secrets, public hostname, NodePort, public LoadBalancer,
  privileged pod, host mount, runner, or Actions unit;
- household-mode checks permit schema-defined non-secret site values only at
  exact, chart-versioned key paths and never upload rendered output or evidence;
- local Git initialization and commits require no network;
- an unset site endpoint produces an actionable, non-fatal status;
- a configured endpoint must use the approved private-site scheme and CA;
- a remote outside the configured private Gitea is never added automatically;
- failed clone/push/pull operations do not damage local history;
- human and JSON doctor output redact credentials and home topology;
- no generated project contains a GitHub mirror or embedded token.

The versioned acceptance script run inside each household should verify:

- registration and anonymous project access are disabled;
- all allowed repository-creation paths default to private;
- Minecraft repositories have no push mirror;
- ingress and Git/SSH are allowed only from approved private sources;
- public DNS, IPv4/IPv6 reachability, router forwarding, UPnP, and tunnels do
  not expose the service;
- a child cannot create an organization, make a repository public, add a mirror
  or webhook, enable Actions, or administer the organization;
- kid projects cannot schedule work on a privileged shared runner;
- backup and restore recover repositories plus database metadata.

The public release gates only the generic starter and acceptance-script
behavior; it does not depend on a maintainer’s private suite. Each household
keeps live evidence private. If it reports compatibility publicly, it reports
only policy version and pass/fail—never addresses, topology, accounts, or logs.

---

## 17. Security, privacy, and legal boundaries

### 17.1 Accounts

- Each player uses a legitimate Minecraft Java Edition entitlement.
- A parent handles Microsoft sign-in.
- Nugget never types, reads, stores, or transmits a password.
- Do not support cracked launchers or offline-account workarounds for multiplayer.
- Steam and Meta account actions remain human-owned.

### 17.2 Mods and plugins

- Prefer source-available projects.
- Record source, version, license, and hash.
- Use trusted integrated catalogs.
- Keep third-party experiments out of the golden profile.
- Never run an `.exe` presented as a Minecraft mod.
- Treat arbitrary JARs as executable code, because they are.

### 17.3 Server

- No public exposure by default.
- No UPnP.
- No broad firewall ranges.
- No externally reachable RCON.
- Keep online authentication enabled.
- Whitelist every participant.
- Back up before deploy.
- Give children limited operational controls, not host administration.

### 17.4 Source hosting

- Public LaCOS may ship only the account-neutral starter, generic templates,
  and policy tests; every rendered Gitea deployment and home-network value
  lives only in that household’s private `my_home`.
- Minecraft project repositories are private and require sign-in.
- Do not mirror child projects to GitHub.
- Do not store Gitea passwords, private keys, administrator tokens, or recovery
  codes in either repository, OS images, generated projects, or Nugget context.
- Give each child a separate identity and least-privilege project access.
- Keep Gitea Actions off for kid repositories until an isolated runner and
  explicit parent approval exist.
- Verify non-reachability from outside the approved private network during every
  infrastructure release.

### 17.5 Distribution

Minecraft’s usage rules permit distributing original mods, but not redistributing a modded copy of the game.

Lava Chicken OS should distribute:

- project source;
- original mod/plugin JARs;
- manifests;
- hashes;
- configuration;
- scripts that acquire legal dependencies.

It should not distribute:

- Minecraft client binaries;
- Minecraft server binaries as repository artifacts;
- Microsoft account tokens;
- copyrighted Mojang art;
- a preassembled modded game directory containing substantial game content.

Preserve the repository’s existing original-assets policy.

---

## 18. Documentation experience

### 18.1 Child-facing guide

`docs/MINECRAFT-LAB.md` should start with three buttons or equivalent choices:

```text
I want to:
[ Make a server power ]  [ Make a real mod ]  [ Play my mod in VR ]
```

Each path should present no more than the next three actions.

### 18.2 Parent guide

Cover:

- account ownership;
- server whitelist;
- LAN-only scope and the fact that remote play is deferred;
- backups;
- third-party mod safety;
- VR account/developer-mode decisions;
- how to stop all services;
- how to restore the classroom profile;
- how to inspect what Nugget changed.

### 18.3 Troubleshooting

Organize by observed symptom:

- Minecraft will not start
- the project will not build
- the mod does not appear
- friends cannot join
- server starts but plugin does not load
- VR headset cannot find PC
- VR is black
- frame rate is uncomfortable
- a community mod broke the instance
- the child deleted or changed something important

Lead with diagnosis commands:

```bash
lacos minecraft doctor
lacos minecraft server status
lacos minecraft server logs
lacos minecraft vr doctor
```

---

## 19. Implementation phases

### Phase 0: Architecture and security gate

- record the two-repository ownership contract;
- define the LAN-only threat model and negative exposure tests;
- choose the parent/child identity and repository-permission model;
- select one exact classroom version matrix;
- keep remote Gitea access and private-project Actions out of the first release;
- define the versioned, non-secret site-configuration contract between
  `my_home` and LaCOS.

**Exit criterion:** the architecture review can answer who owns every component,
where every secret lives, how external reachability is disproved, and how a
child keeps working during a Gitea outage.

### Phase 1A: Publish the blank-home starter

Implementation in this phase belongs in public `lava-chicken-os`.

- add the account-neutral `templates/my_home/` starter;
- package it in the OS and releases;
- add `docs/CREATE-MY-HOME-GITEA.md`;
- pin and checksum the official Gitea Helm chart and application/database
  images;
- add preflight, render/policy, private-exposure, backup, restore-drill,
  upgrade, and teardown-check helpers;
- define the versioned non-secret LaCOS enrollment contract;
- run clean-room CI with an empty home and no maintainer or GitHub access;
- scan generated files for maintainer literals, remotes, topology, kubeconfigs,
  and secret material.

**Exit criterion:** a new household can create an independent local `my_home`
and render the expected private deployment using only packaged or public
artifacts, without an account or private repository owned by the maintainer.

### Phase 1B: Deploy or adopt household Gitea

Rendered configuration and live implementation belong in each household’s
private `my_home`.

- deploy the pinned starter to the household’s existing k3s or adopt a
  compatible private Gitea;
- force private repositories and authenticated viewing;
- disable open registration, mirrors, and Actions for Minecraft projects;
- create the parent-owned organization and least-privilege child roles;
- enforce private DNS, TLS/CA, ingress, SSH, firewall, router, IPv4, and IPv6
  policy;
- back up and restore repository data plus database metadata;
- run allowed-client, anonymous-client, cross-user, and external-network
  acceptance tests.

**Exit criterion:** an authenticated child on the home LAN can clone and push,
while anonymous and external clients cannot discover or reach the service; a
restore drill on isolated infrastructure recovers a private test repository and
its metadata.

### Phase 2: Local-first Paper and Git vertical slice

Implementation in this phase belongs in public `lava-chicken-os`.

- reconcile the multi-user app and JDK model;
- remove ambient Gradle and moving template clones;
- add the exact version manifest;
- implement `lacos minecraft status` and `doctor --json`;
- create the tiny pinned Paper generator and tests;
- initialize a local Git repository and first commit;
- add site-configured Gitea status/connect/push/clone flows;
- prove local edit/build/test/play works offline.

**Exit criterion:** a child changes one Paper command, builds it, commits it,
pushes it to a private in-home repository, and can reproduce the build from a
clean clone without giving LaCOS or Nugget an administrator credential.

### Phase 3: Social Paper server

- managed unprivileged Paper server;
- online authentication and whitelist;
- parent-owned access controls;
- pre-deploy backup and restore;
- safe deploy-and-restart flow;
- LAN-only game firewall;
- logs and failure translation.

**Exit criterion:** a child deploys a committed command and demonstrates it to
a whitelisted friend on the home LAN; neither Gitea nor the game server is
publicly reachable.

### Phase 4: Fabric and reproducible Prism Lab

- pinned Fabric starter and tests;
- Vanilla and Lab Prism manifests;
- hash-verified profile composition;
- desktop build/deploy/play path;
- profile reset/recreate and export/import;
- source/profile separation.

**Exit criterion:** a fresh Fabric project builds and runs in the Lab profile,
and deleting and recreating that profile neither changes nor deletes source.

### Phase 5: Vivecraft VR

- isolated VR Prism profile on the classroom Fabric baseline;
- `lacos minecraft vr doctor`;
- WiVRn and ALVR composition paths;
- conservative reference-hardware defaults;
- optional compatible server extension;
- manual VR release checklist.

**Exit criterion:** the same committed Fabric project runs in desktop and VR
profiles without cross-contamination, and the non-VR path still passes after
the VR test.

### Phase 6: Nugget coaching and curriculum

- separate `minecraft-dev` skill;
- project-scoped writes and restricted commands;
- predict/patch/prove/explain protocol;
- lesson state and Git checkpoints;
- parent-visible diffs;
- Paper, Fabric, release, recovery, and VR lessons.

**Exit criterion:** Nugget helps complete and commit a lesson without account
access, arbitrary downloads, broad shell access, server administration, or
unexplained bulk generation.

### Phase 7: CI and release discipline

- public CI for version policy, generators, server config, and Prism manifests;
- public CI for the generic blank-home Helm render, schema, policy, secret scan,
  and maintainer-literal scan;
- a versioned acceptance script that each household runs against its own private
  deployment without uploading topology or evidence;
- no private-project runner until its isolation gate is satisfied;
- versioned classroom track and upgrade ceremony;
- artifact hashes and generated release notes;
- hardware test matrix and manual VR record;
- rollback and cross-repository compatibility proof.

**Exit criterion:** an OS or home-infrastructure update cannot silently expose,
lose, or break the family’s known-good Minecraft Lab.

---

## 20. Suggested GitHub issue breakdown

### Epic: Minecraft Lab

**Goal:** Turn Lava Chicken OS’s existing Minecraft and VR tooling into a reproducible, multiplayer-first programming environment for kids.

#### Issue 1: Publish clean-room `my_home` starter and k3s Gitea guide

- packaged, account-neutral starter with no `.git` or remote
- pinned official Helm chart and images
- kube-context/storage/network/TLS/backup preflight
- secret-free values and private ingress/NetworkPolicy templates
- parent/child identity bootstrap
- LaCOS enrollment contract
- backup, restore, upgrade, and safe teardown runbooks
- clean-room CI and private-exposure acceptance script

#### Household-owned downstream task: Deploy or adopt the in-home Gitea

Track rendered values and live implementation only in that household’s private
home repository:

- authenticated/private defaults;
- parent/child roles and repository bootstrap;
- LAN-only DNS, TLS, ingress, SSH, firewall, and negative IPv4/IPv6 WAN test;
- no Minecraft-project mirrors;
- Actions disabled for kid repositories;
- consistent backup and tested restore.

The public Epic records only starter/policy version compatibility, not a
household’s private issue URL, topology, account names, or diagnostic evidence.

#### Issue 2: Record architecture, threat model, and version contract

- public LaCOS/private `my_home` ownership
- local-first/offline behavior
- identity and credential boundaries
- LAN-only acceptance tests
- `classroom` and `experimental` tracks
- exact versions
- schema validation
- site-contract versioning

#### Issue 3: Make Java toolchains multi-user and deterministic

- JDK 21
- JDK 25
- project toolchain selection
- remove ambient Gradle dependency

#### Issue 4: Converge Minecraft desktop apps

- system Prism
- system IntelliJ
- per-user MCreator
- Flatpak access to `~/MinecraftLab`
- doctor checks

#### Issue 5: Implement `lacos minecraft` and JSON doctor

- status
- toolchain diagnostics
- project discovery
- offline-safe Git diagnostics
- human and JSON output

#### Issue 6: Add private Gitea client integration

- non-secret site settings
- home-CA and SSH host verification
- per-user public-key enrollment workflow
- connect/push/pull/clone
- no admin token
- no public mirror

#### Issue 7: Create pinned Paper plugin starter

- generator
- sample command
- local Git initialization and first commit
- tests
- build CI

#### Issue 8: Add managed Paper test server

- isolated service
- online mode
- whitelist
- LAN-only firewall
- lifecycle commands

#### Issue 9: Add server backup and restore

- pre-deploy snapshots
- metadata
- retention
- parent pinning

#### Issue 10: Create pinned Fabric mod starter

- generator
- sample item/block
- tests/GameTest
- build CI

#### Issue 11: Generate Prism Vanilla and Lab instances

- exact versions
- manifest
- reset/recreate
- project deployment

#### Issue 12: Generate Vivecraft VR instance

- Fabric API
- Vivecraft
- performance mods
- transport checks
- reference GPU defaults

#### Issue 13: Add `minecraft-dev` Nugget skill

- scoped filesystem
- restricted commands
- no network
- coaching protocol
- diff review

#### Issue 14: Add curriculum

- lessons
- progress state
- playable outcomes
- Git checkpoints

#### Issue 15: Add full CI/release gate

- generated projects build
- public/private policy suites pass
- server boots
- Prism profiles validate
- manual VR result recorded
- rollback verified

Parent-controlled remote access is deliberately outside this Epic. Propose it
later only as a separate threat-model change; never implement public exposure.

---

## 21. Definition of done

Lava Chicken OS may claim “Minecraft Modding Lab” when all of the following are true:

### Installation

- A fresh supported install provisions all required applications for every intended user.
- JDK 21 and JDK 25 are available and correctly selected by track.
- No global Gradle version is required.
- `lacos minecraft doctor` is green.

### First project

- A child can generate a Paper plugin.
- The generated project builds and tests.
- One command deploys it to the test server.
- The child can observe the behavior in game.
- The project is a Git repository with an initial commit.

### Independent home bootstrap

- Starting with an empty home and no maintainer/GitHub access, a parent can
  initialize a local private `my_home` with no remote.
- Only public or installed LaCOS artifacts are needed to render and deploy the
  pinned Gitea stack to the parent’s existing k3s.
- No generated file contains a maintainer identity, hostname, address, key,
  remote, repository name, or private infrastructure detail.
- The new `my_home` is pushed only to a private repository on the household’s
  own Gitea after privacy tests pass.
- Protected off-cluster bootstrap material can rebuild Gitea without first
  accessing the failed Gitea.

### Private source control

- The child can push and clone through an individual, non-admin identity.
- Every Minecraft project repository is private and requires authentication.
- Anonymous and external clients cannot enumerate or reach the service.
- No Minecraft project has an automatic public mirror.
- Local commit, build, test, and play continue when Gitea is unavailable.
- LaCOS and Nugget have no Gitea administrator credential.
- Gitea source and metadata pass a private backup-and-restore drill.

### Mod project

- A child can generate a Fabric mod.
- The generated project launches in a development client.
- The built JAR deploys to the Lab Prism instance.
- Resetting the instance does not delete source code.

### Friends

- A parent can whitelist a friend.
- The friend can join over the home LAN.
- The server is not publicly exposed.
- Online authentication remains enabled.
- The child’s plugin behavior is visible to the friend.

### Recovery

- The server backs up before deployment.
- A parent can restore a world.
- A broken Prism instance can be recreated.
- A private project can be recovered from Gitea and its tested backup.
- An OS upgrade can be rolled back.
- Classroom and experimental tracks cannot overwrite one another.

### VR

- The VR doctor reports the transport, runtime, instance, Java, Vivecraft, and GPU status.
- The VR instance launches independently of the normal Lab instance.
- The same local mod can be tested in desktop and VR.
- The reference-hardware limitations are documented honestly.

### Agent safety

- Nugget cannot read credentials.
- Nugget cannot download arbitrary binaries.
- Nugget writes only inside Minecraft project directories.
- Nugget shows diffs.
- Nugget runs tests and reports evidence.
- Parent-only server/network operations remain parent-owned.

---

## 22. Recommended first milestone

Do not begin with VR.

The highest-value first milestone is:

> A child creates a Paper project, changes one command, commits and pushes it
> to a private LAN-only Gitea repository, deploys it to a parent-controlled
> local Paper server, and a whitelisted friend sees the result.

That milestone proves the motivational core:

- programming;
- build;
- private version control and recovery;
- deployment;
- multiplayer;
- social feedback;
- safe operations.

Then add Fabric. Then compose Fabric with Vivecraft.

VR is the fireworks. The server-side coding loop is the stove.

---

## 23. Immediate work items

1. Add this document and its public tracking Epic to `lava-chicken-os`.
2. Add `docs/CREATE-MY-HOME-GITEA.md` and the account-neutral
   `templates/my_home/` starter; package the starter for installed and release
   use.
3. Add clean-room render/policy tests that require no maintainer account,
   private repository, home topology, or GitHub login.
4. Record the cross-repository ownership, site-contract version, LAN-only
   threat model, identity model, and runner exclusion in an ADR.
5. Exercise both starter paths: a blank-directory deployment on disposable k3s
   and adoption of an existing private Gitea. Neither private deployment is a
   public-release dependency.
6. Add IntelliJ IDEA Community to `common/bin/lacos-install-apps`.
7. Split `scripts/60-modding-tools.sh` into:
   - legacy bootstrap compatibility;
   - shared JDK provisioning;
   - project/profile creation through `lacos minecraft`.
8. Remove `sdk install gradle`.
9. Install and manage JDK 21 and 25.
10. Add `common/minecraft/versions.toml`.
11. Replace branch clones with pinned starter kits.
12. Add `common/bin/lacos-minecraft` and route it through `common/bin/lacos`.
13. Implement `lacos minecraft doctor --json`, including offline-safe private
    Git status with redacted output.
14. Add the Paper starter, local Git initialization, and private Gitea
    connect/push/clone flow before expanding NeoForge support.
15. Add a managed LAN-only Paper server.
16. Generate reproducible Prism Lab and Vivecraft profiles from one version set.
17. Split coaching from code-writing into separate Nugget skills.
18. Gate classroom track updates on the public scaffold tests plus the
    household-run private acceptance script, generated builds, server/profile
    validation, manual hardware tests, and rollback.

---

## References

### Lava Chicken OS

- [Repository overview](../README.md)
- [Current modding tool script](../scripts/60-modding-tools.sh)
- [Current modding notes](../templates/MODDING.md)
- [Current app convergence](../common/bin/lacos-install-apps)
- [Current `lacos` command](../common/bin/lacos)
- [Current modding skill](../common/newt-skills/modding/SKILL.md)
- [Current VR command](../common/bin/lacos-vr)
- [Current VR coaching skill](../common/newt-skills/vr-setup/SKILL.md)

### Private source hosting

- [Gitea installation on Kubernetes](https://docs.gitea.com/installation/install-on-kubernetes)
- [Gitea configuration cheat sheet](https://docs.gitea.com/administration/config-cheat-sheet)
- [Gitea repository and organization permissions](https://docs.gitea.com/usage/access-control/permissions)
- [Gitea Actions security model](https://docs.gitea.com/usage/actions/overview)
- [Gitea backup and restore](https://docs.gitea.com/usage/backup-and-restore)
- [k3s networking services and ServiceLB](https://docs.k3s.io/networking/networking-services)
- [k3s secrets encryption](https://docs.k3s.io/security/secrets-encryption)
- [k3s backup and restore](https://docs.k3s.io/datastore/backup-restore)

### Minecraft mod and plugin development

- [Fabric documentation](https://docs.fabricmc.net/)
- [Fabric developer guides](https://docs.fabricmc.net/develop/)
- [Fabric automated testing](https://docs.fabricmc.net/develop/automatic-testing)
- [NeoForge documentation](https://docs.neoforged.net/)
- [PaperMC project setup](https://docs.papermc.io/paper/dev/project-setup/)
- [PaperMC plugin metadata](https://docs.papermc.io/paper/dev/plugin-yml/)

### Launcher and VR

- [Prism Launcher documentation](https://prismlauncher.org/wiki/)
- [Vivecraft](https://www.vivecraft.org/)
- [Vivecraft downloads and requirements](https://www.vivecraft.org/downloads/)
- [Vivecraft mod project](https://github.com/Vivecraft/VivecraftMod)
- [WiVRn](https://github.com/WiVRn/WiVRn)

### Minecraft policy

- [Minecraft Usage Guidelines](https://www.minecraft.net/en-us/usage-guidelines)
- [Minecraft EULA](https://www.minecraft.net/en-us/eula)
- [Minecraft parental controls](https://www.minecraft.net/en-us/article/parental-controls)
