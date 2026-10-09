"""Generate the six demo media assets referenced by 006_seed_data.sql.

Pure placeholder artwork (gradients + geometry), sized to match the seeded
metadata so the media table describes bytes that actually exist.
"""
import json
import os
import random
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))), ".seed_media")

ASSETS = [
    ("india_tech/articles/2026-10-ai-tool-framework-hero.jpg", (1600, 900),
     ((76, 60, 168), (34, 190, 194))),
    ("india_tech/articles/2026-09-dpi-explained-hero.jpg", (1600, 900),
     ((24, 58, 138), (247, 147, 30))),
    ("india_tech/articles/2026-10-spec-sheet-decoded-hero.jpg", (1600, 900),
     ((18, 26, 58), (168, 222, 66))),
    ("india_tech/articles/2026-09-family-cyber-safety-hero.jpg", (1600, 900),
     ((16, 88, 96), (240, 178, 78))),
    ("india_tech/authors/aravind-sharma-avatar.jpg", (300, 300),
     ((62, 72, 120), (198, 166, 120))),
    ("india_tech/brand/bharat-tech-pulse-og-default.jpg", (1200, 630),
     ((30, 42, 96), (233, 108, 46))),
]


def gradient(size, c1, c2):
    w, h = size
    base = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(h - 1, 1)
        base.putpixel((0, y), tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3)))
    return base.resize((w, h))


def decorate(img, seed):
    d = ImageDraw.Draw(img, "RGBA")
    rnd = random.Random(seed)
    w, h = img.size
    for i in range(26):
        x = rnd.randint(-w // 6, w)
        y = rnd.randint(-h // 6, h)
        r = rnd.randint(h // 24, h // 3)
        tone = rnd.choice([(255, 255, 255, 22), (0, 0, 0, 20), (255, 214, 120, 18)])
        if rnd.random() < 0.5:
            d.ellipse([x, y, x + r * 2, y + r * 2], fill=tone)
        else:
            d.rounded_rectangle([x, y, x + r * 2, y + r], radius=r // 6, fill=tone)
    band = h // 9
    d.rectangle([0, h - band, w, h], fill=(12, 16, 34, 120))
    for k in range(4):
        d.rounded_rectangle(
            [w // 12 + k * (w // 5), h - band // 2 - 8,
             w // 12 + k * (w // 5) + w // 8, h - band // 2 + 8],
            radius=8, fill=(255, 255, 255, 46))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    report = {}
    for i, (rel, size, cols) in enumerate(ASSETS):
        img = decorate(gradient(size, *cols), seed=1000 + i)
        path = os.path.join(OUT, rel.replace("/", "__"))
        img.save(path, "JPEG", quality=88, optimize=True)
        report[rel] = {"bytes": os.path.getsize(path),
                       "width": img.size[0], "height": img.size[1]}
    print(json.dumps(report, indent=1))


if __name__ == "__main__":
    main()
