#!/usr/bin/env python3
"""Generate the original starter icon as SVG and opaque 1024px RGB PNG using only Python's standard library."""
from pathlib import Path
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
SIZE = 1024
BACKGROUND = (20, 40, 65)
FOREGROUND = (238, 247, 255)
ACCENT = (65, 218, 181)
LEFT = [(384, 272), (448, 336), (288, 512), (448, 688), (384, 752), (160, 512)]
RIGHT = [(SIZE - x, y) for x, y in LEFT]


def inside(x, y, polygon):
    hit = False
    previous = polygon[-1]
    for current in polygon:
        ax, ay = previous; bx, by = current
        if (ay > y) != (by > y) and x < (bx - ax) * (y - ay) / (by - ay) + ax:
            hit = not hit
        previous = current
    return hit


def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)


def main():
    rows = bytearray()
    for y in range(SIZE):
        rows.append(0)
        for x in range(SIZE):
            color = ACCENT if (x - 512) ** 2 + (y - 512) ** 2 <= 44 ** 2 else (
                FOREGROUND if inside(x, y, LEFT) or inside(x, y, RIGHT) else BACKGROUND)
            rows.extend(color)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', SIZE, SIZE, 8, 2, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(rows, 9)) + chunk(b'IEND', b'')
    target = ROOT / 'StarterApp/StarterApp/Assets.xcassets/AppIcon.appiconset/StarterIcon.png'
    target.write_bytes(png)
    design = ROOT / 'design'; design.mkdir(exist_ok=True)
    polygons = ''.join('<polygon points="' + ' '.join(f'{x},{y}' for x, y in shape) + '" fill="#eef7ff"/>' for shape in (LEFT, RIGHT))
    (design / 'starter-icon.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024"><rect width="1024" height="1024" fill="#142841"/>' + polygons + '<circle cx="512" cy="512" r="44" fill="#41dab5"/></svg>\n')
    print('Generated opaque 1024px starter icon and matching editable SVG reference.')


if __name__ == '__main__': main()
