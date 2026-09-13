# Art

Creature and backdrop art is derived from real reference photos, never
AI-generated — see `docs/superpowers/specs/2026-09-13-creature-art-pipeline-design.md`
for the full pipeline and `tools/art/trace_creature.py` to run it. Drop the
resulting `.svg` (or `.png`, for anything not yet migrated) here as
`<art_id>`; `ArtPlaceholder` shows it automatically, `.svg` preferred over
`.png` (until then it shows the bracketed brief).

| art_id | size (px) | brief |
|---|---|---|
| `map_party` | 400×300 | the party, torchlit, mid-argument over which way the torch smoke is blowing — deeper corridor behind them each floor |
| `map_corridor` | 940×900 | corridor backdrop — three parallax layers: far vault, mid pillars, near arch; scrolls as you climb |
| `camp_fire` | 820×900 | camp: a low fire in a stone alcove, packs against the wall, the party arguing in silhouette; one of them is trying to light the fire with a spellbook |
| `enemy_coypu` | 288×266 | a wet, hissing coypu baring its incisors — Act 1's first forest fight |

Style: dark stone, one warm ember light source, traced from real photo
reference and darkened into that palette (not painterly, not
AI-generated), original cast (Hilde Barrowdust, dwarf; companions
unnamed for now).
