# Creature & Backdrop Art Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the "AI-generated painterly PNG" art plan with a photo-traced pipeline, and land the first real creature (Coypu, Act 1's first forest fight) through it end to end — real art on screen, not a placeholder brief.

**Architecture:** `ArtPlaceholder` keeps its existing `res://assets/art/<art_id>.png`-or-brief contract, extended to also resolve `.svg` (Godot imports SVG natively as a texture — no separate rasterize step). A new opt-in shader (`torchlit_creature.gdshader`) adds the game's ember rim-light on top of whichever art loads, and a new opt-in accent-marker mechanism spawns small glowing dots (eye/mouth) positioned per creature. A small reusable Python tool (`tools/art/trace_creature.py`) turns a reference photo into the traced SVG asset; the Coypu is produced with it and wired in as the renamed first Act-1-forest enemy (was "Forest Wolf").

**Tech Stack:** GDScript / Godot 4.7, GUT test framework, Python 3 + Pillow (posterize/darken step), `vtracer` CLI (vectorize step, installed via `cargo install vtracer` — **not** the PyPI wheel, which segfaults on Python 3.14+).

**Spec:** `docs/superpowers/specs/2026-09-13-creature-art-pipeline-design.md`

## Global Constraints

- Darkening formula (applied to every posterized colour, uniformly, never eyeballed per creature): `s' = min(s * 0.85, 0.6)`, `v' = min(v * 0.62 + 0.04, 0.55)` in HSV.
- `vtracer` invocation: `--colormode color --hierarchical stacked --mode spline --filter_speckle 5 --color_precision 8 --corner_threshold 80 --segment_length 3.5 --splice_threshold 45`.
- Posterize to ~22 colour buckets (`PIL.Image.quantize`, `MEDIANCUT`, **no dithering** — dithering defeats flat-region tracing).
- `vtracer` must be the cargo-built native CLI (`cargo install vtracer`), not the PyPI wheel.
- File convention: `assets/art_source/<id>/reference.jpg` (gitignored) vs. `assets/art/enemy_<name>.svg` (tracked). `ArtPlaceholder` checks `.svg` before `.png`.
- No AI-generated art anywhere in this pipeline — photo reference only.
- `UiTokens.EMBER` = `#e8a44a` = `vec4(0.910, 0.643, 0.290, 1.0)` — the shader's default rim colour.
- Test/run commands (this machine): Python at `C:/Users/cedri/AppData/Local/Python/pythoncore-3.14-64/python.exe`; Godot at `C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe`; GUT: `--headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`; re-import after adding assets: `--headless --import`.

---

### Task 1: `ArtPlaceholder` resolves `.svg` before `.png`

**Files:**
- Modify: `scripts/ui/theme/art_placeholder.gd`
- Create: `assets/art/_test_fixture.svg` (tiny permanent test fixture — GUT needs a real imported file under `assets/art/` to exercise the "art exists" branch; leading underscore marks it as not real game content)
- Test: `tests/unit/test_ui_components.gd`

**Interfaces:**
- Consumes: nothing new.
- Produces: `ArtPlaceholder._resolve_art_path(art_id: StringName) -> String` (empty string if neither file exists) — Tasks 2 and 3 build on this same `setup()` method, so its final shape after this task matters to them.

- [ ] **Step 1: Create the SVG test fixture**

Create `assets/art/_test_fixture.svg`:

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="4" height="4"><rect width="4" height="4" fill="#e8a44a"/></svg>
```

- [ ] **Step 2: Import it so Godot's ResourceLoader recognizes it**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --path "D:/CC" --headless --import`

- [ ] **Step 3: Write the failing test**

Add to `tests/unit/test_ui_components.gd` (after `test_art_placeholder_can_be_set_up_twice`):

```gdscript
func test_art_placeholder_resolves_an_svg_before_a_png():
	var art := ArtPlaceholder.new()
	add_child_autofree(art)
	art.setup(&"_test_fixture", "a fixture creature", Vector2(40, 40))
	assert_true(art.has_art)
	assert_not_null(art.texture_rect)
	assert_null(art.label)
```

- [ ] **Step 4: Run it to verify it fails**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit -ginclude_subdirs -gtest=test_ui_components`
Expected: FAIL — `_test_fixture` resolves nothing today (`ArtPlaceholder` only checks `.png`).

- [ ] **Step 5: Implement**

Replace the body of `scripts/ui/theme/art_placeholder.gd` with:

```gdscript
extends PanelContainer
class_name ArtPlaceholder

