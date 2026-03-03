#!/usr/bin/env python3
"""
Art asset generator for Dudes in Alaska.
Produces pixel-art PNGs for all game sprites.

Outputs:
  assets/sprites/player_sheet.png       128×192  (4 cols × 6 rows of 32×32)
  assets/sprites/campfire_sheet.png     128×32   (4 cols × 1 row  of 32×32)
  assets/sprites/tree.png               32×64    (single sprite)
  assets/sprites/stump.png              32×32    (single sprite)
  assets/sprites/tileset_terrain.png   256×256  (8×8 grid of 32×32 tiles)
  assets/sprites/ui_icons.png           80×16    (5 cols × 1 row of 16×16 icons)
"""

from PIL import Image, ImageDraw
import os

OUT = os.path.join(os.path.dirname(__file__), "sprites")
os.makedirs(OUT, exist_ok=True)

# ---------------------------------------------------------------------------
# Colour palette
# ---------------------------------------------------------------------------
T  = (0,   0,   0,   0)    # transparent

# Character colours
SKIN       = (222, 180, 145, 255)
SKIN_DARK  = (190, 148, 112, 255)
HAIR       = (55,  35,  15,  255)
EYE        = (40,  70,  130, 255)
MOUTH      = (180, 100,  80, 255)
PARKA      = (210,  85,  20, 255)   # orange parka
PARKA_DK   = (155,  55,   5, 255)
PARKA_LT   = (240, 130,  60, 255)
PANTS      = (45,  60, 100, 255)
PANTS_DK   = (28,  38,  72, 255)
BOOT       = (38,  22,  12, 255)
BOOT_LT    = (58,  38,  22, 255)
OUTLINE    = (18,  14,  10, 255)

# Tree colours
PINE_DK    = (25,  60,  25, 255)
PINE_MD    = (45,  95,  35, 255)
PINE_LT    = (70, 130,  50, 255)
PINE_SN    = (220, 230, 245, 255)   # snow on branches
TRUNK_BR   = (88,  58,  30, 255)
TRUNK_DK   = (58,  36,  16, 255)
STUMP_LT   = (120,  80,  40, 255)
STUMP_DK   = ( 80,  50,  20, 255)
STUMP_RING = (100,  65,  30, 255)

# Campfire colours
LOG_BR     = (100, 62, 30, 255)
LOG_DK     = ( 65, 38, 14, 255)
ASH        = (160, 155, 148, 255)
EMBER      = (255, 100,  20, 255)
FIRE_YL    = (255, 220,  50, 255)
FIRE_OR    = (255, 140,  25, 255)
FIRE_RD    = (210,  50,  10, 255)

# Terrain colours
GRASS      = ( 78, 132,  52, 255)
GRASS2     = ( 95, 155,  65, 255)
GRASS3     = ( 62, 112,  40, 255)
GRASS_DRY  = (120, 145,  65, 255)
DIRT       = (120,  88,  55, 255)
DIRT_DK    = ( 88,  62,  35, 255)
SNOW_WH    = (232, 240, 250, 255)
SNOW_SH    = (195, 210, 232, 255)
SNOW_BL    = (175, 195, 220, 255)
ICE        = (170, 210, 235, 255)
ICE_SH     = (140, 185, 215, 255)
ROCK       = (125, 122, 118, 255)
ROCK_DK    = ( 88,  85,  82, 255)
ROCK_LT    = (158, 155, 150, 255)
WATER      = ( 55,  95, 175, 255)
WATER_LT   = ( 80, 130, 205, 255)
WATER_DK   = ( 35,  70, 145, 255)
MUD        = ( 95,  72,  42, 255)
MUD_WET    = ( 75,  55,  28, 255)
GRAVEL     = (110, 108, 102, 255)
SAND       = (200, 185, 135, 255)

# UI colours
UI_HEART   = (210,  40,  40, 255)
UI_HUNGER  = (220, 160,  40, 255)
UI_WARM    = (240, 100,  20, 255)
UI_REST    = ( 80, 130, 220, 255)
UI_MORALE  = (170,  80, 210, 255)


# ---------------------------------------------------------------------------
# Helper: set pixel only if inside bounds
# ---------------------------------------------------------------------------
def px(img: Image.Image, x: int, y: int, c: tuple) -> None:
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c)


def rect(img: Image.Image, x0: int, y0: int, x1: int, y1: int, c: tuple) -> None:
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(img, x, y, c)


def hline(img: Image.Image, y: int, x0: int, x1: int, c: tuple) -> None:
    for x in range(x0, x1 + 1):
        px(img, x, y, c)


def vline(img: Image.Image, x: int, y0: int, y1: int, c: tuple) -> None:
    for y in range(y0, y1 + 1):
        px(img, x, y, c)


# ---------------------------------------------------------------------------
# Player sprites  (top-down, 32×32)
#
# Sheet layout (4 cols × 6 rows):
#   row 0 : idle_down   (frames 0-3)
#   row 1 : walk_down   (frames 0-3)
#   row 2 : idle_up     (frames 0-3)
#   row 3 : walk_up     (frames 0-3)
#   row 4 : idle_side   (frames 0-3)
#   row 5 : walk_side   (frames 0-3)
# ---------------------------------------------------------------------------

