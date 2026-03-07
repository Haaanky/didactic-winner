#!/usr/bin/env python3
"""
High-fidelity environment sprite generator for Dudes in Alaska.
Creates photorealistic-style 2D sprites for the Alaskan world environment.

Outputs (all in assets/sprites/environment/):
  sky_gradient.png          2048x512   day sky with horizon glow
  mountains_far.png         4096x384   distant blue-grey mountain silhouette
  mountains_mid.png         4096x512   mid-distance snow-capped peaks
  glacier.png               2048x256   ice/glacier face detail
  forest_far.png            4096x320   dark treeline silhouette
  spruce_large.png          128x256    detailed snow-laden spruce
  spruce_medium.png         96x192     medium snow spruce
  spruce_small.png          64x128     small spruce
  birch_large.png           96x256     bare winter birch
  snow_ground.png           512x256    detailed snow ground texture (tileable)
  snow_cliff.png            256x256    rocky cliff with snow
  water_surface.png         512x256    ocean/lake water surface texture
  water_deep.png            512x256    deep water texture
  coastal_rocks.png         512x256    rocky coastal foreground
  ice_shore.png             512x128    shore ice / sea ice
  fog_wisp.png              512x256    soft fog particle texture
  snowflake.png             32x32      snowflake particle
  cloud_layer.png           2048x256   low cloud bank
  aurora_strip.png          2048x256   aurora borealis hint
"""

import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "sprites", "environment")
os.makedirs(OUT, exist_ok=True)


# ---------------------------------------------------------------------------
# Noise helpers
# ---------------------------------------------------------------------------

def noise(x: float, y: float, seed: int = 0) -> float:
    """Cheap deterministic pseudo-random in [0, 1]."""
    xi, yi = int(x), int(y)
    v = (xi * 73856093) ^ (yi * 19349663) ^ (seed * 83492791)
    v = (v ^ (v >> 16)) & 0xFFFFFF
    return v / 0xFFFFFF


def smooth_noise(x: float, y: float, seed: int = 0) -> float:
    """Bilinear-interpolated noise."""
    xi, yi = int(x), int(y)
    fx, fy = x - xi, y - yi
    a = noise(xi, yi, seed)
    b = noise(xi + 1, yi, seed)
    c = noise(xi, yi + 1, seed)
    d = noise(xi + 1, yi + 1, seed)
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy


def fractal_noise(x: float, y: float, octaves: int = 5, seed: int = 0) -> float:
    """Multi-octave fractal noise, returns [0, 1]."""
    val, amp, freq = 0.0, 1.0, 1.0
    total_amp = 0.0
    for _ in range(octaves):
        val += smooth_noise(x * freq, y * freq, seed) * amp
        total_amp += amp
        amp *= 0.5
        freq *= 2.0
    return val / total_amp


def lerp_color(c1: tuple, c2: tuple, t: float) -> tuple:
    t = max(0.0, min(1.0, t))
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def blend_colors(base: tuple, overlay: tuple, alpha: float) -> tuple:
    """Blend overlay over base with given alpha."""
    alpha = max(0.0, min(1.0, alpha))
    r = int(base[0] * (1 - alpha) + overlay[0] * alpha)
    g = int(base[1] * (1 - alpha) + overlay[1] * alpha)
    b = int(base[2] * (1 - alpha) + overlay[2] * alpha)
    a = base[3] if len(base) > 3 else 255
    return (r, g, b, a)


# ---------------------------------------------------------------------------
# Sky gradient
# ---------------------------------------------------------------------------

def build_sky_gradient() -> None:
    W, H = 2048, 512
    img = Image.new("RGBA", (W, H))

    # Alaskan day sky: deep blue at zenith, lighter blue/steel at horizon
    # with a soft warm glow near horizon
    SKY_TOP    = (42, 82, 148, 255)    # deep Alaska blue zenith
    SKY_MID    = (95, 145, 195, 255)   # mid blue
    SKY_HORIZ  = (170, 200, 225, 255)  # pale steel blue near horizon
    HORIZ_GLOW = (220, 210, 190, 255)  # warm glow just above horizon

    for y in range(H):
        t = y / H
        # Gradient: top=sky_top, 70%=sky_mid, 90%=sky_horiz, 100%=horiz_glow
        if t < 0.5:
            base = lerp_color(SKY_TOP, SKY_MID, t / 0.5)
        elif t < 0.80:
            base = lerp_color(SKY_MID, SKY_HORIZ, (t - 0.5) / 0.3)
        else:
            base = lerp_color(SKY_HORIZ, HORIZ_GLOW, (t - 0.80) / 0.2)

        for x in range(W):
            # Subtle horizontal variation using noise
            n = smooth_noise(x / 400.0, y / 200.0, seed=77) * 0.04
            r = max(0, min(255, base[0] + int(n * 30)))
            g = max(0, min(255, base[1] + int(n * 25)))
            b = max(0, min(255, base[2] + int(n * 15)))
            img.putpixel((x, y), (r, g, b, 255))

    # Slight cloud wisps in upper sky
    rng = random.Random(42)
    for _ in range(18):
        cx = rng.randint(0, W)
        cy = rng.randint(20, int(H * 0.45))
        cw = rng.randint(200, 600)
        ch = rng.randint(20, 55)
        cloud_img = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        cd = ImageDraw.Draw(cloud_img)
        cd.ellipse([0, 0, cw, ch], fill=(230, 235, 242, 38))
        img.alpha_composite(cloud_img, (cx % W, cy))

    img = img.filter(ImageFilter.GaussianBlur(1))
    path = os.path.join(OUT, "sky_gradient.png")
    img.save(path)
    print(f"  Saved {path}")


