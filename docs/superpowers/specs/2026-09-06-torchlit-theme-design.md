# Design: Torchlit Theme Foundation, Map & Camp (Plan 4A)

**Date:** 2026-09-06
**Status:** Approved, pending implementation plan
**Parent spec:** `docs/superpowers/specs/2026-09-04-party-deckbuilder-design.md`
**Visual design:** `docs/design/look-and-feel/` (the "Torchlit corridor"
direction — `Main.dc.html` Map, `Combat.dc.html`, `Camp.dc.html`,
`Tokens.dc.html` design system; published canvas
https://claude.ai/code/artifact/5b5d65f8-09cf-4ce8-89ee-bd8367047748)
**Builds on:** Plans 2A–3B, merged to master at `63bfe52`.

## Summary

The first sub-project of Plan 4 (Look & Feel). Until now every screen is
unstyled Godot controls built in code. This plan adds the design system
as code — tokens, fonts, icons, a `Theme` built by a `ThemeBuilder`, and
five shared components — and rebuilds the two screens the player sees
most between fights, **Map** and **Camp**, to the Torchlit mockups. Every
other screen inherits the theme's palette and type for free; their
layouts follow in Plans 4B (Combat) and 4C (the rest).

The direction, in one line: dark stone, one warm light source per
screen, quiet chrome; the humour lives in portraits, copy and motion —
never in the panels. Art is AI-generated later and drops in through an
`ArtPlaceholder` component that shows its prompt brief until an image
exists.

## 1. Scope

**In scope:**

- **Tokens** — `UiTokens` (typed consts: colours, font sizes, spacing,
  radii, durations) mirroring `Tokens.dc.html`.
- **Fonts** — Cinzel (display, numbers) and Source Sans 3 (body) as OFL
  variable `.ttf` files under `assets/fonts/`, with their licences.
- **Icons** — the mockups' stroke SVGs under `assets/icons/`, imported by
  Godot as textures.
- **`ThemeBuilder.build() -> Theme`** — the whole `Theme` in code:
  default font and colours, `Button` (+ variations `Primary`, `Ghost`,
  `Danger`, `NodeLocked`, `NodeVisited`, `NodeOpen`, `NodeCurrent`),
  `PanelContainer` (+ `Chip`), `Label` (+ `Display`, `Eyebrow`, `Muted`,
  `Number`), `ProgressBar`. Applied once on `RunScene`; children inherit.
- **Display settings** — 1440×900 base, `canvas_items` stretch, `keep`
  aspect.
- **Shared components** — `StatChip`, `StatBar`, `TorchGlow`,
  `ArtPlaceholder`, `StatusHeader`.
- **Map screen** rebuilt: vertical floors (bottom = start), icon node
  buttons with state styling, drawn connection paths, right column
  (party art, "Overheard" banter, relics and potions).
- **Camp screen** rebuilt to the mockup layout; behaviour unchanged.
- **`BanterContent`** — a dozen original "Overheard" lines for the Map.

**Explicitly out of scope (deferred):**

- Combat layout (Plan 4B): card frames, energy orb, intent chip, draw/
  discard piles, hover motion.
- Inventory, Skill Tree, Shop, Event, Rest, Victory, Game Over layouts
  (Plan 4C) — they get the theme's look automatically, nothing more.
- Real images (the `ArtPlaceholder` contract is how they arrive),
  audio, screen-transition motion, localisation, a `.tres` theme file,
  Godot editor `.tscn` layouts (the project builds UI in code and this
  plan follows that).

## 2. Tokens, fonts, icons

### 2.1 `UiTokens` (`scripts/ui/theme/ui_tokens.gd`, `class_name UiTokens`, `RefCounted`)

Typed constants only, taken verbatim from `Tokens.dc.html`:

| Group | Constants |
|---|---|
| Colours | `BG = Color("#14110f")`, `SURFACE = "#1f1a16"`, `SURFACE_2 = "#2a231d"`, `TEXT = "#ece3d3"`, `MUTED = "#8f857a"`, `DIM = "#7a7166"`, `EMBER = "#e8a44a"`, `EMBER_LIGHT = "#f3c274"`, `EMBER_DEEP = "#c9542b"`, `RUNE = "#74b0d6"`, `MOSS = "#8fae5c"`, `BLOOD = "#c94a3b"`, `LINE = Color(0.91, 0.64, 0.29, 0.26)` (ember at 26%), `LINE_SOFT = Color(1, 1, 1, 0.07)` |
| Type sizes | `FONT_EYEBROW = 12`, `FONT_BODY = 15`, `FONT_BANTER = 16`, `FONT_H2 = 20`, `FONT_NUMBER = 24`, `FONT_H1 = 40` |
| Spacing | `SPACE_1 = 4 … SPACE_6 = 32` (4, 8, 12, 16, 24, 32) |
| Radii | `RADIUS_BUTTON = 4`, `RADIUS_PANEL = 6`, `RADIUS_CARD = 8` |
| Sizes | `HIT_TARGET = 44`, `NODE_SIZE = 56`, `NODE_SIZE_BOSS = 72` |
| Motion | `FLICKER_SECONDS = 3.4`, `PULSE_SECONDS = 2.2`, `HOVER_SECONDS = 0.18` |

### 2.2 Fonts (`assets/fonts/`)

`Cinzel[wght].ttf` and `SourceSans3[wght].ttf` from the google/fonts
repository (`ofl/cinzel/`, `ofl/sourcesans3/`), each with its `OFL.txt`
beside it. `ThemeBuilder` exposes `static func display_font(weight: int)
-> FontVariation` and `static func body_font(weight: int) ->
FontVariation` (`variation_opentype = {"wght": weight}`), with fallbacks
to the engine default if a file fails to load (a warning, never a crash).

### 2.3 Icons (`assets/icons/`)

`sword, skull, quest, flame, coin, chest, crown, heart, shield, bolt,
flask, tree, bag, gem, cards, fang` as 20×20 stroke SVGs
(`stroke="currentColor"` replaced by `#ece3d3`; tinted at use via
`modulate`). `UiIcons.texture(name: StringName) -> Texture2D` loads
`res://assets/icons/<name>.svg` (`null` + warning if missing).
`MapNode.NodeType` → icon: COMBAT sword, ELITE skull, EVENT quest, REST
flame, SHOP coin, TREASURE chest, BOSS crown.

## 3. Theme and display

### 3.1 `ThemeBuilder` (`scripts/ui/theme/theme_builder.gd`, `class_name ThemeBuilder`)

`static func build() -> Theme` (memoised in a static var). Contents:

- **Defaults:** `default_font = body_font(400)`, `default_font_size =
  FONT_BODY`; `Label` `font_color = TEXT`.
- **Label variations:** `Display` (Cinzel 800, `FONT_H1`, `EMBER`),
  `Heading` (Cinzel 800, `FONT_H2`, `TEXT`), `Eyebrow` (Cinzel 800,
  `FONT_EYEBROW`, `EMBER`), `Number` (Cinzel 800, `FONT_NUMBER`,
  `EMBER`), `Muted` (body 400, `FONT_BODY`, `MUTED`), `Banter` (body 400,
  `FONT_BANTER`, `MUTED`; italics deferred — the italic font file is not
  shipped in 4A).
- **Button:** Cinzel 800, `FONT_BODY - 1`, `EMBER` text; `StyleBoxFlat`
  normal = ember at 7% fill, 1px `LINE`-strength ember border,
  `RADIUS_BUTTON`, content margins 22×12; hover = fill 14%; pressed =
  fill 20%; disabled = 40% opacity colours; `minimum_size.y =
  HIT_TARGET`. Variations: `Primary` (fill `EMBER`, text `BG`, border
  `EMBER_LIGHT`), `Ghost` (no border, `MUTED` text), `Danger` (text
  `#e07a66`, border `BLOOD` at 60%), and the four node variations
  (`NodeLocked` fill `#1a1613` border white 6% text `#4a423a`;
  `NodeVisited` fill `#221c17` border ember 18% text `DIM`; `NodeOpen`
  fill `SURFACE_2` border `EMBER` text `EMBER`; `NodeCurrent` fill
  `EMBER` border `EMBER_LIGHT` 2px text `BG`) — all node variations have
  corner radius 999 (circular) and `NODE_SIZE` minimum size.
- **PanelContainer:** `StyleBoxFlat` fill `SURFACE` at 94%, 1px `LINE`
  border, `RADIUS_PANEL`, shadow size 10 at 50% black, content margins
  16×14. Variation `Chip`: fill white 4%, border `LINE_SOFT`, radius 999,
  margins 10×5.
- **ProgressBar:** background `SURFACE_2` with 1px black 40% border,
  fill `EMBER`, both radius 4, `minimum_size.y = 8`; `show_percentage =
  false` is set by `StatBar`, not the theme.

`RunScene._ready()` sets `theme = ThemeBuilder.build()` on itself before
building children. Scenes instantiated alone in tests have no theme;
that is fine — nothing asserts on colours.

### 3.2 Display (`project.godot`)

```
[display]
window/size/viewport_width=1440
window/size/viewport_height=900
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"
```

## 4. Shared components (`scripts/ui/theme/`)

All `class_name`d, built in code, typed, no `.tscn`.

- **`StatChip extends PanelContainer`** — `theme_type_variation =
  &"Chip"`; `func setup(icon: StringName, text: String, tint: Color =
  UiTokens.TEXT) -> void`; public `icon_rect: TextureRect`, `label:
  Label`. `set_text(text)` updates the label.
- **`StatBar extends VBoxContainer`** — `func setup(caption: String,
  fill: Color) -> void`; `func set_values(value: int, max_value: int)`
  → caption row "`caption`" / "`value / max_value`" and a `ProgressBar`
  (`bar`) with the fill colour override. Public `caption_label`,
  `value_label`, `bar`.
- **`TorchGlow extends Control`** — draws a radial ember gradient
  (`_draw`: 24 concentric circles from `EMBER` 38% alpha to transparent)
  sized to its rect; `mouse_filter = IGNORE`; on `_ready` starts a
  looping `Tween` on `modulate.a` between 0.72 and 1.0 over
  `FLICKER_SECONDS` (skipped when `Engine.is_editor_hint()`; runs in
  headless tests harmlessly). `func set_radius(r: float)`.
- **`ArtPlaceholder extends PanelContainer`** — `func setup(art_id:
  StringName, brief: String, size: Vector2) -> void`. If
  `res://assets/art/<art_id>.png` exists, shows it in a `TextureRect`
  (`expand_mode = IGNORE_SIZE`, `stretch_mode = KEEP_ASPECT_COVERED`);
  otherwise a dashed-look panel (`LINE` border, black 25% fill) with a
  centred `Muted` label `"[art: <brief>]"`. Public `has_art: bool`,
  `label: Label`, `texture_rect: TextureRect` (null when placeholder).
  `const ART_DIR := "res://assets/art/"`.
- **`StatusHeader extends HBoxContainer`** — `func refresh() -> void`
  reads `RunState`: `level_label` (`Number` variation, `"LEVEL %d"`,
  or `"LEVEL %d · MAX"` at cap), `xp_bar: StatBar` ("XP", `EMBER`; hidden
  at max level), `skill_points_chip: StatChip` (tree icon, `"%d skill
  point(s)"`, ember tint, hidden when 0), `gold_chip` (coin, `"%d gold"`),
  `hp_chip` (heart, `"%d / %d"`, blood tint). `func set_gold_visible(v)`
  / `set_hp_visible(v)` because Camp shows neither (no run).

## 5. Map screen (`scripts/ui/run/map_view.gd`)

Signals and public buttons are unchanged: `node_selected(node)`,
`skill_tree_requested`, `inventory_requested`, `skill_tree_button`,
`inventory_button`. `display(map, current_node)` still rebuilds
everything from scratch with `remove_child` + `queue_free`.

**Layout (1440×900):**

- `TorchGlow` ×2 behind everything (top-left 520px, bottom-centre 480px).
- Top bar: `header: StatusHeader` (level, XP, skill points, gold, HP) left;
  `skill_tree_button` / `inventory_button` right with tree/bag icons.
- `floors_container: VBoxContainer` (was `HBoxContainer`) inside a
  `MarginContainer` occupying the left 940px: **one `HBoxContainer` row
  per floor, top row = boss floor, bottom row = floor 0**, rows spaced to
  fill the height, nodes centred. Each node is a `Button` with
  `theme_type_variation` = one of the four node variations, the type's
  icon, no text, `NODE_SIZE` (`NODE_SIZE_BOSS` for BOSS), `tooltip_text` =
  the type name. State: `current` = `current_node`; `open` = reachable
  and not visited (`node_a.connections` of a visited current node, or the
  current node itself when unvisited — the same rule as today); `visited`
  = `node.visited`; else `locked`. Only `open` (and an unvisited current)
  buttons are enabled.
- `paths: MapPaths` (`extends Control`, `mouse_filter = IGNORE`) drawn
  under the buttons: for every `connections` edge, a cubic bezier from the
  lower button's centre-top to the upper button's centre-bottom;
  `LINE`-coloured dashed for ordinary edges, solid `EMBER` 2px for edges
  from the current node to an open node. It re-reads button rects on
  `NOTIFICATION_RESIZED` and via `call_deferred("queue_redraw")` after
  `display()`, since containers lay out one frame later.
- Right column (400px): `party_art: ArtPlaceholder` (`&"map_party"`,
  brief "the party, torchlit, mid-argument — deeper corridor behind them
  each floor", 400×300); `banter_panel` (Eyebrow "Overheard", the line,
  a `Muted` attribution) fed by `BanterContent.get_overheard(rng)`;
  `relics_panel` (Eyebrow "Relics" + one gem `StatChip` per
  `RunState.unlocked_relics`, display names via `DwarfRelics.get_by_id`);
  `potions_panel` (Eyebrow "Potions" + one flask chip per
  `RunState.potions`, plus dashed "empty" chips up to `MAX_POTIONS`).
- Background: an `ArtPlaceholder` (`&"map_corridor"`, brief "corridor
  backdrop — three parallax layers: far vault, mid pillars, near arch;
  scrolls as you climb", 940×900) behind the floors; parallax itself is
  deferred to when the art exists.

**Test contract change:** tests stop indexing `floors_container`
children; `MapView` gains `func floor_count() -> int` and `func
node_button(floor_index: int, node_index: int) -> Button` (floor 0 =
start floor regardless of visual order). The status assertions move
from `status_label.text` to `header.level_label.text` and
`header.skill_points_chip.label.text`. `status_label` is removed.

### 5.1 `BanterContent` (`scripts/content/banter_content.gd`)

`static func get_overheard(rng: RandomNumberGenerator) -> Dictionary`
→ `{"line": String, "who": String}` from a hand-written list of at
least 12 **original** exchanges in the bickering-party register (no
Naheulbeuk characters, names, catchphrases or its signature "we're
lost" gag), e.g. `"Left at the skull, right at the other skull. Which
skull?"` / `"Hilde, to a corridor with no skulls in it"`. The player
character is named **Hilde Barrowdust** (placeholder; class Dwarf) —
`ClassResource.display_name` stays "Dwarf"; a new `ClassResource.
character_name: String = "Hilde Barrowdust"` carries the name.

## 6. Camp screen (`scripts/ui/camp/camp_scene.gd`)

Signals, buttons and `refresh()` semantics unchanged (including the
suspended-run swap from Plan 3B). Layout to `Camp.dc.html`:

- Left 820px: `camp_art: ArtPlaceholder` (`&"camp_fire"`, brief "camp: a
  low fire in a stone alcove, packs against the wall, the party arguing
  in silhouette; one of them is trying to light the fire with a
  spellbook", 820×900) with a `TorchGlow` over it.
- Right column (500px, at x 880): `Eyebrow` "Between expeditions",
  `Display` "Camp", `flavor_label` (`Banter` style; `FLAVOR_LINE` /
  `SUSPENDED_FLAVOR_LINE` as today), a `PanelContainer` holding
  `header: StatusHeader` (gold and HP hidden) and the **gear table** —
  three rows `gear_rows: Dictionary` keyed by `EquipmentResource.Slot`,
  each a `GearRow` (`HBoxContainer`: `slot_label` Eyebrow-sized muted,
  `name_label` body, `effect_label` muted; "— empty —" in `DIM` when the
  slot is empty; effect text from the item's `description`), then the
  buttons: `start_run_button` (`Primary`, flame icon, 56px tall),
  `skill_tree_button` + `inventory_button` (secondary, side by side),
  and the suspended variant `continue_run_button` (`Primary`) +
  `abandon_run_button` (`Danger`) — same visibility rule as Plan 3B.

**Test contract change:** `status_label` → `header.level_label` /
`header.skill_points_chip`; `gear_label` → `gear_rows[slot].name_label`.
Existing behavioural tests (signals, visibility swap, flavor lines) are
otherwise unchanged.

## 7. Error handling

- Missing font file → engine default font with a warning.
- Missing icon → `null` texture, button shows no icon, warning.
- Missing art → placeholder (by design, no warning).
- `MapPaths` with a node whose connection id is not on the map → that
  edge is skipped.

## 8. Testing

- `UiTokens`: a smoke test that the palette constants are the design's
  hex values (guards against typo drift).
- `ThemeBuilder`: `build()` returns the same `Theme` twice; the theme
  has the listed variations for `Button`, `Label`, `PanelContainer`;
  `display_font(800)` / `body_font(400)` return a `FontVariation`
  whose base font is loaded.
- `UiIcons`: every `NodeType` maps to a loadable texture; unknown name
  → `null`.
- Components: `StatChip.setup` sets label and icon; `StatBar.set_values`
  sets ratio and text; `ArtPlaceholder` shows the bracketed brief when
  no file exists and `has_art` false; `StatusHeader.refresh` reflects
  `RunState` (level, XP hidden at max, skill chip hidden at 0);
  `TorchGlow` instantiates and has a running tween.
- `MapView`: rewritten tests — `floor_count()`, `node_button(f, i)`
  enabled/disabled rules identical to today's, `theme_type_variation`
  per state, `node_selected` on press, `display()` twice leaves one
  root, header/level assertions, relics and potions chips count, banter
  panel non-empty, `paths` draws (edge count).
- `CampScene`: `gear_rows` names/empties, header level, existing signal
  and visibility tests.
- `BanterContent`: ≥ 12 entries, all with non-empty `line` and `who`,
  no duplicates.
- `RunScene`: `theme` is set after `_ready`.
- Any test asserting on values the combat turn loop touches keeps the
  `start_player_turn()` rule (untouched by this plan).

**Manual verification (non-negotiable):** run the game at 1440×900:
Camp matches `Camp.dc.html` (column, gear table, buttons, flicker);
Start Run → the Map matches `Main.dc.html` (vertical floors, node
states, lit paths from the current node, right column); click through
three nodes and watch paths/states update; open Inventory and Skill Tree
to confirm they inherited the theme legibly; resize the window to a
different aspect and confirm the 1440×900 canvas letterboxes rather
than distorts.

## Open items for later (explicitly out of scope now)

- Plan 4B Combat; Plan 4C remaining screens.
- Parallax corridor once the three backdrop layers exist.
- Screen transitions (dim-to-vignette, rise) and card hover motion.
- A real character-naming pass (Hilde Barrowdust is a placeholder).
