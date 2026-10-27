#!/usr/bin/env python3
"""Generate one alpha mask per controller control from the Xelu PS4 line art.

The masks are written to prototype/assets/masks/<art>-<control>.png. The page tints
those pixels with CSS. Nothing here invents pixels: every mask is a copy of the
alpha channel of the original PNG, restricted to the region of one control.

Python 3 standard library only.
"""

from __future__ import annotations

import argparse
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
MASKS = ASSETS / "masks"

# Control regions in the 1452 x 940 image coordinate system. The positions come
# from Sources/NaconCore/PadLayout.swift and from connected-component analysis of
# the artwork (bounds of the rings, pills, sticks and shoulders).
CONTROLS = [
    # id, kind, region
    ("dpadUp", "dpad", ("flood", 320, 339)),
    ("dpadDown", "dpad", ("flood", 320, 468)),
    ("dpadLeft", "dpad", ("flood", 253, 404)),
    ("dpadRight", "dpad", ("flood", 388, 404)),
    ("buttonA", "face", ("circle", 1138, 491, 55)),
    ("buttonB", "face", ("circle", 1232, 404, 55)),
    ("buttonX", "face", ("circle", 1045, 404, 55)),
    ("buttonY", "face", ("circle", 1138, 317, 55)),
    ("leftBumper", "shoulder", ("shoulder", 230, 430, 70, 145)),
    ("leftTrigger", "shoulder", ("shoulder", 230, 430, 145, 180)),
    ("rightBumper", "shoulder", ("shoulder", 1022, 1222, 70, 145)),
    ("rightTrigger", "shoulder", ("shoulder", 1022, 1222, 145, 180)),
    ("back", "pill", ("rect", 430, 225, 493, 325)),
    ("start", "pill", ("rect", 965, 225, 1028, 325)),
    ("guide", "reserved", ("circle", 729, 570, 45)),
    ("leftThumb", "stick", ("circle", 522, 603, 60)),
    ("rightThumb", "stick", ("circle", 936, 603, 60)),
]


def read_png(path: Path) -> tuple[int, int, int, bytes]:
    """Decode a non-interlaced 8-bit PNG. Returns width, height, channels, pixels."""
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"not a PNG: {path}")
    pos = 8
    idat = b""
    width = height = bit_depth = color_type = None
    while pos < len(data):
        length = struct.unpack(">I", data[pos : pos + 4])[0]
        kind = data[pos + 4 : pos + 8]
        chunk = data[pos + 8 : pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            width, height, bit_depth, color_type, comp, filt, interlace = struct.unpack(
                ">IIBBBBB", chunk
            )
            if bit_depth != 8 or interlace != 0:
                raise ValueError(f"unsupported PNG encoding in {path}")
        elif kind == b"IDAT":
            idat += chunk
        elif kind == b"IEND":
            break
    if width is None or height is None or color_type is None:
        raise ValueError(f"no IHDR in {path}")
    channels = {0: 1, 2: 3, 4: 2, 6: 4}[color_type]
    raw = zlib.decompress(idat)
    stride = width * channels
    pixels = bytearray(height * stride)
    previous = bytearray(stride)
    offset = 0
    for y in range(height):
        filter_type = raw[offset]
        offset += 1
        line = bytearray(raw[offset : offset + stride])
        offset += stride
        if filter_type == 1:
            for i in range(channels, stride):
                line[i] = (line[i] + line[i - channels]) & 0xFF
        elif filter_type == 2:
            for i in range(stride):
                line[i] = (line[i] + previous[i]) & 0xFF
        elif filter_type == 3:
            for i in range(stride):
                left = line[i - channels] if i >= channels else 0
                line[i] = (line[i] + ((left + previous[i]) >> 1)) & 0xFF
        elif filter_type == 4:
            for i in range(stride):
                left = line[i - channels] if i >= channels else 0
                up = previous[i]
                up_left = previous[i - channels] if i >= channels else 0
                estimate = left + up - up_left
                pa = abs(estimate - left)
                pb = abs(estimate - up)
                pc = abs(estimate - up_left)
                predictor = left if (pa <= pb and pa <= pc) else (up if pb <= pc else up_left)
                line[i] = (line[i] + predictor) & 0xFF
        elif filter_type != 0:
            raise ValueError(f"unsupported filter {filter_type}")
        pixels[y * stride : (y + 1) * stride] = line
        previous = line
    return width, height, channels, bytes(pixels)


def write_png(path: Path, width: int, height: int, rgba: bytes) -> None:
    """Write an 8-bit RGBA PNG with filter 0."""
    stride = width * 4
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        raw += rgba[y * stride : (y + 1) * stride]

    def chunk(kind: bytes, payload: bytes) -> bytes:
        return (
            struct.pack(">I", len(payload))
            + kind
            + payload
            + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)
        )

    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )
    path.write_bytes(png)


def alpha_channel(width: int, height: int, channels: int, pixels: bytes) -> bytearray:
    alpha = bytearray(width * height)
    if channels == 4:
        for i in range(width * height):
            alpha[i] = pixels[i * 4 + 3]
    elif channels == 2:
        for i in range(width * height):
            alpha[i] = pixels[i * 2 + 1]
    else:
        alpha[:] = b"\xff" * (width * height)
    return alpha


def empty_mask(width: int, height: int) -> bytearray:
    return bytearray(width * height)


