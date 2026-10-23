"""Procedural pixel-art generator for Race to the Moon.

Run from the repo root:  python tools/art/generate_art.py
Writes game sprites to assets/art/ and preview images to docs/art/.
Everything is seeded, so re-running gives identical output: tweak a function and re-run.
Requires Pillow (pip install pillow).
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "assets" / "art"
PREVIEW = ROOT / "docs" / "art"


def hexc(h: str) -> tuple[int, int, int, int]:
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


# Main palette (based on Endesga 32) plus a few extras for rock and moon.
P = {name: hexc(v) for name, v in {
    "outline": "181425", "navy": "262b44",
    "white": "ffffff", "light": "c0cbdc", "grey": "8b9bb4", "dgrey": "5a6988", "ddgrey": "3a4466",
    "pink": "f5a097", "red": "e43b44", "dred": "a22633", "orange": "f77622", "gold": "feae34", "yellow": "fee761",
    "cream": "ead4aa", "tan": "e4a672", "brown": "b86f50", "dbrown": "743f39", "ddbrown": "3f2832",
    "lgreen": "a8e05f", "green": "63c74d", "dgreen": "3e8948", "ddgreen": "265c42",
    "cyan": "2ce8f5", "blue": "0099db", "dblue": "124e89",
    "purple": "68386c", "magenta": "b55088",
    "lrock": "b0a19a", "rock": "8a7a72", "drock": "5e4f50",
    "lmoon": "eceae4", "moon": "c9c6bd", "dmoon": "8e8a85", "ddmoon": "5f5c5a",
}.items()}
CLEAR = (0, 0, 0, 0)
BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


# ---------------------------------------------------------------- helpers

def new(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w, h), CLEAR)


def put(img: Image.Image, x: float, y: float, c) -> None:
    x, y = int(x), int(y)
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c)


def get(img: Image.Image, x: int, y: int):
    if 0 <= x < img.width and 0 <= y < img.height:
        return img.getpixel((x, y))
    return CLEAR


def rect(img, x0, y0, x1, y1, c) -> None:
    for y in range(int(y0), int(y1) + 1):
        for x in range(int(x0), int(x1) + 1):
            put(img, x, y, c)


def ellipse(img, cx, cy, rx, ry, c) -> None:
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                put(img, x, y, c)


def outline(img, c=None) -> Image.Image:
    """Adds a 1px outline around every opaque area (4-neighbour)."""
    c = c or P["outline"]
    src = img.copy()
    for y in range(img.height):
        for x in range(img.width):
            if src.getpixel((x, y))[3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    if get(src, x + dx, y + dy)[3] > 0:
                        img.putpixel((x, y), c)
                        break
    return img


def hash01(x: int, y: int, seed: int = 0) -> float:
    n = (x * 374761393 + y * 668265263 + seed * 2147483647) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def noise1d(x: float, period: int, scale: float, seed: int) -> float:
    """Smooth value noise in 0..1 that tiles every `period` pixels."""
    cells = max(1, round(period / scale))
    fx = x / scale
    i0 = math.floor(fx)
    t = fx - i0
    t = (1 - math.cos(t * math.pi)) / 2
    a = hash01(i0 % cells, 0, seed)
    b = hash01((i0 + 1) % cells, 0, seed)
    return a + (b - a) * t


def noise2d(x: float, y: float, scale: float, seed: int) -> float:
    """Smooth 2D value noise in 0..1 (not tiling)."""
    fx, fy = x / scale, y / scale
    ix, iy = math.floor(fx), math.floor(fy)
    tx, ty = fx - ix, fy - iy
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    a, b = hash01(ix, iy, seed), hash01(ix + 1, iy, seed)
    c, d = hash01(ix, iy + 1, seed), hash01(ix + 1, iy + 1, seed)
    top, bot = a + (b - a) * tx, c + (d - c) * tx
    return top + (bot - top) * ty


def lerp_color(a, b, t: float):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3)) + (255,)


def shade_index(d: float, levels: int, x: int, y: int) -> int:
    """Turns a 0..1 brightness into a palette index with ordered dithering."""
    f = max(0.0, min(0.999, d)) * (levels - 1)
    base = int(f)
    if f - base > (BAYER4[y % 4][x % 4] + 0.5) / 16 and base < levels - 1:
        base += 1
    return base


def sphere(img, cx, cy, r, colors, band=None, light=(-0.55, -0.6, 0.58)) -> None:
    """Lit sphere. colors: dark -> light. band(nx, ny) may return a palette list per pixel."""
    lx, ly, lz = light
    ln = math.sqrt(lx * lx + ly * ly + lz * lz)
    lx, ly, lz = lx / ln, ly / ln, lz / ln
    for y in range(int(cy - r) - 1, int(cy + r) + 2):
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            nx, ny = (x + 0.5 - cx) / r, (y + 0.5 - cy) / r
            dd = nx * nx + ny * ny
            if dd > 1:
                continue
            nz = math.sqrt(1 - dd)
            d = max(0.0, nx * lx + ny * ly + nz * lz)
            pal = band(nx, ny) if band else colors
            put(img, x, y, pal[shade_index(d * 1.1, len(pal), x, y)])


def paste(base: Image.Image, img: Image.Image, x: int, y: int) -> None:
    """Alpha-composites img onto base at (x, y), clipping to the base image."""
    x0, y0 = max(0, -x), max(0, -y)
    x1, y1 = min(img.width, base.width - x), min(img.height, base.height - y)
    if x1 <= x0 or y1 <= y0:
        return
    base.alpha_composite(img.crop((x0, y0, x1, y1)), (x + x0, y + y0))


def save(img: Image.Image, rel: str) -> None:
    path = ART / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    SAVED[rel] = img


SAVED: dict[str, Image.Image] = {}


def sheet(frames: list[Image.Image]) -> Image.Image:
    w, h = frames[0].size
    out = new(w * len(frames), h)
    for i, f in enumerate(frames):
        out.paste(f, (i * w, 0))
    return out


# ---------------------------------------------------------------- player (dog)

def draw_dog(legs, bob=0, ears_up=False, tail="up") -> Image.Image:
    """24x24 beagle-ish pet dog facing right. legs: (x, lift, far) for each of the 4 legs."""
    img = new(24, 24)
    b = bob
    fur, dark, light, ear = P["tan"], P["brown"], P["cream"], P["dbrown"]
    for x, lift, far in legs:
        col = dark if far else fur
        bottom = 22 - lift
        rect(img, x, 17 + b, x + 1, bottom, col)
        if not far:
            rect(img, x, bottom, x + 1, bottom, light)  # white socks
    tails = {
        "up": [(4, 14), (3, 13), (2, 12), (2, 11), (1, 10)],
        "wag": [(4, 14), (3, 13), (2, 13), (1, 12), (0, 12)],
    }
    for x, y in tails[tail]:
        put(img, x, y + b, fur)
    put(img, tails[tail][-1][0], tails[tail][-1][1] + b, light)  # white tail tip
    ellipse(img, 10.5, 15.5 + b, 7, 3.5, fur)
    for y in range(24):
        for x in range(24):
            if img.getpixel((x, y)) == fur:
                if y <= 14 + b and 5 <= x <= 13:
                    put(img, x, y, dark)  # beagle saddle
                elif y >= 18 + b and 7 <= x <= 14:
                    put(img, x, y, light)  # belly
    ellipse(img, 17.5, 10.5 + b, 4, 3.5, fur)
    rect(img, 20, 11 + b, 22, 13 + b, light)
    put(img, 22, 11 + b, P["outline"])  # nose
    put(img, 18, 9 + b, P["outline"])  # eye
    if ears_up:  # ear flaps back in the wind
        for x, y in ((14, 9), (13, 9), (13, 8), (12, 8), (11, 7), (12, 7)):
            put(img, x, y + b, ear)
    else:
        rect(img, 14, 8 + b, 15, 12 + b, ear)
    for x in (15, 16, 17):
        put(img, x, 14 + b, P["red"])
    put(img, 16, 15 + b, P["gold"])  # name tag
    return outline(img)


def make_player() -> None:
    T, F = True, False
    frames = [
        # idle x2
        draw_dog([(5, 0, T), (7, 0, F), (13, 0, T), (15, 0, F)], 0, tail="up"),
        draw_dog([(5, 0, T), (7, 0, F), (13, 0, T), (15, 0, F)], 0, tail="wag"),
        # run x4
        draw_dog([(3, 1, T), (6, 0, F), (14, 0, T), (17, 1, F)], 0),
        draw_dog([(5, 0, T), (7, 2, F), (14, 2, T), (15, 0, F)], 1, tail="wag"),
        draw_dog([(7, 1, T), (8, 0, F), (12, 0, T), (13, 1, F)], 0),
        draw_dog([(5, 2, T), (6, 0, F), (15, 0, T), (16, 2, F)], 1, tail="wag"),
        # jump, fall
        draw_dog([(3, 2, T), (5, 1, F), (16, 3, T), (17, 2, F)], -1),
        draw_dog([(5, 1, T), (7, 0, F), (14, 1, T), (16, 0, F)], -1, ears_up=True),
    ]
    save(sheet(frames), "player/dog.png")


# ---------------------------------------------------------------- rocket

def draw_rocket() -> Image.Image:
    W, H, cx = 48, 112, 24
    img = new(W, H)
    d = ImageDraw.Draw(img)
    # fins behind the body
    d.polygon([(cx - 11, 68), (cx - 22, 96), (cx - 22, 104), (cx - 10, 99)], fill=P["red"])
    d.polygon([(cx + 10, 68), (cx + 21, 96), (cx + 21, 104), (cx + 9, 99)], fill=P["dred"])

    def half(y: int) -> float:
        if y < 34:
            return 12.5 * math.sin(((y + 1) / 34) * math.pi / 2) ** 0.75
        if y < 92:
            return 12.5
        return 12.5 - (y - 92) * 0.45

    for y in range(0, 99):
        h = half(y)
        for x in range(cx - 13, cx + 13):
            dx = (x + 0.5 - cx) / h
            if abs(dx) > 1:
                continue
            red_part = y < 33 or 36 <= y <= 38 or 86 <= y <= 88
            if red_part:
                c = P["pink"] if -0.65 < dx < -0.35 else P["red"] if dx < 0.3 else P["dred"]
            else:
                c = P["light"] if dx < -0.75 else P["white"] if dx < 0.15 else P["light"] if dx < 0.6 else P["grey"]
            put(img, x, y, c)
    # nozzle
    for i, y in enumerate(range(99, 107)):
        h = 6 + i * 0.35
        for x in range(cx - 9, cx + 9):
            dx = (x + 0.5 - cx) / h
            if abs(dx) <= 1:
                put(img, x, y, P["grey"] if dx < -0.3 else P["dgrey"] if dx < 0.4 else P["ddgrey"])
    # front fin
    rect(img, cx - 1, 80, cx, 104, P["red"])
    put(img, cx - 1, 80, P["pink"])
    # window with the pet's owner inside
    ellipse(img, cx, 54, 7.5, 7.5, P["dgrey"])
    ellipse(img, cx, 54, 6, 6, P["light"])
    ellipse(img, cx, 54, 5, 5, P["dblue"])
    ellipse(img, cx, 55, 3.5, 3.5, P["white"])   # helmet
    rect(img, cx - 2, 55, cx + 1, 57, P["cream"])  # face
    put(img, cx - 1, 56, P["outline"])
    put(img, cx + 1, 56, P["outline"])
    put(img, cx - 4, 51, P["cyan"])
    put(img, cx - 3, 50, P["cyan"])
    # rivets
    for y in (44, 66, 76):
        for x in (cx - 8, cx + 7):
            put(img, x, y, P["grey"])
    return outline(img)


def draw_flame(seed: int) -> Image.Image:
    rnd = random.Random(seed)
    W, H, cx = 20, 34, 10
    img = new(W, H)
    length = H - 2 - rnd.randint(0, 6)
    for y in range(length):
        t = y / length
        w = 7.5 * (1 - t) ** 0.8 + rnd.uniform(-0.6, 0.6)
        wobble = math.sin(y * 0.7 + seed) * 0.8 * t
        for x in range(W):
            dx = abs(x + 0.5 - cx - wobble) / max(w, 0.5)
            if dx > 1:
                continue
            c = P["white"] if dx < 0.3 and t < 0.45 else P["yellow"] if dx < 0.55 and t < 0.7 else P["gold"] if dx < 0.8 else P["orange"]
            if t > 0.8 and hash01(x, y, seed) < 0.4:
                c = P["red"]
            put(img, x, y, c)
    return img


def make_rocket() -> None:
    save(draw_rocket(), "rocket/rocket.png")
    save(sheet([draw_flame(s) for s in (1, 2, 3)]), "rocket/flame.png")
    puffs = []
    for i, r in enumerate((4.5, 6, 7.5)):
        img = new(16, 16)
        ellipse(img, 8, 8.5, r, r * 0.85, P["light"])
        ellipse(img, 7, 7.5, r * 0.75, r * 0.65, P["white"])
        puffs.append(img)
    save(sheet(puffs), "rocket/smoke.png")


# ---------------------------------------------------------------- platform tiles

def in_round_rect(x, y, x0, y0, x1, y1, r) -> bool:
    px, py = x + 0.5, y + 0.5
    if not (x0 <= px <= x1 and y0 <= py <= y1):
        return False
    cx = min(max(px, x0 + r), x1 - r)
    cy = min(max(py, y0 + r), y1 - r)
    return (px - cx) ** 2 + (py - cy) ** 2 <= r * r


def platform_strip(zone: str, w: int) -> Image.Image:
    """A w x 16 platform with caps at both ends. Texture repeats every 16px so middle tiles tile."""
    img = new(w, 16)
    oc = P["outline"]
    for y in range(16):
        for x in range(w):
            u = x % 16
            n = hash01(u, y, 7)
            c = None
            if zone == "grass":
                if in_round_rect(x, y, 1, 1, w - 1, 15, 3):
                    if y == 1:
                        c = P["lgreen"]
                    elif y <= 4:
                        c = P["green"] if n > 0.15 else P["lgreen"]
                    elif y == 5:
                        c = P["dgreen"] if hash01(u, 0, 3) < 0.55 else P["brown"]
                    elif y >= 14:
                        c = P["dbrown"]
                    else:
                        c = P["dbrown"] if n < 0.12 else P["grey"] if n > 0.97 else P["brown"]
            elif zone == "launchpad":
                if in_round_rect(x, y, 1, 1, w - 1, 15, 1):
                    if y == 1:
                        c = P["light"]
                    elif y <= 5:
                        c = P["dgrey"] if (u % 8 == 3 and y == 3) else P["grey"]
                    elif y <= 9:
                        c = P["yellow"] if ((x + y) // 3) % 2 == 0 else P["navy"]
                    else:
                        c = P["ddgrey"] if (u % 4 == 1 and 11 <= y <= 13) else P["dgrey"]
            elif zone == "cloud":
                edge = min(x - 1, w - 2 - x)
                pinch = max(0, 6 - edge) ** 2 / 9 if edge < 6 else 0
                top = 3 + 1.6 * math.cos(2 * math.pi * (u + 0.5) / 8) + pinch
                bottom = 12.5 + 1.2 * math.cos(2 * math.pi * (u + 4.5) / 16) - pinch * 0.7
                if edge >= 0 and top <= y + 0.5 <= bottom:
                    c = P["white"] if y + 0.5 < top + 3 else P["light"] if y + 0.5 < bottom - 1.5 else P["grey"]
                oc = P["dgrey"]
            elif zone == "girder":
                if 1 <= x <= w - 2 and 1 <= y <= 14:
                    edge_post = x <= 2 or x >= w - 3
                    if y <= 3:
                        c = P["gold"] if y == 1 else P["orange"]
                        if y == 2 and u % 8 == 4:
                            c = P["dbrown"]
                    elif y >= 12:
                        c = P["orange"] if y < 14 else P["dbrown"]
                    elif edge_post:
                        c = P["orange"]
                    else:
                        k = y - 4
                        if u in (2 * k, 2 * k + 1, 15 - 2 * k, 14 - 2 * k):
                            c = P["orange"] if u < 8 else P["dbrown"]
            elif zone == "solar":
                if in_round_rect(x, y, 1, 1, w - 1, 15, 1):
                    if y <= 2 or y >= 13 or x <= 2 or x >= w - 3:
                        c = P["light"] if y <= 2 else P["grey"]
                    else:
                        line = u % 4 == 3 or y % 4 == 2
                        c = P["navy"] if line else (P["blue"] if (u + y) % 7 == 0 else P["dblue"])
            elif zone in ("asteroid", "moon"):
                rough = 2.2 if zone == "asteroid" else 0.8
                edge = min(x - 1, w - 2 - x)
                pinch = max(0, 5 - edge) ** 2 / 6 if edge < 5 else 0
                top = 2 + rough * noise1d(u, 16, 4, 11 if zone == "asteroid" else 5) + pinch * 0.6
                bottom = 14 - rough * noise1d(u, 16, 4, 23) - pinch
                if edge >= 0 and top <= y + 0.5 <= bottom:
                    pal = ([P["drock"], P["rock"], P["lrock"]] if zone == "asteroid"
                           else [P["dmoon"], P["moon"], P["lmoon"]])
                    c = pal[2] if y + 0.5 < top + 1.5 else pal[0] if y + 0.5 > bottom - 2 else pal[1]
                    for ccx, ccy, cr in ((4.5, 7.5, 2.2), (11.5, 9.5, 1.6)):
                        dd = math.hypot(u + 0.5 - ccx, y + 0.5 - ccy)
                        if dd < cr:
                            c = pal[0]
                        elif dd < cr + 1 and y + 0.5 > ccy:
                            c = pal[2]
                    if n < 0.06:
                        c = pal[0]
            if c:
                img.putpixel((x, y), c)
    return outline(img, oc)


ZONES = ["grass", "launchpad", "cloud", "girder", "solar", "asteroid", "moon"]


def make_tiles() -> None:
    atlas = new(64, 16 * len(ZONES))
    for row, zone in enumerate(ZONES):
        strip = platform_strip(zone, 64)
        single = platform_strip(zone, 16)
        tiles = [strip.crop((0, 0, 16, 16)), strip.crop((16, 0, 32, 16)), strip.crop((48, 0, 64, 16)), single]
        for col, t in enumerate(tiles):
            atlas.paste(t, (col * 16, row * 16))
    save(atlas, "tiles/platforms.png")
    # dirt fill that sits under the grass ground
    fill = new(16, 16)
    for y in range(16):
        for x in range(16):
            n = hash01(x, y, 7)
            fill.putpixel((x, y), P["dbrown"] if n < 0.12 else P["grey"] if n > 0.97 else P["brown"])
    save(fill, "tiles/dirt_fill.png")


# ---------------------------------------------------------------- backgrounds

SKY_STOPS = [
    (0.00, (150, 215, 255)), (0.18, (95, 175, 250)), (0.36, (45, 115, 215)), (0.54, (30, 60, 145)),
    (0.70, (32, 30, 90)), (0.85, (20, 14, 48)), (1.00, (10, 8, 22)),
]


def sky_color(t: float):
    for (t0, c0), (t1, c1) in zip(SKY_STOPS, SKY_STOPS[1:]):
        if t <= t1:
            return lerp_color(c0, c1, (t - t0) / (t1 - t0))
    return SKY_STOPS[-1][1] + (255,)


def make_sky() -> None:
    W, H, bands = 16, 1440, 18
    img = new(W, H)
    for y in range(H):
        t = 1 - y / (H - 1)  # 0 at the bottom (ground), 1 at the top (deep space)
        f = t * (bands - 1)
        base = int(f)
        for x in range(W):
            b = base + (1 if f - base > (BAYER4[y % 4][x % 4] + 0.5) / 16 and base < bands - 1 else 0)
            img.putpixel((x, y), sky_color(b / (bands - 1)))
    save(img, "backgrounds/sky_gradient.png")


def make_stars() -> None:
    for name, count, bright, seed in (("stars_far", 220, 0, 1), ("stars_near", 70, 10, 2)):
        rnd = random.Random(seed)
        W, H = 320, 180
        img = new(W, H)
        dim = [P["ddgrey"], P["dgrey"], P["grey"]] if name == "stars_far" else [P["grey"], P["light"], P["white"], P["cyan"], P["yellow"]]
        for _ in range(count):
            put(img, rnd.randrange(W), rnd.randrange(H), rnd.choice(dim))
        for _ in range(bright):
            x, y = rnd.randrange(W), rnd.randrange(H)
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                put(img, (x + dx) % W, (y + dy) % H, P["light"])
            put(img, x, y, P["white"])
        save(img, f"backgrounds/{name}.png")


def make_earth_skyline() -> None:
    W, H = 640, 180
    img = new(W, H)
    far, mid, near = (118, 160, 214, 255), (74, 128, 120, 255), P["ddgreen"]
    for x in range(W):
        m = 70 + 45 * noise1d(x, W, 90, 1) + 12 * noise1d(x, W, 23, 2)
        hills = 120 + 22 * noise1d(x, W, 70, 3) + 5 * noise1d(x, W, 9, 4)
        trees = 150 + 6 * noise1d(x, W, 5, 6) + 4 * noise1d(x, W, 31, 7)
        for y in range(H):
            if y >= trees:
                c = near if y > trees + 1 else P["dgreen"]
            elif y >= hills:
                c = mid if y > hills + 1 else (110, 165, 140, 255)
            elif y >= m:
                c = far if y > m + 1 else (150, 190, 232, 255)
            else:
                continue
            img.putpixel((x, y), c)
    save(img, "backgrounds/earth_skyline.png")


def make_launch_tower() -> None:
    W, H = 40, 168
    img = new(W, H)
    c, dc = P["red"], P["dred"]
    for y in range(8, H - 6):
        put(img, 4, y, c)
        put(img, 5, y, c)
        put(img, 18, y, dc)
        put(img, 19, y, dc)
        k = (y - 8) % 14
        if k == 0:
            rect(img, 4, y, 19, y, c)
        else:
            put(img, 5 + k, y, dc)
            put(img, 18 - k, y, dc)
    for y in (40, 92):  # service arms reaching toward the rocket
        rect(img, 20, y, 38, y + 2, P["grey"])
        rect(img, 20, y + 3, 38, y + 3, P["dgrey"])
    rect(img, 11, 0, 12, 8, P["grey"])  # lightning rod
    put(img, 11, 0, P["red"])
    rect(img, 0, H - 6, 23, H - 2, P["dgrey"])
    rect(img, 0, H - 6, 23, H - 6, P["grey"])
    save(outline(img), "props/launch_tower.png")


def draw_cloud(w: int, h: int, seed: int) -> Image.Image:
    rnd = random.Random(seed)
    img = new(w, h)
    blobs = []
    x = h * 0.5
    while x < w - h * 0.4:
        r = rnd.uniform(h * 0.28, h * 0.45)
        blobs.append((x, h - r - 2, r))
        x += r * 1.1
    for bx, by, r in blobs:
        ellipse(img, bx, by, r, r, (210, 228, 248, 255))
    for bx, by, r in blobs:
        ellipse(img, bx - 1, by - 1.5, r * 0.85, r * 0.85, P["white"])
    rect(img, h * 0.4, h - 6, w - h * 0.4, h - 3, (210, 228, 248, 255))
    return outline(img, (176, 200, 232, 255))


def make_clouds() -> None:
    save(draw_cloud(96, 40, 1), "props/cloud_big.png")
    save(draw_cloud(64, 28, 2), "props/cloud_medium.png")
    save(draw_cloud(40, 20, 3), "props/cloud_small.png")


def make_earth_horizon() -> None:
    """The curved Earth seen from high above; shown when the climb leaves the atmosphere."""
    W, H, R = 640, 150, 900
    cx, cy = W / 2, 30 + R
    img = new(W, H)
    for y in range(H):
        for x in range(W):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if d <= R:
                # squash noise vertically so land and clouds look foreshortened on the curve
                land = noise2d(x, y * 3, 48, 8) * 0.65 + noise2d(x, y * 3, 14, 9) * 0.35
                cloud = noise2d(x, y * 3.5, 30, 10) * 0.7 + noise2d(x, y * 3.5, 8, 11) * 0.3
                depth = (y + 0.5 - (cy - R)) / H
                if cloud > 0.68:
                    c = P["white"] if cloud > 0.74 else P["light"]
                elif land > 0.62:
                    c = P["green"] if land < 0.7 else P["dgreen"]
                else:
                    c = P["blue"] if depth < 0.45 else P["dblue"]
                if R - d < 2:
                    c = P["cyan"]
                img.putpixel((x, y), c)
            elif d <= R + 7:
                a = 1 - (d - R) / 7
                if a > (BAYER4[y % 4][x % 4] + 0.5) / 16:
                    img.putpixel((x, y), P["cyan"] if d < R + 3 else (90, 170, 255, 255))
    save(img, "backgrounds/earth_horizon.png")


def make_planets() -> None:
    # ringed planet
    img = new(72, 40)
    cx, cy = 36, 20

    def ring(front: bool) -> None:
        for y in range(40):
            for x in range(72):
                v = ((x + 0.5 - cx) / 33) ** 2 + ((y + 0.5 - cy) / 7) ** 2
                inner = ((x + 0.5 - cx) / 22) ** 2 + ((y + 0.5 - cy) / 4.2) ** 2
                if v <= 1 and inner > 1 and ((y + 0.5 >= cy) == front):
                    put(img, x, y, P["cream"] if v < 0.8 else P["tan"])

    ring(False)
    sphere(img, cx, cy, 14, None, band=lambda nx, ny: [P["dbrown"], P["brown"], P["tan"], P["cream"]]
           if int((ny + 1) * 5) % 2 else [P["dbrown"], P["orange"], P["gold"], P["yellow"]])
    ring(True)
    save(outline(img), "props/planet_ringed.png")

    img = new(34, 34)
    sphere(img, 17, 17, 15, [P["ddbrown"], P["dred"], P["red"], P["orange"]])
    for ccx, ccy, r in ((12, 12, 3), (21, 20, 2), (14, 23, 1.6)):
        ellipse(img, ccx, ccy, r, r, P["dred"])
    save(outline(img), "props/planet_red.png")

    img = new(50, 50)
    sphere(img, 25, 25, 23, None, band=lambda nx, ny: [P["navy"], P["purple"], P["magenta"], P["pink"]]
           if int((ny + 1) * 6 + nx * 0.6) % 3 else [P["navy"], P["ddgrey"], P["purple"], P["magenta"]])
    save(outline(img), "props/planet_gas.png")

    img = new(22, 22)
    sphere(img, 11, 11, 9.5, [P["dblue"], P["blue"], P["cyan"], P["white"]])
    save(outline(img), "props/planet_ice.png")


def make_moon() -> None:
    S, r = 132, 62
    img = new(S, S)
    sphere(img, S / 2, S / 2, r, [P["ddmoon"], P["dmoon"], P["moon"], P["lmoon"]])
    rnd = random.Random(4)
    for _ in range(22):
        a, dist = rnd.uniform(0, math.tau), math.sqrt(rnd.random()) * (r - 7)
        ccx, ccy = S / 2 + math.cos(a) * dist, S / 2 + math.sin(a) * dist
        cr = rnd.uniform(2, 8)
        for y in range(int(ccy - cr) - 1, int(ccy + cr) + 2):
            for x in range(int(ccx - cr) - 1, int(ccx + cr) + 2):
                if img.getpixel((x % S, y % S))[3] == 0:
                    continue
                dd = math.hypot(x + 0.5 - ccx, y + 0.5 - ccy)
                if dd < cr - 1:
                    put(img, x, y, P["dmoon"] if (x + 0.5 - ccx) + (y + 0.5 - ccy) < 0 else P["moon"])
                elif dd < cr and (x + 0.5 - ccx) + (y + 0.5 - ccy) > 0:
                    put(img, x, y, P["lmoon"])
    save(outline(img, P["ddmoon"]), "props/moon.png")


def draw_asteroid(r: float, seed: int) -> Image.Image:
    S = int(r * 2 + 6)
    img = new(S, S)
    c = S / 2
    rnd = random.Random(seed)
    bumps = [rnd.uniform(0.8, 1.05) for _ in range(9)]
    pal = [P["drock"], P["rock"], P["lrock"]]
    for y in range(S):
        for x in range(S):
            dx, dy = x + 0.5 - c, y + 0.5 - c
            ang = (math.atan2(dy, dx) + math.pi) / math.tau * 9
            i = int(ang) % 9
            t = ang - int(ang)
            rr = r * (bumps[i] + (bumps[(i + 1) % 9] - bumps[i]) * t)
            dist = math.hypot(dx, dy)
            if dist <= rr:
                light = 0.5 - (dx + dy) / (2.8 * r) + 0.2 * math.sqrt(max(0, 1 - (dist / rr) ** 2))
                img.putpixel((x, y), pal[shade_index(light, 3, x, y)])
    for _ in range(max(1, int(r / 5))):
        a, dist = rnd.uniform(0, math.tau), rnd.uniform(0, r * 0.5)
        cr = rnd.uniform(1.2, r * 0.25)
        ellipse(img, c + math.cos(a) * dist, c + math.sin(a) * dist, cr, cr, P["drock"])
    return outline(img)


def make_space_props() -> None:
    save(draw_asteroid(5, 1), "props/asteroid_small.png")
    save(draw_asteroid(9, 2), "props/asteroid_medium.png")
    save(draw_asteroid(15, 3), "props/asteroid_large.png")

    frames = []
    for f in range(2):
        img = new(34, 18)
        ellipse(img, 17, 7, 6.5, 5, P["cyan"])
        rect(img, 10, 7, 24, 9, CLEAR)
        put(img, 14, 4, P["white"])
        ellipse(img, 17, 10.5, 15, 3.6, P["grey"])
        rect(img, 3, 9, 31, 9, P["light"])
        for i, x in enumerate((8, 13, 18, 23, 28)):
            put(img, x - 1, 11, P["yellow"] if (i + f) % 2 else P["red"])
        frames.append(outline(img))
    save(sheet(frames), "props/ufo.png")

    img = new(40, 18)
    d = ImageDraw.Draw(img)
    d.polygon([(4, 6), (30, 6), (37, 9), (30, 12), (4, 12)], fill=P["light"])
    d.polygon([(6, 6), (12, 1), (16, 1), (16, 6)], fill=P["red"])
    d.polygon([(10, 12), (18, 12), (14, 16), (8, 16)], fill=P["dred"])
    rect(img, 4, 10, 31, 12, P["grey"])
    rect(img, 24, 7, 28, 8, P["cyan"])
    rect(img, 1, 7, 3, 11, P["orange"])
    put(img, 0, 9, P["yellow"])
    save(outline(img), "props/spaceship.png")

    img = new(44, 22)
    for x0 in (1, 29):
        rect(img, x0, 5, x0 + 13, 15, P["dblue"])
        for x in range(x0, x0 + 14):
            for y in range(5, 16):
                if (x - x0) % 4 == 3 or (y - 5) % 4 == 3:
                    put(img, x, y, P["navy"])
    rect(img, 15, 9, 28, 11, P["grey"])
    rect(img, 17, 5, 26, 16, P["gold"])
    rect(img, 17, 5, 26, 6, P["yellow"])
    rect(img, 23, 7, 26, 16, P["orange"])
    rect(img, 21, 1, 22, 4, P["light"])
    ellipse(img, 21.5, 2, 3, 1.5, P["light"])
    save(outline(img), "props/satellite.png")


def make_sky_props() -> None:
    img = new(36, 14)
    d = ImageDraw.Draw(img)
    rect(img, 4, 5, 31, 8, P["white"])
    ellipse(img, 31, 6.5, 4, 2.2, P["white"])
    rect(img, 4, 8, 31, 8, P["light"])
    d.polygon([(2, 1), (6, 1), (10, 5), (4, 5)], fill=P["red"])
    d.polygon([(14, 7), (22, 7), (16, 13), (12, 13)], fill=P["light"])
    for x in range(12, 30, 3):
        put(img, x, 6, P["blue"])
    put(img, 33, 6, P["dblue"])
    save(outline(img), "props/airplane.png")

    frames = []
    for up in (True, False):
        img = new(13, 10)
        rect(img, 5, 5, 7, 6, P["white"])
        put(img, 8, 5, P["white"])
        put(img, 9, 5, P["orange"])
        wing = ([(2, 2), (3, 3), (4, 4), (10, 2), (9, 3), (8, 4)] if up
                else [(2, 7), (3, 7), (4, 6), (10, 7), (9, 7), (8, 6)])
        for x, y in wing:
            put(img, x, y, P["white"])
        frames.append(outline(img, P["dgrey"]))
    save(sheet(frames), "props/bird.png")

    img = new(24, 32)
    for y in range(32):
        for x in range(24):
            dx, dy = (x + 0.5 - 12) / 10.5, (y + 0.5 - 11) / 10.5
            if dy > 0:
                dx /= max(0.35, 1 - dy * 0.55)
            if dx * dx + dy * dy <= 1:
                stripe = int((dx + 1) * 3) % 2
                c = (P["red"] if stripe else P["yellow"]) if dx < 0.35 else (P["dred"] if stripe else P["gold"])
                put(img, x, y, c)
    for x0, x1 in ((7, 10), (16, 13)):
        for y in range(20, 26):
            put(img, x0 + (x1 - x0) * (y - 20) / 6, y, P["dbrown"])
    rect(img, 9, 26, 14, 30, P["brown"])
    rect(img, 9, 26, 14, 26, P["tan"])
    save(outline(img), "props/hot_air_balloon.png")


# ---------------------------------------------------------------- previews

def tile(zone: str, col: int) -> Image.Image:
    row = ZONES.index(zone)
    return SAVED["tiles/platforms.png"].crop((col * 16, row * 16, col * 16 + 16, row * 16 + 16))


def platform(base, zone: str, x: int, y: int, n: int) -> None:
    if n == 1:
        paste(base, tile(zone, 3), x, y)
        return
    for i in range(n):
        paste(base, tile(zone, 0 if i == 0 else 2 if i == n - 1 else 1), x + i * 16, y)


def frame(rel: str, i: int, w: int) -> Image.Image:
    img = SAVED[rel]
    return img.crop((i * w, 0, i * w + w, img.height))


def sky_section(y0: int) -> Image.Image:
    """The gradient tiles horizontally (dither repeats every 4px), like a repeating TextureRect in Godot."""
    strip = SAVED["backgrounds/sky_gradient.png"].crop((0, y0, 16, y0 + 360))
    out = new(640, 360)
    for x in range(0, 640, 16):
        out.paste(strip, (x, 0))
    return out


def mockups() -> Image.Image:
    rocket = SAVED["rocket/rocket.png"]
    dog = SAVED["player/dog.png"]

    # 1. Launch site
    a = sky_section(1080)
    paste(a, SAVED["props/cloud_medium.png"], 80, 60)
    paste(a, SAVED["props/cloud_small.png"], 420, 30)
    paste(a, SAVED["backgrounds/earth_skyline.png"], 0, 180)
    paste(a, SAVED["props/launch_tower.png"], 440, 344 - 168 + 4)
    paste(a, rocket, 474, 344 - 112 + 4)
    for i, x in enumerate((468, 492, 512)):
        paste(a, frame("rocket/smoke.png", i, 16), x, 330)
    for x in range(0, 640, 16):
        paste(a, tile("grass", 1), x, 344)
    platform(a, "launchpad", 96, 296, 4)
    platform(a, "grass", 220, 248, 3)
    platform(a, "grass", 60, 200, 1)
    paste(a, frame("player/dog.png", 2, 24), 120, 296 - 24 + 2)

    # 2. Sky
    b = sky_section(560)
    paste(b, SAVED["props/cloud_big.png"], 40, 220)
    paste(b, SAVED["props/cloud_medium.png"], 500, 80)
    paste(b, SAVED["props/airplane.png"], 380, 40)
    paste(b, SAVED["props/hot_air_balloon.png"], 120, 50)
    paste(b, frame("props/bird.png", 0, 13), 300, 120)
    paste(b, frame("props/bird.png", 1, 13), 318, 128)
    paste(b, rocket, 440, 120)
    paste(b, frame("rocket/flame.png", 0, 20), 454, 120 + 106)
    platform(b, "cloud", 80, 300, 4)
    platform(b, "cloud", 260, 240, 3)
    platform(b, "girder", 120, 170, 3)
    platform(b, "cloud", 300, 120, 1)
    paste(b, frame("player/dog.png", 6, 24), 290, 200)

    # 3. Space
    c = sky_section(0)
    paste(c, SAVED["backgrounds/stars_far.png"], 0, 0)
    paste(c, SAVED["backgrounds/stars_far.png"], 320, 0)
    paste(c, SAVED["backgrounds/stars_far.png"], 0, 180)
    paste(c, SAVED["backgrounds/stars_far.png"], 320, 180)
    paste(c, SAVED["backgrounds/stars_near.png"], 0, 0)
    paste(c, SAVED["backgrounds/stars_near.png"], 320, 180)
    paste(c, SAVED["backgrounds/earth_horizon.png"], 0, 290)
    paste(c, SAVED["props/moon.png"], 470, -30)
    paste(c, SAVED["props/planet_ringed.png"], 60, 40)
    paste(c, SAVED["props/planet_red.png"], 330, 60)
    paste(c, SAVED["props/planet_gas.png"], 20, 170)
    paste(c, SAVED["props/planet_ice.png"], 260, 20)
    paste(c, frame("props/ufo.png", 0, 34), 380, 150)
    paste(c, SAVED["props/satellite.png"], 560, 200)
    paste(c, SAVED["props/spaceship.png"], 160, 120)
    paste(c, SAVED["props/asteroid_large.png"], 520, 270)
    paste(c, SAVED["props/asteroid_medium.png"], 200, 230)
    paste(c, SAVED["props/asteroid_small.png"], 300, 180)
    paste(c, rocket, 420, 150)
    paste(c, frame("rocket/flame.png", 1, 20), 434, 150 + 106)
    platform(c, "asteroid", 60, 300, 3)
    platform(c, "solar", 220, 260, 4)
    platform(c, "asteroid", 120, 210, 1)
    platform(c, "moon", 300, 160, 4)
    paste(c, frame("player/dog.png", 0, 24), 330, 160 - 24 + 2)

    out = new(640, 360 * 3 + 8)
    for i, im in enumerate((c, b, a)):
        out.paste(im, (0, i * 364))
    return out


def asset_sheet() -> Image.Image:
    items = [(k, v) for k, v in SAVED.items() if not k.startswith("backgrounds/")]
    pad, scale, width = 6, 2, 640
    x = y = pad
    row_h = 0
    placed = []
    for name, img in items:
        w, h = img.width * scale, img.height * scale
        if x + w > width - pad:
            x, y = pad, y + row_h + pad
            row_h = 0
        placed.append((img, x, y))
        x += w + pad
        row_h = max(row_h, h)
    out = Image.new("RGBA", (width, y + row_h + pad), (40, 44, 60, 255))
    for img, x, y in placed:
        paste(out, img.resize((img.width * scale, img.height * scale), Image.NEAREST), x, y)
    return out


def save_palette() -> None:
    """Palette files for artists: a swatch image and a GIMP/Aseprite .gpl palette."""
    names = list(P)
    cols, size = 9, 24
    rows = math.ceil(len(names) / cols)
    img = Image.new("RGBA", (cols * size, rows * size), (255, 255, 255, 0))
    for i, name in enumerate(names):
        x, y = (i % cols) * size, (i // cols) * size
        rect(img, x + 1, y + 1, x + size - 2, y + size - 2, P[name])
    img.save(PREVIEW / "palette.png")
    lines = ["GIMP Palette", "Name: Race to the Moon", f"Columns: {cols}", "#"]
    lines += [f"{c[0]:3d} {c[1]:3d} {c[2]:3d}\t{name}" for name, c in P.items()]
    (PREVIEW / "palette.gpl").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    make_player()
    make_rocket()
    make_tiles()
    make_sky()
    make_stars()
    make_earth_skyline()
    make_launch_tower()
    make_clouds()
    make_earth_horizon()
    make_planets()
    make_moon()
    make_space_props()
    make_sky_props()
    PREVIEW.mkdir(parents=True, exist_ok=True)
    mockups().save(PREVIEW / "mockups.png")
    asset_sheet().save(PREVIEW / "asset-sheet.png")
    save_palette()
    print(f"Wrote {len(SAVED)} images to {ART} and previews to {PREVIEW}")


if __name__ == "__main__":
    main()
