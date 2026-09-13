#!/usr/bin/env python3
"""Turn a reference photo into a traced, dark-stone-toned SVG for nalbeuk's
creature/backdrop art.

See docs/superpowers/specs/2026-09-13-creature-art-pipeline-design.md.

The subject is matted off its background (rembg / U2-Net) and composited onto
a solid synthetic key colour — pure magenta, #ff00ff — which then survives the
posterize/darken pass untouched and traces out as one flat, fully-opaque
background region. `scripts/ui/theme/torchlit_creature.gdshader` chroma-keys
that colour at runtime to recover the subject's alpha, which is what its
ember rim-light edge detection needs. We deliberately do NOT rely on PNG alpha
surviving `vtracer` (its CLI exposes no alpha handling at all).

Requires:
- The `vtracer` CLI on PATH, built via `cargo install vtracer`.
  Do NOT use the PyPI `vtracer` wheel — it segfaults on Python 3.14+.
- Pillow (`pip install pillow`).
- rembg with a CPU backend (`pip install "rembg[cpu]"`). Its U2-Net model
  (~1GB for isnet-general-use) downloads to the user cache on first run.

The reference photo must already be cropped to the art's display aspect ratio,
because ArtPlaceholder's TextureRect uses STRETCH_SCALE and will squeeze a
mismatched canvas. The Coypu's 288x266 crop of docs/ragondin.jpg is:

    Image.open("docs/ragondin.jpg").crop((248, 9, 2264, 1871))  # 2016x1862

Usage:
    python trace_creature.py --input assets/art_source/coypu/reference.jpg \
        --out-svg assets/art/enemy_coypu.svg
"""
import argparse
import colorsys
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

# Pure magenta: impossible in the reference photos (wet fur, stone, water) and
# absent from the game's ember/stone palette, so it can never collide with a
# real subject colour. Kept bit-exact end to end so the shader can key it.
KEY_COLOR = (255, 0, 255)
# Max per-channel drift still counted as "this palette entry is the key colour".
KEY_MATCH_SLOP = 8
# Alpha at/above which a matted pixel counts as subject.
MATTE_CUTOFF = 128


def _resize_to_working(im: Image.Image, working_max_dim: int) -> Image.Image:
    scale = working_max_dim / max(im.size)
    if scale >= 1.0:
        return im
    return im.resize((int(im.width * scale), int(im.height * scale)), Image.LANCZOS)


def matte_onto_key(src: Path, working_max_dim: int) -> Image.Image:
    """Cut the subject out of its background and drop it on the key colour.

    Downscaling happens *before* the composite, and the matte is hardened to a
    binary mask at that final resolution. Compositing first and resampling
    afterwards would blend subject colours into the key colour and litter the
    palette with half-magenta fringe entries the shader could classify neither
    as background nor as subject (measured: #a02598, #6b1d64 and friends).
    """
    try:
        from rembg import remove
    except ImportError as exc:  # pragma: no cover - environment guard
        sys.exit(
            f"rembg is required for background matting ({exc}).\n"
            'Install it with: pip install "rembg[cpu]"'
        )

    cut = remove(Image.open(src).convert("RGB"))
    if cut.mode != "RGBA":
        cut = cut.convert("RGBA")
    small = _resize_to_working(cut, working_max_dim)

    mask = small.getchannel("A").point(lambda a: 255 if a >= MATTE_CUTOFF else 0)
    keyed = Image.new("RGB", small.size, KEY_COLOR)
    # A 0-or-255 mask makes paste() a hard stencil, so every output pixel is
    # either exactly the key colour or an untouched subject colour.
    keyed.paste(small.convert("RGB"), (0, 0), mask)
    return keyed


def _is_key_color(r: int, g: int, b: int) -> bool:
    return all(abs(c - k) <= KEY_MATCH_SLOP for c, k in zip((r, g, b), KEY_COLOR))


def posterize_and_darken(im: Image.Image, dest: Path, colors: int) -> None:
    """Quantize to `colors` buckets and pull each one into the stone palette.

    `im` is expected to already be at working resolution (see
    `_resize_to_working`) so no resampling happens after this point.
    """
    quant = im.convert("RGB").quantize(
        colors=colors, method=Image.MEDIANCUT, dither=Image.Dither.NONE
    )
    palette = quant.getpalette() or []
    # quantize() can hand back fewer entries than requested (flat images), so
    # never walk past what it actually produced.
    entries = min(colors, len(palette) // 3)

    new_palette: list[int] = []
    for i in range(entries):
        r8, g8, b8 = palette[i * 3 : i * 3 + 3]
        if _is_key_color(r8, g8, b8):
            # Leave the background's entry alone (and snap it back to exactly
            # the key colour) so the shader's chroma key stays a precise match.
            new_palette.extend(KEY_COLOR)
            continue
        r, g, b = (c / 255.0 for c in (r8, g8, b8))
        h, s, v = colorsys.rgb_to_hsv(r, g, b)
        s2 = min(s * 0.85, 0.6)
        v2 = min(v * 0.62 + 0.04, 0.55)
        r2, g2, b2 = colorsys.hsv_to_rgb(h, s2, v2)
        new_palette.extend([int(r2 * 255), int(g2 * 255), int(b2 * 255)])
    new_palette += [0, 0, 0] * (256 - entries)

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
    parser.add_argument("--no-matte", action="store_true", help="Skip background matting (keep the photo's own background)")
    args = parser.parse_args()

    if not args.input.exists():
        sys.exit(f"input not found: {args.input}")
    if shutil.which("vtracer") is None:
        sys.exit(
            "the `vtracer` CLI is not on PATH.\n"
            "Install it with: cargo install vtracer\n"
            "(do NOT use the PyPI `vtracer` wheel — it segfaults on Python 3.14+)"
        )

    if args.no_matte:
        source = _resize_to_working(Image.open(args.input).convert("RGB"), args.working_max_dim)
    else:
        source = matte_onto_key(args.input, args.working_max_dim)

    # Keep the posterized intermediate out of assets/art/ — a vtracer failure
    # there would leave a stray PNG for Godot to import on the next pass.
    handle = tempfile.NamedTemporaryFile(suffix=".png", delete=False)
    handle.close()
    posterized = Path(handle.name)
    try:
        posterize_and_darken(source, posterized, args.colors)
        vectorize(posterized, args.out_svg)
    finally:
        try:
            os.unlink(posterized)
        except OSError:
            pass
    print(f"wrote {args.out_svg}")


if __name__ == "__main__":
    main()