# ---------------------------------------------------------------------------
# Aurora borealis strip
# ---------------------------------------------------------------------------

def build_aurora_strip() -> None:
    W, H = 2048, 256
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    # Aurora bands: green and teal ribbons
    AURORA_GREEN = (80, 220, 140)
    AURORA_TEAL  = (60, 200, 200)
    AURORA_VIOLET = (180, 120, 220)

    colors = [AURORA_GREEN, AURORA_TEAL, AURORA_VIOLET]
    rng = random.Random(7)

    for band in range(4):
        col = colors[band % len(colors)]
        base_y = rng.randint(20, H - 60)
        for x in range(W):
            # Wavy ribbon
            wave = math.sin(x / 180.0 + band * 1.3) * 30 + math.sin(x / 80.0 + band * 0.7) * 15
            cy = int(base_y + wave)
            thickness = rng.randint(12, 35)
            for dy in range(-thickness, thickness + 1):
                py = cy + dy
                if 0 <= py < H:
                    dist = abs(dy) / thickness
                    alpha = int((1.0 - dist * dist) * 80 * smooth_noise(x / 300.0, band + 0.5, seed=band + 10))
                    if alpha > 0:
                        ex, ey = x, py
                        r, g, b, a = img.getpixel((ex, ey))
                        nr = min(255, r + int(col[0] * alpha / 255))
                        ng = min(255, g + int(col[1] * alpha / 255))
                        nb = min(255, b + int(col[2] * alpha / 255))
                        na = min(255, a + alpha)
                        img.putpixel((ex, ey), (nr, ng, nb, na))

    img = img.filter(ImageFilter.GaussianBlur(3))
    path = os.path.join(OUT, "aurora_strip.png")
    img.save(path)
    print(f"  Saved {path}")


# ---------------------------------------------------------------------------
# Distant mountains silhouette
# ---------------------------------------------------------------------------

def _mountain_profile(W: int, H: int, peaks: int, seed: int,
                      min_height: float, max_height: float) -> list:
    """Generate a list of (x, y) profile points for mountain silhouette."""
    rng = random.Random(seed)
    # Place peaks
    peak_xs = sorted(rng.randint(0, W) for _ in range(peaks))
    peak_ys = [int(H * rng.uniform(min_height, max_height)) for _ in peak_xs]
    # Pad edges
    xs = [0] + peak_xs + [W]
    ys = [int(H * 0.85)] + peak_ys + [int(H * 0.85)]

    # Interpolate with smooth curve
    profile = []
    for x in range(W):
        # Find surrounding control points
        left_i = 0
        for i in range(len(xs) - 1):
            if xs[i] <= x:
                left_i = i
        right_i = min(left_i + 1, len(xs) - 1)
        if xs[right_i] == xs[left_i]:
            profile.append(ys[left_i])
            continue
        t = (x - xs[left_i]) / (xs[right_i] - xs[left_i])
        t = t * t * (3 - 2 * t)  # smoothstep
        y = int(ys[left_i] + (ys[right_i] - ys[left_i]) * t)
        # Add small-scale noise for rocky texture
        n = smooth_noise(x / 40.0, 0, seed=seed + 1) * 15 - 7
        profile.append(max(0, min(H - 1, y + int(n))))
    return profile


def build_mountains_far() -> None:
    W, H = 4096, 384
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    # Three overlapping mountain layers from back to front
    layers = [
        # (peaks, seed, min_h, max_h, base_color, snow_color, opacity)
        (22, 10, 0.10, 0.50, (80, 95, 125),  (200, 215, 230), 0.50),  # farthest, most blue
        (18, 20, 0.15, 0.60, (65, 80, 110),  (195, 210, 228), 0.65),  # mid
        (14, 30, 0.20, 0.65, (55, 70,  98),  (190, 208, 228), 0.80),  # nearest
    ]

    for peaks, seed, min_h, max_h, base_col, snow_col, opacity in layers:
        profile = _mountain_profile(W, H, peaks, seed, min_h, max_h)
        for x in range(W):
            ridge_y = profile[x]
            for y in range(ridge_y, H):
                # Snow near top, rock below
                snow_frac = max(0.0, min(1.0, (y - ridge_y) / max(1, H * 0.12)))
                col = lerp_color(snow_col + (255,), base_col + (255,), snow_frac)

                # Atmospheric fade toward bottom edge
                fade = 1.0 - max(0.0, (y - H * 0.7) / (H * 0.3))
                alpha = int(opacity * 255 * max(0.1, fade))

                # Subtle shading noise
                n = smooth_noise(x / 80.0, y / 80.0, seed=seed) * 0.18 - 0.09
                r = max(0, min(255, col[0] + int(n * 40)))
                g = max(0, min(255, col[1] + int(n * 35)))
                b = max(0, min(255, col[2] + int(n * 30)))

                cur = img.getpixel((x, y))
                # Alpha composite
                src_a = alpha / 255.0
                dst_a = cur[3] / 255.0
                out_a = src_a + dst_a * (1 - src_a)
                if out_a > 0:
                    nr = int((r * src_a + cur[0] * dst_a * (1 - src_a)) / out_a)
                    ng = int((g * src_a + cur[1] * dst_a * (1 - src_a)) / out_a)
                    nb = int((b * src_a + cur[2] * dst_a * (1 - src_a)) / out_a)
                    img.putpixel((x, y), (nr, ng, nb, int(out_a * 255)))

    img = img.filter(ImageFilter.GaussianBlur(1.5))
    path = os.path.join(OUT, "mountains_far.png")
    img.save(path)
    print(f"  Saved {path}")


