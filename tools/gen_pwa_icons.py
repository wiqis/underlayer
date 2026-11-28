#!/usr/bin/env python3
"""Generate the two installable-web-app icons (pure stdlib, deterministic).

The icons are served by explicit same-origin routes from app/. They contain no
third-party URL and no tracking. Regenerate with: python tools/gen_pwa_icons.py
"""
import os
import struct
import zlib

OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "app")


def png_chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def make_icon(size: int) -> bytes:
    bg = (17, 34, 65)
    fg = (240, 245, 255)
    accent = (59, 130, 246)
    rows = []
    u_left = size // 5
    u_right = size - u_left
    u_top = size // 5
    u_bottom = size - size // 4
    stem = max(2, size // 16)
    for y in range(size):
        row = bytearray()
        for x in range(size):
            color = bg
            # A blocky "U": two vertical stems and a bottom bar.
            in_u = (
                (u_left <= x < u_left + stem and u_top <= y < u_bottom)
                or (u_right - stem <= x < u_right and u_top <= y < u_bottom)
                or (u_left <= x < u_right and u_bottom - stem <= y < u_bottom)
            )
            if in_u:
                color = fg
            # A small accent notch marks the open top of the U.
            if size // 2 - stem <= x < size // 2 + stem and u_top <= y < u_top + stem * 2:
                color = accent
            row.extend(color)
        rows.append(bytes(row))
    raw = b"".join(b"\x00" + row for row in rows)
    ihdr = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", ihdr)
        + png_chunk(b"IDAT", zlib.compress(raw, 9))
        + png_chunk(b"IEND", b"")
    )


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    for size in (192, 512):
        path = os.path.join(OUT_DIR, "icon-%d.png" % size)
        with open(path, "wb") as f:
            f.write(make_icon(size))
        print("wrote %s (%d bytes)" % (path, os.path.getsize(path)))


if __name__ == "__main__":
    main()
