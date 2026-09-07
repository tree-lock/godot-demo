#!/usr/bin/env python3
"""Print spritesheet grid occupancy and optional cell size."""

from __future__ import annotations

import argparse
import struct
import zlib
from pathlib import Path


def decode_png(path: Path):
    data = path.read_bytes()
    pos = 8
    w = h = col = None
    idat = b""
    while pos < len(data):
        ln = struct.unpack(">I", data[pos : pos + 4])[0]
        typ = data[pos + 4 : pos + 8]
        chunk = data[pos + 8 : pos + 8 + ln]
        pos += 12 + ln
        if typ == b"IHDR":
            w, h, _bitd, col, _c, _f, _i = struct.unpack(">IIBBBBB", chunk)
        elif typ == b"IDAT":
            idat += chunk
        elif typ == b"IEND":
            break
    raw = zlib.decompress(idat)
    bpp = 4 if col == 6 else 3 if col == 2 else (_ for _ in ()).throw(SystemExit(f"unsupported png color {col}"))
    stride = w * bpp
    rows = []
    i = 0
    prev = bytearray(stride)

    def paeth(a, b, c):
        p = a + b - c
        pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
        if pa <= pb and pa <= pc:
            return a
        if pb <= pc:
            return b
        return c

    for _y in range(h):
        f = raw[i]
        i += 1
        row = bytearray(raw[i : i + stride])
        i += stride
        if f == 1:
            for x in range(stride):
                a = row[x - bpp] if x >= bpp else 0
                row[x] = (row[x] + a) & 255
        elif f == 2:
            for x in range(stride):
                row[x] = (row[x] + prev[x]) & 255
        elif f == 3:
            for x in range(stride):
                a = row[x - bpp] if x >= bpp else 0
                row[x] = (row[x] + ((a + prev[x]) // 2)) & 255
        elif f == 4:
            for x in range(stride):
                a = row[x - bpp] if x >= bpp else 0
                b = prev[x]
                c = prev[x - bpp] if x >= bpp else 0
                row[x] = (row[x] + paeth(a, b, c)) & 255
        rows.append(bytes(row))
        prev = row
    return w, h, bpp, rows


def nonempty(rows, bpp, x0, y0, cw, ch, w, h):
    n = 0
    for y in range(y0, min(h, y0 + ch)):
        row = rows[y]
        for x in range(x0, min(w, x0 + cw)):
            o = x * bpp
            r, g, b = row[o], row[o + 1], row[o + 2]
            a = row[o + 3] if bpp == 4 else 255
            if a > 10 and r + g + b > 15:
                n += 1
    return n


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("png")
    p.add_argument("--cell", type=int, default=32)
    args = p.parse_args()
    w, h, bpp, rows = decode_png(Path(args.png))
    cw = ch = args.cell
    cols, rcount = w // cw, h // ch
    print(f"size {w}x{h} cell {cw} grid {cols}x{rcount}")
    print("row  y    " + " ".join(f"c{c}" for c in range(cols)))
    for row in range(rcount):
        counts = [nonempty(rows, bpp, c * cw, row * ch, cw, ch, w, h) for c in range(cols)]
        print(f"{row:3d} {row * ch:4d} " + " ".join(f"{n:4d}" for n in counts))


if __name__ == "__main__":
    main()