# Shows res://assets/art/<art_id>.svg or .png when either exists (svg is
# checked first — the traced-from-photo pipeline's output; see
# docs/superpowers/specs/2026-09-13-creature-art-pipeline-design.md);
# otherwise a quiet panel carrying the image brief, so art drops in later
# with no code change. See assets/art/README.md.

const ART_DIR := "res://assets/art/"

var has_art: bool = false
var label: Label = null
var texture_rect: TextureRect = null

func setup(art_id: StringName, brief: String, art_size: Vector2) -> void:
	custom_minimum_size = art_size
	for child in get_children():
		remove_child(child)
		# Safe to free immediately: Label and TextureRect have no signal handlers
		child.free()
	label = null
	texture_rect = null
	var path := _resolve_art_path(art_id)
	if path != "":
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

func _resolve_art_path(art_id: StringName) -> String:
	var svg_path: String = ART_DIR + String(art_id) + ".svg"
	if ResourceLoader.exists(svg_path):
		return svg_path
	var png_path: String = ART_DIR + String(art_id) + ".png"
	if ResourceLoader.exists(png_path):
		return png_path
	return ""
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: PASS, all 371+ tests green (this is also a regression check for every existing `ArtPlaceholder` call site).

- [ ] **Step 7: Commit**

```bash
git add scripts/ui/theme/art_placeholder.gd assets/art/_test_fixture.svg tests/unit/test_ui_components.gd
git commit -m "feat: ArtPlaceholder resolves .svg before .png"
```

---

### Task 2: Torchlit rim-light shader, opt-in per `ArtPlaceholder`

**Files:**
- Create: `scripts/ui/theme/torchlit_creature.gdshader`
- Modify: `scripts/ui/theme/art_placeholder.gd`
- Test: `tests/unit/test_ui_components.gd`

**Interfaces:**
- Consumes: `ArtPlaceholder.setup()` from Task 1.
- Produces: `ArtPlaceholder.setup(art_id, brief, art_size, use_torchlit_shader: bool = false)` — Task 3 adds one more parameter after this one, so its position matters to that task.

- [ ] **Step 1: Write the failing tests**

Add to `tests/unit/test_ui_components.gd`:

```gdscript
func test_art_placeholder_applies_the_torchlit_shader_when_requested():
	var art := ArtPlaceholder.new()
	add_child_autofree(art)
	art.setup(&"_test_fixture", "a fixture creature", Vector2(40, 40), true)
	assert_true(art.texture_rect.material is ShaderMaterial)

func test_art_placeholder_skips_the_shader_by_default():
	var art := ArtPlaceholder.new()
	add_child_autofree(art)
	art.setup(&"_test_fixture", "a fixture creature", Vector2(40, 40))
	assert_null(art.texture_rect.material)
```

- [ ] **Step 2: Run to verify failure**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: FAIL — `setup()` doesn't take a 4th argument yet.

- [ ] **Step 3: Create the shader**

Create `scripts/ui/theme/torchlit_creature.gdshader`:

```glsl
shader_type canvas_item;

// Ember rim-light along one edge, matching the "one warm light source per
// screen" rule (UiTokens/TorchGlow) — the direction is fixed so every
// creature is lit consistently, with no per-asset tuning. See
// docs/superpowers/specs/2026-09-13-creature-art-pipeline-design.md.

uniform vec2 light_direction = vec2(0.6, -0.8);
uniform vec4 rim_color : source_color = vec4(0.910, 0.643, 0.290, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 1.0;
uniform float rim_reach : hint_range(1.0, 8.0) = 3.0;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	vec2 dir = normalize(light_direction);
	vec2 offset = dir * TEXTURE_PIXEL_SIZE * rim_reach;
	float alpha_here = tex_color.a;
	float alpha_toward_light = texture(TEXTURE, UV + offset).a;
	float edge = clamp(alpha_here - alpha_toward_light, 0.0, 1.0) * rim_strength;
	COLOR = vec4(tex_color.rgb + rim_color.rgb * edge, tex_color.a);
}
```

- [ ] **Step 4: Wire it into `ArtPlaceholder`**

In `scripts/ui/theme/art_placeholder.gd`, add near the top (after `const ART_DIR`):

