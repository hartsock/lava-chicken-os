# Media assets: what this repo will and won't ship

This repo is public. These stay **out** of git:

- **"Steve's Lava Chicken"** (Jack Black, *A Minecraft Movie*, 2025) — the
  recording and composition are copyrighted. Use your own purchased/ripped
  copy locally. Scripts read it from `assets/user/`, which is gitignored.
- **Official Minecraft artwork, textures, screenshots-of-assets** — Mojang's
  [Usage Guidelines](https://www.minecraft.net/en-us/usage-guidelines) don't
  permit redistributing their assets in a repo like this.
- Movie clips, trailers, fan re-uploads of the song: same deal.

What CAN live in the repo:

- Original "blocky/voxel-style" art we generate ourselves
  (`assets/generated/make_wallpaper.py`) — inspired-by is fine, copies are not.
- **The Nugget mascot + default wallpaper** (`assets/brand/nugget.png`,
  `wallpaper.png` + variants) — original character/scene art supplied by the
  project owner, used for the boot splash, the agent's avatar, and the default
  desktop wallpaper.
- **The boot chime + boot movie** (`assets/brand/boot-sound.wav`,
  `boot-movie.webm`) — the owner's **original** music/video (NOT the copyrighted
  song above), so they ship with the OS and play by default. The `.gitignore`
  blocks `*.wav`/`*.webm` repo-wide and re-includes only these two. It riffs on a Minecraft *aesthetic* (blocky, a Steve-style
  cap) but is an original character, not a Mojang asset. If you fork and are
  wary of the resemblance, swap in your own mascot at the same paths.
- All scripts, docs, and configs (MIT).

The `.gitignore` blocks `assets/user/*` and common media extensions repo-wide
as a second layer of protection. Before pushing:

```bash
git status --ignored
git ls-files | grep -Ei '\.(mp3|m4a|ogg|opus|wav|flac|webm|mp4|png|jpg|jpeg)$' || echo clean
```