def build_mountains_mid() -> None:
    W, H = 4096, 512
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    # Larger, more detailed mid-range mountains — two layers
    layers = [
        (16, 40, 0.05, 0.55, (75, 80, 85),   (215, 225, 235), 0.75),
        (12, 50, 0.08, 0.65, (58, 65, 72),   (220, 230, 240), 0.90),
    ]

    for peaks, seed, min_h, max_h, base_col, snow_col, opacity in layers:
        profile = _mountain_profile(W, H, peaks, seed, min_h, max_h)
        for x in range(W):
            ridge_y = profile[x]
            for y in range(ridge_y, H):
                depth = (y - ridge_y) / max(1, H - ridge_y)
                # Snow line: top 25% of each mountain is snow
                snow_frac = max(0.0, min(1.0, depth / 0.25))
                col = lerp_color(snow_col + (255,), base_col + (255,), snow_frac)

                # Add rock face detail via noise
                rock_n = fractal_noise(x / 120.0, y / 60.0, octaves=4, seed=seed + 5)
                shade = int((rock_n - 0.5) * 50)
                r = max(0, min(255, col[0] + shade))
                g = max(0, min(255, col[1] + shade))
                b = max(0, min(255, col[2] + shade))

                # Fade at bottom for atmosphere
                fade = 1.0 - max(0.0, (y - H * 0.75) / (H * 0.25)) * 0.6
                alpha = int(opacity * 255 * fade)

                cur = img.getpixel((x, y))
                src_a = alpha / 255.0
                dst_a = cur[3] / 255.0
                out_a = src_a + dst_a * (1 - src_a)
                if out_a > 0:
                    nr = int((r * src_a + cur[0] * dst_a * (1 - src_a)) / out_a)
                    ng = int((g * src_a + cur[1] * dst_a * (1 - src_a)) / out_a)
                    nb = int((b * src_a + cur[2] * dst_a * (1 - src_a)) / out_a)
                    img.putpixel((x, y), (nr, ng, nb, int(out_a * 255)))

    img = img.filter(ImageFilter.GaussianBlur(0.8))
    path = os.path.join(OUT, "mountains_mid.png")
    img.save(path)
    print(f"  Saved {path}")


# ---------------------------------------------------------------------------
# Glacier face
# ---------------------------------------------------------------------------

def build_glacier() -> None:
    W, H = 2048, 256
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    ICE_BASE  = (175, 215, 235)
    ICE_LIGHT = (215, 238, 250)
    ICE_DARK  = (110, 160, 195)
    ICE_BLUE  = (80, 140, 185)
    SNOW_TOP  = (235, 242, 248)

    for x in range(W):
        # Top profile: relatively flat glacier top
        top_n = smooth_noise(x / 300.0, 0, seed=60) * 30 - 15
        top_y = int(H * 0.15 + top_n)

        for y in range(top_y, H):
            if y < top_y + 20:
                # Snow cap
                col = lerp_color(SNOW_TOP, ICE_LIGHT, (y - top_y) / 20.0)
            else:
                depth = (y - top_y - 20) / max(1, H - top_y - 20)
                # Ice face with crevasse detail
                crack_n = fractal_noise(x / 40.0, y / 25.0, octaves=3, seed=61)
                if crack_n < 0.3:
                    col = ICE_BLUE
                elif crack_n < 0.5:
                    col = ICE_DARK
                else:
                    col = lerp_color(ICE_BASE, ICE_LIGHT, depth)

            # Fade at bottom
            fade = min(1.0, (H - y) / 40.0)
            alpha = int(220 * fade)
            # Vertical striations
            striation = smooth_noise(x / 15.0, y / 60.0, seed=62) * 20 - 10
            r = max(0, min(255, col[0] + int(striation)))
            g = max(0, min(255, col[1] + int(striation * 0.8)))
            b = max(0, min(255, col[2] + int(striation * 0.5)))
            img.putpixel((x, y), (r, g, b, alpha))

    img = img.filter(ImageFilter.GaussianBlur(0.5))
    path = os.path.join(OUT, "glacier.png")
    img.save(path)
    print(f"  Saved {path}")


# ---------------------------------------------------------------------------
# Forest far (dark treeline silhouette)
# ---------------------------------------------------------------------------