```gdscript
const TORCHLIT_SHADER := preload("res://scripts/ui/theme/torchlit_creature.gdshader")
```

Change the `setup()` signature to:

```gdscript
func setup(art_id: StringName, brief: String, art_size: Vector2, use_torchlit_shader: bool = false) -> void:
```

In the `if path != "":` block, right before `add_child(texture_rect)` `return`, insert:

```gdscript
		add_child(texture_rect)
		if use_torchlit_shader:
			var mat := ShaderMaterial.new()
			mat.shader = TORCHLIT_SHADER
			texture_rect.material = mat
		return
```

(replacing the previous bare `add_child(texture_rect)` / `return` pair).

- [ ] **Step 5: Run the tests to verify they pass**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: PASS, full suite green.

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/theme/torchlit_creature.gdshader scripts/ui/theme/art_placeholder.gd tests/unit/test_ui_components.gd
git commit -m "feat: add opt-in torchlit rim-light shader to ArtPlaceholder"
```

---

### Task 3: Glowing accent-marker dots (eye/mouth highlights)

**Files:**
- Create: `scripts/ui/theme/art_accent_dot.gd`
- Modify: `scripts/ui/theme/art_placeholder.gd`
- Test: `tests/unit/test_ui_components.gd`

**Interfaces:**
- Consumes: `ArtPlaceholder.setup()` from Task 2.
- Produces: `ArtAccentDot.new(tint: Color = UiTokens.EMBER_LIGHT, radius: float = 6.0) -> ArtAccentDot` with `is_pulsing() -> bool`; `ArtPlaceholder.setup(art_id, brief, art_size, use_torchlit_shader: bool = false, accent_markers: Array[Vector2] = [])` — Task 7 calls this final shape directly, by name, so the parameter order here is final.

- [ ] **Step 1: Write the failing tests**

Add to `tests/unit/test_ui_components.gd`:

```gdscript
func test_art_accent_dot_ignores_the_mouse_and_pulses():
	var dot := ArtAccentDot.new(UiTokens.RUNE, 6.0)
	add_child_autofree(dot)
	assert_eq(dot.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(dot.custom_minimum_size, Vector2(12, 12))
	assert_true(dot.is_pulsing())

func test_art_placeholder_adds_a_glow_dot_per_accent_marker():
	var art := ArtPlaceholder.new()
	add_child_autofree(art)
	var markers: Array[Vector2] = [Vector2(0.5, 0.5)]
	art.setup(&"_test_fixture", "a fixture creature", Vector2(40, 40), false, markers)
	assert_eq(art.get_child_count(), 2, "texture_rect plus one accent dot")
	var dot: ArtAccentDot = art.get_child(1)
	assert_eq(dot.position, Vector2(20, 20) - dot.custom_minimum_size / 2.0)

func test_art_placeholder_adds_no_dots_without_markers():
	var art := ArtPlaceholder.new()
	add_child_autofree(art)
	art.setup(&"_test_fixture", "a fixture creature", Vector2(40, 40))
	assert_eq(art.get_child_count(), 1, "just the texture_rect")
```

- [ ] **Step 2: Run to verify failure**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: FAIL — `ArtAccentDot` doesn't exist yet, `setup()` doesn't take a 5th argument.

- [ ] **Step 3: Create `ArtAccentDot`**

Create `scripts/ui/theme/art_accent_dot.gd`:

```gdscript
extends Control
class_name ArtAccentDot

# A small glowing dot for a creature art's eye/mouth accent — the same
# stacked-rings-plus-pulse technique as TorchGlow, but tiny, tintable, and
# positioned inside another Control rather than centred on itself.

const STEPS := 10
const PEAK_ALPHA := 0.05

var tint: Color
var _tween: Tween = null

func _init(p_tint: Color = UiTokens.EMBER_LIGHT, p_radius: float = 6.0) -> void:
	tint = p_tint
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(p_radius * 2.0, p_radius * 2.0)
	size = custom_minimum_size

func _ready() -> void:
	_start_pulse()
	queue_redraw()

func is_pulsing() -> bool:
	return _tween != null and _tween.is_valid()

func _draw() -> void:
	var center := size / 2.0
	var radius: float = size.x / 2.0
	for i in range(STEPS):
		var ring_radius: float = radius * (1.0 - float(i) / STEPS)
		draw_circle(center, ring_radius, Color(tint.r, tint.g, tint.b, PEAK_ALPHA))

func _start_pulse() -> void:
	if Engine.is_editor_hint():
		return
	_tween = create_tween().set_loops()
	var half: float = UiTokens.PULSE_SECONDS / 2.0
	_tween.tween_property(self, "modulate:a", 0.5, half).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "modulate:a", 1.0, half).set_trans(Tween.TRANS_SINE)
