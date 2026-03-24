#!/usr/bin/env python3
"""
remove_bg.py — Strip white/near-white backgrounds from AI-generated sprites.

Usage:
    python3 tools/remove_bg.py <image.png> [<image2.png> ...]
    python3 tools/remove_bg.py <image.png> --out <output.png>

Strategy:
  1. Flood-fill from all four corners to find connected background pixels.
  2. Any pixel within FUZZ of white that is reachable is considered background.
  3. Alpha is set proportional to distance from white so anti-aliased edges
     fade smoothly rather than leaving a hard fringe.

Pixels inside the sprite that happen to be white-ish are preserved because
they are not reachable from the corners in the flood-fill.
"""

import sys
import argparse
from collections import deque
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.exit("ERROR: Pillow is required — pip install Pillow")

# How close to pure white (255,255,255) a pixel must be to count as background.
# Lower = more conservative; higher = removes more near-white pixels.
FUZZ: int = 30

# Minimum alpha given to a non-white foreground pixel that sits right next to
# a transparent background pixel (preserves anti-aliased edges).
EDGE_ALPHA_FLOOR: int = 20


def _is_near_white(r: int, g: int, b: int, fuzz: int = FUZZ) -> bool:
    return r >= 255 - fuzz and g >= 255 - fuzz and b >= 255 - fuzz


def _white_distance(r: int, g: int, b: int) -> float:
    """Euclidean distance from (r,g,b) to pure white (255,255,255)."""
    return ((255 - r) ** 2 + (255 - g) ** 2 + (255 - b) ** 2) ** 0.5


def remove_background(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    width, height = img.size
    pixels = img.load()

    # --- Flood-fill background detection from corners ---
    visited = [[False] * height for _ in range(width)]
    queue: deque = deque()

    def _enqueue(x: int, y: int) -> None:
        if 0 <= x < width and 0 <= y < height and not visited[x][y]:
            r, g, b, _ = pixels[x, y]
            if _is_near_white(r, g, b):
                visited[x][y] = True
                queue.append((x, y))

    # Seed from all four edges
    for x in range(width):
        _enqueue(x, 0)
        _enqueue(x, height - 1)
    for y in range(height):
        _enqueue(0, y)
        _enqueue(width - 1, y)

    while queue:
        cx, cy = queue.popleft()
        for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
            _enqueue(nx, ny)

    # --- Apply transparency ---
    # Max distance for a "pure white" pixel is 0; max possible distance is ~441.
    max_fuzz_dist = _white_distance(255 - FUZZ, 255 - FUZZ, 255 - FUZZ)

    for x in range(width):
        for y in range(height):
            r, g, b, a = pixels[x, y]
            if visited[x][y]:
                # Background: fully transparent, alpha proportional to
                # how white the pixel is (softer edges).
                dist = _white_distance(r, g, b)
                # Pixels very close to white → fully transparent.
                # Pixels at the fuzz boundary → keep a little alpha.
                alpha = int((dist / max_fuzz_dist) * EDGE_ALPHA_FLOOR)
                pixels[x, y] = (r, g, b, alpha)

    return img


def process_file(src: Path, dst: Path) -> None:
    img = Image.open(src)
    result = remove_background(img)
    result.save(dst, "PNG")
    print(f"Saved: {dst}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Remove white background from sprites.")
    parser.add_argument("images", nargs="+", type=Path, help="Input image file(s)")
    parser.add_argument("--out", type=Path, default=None,
                        help="Output path (only valid for single input file)")
    args = parser.parse_args()

    if args.out and len(args.images) > 1:
        sys.exit("ERROR: --out can only be used with a single input file")

    for src in args.images:
        if not src.exists():
            print(f"WARNING: file not found, skipping — {src}", file=sys.stderr)
            continue
        dst = args.out if args.out else src.with_suffix(".png")
        process_file(src, dst)


if __name__ == "__main__":
    main()
