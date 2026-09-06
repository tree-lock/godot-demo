#!/usr/bin/env python3
"""Encode/decode Godot 4.3+ TileMapLayer tile_map_data in a .tscn file."""

from __future__ import annotations

import argparse
import base64
import re
import struct
from pathlib import Path

CHARS = {
    ".": (0, 0, 0),
    "r": (0, 1, 0),
    "W": (0, 2, 0),
    "s": (0, 0, 1),
    "c": (0, 1, 1),
    "Y": (0, 2, 1),
    "b": (0, 0, 2),
    "-": (0, 1, 2),
    "u": (0, 2, 2),
    "T": (0, 3, 2),
    "K": (0, 2, 3),
    "t": (0, 3, 3),
    "P": (2, 0, 2),
    "V": (2, 0, 3),
    "S": (2, 0, 4),
    "H": (2, 0, 5),
}

REV = {v: k for k, v in CHARS.items()}
ARRAY_RE = re.compile(r'PackedByteArray\("([^"]*)"\)')


def encode_cells(cells: list[tuple[int, int, int, int, int, int]]) -> str:
    buf = bytearray(struct.pack("<H", 0))
    for x, y, src, ax, ay, alt in cells:
        buf += struct.pack("<hhhhhh", x, y, src, ax, ay, alt)
    return base64.b64encode(buf).decode("ascii")


def decode_b64(b64: str) -> list[tuple[int, int, int, int, int, int]]:
    raw = base64.b64decode(b64)
    if len(raw) < 2:
        return []
    usable = raw[2:]
    usable = usable[: len(usable) - (len(usable) % 12)]
    cells = []
    for i in range(0, len(usable), 12):
        x, y, src, ax, ay, alt = struct.unpack_from("<hhhhhh", usable, i)
        if src == -1 or src == 0xFFFF:
            continue
        cells.append((x, y, src, ax, ay, alt))
    return cells


def rows_to_cells(rows: list[str]) -> list[tuple[int, int, int, int, int, int]]:
    cells = []
    for y, row in enumerate(rows):
        row = row.rstrip("\n")
        if len(row) != 16:
            raise SystemExit(f"row {y} has length {len(row)}, expected 16: {row!r}")
        for x, ch in enumerate(row):
            if ch not in CHARS:
                raise SystemExit(f"unknown char {ch!r} at ({x},{y})")
            src, ax, ay = CHARS[ch]
            cells.append((x, y, src, ax, ay, 0))
    if len(rows) != 16:
        raise SystemExit(f"expected 16 rows, got {len(rows)}")
    return cells


def overlay_cells(pairs: list[str]) -> list[tuple[int, int, int, int, int, int]]:
    cells = []
    for item in pairs:
        x_s, y_s = item.split(",")
        cells.append((int(x_s), int(y_s), 0, 0, 0, 0))
    return cells


def print_layer(
    cells: list[tuple[int, int, int, int, int, int]], title: str, overlay: bool = False
) -> None:
    if not cells:
        print(title, "(empty)")
        return
    by = {(c[0], c[1]): c for c in cells}
    xs = [c[0] for c in cells]
    ys = [c[1] for c in cells]
    print(title, f"cells={len(cells)} x={min(xs)}..{max(xs)} y={min(ys)}..{max(ys)}")
    for y in range(min(ys), max(ys) + 1):
        parts = []
        for x in range(min(xs), max(xs) + 1):
            c = by.get((x, y))
            if not c:
                parts.append(" ")
                continue
            if overlay and (c[2], c[3], c[4]) == (0, 0, 0):
                parts.append("!")
                continue
            key = (c[2], c[3], c[4])
            parts.append(REV.get(key, "?"))
        print(f"{y:2d} {''.join(parts)}")


def patch_tscn(path: Path, ground_b64: str | None, overlay_b64: str | None) -> None:
    text = path.read_text()
    arrs = ARRAY_RE.findall(text)
    if len(arrs) < 2:
        raise SystemExit(f"expected >=2 PackedByteArray in {path}, found {len(arrs)}")
    if ground_b64 is not None:
        text = text.replace(arrs[0], ground_b64, 1)
        arrs = ARRAY_RE.findall(text)
    if overlay_b64 is not None:
        text = text.replace(arrs[1], overlay_b64, 1)
    path.write_text(text)


def cmd_decode(args: argparse.Namespace) -> None:
    text = Path(args.tscn).read_text()
    arrs = ARRAY_RE.findall(text)
    names = ["ground", "overlay"]
    for i, b64 in enumerate(arrs):
        title = names[i] if i < len(names) else f"array{i}"
        print_layer(decode_b64(b64), title, overlay=title == "overlay")


def cmd_paint(args: argparse.Namespace) -> None:
    rows = Path(args.ground_file).read_text().splitlines()
    rows = [r for r in rows if r and not r.startswith("#")]
    ground = encode_cells(rows_to_cells(rows))
    overlay = encode_cells(overlay_cells(args.overlay or []))
    patch_tscn(Path(args.tscn), ground, overlay)
    print("wrote", args.tscn)


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest="cmd", required=True)

    d = sub.add_parser("decode", help="print layers from a .tscn")
    d.add_argument("tscn")
    d.set_defaults(func=cmd_decode)

    pt = sub.add_parser("paint", help="write 16x16 char map + overlay cells")
    pt.add_argument("tscn")
    pt.add_argument("--ground-file", required=True, help="16 lines of 16 chars")
    pt.add_argument(
        "--overlay",
        nargs="*",
        default=[],
        help="overlay cells as x,y (16x32 warning signs)",
    )
    pt.set_defaults(func=cmd_paint)

    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