```

- [ ] **Step 4: Wire accent markers into `ArtPlaceholder`**

Change the `setup()` signature to:

```gdscript
func setup(art_id: StringName, brief: String, art_size: Vector2, use_torchlit_shader: bool = false, accent_markers: Array[Vector2] = []) -> void:
```

Right after the shader block from Task 2, before `return`:

```gdscript
		add_child(texture_rect)
		if use_torchlit_shader:
			var mat := ShaderMaterial.new()
			mat.shader = TORCHLIT_SHADER
			texture_rect.material = mat
		for marker in accent_markers:
			var dot := ArtAccentDot.new()
			dot.position = marker * art_size - dot.custom_minimum_size / 2.0
			add_child(dot)
		return
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: PASS, full suite green.

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/theme/art_accent_dot.gd scripts/ui/theme/art_placeholder.gd tests/unit/test_ui_components.gd
git commit -m "feat: add glowing accent-marker dots to ArtPlaceholder"
```

---

### Task 4: `CreatureArtAccents` — per-creature marker lookup

**Files:**
- Create: `scripts/content/creature_art_accents.gd`
- Test: `tests/unit/test_creature_art_accents.gd`

**Interfaces:**
- Consumes: nothing (pure data lookup).
- Produces: `CreatureArtAccents.markers_for(art_id: StringName) -> Array[Vector2]` — Task 7 calls this directly.

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_creature_art_accents.gd`:

```gdscript
extends GutTest

func test_markers_for_known_creature_returns_its_points():
	var markers := CreatureArtAccents.markers_for(&"enemy_coypu")
	assert_eq(markers.size(), 2)

func test_markers_for_unknown_creature_returns_empty():
	var markers := CreatureArtAccents.markers_for(&"enemy_nonexistent")
	assert_eq(markers, [] as Array[Vector2])
```

- [ ] **Step 2: Run to verify failure**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: FAIL — `CreatureArtAccents` doesn't exist yet.

- [ ] **Step 3: Implement**

Create `scripts/content/creature_art_accents.gd`:

```gdscript
extends RefCounted
class_name CreatureArtAccents

# Eye/mouth accent-glow positions for creature art, keyed by the same art_id
# ArtPlaceholder resolves to a file (scripts/ui/theme/art_placeholder.gd).
# Normalized (0-1) within the art's own display size, hand-placed per
# creature by eye — not derived automatically. See
# docs/superpowers/specs/2026-09-13-creature-art-pipeline-design.md.

const _MARKERS: Dictionary = {
	&"enemy_coypu": [Vector2(0.34, 0.40), Vector2(0.30, 0.55)],
}

static func markers_for(art_id: StringName) -> Array[Vector2]:
	if _MARKERS.has(art_id):
		return _MARKERS[art_id]
	return []
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: PASS, full suite green.

- [ ] **Step 5: Commit**

```bash
git add scripts/content/creature_art_accents.gd tests/unit/test_creature_art_accents.gd
git commit -m "feat: add CreatureArtAccents marker lookup"
```

---

### Task 5: Rename the Act 1 forest enemy from Forest Wolf to Coypu

**Files:**
- Modify: `scripts/content/forest_content.gd`
- Modify: `tests/unit/test_forest_content.gd`
- Modify: `tests/unit/test_run_state.gd:23`

**Interfaces:**
- Consumes: nothing new.
- Produces: `ForestContent.get_enemy_resource()` now returns `id = &"coypu"`, `display_name = "Coypu"` — Task 7's `combat_scene.gd` wiring and Task 4's `CreatureArtAccents` key (`&"enemy_coypu"`, from `"Coypu".to_snake_case()`) both depend on this exact name.

This is a deliberate, minimal scope call: the spec left "does Coypu replace Forest Wolf" open for this plan to resolve. Resolving it as a straight rename (same stats, same move shape, reskinned flavor text) keeps the existing single-first-fight structure intact and makes the pilot asset actually appear in a real playthrough, without redesigning combat balance.

- [ ] **Step 1: Update the failing tests first**

Replace `tests/unit/test_forest_content.gd` entirely:

```gdscript
extends GutTest

