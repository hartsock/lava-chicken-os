#!/usr/bin/env python3
"""Generate ORIGINAL blocky/voxel-style art (wallpaper or boot still).

Deliberately not a copy of any Mojang asset: procedural "lava field with a
blocky chicken" built from plain colored squares. Stdlib-only fallback writes
a PPM->PNG via Pillow if available, else raw PPM.

Usage:
  make_wallpaper.py OUT.png            # 3840x2160 wallpaper
  make_wallpaper.py --boot OUT.png     # 1920x1080 boot still
"""
import random
import sys

BLOCK = 40


def palette_row(y, h):
    """Sky -> stone -> lava gradient bands, minecrafty but original."""
    frac = y / h
    if frac < 0.45:
        return [(20, 24, 46), (28, 32, 60), (16, 18, 38)]          # night sky
    if frac < 0.65:
        return [(66, 66, 66), (84, 84, 84), (52, 52, 52)]          # stone
    return [(207, 87, 0), (252, 145, 20), (255, 200, 40), (120, 40, 8)]  # lava


CHICKEN = [  # 8x8 pixel chicken, original design
    "..ww....",
    ".wwww.o.",
    ".wwwwwo.",
    "wwwwwww.",
    "wwwwww..",
    ".wwww...",
    "..y.y...",
    "..y.y...",
]
CHICKEN_COLORS = {"w": (240, 240, 235), "o": (250, 160, 30), "y": (230, 190, 40)}


def render(w, h, seed=414):
    rng = random.Random(seed)
    px = [[None] * w for _ in range(h)]
    for by in range(0, h, BLOCK):
        row = palette_row(by, h)
        for bx in range(0, w, BLOCK):
            c = rng.choice(row)
            for y in range(by, min(by + BLOCK, h)):
                for x in range(bx, min(bx + BLOCK, w)):
                    px[y][x] = c
    # sprinkle stars in the sky
    for _ in range(w // 30):
        x, y = rng.randrange(w), rng.randrange(int(h * 0.4))
        px[y][x] = (255, 255, 255)
    # chicken standing on the stone band, big pixels
    scale = BLOCK
    cx, cy = w // 2 - 4 * scale, int(h * 0.65) - 8 * scale
    for r, line in enumerate(CHICKEN):
        for c, ch in enumerate(line):
            if ch in CHICKEN_COLORS:
                for y in range(cy + r * scale, cy + (r + 1) * scale):
                    for x in range(cx + c * scale, cx + (c + 1) * scale):
                        if 0 <= y < h and 0 <= x < w:
                            px[y][x] = CHICKEN_COLORS[ch]
    return px


def save(px, path):
    h, w = len(px), len(px[0])
    try:
        from PIL import Image
        img = Image.new("RGB", (w, h))
        img.putdata([tuple(p) for row in px for p in row])
        img.save(path)
    except ImportError:
        ppm = path.rsplit(".", 1)[0] + ".ppm"
        with open(ppm, "wb") as f:
            f.write(f"P6 {w} {h} 255\n".encode())
            f.write(bytes(v for row in px for p in row for v in p))
        print(f"Pillow not installed; wrote {ppm} instead (convert with ffmpeg).")
        return ppm
    return path


if __name__ == "__main__":
    args = sys.argv[1:]
    boot = "--boot" in args
    args = [a for a in args if a != "--boot"]
    out = args[0] if args else "lava-chicken-wall.png"
    w, h = (1920, 1080) if boot else (3840, 2160)
    print(f"Rendering {w}x{h} -> {out}")
    print("Saved:", save(render(w, h), out))
