#!/usr/bin/env python3
"""Resize an image from data_pics into a P3 PPM used by overlay simulation."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def write_p3_ppm(path: Path, image: Image.Image) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image = image.convert("RGB")
    width, height = image.size
    with path.open("w", encoding="ascii") as fh:
        fh.write("P3\n")
        fh.write(f"{width} {height}\n")
        fh.write("255\n")
        for r, g, b in image.getdata():
            fh.write(f"{r} {g} {b}\n")


def write_hex(path: Path, image: Image.Image) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image = image.convert("RGB")
    with path.open("w", encoding="ascii") as fh:
        for r, g, b in image.getdata():
            fh.write(f"{r:02x}{g:02x}{b:02x}\n")


def main() -> int:
    root = repo_root()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=root / "data_pics" / "1.jpeg")
    parser.add_argument("--output", type=Path, default=root / "sim_pds" / "sim_modelsim" / "input_image.ppm")
    parser.add_argument("--hex-output", type=Path, default=root / "sim_pds" / "sim_modelsim" / "input_image.hex")
    parser.add_argument("--width", type=int, default=256)
    parser.add_argument("--height", type=int, default=256)
    args = parser.parse_args()

    resample = getattr(Image.Resampling, "BILINEAR", Image.BILINEAR)
    image = Image.open(args.input).convert("RGB").resize((args.width, args.height), resample)
    write_p3_ppm(args.output, image)
    write_hex(args.hex_output, image)
    print(f"Wrote {args.output} and {args.hex_output} from {args.input} as {args.width}x{args.height}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
