# Design: Creature & Backdrop Art Pipeline (photo-traced, procedural torchlit treatment)

**Date:** 2026-09-13
**Status:** Approved, pending implementation plan
**Parent spec:** `docs/superpowers/specs/2026-09-06-torchlit-theme-design.md`
**Builds on:** the Torchlit theme foundation (`UiTokens`, `ThemeBuilder`, `ArtPlaceholder`) — merged.
**Supersedes:** the "AI-generated painterly PNG" art plan noted in `assets/art/README.md` and in the torchlit-theme spec's summary. No AI-generated art in this project; art is derived from real reference photos instead.

## Summary

`ArtPlaceholder` (`scripts/ui/theme/art_placeholder.gd`) already shows
`res://assets/art/<art_id>.png` when it exists, falling back to a
bracketed brief otherwise — that plumbing doesn't change. What changes
is how the art itself gets made: instead of commissioning or
AI-generating paintings, each creature (and eventually each backdrop)
is derived from a real reference photo through a small, repeatable,
scriptable pipeline — crop, posterize to a handful of colours, darken
those colours into the game's "dark stone" value range, vectorize —
producing a traced SVG that Godot imports natively as a texture. A
shared shader then adds the game's specific "torchlit" treatment (one
ember rim-light, glowing accent details) on top at runtime, so that
part is uniform across every asset and never hand-tuned per creature.

Validated end to end during design on a real photo (a coypu, the
intended first Act-1-forest creature) — see `assets/art_source/coypu/`
once the pilot lands.

## 1. Scope

**In scope:**

- The production pipeline: reference photo → cropped to the art's
  display aspect ratio → subject matted off its background (`rembg`)
  onto a synthetic magenta key colour → posterized (~20 colour
  buckets) → darkened/desaturated → vectorized (`vtracer`) → tracked
  SVG.
- `ArtPlaceholder` extended to look up `.svg` (in addition to today's
  `.png`).
- A shared `torchlit_creature.gdshader`: ember rim-light along one
  global light direction, driven by the silhouette edge the shader
  recovers by chroma-keying the matte's magenta background (the traced
  SVG itself is fully opaque — `vtracer` cannot carry alpha).
- A small per-creature accent-marker convention (eye / mouth position)
  for glowing highlight dots, defined alongside existing content
  scripts (pattern: `forest_content.gd`).
- File/folder conventions for source photos vs. tracked art.
- One pilot asset: the Coypu (Act 1 forest's first creature) end to
  end, proving the pipeline in the real engine.

**Explicitly out of scope (deferred):**

- Re-deriving the existing backdrop briefs (`map_party`, `map_corridor`,
  `camp_fire`) through this pipeline — same system, later pass.
- Any change to `forest_content.gd`'s enemy roster (whether the Coypu
  replaces "Forest Wolf" as the first fight, or sits alongside it) —
  a content/game-design decision, not an art-pipeline one. Flagged for
  the implementation plan to resolve, not decided here.
- Animation/rigging of creature art (idle motion, hit-flash, death) —
  the pipeline produces a static texture; motion is a later concern.
- Retouching/cleaning of the traced SVG beyond the automated pipeline
  (manual path cleanup) — do it if a specific creature needs it, not
  as a mandatory step.

## 2. Pipeline

For each creature or backdrop:

1. **Source one reference photo.** Supplied by the user (or a
   public-domain wildlife/scene photo). Not AI-generated.
2. **Crop** to the subject, removing excess background. The crop must
   match the art's display aspect ratio (`ArtPlaceholder`'s
   `TextureRect` uses `STRETCH_SCALE`, so a mismatched canvas is
   visibly squeezed). The Coypu's 288×266 crop of `docs/ragondin.jpg`
   is `(248, 9, 2264, 1871)` → 2016×1862.
3. **Matte** the subject off its background with `rembg` (U2-Net) and
   composite it onto pure magenta, `#ff00ff` — a colour that cannot
   occur in a reference photo or in this game's palette. Downscale to
   the working resolution *before* compositing and harden the matte to
   a binary mask there, so no pixel is ever a magenta/subject blend.
   The key colour is what the shader chroma-keys at runtime to recover
   the silhouette; carrying real PNG alpha through `vtracer` is not an
   option (its CLI has no alpha handling at all).
4. **Posterize**: quantize to ~20–22 flat colours (`PIL.Image.quantize`,
   `MEDIANCUT`, no dithering — dithering defeats flat-region tracing).