def build_forest_far() -> None:
    W, H = 4096, 320
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    PINE_DK    = (28, 48, 32, 255)
    PINE_MD    = (38, 65, 42, 255)
    PINE_LT    = (55, 90, 55, 255)
    SNOW_PINE  = (200, 215, 228, 200)

    rng = random.Random(99)
    tree_xs = sorted(rng.randint(-30, W + 30) for _ in range(280))
    tree_scales = [rng.uniform(0.4, 1.0) for _ in tree_xs]
    tree_ys = [int(H * rng.uniform(0.30, 0.62)) for _ in tree_xs]

    for tx, ty, ts in zip(tree_xs, tree_ys, tree_scales):
        tree_h = int(ts * 140)
        tree_w_base = int(ts * 50)

        # Draw spruce silhouette: 3 tiers
        for tier in range(3):
            tier_tip = ty - tree_h + int(tier * tree_h * 0.28)
            tier_bot = ty - tree_h + int((tier + 1) * tree_h * 0.36)
            tier_bot = min(tier_bot, ty)
            tier_hw = int(tree_w_base * (tier + 1) / 3.5)

            for y in range(tier_tip, tier_bot + 1):
                frac = (y - tier_tip) / max(1, tier_bot - tier_tip)
                w = int(tier_hw * frac)
                for x in range(tx - w, tx + w + 1):
                    if 0 <= x < W and 0 <= y < H:
                        # Pick shade based on x position (light from upper-left)
                        shade = PINE_LT if x < tx else PINE_DK
                        img.putpixel((x, y), shade)

                # Snow on branch tips
                snow_n = smooth_noise(tx / 80.0, y / 30.0, seed=100)
                if snow_n > 0.58 and tier < 2:
                    snow_w = max(1, int(w * 0.4))
                    for x in range(tx - w, tx - w + snow_w):
                        if 0 <= x < W and 0 <= y < H:
                            img.putpixel((x, y), SNOW_PINE)
                    for x in range(tx + w - snow_w, tx + w + 1):
                        if 0 <= x < W and 0 <= y < H:
                            img.putpixel((x, y), SNOW_PINE)

        # Fill below to ground with dark trunk mass
        for y in range(ty - int(tree_h * 0.15), ty + 1):
            for x in range(tx - 3, tx + 4):
                if 0 <= x < W and 0 <= y < H:
                    img.putpixel((x, y), PINE_DK)

    # Slight blur for atmospheric haze
    img = img.filter(ImageFilter.GaussianBlur(1.0))
    path = os.path.join(OUT, "forest_far.png")
    img.save(path)
    print(f"  Saved {path}")


# ---------------------------------------------------------------------------
# Individual spruce trees  (large, medium, small)
# ---------------------------------------------------------------------------

