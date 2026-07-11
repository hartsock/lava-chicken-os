# Drop your local media here (gitignored)

| File you provide | Used by | Notes |
|---|---|---|
| `lava-chicken.(mp3\|m4a\|ogg\|opus\|wav\|flac)` | boot video + login sound | Your own copy of *Steve's Lava Chicken*. First ~15s are used for the startup movie. |
| `boot-image.(png\|jpg)` | boot video | Optional still frame behind the audio. Omit it and the generator makes original lava/chicken pixel art. |
| `wallpaper*.(png\|jpg)` | desktop wallpaper | Optional. Omit and `make_wallpaper.py` generates original blocky art. |

Nothing in this directory is ever committed (see `.gitignore` and
`docs/LEGAL-ASSETS.md`).
