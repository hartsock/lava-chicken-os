---
name: youtube-prep
description: Get a recording (OBS capture, phone clip) ready for YouTube on this box — verify codecs with ffprobe, transcode to editor-safe or Resolve-safe formats, and export a YouTube-ready H.264/AAC file using AMD VAAPI hardware encode when available. Ends at an upload-ready file plus a checklist; NEVER uploads or touches any account.
when_to_use: The user asks to "get my video ready for YouTube", convert/transcode a recording, fix a clip an editor won't import, check why audio/video is broken, or export/render for upload. Also when Kdenlive/Shotcut/Resolve rejects a source file.
version: 1.0.0
license: MIT
caveats:
  exec: { only: ["ffmpeg", "ffprobe", "ls", "du", "df", "mkdir"] }
  fs_read: all
  fs_write: all
  net: { only: [] }
---

# YouTube prep — verify, transcode, export (never upload)

You prepare video files. You do **not** publish them. The hard boundary:
**no uploading, no browser, no YouTube/Google account actions, no credentials —
ever.** You end every job at "here is your upload-ready file + checklist"; the
human uploads it themselves (browser or OBS). Work only on the invoking user's
own files, inside their home directory.

## 1. Always start with ffprobe

```bash
ffprobe -v error -show_format -show_streams -of default=noprint_wrappers=1 "$IN"
```

Summarize for the user: container, video codec / resolution / fps, audio codec /
sample rate, duration, size. This tells you which path below applies.

## 2. Know this box's codec facts (from docs/APPS.md)

- **Kdenlive / Shotcut** (the default editors here): handle H.264/HEVC + AAC
  natively. Most OBS captures and phone clips import as-is — verify before
  transcoding; **do not transcode what already works.**
- **DaVinci Resolve (free, Linux)**: cannot decode/encode H.264/H.265 and has
  **no AAC at all**. For Resolve, transcode to DNxHR + PCM first (§4).
- **AMD hardware encode** on this box is **VAAPI** (OBS's AMF is Windows-only).
  Prefer `h264_vaapi` when `/dev/dri/renderD128` exists; fall back to `libx264`.

## 3. Editor-safe intermediate (only when an editor rejects the source)

```bash
ffmpeg -i "$IN" -c:v libx264 -crf 18 -preset fast -c:a aac -b:a 192k "$OUT.mp4"
```

**Variable-frame-rate source?** (phone clips, some OBS captures — shows as
non-constant fps in ffprobe; causes audio drift in editors). Add a constant-fps
flag, using the source's nominal fps from ffprobe:

```bash
ffmpeg -i "$IN" -fps_mode cfr -r 30 -c:v libx264 -crf 18 -preset fast \
       -c:a aac -b:a 192k "$OUT.mp4"
```

## 4. Resolve-safe intermediate (DNxHR + PCM)

```bash
ffmpeg -i "$IN" -c:v dnxhd -profile:v dnxhr_hq -pix_fmt yuv422p \
       -c:a pcm_s16le "$OUT.mov"
```
Warn first: DNxHR files are BIG (~10x). Check free space with `du`/`df` sizes.

## 5. YouTube export (the main event)

Hardware path (try first when `/dev/dri/renderD128` exists):

```bash
ffmpeg -init_hw_device vaapi=va:/dev/dri/renderD128 -i "$IN" \
  -vf 'format=nv12,hwupload' -c:v h264_vaapi -qp 23 \
  -c:a aac -b:a 192k -movflags +faststart "$OUT-youtube.mp4"
```

Software fallback (always works, slower):

```bash
ffmpeg -i "$IN" -c:v libx264 -crf 20 -preset medium \
  -c:a aac -b:a 192k -movflags +faststart "$OUT-youtube.mp4"
```

Keep the source resolution/fps unless asked (YouTube handles 1080p/1440p/4K).
`+faststart` matters — YouTube ingests it faster.

## 6. Verify, then hand off

Re-run the §1 ffprobe on the output and show the before/after table. Then end
with the handoff checklist — and stop:

```
READY TO UPLOAD: <path>  (<size>, <duration>, H.264/AAC, faststart)
Your move (I don't upload):
  1. youtube.com -> Create -> Upload, pick the file above
  2. Title / description / visibility (start Unlisted for test uploads)
  3. Kids' channel? Double-check the "made for kids" setting with a parent.
```

If asked to upload anyway: decline once, kindly — "uploading is a human step on
this box, by design" — and point at the checklist.
