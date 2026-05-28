#!/usr/bin/env python3
"""Verify crop PPM files against the expected bilinear interpolation output.

The default model mirrors the fixed-point datapath in rtl_pds/overlay/
box_overlay_sync.sv, including the reciprocal-based resize step and the
two-stage interpolation rounding.  Use --model ideal to compare against a
plain fixed-point bilinear model instead.
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import replace
from dataclasses import dataclass
from pathlib import Path


FRAC_BITS = 8
FRAC_ONE = 1 << FRAC_BITS
RECIP_BITS = 32


@dataclass
class Box:
    cls: int
    idx_x: int
    idx_y: int
    conf: int
    left: int
    top: int
    right: int
    bottom: int
    xmin: int
    ymin: int
    xmax: int
    ymax: int
    width: int
    height: int


def repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def parse_parameters(tb_path: Path) -> dict[str, int]:
    text = tb_path.read_text(encoding="utf-8", errors="ignore")
    params: dict[str, int] = {}
    for name, value in re.findall(r"parameter\s+(\w+)\s*=\s*([0-9]+)\s*;", text):
        params[name] = int(value)
    return params


def parse_injected_boxes(tb_path: Path, params: dict[str, int]) -> list[Box]:
    text = tb_path.read_text(encoding="utf-8", errors="ignore")
    boxes: list[Box] = []
    call_re = re.compile(r"send_box_data\s*\(([^()]*)\)")

    for match in call_re.finditer(text):
        fields = [v.strip() for v in match.group(1).split(",")]
        if len(fields) != 8 or not all(re.fullmatch(r"[+-]?\d+", field) for field in fields):
            continue
        values = [int(v) for v in fields]
        if len(values) != 8:
            continue
        cls, idx_x, idx_y, conf, left, top, right, bottom = values
        boxes.append(make_box(cls, idx_x, idx_y, conf, left, top, right, bottom, params))
    return boxes


def make_box(
    cls: int,
    idx_x: int,
    idx_y: int,
    conf: int,
    left: int,
    top: int,
    right: int,
    bottom: int,
    params: dict[str, int],
) -> Box:
    img_width = params["IMG_WIDTH"]
    img_height = params["IMG_HEIGHT"]
    crop_width = params["CROP_WIDTH"]
    crop_height = params["CROP_HEIGHT"]
    stride_center = params["GRID_STRIDE_CENTER"]
    stride_ltrb = params["GRID_STRIDE_LTRB"]

    cx = idx_x * stride_center + stride_center // 2
    cy = idx_y * stride_center + stride_center // 2

    xmin_val = cx - left * stride_ltrb
    ymin_val = cy - top * stride_ltrb
    xmax_val = cx + right * stride_ltrb
    ymax_val = cy + bottom * stride_ltrb

    xmin = xmin_val - 10 if (xmin_val - 10) > 1 else 1
    ymin = ymin_val - 5 if (ymin_val - 5) > 1 else 1
    xmax = xmax_val + 10 if (xmax_val + 10) < img_width - 2 else img_width - 2
    ymax = ymax_val + 5 if (ymax_val + 5) < img_height - 2 else img_height - 2

    width = xmax - xmin
    height = ymax - ymin

    if height < crop_height:
        if ymin + crop_height <= img_height - 2:
            ymax = ymin + crop_height
        else:
            ymax = img_height - 2
            ymin = (img_height - 2 - crop_height) if (img_height - 2 >= crop_height) else 1
        height = crop_height

    if width < crop_width:
        if xmin + crop_width <= img_width - 2:
            xmax = xmin + crop_width
        else:
            xmax = img_width - 2
            xmin = (img_width - 2 - crop_width) if (img_width - 2 >= crop_width) else 1
        width = crop_width

    return Box(cls, idx_x, idx_y, conf, left, top, right, bottom, xmin, ymin, xmax, ymax, width, height)


def read_ppm(path: Path) -> tuple[int, int, list[tuple[int, int, int]]]:
    tokens: list[str] = []
    for raw_line in path.read_text(encoding="ascii", errors="strict").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        tokens.extend(line.split())

    if not tokens or tokens[0] != "P3":
        raise ValueError(f"{path} is not an ASCII P3 PPM")
    width = int(tokens[1])
    height = int(tokens[2])
    max_value = int(tokens[3])
    if max_value != 255:
        raise ValueError(f"{path} has unsupported max value {max_value}")

    values = [int(v) for v in tokens[4:]]
    if len(values) != width * height * 3:
        raise ValueError(f"{path} has {len(values)} RGB values, expected {width * height * 3}")

    pixels = [(values[i], values[i + 1], values[i + 2]) for i in range(0, len(values), 3)]
    return width, height, pixels


SOURCE_IMAGE: tuple[int, int, list[tuple[int, int, int]]] | None = None


def tb_source_pixel(x: int, y: int) -> tuple[int, int, int]:
    """Mirror the SV assignment used in generate_video_frame().

    In the testbench, y[7:0]*2 and x[7:0]*2 are self-determined wider
    expressions inside a concatenation.  Assigning that wide concatenation
    to 24 bits keeps the low 16 bits of x*2 and the 8-bit checker color.
    """
    x_word = (x & 0xFF) * 2
    red = (x_word >> 8) & 0xFF
    green = x_word & 0xFF
    blue = 0x99 if ((x // 10) % 2) == ((y // 10) % 2) else 0x11
    return red, green, blue


def source_pixel(x: int, y: int) -> tuple[int, int, int]:
    if SOURCE_IMAGE is None:
        return tb_source_pixel(x, y)

    width, height, pixels = SOURCE_IMAGE
    x = max(0, min(width - 1, x))
    y = max(0, min(height - 1, y))
    return pixels[y * width + x]


def calc_step(src_size: int, dst_size: int) -> int:
    recip = ((1 << RECIP_BITS) + dst_size - 1) // dst_size
    return ((src_size << FRAC_BITS) * recip) >> RECIP_BITS


def calc_start_fp(step: int) -> int:
    return (step >> 1) - (FRAC_ONE >> 1) if step > FRAC_ONE else 0


def calc_sample(fp: int, src_size: int) -> int:
    base = fp >> FRAC_BITS
    has_frac = 1 if (fp & (FRAC_ONE - 1)) else 0
    sample = base + has_frac
    if src_size != 0 and sample >= src_size:
        sample = src_size - 1
    return sample


def interp_horizontal(c0: int, c1: int, frac: int) -> int:
    return ((c0 << FRAC_BITS) + (c1 - c0) * frac) & 0x1FFFF


def interp_vertical(top: int, bottom: int, frac: int) -> int:
    acc = (top << FRAC_BITS) + (bottom - top) * frac + (1 << (2 * FRAC_BITS - 1))
    value = acc >> (2 * FRAC_BITS)
    return max(0, min(255, value))


def expected_pixel_rtl(box: Box, dst_x: int, dst_y: int, crop_width: int, crop_height: int) -> tuple[int, int, int]:
    x_step = calc_step(box.width, crop_width)
    y_step = calc_step(box.height, crop_height)
    x_fp = calc_start_fp(x_step) + dst_x * x_step
    y_fp = calc_start_fp(y_step) + dst_y * y_step
    x_sample = calc_sample(x_fp, box.width)
    y_sample = calc_sample(y_fp, box.height)
    x_frac = x_fp & (FRAC_ONE - 1)
    y_frac = y_fp & (FRAC_ONE - 1)

    current_x = box.xmin + x_sample
    current_y = box.ymin + y_sample
    left_x = current_x if x_frac == 0 else current_x - 1
    top_y = current_y if y_frac == 0 else current_y - 1

    p00 = source_pixel(left_x, top_y)
    p10 = source_pixel(current_x, top_y)
    p01 = source_pixel(left_x, current_y)
    p11 = source_pixel(current_x, current_y)

    out = []
    for ch in range(3):
        top = interp_horizontal(p00[ch], p10[ch], x_frac)
        bottom = interp_horizontal(p01[ch], p11[ch], x_frac)
        out.append(interp_vertical(top, bottom, y_frac))
    return tuple(out)  # type: ignore[return-value]


def expected_pixel_ideal(box: Box, dst_x: int, dst_y: int, crop_width: int, crop_height: int) -> tuple[int, int, int]:
    x_step = calc_step(box.width, crop_width)
    y_step = calc_step(box.height, crop_height)
    x_fp = calc_start_fp(x_step) + dst_x * x_step
    y_fp = calc_start_fp(y_step) + dst_y * y_step

    x0_rel = min(box.width - 1, x_fp >> FRAC_BITS)
    y0_rel = min(box.height - 1, y_fp >> FRAC_BITS)
    x1_rel = min(box.width - 1, x0_rel + 1)
    y1_rel = min(box.height - 1, y0_rel + 1)
    x_frac = x_fp & (FRAC_ONE - 1)
    y_frac = y_fp & (FRAC_ONE - 1)

    p00 = source_pixel(box.xmin + x0_rel, box.ymin + y0_rel)
    p10 = source_pixel(box.xmin + x1_rel, box.ymin + y0_rel)
    p01 = source_pixel(box.xmin + x0_rel, box.ymin + y1_rel)
    p11 = source_pixel(box.xmin + x1_rel, box.ymin + y1_rel)

    out = []
    for ch in range(3):
        top = interp_horizontal(p00[ch], p10[ch], x_frac)
        bottom = interp_horizontal(p01[ch], p11[ch], x_frac)
        out.append(interp_vertical(top, bottom, y_frac))
    return tuple(out)  # type: ignore[return-value]


def crop_index(path: Path) -> int:
    match = re.search(r"crop_out_box_(\d+)_x", path.name)
    if not match:
        raise ValueError(f"cannot parse crop index from {path.name}")
    return int(match.group(1))


def crop_xy(path: Path) -> tuple[int, int]:
    match = re.search(r"_x(\d+)_y(\d+)\.ppm$", path.name)
    if not match:
        raise ValueError(f"cannot parse crop coordinates from {path.name}")
    return int(match.group(1)), int(match.group(2))


def match_boxes_to_files(files: list[Path], boxes: list[Box], coord_tolerance: int) -> dict[Path, Box]:
    remaining = boxes.copy()
    matched: dict[Path, Box] = {}

    for path in files:
        x, y = crop_xy(path)
        for idx, box in enumerate(remaining):
            if abs(box.xmin - x) <= coord_tolerance and abs(box.ymin - y) <= coord_tolerance:
                matched[path] = box
                del remaining[idx]
                break
        else:
            raise ValueError(
                f"no injected box matches {path.name} at x={x}, y={y} "
                f"within +/-{coord_tolerance} pixel"
            )
    return matched


def shift_box(box: Box, dx: int, dy: int, params: dict[str, int]) -> Box:
    img_width = params["IMG_WIDTH"]
    img_height = params["IMG_HEIGHT"]

    xmin = max(0, min(img_width - 1, box.xmin + dx))
    xmax = max(0, min(img_width - 1, box.xmax + dx))
    ymin = max(0, min(img_height - 1, box.ymin + dy))
    ymax = max(0, min(img_height - 1, box.ymax + dy))
    return replace(box, xmin=xmin, ymin=ymin, xmax=xmax, ymax=ymax)


def verify_file_once(
    path: Path,
    box: Box,
    model: str,
    tolerance: int,
) -> tuple[int, int, int, tuple[int, int], tuple[int, int, int], tuple[int, int, int]]:
    width, height, pixels = read_ppm(path)
    expected_fn = expected_pixel_rtl if model == "rtl" else expected_pixel_ideal

    fail_count = 0
    max_error = 0
    worst_xy = (0, 0)
    worst_actual = (0, 0, 0)
    worst_expected = (0, 0, 0)

    for y in range(height):
        for x in range(width):
            actual = pixels[y * width + x]
            expected = expected_fn(box, x, y, width, height)
            channel_error = max(abs(a - e) for a, e in zip(actual, expected))
            if channel_error > max_error:
                max_error = channel_error
                worst_xy = (x, y)
                worst_actual = actual
                worst_expected = expected
            if channel_error > tolerance:
                fail_count += 1

    return width * height, fail_count, max_error, worst_xy, worst_actual, worst_expected


def verify_file(
    path: Path,
    box: Box,
    model: str,
    tolerance: int,
    offset_tolerance: int,
    params: dict[str, int],
) -> tuple[int, int, int, tuple[int, int], tuple[int, int, int], tuple[int, int, int], tuple[int, int]]:
    best = None
    best_offset = (0, 0)

    for dy in range(-offset_tolerance, offset_tolerance + 1):
        for dx in range(-offset_tolerance, offset_tolerance + 1):
            shifted = shift_box(box, dx, dy, params)
            result = verify_file_once(path, shifted, model, tolerance)
            _, failures, max_error, *_ = result
            score = (failures, max_error, abs(dx) + abs(dy), abs(dx), abs(dy))
            if best is None or score < best[0]:
                best = (score, result)
                best_offset = (dx, dy)

    assert best is not None
    return (*best[1], best_offset)


def main() -> int:
    root = repo_root()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sim-out", type=Path, default=root / "sim_pds" / "sim_modelsim" / "sim_out")
    parser.add_argument("--tb", type=Path, default=root / "sim_pds" / "tb_box_overlay_crop_buffer_manager.sv")
    parser.add_argument("--crop-width", type=int, default=None, help="override CROP_WIDTH parsed from the testbench")
    parser.add_argument("--crop-height", type=int, default=None, help="override CROP_HEIGHT parsed from the testbench")
    parser.add_argument("--source-ppm", type=Path, default=None, help="source image P3 PPM used by the testbench")
    parser.add_argument("--model", choices=["rtl", "ideal"], default="rtl")
    parser.add_argument("--tolerance", type=int, default=2)
    parser.add_argument(
        "--offset-tolerance",
        type=int,
        default=1,
        help="try source crop offsets in both x/y directions within this many pixels",
    )
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    params = parse_parameters(args.tb)
    if args.crop_width is not None:
        params["CROP_WIDTH"] = args.crop_width
    if args.crop_height is not None:
        params["CROP_HEIGHT"] = args.crop_height
    if args.source_ppm is not None:
        global SOURCE_IMAGE
        SOURCE_IMAGE = read_ppm(args.source_ppm)
    boxes = parse_injected_boxes(args.tb, params)
    files = sorted(args.sim_out.glob("crop_out_box_*_x*_y*.ppm"), key=crop_index)

    if not files:
        print(f"ERROR: no crop_out_box_*.ppm files found in {args.sim_out}", file=sys.stderr)
        return 2
    if len(files) > len(boxes):
        print(f"ERROR: found {len(files)} crop files but only {len(boxes)} injected boxes", file=sys.stderr)
        return 2

    matched = match_boxes_to_files(files, boxes, args.offset_tolerance)

    total_pixels = 0
    total_failures = 0
    global_max_error = 0

    print(f"Checking {len(files)} crop files with model={args.model}, tolerance={args.tolerance}")
    for path in files:
        box = matched[path]
        pixels, failures, max_error, worst_xy, actual, expected, best_offset = verify_file(
            path,
            box,
            args.model,
            args.tolerance,
            args.offset_tolerance,
            params,
        )
        total_pixels += pixels
        total_failures += failures
        global_max_error = max(global_max_error, max_error)

        status = "PASS" if failures == 0 else "FAIL"
        if args.verbose or failures:
            print(
                f"{status} {path.name}: pixels={pixels}, failures={failures}, max_error={max_error}, "
                f"worst_xy={worst_xy}, actual={actual}, expected={expected}, "
                f"best_offset={best_offset}, "
                f"src_box=({box.xmin},{box.ymin})-({box.xmax},{box.ymax})"
            )

    print(
        f"Summary: files={len(files)}, pixels={total_pixels}, failures={total_failures}, "
        f"max_error={global_max_error}"
    )
    return 0 if total_failures == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
