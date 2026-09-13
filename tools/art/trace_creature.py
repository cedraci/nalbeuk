#!/usr/bin/env python3
"""Turn a reference photo into a traced, dark-stone-toned SVG for nalbeuk's
creature/backdrop art.

See docs/superpowers/specs/2026-09-13-creature-art-pipeline-design.md.

Requires:
- The `vtracer` CLI on PATH, built via `cargo install vtracer`.
  Do NOT use the PyPI `vtracer` wheel — it segfaults on Python 3.14+.
- Pillow (`pip install pillow`).

Usage:
    python trace_creature.py --input assets/art_source/coypu/reference.jpg \
        --out-svg assets/art/enemy_coypu.svg
"""
import argparse
import colorsys
import subprocess
import sys
from pathlib import Path

from PIL import Image


def posterize_and_darken(src: Path, dest: Path, colors: int, working_max_dim: int) -> None:
    im = Image.open(src).convert("RGB")
    scale = working_max_dim / max(im.size)
    if scale < 1.0:
        im = im.resize((int(im.width * scale), int(im.height * scale)), Image.LANCZOS)

    quant = im.quantize(colors=colors, method=Image.MEDIANCUT, dither=Image.Dither.NONE)
    palette = quant.getpalette()[: colors * 3]

    new_palette = []
    for i in range(colors):
        r, g, b = (c / 255.0 for c in palette[i * 3 : i * 3 + 3])
        h, s, v = colorsys.rgb_to_hsv(r, g, b)
        s2 = min(s * 0.85, 0.6)
        v2 = min(v * 0.62 + 0.04, 0.55)
        r2, g2, b2 = colorsys.hsv_to_rgb(h, s2, v2)
        new_palette.extend([int(r2 * 255), int(g2 * 255), int(b2 * 255)])
    new_palette += [0, 0, 0] * (256 - colors)

    quant.putpalette(new_palette)
    quant.convert("RGB").save(dest)


def vectorize(src: Path, dest: Path) -> None:
    subprocess.run(
        [
            "vtracer",
            "--input", str(src),
            "--output", str(dest),
            "--colormode", "color",
            "--hierarchical", "stacked",
            "--mode", "spline",
            "--filter_speckle", "5",
            "--color_precision", "8",
            "--corner_threshold", "80",
            "--segment_length", "3.5",
            "--splice_threshold", "45",
        ],
        check=True,
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path, help="Cropped reference photo")
    parser.add_argument("--out-svg", required=True, type=Path, help="Where to write the traced SVG")
    parser.add_argument("--colors", type=int, default=22, help="Posterize colour bucket count")
    parser.add_argument("--working-max-dim", type=int, default=900, help="Resize longest side to this before tracing")
    args = parser.parse_args()

    if not args.input.exists():
        sys.exit(f"input not found: {args.input}")

    posterized = args.out_svg.with_suffix(".posterized.png")
    posterize_and_darken(args.input, posterized, args.colors, args.working_max_dim)
    vectorize(posterized, args.out_svg)
    posterized.unlink()
    print(f"wrote {args.out_svg}")


if __name__ == "__main__":
    main()