func test_coypu_enemy_resource_has_expected_shape():
	var enemy_res := ForestContent.get_enemy_resource()
	assert_eq(enemy_res.display_name, "Coypu")
	assert_eq(enemy_res.max_hp, 16)
	assert_eq(enemy_res.moves.size(), 2)

func test_coypu_moves_have_descriptions_and_display_values():
	var enemy_res := ForestContent.get_enemy_resource()
	for move in enemy_res.moves:
		assert_ne(move.description, "", "A Coypu move should have a non-empty description.")
	var bite: EnemyMove = enemy_res.moves[0]
	assert_eq(bite.intent_type, EnemyMove.IntentType.ATTACK)
	assert_eq(bite.display_value, 4)
	var hiss: EnemyMove = enemy_res.moves[1]
	assert_eq(hiss.intent_type, EnemyMove.IntentType.BUFF)

func test_coypu_hiss_grants_itself_strength():
	var enemy_res := ForestContent.get_enemy_resource()
	var coypu := ActorFactory.build_enemy_actor(enemy_res)
	var hiss: EnemyMove = enemy_res.moves[1]
	var context := EffectContext.new(coypu, coypu)
	for effect in hiss.effects:
		effect.apply(context)
	assert_eq(coypu.get_status_stacks(&"strength"), 1)
```

In `tests/unit/test_run_state.gd`, change line 23 from:

```gdscript
	assert_eq(encounter.enemy.display_name, "Forest Wolf")
```

to:

```gdscript
	assert_eq(encounter.enemy.display_name, "Coypu")
```

- [ ] **Step 2: Run to verify failure**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: FAIL — `ForestContent` still returns "Forest Wolf".

- [ ] **Step 3: Implement**

Replace `scripts/content/forest_content.gd` entirely:

```gdscript
extends RefCounted
class_name ForestContent

# An Act's first fight happens at the forest's edge, before the dungeon
# entrance proper — see docs/design/look-and-feel/Combat.dc.html. Wired
# to an Act's first-floor combat nodes in RunState.build_encounter_for_node
# (only one Act exists today, so this is the run's first fight for now).

static func get_enemy_resource() -> EnemyResource:
	var enemy_res := EnemyResource.new()
	enemy_res.id = &"coypu"
	enemy_res.display_name = "Coypu"
	enemy_res.max_hp = 16
	enemy_res.moves = [_make_bite_move(), _make_hiss_move()]
	return enemy_res

static func _make_bite_move() -> EnemyMove:
	var move := EnemyMove.new()
	move.intent_type = EnemyMove.IntentType.ATTACK
	var effect := DamageEffect.new()
	effect.amount = 4
	move.effects = [effect]
	move.description = "The coypu lunges, its orange incisors bared."
	move.display_value = 4
	return move

static func _make_hiss_move() -> EnemyMove:
	var move := EnemyMove.new()
	move.intent_type = EnemyMove.IntentType.BUFF
	var effect := ApplyStatusEffect.new()
	effect.status_id = &"strength"
	effect.stacks = 1
	effect.apply_to_source = true
	move.effects = [effect]
	move.description = "The coypu hisses, puffing up to guard its burrow."
	move.display_value = 1
	return move
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: PASS, full suite green.

- [ ] **Step 5: Commit**

```bash
git add scripts/content/forest_content.gd tests/unit/test_forest_content.gd tests/unit/test_run_state.gd
git commit -m "refactor: reskin the Act 1 forest enemy as Coypu (was Forest Wolf)"
```

---

### Task 6: Reusable tracing tool + the real Coypu asset

**Files:**
- Create: `tools/art/trace_creature.py`
- Modify: `.gitignore`
- Create: `assets/art_source/coypu/reference.jpg` (gitignored, not committed)
- Create: `assets/art/enemy_coypu.svg`
- Modify: `assets/art/README.md`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `assets/art/enemy_coypu.svg` on disk — Task 7's `ArtPlaceholder.setup(&"enemy_coypu", ...)` call resolves to this file.

This task has no GUT test — it's producing a binary/vector asset and a standalone script, not game logic. It's verified by the asset existing, importing cleanly, and (in Task 7) actually rendering in the running game.

- [ ] **Step 1: Add the source-photo gitignore rule**

In `.gitignore`, add a line after the existing `/.superpowers/` entry:

