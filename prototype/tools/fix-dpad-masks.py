#!/usr/bin/env python3
"""Rebuild the four d-pad masks so a petal lights up whole.

The masks produced by `make-masks.py` cover only part of each d-pad petal: the little
arrow inside it, or a sliver of the rim. Hovering the up button then tinted a thin arc
and the shape was hard to find on the drawing.

Each petal is drawn as two separate strokes in the artwork, one inside the other:

    up     outline (280,295)-(360,392)   arrow (292,310)-(348,341)
    down   outline (280,415)-(360,512)   arrow (292,466)-(348,497)
    left   outline (207,364)-(309,444)   arrow (218,382)-(255,434)
    right  outline (332,364)-(434,444)   arrow (386,382)-(423,434)

The right outline reaches x=434. An earlier region scan stopped at 429 and clipped it,
which is why containment failed for that petal alone.

The new mask is the union of the two, so the whole petal is tinted and the large circle
that rings the d-pad is still excluded (its strokes are separate components that run
outside these boxes).

Python 3 standard library only. Run it from the repository root:

    python3 prototype/tools/fix-dpad-masks.py <labelled-diagram.bmp>

It writes `diagram-dpad<Direction>.png` next to the app's other masks and into the
prototype's mask folder, byte for byte the same file in both places.
"""

import struct
import sys
import zlib
from pathlib import Path

CANVAS = (1452, 940)

# Bounding boxes measured from the artwork's alpha channel. A component is kept when its
# own bounding box lies inside one of these, which is what separates a petal from the ring
# around it and from its neighbours.
PETALS = {
    "Up": [(280, 295, 360, 392), (292, 310, 348, 341)],
    "Down": [(280, 415, 360, 512), (292, 466, 348, 497)],
    "Left": [(207, 364, 309, 444), (218, 382, 255, 434)],
    "Right": [(332, 364, 434, 444), (386, 382, 423, 434)],
}


def read_bmp_alpha(path):
    data = Path(path).read_bytes()
    offset = struct.unpack_from("<I", data, 10)[0]
    width, height = struct.unpack_from("<ii", data, 18)
    stride = ((abs(width) * 4 + 3) // 4) * 4

    def alpha(x, y):
        row = y if height < 0 else abs(height) - 1 - y
        return data[offset + row * stride + x * 4 + 3]

    return alpha, abs(width), abs(height)


def components(alpha, width, height, min_pixels=80):
    seen = set()
    found = []
    for y in range(height):
        for x in range(width):
            if (x, y) in seen or alpha(x, y) <= 128:
                continue
            stack = [(x, y)]
            seen.add((x, y))
            points = []
            while stack:
                cx, cy = stack.pop()
                points.append((cx, cy))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = cx + dx, cy + dy
                        if (
                            0 <= nx < width
                            and 0 <= ny < height
                            and (nx, ny) not in seen
                            and alpha(nx, ny) > 128
                        ):
                            seen.add((nx, ny))
                            stack.append((nx, ny))
            if len(points) >= min_pixels:
                xs = [p[0] for p in points]
                ys = [p[1] for p in points]
                found.append((min(xs), min(ys), max(xs), max(ys), points))
    return found


def write_mask(path, width, height, pixels):
    """Write an RGBA PNG where `pixels` are opaque white and everything else is clear."""
    rows = []
    for y in range(height):
        row = bytearray(b"\x00")  # filter type 0
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
    found = components(alpha, width, height)

    targets = [
        Path("Sources/NaconDiagnostics/Resources/masks"),
        Path("prototype/assets/masks"),
    ]
    for direction, boxes in PETALS.items():
        pixels = set()
        for comp in found:
            box = comp[:4]
            if any(
                bx0 <= box[0] and bx1 >= box[2] and by0 <= box[1] and by1 >= box[3]
                for (bx0, by0, bx1, by1) in boxes
            ):
                pixels.update(comp[4])
        if not pixels:
            sys.exit(f"no components found for the {direction} petal")
        for target in targets:
            write_mask(target / f"diagram-dpad{direction}.png", width, height, pixels)
        xs = [p[0] for p in pixels]
        ys = [p[1] for p in pixels]
        print(f"dpad{direction}: {len(pixels)} px, bbox ({min(xs)},{min(ys)})-({max(xs)},{max(ys)})")


if __name__ == "__main__":
    main()