def _draw_head_front(img: Image.Image, cx: int, cy: int) -> None:
    """Draw front-facing head centred at cx, cy."""
    # Hair
    hair_xs = [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
    for x in hair_xs:
        px(img, cx - 5 + (x - 11), cy - 6, HAIR)
    for x in range(cx - 5, cx + 6):
        px(img, x, cy - 5, HAIR)
    for x in range(cx - 5, cx + 6):
        px(img, x, cy - 4, HAIR)

    # Face
    for y in range(cy - 3, cy + 4):
        for x in range(cx - 4, cx + 5):
            px(img, x, y, SKIN)
    # Outline
    for y in range(cy - 3, cy + 4):
        px(img, cx - 5, y, OUTLINE)
        px(img, cx + 5, y, OUTLINE)
    for x in range(cx - 4, cx + 5):
        px(img, x, cy + 4, OUTLINE)

    # Eyes
    px(img, cx - 2, cy - 1, EYE)
    px(img, cx + 2, cy - 1, EYE)
    px(img, cx - 2, cy - 2, OUTLINE)
    px(img, cx + 2, cy - 2, OUTLINE)

    # Nose
    px(img, cx, cy + 1, SKIN_DARK)

    # Mouth
    px(img, cx - 1, cy + 2, OUTLINE)
    px(img, cx,     cy + 2, OUTLINE)
    px(img, cx + 1, cy + 2, OUTLINE)

    # Ear dots
    px(img, cx - 5, cy - 1, SKIN)
    px(img, cx + 5, cy - 1, SKIN)


def _draw_head_back(img: Image.Image, cx: int, cy: int) -> None:
    """Draw back-facing head centred at cx, cy (hair only)."""
    for y in range(cy - 5, cy + 3):
        for x in range(cx - 5, cx + 6):
            px(img, x, y, HAIR)
    # Ear bumps
    px(img, cx - 5, cy,     SKIN)
    px(img, cx - 5, cy + 1, SKIN)
    px(img, cx + 5, cy,     SKIN)
    px(img, cx + 5, cy + 1, SKIN)
    # Neck
    rect(img, cx - 2, cy + 2, cx + 2, cy + 3, SKIN)
    # Outline
    for y in range(cy - 5, cy + 3):
        px(img, cx - 6, y, OUTLINE)
        px(img, cx + 6, y, OUTLINE)
    hline(img, cy + 3, cx - 5, cx + 5, OUTLINE)


def _draw_head_side(img: Image.Image, cx: int, cy: int, facing_right: bool) -> None:
    """Draw side-profile head."""
    d = 1 if facing_right else -1
    # Hair cap
    for y in range(cy - 5, cy - 1):
        for x in range(cx - 4 * d, cx + 5 * d, d):
            px(img, x, y, HAIR)
    # Face
    for y in range(cy - 2, cy + 4):
        for x in range(cx - 1 * d, cx + 5 * d, d):
            px(img, x, y, SKIN)
    # Eye
    px(img, cx + 3 * d, cy, EYE)
    # Nose bump
    px(img, cx + 5 * d, cy + 1, SKIN_DARK)
    # Mouth
    px(img, cx + 4 * d, cy + 2, OUTLINE)
    # Neck
    rect(img, cx - 1 * d, cy + 4, cx + 1 * d, cy + 5, SKIN)
    # Ear
    px(img, cx - 1 * d, cy, SKIN)


def _draw_body_front(img: Image.Image, cx: int, body_top: int, body_bot: int) -> None:
    """Draw parka body (front)."""
    # Main torso
    rect(img, cx - 5, body_top, cx + 5, body_bot, PARKA)
    # Outline sides
    vline(img, cx - 6, body_top, body_bot, OUTLINE)
    vline(img, cx + 6, body_top, body_bot, OUTLINE)
    # Chest highlight
    vline(img, cx, body_top, body_top + 3, PARKA_LT)
    # Zipper
    vline(img, cx, body_top + 4, body_bot, PARKA_DK)
    # Pocket lines
    hline(img, body_top + 5, cx - 5, cx - 2, PARKA_DK)
    hline(img, body_top + 5, cx + 2, cx + 5, PARKA_DK)


def _draw_body_back(img: Image.Image, cx: int, body_top: int, body_bot: int) -> None:
    """Draw parka body (back)."""
    rect(img, cx - 5, body_top, cx + 5, body_bot, PARKA_DK)
    vline(img, cx - 6, body_top, body_bot, OUTLINE)
    vline(img, cx + 6, body_top, body_bot, OUTLINE)
    # Seam
    vline(img, cx, body_top, body_bot, PARKA)


def _draw_body_side(img: Image.Image, cx: int, body_top: int, body_bot: int,
                    facing_right: bool) -> None:
    """Draw parka body (side profile)."""
    d = 1 if facing_right else -1
    rect(img, cx - 3 * d, body_top, cx + 4 * d, body_bot, PARKA)
    # Front edge highlight
    vline(img, cx + 4 * d, body_top, body_bot, PARKA_LT)
    # Back edge dark
    vline(img, cx - 3 * d, body_top, body_bot, PARKA_DK)
    # Outline
    vline(img, cx - 4 * d, body_top, body_bot, OUTLINE)
    vline(img, cx + 5 * d, body_top, body_bot, OUTLINE)


def _draw_arms_front(img: Image.Image, cx: int, arm_top: int, arm_bot: int,
                     swing: int = 0) -> None:
    """Draw front-view arms. swing shifts arm endpoints up/down."""
    # Left arm
    rect(img, cx - 8, arm_top + swing, cx - 6, arm_bot + swing, PARKA)
    vline(img, cx - 9, arm_top + swing, arm_bot + swing, OUTLINE)
    # Right arm
    rect(img, cx + 6, arm_top - swing, cx + 8, arm_bot - swing, PARKA)
    vline(img, cx + 9, arm_top - swing, arm_bot - swing, OUTLINE)
    # Gloves
    rect(img, cx - 8, arm_bot + swing + 1, cx - 6, arm_bot + swing + 2, PANTS_DK)
    rect(img, cx + 6, arm_bot - swing + 1, cx + 8, arm_bot - swing + 2, PANTS_DK)


def _draw_arms_back(img: Image.Image, cx: int, arm_top: int, arm_bot: int,
                    swing: int = 0) -> None:
    _draw_arms_front(img, cx, arm_top, arm_bot, -swing)


def _draw_legs_front(img: Image.Image, cx: int, leg_top: int,
                     left_off: int = 0, right_off: int = 0) -> None:
    """Draw front-view legs. offsets shift each foot up or down."""
    # Left leg
    rect(img, cx - 5, leg_top + left_off, cx - 2, leg_top + 5 + left_off, PANTS)
    vline(img, cx - 6, leg_top + left_off, leg_top + 5 + left_off, OUTLINE)
    # Right leg
    rect(img, cx + 2, leg_top + right_off, cx + 5, leg_top + 5 + right_off, PANTS)
    vline(img, cx + 6, leg_top + right_off, leg_top + 5 + right_off, OUTLINE)
    # Boots
    rect(img, cx - 6, leg_top + 6 + left_off,  cx - 1, leg_top + 8 + left_off,  BOOT)
    rect(img, cx + 1, leg_top + 6 + right_off, cx + 6, leg_top + 8 + right_off, BOOT)
    # Boot highlight
    hline(img, leg_top + 6 + left_off,  cx - 6, cx - 2, BOOT_LT)
    hline(img, leg_top + 6 + right_off, cx + 2, cx + 6, BOOT_LT)


def _draw_legs_back(img: Image.Image, cx: int, leg_top: int,
                    left_off: int = 0, right_off: int = 0) -> None:
    """Draw back-view legs (same geometry, darker pants)."""
    rect(img, cx - 5, leg_top + left_off,  cx - 2, leg_top + 5 + left_off,  PANTS_DK)
    vline(img, cx - 6, leg_top + left_off, leg_top + 5 + left_off, OUTLINE)
    rect(img, cx + 2, leg_top + right_off, cx + 5, leg_top + 5 + right_off, PANTS_DK)
    vline(img, cx + 6, leg_top + right_off, leg_top + 5 + right_off, OUTLINE)
    rect(img, cx - 6, leg_top + 6 + left_off,  cx - 1, leg_top + 8 + left_off,  BOOT)
    rect(img, cx + 1, leg_top + 6 + right_off, cx + 6, leg_top + 8 + right_off, BOOT)
    hline(img, leg_top + 6 + left_off,  cx - 6, cx - 2, BOOT_LT)
    hline(img, leg_top + 6 + right_off, cx + 2, cx + 6, BOOT_LT)


def _draw_legs_side(img: Image.Image, cx: int, leg_top: int,
                    front_off: int = 0, back_off: int = 0,
                    facing_right: bool = True) -> None:
    d = 1 if facing_right else -1
    # front leg (closer to viewer)
    rect(img, cx + 1 * d, leg_top + front_off, cx + 4 * d, leg_top + 5 + front_off, PANTS)
    vline(img, cx + 5 * d, leg_top + front_off, leg_top + 5 + front_off, OUTLINE)
    rect(img, cx + 1 * d, leg_top + 6 + front_off, cx + 5 * d, leg_top + 8 + front_off, BOOT)
    hline(img, leg_top + 6 + front_off, cx + 1 * d, cx + 5 * d, BOOT_LT)
    # back leg
    rect(img, cx - 3 * d, leg_top + back_off, cx,     leg_top + 5 + back_off, PANTS_DK)
    rect(img, cx - 4 * d, leg_top + 6 + back_off, cx, leg_top + 8 + back_off, BOOT)


def make_player_frame(direction: str, frame: int, walking: bool) -> Image.Image:
    """
    direction: 'down' | 'up' | 'side'
    frame:     0-3 (animation frame index)
    walking:   True = walk cycle, False = idle
    """
    img = Image.new("RGBA", (32, 32), T)
    cx = 15   # horizontal centre of sprite

    # Animation timing: frames 0,2 are neutral; 1,3 are stride extremes
    stride = (frame % 2) * 2 - 1 if walking else 0  # -1 or +1
    bob    = 1 if (walking and frame % 2 == 1) else 0
    arm_sw = 2 * stride if walking else 0

    if direction == "down":
        head_cy   = 7  - bob
        body_top  = head_cy + 6
        body_bot  = body_top + 9
        arm_top   = body_top + 1
        arm_bot   = arm_top  + 5
        leg_top   = body_bot + 1
        left_off  =  stride if walking else 0
        right_off = -stride if walking else 0

        _draw_body_front(img, cx, body_top, body_bot)
        _draw_arms_front(img, cx, arm_top, arm_bot, arm_sw)
        _draw_legs_front(img, cx, leg_top, left_off, right_off)
        _draw_head_front(img, cx, head_cy)

    elif direction == "up":
        head_cy   = 7  - bob
        body_top  = head_cy + 5
        body_bot  = body_top + 9
        arm_top   = body_top + 1
        arm_bot   = arm_top  + 5
        leg_top   = body_bot + 1
        left_off  =  stride if walking else 0
        right_off = -stride if walking else 0

        _draw_body_back(img, cx, body_top, body_bot)
        _draw_arms_back(img, cx, arm_top, arm_bot, arm_sw)
        _draw_legs_back(img, cx, leg_top, left_off, right_off)
        _draw_head_back(img, cx, head_cy)

    elif direction == "side":
        head_cy   = 7  - bob
        body_top  = head_cy + 5
        body_bot  = body_top + 9
        arm_top   = body_top + 1
        arm_bot   = arm_top  + 5
        leg_top   = body_bot + 1
        front_off =  stride if walking else 0
        back_off  = -stride if walking else 0

        _draw_body_side(img, cx, body_top, body_bot, True)
        _draw_legs_side(img, cx, leg_top, front_off, back_off, True)
        _draw_head_side(img, cx, head_cy, True)

        # Single arm visible (forward-ish)
        if walking:
            arm_x = cx + 5
            rect(img, arm_x, arm_top + arm_sw, arm_x + 2, arm_bot + arm_sw, PARKA)
            rect(img, arm_x, arm_bot + arm_sw + 1, arm_x + 2, arm_bot + arm_sw + 2, PANTS_DK)

    return img


def build_player_sheet() -> None:
    W, H = 128, 192   # 4 cols × 6 rows of 32×32
    sheet = Image.new("RGBA", (W, H), T)

    # (row, direction, walking)
    rows = [
        (0, "down",  False),   # idle_down
        (1, "down",  True ),   # walk_down
        (2, "up",    False),   # idle_up
        (3, "up",    True ),   # walk_up
        (4, "side",  False),   # idle_side
        (5, "side",  True ),   # walk_side
    ]

    for row, direction, walking in rows:
        for col in range(4):
            frame_img = make_player_frame(direction, col, walking)
            sheet.paste(frame_img, (col * 32, row * 32))

    path = os.path.join(OUT, "player_sheet.png")
    sheet.save(path)
    print(f"  Saved {path}")


# ---------------------------------------------------------------------------
# Campfire sprite sheet  (128×32, 4 frames of 32×32)
# ---------------------------------------------------------------------------

def make_campfire_frame(frame: int) -> Image.Image:
    img = Image.new("RGBA", (32, 32), T)

    # Ash base
    rect(img, 8, 26, 23, 29, ASH)

    # Logs (X shape)
    # Log 1 (diagonal \)
    for i in range(12):
        px(img, 8  + i, 24 - i // 3, LOG_BR)
        px(img, 9  + i, 24 - i // 3, LOG_BR)
    # Log 2 (diagonal /)
    for i in range(12):
        px(img, 23 - i, 24 - i // 3, LOG_DK)
        px(img, 22 - i, 24 - i // 3, LOG_DK)

    # Embers
    for ex, ey in [(14,22),(16,21),(18,22),(15,23),(17,23)]:
        px(img, ex, ey, EMBER)

    # Flame — grows and shifts each frame
    heights = [10, 12, 11, 9]
    lean    = [0,  1,  0, -1]
    h = heights[frame]
    l = lean[frame]

    flame_base_y = 21
    flame_cx     = 15 + l

    # Core flame (bright yellow)
    for y in range(flame_base_y - h + 3, flame_base_y + 1):
        width = max(1, int(3 * (flame_base_y - y + 1) / (h // 2)))
        hline(img, y, flame_cx - width, flame_cx + width, FIRE_YL)

    # Mid flame (orange)
    for y in range(flame_base_y - h // 2, flame_base_y + 1):
        width = max(1, int(5 * (flame_base_y - y + 1) / h))
        hline(img, y, flame_cx - width + 1, flame_cx + width - 1, FIRE_OR)

    # Outer flame (red)
    for y in range(flame_base_y - h // 3, flame_base_y + 1):
        width = max(0, int(4 * (flame_base_y - y + 1) / (h // 3)))
        if width > 0:
            hline(img, y, flame_cx - width + 2, flame_cx + width - 2, FIRE_RD)

    # Tip flicker
    if frame in (1, 2):
        px(img, flame_cx + l, flame_base_y - h + 2, FIRE_YL)

    return img


def build_campfire_sheet() -> None:
    W, H = 128, 32
    sheet = Image.new("RGBA", (W, H), T)
    for col in range(4):
        f = make_campfire_frame(col)
        sheet.paste(f, (col * 32, 0))
    path = os.path.join(OUT, "campfire_sheet.png")
    sheet.save(path)
    print(f"  Saved {path}")


# ---------------------------------------------------------------------------
# Tree sprite  (32×64)
# ---------------------------------------------------------------------------

def build_tree() -> None:
    img = Image.new("RGBA", (32, 64), T)

    # Trunk (bottom third)
    trunk_top = 45
    for y in range(trunk_top, 64):
        for x in range(12, 20):
            img.putpixel((x, y), TRUNK_BR)
        img.putpixel((12, y), TRUNK_DK)
        img.putpixel((19, y), TRUNK_DK)
    # Trunk outline
    vline(img, 11, trunk_top, 63, OUTLINE)
    vline(img, 20, trunk_top, 63, OUTLINE)
    hline(img, 63, 11, 20, OUTLINE)

    # Three layered triangular tiers of foliage (Alaskan spruce)
    tiers = [
        # (tip_y, half_width_bot, bot_y, colour)
        ( 2, 8, 18, PINE_MD),   # top tier
        (12, 11, 28, PINE_DK),  # mid tier
        (24, 14, 44, PINE_MD),  # bottom tier
    ]
    for tip_y, hw, bot_y, base_col in tiers:
        height = bot_y - tip_y
        for y in range(tip_y, bot_y + 1):
            frac = (y - tip_y) / height
            w = int(hw * frac)
            for x in range(16 - w, 16 + w + 1):
                if 0 <= x < 32:
                    # alternating rows for texture
                    c = PINE_LT if (x + y) % 3 == 0 else base_col
                    img.putpixel((x, y), c)

    # Snow patches on branches (top two tiers)
    for tier_bot, tier_tip in [(18, 2), (28, 12)]:
        for y in range(tier_tip, tier_bot, 3):
            frac = (y - tier_tip) / (tier_bot - tier_tip) if tier_bot != tier_tip else 0
            hw = int(10 * frac)
            for x in range(16 - hw, 16 + hw + 1, 2):
                if 0 <= x < 32:
                    img.putpixel((x, y), PINE_SN)

    # Outline around crown
    for y in range(2, 45):
        for x in range(32):
            if img.getpixel((x, y))[3] > 0:
                for dx, dy in [(-1,0),(1,0),(0,-1),(0,1)]:
                    nx, ny = x+dx, y+dy
                    if 0 <= nx < 32 and 0 <= ny < 64:
                        if img.getpixel((nx, ny))[3] == 0:
                            img.putpixel((nx, ny), OUTLINE)

    path = os.path.join(OUT, "tree.png")
    img.save(path)
    print(f"  Saved {path}")


# ---------------------------------------------------------------------------
# Stump sprite  (32×32)
# ---------------------------------------------------------------------------

def build_stump() -> None:
    img = Image.new("RGBA", (32, 32), T)

    # Main stump body
    rect(img, 10, 12, 21, 28, STUMP_DK)
    rect(img, 11, 12, 20, 27, STUMP_LT)

    # Growth rings on top
    rect(img, 10, 10, 21, 13, STUMP_LT)   # top surface
    rect(img, 11, 10, 20, 12, STUMP_DK)
    for rx in [14, 16]:
        px(img, rx, 11, STUMP_RING)
    rect(img, 13, 11, 18, 11, STUMP_RING) # outer ring

    # Outline
    for y in range(10, 29):
        px(img, 9,  y, OUTLINE)
        px(img, 22, y, OUTLINE)
    hline(img, 9,  9, 22, OUTLINE)
    hline(img, 28, 9, 22, OUTLINE)

    # Bark texture lines
    for y in range(14, 28, 3):
        hline(img, y, 12, 19, STUMP_DK)

    # Sap drop
    px(img, 13, 20, (210, 170, 60, 200))
    px(img, 13, 21, (210, 170, 60, 200))

    path = os.path.join(OUT, "stump.png")
    img.save(path)
    print(f"  Saved {path}")


# ---------------------------------------------------------------------------
# Terrain tileset  (256×256 = 8×8 grid of 32×32 tiles)
#
# Tile index (row, col):
#   (0,0) grass_plain      (0,1) grass_rocky     (0,2) grass_flowers
#   (0,3) dirt_path        (0,4) dirt_mud         (0,5) rock_floor
#   (0,6) gravel           (0,7) sand
#   (1,0) snow_plain       (1,1) snow_footprint   (1,2) snow_deep
#   (1,3) ice_plain        (1,4) ice_cracked      (1,5) ice_dark
#   (1,6) frozen_dirt      (1,7) frozen_mud
#   (2,0) water_shallow    (2,1) water_deep       (2,2) water_ripple
#   (2,3) water_frozen_edge (2,4) river_bed       (2,5) waterfall
#   (2,6) pond_center      (2,7) mud_wet
#   (3,0)-(7,7): transition/border tiles (fill with base colours for now)
# ---------------------------------------------------------------------------

def _noise(x: int, y: int, seed: int = 0) -> float:
    """Cheap deterministic pseudo-random float 0..1 from pixel coords."""
    v = (x * 73856093) ^ (y * 19349663) ^ (seed * 83492791)
    v = (v ^ (v >> 16)) & 0xFFFFFF
    return v / 0xFFFFFF


def _vary(base: tuple, x: int, y: int, seed: int, amount: int = 12) -> tuple:
    """Vary a colour slightly based on position."""
    n = _noise(x, y, seed)
    d = int((n - 0.5) * 2 * amount)
    r, g, b, a = base
    return (
        max(0, min(255, r + d)),
        max(0, min(255, g + d)),
        max(0, min(255, b + d)),
        a
    )


def tile_grass(seed: int = 0) -> Image.Image:
    img = Image.new("RGBA", (32, 32), GRASS)
    for y in range(32):
        for x in range(32):
            img.putpixel((x, y), _vary(GRASS, x, y, seed, 14))
    # Blade hints
    for _ in range(12):
        bx = int(_noise(_, 99, seed) * 30)
        by = int(_noise(99, _, seed) * 30)
        img.putpixel((bx, by), GRASS2)
    return img


def tile_grass_rocky(seed: int = 1) -> Image.Image:
    img = tile_grass(seed)
    # Scattered pebbles
    for i in range(6):
        rx = int(_noise(i, 10, seed) * 28) + 1
        ry = int(_noise(10, i, seed) * 28) + 1
        rect(img, rx, ry, rx+1, ry+1, ROCK)
    return img


def tile_grass_flowers(seed: int = 2) -> Image.Image:
    img = tile_grass(seed)
    flowers = [(5,5),(12,8),(20,4),(8,18),(25,22),(14,25),(3,28)]
    cols = [(255,220,50,255),(255,100,100,255),(200,255,100,255)]
    for i,(fx,fy) in enumerate(flowers):
        c = cols[i % len(cols)]
        px(img, fx, fy, c)
        for dx,dy in [(-1,0),(1,0),(0,-1),(0,1)]:
            px(img, fx+dx, fy+dy, c)
    return img


def tile_dirt(seed: int = 3) -> Image.Image:
    img = Image.new("RGBA", (32, 32), DIRT)
    for y in range(32):
        for x in range(32):
            img.putpixel((x, y), _vary(DIRT, x, y, seed, 16))
    return img


def tile_mud(seed: int = 4) -> Image.Image:
    img = Image.new("RGBA", (32, 32), MUD)
    for y in range(32):
        for x in range(32):
            c = MUD_WET if _noise(x, y, seed) < 0.35 else MUD
            img.putpixel((x, y), c)
    return img


def tile_rock(seed: int = 5) -> Image.Image:
    img = Image.new("RGBA", (32, 32), ROCK)
    for y in range(32):
        for x in range(32):
            img.putpixel((x, y), _vary(ROCK, x, y, seed, 18))
    # Cracks
    for cy in [10, 22]:
        hline(img, cy, 4, 12, ROCK_DK)
    vline(img, 20, 8, 20, ROCK_DK)
    return img


def tile_gravel(seed: int = 6) -> Image.Image:
    img = Image.new("RGBA", (32, 32), GRAVEL)
    for y in range(32):
        for x in range(32):
            n = _noise(x, y, seed)
            c = ROCK_DK if n < 0.25 else (ROCK_LT if n > 0.75 else GRAVEL)
            img.putpixel((x, y), c)
    return img


def tile_sand(seed: int = 7) -> Image.Image:
    img = Image.new("RGBA", (32, 32), SAND)
    for y in range(32):
        for x in range(32):
            img.putpixel((x, y), _vary(SAND, x, y, seed, 20))
    return img


def tile_snow(seed: int = 8) -> Image.Image:
    img = Image.new("RGBA", (32, 32), SNOW_WH)
    for y in range(32):
        for x in range(32):
            n = _noise(x, y, seed)
            c = SNOW_SH if n < 0.3 else SNOW_WH
            img.putpixel((x, y), c)
    return img


def tile_snow_footprint(seed: int = 9) -> Image.Image:
    img = tile_snow(seed)
    # Boot prints
    boots = [(8,6),(10,14),(20,10),(22,20)]
    for bx, by in boots:
        rect(img, bx, by, bx+3, by+5, SNOW_BL)
    return img


def tile_snow_deep(seed: int = 10) -> Image.Image:
    img = Image.new("RGBA", (32, 32), SNOW_WH)
    for y in range(32):
        for x in range(32):
            n = _noise(x, y, seed)
            c = SNOW_WH if n > 0.4 else SNOW_SH
            img.putpixel((x, y), c)
    # Drifts
    for dy in range(8, 24):
        img.putpixel((4 + dy//4, dy), SNOW_SH)
    return img


def tile_ice(seed: int = 11) -> Image.Image:
    img = Image.new("RGBA", (32, 32), ICE)
    for y in range(32):
        for x in range(32):
            img.putpixel((x, y), _vary(ICE, x, y, seed, 12))
    # Reflection highlight
    rect(img, 5, 5, 14, 7, (220, 235, 250, 255))
    return img


def tile_ice_cracked(seed: int = 12) -> Image.Image:
    img = tile_ice(seed)
    draw = ImageDraw.Draw(img)
    draw.line([(4,4),(15,18)], fill=ICE_SH, width=1)
    draw.line([(15,18),(28,22)], fill=ICE_SH, width=1)
    draw.line([(10,10),(20,8)], fill=ICE_SH, width=1)
    return img


def tile_ice_dark(seed: int = 13) -> Image.Image:
    img = Image.new("RGBA", (32, 32), ICE_SH)
    for y in range(32):
        for x in range(32):
            img.putpixel((x, y), _vary(ICE_SH, x, y, seed, 10))
    return img


def tile_frozen_dirt(seed: int = 14) -> Image.Image:
    img = tile_dirt(seed)
    # Frost overlay
    for y in range(32):
        for x in range(32):
            if _noise(x, y, seed + 100) > 0.6:
                r, g, b, a = img.getpixel((x, y))
                img.putpixel((x, y), (
                    min(255, r + 40),
                    min(255, g + 50),
                    min(255, b + 70),
                    a
                ))
    return img


def tile_frozen_mud(seed: int = 15) -> Image.Image:
    img = tile_mud(seed)
    for y in range(32):
        for x in range(32):
            if _noise(x, y, seed + 200) > 0.55:
                r, g, b, a = img.getpixel((x, y))
                img.putpixel((x, y), (
                    min(255, r + 30),
                    min(255, g + 40),
                    min(255, b + 60),
                    a
                ))
    return img


def tile_water_shallow(seed: int = 16) -> Image.Image:
    img = Image.new("RGBA", (32, 32), WATER_LT)
    for y in range(32):
        for x in range(32):
            img.putpixel((x, y), _vary(WATER_LT, x, y, seed, 14))
    # Ripples
    for ry in [6, 16, 26]:
        for rx in range(4, 28, 4):
            px(img, rx, ry, WATER_DK)
    return img


def tile_water_deep(seed: int = 17) -> Image.Image:
    img = Image.new("RGBA", (32, 32), WATER)
    for y in range(32):
        for x in range(32):
            img.putpixel((x, y), _vary(WATER, x, y, seed, 10))
    return img


def tile_water_ripple(seed: int = 18) -> Image.Image:
    img = tile_water_deep(seed)
    draw = ImageDraw.Draw(img)
    draw.ellipse([(8,8),(22,22)], outline=WATER_LT)
    draw.ellipse([(12,12),(18,18)], outline=WATER_LT)
    px(img, 15, 15, WATER_LT)
    return img


def tile_water_frozen_edge(seed: int = 19) -> Image.Image:
    img = tile_water_shallow(seed)
    # Ice border
    for x in range(32):
        for y in range(0, 6):
            if _noise(x, y, seed) > 0.3:
                img.putpixel((x, y), ICE)
    return img


def tile_river_bed(seed: int = 20) -> Image.Image:
    img = Image.new("RGBA", (32, 32), WATER_DK)
    for y in range(32):
        for x in range(32):
            img.putpixel((x, y), _vary(WATER_DK, x, y, seed, 8))
    for gx, gy in [(5,10),(14,20),(24,6),(8,26)]:
        rect(img, gx, gy, gx+2, gy+2, GRAVEL)
    return img


def tile_waterfall(seed: int = 21) -> Image.Image:
    img = Image.new("RGBA", (32, 32), WATER_LT)
    for y in range(32):
        for x in range(10, 22):
            img.putpixel((x, y), _vary(WATER, x, y + seed, seed, 8))
    # Foam
    for fy in range(0, 32, 4):
        for fx in range(10, 22, 2):
            img.putpixel((fx, fy), SNOW_WH)
    return img


def tile_pond_center(seed: int = 22) -> Image.Image:
    img = tile_water_deep(seed)
    # Reflection shimmer
    for i in range(8):
        rx = int(_noise(i, 77, seed) * 28) + 2
        ry = int(_noise(77, i, seed) * 28) + 2
        img.putpixel((rx, ry), WATER_LT)
    return img


def tile_mud_wet(seed: int = 23) -> Image.Image:
    img = Image.new("RGBA", (32, 32), MUD_WET)
    for y in range(32):
        for x in range(32):
            img.putpixel((x, y), _vary(MUD_WET, x, y, seed, 10))
    # Small puddles
    for px_c, py_c in [(8,8),(22,20)]:
        for iy in range(py_c-2, py_c+3):
            for ix in range(px_c-3, px_c+4):
                if 0<=ix<32 and 0<=iy<32:
                    img.putpixel((ix, iy), WATER)
    return img


def build_tileset() -> None:
    W, H = 256, 256
    sheet = Image.new("RGBA", (W, H), T)

    generators = [
        # Row 0
        tile_grass(0), tile_grass_rocky(1), tile_grass_flowers(2),
        tile_dirt(3), tile_mud(4), tile_rock(5), tile_gravel(6), tile_sand(7),
        # Row 1
        tile_snow(8), tile_snow_footprint(9), tile_snow_deep(10),
        tile_ice(11), tile_ice_cracked(12), tile_ice_dark(13),
        tile_frozen_dirt(14), tile_frozen_mud(15),
        # Row 2
        tile_water_shallow(16), tile_water_deep(17), tile_water_ripple(18),
        tile_water_frozen_edge(19), tile_river_bed(20),
        tile_waterfall(21), tile_pond_center(22), tile_mud_wet(23),
        # Rows 3-7: repeated base tiles for now (reserved for transitions)
        tile_grass(30), tile_grass_rocky(31), tile_snow(32), tile_ice(33),
        tile_dirt(34), tile_rock(35), tile_water_deep(36), tile_mud(37),

        tile_grass(40), tile_dirt(41), tile_snow(42), tile_rock(43),
        tile_ice(44), tile_water_shallow(45), tile_grass_flowers(46), tile_gravel(47),

        tile_grass_rocky(50), tile_snow_deep(51), tile_frozen_dirt(52), tile_frozen_mud(53),
        tile_mud_wet(54), tile_water_ripple(55), tile_river_bed(56), tile_sand(57),

        tile_rock(60), tile_gravel(61), tile_sand(62), tile_dirt(63),
        tile_grass(64), tile_snow(65), tile_ice_cracked(66), tile_ice_dark(67),

        tile_grass(70), tile_dirt(71), tile_mud(72), tile_rock(73),
        tile_snow_footprint(74), tile_frozen_dirt(75), tile_water_deep(76), tile_gravel(77),
    ]

    for i, tile_img in enumerate(generators):
        col = i % 8
        row = i // 8
        if row < 8:
            sheet.paste(tile_img, (col * 32, row * 32))

    path = os.path.join(OUT, "tileset_terrain.png")
    sheet.save(path)
    print(f"  Saved {path}")


# ---------------------------------------------------------------------------
# UI icons  (64×16, 4 icons of 16×16: health, hunger, warmth, rest)
# ---------------------------------------------------------------------------

def make_heart_icon() -> Image.Image:
    img = Image.new("RGBA", (16, 16), T)
    # Heart shape
    pixels = [
        (2,2),(3,2),(5,2),(6,2),
        (1,3),(2,3),(3,3),(4,3),(5,3),(6,3),(7,3),
        (1,4),(2,4),(3,4),(4,4),(5,4),(6,4),(7,4),
        (2,5),(3,5),(4,5),(5,5),(6,5),
        (3,6),(4,6),(5,6),
        (4,7),
    ]
    for (hx, hy) in pixels:
        px(img, hx, hy, UI_HEART)
        px(img, 8 + (7 - hx), hy, UI_HEART)  # mirror
    return img


def make_hunger_icon() -> Image.Image:
    img = Image.new("RGBA", (16, 16), T)
    # Fish silhouette
    # Body
    rect(img, 4, 5, 11, 10, UI_HUNGER)
    # Tail
    for dy in range(3):
        px(img, 12 + dy, 4 + dy, UI_HUNGER)
        px(img, 12 + dy, 11 - dy, UI_HUNGER)
    # Eye
    px(img, 4, 7, OUTLINE)
    return img


def make_warmth_icon() -> Image.Image:
    img = Image.new("RGBA", (16, 16), T)
    # Flame shape
    flame_pts = [
        (7,2),(8,2),
        (6,3),(7,3),(8,3),(9,3),
        (5,4),(6,4),(7,4),(8,4),(9,4),(10,4),
        (4,5),(5,5),(6,5),(7,5),(8,5),(9,5),(10,5),(11,5),
        (4,6),(5,6),(6,6),(7,6),(8,6),(9,6),(10,6),(11,6),
        (4,7),(5,7),(6,7),(7,7),(8,7),(9,7),(10,7),(11,7),
        (5,8),(6,8),(7,8),(8,8),(9,8),(10,8),
        (6,9),(7,9),(8,9),(9,9),
        (7,10),(8,10),
    ]
    for (fx, fy) in flame_pts:
        c = FIRE_YL if fy < 6 else (FIRE_OR if fy < 8 else FIRE_RD)
        px(img, fx, fy, c)
    return img


def make_rest_icon() -> Image.Image:
    img = Image.new("RGBA", (16, 16), T)
    # Moon crescent
    draw = ImageDraw.Draw(img)
    draw.ellipse([(2,2),(13,13)], fill=UI_REST)
    draw.ellipse([(5,2),(14,11)], fill=T)
    # Star
    px(img, 13, 4, FIRE_YL)
    px(img, 12, 2, FIRE_YL)
    px(img, 14, 6, FIRE_YL)
    return img


def make_morale_icon() -> Image.Image:
    img = Image.new("RGBA", (16, 16), T)
    draw = ImageDraw.Draw(img)
    # Circle outline (face)
    draw.ellipse([(1, 1), (14, 14)], outline=UI_MORALE)
    # Eyes (2×2 dots)
    px(img, 5, 5, UI_MORALE)
    px(img, 5, 6, UI_MORALE)
    px(img, 10, 5, UI_MORALE)
    px(img, 10, 6, UI_MORALE)
    # Smile arc
    for sx, sy in [(5, 10), (6, 11), (7, 12), (8, 12), (9, 11), (10, 10)]:
        px(img, sx, sy, UI_MORALE)
    return img


def build_ui_icons() -> None:
    W, H = 80, 16   # 5 icons of 16×16
    sheet = Image.new("RGBA", (W, H), T)
    icons = [
        make_heart_icon(),
        make_hunger_icon(),
        make_warmth_icon(),
        make_rest_icon(),
        make_morale_icon(),
    ]
    for i, icon in enumerate(icons):
        sheet.paste(icon, (i * 16, 0))
    path = os.path.join(OUT, "ui_icons.png")
    sheet.save(path)
    print(f"  Saved {path}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    print("Generating art assets for Dudes in Alaska…")
    build_player_sheet()
    build_campfire_sheet()
    build_tree()
    build_stump()
    build_tileset()
    build_ui_icons()
    print("Done.")