```
/assets/art_source/
```

- [ ] **Step 2: Write the reusable tracing tool**

Create `tools/art/trace_creature.py`:

```python
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
```

- [ ] **Step 3: Produce the cropped reference photo**

The source photo is at `D:\CC\docs\ragondin.jpg`. Crop it to the subject (removing background margin) and save it as the tracked-but-gitignored reference:

```bash
mkdir -p "D:/CC/assets/art_source/coypu"
"C:/Users/cedri/AppData/Local/Python/pythoncore-3.14-64/python.exe" -c "
from PIL import Image
im = Image.open(r'D:\CC\docs\ragondin.jpg')
w, h = im.size
im.crop((int(w*0.02), 0, int(w*0.90), h)).save(r'D:\CC\assets\art_source\coypu\reference.jpg')
"
```

- [ ] **Step 4: Run the tracing tool**

```bash
"C:/Users/cedri/AppData/Local/Python/pythoncore-3.14-64/python.exe" "D:/CC/tools/art/trace_creature.py" \
  --input "D:/CC/assets/art_source/coypu/reference.jpg" \
  --out-svg "D:/CC/assets/art/enemy_coypu.svg"
```

Expected: `wrote D:/CC/assets/art/enemy_coypu.svg`, no errors from `vtracer`.

- [ ] **Step 5: Import the new asset**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --path "D:/CC" --headless --import`
Expected: completes without error; `enemy_coypu.svg.import` appears next to the new file.

- [ ] **Step 6: Rewrite `assets/art/README.md`**

Replace its contents:

```markdown
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
```

- [ ] **Step 7: Commit**

```bash
git add .gitignore tools/art/trace_creature.py assets/art/enemy_coypu.svg assets/art/enemy_coypu.svg.import assets/art/README.md
git commit -m "feat: add the creature-tracing tool and the Coypu art asset"
```

(`assets/art_source/coypu/reference.jpg` is gitignored and must NOT appear in `git status` as staged — verify with `git status` before committing that only the files above are added.)

---

### Task 7: Wire the Coypu's real art into combat

**Files:**
- Modify: `scripts/ui/combat/combat_scene.gd:209-211`

**Interfaces:**
- Consumes: `ArtPlaceholder.setup()` (Task 3's final shape), `CreatureArtAccents.markers_for()` (Task 4), `assets/art/enemy_coypu.svg` (Task 6), `"Coypu"` as `encounter.enemy.display_name` (Task 5).
- Produces: nothing further consumed elsewhere — this is the integration task.

- [ ] **Step 1: Update the enemy art call site**

In `scripts/ui/combat/combat_scene.gd`, replace:

```gdscript
	var enemy_name: String = encounter.enemy.display_name
	enemy_art.setup(StringName("enemy_" + enemy_name.to_snake_case()), "%s, ready to fight" % enemy_name, Vector2(288, 266))
	enemy_art.size = Vector2(288, 266)
```

with:

```gdscript
	var enemy_name: String = encounter.enemy.display_name
	var enemy_art_id := StringName("enemy_" + enemy_name.to_snake_case())
	enemy_art.setup(enemy_art_id, "%s, ready to fight" % enemy_name, Vector2(288, 266), true, CreatureArtAccents.markers_for(enemy_art_id))
	enemy_art.size = Vector2(288, 266)
```

- [ ] **Step 2: Run the full test suite**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: PASS, full suite green (this exercises the real `enemy_coypu.svg` for the first time through `test_combat_scene.gd`'s existing coverage, if any encounter reaches floor 0 combat — check for regressions there specifically).

- [ ] **Step 3: Visually verify in the running game**

Launch the game (windowed) and start a new run to reach the first combat:

```bash
"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --path "D:/CC"
```

Confirm: the Coypu's traced art shows in the enemy art slot (not a placeholder brief), the ember rim-light is visible along its lit edge, and the two accent-marker glows sit roughly on the eye and mouth — nudge the `Vector2` values in `scripts/content/creature_art_accents.gd`'s `&"enemy_coypu"` entry if they're visibly off, and re-run this step.

- [ ] **Step 4: Commit**

```bash
git add scripts/ui/combat/combat_scene.gd
git commit -m "feat: wire the Coypu's traced art, shader, and accent markers into combat"
```

If Step 3 required nudging the accent markers, include `scripts/content/creature_art_accents.gd` in this commit instead of a separate one.
