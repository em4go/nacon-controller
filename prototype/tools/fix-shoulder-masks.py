#!/usr/bin/env python3
"""Rebuild the four shoulder masks so each one is the right button, whole.

Two defects, both visible on screen:

1. L1 and L2 were swapped. Each shoulder is drawn as two shapes, a dome behind and an
   ellipse in front; on the controller the front one is the bumper (L1) and the one behind
   it is the trigger (L2), so the ellipse is L1 and the dome is L2.
2. The front shape was only partly tinted: its mask covered the inner line and a sliver of
   the arc, which left most of the outline its normal colour.

The shapes are not separate components in the artwork (the dome, the ellipse and the body
outline all touch), so a mask cannot be cut by connectivity. It is cut by the box that
tightly contains the shape, which is why both boxes are written out here and why they must
be re-measured if the artwork ever changes.

Boxes, measured from the labelled diagram (1452 x 940):

    left  dome    (243, 70)-(415, 141)      left  ellipse  (236, 126)-(433, 183)
    right dome    (1037, 70)-(1209, 141)    right ellipse  (1019, 126)-(1216, 183)

The two boxes overlap by a few rows where the ellipse's top arc runs under the dome; those
pixels belong to both, which is correct at the joint.

Python 3 standard library only. Run it from the repository root:

    python3 prototype/tools/fix-shoulder-masks.py <labelled-diagram.bmp>
"""

import struct
import sys
import zlib
from pathlib import Path

CANVAS = (1452, 940)

# control name -> box, in artwork pixels
SHAPES = {
    # L1 is the front bumper: the ellipse.
    "leftBumper": (236, 126, 433, 183),
    "rightBumper": (1019, 126, 1216, 183),
    # L2 is the trigger behind it: the dome.
    "leftTrigger": (243, 70, 415, 141),
    "rightTrigger": (1037, 70, 1209, 141),
}

TARGETS = [
    Path("Sources/NaconDiagnostics/Resources/masks"),
    Path("prototype/assets/masks"),
]


def read_bmp_alpha(path):
    data = Path(path).read_bytes()
    offset = struct.unpack_from("<I", data, 10)[0]
    width, height = struct.unpack_from("<ii", data, 18)
    stride = ((abs(width) * 4 + 3) // 4) * 4

    def alpha(x, y):
        row = y if height < 0 else abs(height) - 1 - y
        return data[offset + row * stride + x * 4 + 3]

    return alpha, abs(width), abs(height)


def write_mask(path, width, height, pixels):
    rows = []
    for y in range(height):
        row = bytearray(b"\x00")
        for x in range(width):
            row += b"\xff\xff\xff\xff" if (x, y) in pixels else b"\x00\x00\x00\x00"
        rows.append(bytes(row))
    raw = zlib.compress(b"".join(rows), 9)

    def chunk(kind, payload):
        body = kind + payload
        return struct.pack(">I", len(payload)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", raw)
    png += chunk(b"IEND", b"")
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_bytes(png)


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    alpha, width, height = read_bmp_alpha(sys.argv[1])
    if (width, height) != CANVAS:
        sys.exit(f"unexpected canvas {width}x{height}")

    for control, (x0, y0, x1, y1) in SHAPES.items():
        pixels = {
            (x, y)
            for y in range(y0, y1 + 1)
            for x in range(x0, x1 + 1)
            if alpha(x, y) > 128
        }
        if not pixels:
            sys.exit(f"no pixels for {control}")
        for target in TARGETS:
            write_mask(target / f"diagram-{control}.png", width, height, pixels)
        xs = [p[0] for p in pixels]
        ys = [p[1] for p in pixels]
        print(f"{control:14s} {len(pixels):5d} px, bbox ({min(xs)},{min(ys)})-({max(xs)},{max(ys)})")


if __name__ == "__main__":
    main()
