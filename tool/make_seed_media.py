"""Generate the demo media assets referenced by 006_seed_data.sql.

Pure placeholder artwork (gradients + geometry) — no third-party hotlinks — so
every URL the seeded rows advertise resolves to a byte-exact object in the
project's own `media` Storage bucket. Run this, upload the output tree to
Storage under the same relative paths, then paste the printed JSON into the
media block of 006 (and the matching live UPDATE) so file_size/width/height
describe the bytes that really exist.

Output: <repo>/.seed_media/<path>  (flat, path separators doubled — that is the
form the Supabase dashboard uploader expects; mirrors 006's storage_path).
"""
import json
import os
import random
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))), ".seed_media")

SITE = "india_tech"

CATEGORY_SLUGS = [
    ("ai", ((76, 60, 168), (34, 190, 194))),
    ("smartphones", ((18, 26, 58), (168, 222, 66))),
    ("apps", ((24, 58, 138), (247, 147, 30))),
    ("how-to", ((16, 88, 96), (240, 178, 78))),
    ("tech-news", ((44, 32, 96), (236, 72, 116))),
    ("comparisons", ((12, 74, 66), (126, 200, 138))),
    ("cyber-safety", ((28, 28, 46), (56, 189, 248))),
    ("buying-guides", ((96, 52, 24), (250, 204, 21))),
]

AUTHOR_SLUGS = [
    ("aravind-sharma", ((62, 72, 120), (198, 166, 120))),
    ("priya-nambiar", ((88, 40, 96), (222, 148, 170))),
    ("rohit-deshmukh", ((20, 62, 96), (120, 190, 220))),
    ("sneha-kulkarni", ((96, 40, 40), (246, 190, 130))),
]

BRAND = [("bharat-tech-pulse-og-default", (1200, 630),
          ((30, 42, 96), (233, 108, 46)))]

# Heroes already uploaded one-per-article before the artwork moved to a
# per-category scheme. Still real objects in the bucket, still registered in
# public.media — kept so the library has no rows pointing at missing bytes.
LEGACY_ARTICLE_HEROES = [
    "2026-10-ai-tool-framework-hero",
    "2026-09-dpi-explained-hero",
    "2026-10-spec-sheet-decoded-hero",
    "2026-09-family-cyber-safety-hero",
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


def plan():
    items = []
    for i, (slug, cols) in enumerate(CATEGORY_SLUGS):
        items.append((f"{SITE}/articles/category/{slug}-hero.jpg",
                      (1600, 900), cols, 2000 + i))
    for i, (slug, cols) in enumerate(AUTHOR_SLUGS):
        items.append((f"{SITE}/authors/{slug}-avatar.jpg", (300, 300), cols, 3000 + i))
    for i, (name, size, cols) in enumerate(BRAND):
        items.append((f"{SITE}/brand/{name}.jpg", size, cols, 4000 + i))
    for i, name in enumerate(LEGACY_ARTICLE_HEROES):
        items.append((f"{SITE}/articles/{name}.jpg", (1600, 900),
                      CATEGORY_SLUGS[i][1], 5000 + i))
    return items


def main():
    os.makedirs(OUT, exist_ok=True)
    report = {}
    for rel, size, cols, seed in plan():
        img = decorate(gradient(size, *cols), seed=seed)
        path = os.path.join(OUT, rel.replace("/", "__"))
        os.makedirs(os.path.dirname(path), exist_ok=True)
        img.save(path, "JPEG", quality=88, optimize=True)
        report[rel] = {"bytes": os.path.getsize(path),
                       "width": img.size[0], "height": img.size[1]}
    print(json.dumps(report, indent=1))


if __name__ == "__main__":
    main()