def circle_mask(
    alpha: bytearray, width: int, height: int, cx: float, cy: float, radius: float
) -> bytearray:
    mask = empty_mask(width, height)
    r2 = radius * radius
    x0 = max(0, int(cx - radius) - 1)
    x1 = min(width - 1, int(cx + radius) + 1)
    y0 = max(0, int(cy - radius) - 1)
    y1 = min(height - 1, int(cy + radius) + 1)
    for y in range(y0, y1 + 1):
        dy = y - cy
        for x in range(x0, x1 + 1):
            dx = x - cx
            if dx * dx + dy * dy <= r2:
                i = y * width + x
                mask[i] = alpha[i]
    return mask


def rect_mask(
    alpha: bytearray, width: int, height: int, x0: int, y0: int, x1: int, y1: int
) -> bytearray:
    mask = empty_mask(width, height)
    for y in range(max(0, y0), min(height, y1)):
        base = y * width
        for x in range(max(0, x0), min(width, x1)):
            mask[base + x] = alpha[base + x]
    return mask


def flood_mask(
    alpha: bytearray, width: int, height: int, seed_x: int, seed_y: int
) -> bytearray:
    """Copy the connected component that contains the seed.

    The d-pad petals are four disconnected components in the artwork, so a flood
    fill from each petal centre returns exactly that petal and never the shared
    ring. Threshold 8 keeps the anti-aliased edge of the stroke.
    """
    mask = empty_mask(width, height)
    start = seed_y * width + seed_x
    if alpha[start] <= 8:
        # The control centres are hollow (the petals are outlines), so walk out to
        # the nearest stroke pixel before flooding.
        best = None
        best_distance = None
        for radius in range(1, 40):
            for dy in range(-radius, radius + 1):
                for dx in range(-radius, radius + 1):
                    x = seed_x + dx
                    y = seed_y + dy
                    if x < 0 or x >= width or y < 0 or y >= height:
                        continue
                    i = y * width + x
                    if alpha[i] <= 8:
                        continue
                    distance = dx * dx + dy * dy
                    if best_distance is None or distance < best_distance:
                        best = i
                        best_distance = distance
            if best is not None:
                break
        if best is None:
            raise ValueError(f"no stroke near flood seed: {seed_x},{seed_y}")
        start = best
    mask[start] = alpha[start]
    stack = [start]
    while stack:
        i = stack.pop()
        x = i % width
        for j in (i - 1, i + 1, i - width, i + width):
            if j < 0 or j >= width * height:
                continue
            if (j == i - 1 and x == 0) or (j == i + 1 and x == width - 1):
                continue
            if mask[j] == 0 and alpha[j] > 8:
                mask[j] = alpha[j]
                stack.append(j)
    return mask


def mask_to_rgba(mask: bytearray) -> bytes:
    rgba = bytearray(len(mask) * 4)
    for i, a in enumerate(mask):
        if a:
            rgba[i * 4 : i * 4 + 4] = bytes((255, 255, 255, a))
    return bytes(rgba)


def build(art: str, source: Path, debug: Path | None) -> None:
    width, height, channels, pixels = read_png(source)
    if (width, height) != (1452, 940):
        raise ValueError(f"unexpected image size for {source}: {width}x{height}")
    alpha = alpha_channel(width, height, channels, pixels)
    counts: dict[str, int] = {}
    debug_rgba = bytearray(width * height * 4)
    # Base for the debug composite: the artwork in dim grey.
    for i, a in enumerate(alpha):
        if a:
            debug_rgba[i * 4 : i * 4 + 4] = bytes((70, 78, 92, a))

    palette = [
        (110, 231, 183),
        (125, 211, 252),
        (251, 191, 36),
        (244, 114, 182),
        (167, 139, 250),
        (45, 212, 191),
        (248, 113, 113),
        (163, 230, 53),
    ]

    for index, (control, _kind, region) in enumerate(CONTROLS):
        if art == "simple" and control == "guide":
            # The simple artwork deliberately has no PS logo; the page draws the
            # glyph as a vector and tints it with CSS.
            mask = empty_mask(width, height)
        elif region[0] == "flood":
            mask = flood_mask(alpha, width, height, region[1], region[2])
        elif region[0] == "circle":
            mask = circle_mask(alpha, width, height, region[1], region[2], region[3])
        elif region[0] == "rect":
            mask = rect_mask(alpha, width, height, region[1], region[2], region[3], region[4])
        elif region[0] == "shoulder":
            mask = rect_mask(alpha, width, height, region[1], region[3], region[2], region[4])
        else:
            raise ValueError(f"unknown region {region}")

        counts[control] = sum(1 for a in mask if a)
        output = MASKS / f"{art}-{control}.png"
        write_png(output, width, height, mask_to_rgba(mask))

        color = palette[index % len(palette)]
        for i, a in enumerate(mask):
            if a:
                debug_rgba[i * 4 : i * 4 + 4] = bytes((*color, a))

    if debug is not None:
        write_png(debug, width, height, bytes(debug_rgba))

    print(f"{art}: {len(CONTROLS)} masks from {source.name}")
    for control, kind, _ in CONTROLS:
        print(f"  {control:14s} {kind:9s} {counts[control]:6d} px")
    total = sum(p.stat().st_size for p in MASKS.glob(f"{art}-*.png"))
    print(f"  total mask bytes: {total:,}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--debug",
        type=Path,
        help="write a colour-coded composite of all masks to this path",
    )
    parser.add_argument(
        "--simple",
        type=Path,
        default=ASSETS / "ps4-simple.png",
        help="path to PS4_Diagram_Simple.png",
    )
    parser.add_argument(
        "--diagram",
        type=Path,
        default=ASSETS / "ps4-diagram.png",
        help="path to PS4_Diagram.png",
    )
    args = parser.parse_args()
    MASKS.mkdir(parents=True, exist_ok=True)
    build("simple", args.simple, args.debug)
    build("diagram", args.diagram, None)


if __name__ == "__main__":
    main()
