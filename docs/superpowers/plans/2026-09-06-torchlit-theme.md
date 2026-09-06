# Torchlit Theme Foundation, Map & Camp (Plan 4A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the Torchlit design system as code (tokens, fonts, icons, a
`Theme`, five shared components) and rebuild the Map and Camp screens to
the mockups, so every other screen inherits the look and the two
between-fight screens match `docs/design/look-and-feel/`.

**Architecture:** `UiTokens` holds the design values as typed consts;
`ThemeBuilder.build()` constructs one memoised `Theme` in code (fonts,
label/button/panel/bar styles and named variations) that `RunScene`
applies at its root so every child scene inherits it. Five small
components (`StatChip`, `StatBar`, `TorchGlow`, `ArtPlaceholder`,
`StatusHeader`) are the vocabulary the screens compose. `MapView` is
rebuilt vertical with icon node buttons, a `MapPaths` overlay that draws
the connections, and a right column (art, banter, relics, potions);
`CampScene` is rebuilt to the mockup with a gear table. Signals and
public buttons stay; two test contracts change and their tests are
rewritten.

**Tech Stack:** Godot 4.7.stable, GDScript (strict typing throughout), GUT
9.6.1 for tests; fonts Cinzel and Source Sans 3 (OFL, variable `.ttf`).

**Spec:** `docs/superpowers/specs/2026-09-06-torchlit-theme-design.md`
**Visual design:** `docs/design/look-and-feel/Main.dc.html` (Map),
`Camp.dc.html`, `Tokens.dc.html` — read them once; they are the target.

## Global Constraints

- Every `var`, parameter, and return type is explicitly typed (project
  convention, no exceptions).
- Tests drive the same entry point a real click would (emit a button's
  `pressed` signal or a scene's public signal) — never call a private
  `_on_*` handler directly. Tests that touch `RunState` extend
  `RunStateTest` and call `RunState.start_new_run(...)` /
  `enter_camp(...)` first.
- UI is built in code (no `.tscn`); components create their children in
  `_init()` so they are usable right after `.new()`.
- Colours, sizes, fonts come from `UiTokens` / `ThemeBuilder` — no
  literal hex values in screens or components except where the spec
  lists one (node-state fills, `#e07a66`).
- The palette is the design's: BG `#14110f`, SURFACE `#1f1a16`, SURFACE_2
  `#2a231d`, TEXT `#ece3d3`, MUTED `#8f857a`, DIM `#7a7166`, EMBER
  `#e8a44a`, EMBER_LIGHT `#f3c274`, EMBER_DEEP `#c9542b`, RUNE `#74b0d6`,
  MOSS `#8fae5c`, BLOOD `#c94a3b`.
- Public signals of `MapView` (`node_selected`, `skill_tree_requested`,
  `inventory_requested`) and `CampScene` (`skill_tree_requested`,
  `inventory_requested`, `run_requested`, `continue_requested`,
  `abandon_requested`) and their public buttons keep their names.
  `MapView.status_label` and `CampScene.status_label`/`gear_label` are
  removed; `MapView.floor_count()` / `node_button(floor, i)`,
  `CampScene.header` / `gear_rows` replace them.
- Missing font/icon → warning and fallback, never a crash. Missing art →
  placeholder, no warning.
- No Naheulbeuk characters, names, catchphrases or dialogue; no
  character identified only by a class noun. The player character is
  **Hilde Barrowdust** (placeholder name), class Dwarf.
- Out of scope: Combat layout, the other screens' layouts, real images,
  audio, screen transitions, localisation, `.tres` theme files.

## Environment notes (read before running anything)

- Test command (repo root, Bash tool):
  `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
  (~8 s; `-gtest=` does NOT narrow the run — read the totals / per-script lines).
- **After creating any new `.gd`, `.svg`, `.ttf` or `.png` file** run
  `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless --import`
  once — it registers scripts and generates `.import` files for assets;
  otherwise GUT silently skips new scripts and `load()` of a new asset
  fails. Then `git checkout -- addons/` before committing (the import
  rewrites addon line endings). Commit the generated `.import` files and
  `.gd.uid` files next to new assets/scripts.
- Checked-out files are CRLF; use the Edit tool for targeted edits and
  heredocs/Write only for whole new files.
- Never commit anything under `.superpowers/`.
- Baseline at plan start: 40 scripts / 316 tests, all passing, at
  `814c7fb`.

---

## Pre-existing code this plan builds on (read-only unless a task says so)

- `scripts/ui/run/map_view.gd` — `MapView extends Control`: signals
  `node_selected(node: MapNode)`, `skill_tree_requested`,
  `inventory_requested`; `status_label`, `skill_tree_button`,
  `inventory_button`, `floors_container: HBoxContainer`; `display(map:
  MapGraph, current_node: MapNode)` rebuilds children (remove_child +
  queue_free) as an HBox of per-floor VBoxes of text buttons; reachable
  rule: `current_node.connections` if `current_node.visited` else
  `[current_node.id]`; `button.disabled = node.visited or not
  reachable_ids.has(node.id)`. **Replaced wholesale in Task 5.**
- `scripts/ui/camp/camp_scene.gd` — `CampScene extends Control` with
  the five signals, `FLAVOR_LINE`, `SUSPENDED_FLAVOR_LINE`, `EMPTY_SLOT`,
  labels/buttons, `refresh()` toggling button visibility on
  `SaveManager.has_run_snapshot()`. **Replaced wholesale in Task 6.**
- `scripts/ui/run/run_scene.gd` — `_ready()` builds `map_view`, calls
  `SaveManager.load_game()`, `RunState.enter_camp(...)`, `_show_camp()`.
  Modified by Task 7.
- `scripts/resources/class_resource.gd` — `ClassResource`: `id`,
  `display_name`, `base_hp`, `starting_deck`. Modified by Task 4.
- `scripts/content/dwarf_content.gd` — `get_class_resource()` sets
  `display_name = "Dwarf"`. Modified by Task 4.
- `scripts/run/map_node.gd` — `MapNode`: `id`, `node_type: NodeType
  {COMBAT, ELITE, EVENT, REST, SHOP, BOSS, TREASURE}`, `floor`,
  `connections: Array[int]`, `visited`.
- `scripts/run/run_state.gd` — fields read by the header/screens:
  `level`, `xp`, `skill_points`, `gold`, `player_current_hp`,
  `player_max_hp`, `unlocked_relics: Array[StringName]`, `potions:
  Array[PotionResource]`, `equipped_weapon/armor/trinket`, `rng`,
  `MAX_LEVEL`, `XP_THRESHOLDS`, `MAX_POTIONS`. `DwarfRelics.get_by_id`,
  `DwarfEquipment.get_by_id` exist.
- `tests/unit/run_state_test.gd` — `RunStateTest` base (`before_each`
  resets `MetaState`, points `SaveManager` at a test file, nulls
  `run_snapshot`).
- `tests/unit/test_map_view.gd` (9 tests, index `floors_container`
  children), `tests/unit/test_camp_scene.gd` (10 tests, read
  `status_label`/`gear_label`), `tests/unit/test_run_scene.gd:189`
  (`scene.camp_scene.status_label.text.begins_with("Lv 3")`).
- `project.godot` — no `[display]` section.

---

### Task 1: Assets, display settings, `UiTokens`, `UiIcons`

**Files:**
- Create: `assets/fonts/Cinzel[wght].ttf`, `assets/fonts/SourceSans3[wght].ttf`, `assets/fonts/OFL-Cinzel.txt`, `assets/fonts/OFL-SourceSans3.txt`
- Create: `assets/icons/<16 names>.svg`
- Create: `assets/art/README.md`
- Create: `scripts/ui/theme/ui_tokens.gd`, `scripts/ui/theme/ui_icons.gd`
- Modify: `project.godot`
- Test: `tests/unit/test_ui_tokens.gd`, `tests/unit/test_ui_icons.gd`

**Interfaces:**
- Produces: `UiTokens` consts (see Step 3); `UiIcons.texture(name:
  StringName) -> Texture2D` (`null` + warning when missing),
  `UiIcons.for_node_type(node_type: MapNode.NodeType) -> Texture2D`,
  `UiIcons.NODE_ICONS: Dictionary`. Consumed by every later task.

- [ ] **Step 1: Fetch the fonts and write the icons**

From the repo root:

```bash
mkdir -p assets/fonts assets/icons assets/art
curl -sSL -o "assets/fonts/Cinzel[wght].ttf" "https://raw.githubusercontent.com/google/fonts/main/ofl/cinzel/Cinzel%5Bwght%5D.ttf"
curl -sSL -o "assets/fonts/SourceSans3[wght].ttf" "https://raw.githubusercontent.com/google/fonts/main/ofl/sourcesans3/SourceSans3%5Bwght%5D.ttf"
curl -sSL -o "assets/fonts/OFL-Cinzel.txt" "https://raw.githubusercontent.com/google/fonts/main/ofl/cinzel/OFL.txt"
curl -sSL -o "assets/fonts/OFL-SourceSans3.txt" "https://raw.githubusercontent.com/google/fonts/main/ofl/sourcesans3/OFL.txt"
ls -la assets/fonts
```

Expected: the two `.ttf` files are ~125 KB and ~646 KB (a 9-byte file is
a "Not Found" page — re-check the URL).

Write the icons with this Python snippet (run from the repo root):

```bash
python - <<'PY'
import io, os
paths = {
    "sword":  '<path d="M4 16l9-9"/><path d="M13 7l3-3 1 1-3 3"/><path d="M3 17l2 2"/><path d="M6 14l2 2"/>',
    "skull":  '<circle cx="10" cy="9" r="6"/><circle cx="8" cy="9" r="1"/><circle cx="12" cy="9" r="1"/><path d="M7 15v3M13 15v3M10 15v3"/>',
    "quest":  '<path d="M7 7a3 3 0 1 1 4 3c-1 .5-1 1-1 2"/><circle cx="10" cy="15.5" r=".8"/>',
    "flame":  '<path d="M10 3c1 3 4 4 4 8a4 4 0 0 1-8 0c0-2 1-3 2-4 0 1 .5 2 1 2 0-2 .5-4 1-6z"/>',
    "coin":   '<circle cx="10" cy="10" r="6"/><path d="M8 10h4M10 8v4"/>',
    "chest":  '<rect x="4" y="8" width="12" height="8" rx="1"/><path d="M4 11h12M10 11v2"/><path d="M6 8V6h8v2"/>',
    "crown":  '<path d="M4 15l1-8 3 4 2-5 2 5 3-4 1 8z"/>',
    "heart":  '<path d="M10 16s-6-3.5-6-8a3 3 0 0 1 6-1 3 3 0 0 1 6 1c0 4.5-6 8-6 8z"/>',
    "shield": '<path d="M10 3l6 2v5c0 4-3 6-6 7-3-1-6-3-6-7V5z"/>',
    "bolt":   '<path d="M11 3L5 11h4l-1 6 6-8h-4z"/>',
    "flask":  '<path d="M8 3h4M9 3v5l-4 7a1 1 0 0 0 1 2h8a1 1 0 0 0 1-2l-4-7V3"/>',
    "tree":   '<path d="M10 17V9"/><path d="M6 13h8"/><circle cx="10" cy="6" r="3"/><circle cx="5" cy="13" r="2"/><circle cx="15" cy="13" r="2"/>',
    "bag":    '<path d="M5 8h10l-1 9H6z"/><path d="M8 8V6a2 2 0 0 1 4 0v2"/>',
    "gem":    '<path d="M6 4h8l3 4-7 9-7-9z"/><path d="M3 8h14M9 4l1 13M11 4l-1 13"/>',
    "cards":  '<rect x="5" y="5" width="9" height="12" rx="1"/><path d="M8 3h9v12"/>',
    "fang":   '<path d="M6 4l4 12 4-12"/><path d="M6 4h8"/>',
}
for name, body in paths.items():
    svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 20 20" fill="none" '
           'stroke="#ece3d3" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">' + body + '</svg>\n')
    io.open(os.path.join("assets/icons", name + ".svg"), "w", encoding="utf-8", newline="\n").write(svg)
