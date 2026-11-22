#!/usr/bin/env python3
"""Generate the launcher icon set for Block Arena (no external dependencies).

Produces:
  icon.png                 512x512 rounded-square app icon
  icon_foreground.png      512x512 adaptive foreground (transparent, safe-zone)
  icon_background.png      512x512 adaptive background (gradient only)
"""

import math
import os
import struct
import zlib

SIZE = 512
OUT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

BG_TOP = (0.10, 0.17, 0.36)
BG_BOTTOM = (0.03, 0.05, 0.11)
GLOW = (0.18, 0.55, 0.72)

CYAN = (0.36, 0.92, 1.00)
SKIN = (0.90, 0.74, 0.57)
HAIR = (0.17, 0.13, 0.11)
SHIRT = (0.96, 0.45, 0.24)
DARK = (0.10, 0.11, 0.15)
WHITE = (0.98, 0.99, 1.00)


class Canvas:
    def __init__(self, size):
        self.size = size
        self.buf = bytearray(size * size * 4)

    def blend(self, x, y, rgb, alpha):
        if alpha <= 0.0 or x < 0 or y < 0 or x >= self.size or y >= self.size:
            return
        a = min(1.0, alpha)
        i = (y * self.size + x) * 4
        b = self.buf
        b[i] = int(b[i] * (1.0 - a) + rgb[0] * 255.0 * a)
        b[i + 1] = int(b[i + 1] * (1.0 - a) + rgb[1] * 255.0 * a)
        b[i + 2] = int(b[i + 2] * (1.0 - a) + rgb[2] * 255.0 * a)
        b[i + 3] = int(b[i + 3] * (1.0 - a) + 255.0 * a)

    def fill_gradient(self, top, bottom, glow=None, glow_pos=(0.5, 0.44)):
        for y in range(self.size):
            t = y / (self.size - 1)
            for x in range(self.size):
                c = [top[k] + (bottom[k] - top[k]) * t for k in range(3)]
                if glow:
                    dx = (x / (self.size - 1)) - glow_pos[0]
                    dy = (y / (self.size - 1)) - glow_pos[1]
                    d = math.sqrt(dx * dx + dy * dy)
                    f = max(0.0, 1.0 - d / 0.70) ** 2
                    for k in range(3):
                        c[k] += glow[k] * f
                self.blend(x, y, c, 1.0)

    def rounded_rect(self, cx, cy, hw, hh, radius, rgb, alpha=1.0):
        x0, x1 = int(cx - hw) - 2, int(cx + hw) + 3
        y0, y1 = int(cy - hh) - 2, int(cy + hh) + 3
        for y in range(max(0, y0), min(self.size, y1)):
            for x in range(max(0, x0), min(self.size, x1)):
                px, py = x + 0.5, y + 0.5
                qx = abs(px - cx) - hw + radius
                qy = abs(py - cy) - hh + radius
                sd = math.hypot(max(qx, 0.0), max(qy, 0.0)) + min(max(qx, qy), 0.0) - radius
                cov = min(1.0, max(0.0, 0.5 - sd))
                self.blend(x, y, rgb, cov * alpha)

    def ring(self, cx, cy, radius, thickness, rgb, alpha=1.0):
        outer = radius + thickness * 0.5
        inner = radius - thickness * 0.5
        x0, x1 = int(cx - outer) - 2, int(cx + outer) + 3
        y0, y1 = int(cy - outer) - 2, int(cy + outer) + 3
        for y in range(max(0, y0), min(self.size, y1)):
            for x in range(max(0, x0), min(self.size, x1)):
                d = math.hypot((x + 0.5) - cx, (y + 0.5) - cy)
                cov = min(1.0, max(0.0, 0.5 + (outer - d))) * min(1.0, max(0.0, 0.5 + (d - inner)))
                self.blend(x, y, rgb, cov * alpha)

    def save(self, path):
        raw = bytearray()
        stride = self.size * 4
        for y in range(self.size):
            raw.append(0)
            raw += self.buf[y * stride:(y + 1) * stride]

        def chunk(tag, data):
            return (struct.pack(">I", len(data)) + tag + data
                    + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

        png = b"\x89PNG\r\n\x1a\n"
        png += chunk(b"IHDR", struct.pack(">IIBBBBB", self.size, self.size, 8, 6, 0, 0, 0))
        png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        png += chunk(b"IEND", b"")
        with open(path, "wb") as f:
            f.write(png)
        print("wrote", path, len(png), "bytes")


def draw_crosshair(c, cx, cy, radius, scale=1.0):
    ring_t = 13.0 * scale
    c.ring(cx, cy, radius, ring_t, CYAN, 0.85)
    tick_len = 46.0 * scale
    tick_w = 15.0 * scale
    gap = radius + ring_t * 0.5
    for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
        tx = cx + dx * (gap + tick_len * 0.5)
        ty = cy + dy * (gap + tick_len * 0.5)
        c.rounded_rect(tx, ty, tick_w * 0.5 if dx == 0 else tick_len * 0.5,
                       tick_len * 0.5 if dx == 0 else tick_w * 0.5, 6.0 * scale, CYAN, 0.85)


def draw_avatar(c, cx, cy, scale=1.0):
    # Torso.
    c.rounded_rect(cx, cy + 86.0 * scale, 98.0 * scale, 66.0 * scale, 22.0 * scale, SHIRT)
    # Head.
    c.rounded_rect(cx, cy - 22.0 * scale, 78.0 * scale, 74.0 * scale, 22.0 * scale, SKIN)
    # Hair.
    c.rounded_rect(cx, cy - 80.0 * scale, 84.0 * scale, 28.0 * scale, 13.0 * scale, HAIR)
    # Eyes.
    c.rounded_rect(cx - 30.0 * scale, cy - 20.0 * scale, 14.0 * scale, 20.0 * scale, 5.0 * scale, DARK)
    c.rounded_rect(cx + 30.0 * scale, cy - 20.0 * scale, 14.0 * scale, 20.0 * scale, 5.0 * scale, DARK)
    # Gun poking out to the right.
    c.rounded_rect(cx + 112.0 * scale, cy + 66.0 * scale, 40.0 * scale, 13.0 * scale, 6.0 * scale, DARK)
    c.rounded_rect(cx + 84.0 * scale, cy + 80.0 * scale, 18.0 * scale, 24.0 * scale, 6.0 * scale, DARK)


def main():
    # ---- main icon: rounded square + crosshair + avatar
    grad = Canvas(SIZE)
    grad.fill_gradient(BG_TOP, BG_BOTTOM, glow=GLOW, glow_pos=(0.5, 0.42))

    mask = Canvas(SIZE)
    mask.rounded_rect(SIZE / 2, SIZE / 2, SIZE / 2 - 6, SIZE / 2 - 6, 112, (1, 1, 1))

    icon = Canvas(SIZE)
    for i in range(0, len(grad.buf), 4):
        a = mask.buf[i + 3] / 255.0
        for k in range(3):
            icon.buf[i + k] = int(grad.buf[i + k] * a)
        icon.buf[i + 3] = int(255 * a)

    draw_crosshair(icon, 256.0, 240.0, 178.0, 1.0)
    draw_avatar(icon, 256.0, 244.0, 1.0)
    icon.save(os.path.join(OUT_DIR, "icon.png"))

    # ---- adaptive foreground: same art, transparent, inside the safe zone
    fg = Canvas(SIZE)
    draw_crosshair(fg, 256.0, 250.0, 132.0, 0.74)
    draw_avatar(fg, 256.0, 256.0, 0.74)
    fg.save(os.path.join(OUT_DIR, "icon_foreground.png"))

    # ---- adaptive background
    bg = Canvas(SIZE)
    bg.fill_gradient(BG_TOP, BG_BOTTOM, glow=GLOW, glow_pos=(0.5, 0.42))
    bg.save(os.path.join(OUT_DIR, "icon_background.png"))


if __name__ == "__main__":
    main()
