"""Generates the channel icons and splash as small flat PNGs (stdlib only).

Design: near-black field with one tile outlined in amber, matching the UI.
Run: python3 scripts/make-images.py
"""
import struct
import zlib
from pathlib import Path

BG = (0x08, 0x08, 0x08)
TILE = (0x17, 0x17, 0x17)
AMBER = (0xF2, 0xB8, 0x4B)


def png(path, w, h, pixel):
    rows = bytearray()
    for y in range(h):
        rows.append(0)
        for x in range(w):
            rows.extend(pixel(x, y))

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

    data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    data += chunk(b"IDAT", zlib.compress(bytes(rows), 9)) + chunk(b"IEND", b"")
    Path(path).write_bytes(data)


def icon(w, h):
    tw, th = int(w * 0.46), int(h * 0.40)
    x0, y0 = (w - tw) // 2, (h - th) // 2
    ring = max(3, w // 90)

    def pixel(x, y):
        inside_ring = x0 - ring <= x < x0 + tw + ring and y0 - ring <= y < y0 + th + ring
        inside_tile = x0 <= x < x0 + tw and y0 <= y < y0 + th
        if inside_tile:
            return TILE
        if inside_ring:
            return AMBER
        return BG

    return pixel


root = Path(__file__).resolve().parent.parent / "images"
root.mkdir(exist_ok=True)
png(root / "icon_focus_hd.png", 290, 218, icon(290, 218))
png(root / "icon_focus_fhd.png", 540, 405, icon(540, 405))
png(root / "splash_fhd.png", 1920, 1080, lambda x, y: BG)