print("wrote", len(paths), "icons")
PY
```

Create `assets/art/README.md`:

```markdown
# Art

Drop AI-generated images here as `<art_id>.png`; `ArtPlaceholder` shows
them automatically (until then it shows the bracketed brief). Ids and
briefs used by Plan 4A:

| art_id | size (px) | brief |
|---|---|---|
| `map_party` | 400×300 | the party, torchlit, mid-argument over which way the torch smoke is blowing — deeper corridor behind them each floor |
| `map_corridor` | 940×900 | corridor backdrop — three parallax layers: far vault, mid pillars, near arch; scrolls as you climb |
| `camp_fire` | 820×900 | camp: a low fire in a stone alcove, packs against the wall, the party arguing in silhouette; one of them is trying to light the fire with a spellbook |

Style: dark stone, one warm ember light source, painterly, original cast
(Hilde Barrowdust, dwarf; companions unnamed for now).
```

- [ ] **Step 2: Add the display settings**

In `project.godot`, after the `[autoload]` section, add:

```
[display]

window/size/viewport_width=1440
window/size/viewport_height=900
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"
```

- [ ] **Step 3: Write the failing tests**

Create `tests/unit/test_ui_tokens.gd`:

```gdscript
extends GutTest

func test_palette_matches_the_design_sheet():
	assert_eq(UiTokens.BG.to_html(false), "14110f")
	assert_eq(UiTokens.SURFACE.to_html(false), "1f1a16")
	assert_eq(UiTokens.TEXT.to_html(false), "ece3d3")
	assert_eq(UiTokens.EMBER.to_html(false), "e8a44a")
	assert_eq(UiTokens.RUNE.to_html(false), "74b0d6")
	assert_eq(UiTokens.BLOOD.to_html(false), "c94a3b")
	assert_almost_eq(UiTokens.LINE.a, 0.26, 0.001)

func test_sizes_match_the_design_sheet():
	assert_eq(UiTokens.FONT_BODY, 15)
	assert_eq(UiTokens.FONT_H1, 40)
	assert_eq(UiTokens.HIT_TARGET, 44)
	assert_eq(UiTokens.NODE_SIZE, 56)
	assert_eq(UiTokens.SPACE_6, 32)
	assert_almost_eq(UiTokens.FLICKER_SECONDS, 3.4, 0.001)
```

Create `tests/unit/test_ui_icons.gd`:

```gdscript
extends GutTest

func test_every_node_type_has_a_loadable_icon():
	for node_type in MapNode.NodeType.values():
		assert_not_null(UiIcons.for_node_type(node_type), "NodeType %d" % node_type)

func test_named_icons_load():
	for name in [&"heart", &"shield", &"bolt", &"flask", &"tree", &"bag", &"gem", &"cards", &"fang"]:
		assert_not_null(UiIcons.texture(name), String(name))

func test_unknown_icon_returns_null():
	assert_null(UiIcons.texture(&"no_such_icon"))
```

- [ ] **Step 4: Run the import, then the suite, to see the new tests fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless --import` then the test command.
Expected: the two new scripts fail to load (`UiTokens` / `UiIcons` not declared).

- [ ] **Step 5: Write `UiTokens` and `UiIcons`**

Create `scripts/ui/theme/ui_tokens.gd`:

```gdscript
extends RefCounted
class_name UiTokens

# The Torchlit design system as typed constants — the single source for
# colours, type sizes, spacing, radii and motion. Mirrors
# docs/design/look-and-feel/Tokens.dc.html.

const BG := Color("#14110f")
const SURFACE := Color("#1f1a16")
const SURFACE_2 := Color("#2a231d")
const TEXT := Color("#ece3d3")
const MUTED := Color("#8f857a")
const DIM := Color("#7a7166")
const EMBER := Color("#e8a44a")
const EMBER_LIGHT := Color("#f3c274")
const EMBER_DEEP := Color("#c9542b")
const RUNE := Color("#74b0d6")
const MOSS := Color("#8fae5c")
const BLOOD := Color("#c94a3b")
const LINE := Color(0.91, 0.64, 0.29, 0.26)
const LINE_SOFT := Color(1.0, 1.0, 1.0, 0.07)

const FONT_EYEBROW := 12
const FONT_BODY := 15
const FONT_BANTER := 16
const FONT_H2 := 20
const FONT_NUMBER := 24
const FONT_H1 := 40

const SPACE_1 := 4
const SPACE_2 := 8
const SPACE_3 := 12
const SPACE_4 := 16
const SPACE_5 := 24
const SPACE_6 := 32

const RADIUS_BUTTON := 4
const RADIUS_PANEL := 6
const RADIUS_CARD := 8

const HIT_TARGET := 44
const NODE_SIZE := 56
const NODE_SIZE_BOSS := 72

const FLICKER_SECONDS := 3.4
const PULSE_SECONDS := 2.2
const HOVER_SECONDS := 0.18

static func ember(alpha: float) -> Color:
	return Color(EMBER.r, EMBER.g, EMBER.b, alpha)
```

Create `scripts/ui/theme/ui_icons.gd`:

```gdscript
extends RefCounted
class_name UiIcons

# Stroke icons from the design (assets/icons/*.svg, imported by Godot as
# textures). Tint at use with `modulate`.

const ICON_DIR := "res://assets/icons/"
const NODE_ICONS: Dictionary = {
	MapNode.NodeType.COMBAT: &"sword",
	MapNode.NodeType.ELITE: &"skull",
	MapNode.NodeType.EVENT: &"quest",
	MapNode.NodeType.REST: &"flame",
	MapNode.NodeType.SHOP: &"coin",
	MapNode.NodeType.TREASURE: &"chest",
	MapNode.NodeType.BOSS: &"crown",
}

static func texture(name: StringName) -> Texture2D:
	var path: String = ICON_DIR + String(name) + ".svg"
	if not ResourceLoader.exists(path):
		push_warning("UiIcons: missing icon '%s'" % name)
		return null
	return load(path) as Texture2D

static func for_node_type(node_type: MapNode.NodeType) -> Texture2D:
	return texture(NODE_ICONS[node_type])
```

- [ ] **Step 6: Import again and run the suite**

Run the import, then the test command.
Expected: PASS, 42 scripts, 321 tests. `assets/icons/*.svg.import` and
`assets/fonts/*.ttf.import` files now exist.

- [ ] **Step 7: Commit**

```bash
git checkout -- addons/
git add project.godot assets/fonts assets/icons assets/art/README.md scripts/ui/theme/ui_tokens.gd scripts/ui/theme/ui_tokens.gd.uid scripts/ui/theme/ui_icons.gd scripts/ui/theme/ui_icons.gd.uid tests/unit/test_ui_tokens.gd tests/unit/test_ui_tokens.gd.uid tests/unit/test_ui_icons.gd tests/unit/test_ui_icons.gd.uid
git commit -m "feat: add Torchlit tokens, fonts, icons and 1440x900 display settings"
```

---

### Task 2: `ThemeBuilder`

**Files:**
- Create: `scripts/ui/theme/theme_builder.gd`
- Test: `tests/unit/test_theme_builder.gd`

**Interfaces:**
- Consumes: `UiTokens` (Task 1), the two font files.
- Produces: `ThemeBuilder.build() -> Theme` (memoised),
  `ThemeBuilder.display_font(weight: int) -> FontVariation`,
  `ThemeBuilder.body_font(weight: int) -> FontVariation`; theme type
  variations: Button `Primary`, `Ghost`, `Danger`, `NodeLocked`,
  `NodeVisited`, `NodeOpen`, `NodeCurrent`; PanelContainer `Chip`; Label
  `Display`, `Heading`, `Eyebrow`, `Number`, `Muted`, `Banter`. Consumed by
  Tasks 3–7.

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_theme_builder.gd`:

```gdscript
extends GutTest

func test_build_is_memoised():
	assert_eq(ThemeBuilder.build(), ThemeBuilder.build())

func test_fonts_load_as_variations_of_the_bundled_files():
	var display := ThemeBuilder.display_font(800)
	var body := ThemeBuilder.body_font(400)
	assert_true(display.base_font is FontFile)
	assert_true(body.base_font is FontFile)
	assert_true(display.variation_opentype.has(TextServer.name_to_tag("weight")))
	assert_eq(int(display.variation_opentype[TextServer.name_to_tag("weight")]), 800)

func test_theme_defines_the_button_variations():
	var theme := ThemeBuilder.build()
	for variation in [&"Primary", &"Ghost", &"Danger", &"NodeLocked", &"NodeVisited", &"NodeOpen", &"NodeCurrent"]:
		assert_eq(theme.get_type_variation_base(variation), &"Button", String(variation))
		assert_true(theme.has_stylebox(&"normal", variation), "%s has a normal stylebox" % variation)

func test_theme_defines_label_and_panel_variations():
	var theme := ThemeBuilder.build()
	for variation in [&"Display", &"Heading", &"Eyebrow", &"Number", &"Muted", &"Banter"]:
		assert_eq(theme.get_type_variation_base(variation), &"Label", String(variation))
		assert_true(theme.has_font_size(&"font_size", variation), String(variation))
	assert_eq(theme.get_type_variation_base(&"Chip"), &"PanelContainer")
	assert_true(theme.has_stylebox(&"panel", &"PanelContainer"))
	assert_true(theme.has_stylebox(&"fill", &"ProgressBar"))

func test_theme_defaults_use_the_body_font_and_text_colour():
	var theme := ThemeBuilder.build()
	assert_true(theme.default_font is FontVariation)
	assert_eq(theme.default_font_size, UiTokens.FONT_BODY)
	assert_eq(theme.get_color(&"font_color", &"Label"), UiTokens.TEXT)
```

- [ ] **Step 2: Import, run, verify the new script fails to load**

Run the import, then the test command. Expected: `ThemeBuilder` not declared.

- [ ] **Step 3: Write `ThemeBuilder`**

Create `scripts/ui/theme/theme_builder.gd`:

```gdscript
extends RefCounted
class_name ThemeBuilder

# Builds the Torchlit Theme in code (the project builds all UI in code;
# a .tres would be a second source of truth). RunScene applies it once
# at its root; every child scene inherits it.

const DISPLAY_FONT_PATH := "res://assets/fonts/Cinzel[wght].ttf"
const BODY_FONT_PATH := "res://assets/fonts/SourceSans3[wght].ttf"

