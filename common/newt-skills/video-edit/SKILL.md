---
name: video-edit
description: Coach a video edit on this box — Kdenlive (default) or Shotcut, from OBS recording to YouTube-ready render. Project setup, trim/titles/music, the export preset that works, and the Resolve codec trap. Ends at a rendered file; NEVER uploads or touches any account.
when_to_use: The user wants to edit a recording — cut/trim clips, add titles or music, combine takes, "make a YouTube video from my recording" — or asks which editor to use, or why DaVinci Resolve won't import their file.
version: 1.0.0
license: MIT
caveats:
  exec: { only: ["ffprobe", "ls", "du", "mkdir"] }
  fs_read: all
  fs_write: all
  net: { only: [] }
---

# Video editing on this box — coach, don't click

You coach the edit; the human drives the editor (it's a GUI). Launch nothing —
tell them what to click. Rendering ends the job: **no uploading, no accounts,
no browser — ever.** The [[youtube-prep]] skill owns transcodes and the final
upload checklist; hand off to it for codec problems and exports outside the
editor.

## The editors (from docs/APPS.md)

| Editor | Verdict |
|---|---|
| **Kdenlive** | the default — handles H.264/AAC natively, VAAPI export |
| **Shotcut** | simpler fallback, same codec story |
| DaVinci Resolve free | **trap on Linux**: no H.264/H.265, no AAC. Grading only; needs a DNxHR transcode first (youtube-prep §4) |

Both are installed as Flatpaks for every user (menu: Kdenlive / Shotcut).

## Where things live

- OBS recordings: `~/Videos` (OBS default on this box)
- Suggest a project folder per video: `~/Videos/projects/<name>/` — keep the
  `.kdenlive` project file, sources, and renders together.

## Kdenlive: the 6-step kid-proof flow

1. **New project** — match the footage: 1080p, and the *recording's* fps
   (check with `ffprobe` if unsure; mixing 30/60 causes stutter).
2. **Import** — drag files into the Project Bin. If Kdenlive rejects a file,
   don't fight it: ffprobe it, then hand to [[youtube-prep]] §3.
3. **Rough cut** — drag to timeline; `x` razor at the cut points, select the
   scraps, `Del`. Save early (`Ctrl-s`), save often.
4. **Titles** — Project menu → Add Title Clip; place it on the video track
   ABOVE the footage track.
5. **Music bed** — drop the track on an audio lane; drag its volume line down
   (~-18 dB under speech); fade in/out with the corner handles.
6. **Render** — Project → Render → preset **MP4-H264/AAC**, check
   "Parallel processing". Output into the project folder.

## After the render

ffprobe the output and sanity-check: H.264 + AAC, expected duration, size sane
(~1 GB per 10 min of 1080p is normal). Then hand the file to [[youtube-prep]]
§6 for the upload checklist — its no-upload rule is yours too.

## When something's weird

- **Choppy preview** ≠ broken render — lower the preview resolution
  (dropdown under the monitor), or let it render.
- **Audio drift / variable fps** (some phone/OBS captures): transcode to
  constant fps with [[youtube-prep]] §3's VFR variant (`-fps_mode cfr -r <fps>`),
  then edit that file instead.
- **"It needs Premiere/Resolve"**: real Adobe means booting the Windows side
  (that's why this box dual-boots) — say so plainly.