def _draw_spruce(img: Image.Image, cx: int, base_y: int, tree_h: int, seed: int) -> None:
    """Draw a detailed snow-laden spruce on img."""
    W, H = img.size
    rng = random.Random(seed)

    PINE_DK    = (22, 52, 25)
    PINE_MD    = (38, 75, 38)
    PINE_LT    = (60, 110, 55)
    PINE_HIGHLIGHT = (80, 135, 70)
    SNOW       = (228, 238, 248)
    SNOW_SH    = (180, 200, 222)
    TRUNK      = (72, 48, 28)
    TRUNK_DK   = (48, 30, 14)
    TRUNK_LT   = (105, 72, 40)

    tiers = 5
    trunk_h = int(tree_h * 0.18)
    crown_h = tree_h - trunk_h
    base_width = int(tree_h * 0.45)

    # Trunk
    trunk_top = base_y - trunk_h
    tw = max(3, int(base_width * 0.06))
    for y in range(trunk_top, base_y + 1):
        depth = (y - trunk_top) / max(1, trunk_h)
        for x in range(cx - tw, cx + tw + 1):
            if 0 <= x < W and 0 <= y < H:
                shade = TRUNK_LT if x == cx - tw else (TRUNK_DK if x == cx + tw else TRUNK)
                img.putpixel((x, y), shade + (255,))

    # Crown tiers from bottom to top
    for tier in range(tiers):
        t_frac = tier / tiers
        t_top_y = base_y - trunk_h - int(crown_h * (tier + 1) / tiers)
        t_bot_y = base_y - trunk_h - int(crown_h * tier / tiers)
        t_hw = int(base_width * (1.0 - t_frac * 0.65) * 0.5)

        for y in range(t_top_y, t_bot_y + 1):
            row_frac = (y - t_top_y) / max(1, t_bot_y - t_top_y)
            w = int(t_hw * (row_frac * 0.85 + 0.15))

            for x in range(cx - w, cx + w + 1):
                if 0 <= x < W and 0 <= y < H:
                    # Light source from upper-left
                    light = max(0.0, min(1.0, (cx - x) / max(1, w) * 0.5 + 0.5))
                    n = smooth_noise(x / 12.0, y / 8.0, seed=seed + tier)
                    if light > 0.6:
                        base_col = PINE_HIGHLIGHT if n > 0.6 else PINE_LT
                    elif light > 0.35:
                        base_col = PINE_MD
                    else:
                        base_col = PINE_DK

                    img.putpixel((x, y), base_col + (255,))

            # Snow on branch tips and near top
            snow_coverage = max(0.0, 1.0 - t_frac * 0.7)
            if snow_coverage > 0.2:
                # Snow blobs along branch width
                for bx in range(cx - w, cx + w + 1, max(1, w // 4)):
                    snow_h_local = int(rng.uniform(2, 5) * snow_coverage)
                    for dy in range(snow_h_local):
                        sx, sy = bx, y - dy
                        if 0 <= sx < W and 0 <= sy < H:
                            shade_col = SNOW_SH if dy == 0 else SNOW
                            img.putpixel((sx, sy), shade_col + (255,))

    # Snow cap at very tip
    tip_y = base_y - tree_h
    for dy in range(8):
        hw = max(0, 4 - dy)
        for x in range(cx - hw, cx + hw + 1):
            if 0 <= x < W and 0 <= tip_y + dy < H:
                img.putpixel((x, tip_y + dy), SNOW + (255,))


def build_spruce_large() -> None:
    W, H = 128, 256
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    _draw_spruce(img, W // 2, H - 1, int(H * 0.95), seed=1)
    path = os.path.join(OUT, "spruce_large.png")
    img.save(path)
    print(f"  Saved {path}")


def build_spruce_medium() -> None:
    W, H = 96, 192
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    _draw_spruce(img, W // 2, H - 1, int(H * 0.93), seed=2)
    path = os.path.join(OUT, "spruce_medium.png")
    img.save(path)
    print(f"  Saved {path}")


def build_spruce_small() -> None:
    W, H = 64, 128
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    _draw_spruce(img, W // 2, H - 1, int(H * 0.92), seed=3)
    path = os.path.join(OUT, "spruce_small.png")
    img.save(path)
    print(f"  Saved {path}")


# ---------------------------------------------------------------------------
# Winter birch
# ---------------------------------------------------------------------------

def build_birch_large() -> None:
    W, H = 96, 256
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    BARK_LT  = (220, 215, 208)
    BARK_MD  = (195, 188, 178)
    BARK_DK  = (80, 75, 70)
    BRANCH   = (140, 130, 118)
    SNOW_TIP = (228, 238, 248)

    cx = W // 2
    trunk_base = H - 2
    trunk_top = int(H * 0.28)
    trunk_w = 5

    rng = random.Random(55)

    # Main trunk
    for y in range(trunk_top, trunk_base + 1):
        depth = (y - trunk_top) / max(1, trunk_base - trunk_top)
        w = max(trunk_w - 1, int(trunk_w + depth * 2))
        for x in range(cx - w, cx + w + 1):
            if 0 <= x < W and 0 <= y < H:
                # Birch bark markings
                n = smooth_noise(x / 4.0, y / 6.0, seed=55)
                if n < 0.25:
                    col = BARK_DK
                elif n < 0.55:
                    col = BARK_MD
                else:
                    col = BARK_LT
                img.putpixel((x, y), col + (255,))

        # Horizontal bark lines
        if y % 14 == 0:
            for x in range(cx - w - 1, cx + w + 2):
                if 0 <= x < W:
                    img.putpixel((x, y), BARK_DK + (255,))

    # Branches radiating from upper trunk
    branch_starts = [(trunk_top + int((trunk_base - trunk_top) * f), side)
                     for f in [0.05, 0.12, 0.20, 0.30, 0.42, 0.55]
                     for side in [-1, 1]]

    for by, side in branch_starts:
        length = rng.randint(20, 45)
        angle = rng.uniform(0.3, 0.8) * side  # radians from horizontal, going up
        for i in range(length):
            bx = cx + int(side * i * math.cos(angle * (1 + i / length * 0.5)))
            branch_y = by - int(i * math.sin(angle * (1 + i / length * 0.3)))
            if 0 <= bx < W and 0 <= branch_y < H:
                img.putpixel((bx, branch_y), BRANCH + (255,))
                # Sub-branches
                if i > 12 and i % 8 == 0:
                    sub_len = rng.randint(6, 16)
                    sub_angle = rng.uniform(0.4, 0.9) * side
                    for j in range(sub_len):
                        sx = bx + int(side * j * math.cos(sub_angle))
                        sy = branch_y - int(j * math.sin(sub_angle))
                        if 0 <= sx < W and 0 <= sy < H:
                            img.putpixel((sx, sy), BRANCH + (255,))
                            if j == sub_len - 1:
                                # Snow tip
                                for dy in range(-1, 2):
                                    for dx in range(-1, 2):
                                        nx, ny = sx + dx, sy + dy
                                        if 0 <= nx < W and 0 <= ny < H:
                                            img.putpixel((nx, ny), SNOW_TIP + (200,))

    path = os.path.join(OUT, "birch_large.png")
    img.save(path)
    print(f"  Saved {path}")


# ---------------------------------------------------------------------------
# Snow ground texture (tileable)
# ---------------------------------------------------------------------------

def build_snow_ground() -> None:
    W, H = 512, 256
    img = Image.new("RGBA", (W, H))

    SNOW_BASE  = (228, 237, 248)
    SNOW_LIGHT = (245, 250, 255)
    SNOW_SH1   = (190, 208, 228)
    SNOW_SH2   = (160, 185, 215)
    ICE_PATCH  = (170, 205, 230)

    for y in range(H):
        for x in range(W):
            # Large-scale undulation (snowdrifts)
            drift = fractal_noise(x / 180.0, y / 90.0, octaves=4, seed=200)
            # Small-scale snow crystal texture
            crystal = smooth_noise(x / 8.0, y / 8.0, seed=201) * 0.15
            # Combine
            v = drift * 0.75 + crystal

            if v > 0.78:
                col = SNOW_LIGHT
            elif v > 0.60:
                col = SNOW_BASE
            elif v > 0.42:
                col = SNOW_SH1
            else:
                col = SNOW_SH2

            # Occasional ice patches
            ice_n = smooth_noise(x / 45.0, y / 45.0, seed=202)
            if ice_n > 0.78:
                col = ICE_PATCH

            # Sparkle: bright specular highlight points
            spec = smooth_noise(x / 2.5, y / 2.5, seed=203)
            if spec > 0.94:
                col = (255, 255, 255)

            img.putpixel((x, y), col + (255,))

    # Gentle blur to smooth out
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    path = os.path.join(OUT, "snow_ground.png")
    img.save(path)
    print(f"  Saved {path}")


# ---------------------------------------------------------------------------
# Rocky cliff with snow
# ---------------------------------------------------------------------------

def build_snow_cliff() -> None:
    W, H = 256, 256
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    ROCK_BASE  = (90, 82, 75)
    ROCK_LT    = (130, 118, 108)
    ROCK_DK    = (55, 50, 45)
    ROCK_VEIN  = (70, 65, 60)
    LICHEN     = (88, 105, 72)
    SNOW       = (228, 238, 248)
    SNOW_SH    = (185, 205, 225)

    for x in range(W):
        # Cliff profile: jagged left edge, solid on right
        profile_n = fractal_noise(x / 30.0, 0, octaves=3, seed=300)
        left_edge = int(profile_n * 60)

        for y in range(H):
            if x < left_edge:
                continue

            # Rock face texture
            n = fractal_noise(x / 25.0, y / 15.0, octaves=4, seed=301)
            vein = smooth_noise(x / 8.0, y / 20.0, seed=302)

            if vein < 0.2:
                col = ROCK_VEIN
            elif n > 0.65:
                col = ROCK_LT
            elif n < 0.35:
                col = ROCK_DK
            else:
                col = ROCK_BASE

            # Lichen patches on lower sections
            lichen_n = smooth_noise(x / 20.0, y / 20.0, seed=303)
            if lichen_n > 0.72 and y > H * 0.4:
                col = LICHEN

            # Snow on ledges (check if pixel above is empty → ledge top)
            above_edge = x < int(fractal_noise((x) / 30.0, 0, octaves=3, seed=300) * 60)
            snow_n = smooth_noise(x / 15.0, y / 10.0, seed=304)
            if snow_n > 0.65 and y < H * 0.7:
                col = SNOW if snow_n > 0.78 else SNOW_SH

            img.putpixel((x, y), col + (255,))

    img = img.filter(ImageFilter.GaussianBlur(0.4))
    path = os.path.join(OUT, "snow_cliff.png")
    img.save(path)
    print(f"  Saved {path}")


# ---------------------------------------------------------------------------
# Water surface texture
# ---------------------------------------------------------------------------

def build_water_surface() -> None:
    W, H = 512, 256
    img = Image.new("RGBA", (W, H))

    WATER_DK   = (28, 62, 110)
    WATER_MD   = (42, 88, 148)
    WATER_LT   = (65, 120, 175)
    WATER_FOAM = (180, 210, 235)
    SKY_REFL   = (120, 165, 205)
    GLINT      = (220, 240, 255)

    for y in range(H):
        for x in range(W):
            # Large-scale swell
            swell = fractal_noise(x / 120.0, y / 60.0, octaves=4, seed=400)
            # Ripple detail
            ripple = smooth_noise(x / 18.0, y / 12.0, seed=401) * 0.3
            # Sky reflection band near top
            refl = max(0.0, 1.0 - y / (H * 0.35))

            v = swell * 0.7 + ripple

            if v > 0.72:
                col = WATER_LT
            elif v > 0.55:
                col = WATER_MD
            else:
                col = WATER_DK

            # Sky reflection overlay near top
            if refl > 0.1:
                col = lerp_color(col, SKY_REFL, refl * 0.5)

            # Foam crests
            foam_n = smooth_noise(x / 25.0, y / 8.0, seed=402)
            if foam_n > 0.80 and swell > 0.65:
                col = WATER_FOAM

            # Specular glints
            glint_n = smooth_noise(x / 3.0, y / 4.0, seed=403)
            if glint_n > 0.93:
                col = GLINT

            img.putpixel((x, y), col + (255,))

    img = img.filter(ImageFilter.GaussianBlur(0.7))
    path = os.path.join(OUT, "water_surface.png")
    img.save(path)
    print(f"  Saved {path}")


def build_water_deep() -> None:
    W, H = 512, 256
    img = Image.new("RGBA", (W, H))

    DEEP1 = (18, 42, 85)
    DEEP2 = (25, 58, 105)
    DEEP3 = (35, 72, 125)
    LIGHT_SHAFT = (55, 95, 155)

    for y in range(H):
        for x in range(W):
            n = fractal_noise(x / 80.0, y / 40.0, octaves=3, seed=410)
            shaft = smooth_noise(x / 30.0, y / 80.0, seed=411)

            if n > 0.62:
                col = DEEP3
            elif n > 0.45:
                col = DEEP2
            else:
                col = DEEP1

            if shaft > 0.72:
                # Light shaft penetrating down from surface
                light_t = max(0.0, 1.0 - y / H) * (shaft - 0.72) / 0.28
                col = lerp_color(col, LIGHT_SHAFT, light_t * 0.6)

            img.putpixel((x, y), col + (255,))

    img = img.filter(ImageFilter.GaussianBlur(0.5))
    path = os.path.join(OUT, "water_deep.png")
    img.save(path)
    print(f"  Saved {path}")


# ---------------------------------------------------------------------------
# Coastal rocks
# ---------------------------------------------------------------------------

def build_coastal_rocks() -> None:
    W, H = 512, 256
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    ROCK_BASE = (80, 72, 66)
    ROCK_LT   = (118, 108, 98)
    ROCK_DK   = (48, 43, 38)
    WET_ROCK  = (55, 55, 62)
    BARNACLE  = (140, 135, 125)
    MOSS      = (72, 90, 58)
    SNOW      = (225, 235, 245)
    FOAM      = (200, 218, 232)

    rng = random.Random(77)

    rock_count = 12
    for ri in range(rock_count):
        rx = rng.randint(20, W - 40)
        ry = rng.randint(int(H * 0.35), int(H * 0.85))
        rw = rng.randint(30, 100)
        rh = rng.randint(20, 70)

        for y in range(ry - rh, ry + 1):
            if y < 0 or y >= H:
                continue
            depth = (y - (ry - rh)) / max(1, rh)
            w = int(rw * math.sqrt(max(0, 1.0 - (2 * depth - 1) ** 2)))
            for x in range(rx - w, rx + w + 1):
                if x < 0 or x >= W:
                    continue

                # Rock texture
                n = fractal_noise(x / 20.0, y / 15.0, octaves=3, seed=ri * 10 + 500)
                wet_n = smooth_noise(x / 10.0, y / 10.0, seed=ri * 10 + 501)

                if depth > 0.7:
                    col = WET_ROCK  # wet at waterline
                elif n > 0.65:
                    col = ROCK_LT
                elif n < 0.35:
                    col = ROCK_DK
                else:
                    col = ROCK_BASE

                # Barnacles on wet part
                if wet_n > 0.75 and depth > 0.5:
                    col = BARNACLE
                # Moss on sheltered areas
                elif wet_n < 0.2 and depth < 0.3:
                    col = MOSS

                # Snow on top
                snow_n = smooth_noise(x / 12.0, y / 8.0, seed=ri * 10 + 502)
                if depth < 0.18 and snow_n > 0.45:
                    col = SNOW

                img.putpixel((x, y), col + (255,))

        # Foam ring around rock base
        foam_y = ry + 2
        for x in range(rx - rw - 4, rx + rw + 5):
            if 0 <= x < W and 0 <= foam_y < H:
                img.putpixel((x, foam_y), FOAM + (160,))

    img = img.filter(ImageFilter.GaussianBlur(0.5))
    path = os.path.join(OUT, "coastal_rocks.png")
    img.save(path)
    print(f"  Saved {path}")


# ---------------------------------------------------------------------------
# Shore ice
# ---------------------------------------------------------------------------

def build_ice_shore() -> None:
    W, H = 512, 128
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    ICE_BASE  = (185, 218, 238)
    ICE_LT    = (218, 238, 252)
    ICE_DK    = (130, 175, 210)
    ICE_BLUE  = (100, 155, 200)
    SNOW_ICE  = (232, 242, 250)
    WATER_LT  = (65, 120, 175)

    for x in range(W):
        # Ice edge profile
        edge_n = fractal_noise(x / 40.0, 0, octaves=3, seed=600)
        edge_y = int(H * (0.4 + edge_n * 0.35))

        for y in range(H):
            if y < edge_y:
                # Ice slab above waterline
                n = fractal_noise(x / 30.0, y / 20.0, octaves=3, seed=601)
                crack = smooth_noise(x / 8.0, y / 12.0, seed=602)

                if crack < 0.15:
                    col = ICE_BLUE  # crack/crevasse
                elif n > 0.65:
                    col = ICE_LT
                elif n < 0.35:
                    col = ICE_DK
                else:
                    col = ICE_BASE

                # Snow dusting on top surface
                snow_n = smooth_noise(x / 10.0, y / 6.0, seed=603)
                if y < edge_y - 5 and snow_n > 0.55:
                    col = SNOW_ICE

                img.putpixel((x, y), col + (220,))
            else:
                # Water at the edge
                depth = (y - edge_y) / max(1, H - edge_y)
                water_n = smooth_noise(x / 20.0, y / 10.0, seed=604)
                col = lerp_color(WATER_LT, (28, 62, 110), depth * 0.8)
                alpha = int(180 * (1.0 - depth * 0.5))
                img.putpixel((x, y), col + (alpha,))

    img = img.filter(ImageFilter.GaussianBlur(0.5))
    path = os.path.join(OUT, "ice_shore.png")
    img.save(path)
    print(f"  Saved {path}")


# ---------------------------------------------------------------------------
# Fog wisp particle
# ---------------------------------------------------------------------------

def build_fog_wisp() -> None:
    W, H = 512, 256
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    cx, cy = W // 2, H // 2
    for y in range(H):
        for x in range(W):
            # Elliptical falloff
            dx = (x - cx) / (W * 0.48)
            dy = (y - cy) / (H * 0.45)
            dist = math.sqrt(dx * dx + dy * dy)
            if dist >= 1.0:
                continue

            # Wispy noise shape
            n = fractal_noise(x / 80.0, y / 40.0, octaves=3, seed=700)
            mask = max(0.0, 1.0 - dist) * (0.4 + n * 0.6)

            alpha = int(mask * 110)
            if alpha > 0:
                # Fog colour: slightly blue-white
                r = 210 + int(n * 20)
                g = 218 + int(n * 18)
                b = 230 + int(n * 15)
                img.putpixel((x, y), (min(255, r), min(255, g), min(255, b), alpha))

    img = img.filter(ImageFilter.GaussianBlur(6))
    path = os.path.join(OUT, "fog_wisp.png")
    img.save(path)
    print(f"  Saved {path}")


# ---------------------------------------------------------------------------
# Snowflake particle
# ---------------------------------------------------------------------------

def build_snowflake() -> None:
    W, H = 32, 32
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cx, cy = W // 2, H // 2

    SNOW = (230, 240, 255, 220)
    SNOW_CORE = (255, 255, 255, 255)

    # 6 arms
    for arm in range(6):
        angle = arm * math.pi / 3.0
        for r in range(12):
            x = cx + int(r * math.cos(angle))
            y = cy + int(r * math.sin(angle))
            if 0 <= x < W and 0 <= y < H:
                alpha = int(220 * (1.0 - r / 12.0))
                img.putpixel((x, y), (230, 240, 255, alpha))
            # Side branches at 1/3 and 2/3 length
            if r in (4, 7):
                for sign in (-1, 1):
                    branch_angle = angle + sign * math.pi / 6.0
                    for br in range(4):
                        bx = x + int(br * math.cos(branch_angle))
                        by = y + int(br * math.sin(branch_angle))
                        if 0 <= bx < W and 0 <= by < H:
                            alpha = int(180 * (1.0 - br / 4.0))
                            img.putpixel((bx, by), (230, 240, 255, alpha))

    # Core
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            if 0 <= cx + dx < W and 0 <= cy + dy < H:
                img.putpixel((cx + dx, cy + dy), SNOW_CORE)

    img = img.filter(ImageFilter.GaussianBlur(0.5))
    path = os.path.join(OUT, "snowflake.png")
    img.save(path)
    print(f"  Saved {path}")


# ---------------------------------------------------------------------------
# Cloud layer
# ---------------------------------------------------------------------------

def build_cloud_layer() -> None:
    W, H = 2048, 256
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    CLOUD_LT  = (240, 244, 250)
    CLOUD_MD  = (210, 220, 232)
    CLOUD_DK  = (170, 185, 205)
    CLOUD_SH  = (145, 160, 185)

    rng = random.Random(88)
    cloud_count = 14
    for _ in range(cloud_count):
        cx = rng.randint(-100, W + 100)
        cy = rng.randint(20, H - 30)
        # Each cloud is several overlapping ellipses
        blobs = rng.randint(4, 9)
        for b in range(blobs):
            bx = cx + rng.randint(-120, 120)
            by = cy + rng.randint(-25, 15)
            bw = rng.randint(80, 220)
            bh = rng.randint(30, 75)

            cloud_patch = Image.new("RGBA", (bw * 2, bh * 2), (0, 0, 0, 0))
            for py in range(bh * 2):
                for px in range(bw * 2):
                    dx = (px - bw) / bw
                    dy = (py - bh) / bh
                    dist = math.sqrt(dx * dx + dy * dy)
                    if dist >= 1.0:
                        continue
                    # Shade: top-lit
                    vert_t = 1.0 - (py / (bh * 2))
                    n = smooth_noise(px / 30.0, py / 20.0, seed=b * 10)
                    mask = (1.0 - dist * dist) * (0.5 + n * 0.5)
                    if vert_t > 0.6:
                        col = lerp_color(CLOUD_LT, CLOUD_MD, (1 - vert_t) / 0.4)
                    else:
                        col = lerp_color(CLOUD_MD, CLOUD_SH, (0.6 - vert_t) / 0.6)
                    alpha = int(mask * 140)
                    cloud_patch.putpixel((px, py), col + (alpha,))

            cloud_patch = cloud_patch.filter(ImageFilter.GaussianBlur(4))
            paste_x = bx - bw
            paste_y = by - bh
            # Clip to image
            if paste_x < W and paste_y < H and paste_x + bw * 2 > 0 and paste_y + bh * 2 > 0:
                try:
                    img.alpha_composite(cloud_patch, (max(0, paste_x), max(0, paste_y)))
                except Exception:
                    pass

    img = img.filter(ImageFilter.GaussianBlur(2))
    path = os.path.join(OUT, "cloud_layer.png")
    img.save(path)
    print(f"  Saved {path}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    print("Generating high-fidelity Alaskan environment assets…")
    print("  [1/17] Sky gradient…")
    build_sky_gradient()
    print("  [2/17] Aurora strip…")
    build_aurora_strip()
    print("  [3/17] Distant mountains…")
    build_mountains_far()
    print("  [4/17] Mid mountains…")
    build_mountains_mid()
    print("  [5/17] Glacier…")
    build_glacier()
    print("  [6/17] Distant forest…")
    build_forest_far()
    print("  [7/17] Large spruce…")
    build_spruce_large()
    print("  [8/17] Medium spruce…")
    build_spruce_medium()
    print("  [9/17] Small spruce…")
    build_spruce_small()
    print("  [10/17] Winter birch…")
    build_birch_large()
    print("  [11/17] Snow ground…")
    build_snow_ground()
    print("  [12/17] Snow cliff…")
    build_snow_cliff()
    print("  [13/17] Water surface…")
    build_water_surface()
    print("  [14/17] Water deep…")
    build_water_deep()
    print("  [15/17] Coastal rocks…")
    build_coastal_rocks()
    print("  [16/17] Shore ice…")
    build_ice_shore()
    print("  [17/17] Fog / snowflake / cloud…")
    build_fog_wisp()
    build_snowflake()
    build_cloud_layer()
    print("Done — all environment assets generated.")