static var _theme: Theme = null

static func build() -> Theme:
	if _theme != null:
		return _theme
	var theme := Theme.new()
	theme.default_font = body_font(400)
	theme.default_font_size = UiTokens.FONT_BODY
	_build_labels(theme)
	_build_buttons(theme)
	_build_panels(theme)
	_build_progress_bar(theme)
	_theme = theme
	return theme

static func display_font(weight: int) -> FontVariation:
	return _variation(DISPLAY_FONT_PATH, weight)

static func body_font(weight: int) -> FontVariation:
	return _variation(BODY_FONT_PATH, weight)

static func _variation(path: String, weight: int) -> FontVariation:
	var variation := FontVariation.new()
	if ResourceLoader.exists(path):
		variation.base_font = load(path) as Font
	else:
		push_warning("ThemeBuilder: font %s missing, using the engine fallback" % path)
		variation.base_font = ThemeDB.fallback_font
	variation.variation_opentype = {TextServer.name_to_tag("weight"): weight}
	return variation

static func _flat(fill: Color, border: Color, border_width: int, radius: int, margin_x: int, margin_y: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = margin_x
	box.content_margin_right = margin_x
	box.content_margin_top = margin_y
	box.content_margin_bottom = margin_y
	return box

static func _label_variation(theme: Theme, name: StringName, font: FontVariation, size: int, color: Color) -> void:
	theme.set_type_variation(name, &"Label")
	theme.set_font(&"font", name, font)
	theme.set_font_size(&"font_size", name, size)
	theme.set_color(&"font_color", name, color)

static func _build_labels(theme: Theme) -> void:
	theme.set_color(&"font_color", &"Label", UiTokens.TEXT)
	_label_variation(theme, &"Display", display_font(800), UiTokens.FONT_H1, UiTokens.EMBER)
	_label_variation(theme, &"Heading", display_font(800), UiTokens.FONT_H2, UiTokens.TEXT)
	_label_variation(theme, &"Eyebrow", display_font(800), UiTokens.FONT_EYEBROW, UiTokens.EMBER)
	_label_variation(theme, &"Number", display_font(800), UiTokens.FONT_NUMBER, UiTokens.EMBER)
	_label_variation(theme, &"Muted", body_font(400), UiTokens.FONT_BODY, UiTokens.MUTED)
	_label_variation(theme, &"Banter", body_font(400), UiTokens.FONT_BANTER, UiTokens.MUTED)

static func _button_colors(theme: Theme, type_name: StringName, color: Color) -> void:
	var disabled := Color(color.r, color.g, color.b, 0.4)
	for key in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color", &"icon_normal_color", &"icon_hover_color", &"icon_pressed_color", &"icon_focus_color"]:
		theme.set_color(key, type_name, color)
	theme.set_color(&"font_disabled_color", type_name, disabled)
	theme.set_color(&"icon_disabled_color", type_name, disabled)

static func _button_styles(theme: Theme, type_name: StringName, fill: Color, border: Color, border_width: int, radius: int, margin_x: int, margin_y: int) -> void:
	var hover := Color(fill.r, fill.g, fill.b, minf(fill.a * 2.0, 1.0))
	var pressed := Color(fill.r, fill.g, fill.b, minf(fill.a * 3.0, 1.0))
	var disabled_fill := Color(fill.r, fill.g, fill.b, fill.a * 0.4)
	var disabled_border := Color(border.r, border.g, border.b, border.a * 0.4)
	theme.set_stylebox(&"normal", type_name, _flat(fill, border, border_width, radius, margin_x, margin_y))
	theme.set_stylebox(&"hover", type_name, _flat(hover, border, border_width, radius, margin_x, margin_y))
	theme.set_stylebox(&"pressed", type_name, _flat(pressed, border, border_width, radius, margin_x, margin_y))
	theme.set_stylebox(&"disabled", type_name, _flat(disabled_fill, disabled_border, border_width, radius, margin_x, margin_y))
	theme.set_stylebox(&"focus", type_name, StyleBoxEmpty.new())

static func _build_buttons(theme: Theme) -> void:
	theme.set_font(&"font", &"Button", display_font(800))
	theme.set_font_size(&"font_size", &"Button", UiTokens.FONT_BODY - 1)
	_button_colors(theme, &"Button", UiTokens.EMBER)
	_button_styles(theme, &"Button", UiTokens.ember(0.07), UiTokens.ember(0.55), 1, UiTokens.RADIUS_BUTTON, 22, 12)

	theme.set_type_variation(&"Primary", &"Button")
	_button_colors(theme, &"Primary", UiTokens.BG)
	var primary := _flat(UiTokens.EMBER, UiTokens.EMBER_LIGHT, 1, UiTokens.RADIUS_BUTTON, 22, 12)
	theme.set_stylebox(&"normal", &"Primary", primary)
	theme.set_stylebox(&"hover", &"Primary", _flat(UiTokens.EMBER_LIGHT, UiTokens.EMBER_LIGHT, 1, UiTokens.RADIUS_BUTTON, 22, 12))
	theme.set_stylebox(&"pressed", &"Primary", _flat(UiTokens.EMBER_DEEP, UiTokens.EMBER_LIGHT, 1, UiTokens.RADIUS_BUTTON, 22, 12))
	theme.set_stylebox(&"disabled", &"Primary", _flat(UiTokens.ember(0.3), UiTokens.ember(0.3), 1, UiTokens.RADIUS_BUTTON, 22, 12))
	theme.set_stylebox(&"focus", &"Primary", StyleBoxEmpty.new())

	theme.set_type_variation(&"Ghost", &"Button")
	_button_colors(theme, &"Ghost", UiTokens.MUTED)
	_button_styles(theme, &"Ghost", Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, UiTokens.RADIUS_BUTTON, 22, 12)

	theme.set_type_variation(&"Danger", &"Button")
	_button_colors(theme, &"Danger", Color("#e07a66"))
	var blood := UiTokens.BLOOD
	_button_styles(theme, &"Danger", Color(blood.r, blood.g, blood.b, 0.08), Color(blood.r, blood.g, blood.b, 0.6), 1, UiTokens.RADIUS_BUTTON, 22, 12)

	_node_variation(theme, &"NodeLocked", Color("#1a1613"), Color(1, 1, 1, 0.06), 1, Color("#4a423a"))
	_node_variation(theme, &"NodeVisited", Color("#221c17"), UiTokens.ember(0.18), 1, UiTokens.DIM)
	_node_variation(theme, &"NodeOpen", UiTokens.SURFACE_2, UiTokens.EMBER, 1, UiTokens.EMBER)
	_node_variation(theme, &"NodeCurrent", UiTokens.EMBER, UiTokens.EMBER_LIGHT, 2, UiTokens.BG)

static func _node_variation(theme: Theme, name: StringName, fill: Color, border: Color, border_width: int, icon_color: Color) -> void:
	theme.set_type_variation(name, &"Button")
	_button_colors(theme, name, icon_color)
	var box := _flat(fill, border, border_width, 999, 0, 0)
	theme.set_stylebox(&"normal", name, box)
	theme.set_stylebox(&"hover", name, box)
	theme.set_stylebox(&"pressed", name, box)
	theme.set_stylebox(&"disabled", name, box)
	theme.set_stylebox(&"focus", name, StyleBoxEmpty.new())

static func _build_panels(theme: Theme) -> void:
	var surface := UiTokens.SURFACE
	var panel := _flat(Color(surface.r, surface.g, surface.b, 0.94), UiTokens.LINE, 1, UiTokens.RADIUS_PANEL, 16, 14)
	panel.shadow_size = 10
	panel.shadow_color = Color(0, 0, 0, 0.5)
	theme.set_stylebox(&"panel", &"PanelContainer", panel)
	theme.set_type_variation(&"Chip", &"PanelContainer")
	theme.set_stylebox(&"panel", &"Chip", _flat(Color(1, 1, 1, 0.04), UiTokens.LINE_SOFT, 1, 999, 10, 5))

static func _build_progress_bar(theme: Theme) -> void:
	theme.set_stylebox(&"background", &"ProgressBar", _flat(UiTokens.SURFACE_2, Color(0, 0, 0, 0.4), 1, 4, 0, 0))
	theme.set_stylebox(&"fill", &"ProgressBar", _flat(UiTokens.EMBER, Color(0, 0, 0, 0), 0, 4, 0, 0))
```

- [ ] **Step 4: Import, run the suite**

Expected: PASS, 43 scripts, 326 tests.

- [ ] **Step 5: Commit**

```bash
git checkout -- addons/
git add scripts/ui/theme/theme_builder.gd scripts/ui/theme/theme_builder.gd.uid tests/unit/test_theme_builder.gd tests/unit/test_theme_builder.gd.uid
git commit -m "feat: add ThemeBuilder constructing the Torchlit Theme in code"
```

---

### Task 3: `StatChip`, `StatBar`, `TorchGlow`, `ArtPlaceholder`

**Files:**
- Create: `scripts/ui/theme/stat_chip.gd`, `scripts/ui/theme/stat_bar.gd`, `scripts/ui/theme/torch_glow.gd`, `scripts/ui/theme/art_placeholder.gd`
- Test: `tests/unit/test_ui_components.gd`

**Interfaces:**
- Consumes: `UiTokens`, `UiIcons` (Task 1).
- Produces: `StatChip extends PanelContainer` — `setup(icon: StringName,
  text: String, tint: Color = UiTokens.TEXT)`, `set_text(text: String)`,
  `icon_rect: TextureRect`, `label: Label`. `StatBar extends
  VBoxContainer` — `setup(caption: String, fill: Color)`,
  `set_values(value: int, max_value: int)`, `caption_label`,
  `value_label`, `bar: ProgressBar`. `TorchGlow extends Control` —
  `radius: float`, `set_radius(r: float)`, `is_flickering() -> bool`.
  `ArtPlaceholder extends PanelContainer` — `const ART_DIR`,
  `setup(art_id: StringName, brief: String, art_size: Vector2)`,
  `has_art: bool`, `label: Label`, `texture_rect: TextureRect`. Consumed
  by Tasks 4–6.

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_ui_components.gd`:

```gdscript
extends GutTest

func test_stat_chip_shows_icon_text_and_tint():
	var chip := StatChip.new()
	add_child_autofree(chip)
	chip.setup(&"heart", "21 / 36", UiTokens.BLOOD)
	assert_not_null(chip.icon_rect.texture)
	assert_eq(chip.label.text, "21 / 36")
	assert_eq(chip.icon_rect.modulate, UiTokens.BLOOD)
	assert_eq(chip.theme_type_variation, &"Chip")
	chip.set_text("5 / 36")
	assert_eq(chip.label.text, "5 / 36")

func test_stat_bar_shows_caption_and_ratio():
	var bar := StatBar.new()
	add_child_autofree(bar)
	bar.setup("XP", UiTokens.EMBER)
	bar.set_values(7, 30)
	assert_eq(bar.caption_label.text, "XP")
	assert_eq(bar.value_label.text, "7 / 30")
	assert_eq(bar.bar.max_value, 30.0)
	assert_eq(bar.bar.value, 7.0)
	assert_false(bar.bar.show_percentage)

func test_stat_bar_tolerates_a_zero_maximum():
	var bar := StatBar.new()
	add_child_autofree(bar)
	bar.setup("XP", UiTokens.EMBER)
	bar.set_values(0, 0)
	assert_eq(bar.value_label.text, "0 / 0")
	assert_true(bar.bar.max_value > 0.0, "ProgressBar needs max > min; the bar clamps to 1.")

func test_torch_glow_ignores_the_mouse_and_flickers():
	var glow := TorchGlow.new()
	glow.set_radius(120.0)
	add_child_autofree(glow)
	assert_eq(glow.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(glow.custom_minimum_size, Vector2(240, 240))
	assert_true(glow.is_flickering())

func test_art_placeholder_shows_the_brief_when_no_image_exists():
	var art := ArtPlaceholder.new()
	add_child_autofree(art)
	art.setup(&"no_such_art", "the party, torchlit", Vector2(400, 300))
	assert_false(art.has_art)
	assert_null(art.texture_rect)
	assert_eq(art.label.text, "[art: the party, torchlit]")
	assert_eq(art.custom_minimum_size, Vector2(400, 300))

func test_art_placeholder_can_be_set_up_twice():
	var art := ArtPlaceholder.new()
	add_child_autofree(art)
	art.setup(&"a", "first", Vector2(10, 10))
	art.setup(&"b", "second", Vector2(20, 20))
	assert_eq(art.label.text, "[art: second]")
	assert_eq(art.get_child_count(), 1, "setup() replaces its previous content.")
```

- [ ] **Step 2: Import, run, verify the new script fails to load**

Expected: `StatChip` (etc.) not declared.

- [ ] **Step 3: Write the four components**

Create `scripts/ui/theme/stat_chip.gd`:

```gdscript
extends PanelContainer
class_name StatChip

# A pill with an icon and a short value ("21 / 36", "25 gold").

var icon_rect: TextureRect
var label: Label

func _init() -> void:
	theme_type_variation = &"Chip"
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override(&"separation", UiTokens.SPACE_2)
	add_child(hbox)
	icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(16, 16)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(icon_rect)
	label = Label.new()
	hbox.add_child(label)

func setup(icon: StringName, text: String, tint: Color = UiTokens.TEXT) -> void:
	icon_rect.texture = UiIcons.texture(icon)
	icon_rect.modulate = tint
	label.text = text
	label.add_theme_color_override(&"font_color", tint)

func set_text(text: String) -> void:
	label.text = text
```

Create `scripts/ui/theme/stat_bar.gd`:

```gdscript
extends VBoxContainer
class_name StatBar

# Caption row ("XP" ... "7 / 30") over a thin ProgressBar.

var caption_label: Label
var value_label: Label
var bar: ProgressBar

func _init() -> void:
	add_theme_constant_override(&"separation", UiTokens.SPACE_2)
	var row := HBoxContainer.new()
	add_child(row)
	caption_label = Label.new()
	caption_label.theme_type_variation = &"Muted"
	caption_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption_label)
	value_label = Label.new()
	value_label.theme_type_variation = &"Muted"
	row.add_child(value_label)
	bar = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	add_child(bar)

func setup(caption: String, fill: Color) -> void:
	caption_label.text = caption
	var fill_box := StyleBoxFlat.new()
	fill_box.bg_color = fill
	fill_box.set_corner_radius_all(4)
	bar.add_theme_stylebox_override(&"fill", fill_box)

func set_values(value: int, max_value: int) -> void:
	bar.max_value = maxi(max_value, 1)
	bar.value = value
	value_label.text = "%d / %d" % [value, max_value]
```

Create `scripts/ui/theme/torch_glow.gd`:

```gdscript
extends Control
class_name TorchGlow

# A soft ember bloom that flickers — the one light source per screen.
# Purely decorative: ignores the mouse, never carries text.

const STEPS := 24
const PEAK_ALPHA := 0.02  # per ring; 24 rings stack to ~38% at the centre

var radius: float = 240.0
var _tween: Tween = null

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_radius(radius)

func _ready() -> void:
	_start_flicker()
	queue_redraw()

func set_radius(r: float) -> void:
	radius = r
	custom_minimum_size = Vector2(r * 2.0, r * 2.0)
	size = custom_minimum_size
	queue_redraw()

func is_flickering() -> bool:
	return _tween != null and _tween.is_valid()

func _draw() -> void:
	var center := Vector2(radius, radius)
	var ring := UiTokens.ember(PEAK_ALPHA)
	for i in range(STEPS):
		var ring_radius: float = radius * (1.0 - float(i) / STEPS)
		draw_circle(center, ring_radius, ring)

func _start_flicker() -> void:
	if Engine.is_editor_hint():
		return
	_tween = create_tween().set_loops()
	var half: float = UiTokens.FLICKER_SECONDS / 2.0
	_tween.tween_property(self, "modulate:a", 0.72, half).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "modulate:a", 1.0, half).set_trans(Tween.TRANS_SINE)
```

Create `scripts/ui/theme/art_placeholder.gd`:

```gdscript
extends PanelContainer
class_name ArtPlaceholder

# Shows res://assets/art/<art_id>.png when it exists; otherwise a quiet
# panel carrying the image brief, so generated art drops in later with
# no code change. See assets/art/README.md.

const ART_DIR := "res://assets/art/"

var has_art: bool = false
var label: Label = null
var texture_rect: TextureRect = null

func setup(art_id: StringName, brief: String, art_size: Vector2) -> void:
	custom_minimum_size = art_size
	for child in get_children():
		remove_child(child)
		child.queue_free()
	label = null
	texture_rect = null
	var path: String = ART_DIR + String(art_id) + ".png"
	if ResourceLoader.exists(path):
		has_art = true
		add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
		texture_rect = TextureRect.new()
		texture_rect.texture = load(path) as Texture2D
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
		add_child(texture_rect)
		return
	has_art = false
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0.25)
	box.border_color = UiTokens.LINE
	box.set_border_width_all(1)
	box.set_corner_radius_all(UiTokens.RADIUS_PANEL)
	add_theme_stylebox_override(&"panel", box)
	label = Label.new()
	label.theme_type_variation = &"Muted"
	label.text = "[art: %s]" % brief
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
```

- [ ] **Step 4: Import, run the suite**

Expected: PASS, 44 scripts, 332 tests.

- [ ] **Step 5: Commit**

```bash
git checkout -- addons/
git add scripts/ui/theme/stat_chip.gd scripts/ui/theme/stat_chip.gd.uid scripts/ui/theme/stat_bar.gd scripts/ui/theme/stat_bar.gd.uid scripts/ui/theme/torch_glow.gd scripts/ui/theme/torch_glow.gd.uid scripts/ui/theme/art_placeholder.gd scripts/ui/theme/art_placeholder.gd.uid tests/unit/test_ui_components.gd tests/unit/test_ui_components.gd.uid
git commit -m "feat: add StatChip, StatBar, TorchGlow and ArtPlaceholder components"
```

---

### Task 4: `StatusHeader`, `BanterContent`, the character name

**Files:**
- Create: `scripts/ui/theme/status_header.gd`, `scripts/content/banter_content.gd`
- Modify: `scripts/resources/class_resource.gd`, `scripts/content/dwarf_content.gd`
- Test: `tests/unit/test_status_header.gd`, `tests/unit/test_banter_content.gd`; modify `tests/unit/test_dwarf_cards.gd`

**Interfaces:**
- Consumes: `StatChip`, `StatBar` (Task 3), `UiTokens`, `RunState`.
- Produces: `StatusHeader extends HBoxContainer` — `refresh()`,
  `set_gold_visible(v: bool)`, `set_hp_visible(v: bool)`, `level_label:
  Label`, `xp_bar: StatBar`, `skill_points_chip: StatChip`, `gold_chip:
  StatChip`, `hp_chip: StatChip`. `BanterContent.get_all() ->
  Array[Dictionary]`, `BanterContent.get_overheard(rng:
  RandomNumberGenerator) -> Dictionary` (`{"line": String, "who":
  String}`; a `null` rng is allowed). `ClassResource.character_name:
  String`. Consumed by Tasks 5–6.

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_status_header.gd`:

```gdscript
extends RunStateTest

func test_refresh_shows_level_xp_and_skill_points():
	MetaState.level = 3
	MetaState.xp = 12
	MetaState.skill_points = 2
	RunState.enter_camp(DwarfContent.get_class_resource())
	var header := StatusHeader.new()
	add_child_autofree(header)
	header.refresh()
	assert_eq(header.level_label.text, "LEVEL 3")
	assert_true(header.xp_bar.visible)
	assert_eq(header.xp_bar.value_label.text, "12 / 40")
	assert_true(header.skill_points_chip.visible)
	assert_eq(header.skill_points_chip.label.text, "2 skill points")

func test_refresh_at_max_level_hides_the_xp_bar():
	MetaState.level = RunState.MAX_LEVEL
	RunState.enter_camp(DwarfContent.get_class_resource())
	var header := StatusHeader.new()
	add_child_autofree(header)
	header.refresh()
	assert_eq(header.level_label.text, "LEVEL 7 · MAX")
	assert_false(header.xp_bar.visible)

func test_refresh_hides_the_skill_chip_at_zero_and_singularises_one():
	RunState.enter_camp(DwarfContent.get_class_resource())
	var header := StatusHeader.new()
	add_child_autofree(header)
	header.refresh()
	assert_false(header.skill_points_chip.visible)
	RunState.skill_points = 1
	header.refresh()
	assert_eq(header.skill_points_chip.label.text, "1 skill point")

func test_gold_and_hp_chips_reflect_run_state_and_can_be_hidden():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.gold = 25
	RunState.player_current_hp = 21
	var header := StatusHeader.new()
	add_child_autofree(header)
	header.refresh()
	assert_eq(header.gold_chip.label.text, "25 gold")
	assert_eq(header.hp_chip.label.text, "21 / %d" % RunState.player_max_hp)
	header.set_gold_visible(false)
	header.set_hp_visible(false)
	assert_false(header.gold_chip.visible)
	assert_false(header.hp_chip.visible)
```

Create `tests/unit/test_banter_content.gd`:

```gdscript
extends GutTest

func test_there_are_at_least_twelve_distinct_lines():
	var all := BanterContent.get_all()
	assert_true(all.size() >= 12, "%d lines" % all.size())
	var seen: Dictionary = {}
	for entry in all:
		assert_ne(String(entry["line"]), "")
		assert_ne(String(entry["who"]), "")
		assert_false(seen.has(entry["line"]), "duplicate: %s" % entry["line"])
		seen[entry["line"]] = true

func test_get_overheard_is_deterministic_for_a_seeded_rng():
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 5
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 5
	assert_eq(BanterContent.get_overheard(rng_a)["line"], BanterContent.get_overheard(rng_b)["line"])

func test_get_overheard_tolerates_a_null_rng():
	var entry := BanterContent.get_overheard(null)
	assert_true(entry.has("line") and entry.has("who"))
```

Add to `tests/unit/test_dwarf_cards.gd`:

```gdscript
func test_class_resource_names_the_character():
	assert_eq(DwarfContent.get_class_resource().character_name, "Hilde Barrowdust")
	assert_eq(DwarfContent.get_class_resource().display_name, "Dwarf")
```

- [ ] **Step 2: Import, run, verify the new scripts fail to load**

Expected: `StatusHeader` / `BanterContent` not declared; `character_name`
not found.

- [ ] **Step 3: Add `character_name`**

In `scripts/resources/class_resource.gd`, after `display_name`, add:

```gdscript
@export var character_name: String = ""
```

In `scripts/content/dwarf_content.gd`, after `class_res.display_name = "Dwarf"`, add:

```gdscript
	class_res.character_name = "Hilde Barrowdust"
```

- [ ] **Step 4: Write `BanterContent`**

Create `scripts/content/banter_content.gd`:

```gdscript
extends RefCounted
class_name BanterContent

# "Overheard" lines for the map's banter panel. Original cast, original
# jokes: Hilde Barrowdust (dwarf), Ormond (wizard), Pip Nettle (scout),
# Sabine (bard). Never the source comic's characters, names or gags.

static func get_all() -> Array[Dictionary]:
	return [
		{"line": "Left at the skull, right at the other skull. Which skull?", "who": "Hilde, to a corridor with no skulls in it"},
		{"line": "I'm not saying it's a trap. I'm saying it's a trapdoor with a sign that says 'trap'.", "who": "Pip Nettle, ignored"},
		{"line": "It's a rat's nest. — It's a rat's nest with excellent acoustics.", "who": "Sabine, overruled"},
		{"line": "Whose turn is it to carry the torch? — Whoever asked.", "who": "party rule number seven"},
		{"line": "That door was locked from the other side. — So we're on the wrong side. — We're on OUR side.", "who": "Hilde, settling it"},
		{"line": "It says 'Beware'. It doesn't say of what. — That's the bewaring part.", "who": "Ormond, helpfully"},
		{"line": "I counted twelve stairs down and eleven up. — Then we're one stair ahead.", "who": "Hilde, doing the maths"},
		{"line": "Stop poking it. — It's a chest. — It's breathing.", "who": "Pip Nettle, correctly"},
		{"line": "If we split up, we cover more ground. — If we split up, the ground covers us.", "who": "Hilde"},
		{"line": "Someone wrote 'turn back' on this wall. — In what? — Let's say ink.", "who": "Ormond, not looking closer"},
		{"line": "I have a good feeling about this corridor. — You had a good feeling about the last one. — It was a good corridor. Briefly.", "who": "Hilde"},
		{"line": "The map says 'here be dragons'. — That's a soup stain. — Dragons eat soup.", "who": "Ormond, unbothered"},
		{"line": "Sabine, stop composing. — It's a ballad about our deaths. — We're not dead. — It's a first draft.", "who": "Sabine, tuning"},
	]

static func get_overheard(rng: RandomNumberGenerator) -> Dictionary:
	var source: RandomNumberGenerator = rng
	if source == null:
		source = RandomNumberGenerator.new()
		source.randomize()
	var all := get_all()
	return all[source.randi_range(0, all.size() - 1)]
```

- [ ] **Step 5: Write `StatusHeader`**

Create `scripts/ui/theme/status_header.gd`:

```gdscript
extends HBoxContainer
class_name StatusHeader

# Level, XP bar, skill points, gold and HP — the strip at the top of the
# Map and inside Camp's status panel. Reads RunState on refresh().

var level_label: Label
var xp_bar: StatBar
var skill_points_chip: StatChip
var gold_chip: StatChip
var hp_chip: StatChip

func _init() -> void:
	add_theme_constant_override(&"separation", UiTokens.SPACE_5)
	alignment = BoxContainer.ALIGNMENT_BEGIN
	level_label = Label.new()
	level_label.theme_type_variation = &"Number"
	add_child(level_label)
	xp_bar = StatBar.new()
	xp_bar.custom_minimum_size = Vector2(180, 0)
	xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	xp_bar.setup("XP", UiTokens.EMBER)
	add_child(xp_bar)
	skill_points_chip = StatChip.new()
	skill_points_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(skill_points_chip)
	gold_chip = StatChip.new()
	gold_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(gold_chip)
	hp_chip = StatChip.new()
	hp_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(hp_chip)

func refresh() -> void:
	var at_max: bool = RunState.level >= RunState.MAX_LEVEL
	level_label.text = "LEVEL %d · MAX" % RunState.level if at_max else "LEVEL %d" % RunState.level
	xp_bar.visible = not at_max
	if not at_max:
		xp_bar.set_values(RunState.xp, RunState.XP_THRESHOLDS[RunState.level - 1])
	var points: int = RunState.skill_points
	skill_points_chip.setup(&"tree", "%d skill point%s" % [points, "" if points == 1 else "s"], UiTokens.EMBER)
	skill_points_chip.visible = points > 0
	gold_chip.setup(&"coin", "%d gold" % RunState.gold, UiTokens.EMBER)
	hp_chip.setup(&"heart", "%d / %d" % [RunState.player_current_hp, RunState.player_max_hp], UiTokens.BLOOD)

func set_gold_visible(visible_now: bool) -> void:
	gold_chip.visible = visible_now

func set_hp_visible(visible_now: bool) -> void:
	hp_chip.visible = visible_now
```

- [ ] **Step 6: Import, run the suite**

Expected: PASS, 46 scripts, 340 tests.

- [ ] **Step 7: Commit**

```bash
git checkout -- addons/
git add scripts/ui/theme/status_header.gd scripts/ui/theme/status_header.gd.uid scripts/content/banter_content.gd scripts/content/banter_content.gd.uid scripts/resources/class_resource.gd scripts/content/dwarf_content.gd tests/unit/test_status_header.gd tests/unit/test_status_header.gd.uid tests/unit/test_banter_content.gd tests/unit/test_banter_content.gd.uid tests/unit/test_dwarf_cards.gd
git commit -m "feat: add StatusHeader, BanterContent and the character name"
```

---

### Task 5: `MapPaths` and the vertical `MapView`

**Files:**
- Create: `scripts/ui/run/map_paths.gd`
- Modify (replace wholesale): `scripts/ui/run/map_view.gd`
- Modify (replace wholesale): `tests/unit/test_map_view.gd`

**Interfaces:**
- Consumes: `UiTokens`, `UiIcons` (Task 1), `TorchGlow`, `ArtPlaceholder`,
  `StatChip` (Task 3), `StatusHeader`, `BanterContent` (Task 4),
  `RunState`, `DwarfRelics.get_by_id`.
- Produces: `MapPaths extends Control` — `set_edges(edges: Array[Dictionary])`
  (`{"from": Control, "to": Control, "lit": bool}`), `edge_count() ->
  int`. `MapView`: unchanged signals and `skill_tree_button` /
  `inventory_button`; new `header: StatusHeader`, `floors_container:
  VBoxContainer`, `paths: MapPaths`, `party_art: ArtPlaceholder`,
  `banter_label: Label`, `banter_who_label: Label`, `relics_container:
  HBoxContainer`, `potions_container: HBoxContainer`, `floor_count() ->
  int`, `node_button(floor_index: int, node_index: int) -> Button`.
  `status_label` is gone. Consumed by Task 7 (unchanged wiring).

- [ ] **Step 1: Replace the MapView tests**

Replace the full contents of `tests/unit/test_map_view.gd` with:

```gdscript
extends RunStateTest

func _two_floor_graph() -> Array:
	var node_a := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	var node_b := MapNode.new(1, MapNode.NodeType.EVENT, 1)
	node_a.connections = [1]
	var graph := MapGraph.new()
	graph.floors = [[node_a] as Array[MapNode], [node_b] as Array[MapNode]]
	return [graph, node_a, node_b]

func test_display_creates_one_row_per_floor_with_floor_zero_at_the_bottom():
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var parts := _two_floor_graph()
	map_view.display(parts[0], parts[1])
	assert_eq(map_view.floor_count(), 2)
	assert_eq(map_view.floors_container.get_child_count(), 2)
	assert_eq(map_view.floors_container.get_child(1).get_child(0), map_view.node_button(0, 0), "Floor 0 is the LAST row (bottom).")
	assert_eq(map_view.floors_container.get_child(0).get_child(0), map_view.node_button(1, 0), "The top floor is the FIRST row.")

func test_display_enables_only_the_entry_node_before_the_run_has_moved():
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var parts := _two_floor_graph()
	map_view.display(parts[0], parts[1])
	assert_false(map_view.node_button(0, 0).disabled, "Entry node should be clickable before the run has moved.")
	assert_true(map_view.node_button(1, 0).disabled, "Floor 1 node isn't reachable until the entry node is played.")
	assert_eq(map_view.node_button(0, 0).theme_type_variation, &"NodeCurrent")
	assert_eq(map_view.node_button(1, 0).theme_type_variation, &"NodeLocked")

func test_display_enables_connections_of_a_visited_current_node():
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var node_a := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	node_a.visited = true
	var node_b := MapNode.new(1, MapNode.NodeType.EVENT, 1)
	var node_c := MapNode.new(2, MapNode.NodeType.SHOP, 1)
	node_a.connections = [1]
	var graph := MapGraph.new()
	graph.floors = [[node_a] as Array[MapNode], [node_b, node_c] as Array[MapNode]]
	map_view.display(graph, node_a)
	assert_false(map_view.node_button(1, 0).disabled, "node_b is in node_a's connections.")
	assert_true(map_view.node_button(1, 1).disabled, "node_c is not in node_a's connections.")
	assert_eq(map_view.node_button(1, 0).theme_type_variation, &"NodeOpen")
	assert_eq(map_view.node_button(1, 1).theme_type_variation, &"NodeLocked")
	assert_eq(map_view.node_button(0, 0).theme_type_variation, &"NodeCurrent")
	assert_true(map_view.node_button(0, 0).disabled, "A visited current node is not clickable again.")

func test_visited_nodes_behind_the_party_are_styled_visited():
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var node_a := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	node_a.visited = true
	var node_b := MapNode.new(1, MapNode.NodeType.EVENT, 1)
	node_b.visited = true
	node_a.connections = [1]
	var graph := MapGraph.new()
	graph.floors = [[node_a] as Array[MapNode], [node_b] as Array[MapNode]]
	map_view.display(graph, node_b)
	assert_eq(map_view.node_button(0, 0).theme_type_variation, &"NodeVisited")
	assert_eq(map_view.node_button(1, 0).theme_type_variation, &"NodeCurrent")

func test_node_buttons_carry_the_type_icon_and_no_text():
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var parts := _two_floor_graph()
	map_view.display(parts[0], parts[1])
	var button: Button = map_view.node_button(1, 0)
	assert_eq(button.text, "")
	assert_not_null(button.icon)
	assert_eq(button.tooltip_text, "EVENT")
	assert_eq(button.custom_minimum_size, Vector2(UiTokens.NODE_SIZE, UiTokens.NODE_SIZE))

func test_boss_nodes_are_larger():
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var node_a := MapNode.new(0, MapNode.NodeType.BOSS, 0)
	var graph := MapGraph.new()
	graph.floors = [[node_a] as Array[MapNode]]
	map_view.display(graph, node_a)
	assert_eq(map_view.node_button(0, 0).custom_minimum_size, Vector2(UiTokens.NODE_SIZE_BOSS, UiTokens.NODE_SIZE_BOSS))

func test_clicking_a_node_button_emits_node_selected():
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var node_a := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	var graph := MapGraph.new()
	graph.floors = [[node_a] as Array[MapNode]]
	map_view.display(graph, node_a)
	watch_signals(map_view)
	map_view.node_button(0, 0).pressed.emit()
	assert_signal_emitted_with_parameters(map_view, "node_selected", [node_a])

func test_paths_get_one_edge_per_connection_and_light_the_open_ones():
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var node_a := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	node_a.visited = true
	var node_b := MapNode.new(1, MapNode.NodeType.EVENT, 1)
	var node_c := MapNode.new(2, MapNode.NodeType.SHOP, 1)
	node_a.connections = [1, 2]
	var graph := MapGraph.new()
	graph.floors = [[node_a] as Array[MapNode], [node_b, node_c] as Array[MapNode]]
	map_view.display(graph, node_a)
	assert_eq(map_view.paths.edge_count(), 2)
	assert_true(map_view.paths.lit_edge_count() == 2, "Both edges leave the current node towards open nodes.")

func test_display_called_twice_leaves_only_the_current_floors_as_children():
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var node_a := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	var graph1 := MapGraph.new()
	graph1.floors = [[node_a] as Array[MapNode]]
	map_view.display(graph1, node_a)
	var node_b := MapNode.new(1, MapNode.NodeType.EVENT, 0)
	var graph2 := MapGraph.new()
	graph2.floors = [[node_b] as Array[MapNode]]
	map_view.display(graph2, node_b)
	assert_eq(map_view.get_child_count(), 1, "Only the second display() call's root remains; remove_child() must detach the old one immediately.")
	assert_eq(map_view.floor_count(), 1)

func test_display_adds_a_skill_tree_button_that_emits_skill_tree_requested():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var parts := _two_floor_graph()
	map_view.display(parts[0], parts[1])
	watch_signals(map_view)
	map_view.skill_tree_button.pressed.emit()
	assert_signal_emitted(map_view, "skill_tree_requested")

func test_display_adds_an_inventory_button_that_emits_inventory_requested():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var parts := _two_floor_graph()
	map_view.display(parts[0], parts[1])
	watch_signals(map_view)
	map_view.inventory_button.pressed.emit()
	assert_signal_emitted(map_view, "inventory_requested")

func test_header_shows_current_level_and_skill_points():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.level = 3
	RunState.skill_points = 2
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var parts := _two_floor_graph()
	map_view.display(parts[0], parts[1])
	assert_eq(map_view.header.level_label.text, "LEVEL 3")
	assert_eq(map_view.header.skill_points_chip.label.text, "2 skill points")

func test_header_shows_max_level():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.level = RunState.MAX_LEVEL
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var parts := _two_floor_graph()
	map_view.display(parts[0], parts[1])
	assert_true(map_view.header.level_label.text.contains("MAX"))

func test_right_column_lists_relics_potions_and_a_banter_line():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.grant_relic(DwarfRelics.get_by_id(&"whetstone"))
	RunState.grant_relic(DwarfRelics.get_by_id(&"iron_ration"))
	RunState.add_potion(DwarfPotions.get_by_id(&"healing_draught"))
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var parts := _two_floor_graph()
	map_view.display(parts[0], parts[1])
	assert_eq(map_view.relics_container.get_child_count(), 2)
	assert_eq(map_view.potions_container.get_child_count(), RunState.MAX_POTIONS, "One chip per held potion plus dashed empties up to the cap.")
	assert_ne(map_view.banter_label.text, "")
	assert_ne(map_view.banter_who_label.text, "")
	assert_false(map_view.party_art.has_art)
```

- [ ] **Step 2: Run, verify the tests fail**

Expected: `test_map_view.gd` fails to load (`floor_count`, `node_button`,
`header`, `paths` … not found).

- [ ] **Step 3: Write `MapPaths`**

Create `scripts/ui/run/map_paths.gd`:

```gdscript
extends Control
class_name MapPaths

# Draws the connections between map node buttons: dashed ember for
# ordinary edges, solid ember for edges leaving the current node towards
# an open node. Positions are read from the buttons' global rects, so it
# redraws after layout settles (call_deferred from MapView.display) and
# on resize.

const SAMPLES := 24
const CONTROL_OFFSET := 40.0
const LINE_WIDTH := 2.0

var _edges: Array[Dictionary] = []

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func set_edges(edges: Array[Dictionary]) -> void:
	_edges = edges
	queue_redraw()

func edge_count() -> int:
	return _edges.size()

func lit_edge_count() -> int:
	var count: int = 0
	for edge in _edges:
		if edge["lit"]:
			count += 1
	return count

func _draw() -> void:
	var inverse: Transform2D = get_global_transform().affine_inverse()
	for edge in _edges:
		var from_control: Control = edge["from"]
		var to_control: Control = edge["to"]
		var from_rect: Rect2 = from_control.get_global_rect()
		var to_rect: Rect2 = to_control.get_global_rect()
		var start: Vector2 = inverse * Vector2(from_rect.position.x + from_rect.size.x / 2.0, from_rect.position.y)
		var end: Vector2 = inverse * Vector2(to_rect.position.x + to_rect.size.x / 2.0, to_rect.position.y + to_rect.size.y)
		var points := PackedVector2Array()
		for i in range(SAMPLES + 1):
			var t: float = float(i) / SAMPLES
			points.append(start.bezier_interpolate(start + Vector2(0, -CONTROL_OFFSET), end + Vector2(0, CONTROL_OFFSET), end, t))
		if edge["lit"]:
			draw_polyline(points, UiTokens.EMBER, LINE_WIDTH, true)
		else:
			for i in range(0, SAMPLES, 2):
				draw_line(points[i], points[i + 1], UiTokens.LINE, LINE_WIDTH, true)
```

- [ ] **Step 4: Replace `MapView`**

Replace the full contents of `scripts/ui/run/map_view.gd` with:

```gdscript
extends Control
class_name MapView

signal node_selected(node: MapNode)
signal skill_tree_requested
signal inventory_requested

# Layout (1440x900): floors column on the left (60..940), right column at
# 1000 (400 wide). Floors are rows, bottom = floor 0 (start), top = boss.

const FLOORS_LEFT := 60
const FLOORS_TOP := 90
const FLOORS_WIDTH := 880
const FLOORS_HEIGHT := 760
const COLUMN_LEFT := 1000
const COLUMN_TOP := 100
const COLUMN_WIDTH := 400
const ROW_GAP := 48

var header: StatusHeader
var skill_tree_button: Button
var inventory_button: Button
var floors_container: VBoxContainer
var paths: MapPaths
var party_art: ArtPlaceholder
var banter_label: Label
var banter_who_label: Label
var relics_container: HBoxContainer
var potions_container: HBoxContainer

var _node_buttons: Array = []  # [floor][index] -> Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

func floor_count() -> int:
	return _node_buttons.size()

func node_button(floor_index: int, node_index: int) -> Button:
	return _node_buttons[floor_index][node_index]

func display(map: MapGraph, current_node: MapNode) -> void:
	for child in get_children():
		# queue_free(), not free(): display() can run again from inside a
		# node button's own "pressed" handler chain, so freeing immediately
		# would destroy a node still executing its own signal dispatch.
		remove_child(child)
		child.queue_free()
	_node_buttons = []

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_backdrop(root)
	_build_top_bar(root)
	_build_floors(root, map, current_node)
	_build_right_column(root)

func _build_backdrop(root: Control) -> void:
	var corridor := ArtPlaceholder.new()
	corridor.setup(&"map_corridor", "corridor backdrop — three parallax layers: far vault, mid pillars, near arch; scrolls as you climb", Vector2(FLOORS_WIDTH + 60, 900))
	corridor.position = Vector2(FLOORS_LEFT, 0)
	corridor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(corridor)
	var glow_top := TorchGlow.new()
	glow_top.set_radius(260)
	glow_top.position = Vector2(80, -200)
	root.add_child(glow_top)
	var glow_bottom := TorchGlow.new()
	glow_bottom.set_radius(240)
	glow_bottom.position = Vector2(520, 520)
	root.add_child(glow_bottom)

func _build_top_bar(root: Control) -> void:
	var bar := HBoxContainer.new()
	bar.position = Vector2(40, 16)
	bar.size = Vector2(1360, 52)
	bar.add_theme_constant_override(&"separation", UiTokens.SPACE_3)
	root.add_child(bar)
	header = StatusHeader.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.refresh()
	bar.add_child(header)
	skill_tree_button = Button.new()
	skill_tree_button.text = "Skill Tree"
	skill_tree_button.icon = UiIcons.texture(&"tree")
	skill_tree_button.pressed.connect(_on_skill_tree_button_pressed)
	bar.add_child(skill_tree_button)
	inventory_button = Button.new()
	inventory_button.text = "Inventory"
	inventory_button.icon = UiIcons.texture(&"bag")
	inventory_button.pressed.connect(_on_inventory_button_pressed)
	bar.add_child(inventory_button)

func _build_floors(root: Control, map: MapGraph, current_node: MapNode) -> void:
	var area := Control.new()
	area.position = Vector2(FLOORS_LEFT, FLOORS_TOP)
	area.size = Vector2(FLOORS_WIDTH, FLOORS_HEIGHT)
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(area)

	paths = MapPaths.new()
	paths.set_anchors_preset(Control.PRESET_FULL_RECT)
	area.add_child(paths)

	floors_container = VBoxContainer.new()
	floors_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	floors_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(floors_container)

	var reachable_ids: Array[int] = []
	if current_node.visited:
		reachable_ids = current_node.connections.duplicate()
	else:
		reachable_ids.append(current_node.id)

	var buttons_by_id: Dictionary = {}
	for floor_index in range(map.floors.size()):
		_node_buttons.append([])
	for floor_index in range(map.floors.size() - 1, -1, -1):
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override(&"separation", ROW_GAP)
		floors_container.add_child(row)
		for node: MapNode in map.floors[floor_index]:
			var button := _make_node_button(node, current_node, reachable_ids)
			row.add_child(button)
			_node_buttons[floor_index].append(button)
			buttons_by_id[node.id] = button

	var edges: Array[Dictionary] = []
	for floor_nodes in map.floors:
		for node: MapNode in floor_nodes:
			for target_id in node.connections:
				if not buttons_by_id.has(target_id):
					continue
				var target: Button = buttons_by_id[target_id]
				var lit: bool = node == current_node and not target.disabled
				edges.append({"from": buttons_by_id[node.id], "to": target, "lit": lit})
	paths.set_edges(edges)
	paths.queue_redraw.call_deferred()

func _make_node_button(node: MapNode, current_node: MapNode, reachable_ids: Array[int]) -> Button:
	var button := Button.new()
	var size: int = UiTokens.NODE_SIZE_BOSS if node.node_type == MapNode.NodeType.BOSS else UiTokens.NODE_SIZE
	button.custom_minimum_size = Vector2(size, size)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.icon = UiIcons.for_node_type(node.node_type)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.expand_icon = false
	button.tooltip_text = MapNode.NodeType.keys()[node.node_type]
	button.disabled = node.visited or not reachable_ids.has(node.id)
	button.theme_type_variation = _node_variation(node, current_node, reachable_ids)
	button.pressed.connect(_on_node_button_pressed.bind(node))
	return button

func _node_variation(node: MapNode, current_node: MapNode, reachable_ids: Array[int]) -> StringName:
	if node == current_node:
		return &"NodeCurrent"
	if node.visited:
		return &"NodeVisited"
	if reachable_ids.has(node.id):
		return &"NodeOpen"
	return &"NodeLocked"

func _build_right_column(root: Control) -> void:
	var column := VBoxContainer.new()
	column.position = Vector2(COLUMN_LEFT, COLUMN_TOP)
	column.size = Vector2(COLUMN_WIDTH, 760)
	column.add_theme_constant_override(&"separation", UiTokens.SPACE_4)
	root.add_child(column)

	party_art = ArtPlaceholder.new()
	party_art.setup(&"map_party", "the party, torchlit, mid-argument over which way the torch smoke is blowing — deeper corridor behind them each floor", Vector2(COLUMN_WIDTH, 300))
	column.add_child(party_art)

	var banter_panel := PanelContainer.new()
	column.add_child(banter_panel)
	var banter_box := VBoxContainer.new()
	banter_box.add_theme_constant_override(&"separation", UiTokens.SPACE_2)
	banter_panel.add_child(banter_box)
	banter_box.add_child(_eyebrow("Overheard"))
	var entry: Dictionary = BanterContent.get_overheard(RunState.rng)
	banter_label = Label.new()
	banter_label.theme_type_variation = &"Banter"
	banter_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banter_label.text = "\u201c%s\u201d" % String(entry["line"])
	banter_box.add_child(banter_label)
	banter_who_label = Label.new()
	banter_who_label.theme_type_variation = &"Muted"
	banter_who_label.text = "— %s" % String(entry["who"])
	banter_box.add_child(banter_who_label)

	var stock_panel := PanelContainer.new()
	column.add_child(stock_panel)
	var stock_box := VBoxContainer.new()
	stock_box.add_theme_constant_override(&"separation", UiTokens.SPACE_3)
	stock_panel.add_child(stock_box)
	stock_box.add_child(_eyebrow("Relics"))
	relics_container = HBoxContainer.new()
	relics_container.add_theme_constant_override(&"separation", UiTokens.SPACE_2)
	stock_box.add_child(relics_container)
	for relic_id in RunState.unlocked_relics:
		var relic := DwarfRelics.get_by_id(relic_id)
		if relic == null:
			continue
		var chip := StatChip.new()
		chip.setup(&"gem", relic.display_name, UiTokens.EMBER)
		relics_container.add_child(chip)
	stock_box.add_child(_eyebrow("Potions"))
	potions_container = HBoxContainer.new()
	potions_container.add_theme_constant_override(&"separation", UiTokens.SPACE_2)
	stock_box.add_child(potions_container)
	for potion in RunState.potions:
		var chip := StatChip.new()
		chip.setup(&"flask", potion.display_name, UiTokens.RUNE)
		potions_container.add_child(chip)
	for i in range(RunState.potions.size(), RunState.MAX_POTIONS):
		var empty := StatChip.new()
		empty.setup(&"flask", "empty", UiTokens.DIM)
		potions_container.add_child(empty)

func _eyebrow(text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"Eyebrow"
	label.text = text.to_upper()
	return label

func _on_node_button_pressed(node: MapNode) -> void:
	node_selected.emit(node)

func _on_skill_tree_button_pressed() -> void:
	skill_tree_requested.emit()

func _on_inventory_button_pressed() -> void:
	inventory_requested.emit()
```

- [ ] **Step 5: Import, run the full suite**

Expected: PASS, 46 scripts, 345 tests (the 9 old MapView tests are
replaced by 14; no new test script). Every `RunScene` test still passes: `RunScene` only
uses `MapView`'s signals and `display()`.

- [ ] **Step 6: Commit**

```bash
git checkout -- addons/
git add scripts/ui/run/map_paths.gd scripts/ui/run/map_paths.gd.uid scripts/ui/run/map_view.gd tests/unit/test_map_view.gd
git commit -m "feat: rebuild the Map screen vertical with icon nodes, drawn paths and a run column"
```

---

### Task 6: `CampScene` to the mockup, with a gear table

**Files:**
- Create: `scripts/ui/camp/gear_row.gd`
- Modify (replace wholesale): `scripts/ui/camp/camp_scene.gd`
- Modify (replace wholesale): `tests/unit/test_camp_scene.gd`
- Modify: `tests/unit/test_run_scene.gd:189`

**Interfaces:**
- Consumes: `UiTokens`, `UiIcons` (Task 1), `TorchGlow`,
  `ArtPlaceholder` (Task 3), `StatusHeader` (Task 4), `RunState`,
  `SaveManager.has_run_snapshot()`.
- Produces: `GearRow extends HBoxContainer` — `set_item(slot_name:
  String, item: EquipmentResource)`, `slot_label`, `name_label`,
  `effect_label`. `CampScene`: unchanged signals, buttons, `FLAVOR_LINE`,
  `SUSPENDED_FLAVOR_LINE`, `EMPTY_SLOT`, `flavor_label`, `refresh()`;
  new `header: StatusHeader`, `gear_rows: Dictionary` (keyed by
  `EquipmentResource.Slot` → `GearRow`), `camp_art: ArtPlaceholder`.
  `status_label` and `gear_label` are gone.

- [ ] **Step 1: Replace the Camp tests and patch the RunScene assertion**

Replace the full contents of `tests/unit/test_camp_scene.gd` with:

```gdscript
extends RunStateTest

func test_ready_shows_level_xp_and_skill_points():
	MetaState.level = 2
	MetaState.xp = 7
	MetaState.skill_points = 1
	RunState.enter_camp(DwarfContent.get_class_resource())
	var scene := CampScene.new()
	add_child_autofree(scene)
	assert_eq(scene.header.level_label.text, "LEVEL 2")
	assert_eq(scene.header.xp_bar.value_label.text, "7 / 30")
	assert_eq(scene.header.skill_points_chip.label.text, "1 skill point")
	assert_false(scene.header.gold_chip.visible, "Camp has no run, so no gold.")
	assert_false(scene.header.hp_chip.visible, "Camp has no run, so no HP.")

func test_ready_shows_max_level_without_an_xp_bar():
	MetaState.level = RunState.MAX_LEVEL
	RunState.enter_camp(DwarfContent.get_class_resource())
	var scene := CampScene.new()
	add_child_autofree(scene)
	assert_eq(scene.header.level_label.text, "LEVEL 7 · MAX")
	assert_false(scene.header.xp_bar.visible)

func test_ready_shows_equipped_gear_and_empty_slots():
	MetaState.owned_equipment_ids = [&"chainmail"]
	MetaState.equipped_armor_id = &"chainmail"
	RunState.enter_camp(DwarfContent.get_class_resource())
	var scene := CampScene.new()
	add_child_autofree(scene)
	assert_eq(scene.gear_rows[EquipmentResource.Slot.WEAPON].name_label.text, CampScene.EMPTY_SLOT)
	assert_eq(scene.gear_rows[EquipmentResource.Slot.ARMOR].name_label.text, "Chainmail")
	assert_eq(scene.gear_rows[EquipmentResource.Slot.ARMOR].effect_label.text, "+4 Block.")
	assert_eq(scene.gear_rows[EquipmentResource.Slot.TRINKET].name_label.text, CampScene.EMPTY_SLOT)
	assert_eq(scene.gear_rows[EquipmentResource.Slot.ARMOR].slot_label.text, "ARMOR")

func test_ready_shows_the_flavor_line_and_the_art_placeholder():
	RunState.enter_camp(DwarfContent.get_class_resource())
	var scene := CampScene.new()
	add_child_autofree(scene)
	assert_eq(scene.flavor_label.text, CampScene.FLAVOR_LINE)
	assert_false(scene.camp_art.has_art)

func test_buttons_emit_their_signals():
	RunState.enter_camp(DwarfContent.get_class_resource())
	var scene := CampScene.new()
	add_child_autofree(scene)
	watch_signals(scene)
	scene.skill_tree_button.pressed.emit()
	assert_signal_emitted(scene, "skill_tree_requested")
	scene.inventory_button.pressed.emit()
	assert_signal_emitted(scene, "inventory_requested")
	scene.start_run_button.pressed.emit()
	assert_signal_emitted(scene, "run_requested")

func test_refresh_rereads_run_state():
	RunState.enter_camp(DwarfContent.get_class_resource())
	var scene := CampScene.new()
	add_child_autofree(scene)
	RunState.grant_equipment(DwarfEquipment.get_by_id(&"lucky_charm"))
	RunState.equip_item(RunState.owned_equipment[0])
	scene.refresh()
	assert_eq(scene.gear_rows[EquipmentResource.Slot.TRINKET].name_label.text, "Lucky Charm")

func test_without_a_suspended_run_only_the_normal_buttons_show():
	RunState.enter_camp(DwarfContent.get_class_resource())
	var scene := CampScene.new()
	add_child_autofree(scene)
	assert_true(scene.skill_tree_button.visible)
	assert_true(scene.inventory_button.visible)
	assert_true(scene.start_run_button.visible)
	assert_false(scene.continue_run_button.visible)
	assert_false(scene.abandon_run_button.visible)
	assert_eq(scene.flavor_label.text, CampScene.FLAVOR_LINE)

func test_with_a_suspended_run_only_continue_and_abandon_show():
	RunState.enter_camp(DwarfContent.get_class_resource())
	SaveManager.run_snapshot = {"current_floor": 1}
	var scene := CampScene.new()
	add_child_autofree(scene)
	assert_false(scene.skill_tree_button.visible)
	assert_false(scene.inventory_button.visible)
	assert_false(scene.start_run_button.visible)
	assert_true(scene.continue_run_button.visible)
	assert_true(scene.abandon_run_button.visible)
	assert_eq(scene.flavor_label.text, CampScene.SUSPENDED_FLAVOR_LINE)

func test_continue_and_abandon_buttons_emit_their_signals():
	RunState.enter_camp(DwarfContent.get_class_resource())
	SaveManager.run_snapshot = {"current_floor": 1}
	var scene := CampScene.new()
	add_child_autofree(scene)
	watch_signals(scene)
	scene.continue_run_button.pressed.emit()
	assert_signal_emitted(scene, "continue_requested")
	scene.abandon_run_button.pressed.emit()
	assert_signal_emitted(scene, "abandon_requested")

func test_refresh_switches_button_sets_when_the_snapshot_goes_away():
	RunState.enter_camp(DwarfContent.get_class_resource())
	SaveManager.run_snapshot = {"current_floor": 1}
	var scene := CampScene.new()
	add_child_autofree(scene)
	SaveManager.run_snapshot = null
	scene.refresh()
	assert_true(scene.start_run_button.visible)
	assert_false(scene.continue_run_button.visible)
	assert_eq(scene.flavor_label.text, CampScene.FLAVOR_LINE)
```

In `tests/unit/test_run_scene.gd`, change line 189 from:

```gdscript
	assert_true(scene.camp_scene.status_label.text.begins_with("Lv 3"))
```

to:

```gdscript
	assert_eq(scene.camp_scene.header.level_label.text, "LEVEL 3")
```

- [ ] **Step 2: Run, verify the tests fail**

Expected: `test_camp_scene.gd` fails to load (`header`, `gear_rows`,
`camp_art` not found); the `RunScene` test fails the same way.

- [ ] **Step 3: Write `GearRow`**

Create `scripts/ui/camp/gear_row.gd`:

```gdscript
extends HBoxContainer
class_name GearRow

# One line of Camp's gear table: SLOT · item name · effect.

var slot_label: Label
var name_label: Label
var effect_label: Label

func _init() -> void:
	add_theme_constant_override(&"separation", UiTokens.SPACE_3)
	slot_label = Label.new()
	slot_label.theme_type_variation = &"Eyebrow"
	slot_label.custom_minimum_size = Vector2(90, 0)
	add_child(slot_label)
	name_label = Label.new()
	name_label.custom_minimum_size = Vector2(170, 0)
	add_child(name_label)
	effect_label = Label.new()
	effect_label.theme_type_variation = &"Muted"
	effect_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(effect_label)

func set_item(slot_name: String, item: EquipmentResource) -> void:
	slot_label.text = slot_name.to_upper()
	if item == null:
		name_label.text = CampScene.EMPTY_SLOT
		name_label.add_theme_color_override(&"font_color", UiTokens.DIM)
		effect_label.text = ""
		return
	name_label.text = item.display_name
	name_label.remove_theme_color_override(&"font_color")
	effect_label.text = item.description
```

- [ ] **Step 4: Replace `CampScene`**

Replace the full contents of `scripts/ui/camp/camp_scene.gd` with:

```gdscript
extends Control
class_name CampScene

signal skill_tree_requested
signal inventory_requested
signal run_requested
signal continue_requested
signal abandon_requested

# The single story hook this layer ships; Camp dialogue proper comes later.
const FLAVOR_LINE := "The party argues over who lost the map."
const SUSPENDED_FLAVOR_LINE := "The party is still out there, arguing about which way is north."
const EMPTY_SLOT := "— empty —"

# Layout (1440x900): art fills the left 820px; the column sits at 880.
const ART_WIDTH := 820
const COLUMN_LEFT := 880
const COLUMN_TOP := 90
const COLUMN_WIDTH := 500

var camp_art: ArtPlaceholder
var flavor_label: Label
var header: StatusHeader
var gear_rows: Dictionary = {}
var skill_tree_button: Button
var inventory_button: Button
var start_run_button: Button
var continue_run_button: Button
var abandon_run_button: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	camp_art = ArtPlaceholder.new()
	camp_art.setup(&"camp_fire", "camp: a low fire in a stone alcove, packs against the wall, the party arguing in silhouette; one of them is trying to light the fire with a spellbook", Vector2(ART_WIDTH, 900))
	camp_art.position = Vector2.ZERO
	add_child(camp_art)
	var glow := TorchGlow.new()
	glow.set_radius(280)
	glow.position = Vector2(120, 300)
	add_child(glow)

	var column := VBoxContainer.new()
	column.position = Vector2(COLUMN_LEFT, COLUMN_TOP)
	column.size = Vector2(COLUMN_WIDTH, 760)
	column.add_theme_constant_override(&"separation", UiTokens.SPACE_5)
	add_child(column)

	var eyebrow := Label.new()
	eyebrow.theme_type_variation = &"Eyebrow"
	eyebrow.text = "BETWEEN EXPEDITIONS"
	column.add_child(eyebrow)
	var title := Label.new()
	title.theme_type_variation = &"Display"
	title.text = "CAMP"
	column.add_child(title)
	flavor_label = Label.new()
	flavor_label.theme_type_variation = &"Banter"
	flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(flavor_label)

	var status_panel := PanelContainer.new()
	column.add_child(status_panel)
	var status_box := VBoxContainer.new()
	status_box.add_theme_constant_override(&"separation", UiTokens.SPACE_3)
	status_panel.add_child(status_box)
	header = StatusHeader.new()
	header.set_gold_visible(false)
	header.set_hp_visible(false)
	status_box.add_child(header)
	for slot in [EquipmentResource.Slot.WEAPON, EquipmentResource.Slot.ARMOR, EquipmentResource.Slot.TRINKET]:
		var row := GearRow.new()
		status_box.add_child(row)
		gear_rows[slot] = row

	var actions := VBoxContainer.new()
	actions.add_theme_constant_override(&"separation", UiTokens.SPACE_3)
	column.add_child(actions)
	start_run_button = Button.new()
	start_run_button.text = "Start run"
	start_run_button.icon = UiIcons.texture(&"flame")
	start_run_button.theme_type_variation = &"Primary"
	start_run_button.custom_minimum_size = Vector2(0, 56)
	start_run_button.pressed.connect(_on_start_run_pressed)
	actions.add_child(start_run_button)
	var secondary := HBoxContainer.new()
	secondary.add_theme_constant_override(&"separation", UiTokens.SPACE_3)
	actions.add_child(secondary)
	skill_tree_button = Button.new()
	skill_tree_button.text = "Skill Tree"
	skill_tree_button.icon = UiIcons.texture(&"tree")
	skill_tree_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_tree_button.pressed.connect(_on_skill_tree_pressed)
	secondary.add_child(skill_tree_button)
	inventory_button = Button.new()
	inventory_button.text = "Inventory"
	inventory_button.icon = UiIcons.texture(&"bag")
	inventory_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_button.pressed.connect(_on_inventory_pressed)
	secondary.add_child(inventory_button)
	var suspended_row := HBoxContainer.new()
	suspended_row.add_theme_constant_override(&"separation", UiTokens.SPACE_3)
	actions.add_child(suspended_row)
	continue_run_button = Button.new()
	continue_run_button.text = "Continue run"
	continue_run_button.theme_type_variation = &"Primary"
	continue_run_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	continue_run_button.pressed.connect(_on_continue_run_pressed)
	suspended_row.add_child(continue_run_button)
	abandon_run_button = Button.new()
	abandon_run_button.text = "Abandon run"
	abandon_run_button.theme_type_variation = &"Danger"
	abandon_run_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	abandon_run_button.pressed.connect(_on_abandon_run_pressed)
	suspended_row.add_child(abandon_run_button)

	refresh()

func refresh() -> void:
	var suspended: bool = SaveManager.has_run_snapshot()
	header.refresh()
	gear_rows[EquipmentResource.Slot.WEAPON].set_item("Weapon", RunState.equipped_weapon)
	gear_rows[EquipmentResource.Slot.ARMOR].set_item("Armor", RunState.equipped_armor)
	gear_rows[EquipmentResource.Slot.TRINKET].set_item("Trinket", RunState.equipped_trinket)
	flavor_label.text = SUSPENDED_FLAVOR_LINE if suspended else FLAVOR_LINE
	# While a run is suspended, gear and skills are frozen with it: only
	# Continue / Abandon are offered (the map's own buttons return on resume).
	skill_tree_button.visible = not suspended
	inventory_button.visible = not suspended
	start_run_button.visible = not suspended
	continue_run_button.visible = suspended
	abandon_run_button.visible = suspended

func _on_skill_tree_pressed() -> void:
	skill_tree_requested.emit()

func _on_inventory_pressed() -> void:
	inventory_requested.emit()

func _on_start_run_pressed() -> void:
	run_requested.emit()

func _on_continue_run_pressed() -> void:
	continue_requested.emit()

func _on_abandon_run_pressed() -> void:
	abandon_requested.emit()
```

- [ ] **Step 5: Import, run the full suite**

Expected: PASS, 46 scripts, 345 tests (10 Camp tests replace 10).

- [ ] **Step 6: Commit**

```bash
git checkout -- addons/
git add scripts/ui/camp/gear_row.gd scripts/ui/camp/gear_row.gd.uid scripts/ui/camp/camp_scene.gd tests/unit/test_camp_scene.gd tests/unit/test_run_scene.gd
git commit -m "feat: rebuild the Camp screen to the Torchlit mockup with a gear table"
```

---

### Task 7: `RunScene` applies the theme

**Files:**
- Modify: `scripts/ui/run/run_scene.gd`
- Modify: `tests/unit/test_run_scene.gd`

**Interfaces:**
- Consumes: `ThemeBuilder.build()` (Task 2).
- Produces: every scene under `RunScene` renders with the Torchlit theme.
  Last task in the plan.

- [ ] **Step 1: Write the failing test**

Append to `tests/unit/test_run_scene.gd`:

```gdscript
func test_run_scene_applies_the_torchlit_theme_to_its_tree():
	var scene := RunScene.new()
	add_child_autofree(scene)
	assert_eq(scene.theme, ThemeBuilder.build())
	assert_eq(scene.camp_scene.get_theme_font_size(&"font_size", &"Display"), UiTokens.FONT_H1, "Children resolve the inherited theme's variations.")
```

- [ ] **Step 2: Run, verify it fails**

Expected: `scene.theme` is `null`.

- [ ] **Step 3: Apply the theme**

In `scripts/ui/run/run_scene.gd`, change the start of `_ready()` from:

```gdscript
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	map_view = MapView.new()
```

to:

```gdscript
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = ThemeBuilder.build()
	map_view = MapView.new()
```

- [ ] **Step 4: Run the full suite**

Expected: PASS, 46 scripts, 346 tests. If the total differs, compare the
per-script list: the new test scripts are `test_ui_tokens`, `test_ui_icons`,
`test_theme_builder`, `test_ui_components`, `test_status_header`,
`test_banter_content` (+6 over the 40 baseline).

- [ ] **Step 5: Commit**

```bash
git checkout -- addons/
git add scripts/ui/run/run_scene.gd tests/unit/test_run_scene.gd
git commit -m "feat: apply the Torchlit theme at the RunScene root"
```

---

## Manual verification (non-negotiable, per the parent spec's standard)

Launch: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --path . --editor`, F5
(or run `res://scripts/ui/run/run_scene.tscn`). Compare each screen with
the canvas https://claude.ai/code/artifact/5b5d65f8-09cf-4ce8-89ee-bd8367047748.

1. **Camp** matches `Camp.dc.html`: art placeholder brief on the left
   with a flickering glow, eyebrow / CAMP / flavour line, status panel
   with LEVEL 1 + XP bar, three gear rows, ember Start run, two
   secondary buttons. Cinzel headings, Source Sans body.
2. **Map** (Start run) matches `Main.dc.html`: header strip, floors as
   rows with floor 0 at the bottom, the entry node ember/pulsing, other
   nodes locked, dotted paths between nodes, a solid lit path from the
   current node once it has been played; right column with party art
   brief, an Overheard line, Relics (none yet) and two dashed Potion
   chips.
3. Play three nodes: states update (visited/open/current), lit paths
   move with the party, relic/potion chips appear when gained.
4. Open Inventory and Skill Tree from the map: legible on the dark
   theme (they inherit it), buttons ember, back returns to the map.
5. Resize the window to a square-ish shape: the 1440×900 canvas
   letterboxes (bars), nothing stretches.
6. Drop any PNG named `assets/art/camp_fire.png`, run the import,
   relaunch: Camp shows the image instead of the brief.

Automated tests passing is not sufficient on its own to call this plan
done.
