# Persistent Character & Camp (Plan 3A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the character (level, XP, skill points, unlocked skills,
equipment) persist across runs and game sessions via a JSON save, apply
the death/victory rules, and add a minimal Camp screen the game boots into.

**Architecture:** Two new autoloads — `MetaState` (the committed record,
ids and ints only) and `SaveManager` (JSON at `user://save.json`) — sit
under the existing `RunState`, which stays the working copy every scene
already reads. `RunState.start_new_run()` and a new `enter_camp()` seed
from `MetaState`; never-lost state (XP/level/skills) writes through and
saves immediately; at-risk state (gear) commits at run end through a new
`finish_run(victory) -> RunOutcome`. A new `CampScene` reuses
`SkillTreeScene`/`InventoryScene` unchanged. A `RunStateTest` base class
isolates every `RunState`-touching test from write-through and from the
real save file.

**Tech Stack:** Godot 4.7.stable, GDScript (strict typing throughout), GUT
9.6.1 for tests.

**Spec:** `docs/superpowers/specs/2026-09-05-persistent-character-design.md`

## Global Constraints

- Every `var`, parameter, and return type is explicitly typed (project
  convention, no exceptions).
- Tests drive the same entry point a real click would (emit the button's
  `pressed` signal, or the view's own public signal) — never call a
  private `_on_*` handler directly.
- `RunState` is a shared autoload singleton — every test that reads or
  mutates its state must call `RunState.start_new_run(...)` (or, from
  Task 5 on, `RunState.enter_camp(...)`) first.
- Any test asserting on a value the combat turn loop can touch (`block`,
  `starting_block`, anything set by a passive) must call
  `encounter.start_player_turn()` before asserting (Plan 2C/2D rule).
- Autoloads have **no `class_name`** (same rule as `RunState`); they are
  addressed by their global name. Autoload order in `project.godot` is
  `MetaState`, `SaveManager`, `RunState`.
- Save format is JSON, `"version": 1`, ids and integers only. A corrupt
  save is renamed `<save_path>.bad`, never overwritten, never crashes.
- Death: all owned and equipped gear removed; `xp` becomes `floori(xp /
  2.0)`; `level`, `skill_points`, `unlocked_skill_nodes` untouched.
  Victory: everything kept. Deck, gold, relics, potions, HP, map reset
  every run regardless.
- Gear changes write through only when `RunState.in_run` is false (Camp).
- No mid-run snapshot/resume (Plan 3B), no story copy beyond one constant
  flavor line, no save slots, no migration beyond version rejection.

## Environment notes (read before running anything)

- Test command (from the repo root):
  `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
  Add `-gtest=<file>.gd[,<file>.gd]` to run a subset.
- **After creating any new `.gd` file** (script or test) run
  `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless --import`
  once, or GUT silently skips the new script and a filtered run reports a
  misleading "all passed" with the *old* test count. Always compare the
  `Scripts`/`Tests` totals in the summary with what you expect.
- The import rewrites line endings in `addons/gut/*.import`; run
  `git checkout -- addons/` before every commit.
- The repo tracks `.uid` files: `git add` the new `.gd.uid` next to every
  new script.
- `user://` under a headless test run resolves to
  `%APPDATA%\Godot\app_userdata\Party Deckbuilder\`. Tests must always
  point `SaveManager.save_path` at `user://test_save.json` (Task 3/4 do
  this) so they never touch the real `save.json`.

---

## Pre-existing code this plan builds on (read-only context, not modified except where a task says so)

- `scripts/run/run_state.gd` — `RunState` autoload. Fields: `class_resource`,
  `persistent_stats`, `deck`, `player_max_hp`, `player_current_hp`, `gold`,
  `map`, `current_floor`, `current_node`, `rng`, `level`, `xp`,
  `skill_points`, `unlocked_skill_nodes: Array[StringName]`,
  `level_bonus_strength`, `level_bonus_block`, `owned_equipment:
  Array[EquipmentResource]`, `equipped_weapon/armor/trinket`,
  `unlocked_relics`, `relic_bonus_strength/block`, `relic_gold_bonus`,
  `potions`. Methods: `start_new_run(class_resource)`,
  `build_encounter_for_node(node)`, `grant_equipment(item)`,
  `equip_item(item)`, `unequip_slot(slot)`, `grant_relic(relic)`,
  `add_potion`, `consume_potion`, `buy_equipment`, `buy_potion`,
  `_apply_passive`, `heal`, `grant_xp(amount)`, `unlock_skill_node(node)
  -> bool`, `upgrade_card`, `apply_event_choice`, `buy_card`,
  `apply_combat_reward`, `mark_node_visited_and_advance`. Consts include
  `MAX_LEVEL := 7`, `XP_THRESHOLDS: Array[int] = [20, 30, 40, 55, 70, 90]`.
  Modified by Tasks 1, 5, 6, 7.
- `scripts/content/dwarf_equipment.gd` — `DwarfEquipment.get_all_equipment()
  -> Array[EquipmentResource]` (6 items: `rusty_shortsword`,
  `dwarven_warhammer`, `leather_vest`, `chainmail`, `lucky_charm`,
  `guardian_amulet`), `get_random_equipment(rng)`. Modified by Task 1.
- `scripts/content/dwarf_skill_tree.gd` — `DwarfSkillTree.get_skill_tree()
  -> Array[SkillNode]` (7 nodes; root `dwarven_grit` has `strength_delta 1`,
  `vitality_delta 1`; `sharpened_pick` has `strength_delta 2`;
  `thick_hide` has `vitality_delta 3`; `reinforced_guard` has
  `block_delta 3`). Modified by Task 1.
- `scripts/run/skill_node.gd` — `SkillNode`: `id`, `display_name`,
  `description`, `branch`, `requires_id`, `strength_delta`,
  `vitality_delta`, `block_delta`, `passive_id`.
- `scripts/resources/equipment_resource.gd` — `EquipmentResource`: `id`,
  `display_name`, `slot: Slot {WEAPON, ARMOR, TRINKET}`, `description`,
  `strength_delta`, `block_delta`, `passive_id`.
- `scripts/stats/persistent_stats.gd` — `PersistentStats.compute_max_hp(
  base_hp) -> int` returns `base_hp + vitality * 2` (vitality is always 0).
- `scripts/content/dwarf_content.gd` — `DwarfContent.get_class_resource()`
  (`base_hp = 30`, 5-card starting deck).
- `scripts/ui/run/run_scene.gd` — `RunScene` orchestrator; `_ready()`
  currently calls `RunState.start_new_run(...)` and `_show_map()`;
  `_swap_to(node)` queue-frees the outgoing non-map child; `_show_victory()`
  / `_show_game_over()` connect the result scenes' `new_run_requested` to
  `_on_new_run_requested()`. Modified by Task 10.
- `scripts/ui/run/victory_scene.gd`, `scripts/ui/run/game_over_scene.gd` —
  each has `signal new_run_requested`, `result_label`, `new_run_button`.
  Modified by Task 9.
- `scripts/ui/run/skill_tree_scene.gd` — `SkillTreeScene` with
  `_status_text()` producing `"Lv %d   XP: %d/%d   Skill Points: %d"` (or
  `"Lv %d (MAX)   Skill Points: %d"` at cap). `CampScene` (Task 8) copies
  this format.
- `project.godot` — `[autoload]` currently has only
  `RunState="*res://scripts/run/run_state.gd"`. Modified by Tasks 2, 3.
- `tests/unit/*.gd` — all `extends GutTest`; none define `before_each`.
  These 11 files touch `RunState` and are switched to `RunStateTest` in
  Task 4: `test_combat_scene.gd`, `test_event_scene.gd`,
  `test_game_over_scene.gd`, `test_inventory_scene.gd`, `test_map_view.gd`,
  `test_rest_scene.gd`, `test_run_scene.gd`, `test_run_state.gd`,
  `test_shop_scene.gd`, `test_skill_tree_scene.gd`, `test_victory_scene.gd`.

---

### Task 1: Content lookups — `DwarfEquipment.get_by_id`, `DwarfSkillTree.get_node_by_id`

**Files:**
- Modify: `scripts/content/dwarf_equipment.gd`
- Modify: `scripts/content/dwarf_skill_tree.gd`
- Modify: `scripts/run/run_state.gd` (replace the nested passive-lookup loop)
- Modify: `tests/unit/test_dwarf_equipment.gd`
- Modify: `tests/unit/test_dwarf_skill_tree.gd`

**Interfaces:**
- Produces: `static func DwarfEquipment.get_by_id(item_id: StringName) ->
  EquipmentResource` (fresh instance, `null` if unknown);
  `static func DwarfSkillTree.get_node_by_id(node_id: StringName) ->
  SkillNode` (`null` if unknown). Consumed by Tasks 2 and 5.

- [ ] **Step 1: Write the failing tests**

Add to `tests/unit/test_dwarf_equipment.gd`:

```gdscript
func test_get_by_id_returns_a_fresh_instance_of_the_known_item():
	var first := DwarfEquipment.get_by_id(&"chainmail")
	var second := DwarfEquipment.get_by_id(&"chainmail")
	assert_not_null(first)
	assert_eq(first.display_name, "Chainmail")
	assert_eq(first.slot, EquipmentResource.Slot.ARMOR)
	assert_ne(first, second, "Each call returns its own instance so two owned copies are distinct.")

func test_get_by_id_returns_null_for_unknown_id():
	assert_null(DwarfEquipment.get_by_id(&"no_such_item"))
```

Add to `tests/unit/test_dwarf_skill_tree.gd`:

```gdscript
func test_get_node_by_id_returns_the_matching_node():
	var node := DwarfSkillTree.get_node_by_id(&"thick_hide")
	assert_not_null(node)
	assert_eq(node.vitality_delta, 3)

func test_get_node_by_id_returns_null_for_unknown_id():
	assert_null(DwarfSkillTree.get_node_by_id(&"no_such_node"))
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_dwarf_equipment.gd,test_dwarf_skill_tree.gd -gexit`
Expected: both test scripts fail to compile (`get_by_id` /
`get_node_by_id` not found) — the summary's `Scripts` count drops and the
GUT output shows `Nonexistent function` / parse errors for these two
files.

- [ ] **Step 3: Add the lookups**

Append to `scripts/content/dwarf_equipment.gd`:

```gdscript
static func get_by_id(item_id: StringName) -> EquipmentResource:
	for item in get_all_equipment():
		if item.id == item_id:
			return item
	return null
```

Append to `scripts/content/dwarf_skill_tree.gd`:

```gdscript
static func get_node_by_id(node_id: StringName) -> SkillNode:
	for node in get_skill_tree():
		if node.id == node_id:
			return node
	return null
```

- [ ] **Step 4: Use `get_node_by_id` in `build_encounter_for_node`**

In `scripts/run/run_state.gd`, replace:

```gdscript
	for node_id in unlocked_skill_nodes:
		for skill_node in DwarfSkillTree.get_skill_tree():
			if skill_node.id == node_id:
				_apply_passive(skill_node.passive_id, player)
```

with:

```gdscript
	for node_id in unlocked_skill_nodes:
		var skill_node := DwarfSkillTree.get_node_by_id(node_id)
		if skill_node != null:
			_apply_passive(skill_node.passive_id, player)
```

- [ ] **Step 5: Run the full suite**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: PASS, 35 scripts, 212 tests (208 + 4 new).

- [ ] **Step 6: Commit**

```bash
git checkout -- addons/
git add scripts/content/dwarf_equipment.gd scripts/content/dwarf_skill_tree.gd scripts/run/run_state.gd tests/unit/test_dwarf_equipment.gd tests/unit/test_dwarf_skill_tree.gd
git commit -m "feat: add equipment and skill-node lookups by id"
```

---

### Task 2: `MetaState` autoload

**Files:**
- Create: `scripts/meta/meta_state.gd`
- Modify: `project.godot`
- Test: `tests/unit/test_meta_state.gd`

**Interfaces:**
- Consumes: `DwarfEquipment.get_by_id`, `DwarfSkillTree.get_node_by_id`
  (Task 1).
- Produces: autoload `MetaState` with fields `class_id: StringName`,
  `level: int`, `xp: int`, `skill_points: int`, `unlocked_skill_nodes:
  Array[StringName]`, `owned_equipment_ids: Array[StringName]`,
  `equipped_weapon_id / equipped_armor_id / equipped_trinket_id:
  StringName`; `func reset() -> void`, `func to_dict() -> Dictionary`,
  `func from_dict(data: Dictionary) -> void`. Consumed by Tasks 3–7, 10.

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_meta_state.gd`:

```gdscript
extends GutTest

func test_reset_restores_a_level_one_dwarf_with_nothing():
	MetaState.level = 4
	MetaState.xp = 9
	MetaState.skill_points = 2
	MetaState.unlocked_skill_nodes = [&"dwarven_grit"]
	MetaState.owned_equipment_ids = [&"chainmail"]
	MetaState.equipped_armor_id = &"chainmail"
	MetaState.reset()
	assert_eq(MetaState.class_id, &"dwarf")
	assert_eq(MetaState.level, 1)
	assert_eq(MetaState.xp, 0)
	assert_eq(MetaState.skill_points, 0)
	assert_eq(MetaState.unlocked_skill_nodes.size(), 0)
	assert_eq(MetaState.owned_equipment_ids.size(), 0)
	assert_eq(MetaState.equipped_weapon_id, &"")
	assert_eq(MetaState.equipped_armor_id, &"")
	assert_eq(MetaState.equipped_trinket_id, &"")

func test_to_dict_from_dict_round_trips_every_field():
	MetaState.reset()
	MetaState.level = 3
	MetaState.xp = 12
	MetaState.skill_points = 1
	MetaState.unlocked_skill_nodes = [&"dwarven_grit", &"sharpened_pick"]
	MetaState.owned_equipment_ids = [&"rusty_shortsword", &"rusty_shortsword", &"leather_vest"]
	MetaState.equipped_weapon_id = &"rusty_shortsword"
	MetaState.equipped_armor_id = &"leather_vest"
	var data := MetaState.to_dict()
	MetaState.reset()
	MetaState.from_dict(data)
	assert_eq(MetaState.level, 3)
	assert_eq(MetaState.xp, 12)
	assert_eq(MetaState.skill_points, 1)
	assert_eq(MetaState.unlocked_skill_nodes, [&"dwarven_grit", &"sharpened_pick"] as Array[StringName])
	assert_eq(MetaState.owned_equipment_ids, [&"rusty_shortsword", &"rusty_shortsword", &"leather_vest"] as Array[StringName])
	assert_eq(MetaState.equipped_weapon_id, &"rusty_shortsword")
	assert_eq(MetaState.equipped_armor_id, &"leather_vest")
	assert_eq(MetaState.equipped_trinket_id, &"")

func test_to_dict_uses_plain_strings_and_ints_so_json_can_carry_it():
	MetaState.reset()
	MetaState.unlocked_skill_nodes = [&"dwarven_grit"]
	MetaState.owned_equipment_ids = [&"chainmail"]
	MetaState.equipped_armor_id = &"chainmail"
	var data := MetaState.to_dict()
	var text := JSON.stringify(data)
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary)
	MetaState.reset()
	MetaState.from_dict(parsed)
	assert_eq(MetaState.unlocked_skill_nodes, [&"dwarven_grit"] as Array[StringName])
	assert_eq(MetaState.equipped_armor_id, &"chainmail")

func test_from_dict_skips_unknown_ids():
	MetaState.reset()
	MetaState.from_dict({
		"level": 2, "xp": 0, "skill_points": 0,
		"unlocked_skill_nodes": ["dwarven_grit", "no_such_node"],
		"owned_equipment_ids": ["no_such_item", "leather_vest"],
	})
	assert_eq(MetaState.unlocked_skill_nodes, [&"dwarven_grit"] as Array[StringName])
	assert_eq(MetaState.owned_equipment_ids, [&"leather_vest"] as Array[StringName])

func test_from_dict_clears_an_equipped_slot_whose_item_is_not_owned():
	MetaState.reset()
	MetaState.from_dict({
		"owned_equipment_ids": ["leather_vest"],
		"equipped_weapon_id": "rusty_shortsword",
		"equipped_armor_id": "leather_vest",
	})
	assert_eq(MetaState.equipped_weapon_id, &"")
	assert_eq(MetaState.equipped_armor_id, &"leather_vest")

func test_from_dict_defaults_missing_fields_and_floors_bad_numbers():
	MetaState.reset()
	MetaState.from_dict({"level": 0, "xp": -5})
	assert_eq(MetaState.level, 1)
	assert_eq(MetaState.xp, 0)
	assert_eq(MetaState.skill_points, 0)
	assert_eq(MetaState.class_id, &"dwarf")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless --import` then
`"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_meta_state.gd -gexit`
Expected: the script fails to compile (`MetaState` identifier not found)
— it is not yet an autoload.

- [ ] **Step 3: Write `MetaState`**

Create `scripts/meta/meta_state.gd`:

```gdscript
extends Node

# Autoload singleton, registered in project.godot as "MetaState" — the
# committed persistent record of the character. Ids and integers only;
# derived values (max HP, strength/block bonuses) are recomputed by
# RunState.load_character_from_meta(). No class_name, same rule as RunState.

var class_id: StringName = &"dwarf"
var level: int = 1
var xp: int = 0
var skill_points: int = 0
var unlocked_skill_nodes: Array[StringName] = []
var owned_equipment_ids: Array[StringName] = []
var equipped_weapon_id: StringName = &""
var equipped_armor_id: StringName = &""
var equipped_trinket_id: StringName = &""

func reset() -> void:
	class_id = &"dwarf"
	level = 1
	xp = 0
	skill_points = 0
	unlocked_skill_nodes = []
	owned_equipment_ids = []
	equipped_weapon_id = &""
	equipped_armor_id = &""
	equipped_trinket_id = &""

func to_dict() -> Dictionary:
	var skill_ids: Array = []
	for node_id in unlocked_skill_nodes:
		skill_ids.append(String(node_id))
	var gear_ids: Array = []
	for item_id in owned_equipment_ids:
		gear_ids.append(String(item_id))
	return {
		"class_id": String(class_id),
		"level": level,
		"xp": xp,
		"skill_points": skill_points,
		"unlocked_skill_nodes": skill_ids,
		"owned_equipment_ids": gear_ids,
		"equipped_weapon_id": String(equipped_weapon_id),
		"equipped_armor_id": String(equipped_armor_id),
		"equipped_trinket_id": String(equipped_trinket_id),
	}

func from_dict(data: Dictionary) -> void:
	reset()
	class_id = StringName(str(data.get("class_id", "dwarf")))
	level = maxi(int(data.get("level", 1)), 1)
	xp = maxi(int(data.get("xp", 0)), 0)
	skill_points = maxi(int(data.get("skill_points", 0)), 0)
	var raw_skills: Variant = data.get("unlocked_skill_nodes", [])
	if raw_skills is Array:
		for raw in raw_skills:
			var node_id := StringName(str(raw))
			if DwarfSkillTree.get_node_by_id(node_id) == null:
				push_warning("MetaState: unknown skill node '%s' in save, skipped" % node_id)
				continue
			unlocked_skill_nodes.append(node_id)
	var raw_gear: Variant = data.get("owned_equipment_ids", [])
	if raw_gear is Array:
		for raw in raw_gear:
			var item_id := StringName(str(raw))
			if DwarfEquipment.get_by_id(item_id) == null:
				push_warning("MetaState: unknown equipment '%s' in save, skipped" % item_id)
				continue
			owned_equipment_ids.append(item_id)
	equipped_weapon_id = _owned_or_empty(str(data.get("equipped_weapon_id", "")))
	equipped_armor_id = _owned_or_empty(str(data.get("equipped_armor_id", "")))
	equipped_trinket_id = _owned_or_empty(str(data.get("equipped_trinket_id", "")))

func _owned_or_empty(raw: String) -> StringName:
	var item_id := StringName(raw)
	if item_id == &"":
		return &""
	if owned_equipment_ids.has(item_id):
		return item_id
	push_warning("MetaState: equipped item '%s' is not owned, slot cleared" % raw)
	return &""
```

- [ ] **Step 4: Register the autoload**

In `project.godot`, change the `[autoload]` section from:

```
[autoload]

RunState="*res://scripts/run/run_state.gd"
```

to:

```
[autoload]

MetaState="*res://scripts/meta/meta_state.gd"
RunState="*res://scripts/run/run_state.gd"
```

(`SaveManager` is inserted between them in Task 3.)

- [ ] **Step 5: Run tests to verify they pass**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless --import` then
`"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_meta_state.gd -gexit`
Expected: PASS, 6/6. The two "unknown id" tests and the "not owned" test
print `push_warning` lines — that is the specified behaviour, not a
failure.

- [ ] **Step 6: Commit**

```bash
git checkout -- addons/
git add scripts/meta/meta_state.gd scripts/meta/meta_state.gd.uid project.godot tests/unit/test_meta_state.gd tests/unit/test_meta_state.gd.uid
git commit -m "feat: add MetaState autoload holding the persistent character record"
```

---

### Task 3: `SaveManager` autoload

**Files:**
- Create: `scripts/meta/save_manager.gd`
- Modify: `project.godot`
- Test: `tests/unit/test_save_manager.gd`

**Interfaces:**
- Consumes: `MetaState.to_dict()`, `from_dict()`, `reset()` (Task 2).
- Produces: autoload `SaveManager` with `const SAVE_VERSION := 1`,
  `const DEFAULT_SAVE_PATH := "user://save.json"`, `var save_path: String`,
  `func save_meta() -> bool`, `func load_meta() -> bool`,
  `func delete_save() -> void`. Consumed by Tasks 4, 6, 7, 10.

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_save_manager.gd`:

```gdscript
extends GutTest

const TEST_PATH := "user://test_save.json"

func before_each() -> void:
	SaveManager.save_path = TEST_PATH
	SaveManager.delete_save()
	_delete_if_exists(TEST_PATH + ".bad")
	MetaState.reset()

func _delete_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _write_raw(text: String) -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func test_save_then_load_round_trips_meta_state():
	MetaState.level = 3
	MetaState.xp = 12
	MetaState.unlocked_skill_nodes = [&"dwarven_grit"]
	MetaState.owned_equipment_ids = [&"leather_vest"]
	MetaState.equipped_armor_id = &"leather_vest"
	assert_true(SaveManager.save_meta())
	MetaState.reset()
	assert_true(SaveManager.load_meta())
	assert_eq(MetaState.level, 3)
	assert_eq(MetaState.xp, 12)
	assert_eq(MetaState.unlocked_skill_nodes, [&"dwarven_grit"] as Array[StringName])
	assert_eq(MetaState.equipped_armor_id, &"leather_vest")

func test_save_writes_versioned_json():
	SaveManager.save_meta()
	var file := FileAccess.open(TEST_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	assert_true(parsed is Dictionary)
	assert_eq(int(parsed["version"]), SaveManager.SAVE_VERSION)
	assert_true(parsed["meta"] is Dictionary)

func test_load_with_no_file_resets_and_returns_false():
	MetaState.level = 5
	assert_false(SaveManager.load_meta())
	assert_eq(MetaState.level, 1)

func test_load_with_corrupt_json_quarantines_the_file_and_resets():
	_write_raw("{ this is not json")
	MetaState.level = 5
	assert_false(SaveManager.load_meta())
	assert_eq(MetaState.level, 1)
	assert_false(FileAccess.file_exists(TEST_PATH), "The bad file is moved, not left in place.")
	assert_true(FileAccess.file_exists(TEST_PATH + ".bad"), "The bad file is kept for inspection.")

func test_load_with_wrong_version_quarantines_the_file_and_resets():
	_write_raw(JSON.stringify({"version": 99, "meta": {"level": 6}}))
	assert_false(SaveManager.load_meta())
	assert_eq(MetaState.level, 1)
	assert_true(FileAccess.file_exists(TEST_PATH + ".bad"))

func test_load_with_non_dictionary_meta_quarantines_the_file_and_resets():
	_write_raw(JSON.stringify({"version": 1, "meta": [1, 2, 3]}))
	assert_false(SaveManager.load_meta())
	assert_eq(MetaState.level, 1)
	assert_true(FileAccess.file_exists(TEST_PATH + ".bad"))

func test_quarantine_overwrites_a_previous_bad_file():
	_write_raw("first bad")
	SaveManager.load_meta()
	_write_raw("second bad")
	SaveManager.load_meta()
	var bad := FileAccess.open(TEST_PATH + ".bad", FileAccess.READ)
	var text := bad.get_as_text()
	bad.close()
	assert_eq(text, "second bad")

func test_delete_save_removes_the_file_and_is_safe_when_missing():
	SaveManager.save_meta()
	assert_true(FileAccess.file_exists(TEST_PATH))
	SaveManager.delete_save()
	assert_false(FileAccess.file_exists(TEST_PATH))
	SaveManager.delete_save()
	assert_false(FileAccess.file_exists(TEST_PATH))
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless --import` then
`"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_save_manager.gd -gexit`
Expected: the script fails to compile (`SaveManager` identifier not
found).

- [ ] **Step 3: Write `SaveManager`**

Create `scripts/meta/save_manager.gd`:

```gdscript
extends Node

# Autoload singleton, registered in project.godot as "SaveManager".
# Reads/writes MetaState as versioned JSON. Never crashes on a bad file:
# it is renamed to "<save_path>.bad" and a fresh character is used.
# No class_name, same rule as RunState.

const SAVE_VERSION := 1
const DEFAULT_SAVE_PATH := "user://save.json"

var save_path: String = DEFAULT_SAVE_PATH

func save_meta() -> bool:
	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"meta": MetaState.to_dict(),
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: cannot write %s (%s)" % [save_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true

func load_meta() -> bool:
	if not FileAccess.file_exists(save_path):
		MetaState.reset()
		return false
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_warning("SaveManager: cannot read %s (%s)" % [save_path, error_string(FileAccess.get_open_error())])
		MetaState.reset()
		return false
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var data: Dictionary = parsed
		var version: int = int(data.get("version", -1))
		var meta: Variant = data.get("meta", null)
		if version == SAVE_VERSION and meta is Dictionary:
			MetaState.from_dict(meta)
			return true
	_quarantine_bad_save()
	MetaState.reset()
	return false

func delete_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

func _quarantine_bad_save() -> void:
	var bad_path: String = save_path + ".bad"
	if FileAccess.file_exists(bad_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(bad_path))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(save_path), ProjectSettings.globalize_path(bad_path))
	push_warning("SaveManager: %s was unreadable or out of date; moved to %s and starting fresh" % [save_path, bad_path])
```

- [ ] **Step 4: Register the autoload**

In `project.godot`, change the `[autoload]` section to:

```
[autoload]

MetaState="*res://scripts/meta/meta_state.gd"
SaveManager="*res://scripts/meta/save_manager.gd"
RunState="*res://scripts/run/run_state.gd"
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless --import` then
`"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_save_manager.gd -gexit`
Expected: PASS, 8/8 (quarantine tests print `push_warning` lines — expected).

Then the full suite:
`"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: PASS, 37 scripts, 226 tests.

- [ ] **Step 6: Commit**

```bash
git checkout -- addons/
git add scripts/meta/save_manager.gd scripts/meta/save_manager.gd.uid project.godot tests/unit/test_save_manager.gd tests/unit/test_save_manager.gd.uid
git commit -m "feat: add SaveManager autoload with versioned JSON save/load"
```

---

### Task 4: `RunStateTest` base class and test isolation

**Files:**
- Create: `tests/unit/run_state_test.gd`
- Modify: the 11 `RunState`-touching test files listed in "Pre-existing
  code" (first line only)

**Interfaces:**
- Consumes: `MetaState.reset()` (Task 2), `SaveManager.save_path`,
  `SaveManager.delete_save()` (Task 3).
- Produces: `class_name RunStateTest extends GutTest` with a
  `before_each()` that isolates every test from persistent state. Every
  later task's new test file `extends RunStateTest`.

- [ ] **Step 1: Create the base class**

Create `tests/unit/run_state_test.gd` (the filename deliberately does
**not** start with `test_`, so GUT never collects it as a test script):

```gdscript
extends GutTest
class_name RunStateTest

# Base class for every test that touches RunState. From Plan 3A on,
# RunState writes level/XP/skills through to MetaState and saves to disk,
# so without this reset one test's unlock would leak into the next test's
# start_new_run() — and hit the real user://save.json.

const TEST_SAVE_PATH := "user://test_save.json"

func before_each() -> void:
	SaveManager.save_path = TEST_SAVE_PATH
	SaveManager.delete_save()
	MetaState.reset()
```

- [ ] **Step 2: Switch the 11 test files to the base class**

From the repo root:

```bash
for f in test_combat_scene test_event_scene test_game_over_scene test_inventory_scene test_map_view test_rest_scene test_run_scene test_run_state test_shop_scene test_skill_tree_scene test_victory_scene; do
  sed -i '1s/^extends GutTest\r\?$/extends RunStateTest/' "tests/unit/$f.gd"
done
grep -L "^extends RunStateTest" tests/unit/test_combat_scene.gd tests/unit/test_event_scene.gd tests/unit/test_game_over_scene.gd tests/unit/test_inventory_scene.gd tests/unit/test_map_view.gd tests/unit/test_rest_scene.gd tests/unit/test_run_scene.gd tests/unit/test_run_state.gd tests/unit/test_shop_scene.gd tests/unit/test_skill_tree_scene.gd tests/unit/test_victory_scene.gd
```

Expected: the `grep -L` prints nothing (every file now extends
`RunStateTest`). The `\r\?` matters: checked-out files are CRLF on this
machine, and a plain `$` would not match.

- [ ] **Step 3: Run the full suite**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless --import` then
`"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: PASS, still 37 scripts / 226 tests — `run_state_test.gd` must
**not** appear as a 38th script. If GUT reports it, the filename prefix is
wrong.

- [ ] **Step 4: Commit**

```bash
git checkout -- addons/
git add tests/unit/run_state_test.gd tests/unit/run_state_test.gd.uid tests/unit/test_combat_scene.gd tests/unit/test_event_scene.gd tests/unit/test_game_over_scene.gd tests/unit/test_inventory_scene.gd tests/unit/test_map_view.gd tests/unit/test_rest_scene.gd tests/unit/test_run_scene.gd tests/unit/test_run_state.gd tests/unit/test_shop_scene.gd tests/unit/test_skill_tree_scene.gd tests/unit/test_victory_scene.gd
git commit -m "test: add RunStateTest base class isolating tests from persistent state"
```

---

### Task 5: `RunState` — seed from `MetaState` (`load_character_from_meta`, `start_new_run`, `enter_camp`, `in_run`)

**Files:**
- Modify: `scripts/run/run_state.gd`
- Modify: `tests/unit/test_run_state.gd`

**Interfaces:**
- Consumes: `MetaState` fields (Task 2), `DwarfEquipment.get_by_id`,
  `DwarfSkillTree.get_node_by_id` (Task 1).
- Produces: `RunState.in_run: bool`, `func load_character_from_meta() ->
  void`, `func enter_camp(p_class_resource: ClassResource) -> void`;
  `start_new_run` now seeds from `MetaState` and sets `in_run = true`.
  Consumed by Tasks 6, 7, 8, 10.

- [ ] **Step 1: Write the failing tests**

Add to `tests/unit/test_run_state.gd`:

```gdscript
func test_start_new_run_seeds_level_xp_and_skills_from_meta_state():
	MetaState.level = 3
	MetaState.xp = 7
	MetaState.skill_points = 1
	MetaState.unlocked_skill_nodes = [&"dwarven_grit", &"sharpened_pick"]
	RunState.start_new_run(DwarfContent.get_class_resource())
	assert_eq(RunState.level, 3)
	assert_eq(RunState.xp, 7)
	assert_eq(RunState.skill_points, 1)
	assert_eq(RunState.unlocked_skill_nodes, [&"dwarven_grit", &"sharpened_pick"] as Array[StringName])
	assert_true(RunState.in_run)

func test_start_new_run_recomputes_bonuses_and_max_hp_from_unlocked_nodes():
	# dwarven_grit: +1 STR, +1 VIT. sharpened_pick: +2 STR. thick_hide: +3 VIT. reinforced_guard: +3 BLK.
	MetaState.unlocked_skill_nodes = [&"dwarven_grit", &"sharpened_pick", &"thick_hide", &"reinforced_guard"]
	var class_res := DwarfContent.get_class_resource()
	RunState.start_new_run(class_res)
	assert_eq(RunState.level_bonus_strength, 3)
	assert_eq(RunState.level_bonus_block, 3)
	assert_eq(RunState.player_max_hp, class_res.base_hp + 2 * 4)
	assert_eq(RunState.player_current_hp, RunState.player_max_hp)

func test_start_new_run_rehydrates_owned_and_equipped_gear_from_meta_state():
	MetaState.owned_equipment_ids = [&"rusty_shortsword", &"rusty_shortsword", &"chainmail"]
	MetaState.equipped_weapon_id = &"rusty_shortsword"
	MetaState.equipped_armor_id = &"chainmail"
	RunState.start_new_run(DwarfContent.get_class_resource())
	assert_eq(RunState.owned_equipment.size(), 3)
	assert_not_null(RunState.equipped_weapon)
	assert_eq(RunState.equipped_weapon.id, &"rusty_shortsword")
	assert_true(RunState.owned_equipment.has(RunState.equipped_weapon), "The equipped instance is one of the owned instances.")
	assert_eq(RunState.equipped_armor.id, &"chainmail")
	assert_null(RunState.equipped_trinket)

func test_start_new_run_still_resets_run_only_state():
	MetaState.level = 4
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.gold = 50
	RunState.grant_relic(DwarfRelics.get_all_relics()[0])
	RunState.add_potion(DwarfPotions.get_all_potions()[0])
	RunState.buy_card(DwarfContent.get_shop_offerings()[0], 0)
	var class_res := DwarfContent.get_class_resource()
	RunState.start_new_run(class_res)
	assert_eq(RunState.gold, 0)
	assert_eq(RunState.unlocked_relics.size(), 0)
	assert_eq(RunState.relic_bonus_strength, 0)
	assert_eq(RunState.potions.size(), 0)
	assert_eq(RunState.deck.size(), class_res.starting_deck.size())
	assert_eq(RunState.level, 4, "Persistent state is kept across runs.")

func test_enter_camp_seeds_the_character_but_starts_no_run():
	MetaState.level = 2
	MetaState.owned_equipment_ids = [&"leather_vest"]
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.gold = 30
	RunState.enter_camp(DwarfContent.get_class_resource())
	assert_false(RunState.in_run)
	assert_null(RunState.map)
	assert_null(RunState.current_node)
	assert_eq(RunState.level, 2)
	assert_eq(RunState.owned_equipment.size(), 1)
	assert_eq(RunState.gold, 0)
	assert_eq(RunState.unlocked_relics.size(), 0)
	assert_eq(RunState.potions.size(), 0)
	assert_eq(RunState.player_current_hp, RunState.player_max_hp)

func test_build_encounter_after_seeding_applies_persistent_skill_passives():
	MetaState.unlocked_skill_nodes = [&"dwarven_grit", &"thick_hide", &"reinforced_guard", &"unyielding"]
	RunState.start_new_run(DwarfContent.get_class_resource())
	var combat_node := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	var encounter := RunState.build_encounter_for_node(combat_node)
	encounter.start_player_turn()
	assert_eq(encounter.player.block, 5, "Unyielding restored from the save still gives 5 starting Block on turn 1.")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_run_state.gd -gexit`
Expected: the script fails to compile (`in_run` / `enter_camp` not found
on `RunState`).

- [ ] **Step 3: Add the field and helpers, rewrite `start_new_run`, add `enter_camp`**

In `scripts/run/run_state.gd`, add the field alongside the others:

```gdscript
var in_run: bool = false
```

Replace the whole `start_new_run` function with:

```gdscript
func start_new_run(p_class_resource: ClassResource) -> void:
	class_resource = p_class_resource
	persistent_stats = PersistentStats.new()
	load_character_from_meta()
	_reset_run_only_state()
	rng = RandomNumberGenerator.new()
	rng.randomize()
	map = MapGraph.generate(rng)
	current_floor = 0
	current_node = map.floors[0][0]
	in_run = true

func enter_camp(p_class_resource: ClassResource) -> void:
	class_resource = p_class_resource
	persistent_stats = PersistentStats.new()
	load_character_from_meta()
	_reset_run_only_state()
	rng = RandomNumberGenerator.new()
	rng.randomize()
	map = null
	current_floor = 0
	current_node = null
	in_run = false

func load_character_from_meta() -> void:
	level = MetaState.level
	xp = MetaState.xp
	skill_points = MetaState.skill_points
	unlocked_skill_nodes = MetaState.unlocked_skill_nodes.duplicate()
	owned_equipment = []
	for item_id in MetaState.owned_equipment_ids:
		var item := DwarfEquipment.get_by_id(item_id)
		if item != null:
			owned_equipment.append(item)
	equipped_weapon = _find_owned(MetaState.equipped_weapon_id)
	equipped_armor = _find_owned(MetaState.equipped_armor_id)
	equipped_trinket = _find_owned(MetaState.equipped_trinket_id)
	level_bonus_strength = 0
	level_bonus_block = 0
	var vitality_total: int = 0
	for node_id in unlocked_skill_nodes:
		var node := DwarfSkillTree.get_node_by_id(node_id)
		if node != null:
			level_bonus_strength += node.strength_delta
			level_bonus_block += node.block_delta
			vitality_total += node.vitality_delta
	player_max_hp = persistent_stats.compute_max_hp(class_resource.base_hp) + vitality_total * 2
	player_current_hp = player_max_hp

func _find_owned(item_id: StringName) -> EquipmentResource:
	if item_id == &"":
		return null
	for item in owned_equipment:
		if item.id == item_id:
			return item
	return null

func _reset_run_only_state() -> void:
	deck = class_resource.starting_deck.duplicate()
	gold = 0
	unlocked_relics = []
	relic_bonus_strength = 0
	relic_bonus_block = 0
	relic_gold_bonus = 0
	potions = []
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_run_state.gd -gexit`
Expected: PASS, including every pre-existing test — they all run under
`RunStateTest.before_each()`, so `MetaState` is at defaults and
`start_new_run` seeds exactly the zeros those tests assumed (e.g.
`test_start_new_run_resets_leveling_state` now passes because `MetaState`
holds level 1, not because the field is zeroed inline).

Then the full suite:
`"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: PASS, 37 scripts, 232 tests.

- [ ] **Step 5: Commit**

```bash
git checkout -- addons/
git add scripts/run/run_state.gd tests/unit/test_run_state.gd
git commit -m "feat: seed RunState from MetaState on start_new_run and enter_camp"
```

---

### Task 6: `RunState` — write-through of never-lost state and Camp gear changes

**Files:**
- Modify: `scripts/run/run_state.gd`
- Modify: `tests/unit/test_run_state.gd`

**Interfaces:**
- Consumes: `MetaState` (Task 2), `SaveManager.save_meta()` /
  `load_meta()` (Task 3), `in_run` (Task 5).
- Produces: private `_commit_never_lost() -> void` and
  `_commit_equipment() -> void` (both pure copies into `MetaState`, no
  I/O). `grant_xp`, `unlock_skill_node` always commit + save;
  `grant_equipment`, `equip_item`, `unequip_slot` commit + save only when
  `not in_run`. Task 7 reuses both helpers.

- [ ] **Step 1: Write the failing tests**

Add to `tests/unit/test_run_state.gd`:

```gdscript
func test_grant_xp_writes_through_to_meta_state_and_saves():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.grant_xp(25)
	assert_eq(RunState.level, 2)
	assert_eq(MetaState.level, 2)
	assert_eq(MetaState.xp, 5)
	assert_eq(MetaState.skill_points, 1)
	MetaState.reset()
	assert_true(SaveManager.load_meta(), "grant_xp saved to disk.")
	assert_eq(MetaState.level, 2)
	assert_eq(MetaState.xp, 5)

func test_unlock_skill_node_writes_through_to_meta_state_and_saves():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.skill_points = 1
	var root: SkillNode = DwarfSkillTree.get_node_by_id(&"dwarven_grit")
	assert_true(RunState.unlock_skill_node(root))
	assert_eq(MetaState.unlocked_skill_nodes, [&"dwarven_grit"] as Array[StringName])
	assert_eq(MetaState.skill_points, 0)
	MetaState.reset()
	SaveManager.load_meta()
	assert_eq(MetaState.unlocked_skill_nodes, [&"dwarven_grit"] as Array[StringName])

func test_failed_unlock_does_not_touch_meta_state():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.skill_points = 0
	var root: SkillNode = DwarfSkillTree.get_node_by_id(&"dwarven_grit")
	assert_false(RunState.unlock_skill_node(root))
	assert_eq(MetaState.unlocked_skill_nodes.size(), 0)
	assert_false(SaveManager.load_meta(), "Nothing was saved.")

func test_gear_changes_inside_a_run_are_not_written_through():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var sword: EquipmentResource = DwarfEquipment.get_by_id(&"rusty_shortsword")
	RunState.grant_equipment(sword)
	RunState.equip_item(sword)
	assert_eq(MetaState.owned_equipment_ids.size(), 0)
	assert_eq(MetaState.equipped_weapon_id, &"")
	assert_false(SaveManager.load_meta(), "Nothing was saved.")

func test_gear_changes_at_camp_are_written_through_and_saved():
	MetaState.owned_equipment_ids = [&"rusty_shortsword", &"chainmail"]
	RunState.enter_camp(DwarfContent.get_class_resource())
	RunState.equip_item(RunState.owned_equipment[0])
	RunState.equip_item(RunState.owned_equipment[1])
	assert_eq(MetaState.equipped_weapon_id, &"rusty_shortsword")
	assert_eq(MetaState.equipped_armor_id, &"chainmail")
	RunState.unequip_slot(EquipmentResource.Slot.ARMOR)
	assert_eq(MetaState.equipped_armor_id, &"")
	MetaState.reset()
	assert_true(SaveManager.load_meta())
	assert_eq(MetaState.owned_equipment_ids, [&"rusty_shortsword", &"chainmail"] as Array[StringName])
	assert_eq(MetaState.equipped_weapon_id, &"rusty_shortsword")
	assert_eq(MetaState.equipped_armor_id, &"")

func test_event_xp_writes_through():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var choice := EventChoice.new()
	choice.xp_delta = 5
	RunState.apply_event_choice(choice)
	assert_eq(MetaState.xp, 5)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_run_state.gd -gexit`
Expected: FAIL — the four write-through tests find `MetaState` untouched
(`test_failed_unlock_does_not_touch_meta_state` and
`test_gear_changes_inside_a_run_are_not_written_through` may already
pass; that is fine).

- [ ] **Step 3: Add the commit helpers and wire them in**

In `scripts/run/run_state.gd`, add (anywhere among the methods):

```gdscript
func _commit_never_lost() -> void:
	MetaState.level = level
	MetaState.xp = xp
	MetaState.skill_points = skill_points
	MetaState.unlocked_skill_nodes = unlocked_skill_nodes.duplicate()

func _commit_equipment() -> void:
	var ids: Array[StringName] = []
	for item in owned_equipment:
		ids.append(item.id)
	MetaState.owned_equipment_ids = ids
	MetaState.equipped_weapon_id = equipped_weapon.id if equipped_weapon != null else &""
	MetaState.equipped_armor_id = equipped_armor.id if equipped_armor != null else &""
	MetaState.equipped_trinket_id = equipped_trinket.id if equipped_trinket != null else &""

func _commit_equipment_if_at_camp() -> void:
	if in_run:
		return
	_commit_equipment()
	SaveManager.save_meta()
```

Change `grant_xp` from:

```gdscript
func grant_xp(amount: int) -> void:
	if level >= MAX_LEVEL:
		return
	xp += amount
	while level < MAX_LEVEL and xp >= XP_THRESHOLDS[level - 1]:
		xp -= XP_THRESHOLDS[level - 1]
		level += 1
		skill_points += 1
	if level >= MAX_LEVEL:
		xp = 0
```

to:

```gdscript
func grant_xp(amount: int) -> void:
	if level >= MAX_LEVEL:
		return
	xp += amount
	while level < MAX_LEVEL and xp >= XP_THRESHOLDS[level - 1]:
		xp -= XP_THRESHOLDS[level - 1]
		level += 1
		skill_points += 1
	if level >= MAX_LEVEL:
		xp = 0
	_commit_never_lost()
	SaveManager.save_meta()
```

In `unlock_skill_node`, change the final two lines from:

```gdscript
	player_max_hp += hp_gain
	player_current_hp += hp_gain
	return true
```

to:

```gdscript
	player_max_hp += hp_gain
	player_current_hp += hp_gain
	_commit_never_lost()
	SaveManager.save_meta()
	return true
```

Change `grant_equipment`, `equip_item`, and `unequip_slot` to:

```gdscript
func grant_equipment(item: EquipmentResource) -> void:
	owned_equipment.append(item)
	_commit_equipment_if_at_camp()

func equip_item(item: EquipmentResource) -> void:
	match item.slot:
		EquipmentResource.Slot.WEAPON:
			equipped_weapon = item
		EquipmentResource.Slot.ARMOR:
			equipped_armor = item
		EquipmentResource.Slot.TRINKET:
			equipped_trinket = item
	_commit_equipment_if_at_camp()

func unequip_slot(slot: EquipmentResource.Slot) -> void:
	match slot:
		EquipmentResource.Slot.WEAPON:
			equipped_weapon = null
		EquipmentResource.Slot.ARMOR:
			equipped_armor = null
		EquipmentResource.Slot.TRINKET:
			equipped_trinket = null
	_commit_equipment_if_at_camp()
```

(`buy_equipment` calls `grant_equipment`, so it is covered;
`apply_event_choice` calls `grant_xp`, so it is covered.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_run_state.gd -gexit`
Expected: PASS.

Then the full suite:
`"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: PASS, 37 scripts, 238 tests. Every scene test that grants XP
or unlocks skills now writes `user://test_save.json` — harmless, and
`RunStateTest.before_each()` deletes it before the next test.

- [ ] **Step 5: Commit**

```bash
git checkout -- addons/
git add scripts/run/run_state.gd tests/unit/test_run_state.gd
git commit -m "feat: write never-lost progression and Camp gear changes through to MetaState"
```

---

### Task 7: `RunOutcome` and `RunState.finish_run`

**Files:**
- Create: `scripts/run/run_outcome.gd`
- Modify: `scripts/run/run_state.gd`
- Modify: `tests/unit/test_run_state.gd`

**Interfaces:**
- Consumes: `_commit_never_lost`, `_commit_equipment` (Task 6), `in_run`
  (Task 5), `SaveManager.save_meta()` (Task 3).
- Produces: `class_name RunOutcome extends RefCounted` with `victory:
  bool`, `gear_lost: int`, `xp_lost: int`; `RunState.finish_run(victory:
  bool) -> RunOutcome`. Consumed by Tasks 9 and 10.

- [ ] **Step 1: Write the failing tests**

Add to `tests/unit/test_run_state.gd`:

```gdscript
func test_finish_run_victory_commits_gear_found_during_the_run():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var hammer: EquipmentResource = DwarfEquipment.get_by_id(&"dwarven_warhammer")
	RunState.grant_equipment(hammer)
	RunState.equip_item(hammer)
	RunState.grant_xp(5)
	var outcome := RunState.finish_run(true)
	assert_true(outcome.victory)
	assert_eq(outcome.gear_lost, 0)
	assert_eq(outcome.xp_lost, 0)
	assert_false(RunState.in_run)
	assert_eq(MetaState.owned_equipment_ids, [&"dwarven_warhammer"] as Array[StringName])
	assert_eq(MetaState.equipped_weapon_id, &"dwarven_warhammer")
	MetaState.reset()
	assert_true(SaveManager.load_meta())
	assert_eq(MetaState.equipped_weapon_id, &"dwarven_warhammer")
	assert_eq(MetaState.xp, 5)

func test_finish_run_death_wipes_gear_and_halves_xp_but_keeps_level_and_skills():
	MetaState.level = 2
	MetaState.owned_equipment_ids = [&"leather_vest"]
	MetaState.equipped_armor_id = &"leather_vest"
	MetaState.unlocked_skill_nodes = [&"dwarven_grit"]
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.grant_equipment(DwarfEquipment.get_by_id(&"rusty_shortsword"))
	RunState.xp = 15
	var outcome := RunState.finish_run(false)
	assert_false(outcome.victory)
	assert_eq(outcome.gear_lost, 2, "Gear owned before the run and gear found during it are both lost.")
	assert_eq(outcome.xp_lost, 8)
	assert_eq(RunState.xp, 7)
	assert_eq(RunState.owned_equipment.size(), 0)
	assert_null(RunState.equipped_armor)
	assert_eq(RunState.level, 2)
	assert_eq(RunState.unlocked_skill_nodes, [&"dwarven_grit"] as Array[StringName])
	assert_false(RunState.in_run)
	assert_eq(MetaState.owned_equipment_ids.size(), 0)
	assert_eq(MetaState.equipped_armor_id, &"")
	assert_eq(MetaState.xp, 7)
	assert_eq(MetaState.level, 2)
	assert_eq(MetaState.unlocked_skill_nodes, [&"dwarven_grit"] as Array[StringName])
	MetaState.reset()
	assert_true(SaveManager.load_meta())
	assert_eq(MetaState.xp, 7)
	assert_eq(MetaState.owned_equipment_ids.size(), 0)

func test_finish_run_death_with_zero_xp_loses_nothing_extra():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var outcome := RunState.finish_run(false)
	assert_eq(outcome.xp_lost, 0)
	assert_eq(outcome.gear_lost, 0)
	assert_eq(RunState.xp, 0)

func test_finish_run_outside_a_run_is_a_no_op():
	MetaState.owned_equipment_ids = [&"chainmail"]
	RunState.enter_camp(DwarfContent.get_class_resource())
	var outcome := RunState.finish_run(false)
	assert_false(outcome.victory)
	assert_eq(outcome.gear_lost, 0)
	assert_eq(outcome.xp_lost, 0)
	assert_eq(RunState.owned_equipment.size(), 1, "Nothing was wiped.")
	assert_eq(MetaState.owned_equipment_ids, [&"chainmail"] as Array[StringName])
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless --import` then
`"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_run_state.gd -gexit`
Expected: the script fails to compile (`finish_run` not found).

- [ ] **Step 3: Create `RunOutcome`**

Create `scripts/run/run_outcome.gd`:

```gdscript
extends RefCounted
class_name RunOutcome

var victory: bool = false
var gear_lost: int = 0
var xp_lost: int = 0
```

- [ ] **Step 4: Add `finish_run`**

Add to `scripts/run/run_state.gd`:

```gdscript
func finish_run(victory: bool) -> RunOutcome:
	var outcome := RunOutcome.new()
	if not in_run:
		push_warning("RunState.finish_run called outside a run; ignored")
		return outcome
	outcome.victory = victory
	if not victory:
		outcome.gear_lost = owned_equipment.size()
		owned_equipment = []
		equipped_weapon = null
		equipped_armor = null
		equipped_trinket = null
		var kept_xp: int = floori(xp / 2.0)
		outcome.xp_lost = xp - kept_xp
		xp = kept_xp
	_commit_equipment()
	_commit_never_lost()
	in_run = false
	SaveManager.save_meta()
	return outcome
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless --import` then
`"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: PASS, 37 scripts, 242 tests (`run_outcome.gd` is not a test).

- [ ] **Step 6: Commit**

```bash
git checkout -- addons/
git add scripts/run/run_outcome.gd scripts/run/run_outcome.gd.uid scripts/run/run_state.gd tests/unit/test_run_state.gd
git commit -m "feat: add RunOutcome and RunState.finish_run with death and victory rules"
```

---

### Task 8: `CampScene`

**Files:**
- Create: `scripts/ui/camp/camp_scene.gd`
- Test: `tests/unit/test_camp_scene.gd`

**Interfaces:**
- Consumes: `RunState.level`, `xp`, `skill_points`, `MAX_LEVEL`,
  `XP_THRESHOLDS`, `equipped_weapon/armor/trinket`, `enter_camp` (Task 5).
- Produces: `class_name CampScene extends Control`; signals
  `skill_tree_requested`, `inventory_requested`, `run_requested`; public
  nodes `status_label: Label`, `gear_label: Label`, `flavor_label: Label`,
  `skill_tree_button: Button`, `inventory_button: Button`,
  `start_run_button: Button`; `const FLAVOR_LINE`; `func refresh() ->
  void`. Consumed by Task 10.

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_camp_scene.gd`:

```gdscript
extends RunStateTest

func test_ready_shows_level_xp_and_skill_points():
	MetaState.level = 2
	MetaState.xp = 7
	MetaState.skill_points = 1
	RunState.enter_camp(DwarfContent.get_class_resource())
	var scene := CampScene.new()
	add_child_autofree(scene)
	assert_eq(scene.status_label.text, "Lv 2   XP: 7/30   Skill Points: 1")

func test_ready_shows_max_level_without_a_threshold():
	MetaState.level = RunState.MAX_LEVEL
	RunState.enter_camp(DwarfContent.get_class_resource())
	var scene := CampScene.new()
	add_child_autofree(scene)
	assert_eq(scene.status_label.text, "Lv 7 (MAX)   Skill Points: 0")

func test_ready_shows_equipped_gear_and_empty_slots():
	MetaState.owned_equipment_ids = [&"chainmail"]
	MetaState.equipped_armor_id = &"chainmail"
	RunState.enter_camp(DwarfContent.get_class_resource())
	var scene := CampScene.new()
	add_child_autofree(scene)
	assert_eq(scene.gear_label.text, "Weapon: — empty —   Armor: Chainmail   Trinket: — empty —")

func test_ready_shows_the_flavor_line():
	RunState.enter_camp(DwarfContent.get_class_resource())
	var scene := CampScene.new()
	add_child_autofree(scene)
	assert_eq(scene.flavor_label.text, CampScene.FLAVOR_LINE)

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
	assert_true(scene.gear_label.text.contains("Trinket: Lucky Charm"))
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless --import` then
`"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_camp_scene.gd -gexit`
Expected: the script fails to compile (`CampScene` not found).

- [ ] **Step 3: Write `CampScene`**

Create `scripts/ui/camp/camp_scene.gd`:

```gdscript
extends Control
class_name CampScene

signal skill_tree_requested
signal inventory_requested
signal run_requested

# The single story hook this plan ships; Camp dialogue proper comes later.
const FLAVOR_LINE := "The party argues over who lost the map."
const EMPTY_SLOT := "— empty —"

var status_label: Label
var gear_label: Label
var flavor_label: Label
var skill_tree_button: Button
var inventory_button: Button
var start_run_button: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root_vbox := VBoxContainer.new()
	add_child(root_vbox)

	var title := Label.new()
	title.text = "Camp"
	root_vbox.add_child(title)

	flavor_label = Label.new()
	flavor_label.text = FLAVOR_LINE
	root_vbox.add_child(flavor_label)

	status_label = Label.new()
	root_vbox.add_child(status_label)

	gear_label = Label.new()
	root_vbox.add_child(gear_label)

	var buttons_hbox := HBoxContainer.new()
	root_vbox.add_child(buttons_hbox)

	skill_tree_button = Button.new()
	skill_tree_button.text = "Skill Tree"
	skill_tree_button.pressed.connect(_on_skill_tree_pressed)
	buttons_hbox.add_child(skill_tree_button)

	inventory_button = Button.new()
	inventory_button.text = "Inventory"
	inventory_button.pressed.connect(_on_inventory_pressed)
	buttons_hbox.add_child(inventory_button)

	start_run_button = Button.new()
	start_run_button.text = "Start Run"
	start_run_button.pressed.connect(_on_start_run_pressed)
	buttons_hbox.add_child(start_run_button)

	refresh()

func refresh() -> void:
	status_label.text = _status_text()
	gear_label.text = "Weapon: %s   Armor: %s   Trinket: %s" % [
		_slot_name(RunState.equipped_weapon),
		_slot_name(RunState.equipped_armor),
		_slot_name(RunState.equipped_trinket),
	]

func _status_text() -> String:
	if RunState.level >= RunState.MAX_LEVEL:
		return "Lv %d (MAX)   Skill Points: %d" % [RunState.level, RunState.skill_points]
	var next_threshold: int = RunState.XP_THRESHOLDS[RunState.level - 1]
	return "Lv %d   XP: %d/%d   Skill Points: %d" % [RunState.level, RunState.xp, next_threshold, RunState.skill_points]

func _slot_name(item: EquipmentResource) -> String:
	return item.display_name if item != null else EMPTY_SLOT

func _on_skill_tree_pressed() -> void:
	skill_tree_requested.emit()

func _on_inventory_pressed() -> void:
	inventory_requested.emit()

func _on_start_run_pressed() -> void:
	run_requested.emit()
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless --import` then
`"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_camp_scene.gd -gexit`
Expected: PASS, 6/6.

- [ ] **Step 5: Commit**

```bash
git checkout -- addons/
git add scripts/ui/camp/camp_scene.gd scripts/ui/camp/camp_scene.gd.uid tests/unit/test_camp_scene.gd tests/unit/test_camp_scene.gd.uid
git commit -m "feat: add CampScene between-run hub"
```

---

### Task 9: `VictoryScene` and `GameOverScene` — show the outcome, Return to Camp

**Files:**
- Modify: `scripts/ui/run/victory_scene.gd`
- Modify: `scripts/ui/run/game_over_scene.gd`
- Modify: `tests/unit/test_victory_scene.gd`
- Modify: `tests/unit/test_game_over_scene.gd`

**Interfaces:**
- Consumes: `RunOutcome` (Task 7).
- Produces: on both scenes — `signal camp_requested` (replaces
  `new_run_requested`), `var outcome: RunOutcome` (set by the caller
  before `add_child`; a `null` outcome is treated as all zeros),
  `outcome_label: Label`, `camp_button: Button` (replaces
  `new_run_button`). Consumed by Task 10.

- [ ] **Step 1: Write the failing tests**

Replace the full contents of `tests/unit/test_victory_scene.gd` with:

```gdscript
extends RunStateTest

func test_ready_shows_the_floor_reached():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.current_floor = 5
	var scene := VictoryScene.new()
	add_child_autofree(scene)
	assert_eq(scene.result_label.text, "Victory! You reached floor 5.")

func test_ready_tells_the_player_everything_is_kept():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var scene := VictoryScene.new()
	scene.outcome = RunState.finish_run(true)
	add_child_autofree(scene)
	assert_eq(scene.outcome_label.text, "Everything you found is yours to keep.")

func test_camp_button_emits_camp_requested():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var scene := VictoryScene.new()
	add_child_autofree(scene)
	watch_signals(scene)
	assert_eq(scene.camp_button.text, "Return to Camp")
	scene.camp_button.pressed.emit()
	assert_signal_emitted(scene, "camp_requested")
```

Replace the full contents of `tests/unit/test_game_over_scene.gd` with:

```gdscript
extends RunStateTest

func test_ready_shows_the_floor_reached():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.current_floor = 3
	var scene := GameOverScene.new()
	add_child_autofree(scene)
	assert_eq(scene.result_label.text, "You died on floor 3.")

func test_ready_shows_what_was_lost():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.grant_equipment(DwarfEquipment.get_by_id(&"chainmail"))
	RunState.grant_equipment(DwarfEquipment.get_by_id(&"lucky_charm"))
	RunState.xp = 15
	var scene := GameOverScene.new()
	scene.outcome = RunState.finish_run(false)
	add_child_autofree(scene)
	assert_eq(scene.outcome_label.text, "Lost 2 piece(s) of gear and 8 XP. Skills are safe.")

func test_ready_without_an_outcome_shows_zero_losses():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var scene := GameOverScene.new()
	add_child_autofree(scene)
	assert_eq(scene.outcome_label.text, "Lost 0 piece(s) of gear and 0 XP. Skills are safe.")

func test_camp_button_emits_camp_requested():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var scene := GameOverScene.new()
	add_child_autofree(scene)
	watch_signals(scene)
	assert_eq(scene.camp_button.text, "Return to Camp")
	scene.camp_button.pressed.emit()
	assert_signal_emitted(scene, "camp_requested")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_victory_scene.gd,test_game_over_scene.gd -gexit`
Expected: both scripts fail to compile (`outcome`, `outcome_label`,
`camp_button` not found).

- [ ] **Step 3: Rewrite the two scenes**

Replace the full contents of `scripts/ui/run/victory_scene.gd` with:

```gdscript
extends Control
class_name VictoryScene

signal camp_requested

# Set by RunScene before add_child; null is treated as an empty outcome.
var outcome: RunOutcome = null

var result_label: Label
var outcome_label: Label
var camp_button: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var vbox := VBoxContainer.new()
	add_child(vbox)

	result_label = Label.new()
	result_label.text = "Victory! You reached floor %d." % RunState.current_floor
	vbox.add_child(result_label)

	outcome_label = Label.new()
	outcome_label.text = "Everything you found is yours to keep."
	vbox.add_child(outcome_label)

	camp_button = Button.new()
	camp_button.text = "Return to Camp"
	camp_button.pressed.connect(_on_camp_pressed)
	vbox.add_child(camp_button)

func _on_camp_pressed() -> void:
	camp_requested.emit()
```

Replace the full contents of `scripts/ui/run/game_over_scene.gd` with:

```gdscript
extends Control
class_name GameOverScene

signal camp_requested

# Set by RunScene before add_child; null is treated as an empty outcome.
var outcome: RunOutcome = null

var result_label: Label
var outcome_label: Label
var camp_button: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var vbox := VBoxContainer.new()
	add_child(vbox)

	result_label = Label.new()
	result_label.text = "You died on floor %d." % RunState.current_floor
	vbox.add_child(result_label)

	var gear_lost: int = outcome.gear_lost if outcome != null else 0
	var xp_lost: int = outcome.xp_lost if outcome != null else 0
	outcome_label = Label.new()
	outcome_label.text = "Lost %d piece(s) of gear and %d XP. Skills are safe." % [gear_lost, xp_lost]
	vbox.add_child(outcome_label)

	camp_button = Button.new()
	camp_button.text = "Return to Camp"
	camp_button.pressed.connect(_on_camp_pressed)
	vbox.add_child(camp_button)

func _on_camp_pressed() -> void:
	camp_requested.emit()
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_victory_scene.gd,test_game_over_scene.gd -gexit`
Expected: PASS, 7/7.

The full suite is expected to **fail** at this point in exactly one
place: `tests/unit/test_run_scene.gd` (and `run_scene.gd` itself) still
reference `new_run_requested` / `new_run_button` — Task 10 fixes both.
Do not run the full suite as a gate here; commit the two scenes and move
straight to Task 10.

- [ ] **Step 5: Commit**

```bash
git checkout -- addons/
git add scripts/ui/run/victory_scene.gd scripts/ui/run/game_over_scene.gd tests/unit/test_victory_scene.gd tests/unit/test_game_over_scene.gd
git commit -m "feat: result scenes show the run outcome and return to Camp"
```

---

### Task 10: `RunScene` — boot to Camp, run lifecycle, home routing

**Files:**
- Modify: `scripts/ui/run/run_scene.gd`
- Modify: `tests/unit/test_run_scene.gd`

**Interfaces:**
- Consumes: `SaveManager.load_meta()` (Task 3), `RunState.enter_camp`,
  `start_new_run`, `in_run` (Task 5), `finish_run` (Task 7), `CampScene`
  (Task 8), `VictoryScene.camp_requested` / `GameOverScene.camp_requested`
  and their `outcome` field (Task 9).
- Produces: `RunScene.camp_scene: CampScene`; the game boots into Camp.
  This is the last task in the plan.

- [ ] **Step 1: Update the existing RunScene tests and add the new ones**

Every existing test in `tests/unit/test_run_scene.gd` starts with

```gdscript
	var scene := RunScene.new()
	add_child_autofree(scene)
```

and then immediately drives the map. Now that `RunScene` boots to Camp,
each of those tests must press **Start Run** first. Apply this
transformation from the repo root (it rewrites those two lines into one
helper call everywhere, then you fix the single test that asserts on
boot behaviour by hand):

```bash
python - <<'PY'
import io, re
p = 'tests/unit/test_run_scene.gd'
s = io.open(p, encoding='utf-8').read().replace('\r\n', '\n')  # working copy is CRLF
s = s.replace("\tvar scene := RunScene.new()\n\tadd_child_autofree(scene)\n", "\tvar scene := _boot_into_run()\n")
helper = '''extends RunStateTest

func _boot_into_run() -> RunScene:
	var scene := RunScene.new()
	add_child_autofree(scene)
	scene.camp_scene.start_run_button.pressed.emit()
	return scene
'''
assert s.startswith("extends RunStateTest\n")
s = helper + s[len("extends RunStateTest\n"):]
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print("rewritten")
PY
```

Then, by hand, replace the first test
`test_ready_starts_a_run_and_shows_the_map` with:

```gdscript
func test_ready_shows_camp_not_the_map():
	var scene := RunScene.new()
	add_child_autofree(scene)
	assert_eq(scene.camp_scene.get_parent(), scene)
	assert_false(scene.map_view.visible)
	assert_false(RunState.in_run)
```

Replace `test_new_run_requested_from_game_over_starts_a_fresh_run_and_shows_map`
with:

```gdscript
func test_return_to_camp_from_game_over_shows_camp_with_the_run_over():
	var scene := _boot_into_run()
	var combat_node := MapNode.new(9999, MapNode.NodeType.COMBAT, 0)
	scene.map_view.node_selected.emit(combat_node)
	scene.combat_scene.combat_dismissed.emit(false)
	scene.game_over_scene.camp_button.pressed.emit()
	assert_eq(scene.camp_scene.get_parent(), scene)
	assert_false(scene.map_view.visible)
	assert_false(RunState.in_run)
```

Append these new tests:

```gdscript
func test_start_run_from_camp_shows_the_map_with_a_run_in_progress():
	var scene := _boot_into_run()
	assert_true(scene.map_view.visible)
	assert_true(RunState.in_run)
	assert_not_null(RunState.map)
	assert_eq(RunState.current_floor, 0)

func test_ready_loads_the_saved_character():
	MetaState.level = 3
	MetaState.unlocked_skill_nodes = [&"dwarven_grit"]
	SaveManager.save_meta()
	MetaState.reset()
	var scene := RunScene.new()
	add_child_autofree(scene)
	assert_eq(RunState.level, 3)
	assert_true(scene.camp_scene.status_label.text.begins_with("Lv 3"))

func test_losing_a_run_applies_the_death_penalty_and_shows_it():
	var scene := _boot_into_run()
	RunState.grant_equipment(DwarfEquipment.get_by_id(&"chainmail"))
	RunState.xp = 10
	var combat_node := MapNode.new(9999, MapNode.NodeType.COMBAT, 1)
	scene.map_view.node_selected.emit(combat_node)
	scene.combat_scene.combat_dismissed.emit(false)
	assert_eq(RunState.owned_equipment.size(), 0)
	assert_eq(RunState.xp, 5)
	assert_eq(MetaState.xp, 5)
	assert_false(RunState.in_run)
	assert_eq(scene.game_over_scene.outcome_label.text, "Lost 1 piece(s) of gear and 5 XP. Skills are safe.")

func test_winning_the_boss_commits_gear_and_returns_to_camp():
	var scene := _boot_into_run()
	RunState.grant_equipment(DwarfEquipment.get_by_id(&"chainmail"))
	var boss_node := MapNode.new(9999, MapNode.NodeType.BOSS, 0)
	scene.map_view.node_selected.emit(boss_node)
	scene.combat_scene.combat_dismissed.emit(true)
	assert_true(MetaState.owned_equipment_ids.has(&"chainmail"))
	assert_false(RunState.in_run)
	scene.victory_scene.camp_button.pressed.emit()
	assert_eq(scene.camp_scene.get_parent(), scene)

func test_skill_unlocked_mid_run_is_in_meta_state_immediately():
	var scene := _boot_into_run()
	RunState.skill_points = 1
	scene.map_view.skill_tree_requested.emit()
	scene.skill_tree_scene.node_buttons[&"dwarven_grit"].pressed.emit()
	assert_true(MetaState.unlocked_skill_nodes.has(&"dwarven_grit"))

func test_skill_tree_opened_from_camp_returns_to_camp():
	var scene := RunScene.new()
	add_child_autofree(scene)
	scene.camp_scene.skill_tree_requested.emit()
	assert_eq(scene.skill_tree_scene.get_parent(), scene)
	scene.skill_tree_scene.back_requested.emit()
	assert_eq(scene.camp_scene.get_parent(), scene)
	assert_false(RunState.in_run)

func test_inventory_opened_from_camp_returns_to_camp():
	var scene := RunScene.new()
	add_child_autofree(scene)
	scene.camp_scene.inventory_requested.emit()
	assert_eq(scene.inventory_scene.get_parent(), scene)
	scene.inventory_scene.back_requested.emit()
	assert_eq(scene.camp_scene.get_parent(), scene)

func test_gear_equipped_at_camp_is_saved_and_carried_into_the_run():
	MetaState.owned_equipment_ids = [&"dwarven_warhammer"]
	SaveManager.save_meta()
	var scene := RunScene.new()
	add_child_autofree(scene)
	scene.camp_scene.inventory_requested.emit()
	var options: VBoxContainer = scene.inventory_scene.slot_options_containers[EquipmentResource.Slot.WEAPON]
	options.get_child(0).pressed.emit()
	assert_eq(MetaState.equipped_weapon_id, &"dwarven_warhammer")
	scene.inventory_scene.back_requested.emit()
	scene.camp_scene.start_run_button.pressed.emit()
	assert_eq(RunState.equipped_weapon.id, &"dwarven_warhammer")
	var combat_node := MapNode.new(9999, MapNode.NodeType.COMBAT, 0)
	scene.map_view.node_selected.emit(combat_node)
	assert_eq(scene.combat_scene.encounter.player.baseline_strike_bonus, 4)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_run_scene.gd -gexit`
Expected: the script fails to compile (`camp_scene` not found on
`RunScene`; `run_scene.gd` itself also fails on `new_run_requested`).

- [ ] **Step 3: Rewrite `RunScene`'s lifecycle**

In `scripts/ui/run/run_scene.gd`:

Add the field alongside the other scene fields:

```gdscript
var camp_scene: CampScene
```

Replace `_ready()` with:

```gdscript
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	map_view = MapView.new()
	map_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_view.node_selected.connect(_on_map_node_selected)
	map_view.skill_tree_requested.connect(_on_skill_tree_requested)
	map_view.inventory_requested.connect(_on_inventory_requested)
	add_child(map_view)
	SaveManager.load_meta()
	RunState.enter_camp(DwarfContent.get_class_resource())
	_show_camp()
```

Add, right after `_show_map()`:

```gdscript
func _show_camp() -> void:
	camp_scene = CampScene.new()
	camp_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	camp_scene.skill_tree_requested.connect(_on_skill_tree_requested)
	camp_scene.inventory_requested.connect(_on_inventory_requested)
	camp_scene.run_requested.connect(_on_run_requested)
	_swap_to(camp_scene)

# Where "Back" goes: the map during a run, Camp between runs.
func _show_home() -> void:
	if RunState.in_run:
		_show_map()
	else:
		_show_camp()

func _on_run_requested() -> void:
	RunState.start_new_run(DwarfContent.get_class_resource())
	_show_map()
```

Change both back handlers to route home:

```gdscript
func _on_skill_tree_back_requested() -> void:
	_show_home()
```

```gdscript
func _on_inventory_back_requested() -> void:
	_show_home()
```

In `_on_combat_dismissed`, change the tail from:

```gdscript
		RunState.mark_node_visited_and_advance(node)
		if node.node_type == MapNode.NodeType.BOSS:
			_show_victory()
		else:
			_show_map()
	else:
		RunState.current_floor = node.floor
		_show_game_over()
```

to:

```gdscript
		RunState.mark_node_visited_and_advance(node)
		if node.node_type == MapNode.NodeType.BOSS:
			_show_victory(RunState.finish_run(true))
		else:
			_show_map()
	else:
		RunState.current_floor = node.floor
		_show_game_over(RunState.finish_run(false))
```

Replace `_show_victory`, `_show_game_over`, and `_on_new_run_requested`
(delete the last one) with:

```gdscript
func _show_victory(outcome: RunOutcome) -> void:
	victory_scene = VictoryScene.new()
	victory_scene.outcome = outcome
	victory_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	victory_scene.camp_requested.connect(_show_camp)
	_swap_to(victory_scene)

func _show_game_over(outcome: RunOutcome) -> void:
	game_over_scene = GameOverScene.new()
	game_over_scene.outcome = outcome
	game_over_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_over_scene.camp_requested.connect(_show_camp)
	_swap_to(game_over_scene)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_run_scene.gd -gexit`
Expected: PASS — every rewritten pre-existing test plus the 9 new ones.

Then the full suite:
`"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: PASS, 38 scripts (35 original + `test_meta_state`,
`test_save_manager`, `test_camp_scene`; `run_state_test.gd` and
`run_outcome.gd` are not test scripts), 260 tests: 208 (Plan 2D) + 4 (T1)
+ 6 (T2) + 8 (T3) + 6 (T5) + 6 (T6) + 4 (T7) + 6 (T8) + 3 (T9: 7 tests
replace 4) + 9 (T10). A different total means a script was not imported
or a test was lost in the Step 1 rewrite — stop and compare the per-script
list against this one.

- [ ] **Step 5: Commit**

```bash
git checkout -- addons/
git add scripts/ui/run/run_scene.gd tests/unit/test_run_scene.gd
git commit -m "feat: boot into Camp, run finish_run on death and victory, route Back home"
```

---

## Manual verification (non-negotiable, per the parent spec's standard)

Open the project in the Godot editor (`C:/Tools/Godot/Godot_v4.7-stable_win64.exe --path .` then F5) and:

1. **Fresh boot:** with no `user://save.json` (delete it from
   `%APPDATA%\Godot\app_userdata\Party Deckbuilder\` if present), the game
   opens on Camp showing `Lv 1   XP: 0/20   Skill Points: 0`, all three
   slots `— empty —`, and the flavor line.
2. **Camp → Skill Tree → Back** lands on Camp, not the map. Same for
   Inventory.
3. **Start Run** shows the map at floor 0. Win a couple of fights, level
   up, unlock `Dwarven Grit` from the map's Skill Tree button. **Quit the
   game entirely** (close the window), relaunch: Camp shows Lv 2 and the
   Skill Tree shows Dwarven Grit ✓. The map/run itself is gone (expected
   until Plan 3B).
4. **Die with gear:** start a run, win an Elite (gear granted), then lose a
   fight. Game Over shows `Lost N piece(s) of gear and M XP. Skills are
   safe.` with N ≥ 1 and M = half your XP progress (rounded down). Return
   to Camp: gear label is all empty, level unchanged, Skill Tree still ✓.
5. **Win a run:** start a run, get gear, beat the Boss. Victory says
   everything is kept; Return to Camp shows the gear equipped/owned, and
   the Inventory lists it.
6. **Camp gear persists:** at Camp, equip a weapon in Inventory, quit,
   relaunch: Camp shows it equipped. Start a run and confirm the very first
   fight's Strike damage reflects the weapon's bonus (compare with a run
   where it is unequipped).
7. **Corrupt save:** quit, open `save.json` in an editor, delete half of
   it, relaunch: the game opens on a level-1 Camp, `save.json.bad` exists
   next to it, and the Output panel shows the `SaveManager` warning.

Automated tests passing is not sufficient on its own to call this plan
done.
