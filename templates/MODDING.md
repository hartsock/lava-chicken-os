# Minecraft Java Edition modding on this box

Installed by `scripts/60-modding-tools.sh`:

- **JDK 21 (Temurin)** + **Gradle** via SDKMAN (`sdk current`)
- **IntelliJ IDEA Community** (Flatpak) — install the *Minecraft Development* plugin
- **Prism Launcher** (Flatpak) — test instances with your mod dropped in
- **MCreator** (official build, per-user in `~/Applications/MCreator`) — visual,
  blocks-based mod maker; the no-code on-ramp before the IntelliJ path
- Templates in `~/mods/`: `fabric-example-mod`, `neoforge-mdk`

## Loop

```bash
cd ~/mods/fabric-example-mod
./gradlew build            # jar lands in build/libs/
./gradlew runClient        # launches a dev client with the mod loaded
```

Rename the template dir, edit `gradle.properties` (mod id, group), and go.

## Using newt-agent + ollama for modding

newt runs against local ollama, so mod coding works fully offline:

```bash
cd ~/mods/my-mod
newt "add a lava chicken mob that drops cooked chicken when it walks on magma blocks"
```

Bigger models (`qwen2.5-coder:14b`+) handle Fabric/NeoForge APIs noticeably
better if your VRAM allows.

## Version notes

- MC 1.20.5+ requires Java 21; older targets may need `sdk install java 17-tem`.
- Fabric: https://fabricmc.net/develop/ — NeoForge: https://docs.neoforged.net/
- The NeoForge MDK repo is versioned per MC release; update the clone URL in
  `scripts/60-modding-tools.sh` when you target a new MC version.