5. **Darken/desaturate** every quantized colour into the "dark stone"
   value range via an HSV remap: `s' = min(s * 0.85, 0.6)`,
   `v' = min(v * 0.62 + 0.04, 0.55)`. This is a fixed formula applied
   uniformly, not eyeballed per creature, so every asset lands in the
   same tonal register automatically — except the key colour's palette
   entry, which is left undarkened (and snapped back to exact magenta)
   so the shader's chroma key stays a precise match.
6. **Vectorize** the posterized+darkened image with `vtracer`:
   `--colormode color --hierarchical stacked --mode spline
   --filter_speckle 5 --color_precision 8 --corner_threshold 80
   --segment_length 3.5 --splice_threshold 45`. Spline mode and a low
   speckle filter keep enough fine detail (whiskers, fur clumps) to
   read as the real animal rather than a blocky mosaic — this was the
   difference between a rejected first pass (8 colours, polygon mode,
   heavy speckle filtering) and the approved result.
7. The resulting SVG is the tracked game asset — no rasterization step
   needed (see §3).

**Tooling dependency:** `vtracer`, installed via `cargo install
vtracer` (Rust toolchain, already present on this machine). **Do not**
use the `vtracer` PyPI wheel — it segfaults on Python 3.14 even on
trivial input; the native cargo-built CLI is the one that works.
Pillow (`pip install pillow`) does the crop/posterize/darken step, and
`rembg` with a CPU backend (`pip install "rembg[cpu]"`) does the
matting — its model downloads to the user cache on first run.

## 3. Godot integration

Godot's asset importer rasterizes `.svg` to a texture at import time
(`--headless --import`), the same way it handles `.png` — so the
traced SVG can be the actual asset Godot loads, with no separate
"bake to PNG" tool needed. `ArtPlaceholder.setup()` currently only
checks `ART_DIR + art_id + ".png"`; it needs to also check `.svg` and
prefer whichever exists (`.svg` first, since it's the new convention;
`.png` stays supported for backdrops that haven't migrated).

The rim-light/glow treatment is a separate shader layer, not baked
into the traced art:

- **`torchlit_creature.gdshader`**, applied as the material on the
  `TextureRect` `ArtPlaceholder` creates when art exists. Chroma-keys
  the matte's magenta background (`key_color`/`key_tolerance`) to
  derive the subject's alpha — the traced texture has none of its own
  — then uses that to find the silhouette edge and brighten the edge
  facing one fixed light-direction constant (matching the "one warm
  light source" rule already established for screens), tinted with
  `UiTokens.EMBER`. The same derived alpha is written out as the
  fragment's alpha, so the key colour never renders.
- **Accent markers**: 2–3 `Vector2` positions per creature (eye,
  mouth/teeth) stored as constants alongside that creature's content
  definition (e.g. `forest_content.gd`), each rendered as a small
  glowing `RUNE`/`EMBER_LIGHT` dot positioned in the art's local
  space. Not derived automatically — hand-placed once per creature by
  eye, since there are only a couple of points per asset.

## 4. File organization

```
assets/art_source/<id>/reference.jpg   # raw photo — gitignored
assets/art/enemy_<name>.svg             # traced, darkened output — tracked
```

Raw reference photos are gitignored: they're either third-party
wildlife photos or the user's own, and shouldn't ship as project
history regardless — only the transformed, traced art is tracked. The
traced SVG is the real source of truth (there is no separate "design
file" beyond it — it's already vector, already game-ready).

`assets/art/README.md`'s brief table and its "AI-generated, painterly"
framing is stale and gets rewritten to describe this pipeline instead
of the old one, once implemented.

## 5. Testing

`ArtPlaceholder`'s existing GUT tests cover the `.png`-exists /
falls-back-to-brief branches; they extend to cover `.svg` the same
way. The shader and accent-marker rendering are visual, not something
GUT asserts on directly — verified by running the game
(`--headless --import` after adding the pilot asset, then the normal
test suite for regressions), matching how `TorchGlow`/other purely
visual components are already handled in this codebase.

## 6. Pilot

The Coypu is the proof of concept: reference photo already sourced
and traced during design (see §2's validated parameters). Implementing
this spec means wiring the pipeline's output into the actual game —
adding `assets/art/enemy_coypu.svg`, extending `ArtPlaceholder`,
building `torchlit_creature.gdshader`, and placing that creature's
accent markers — not re-deriving the art from scratch.
