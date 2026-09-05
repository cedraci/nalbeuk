# Run Snapshot & Resume (Plan 3B) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Snapshot the in-progress run every time the player is back on the
map, so quitting and relaunching resumes it from that position, with
Continue Run / Abandon Run at Camp.

**Architecture:** A static `RunSnapshot` serializer captures `RunState`
into an id-only dictionary and restores it. `SaveManager` gains an
in-memory `run_snapshot` and writes one version-2 file `{meta, run}`;
`save_meta`/`load_meta` become `save_game`/`load_game`. `RunState` captures
at exactly two checkpoints (end of `start_new_run`, end of
`mark_node_visited_and_advance`), clears in `finish_run`, and gains
`resume_run` / `abandon_saved_run`. `CampScene` swaps its buttons while a
run is suspended; `RunScene` wires continue and abandon; `GameOverScene`
gets an "abandoned" headline.

**Tech Stack:** Godot 4.7.stable, GDScript (strict typing throughout), GUT
9.6.1 for tests.

**Spec:** `docs/superpowers/specs/2026-09-05-run-snapshot-design.md`

## Global Constraints

- Every `var`, parameter, and return type is explicitly typed (project
  convention, no exceptions).
- Tests drive the same entry point a real click would (emit the button's
  `pressed` signal, or the view's own public signal) — never call a
  private `_on_*` handler directly.
- Every test that touches `RunState` `extends RunStateTest` and calls
  `RunState.start_new_run(...)` / `enter_camp(...)` first.
- Any test asserting on a value the combat turn loop can touch calls
  `encounter.start_player_turn()` before asserting (Plan 2C/2D rule).
- Snapshots are taken **between nodes only**: exactly two capture points
  (end of `start_new_run`, end of `mark_node_visited_and_advance`);
  `finish_run` clears the snapshot. Nothing else captures.
- Snapshot content is ids and scalars only; `rng_seed` / `rng_state` are
  **strings** (64-bit ints do not survive JSON doubles).
- Level, XP, skill points, unlocked skills are **not** in the snapshot —
  `resume_run` seeds them from `MetaState` like `start_new_run`.
- Save file version is 2; version-1 files still load (no suspended run).
  A broken snapshot is discarded with **no penalty**. Abandon Run applies
  the death rules (Plan 3A `finish_run(false)`), `RunOutcome.abandoned =
  true`.
- No `class_name` on autoloads. No confirmation dialogs, no save slots,
  no mid-combat resume.

## Environment notes (read before running anything)

- Test command (repo root):
  `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
  `-gtest=` does **not** actually narrow the run in this GUT version; every
  run is the full suite — read the per-script lines or the totals.
- **After creating any new `.gd` file** run
  `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless --import`
  once, or GUT silently skips it and the totals stay at the old count.
- The import rewrites `addons/gut/*.import` line endings: run
  `git checkout -- addons/` before every commit. `git add` the new
  `.gd.uid` next to every new script.
- Checked-out files are CRLF; any scripted edit must normalize
  (`.replace('\r\n', '\n')` in Python, `\r\?` in sed).
- `user://` in headless runs is `%APPDATA%\Godot\app_userdata\Party
  Deckbuilder\`; `RunStateTest.before_each` points `SaveManager` at
  `user://test_save.json`.

---

## Pre-existing code this plan builds on (read-only context, not modified except where a task says so)

- `scripts/run/run_state.gd` — after Plan 3A. Relevant: `in_run`,
  `class_resource`, `persistent_stats`, `deck: Array[CardResource]`,
  `player_max_hp`, `player_current_hp`, `gold`, `map: MapGraph`,
  `current_floor`, `current_node: MapNode`, `rng`, `owned_equipment`,
  `equipped_weapon/armor/trinket`, `unlocked_relics: Array[StringName]`,
  `relic_bonus_strength/block`, `relic_gold_bonus`, `potions:
  Array[PotionResource]`, `MAX_POTIONS := 2`. Methods:
  `start_new_run(class_res)`, `enter_camp(class_res)`,
  `load_character_from_meta()`, `_reset_run_only_state()`,
  `finish_run(victory) -> RunOutcome` (ends with `in_run = false;
  SaveManager.save_meta(); return outcome`),
  `mark_node_visited_and_advance(node)`, `buy_card`, `upgrade_card`,
  `grant_relic`, `add_potion`, `grant_equipment`, `equip_item`. Four
  `SaveManager.save_meta()` calls. Modified by Tasks 3 and 5.
- `scripts/run/run_outcome.gd` — `RunOutcome`: `victory`, `gear_lost`,
  `xp_lost`. Modified by Task 4.
- `scripts/run/map_graph.gd` — `MapGraph`: `var floors: Array` (of
  `Array[MapNode]`), `static generate(rng)`. Modified by Task 2.
- `scripts/run/map_node.gd` — `MapNode(id, node_type, floor)`,
  `connections: Array[int]`, `visited: bool`, `enum NodeType {COMBAT,
  ELITE, EVENT, REST, SHOP, BOSS, TREASURE}`.
- `scripts/meta/save_manager.gd` — `SAVE_VERSION := 1`,
  `DEFAULT_SAVE_PATH`, `save_path`, `save_meta() -> bool`, `load_meta() ->
  bool` (quarantines bad files to `<path>.bad`), `delete_save()`,
  `_quarantine_bad_save()`. Modified by Task 3.
- `scripts/content/dwarf_content.gd` — private card builders
  `_make_strike_card`, `_make_guard_card`, `_make_strike_plus_card`,
  `_make_guard_plus_card` (ids `dwarf_strike`, `dwarf_guard`,
  `dwarf_strike_plus`, `dwarf_guard_plus`); `get_shop_offerings()` returns
  `[Strike, Guard]`. Modified by Task 1.
- `scripts/content/dwarf_relics.gd` (`iron_ration` +3 VIT, `whetstone` +2
  STR, `reinforced_buckle` +2 BLK, `merchants_ledger` +5 gold) and
  `scripts/content/dwarf_potions.gd` (`healing_draught`, `vigor_tonic`).
  Modified by Task 1.
- `scripts/content/dwarf_equipment.gd` — `get_by_id(id)` exists (Plan 3A).
- `scripts/ui/camp/camp_scene.gd` — `CampScene`: `FLAVOR_LINE`,
  `status_label`, `gear_label`, `flavor_label`, `skill_tree_button`,
  `inventory_button`, `start_run_button`, signals `skill_tree_requested`,
  `inventory_requested`, `run_requested`, `refresh()`. Modified by Task 6.
- `scripts/ui/run/run_scene.gd` — `_ready()` calls
  `SaveManager.load_meta()`, `RunState.enter_camp(...)`, `_show_camp()`;
  `_show_camp()` connects the three Camp signals; `_show_game_over(outcome)`
  / `_show_victory(outcome)`. Modified by Tasks 3 and 7.
- `scripts/ui/run/game_over_scene.gd` — `outcome: RunOutcome`,
  `result_label` = `"You died on floor %d." % RunState.current_floor`.
  Modified by Task 7.
- `tests/unit/run_state_test.gd` — `RunStateTest.before_each()` sets
  `SaveManager.save_path`, `delete_save()`, `MetaState.reset()`. Modified
  by Task 3.
- `tests/unit/test_run_scene.gd` — has `_boot_into_run() -> RunScene`
  (new `RunScene`, `add_child_autofree`, presses Start Run). Modified by
  Task 7.
- Files calling `save_meta`/`load_meta` (renamed in Task 3):
  `scripts/run/run_state.gd`, `scripts/ui/run/run_scene.gd`,
  `tests/unit/test_run_state.gd`, `tests/unit/test_run_scene.gd`,
  `tests/unit/test_save_manager.gd`.

Baseline: 38 scripts, 259 tests, all passing at `a9fe44f`.

---

### Task 1: Content lookups — cards, relics, potions by id

**Files:**
- Modify: `scripts/content/dwarf_content.gd`
- Modify: `scripts/content/dwarf_relics.gd`
- Modify: `scripts/content/dwarf_potions.gd`
- Create: `tests/unit/test_dwarf_cards.gd`
- Modify: `tests/unit/test_dwarf_relics.gd`
- Modify: `tests/unit/test_dwarf_potions.gd`

**Interfaces:**
- Produces: `static DwarfContent.get_card_by_id(card_id: StringName) ->
  CardResource`, `static DwarfRelics.get_by_id(relic_id: StringName) ->
  RelicResource`, `static DwarfPotions.get_by_id(potion_id: StringName) ->
  PotionResource` — fresh instance or `null`. Consumed by Task 4.

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_dwarf_cards.gd`:

```gdscript
extends GutTest

func test_get_card_by_id_returns_each_known_card():
	assert_eq(DwarfContent.get_card_by_id(&"dwarf_strike").display_name, "Strike")
	assert_eq(DwarfContent.get_card_by_id(&"dwarf_guard").display_name, "Guard")
	assert_eq(DwarfContent.get_card_by_id(&"dwarf_strike_plus").display_name, "Strike+")
	assert_eq(DwarfContent.get_card_by_id(&"dwarf_guard_plus").display_name, "Guard+")

func test_get_card_by_id_returns_fresh_instances():
	var first := DwarfContent.get_card_by_id(&"dwarf_strike")
	var second := DwarfContent.get_card_by_id(&"dwarf_strike")
	assert_ne(first, second)

func test_get_card_by_id_returns_null_for_unknown_id():
	assert_null(DwarfContent.get_card_by_id(&"no_such_card"))
```

Add to `tests/unit/test_dwarf_relics.gd`:

```gdscript
func test_get_by_id_returns_the_matching_relic():
	var relic := DwarfRelics.get_by_id(&"whetstone")
	assert_not_null(relic)
	assert_eq(relic.strength_delta, 2)

func test_get_by_id_returns_null_for_unknown_id():
	assert_null(DwarfRelics.get_by_id(&"no_such_relic"))
```

Add to `tests/unit/test_dwarf_potions.gd`:

```gdscript
func test_get_by_id_returns_the_matching_potion():
	var potion := DwarfPotions.get_by_id(&"vigor_tonic")
	assert_not_null(potion)
	assert_eq(potion.strength_stacks, 3)

func test_get_by_id_returns_null_for_unknown_id():
	assert_null(DwarfPotions.get_by_id(&"no_such_potion"))
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless --import` then
`"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: `SCRIPT ERROR: Parse Error: Static function "get_card_by_id()"
not found` (and the relic/potion equivalents); those three scripts fail
to load.

- [ ] **Step 3: Add the lookups**

Append to `scripts/content/dwarf_content.gd`:

```gdscript
static func get_card_by_id(card_id: StringName) -> CardResource:
	match card_id:
		&"dwarf_strike":
			return _make_strike_card()
		&"dwarf_guard":
			return _make_guard_card()
		&"dwarf_strike_plus":
			return _make_strike_plus_card()
		&"dwarf_guard_plus":
			return _make_guard_plus_card()
		_:
			return null
```

Append to `scripts/content/dwarf_relics.gd`:

```gdscript
static func get_by_id(relic_id: StringName) -> RelicResource:
	for relic in get_all_relics():
		if relic.id == relic_id:
			return relic
	return null
```

Append to `scripts/content/dwarf_potions.gd`:

```gdscript
static func get_by_id(potion_id: StringName) -> PotionResource:
	for potion in get_all_potions():
		if potion.id == potion_id:
			return potion
	return null
```

- [ ] **Step 4: Run the full suite**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: PASS, 39 scripts, 266 tests.

- [ ] **Step 5: Commit**

```bash
git checkout -- addons/
git add scripts/content/dwarf_content.gd scripts/content/dwarf_relics.gd scripts/content/dwarf_potions.gd tests/unit/test_dwarf_cards.gd tests/unit/test_dwarf_cards.gd.uid tests/unit/test_dwarf_relics.gd tests/unit/test_dwarf_potions.gd
git commit -m "feat: add card, relic, and potion lookups by id"
```

---

### Task 2: `MapGraph.to_dict` / `from_dict` / `find_node`

**Files:**
- Modify: `scripts/run/map_graph.gd`
- Modify: `tests/unit/test_map_graph.gd`

**Interfaces:**
- Produces: `func MapGraph.to_dict() -> Dictionary`,
  `static func MapGraph.from_dict(data: Dictionary) -> MapGraph` (`null`
  when malformed), `func MapGraph.find_node(node_id: int) -> MapNode`
  (`null` if absent). Consumed by Task 4.

- [ ] **Step 1: Write the failing tests**

Add to `tests/unit/test_map_graph.gd`:

```gdscript
func _signature(graph: MapGraph) -> Array:
	var out: Array = []
	for floor_nodes in graph.floors:
		for node in floor_nodes:
			out.append("%d:%d:%d:%s:%s" % [node.id, node.node_type, node.floor, str(node.connections), str(node.visited)])
	return out

func test_to_dict_from_dict_round_trips_a_generated_graph():
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var graph := MapGraph.generate(rng)
	graph.floors[1][0].visited = true
	var rebuilt := MapGraph.from_dict(graph.to_dict())
	assert_not_null(rebuilt)
	assert_eq(rebuilt.floors.size(), graph.floors.size())
	assert_eq(_signature(rebuilt), _signature(graph))

func test_to_dict_survives_json():
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var graph := MapGraph.generate(rng)
	var parsed: Variant = JSON.parse_string(JSON.stringify(graph.to_dict()))
	var rebuilt := MapGraph.from_dict(parsed)
	assert_eq(_signature(rebuilt), _signature(graph))

func test_find_node_returns_the_node_or_null():
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var graph := MapGraph.generate(rng)
	var target: MapNode = graph.floors[2][0]
	assert_eq(graph.find_node(target.id), target)
	assert_null(graph.find_node(9999))

func test_from_dict_returns_null_for_malformed_data():
	assert_null(MapGraph.from_dict({}))
	assert_null(MapGraph.from_dict({"floors": []}))
	assert_null(MapGraph.from_dict({"floors": [[{"type": 0, "floor": 0}]]}), "A node without an id is malformed.")
	assert_null(MapGraph.from_dict({"floors": ["not a floor"]}))
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: `test_map_graph.gd` fails to load (`to_dict` / `from_dict` /
`find_node` not found).

- [ ] **Step 3: Implement**

Append to `scripts/run/map_graph.gd`:

```gdscript
func to_dict() -> Dictionary:
	var floors_data: Array = []
	for floor_nodes in floors:
		var nodes_data: Array = []
		for node in floor_nodes:
			var connections: Array = []
			for connection_id in node.connections:
				connections.append(connection_id)
			nodes_data.append({
				"id": node.id,
				"type": int(node.node_type),
				"floor": node.floor,
				"connections": connections,
				"visited": node.visited,
			})
		floors_data.append(nodes_data)
	return {"floors": floors_data}

static func from_dict(data: Dictionary) -> MapGraph:
	var raw_floors: Variant = data.get("floors", null)
	if not (raw_floors is Array):
		return null
	var floors_array: Array = raw_floors
	if floors_array.is_empty():
		return null
	var graph := MapGraph.new()
	for raw_floor in floors_array:
		if not (raw_floor is Array):
			return null
		var floor_nodes: Array[MapNode] = []
		for raw_node in raw_floor:
			if not (raw_node is Dictionary):
				return null
			var node_data: Dictionary = raw_node
			if not (node_data.has("id") and node_data.has("type") and node_data.has("floor")):
				return null
			var node_type: MapNode.NodeType = int(node_data["type"]) as MapNode.NodeType
			var node := MapNode.new(int(node_data["id"]), node_type, int(node_data["floor"]))
			var raw_connections: Variant = node_data.get("connections", [])
			if raw_connections is Array:
				for connection_id in raw_connections:
					node.connections.append(int(connection_id))
			node.visited = bool(node_data.get("visited", false))
			floor_nodes.append(node)
		graph.floors.append(floor_nodes)
	return graph

func find_node(node_id: int) -> MapNode:
	for floor_nodes in floors:
		for node in floor_nodes:
			if node.id == node_id:
				return node
	return null
```

- [ ] **Step 4: Run the full suite**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: PASS, 39 scripts, 270 tests.

- [ ] **Step 5: Commit**

```bash
git checkout -- addons/
git add scripts/run/map_graph.gd tests/unit/test_map_graph.gd
git commit -m "feat: serialize MapGraph to and from a dictionary"
```

---

### Task 3: `SaveManager` version 2 — `run_snapshot`, `save_game` / `load_game`

**Files:**
- Modify: `scripts/meta/save_manager.gd`
- Modify: `tests/unit/run_state_test.gd`
- Modify (rename callers): `scripts/run/run_state.gd`,
  `scripts/ui/run/run_scene.gd`, `tests/unit/test_run_state.gd`,
  `tests/unit/test_run_scene.gd`, `tests/unit/test_save_manager.gd`
- Modify: `tests/unit/test_save_manager.gd` (new tests)

**Interfaces:**
- Produces: `SaveManager.SAVE_VERSION := 2`,
  `SaveManager.OLDEST_READABLE_VERSION := 1`, `var run_snapshot: Variant`
  (`null` or `Dictionary`), `func save_game() -> bool`, `func load_game()
  -> bool`, `func has_run_snapshot() -> bool`; `delete_save()` also clears
  `run_snapshot`. `save_meta` / `load_meta` no longer exist. Consumed by
  Tasks 5, 6, 7.

- [ ] **Step 1: Rename the callers and extend the test base class**

From the repo root:

```bash
for f in scripts/run/run_state.gd scripts/ui/run/run_scene.gd tests/unit/test_run_state.gd tests/unit/test_run_scene.gd tests/unit/test_save_manager.gd; do
  sed -i 's/save_meta/save_game/g; s/load_meta/load_game/g' "$f"
done
grep -rn "save_meta\|load_meta" scripts tests --include=*.gd
```

Expected: the final `grep` prints only lines from
`scripts/meta/save_manager.gd` (the definitions — renamed in Step 4).

In `tests/unit/run_state_test.gd`, change `before_each` to:

```gdscript
func before_each() -> void:
	SaveManager.save_path = TEST_SAVE_PATH
	SaveManager.delete_save()
	SaveManager.run_snapshot = null
	MetaState.reset()
```

- [ ] **Step 2: Write the failing tests**

In `tests/unit/test_save_manager.gd`, replace its `before_each` with:

```gdscript
func before_each() -> void:
	SaveManager.save_path = TEST_PATH
	SaveManager.delete_save()
	_delete_if_exists(TEST_PATH + ".bad")
	MetaState.reset()
	SaveManager.run_snapshot = null
```

Then add to the same file:

```gdscript
func test_save_game_writes_version_two_with_a_null_run_when_nothing_is_suspended():
	SaveManager.run_snapshot = null
	SaveManager.save_game()
	var file := FileAccess.open(TEST_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	assert_eq(int(parsed["version"]), 2)
	assert_true(parsed.has("run"))
	assert_null(parsed["run"])

func test_run_snapshot_round_trips_through_the_file():
	SaveManager.run_snapshot = {"current_floor": 3, "gold": 12, "deck": ["dwarf_strike"]}
	SaveManager.save_game()
	SaveManager.run_snapshot = null
	assert_true(SaveManager.load_game())
	assert_true(SaveManager.has_run_snapshot())
	assert_eq(int(SaveManager.run_snapshot["current_floor"]), 3)
	assert_eq(int(SaveManager.run_snapshot["gold"]), 12)

func test_version_one_file_loads_with_no_suspended_run():
	_write_raw(JSON.stringify({"version": 1, "meta": {"level": 4}}))
	SaveManager.run_snapshot = {"stale": true}
	assert_true(SaveManager.load_game())
	assert_eq(MetaState.level, 4)
	assert_false(SaveManager.has_run_snapshot())
	assert_false(FileAccess.file_exists(TEST_PATH + ".bad"), "A version-1 file is not quarantined.")

func test_malformed_run_section_is_dropped_but_the_character_is_kept():
	_write_raw(JSON.stringify({"version": 2, "meta": {"level": 3}, "run": "garbage"}))
	assert_true(SaveManager.load_game())
	assert_eq(MetaState.level, 3)
	assert_false(SaveManager.has_run_snapshot())
	assert_false(FileAccess.file_exists(TEST_PATH + ".bad"))

func test_delete_save_clears_the_snapshot():
	SaveManager.run_snapshot = {"current_floor": 1}
	SaveManager.delete_save()
	assert_false(SaveManager.has_run_snapshot())

func test_missing_file_clears_the_snapshot():
	SaveManager.run_snapshot = {"current_floor": 1}
	assert_false(SaveManager.load_game())
	assert_false(SaveManager.has_run_snapshot())
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: many scripts fail to load — `save_game` / `load_game` /
`run_snapshot` do not exist yet on `SaveManager`.

- [ ] **Step 4: Rewrite `SaveManager`**

Replace the full contents of `scripts/meta/save_manager.gd` with:

```gdscript
extends Node

# Autoload singleton, registered in project.godot as "SaveManager".
# Writes one versioned JSON file holding the persistent character (meta)
# and, while a run is suspended, its snapshot (run). Never crashes on a bad
# file: it is renamed to "<save_path>.bad" and a fresh character is used.
# No class_name, same rule as RunState.

const SAVE_VERSION := 2
const OLDEST_READABLE_VERSION := 1
const DEFAULT_SAVE_PATH := "user://save.json"

var save_path: String = DEFAULT_SAVE_PATH
# The latest run snapshot (RunSnapshot.capture()), or null when no run is
# suspended. RunState refreshes it at its checkpoints; save_game() writes it.
var run_snapshot: Variant = null

func save_game() -> bool:
	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"meta": MetaState.to_dict(),
		"run": run_snapshot,
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: cannot write %s (%s)" % [save_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		MetaState.reset()
		run_snapshot = null
		return false
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_warning("SaveManager: cannot read %s (%s)" % [save_path, error_string(FileAccess.get_open_error())])
		MetaState.reset()
		run_snapshot = null
		return false
	var text: String = file.get_as_text()
	file.close()
	# JSON.parse() reports malformed input as a return code; JSON.parse_string()
	# would also log an engine error, which is noise for a file we quarantine anyway.
	var json := JSON.new()
	if json.parse(text) == OK and json.data is Dictionary:
		var data: Dictionary = json.data
		var version: int = int(data.get("version", -1))
		var meta: Variant = data.get("meta", null)
		if version >= OLDEST_READABLE_VERSION and version <= SAVE_VERSION and meta is Dictionary:
			MetaState.from_dict(meta)
			var raw_run: Variant = data.get("run", null)
			if raw_run == null or raw_run is Dictionary:
				run_snapshot = raw_run
			else:
				push_warning("SaveManager: run section of %s is unreadable; suspended run discarded" % save_path)
				run_snapshot = null
			return true
	_quarantine_bad_save()
	MetaState.reset()
	run_snapshot = null
	return false

func has_run_snapshot() -> bool:
	return run_snapshot is Dictionary

func delete_save() -> void:
	run_snapshot = null
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

func _quarantine_bad_save() -> void:
	var bad_path: String = save_path + ".bad"
	if FileAccess.file_exists(bad_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(bad_path))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(save_path), ProjectSettings.globalize_path(bad_path))
	push_warning("SaveManager: %s was unreadable or out of date; moved to %s and starting fresh" % [save_path, bad_path])
```

- [ ] **Step 5: Run the full suite**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: PASS, 39 scripts, 276 tests. The pre-existing
`test_load_with_wrong_version_quarantines_the_file_and_resets` (version
99) and `test_save_writes_versioned_json` (asserts `SAVE_VERSION`) still
pass unchanged.

- [ ] **Step 6: Commit**

```bash
git checkout -- addons/
git add scripts/meta/save_manager.gd scripts/run/run_state.gd scripts/ui/run/run_scene.gd tests/unit/run_state_test.gd tests/unit/test_run_state.gd tests/unit/test_run_scene.gd tests/unit/test_save_manager.gd
git commit -m "feat: SaveManager v2 carries a run snapshot alongside the character"
```

---

### Task 4: `RunSnapshot.capture` / `restore` and `RunOutcome.abandoned`

**Files:**
- Create: `scripts/run/run_snapshot.gd`
- Modify: `scripts/run/run_outcome.gd`
- Test: `tests/unit/test_run_snapshot.gd`

**Interfaces:**
- Consumes: `DwarfContent.get_card_by_id`, `DwarfRelics.get_by_id`,
  `DwarfPotions.get_by_id` (Task 1), `DwarfEquipment.get_by_id`,
  `MapGraph.to_dict/from_dict/find_node` (Task 2).
- Produces: `class_name RunSnapshot extends RefCounted` with
  `static func capture() -> Dictionary` (empty `{}` with a warning when no
  run is in progress) and `static func restore(data: Dictionary) -> bool`
  (writes `RunState` fields; `false` and untouched when the map or
  current node cannot be resolved). `RunOutcome.abandoned: bool`.
  Consumed by Tasks 5 and 7.

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_run_snapshot.gd`:

```gdscript
extends RunStateTest

func _map_signature(graph: MapGraph) -> Array:
	var out: Array = []
	for floor_nodes in graph.floors:
		for node in floor_nodes:
			out.append("%d:%d:%d:%s:%s" % [node.id, node.node_type, node.floor, str(node.connections), str(node.visited)])
	return out

func _deck_ids() -> Array:
	var out: Array = []
	for card in RunState.deck:
		out.append(card.id)
	return out

func _start_and_mutate_a_run() -> MapNode:
	MetaState.unlocked_skill_nodes = [&"dwarven_grit"]
	RunState.start_new_run(DwarfContent.get_class_resource())
	var second_floor_node: MapNode = RunState.map.floors[1][0]
	RunState.mark_node_visited_and_advance(second_floor_node)
	RunState.gold = 40
	RunState.buy_card(DwarfContent.get_shop_offerings()[1], 15)
	RunState.upgrade_card(&"dwarf_strike")
	RunState.grant_relic(DwarfRelics.get_by_id(&"iron_ration"))
	RunState.grant_relic(DwarfRelics.get_by_id(&"whetstone"))
	RunState.add_potion(DwarfPotions.get_by_id(&"vigor_tonic"))
	RunState.grant_equipment(DwarfEquipment.get_by_id(&"chainmail"))
	RunState.equip_item(RunState.owned_equipment[0])
	RunState.player_current_hp = 9
	return second_floor_node

func test_capture_then_restore_reproduces_the_run():
	var saved_node := _start_and_mutate_a_run()
	var expected_map := _map_signature(RunState.map)
	var expected_deck := _deck_ids()
	var expected_max_hp: int = RunState.player_max_hp
	var data := RunSnapshot.capture()
	var expected_next_random: int = RunState.rng.randi()
	RunState.enter_camp(DwarfContent.get_class_resource())
	assert_null(RunState.map, "enter_camp wiped the run before restore.")
	assert_true(RunSnapshot.restore(data))
	assert_eq(_map_signature(RunState.map), expected_map)
	assert_eq(RunState.current_node.id, saved_node.id)
	assert_eq(RunState.current_floor, 1)
	assert_eq(_deck_ids(), expected_deck)
	assert_eq(RunState.player_max_hp, expected_max_hp, "Relic vitality is already baked into the saved max HP.")
	assert_eq(RunState.player_current_hp, 9)
	assert_eq(RunState.gold, 25)
	assert_eq(RunState.unlocked_relics, [&"iron_ration", &"whetstone"] as Array[StringName])
	assert_eq(RunState.relic_bonus_strength, 2)
	assert_eq(RunState.relic_bonus_block, 0)
	assert_eq(RunState.relic_gold_bonus, 0)
	assert_eq(RunState.potions.size(), 1)
	assert_eq(RunState.potions[0].id, &"vigor_tonic")
	assert_eq(RunState.owned_equipment.size(), 1)
	assert_eq(RunState.equipped_armor.id, &"chainmail")
	assert_null(RunState.equipped_weapon)
	assert_eq(RunState.rng.randi(), expected_next_random, "The random sequence continues where it left off.")

func test_snapshot_survives_json():
	_start_and_mutate_a_run()
	var expected_map := _map_signature(RunState.map)
	var data := RunSnapshot.capture()
	var expected_next_random: int = RunState.rng.randi()
	var parsed: Variant = JSON.parse_string(JSON.stringify(data))
	RunState.enter_camp(DwarfContent.get_class_resource())
	assert_true(RunSnapshot.restore(parsed))
	assert_eq(_map_signature(RunState.map), expected_map)
	assert_eq(RunState.rng.randi(), expected_next_random)

func test_capture_outside_a_run_returns_an_empty_dictionary():
	RunState.enter_camp(DwarfContent.get_class_resource())
	assert_eq(RunSnapshot.capture(), {})

func test_restore_rejects_a_missing_map_or_unknown_node_without_touching_state():
	RunState.enter_camp(DwarfContent.get_class_resource())
	RunState.gold = 7
	assert_false(RunSnapshot.restore({"gold": 99}))
	assert_false(RunSnapshot.restore({"gold": 99, "map": {"floors": []}}))
	RunState.start_new_run(DwarfContent.get_class_resource())
	var data := RunSnapshot.capture()
	data["current_node_id"] = 9999
	data["gold"] = 99
	RunState.enter_camp(DwarfContent.get_class_resource())
	RunState.gold = 7
	assert_false(RunSnapshot.restore(data))
	assert_null(RunState.map)
	assert_eq(RunState.gold, 7)

func test_restore_skips_unknown_ids_and_falls_back_to_the_starting_deck():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var data := RunSnapshot.capture()
	data["deck"] = ["no_such_card"]
	data["relic_ids"] = ["no_such_relic", "whetstone"]
	data["potion_ids"] = ["no_such_potion", "healing_draught", "vigor_tonic", "healing_draught"]
	data["owned_equipment_ids"] = ["no_such_item"]
	data["equipped_weapon_id"] = "no_such_item"
	var class_res := DwarfContent.get_class_resource()
	RunState.enter_camp(class_res)
	assert_true(RunSnapshot.restore(data))
	assert_eq(RunState.deck.size(), class_res.starting_deck.size(), "An empty deck falls back to the starting deck.")
	assert_eq(RunState.unlocked_relics, [&"whetstone"] as Array[StringName])
	assert_eq(RunState.potions.size(), RunState.MAX_POTIONS, "Potions are capped at MAX_POTIONS.")
	assert_eq(RunState.owned_equipment.size(), 0)
	assert_null(RunState.equipped_weapon)

func test_run_outcome_abandoned_defaults_to_false():
	var outcome := RunOutcome.new()
	assert_false(outcome.abandoned)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless --import` then
`"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: `test_run_snapshot.gd` fails to load (`RunSnapshot` not
declared; `abandoned` not found on `RunOutcome`).

- [ ] **Step 3: Add `RunOutcome.abandoned`**

Replace the full contents of `scripts/run/run_outcome.gd` with:

```gdscript
extends RefCounted
class_name RunOutcome

var victory: bool = false
var abandoned: bool = false
var gear_lost: int = 0
var xp_lost: int = 0
```

- [ ] **Step 4: Write `RunSnapshot`**

Create `scripts/run/run_snapshot.gd`:

```gdscript
extends RefCounted
class_name RunSnapshot

# Captures the in-progress run held by RunState into an id-only, JSON-safe
# dictionary, and restores it. Level/XP/skills are deliberately absent:
# they are never-lost state that RunState.load_character_from_meta()
# already seeds from MetaState.

static func capture() -> Dictionary:
	if RunState.map == null or RunState.current_node == null or RunState.rng == null:
		push_warning("RunSnapshot.capture called with no run in progress")
		return {}
	var deck_ids: Array = []
	for card in RunState.deck:
		deck_ids.append(String(card.id))
	var relic_ids: Array = []
	for relic_id in RunState.unlocked_relics:
		relic_ids.append(String(relic_id))
	var potion_ids: Array = []
	for potion in RunState.potions:
		potion_ids.append(String(potion.id))
	var gear_ids: Array = []
	for item in RunState.owned_equipment:
		gear_ids.append(String(item.id))
	return {
		"current_floor": RunState.current_floor,
		"current_node_id": RunState.current_node.id,
		"map": RunState.map.to_dict(),
		"deck": deck_ids,
		"player_max_hp": RunState.player_max_hp,
		"player_current_hp": RunState.player_current_hp,
		"gold": RunState.gold,
		"relic_ids": relic_ids,
		"potion_ids": potion_ids,
		"owned_equipment_ids": gear_ids,
		"equipped_weapon_id": _slot_id(RunState.equipped_weapon),
		"equipped_armor_id": _slot_id(RunState.equipped_armor),
		"equipped_trinket_id": _slot_id(RunState.equipped_trinket),
		# 64-bit ints do not survive JSON's doubles; stored as strings.
		"rng_seed": str(RunState.rng.seed),
		"rng_state": str(RunState.rng.state),
	}

static func restore(data: Dictionary) -> bool:
	# Structural checks first: nothing is written unless the map and the
	# current node resolve.
	var raw_map: Variant = data.get("map", null)
	if not (raw_map is Dictionary):
		return false
	var graph := MapGraph.from_dict(raw_map)
	if graph == null:
		return false
	var node := graph.find_node(int(data.get("current_node_id", -1)))
	if node == null:
		return false

	RunState.map = graph
	RunState.current_node = node
	RunState.current_floor = int(data.get("current_floor", node.floor))

	var deck: Array[CardResource] = []
	for raw in _array(data, "deck"):
		var card := DwarfContent.get_card_by_id(StringName(str(raw)))
		if card == null:
			push_warning("RunSnapshot: unknown card '%s' skipped" % str(raw))
			continue
		deck.append(card)
	if deck.is_empty():
		push_warning("RunSnapshot: deck empty after restore; using the starting deck")
		deck = RunState.class_resource.starting_deck.duplicate()
	RunState.deck = deck

	var owned: Array[EquipmentResource] = []
	for raw in _array(data, "owned_equipment_ids"):
		var item := DwarfEquipment.get_by_id(StringName(str(raw)))
		if item == null:
			push_warning("RunSnapshot: unknown equipment '%s' skipped" % str(raw))
			continue
		owned.append(item)
	RunState.owned_equipment = owned
	RunState.equipped_weapon = _find_owned(owned, str(data.get("equipped_weapon_id", "")))
	RunState.equipped_armor = _find_owned(owned, str(data.get("equipped_armor_id", "")))
	RunState.equipped_trinket = _find_owned(owned, str(data.get("equipped_trinket_id", "")))

	var relic_ids: Array[StringName] = []
	var relic_strength: int = 0
	var relic_block: int = 0
	var relic_gold: int = 0
	for raw in _array(data, "relic_ids"):
		var relic := DwarfRelics.get_by_id(StringName(str(raw)))
		if relic == null:
			push_warning("RunSnapshot: unknown relic '%s' skipped" % str(raw))
			continue
		relic_ids.append(relic.id)
		relic_strength += relic.strength_delta
		relic_block += relic.block_delta
		relic_gold += relic.gold_bonus_per_reward
	# Relic vitality is not re-applied: it is already baked into the saved max HP.
	RunState.unlocked_relics = relic_ids
	RunState.relic_bonus_strength = relic_strength
	RunState.relic_bonus_block = relic_block
	RunState.relic_gold_bonus = relic_gold

	var potions: Array[PotionResource] = []
	for raw in _array(data, "potion_ids"):
		if potions.size() >= RunState.MAX_POTIONS:
			break
		var potion := DwarfPotions.get_by_id(StringName(str(raw)))
		if potion == null:
			push_warning("RunSnapshot: unknown potion '%s' skipped" % str(raw))
			continue
		potions.append(potion)
	RunState.potions = potions

	RunState.player_max_hp = maxi(int(data.get("player_max_hp", RunState.player_max_hp)), 1)
	RunState.player_current_hp = clampi(int(data.get("player_current_hp", RunState.player_max_hp)), 0, RunState.player_max_hp)
	RunState.gold = maxi(int(data.get("gold", 0)), 0)

	var rng := RandomNumberGenerator.new()
	rng.seed = str(data.get("rng_seed", "0")).to_int()
	rng.state = str(data.get("rng_state", "0")).to_int()
	RunState.rng = rng
	return true

static func _array(data: Dictionary, key: String) -> Array:
	var raw: Variant = data.get(key, [])
	if raw is Array:
		return raw
	return []

static func _slot_id(item: EquipmentResource) -> String:
	return String(item.id) if item != null else ""

static func _find_owned(owned: Array[EquipmentResource], raw_id: String) -> EquipmentResource:
	var item_id := StringName(raw_id)
	if item_id == &"":
		return null
	for item in owned:
		if item.id == item_id:
			return item
	return null
```

- [ ] **Step 5: Run the full suite**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless --import` then
`"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: PASS, 40 scripts, 282 tests. The "unknown id" test prints
`push_warning` lines — expected.

- [ ] **Step 6: Commit**

```bash
git checkout -- addons/
git add scripts/run/run_snapshot.gd scripts/run/run_snapshot.gd.uid scripts/run/run_outcome.gd tests/unit/test_run_snapshot.gd tests/unit/test_run_snapshot.gd.uid
git commit -m "feat: add RunSnapshot capture/restore and RunOutcome.abandoned"
```

---

### Task 5: `RunState` checkpoints, `resume_run`, `abandon_saved_run`

**Files:**
- Modify: `scripts/run/run_state.gd`
- Modify: `tests/unit/test_run_state.gd`

**Interfaces:**
- Consumes: `RunSnapshot.capture/restore` (Task 4),
  `SaveManager.run_snapshot`, `has_run_snapshot()`, `save_game()` (Task 3).
- Produces: `RunState.resume_run(p_class_resource: ClassResource) ->
  bool`, `RunState.abandon_saved_run() -> RunOutcome` (uses the
  `class_resource` set by `enter_camp`); private `_checkpoint()`.
  `start_new_run` and `mark_node_visited_and_advance` end with a
  checkpoint; `finish_run` clears the snapshot. Consumed by Task 7.

- [ ] **Step 1: Write the failing tests**

Add to `tests/unit/test_run_state.gd`:

```gdscript
func test_start_new_run_leaves_a_snapshot_in_memory_and_on_disk():
	RunState.start_new_run(DwarfContent.get_class_resource())
	assert_true(SaveManager.has_run_snapshot())
	assert_eq(int(SaveManager.run_snapshot["current_node_id"]), RunState.current_node.id)
	SaveManager.run_snapshot = null
	assert_true(SaveManager.load_game())
	assert_true(SaveManager.has_run_snapshot(), "The snapshot was written to disk.")

func test_advancing_to_a_node_refreshes_the_snapshot():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var next_node: MapNode = RunState.map.floors[1][0]
	RunState.gold = 33
	RunState.mark_node_visited_and_advance(next_node)
	assert_eq(int(SaveManager.run_snapshot["current_node_id"]), next_node.id)
	assert_eq(int(SaveManager.run_snapshot["gold"]), 33)
	var visited_in_snapshot: bool = false
	for floor_nodes in SaveManager.run_snapshot["map"]["floors"]:
		for raw_node in floor_nodes:
			if int(raw_node["id"]) == next_node.id:
				visited_in_snapshot = bool(raw_node["visited"])
	assert_true(visited_in_snapshot)

func test_mid_run_xp_save_does_not_change_the_snapshot():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var hp_in_snapshot: int = int(SaveManager.run_snapshot["player_current_hp"])
	RunState.player_current_hp = 3
	RunState.grant_xp(5)
	assert_eq(int(SaveManager.run_snapshot["player_current_hp"]), hp_in_snapshot, "Only checkpoints capture; write-through saves re-write the cached snapshot unchanged.")

func test_finish_run_clears_the_snapshot_in_memory_and_on_disk():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.finish_run(true)
	assert_false(SaveManager.has_run_snapshot())
	SaveManager.run_snapshot = {"stale": true}
	assert_true(SaveManager.load_game())
	assert_false(SaveManager.has_run_snapshot(), "The file was written with run = null.")

func test_resume_run_returns_false_when_nothing_is_suspended():
	RunState.enter_camp(DwarfContent.get_class_resource())
	assert_false(RunState.resume_run(DwarfContent.get_class_resource()))
	assert_false(RunState.in_run)
	assert_null(RunState.map)

func test_resume_run_restores_the_run_including_gear_found_during_it():
	MetaState.level = 2
	RunState.start_new_run(DwarfContent.get_class_resource())
	var next_node: MapNode = RunState.map.floors[1][0]
	RunState.grant_equipment(DwarfEquipment.get_by_id(&"chainmail"))
	RunState.player_current_hp = 11
	RunState.gold = 21
	RunState.mark_node_visited_and_advance(next_node)
	var saved_node_id: int = next_node.id
	RunState.enter_camp(DwarfContent.get_class_resource())
	assert_eq(RunState.owned_equipment.size(), 0, "At Camp the uncommitted run gear is not in MetaState.")
	assert_true(RunState.resume_run(DwarfContent.get_class_resource()))
	assert_true(RunState.in_run)
	assert_eq(RunState.level, 2)
	assert_eq(RunState.current_node.id, saved_node_id)
	assert_eq(RunState.player_current_hp, 11)
	assert_eq(RunState.gold, 21)
	assert_eq(RunState.owned_equipment.size(), 1)
	assert_eq(RunState.owned_equipment[0].id, &"chainmail")

func test_resume_run_returns_false_for_a_broken_snapshot():
	RunState.start_new_run(DwarfContent.get_class_resource())
	SaveManager.run_snapshot["current_node_id"] = 9999
	RunState.enter_camp(DwarfContent.get_class_resource())
	assert_false(RunState.resume_run(DwarfContent.get_class_resource()))
	assert_false(RunState.in_run)
	assert_null(RunState.map)

func test_abandon_saved_run_applies_the_death_rules_to_the_suspended_run():
	MetaState.owned_equipment_ids = [&"leather_vest"]
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.grant_equipment(DwarfEquipment.get_by_id(&"chainmail"))
	RunState.grant_xp(10)  # writes through; XP is not in the snapshot
	RunState.mark_node_visited_and_advance(RunState.map.floors[1][0])
	RunState.enter_camp(DwarfContent.get_class_resource())
	var outcome := RunState.abandon_saved_run()
	assert_true(outcome.abandoned)
	assert_false(outcome.victory)
	assert_eq(outcome.gear_lost, 2, "Gear from before the run and gear found during it are both lost.")
	assert_eq(outcome.xp_lost, 5)
	assert_false(RunState.in_run)
	assert_false(SaveManager.has_run_snapshot())
	assert_eq(MetaState.owned_equipment_ids.size(), 0)
	assert_eq(MetaState.xp, 5)

func test_abandon_saved_run_with_a_broken_snapshot_discards_it_without_penalty():
	MetaState.owned_equipment_ids = [&"leather_vest"]
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.grant_xp(10)  # writes through; XP is not in the snapshot
	SaveManager.run_snapshot["current_node_id"] = 9999
	RunState.enter_camp(DwarfContent.get_class_resource())
	var outcome := RunState.abandon_saved_run()
	assert_false(outcome.abandoned)
	assert_eq(outcome.gear_lost, 0)
	assert_false(SaveManager.has_run_snapshot())
	assert_eq(MetaState.owned_equipment_ids, [&"leather_vest"] as Array[StringName])
	assert_eq(MetaState.xp, 10)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: at least 9 failing tests in `test_run_state.gd` — no
snapshot is taken yet and `resume_run` / `abandon_saved_run` do not
exist (runtime `Nonexistent function` errors).

- [ ] **Step 3: Add the checkpoints and the two methods**

In `scripts/run/run_state.gd`:

Change the end of `start_new_run` from:

```gdscript
	current_node = map.floors[0][0]
	in_run = true
```

to:

```gdscript
	current_node = map.floors[0][0]
	in_run = true
	_checkpoint()
```

Change `mark_node_visited_and_advance` to:

```gdscript
func mark_node_visited_and_advance(node: MapNode) -> void:
	node.visited = true
	current_node = node
	current_floor = node.floor
	_checkpoint()
```

In `finish_run`, change the tail from:

```gdscript
	_commit_equipment()
	_commit_never_lost()
	in_run = false
	SaveManager.save_game()
	return outcome
```

to:

```gdscript
	_commit_equipment()
	_commit_never_lost()
	in_run = false
	SaveManager.run_snapshot = null
	SaveManager.save_game()
	return outcome
```

Add, right after `enter_camp`:

```gdscript
func resume_run(p_class_resource: ClassResource) -> bool:
	if not SaveManager.has_run_snapshot():
		return false
	class_resource = p_class_resource
	persistent_stats = PersistentStats.new()
	load_character_from_meta()
	_reset_run_only_state()
	if not RunSnapshot.restore(SaveManager.run_snapshot):
		push_warning("RunState.resume_run: snapshot could not be restored")
		return false
	in_run = true
	return true

# Abandon = the death rules applied to the suspended run. A snapshot that
# cannot be restored is discarded with no penalty (not the player's fault).
func abandon_saved_run() -> RunOutcome:
	if not resume_run(class_resource):
		SaveManager.run_snapshot = null
		SaveManager.save_game()
		return RunOutcome.new()
	var outcome := finish_run(false)
	outcome.abandoned = true
	return outcome

# The only two places that capture a snapshot are start_new_run and
# mark_node_visited_and_advance — "back on the map".
func _checkpoint() -> void:
	SaveManager.run_snapshot = RunSnapshot.capture()
	SaveManager.save_game()
```

- [ ] **Step 4: Run the full suite**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: PASS, 40 scripts, 291 tests. Every pre-existing test still
passes: `RunStateTest.before_each` clears `run_snapshot`, and
`start_new_run` now also writes the test save file, which the next
`before_each` deletes.

- [ ] **Step 5: Commit**

```bash
git checkout -- addons/
git add scripts/run/run_state.gd tests/unit/test_run_state.gd
git commit -m "feat: checkpoint the run on the map; add resume_run and abandon_saved_run"
```

---

### Task 6: `CampScene` — Continue Run / Abandon Run

**Files:**
- Modify: `scripts/ui/camp/camp_scene.gd`
- Modify: `tests/unit/test_camp_scene.gd`

**Interfaces:**
- Consumes: `SaveManager.has_run_snapshot()` (Task 3).
- Produces: `CampScene.continue_run_button: Button`,
  `abandon_run_button: Button`, signals `continue_requested`,
  `abandon_requested`, `const SUSPENDED_FLAVOR_LINE`. `refresh()` toggles
  visibility. Consumed by Task 7.

- [ ] **Step 1: Write the failing tests**

Add to `tests/unit/test_camp_scene.gd`:

```gdscript
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

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: `test_camp_scene.gd` fails to load (`continue_run_button`,
`SUSPENDED_FLAVOR_LINE` not found).

- [ ] **Step 3: Extend `CampScene`**

In `scripts/ui/camp/camp_scene.gd`:

Add the signals after `signal run_requested`:

```gdscript
signal continue_requested
signal abandon_requested
```

Add the constant after `FLAVOR_LINE`:

```gdscript
const SUSPENDED_FLAVOR_LINE := "The party is still out there, arguing about which way is north."
```

Add the fields after `start_run_button`:

```gdscript
var continue_run_button: Button
var abandon_run_button: Button
```

In `_ready()`, right after `buttons_hbox.add_child(start_run_button)`:

```gdscript
	continue_run_button = Button.new()
	continue_run_button.text = "Continue Run"
	continue_run_button.pressed.connect(_on_continue_run_pressed)
	buttons_hbox.add_child(continue_run_button)

	abandon_run_button = Button.new()
	abandon_run_button.text = "Abandon Run"
	abandon_run_button.pressed.connect(_on_abandon_run_pressed)
	buttons_hbox.add_child(abandon_run_button)
```

Replace `refresh()` with:

```gdscript
func refresh() -> void:
	var suspended: bool = SaveManager.has_run_snapshot()
	status_label.text = _status_text()
	gear_label.text = "Weapon: %s   Armor: %s   Trinket: %s" % [
		_slot_name(RunState.equipped_weapon),
		_slot_name(RunState.equipped_armor),
		_slot_name(RunState.equipped_trinket),
	]
	flavor_label.text = SUSPENDED_FLAVOR_LINE if suspended else FLAVOR_LINE
	# While a run is suspended, gear and skills are frozen with it: only
	# Continue / Abandon are offered (the map's own buttons return on resume).
	skill_tree_button.visible = not suspended
	inventory_button.visible = not suspended
	start_run_button.visible = not suspended
	continue_run_button.visible = suspended
	abandon_run_button.visible = suspended
```

Add the handlers after `_on_start_run_pressed`:

```gdscript
func _on_continue_run_pressed() -> void:
	continue_requested.emit()

func _on_abandon_run_pressed() -> void:
	abandon_requested.emit()
```

- [ ] **Step 4: Run the full suite**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: PASS, 40 scripts, 295 tests.

- [ ] **Step 5: Commit**

```bash
git checkout -- addons/
git add scripts/ui/camp/camp_scene.gd tests/unit/test_camp_scene.gd
git commit -m "feat: Camp offers Continue Run / Abandon Run while a run is suspended"
```

---

### Task 7: `RunScene` continue/abandon flows and the abandoned Game Over

**Files:**
- Modify: `scripts/ui/run/game_over_scene.gd`
- Modify: `scripts/ui/run/run_scene.gd`
- Modify: `tests/unit/test_game_over_scene.gd`
- Modify: `tests/unit/test_run_scene.gd`

**Interfaces:**
- Consumes: `CampScene.continue_requested` / `abandon_requested` (Task 6),
  `RunState.resume_run` / `abandon_saved_run` (Task 5),
  `RunOutcome.abandoned` (Task 4), `SaveManager.run_snapshot` /
  `save_game()` (Task 3).
- Produces: nothing new for later tasks — this is the last task.

- [ ] **Step 1: Write the failing tests**

Add to `tests/unit/test_game_over_scene.gd`:

```gdscript
func test_ready_says_abandoned_when_the_outcome_is_an_abandon():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.current_floor = 4
	var outcome := RunOutcome.new()
	outcome.abandoned = true
	outcome.gear_lost = 1
	outcome.xp_lost = 3
	var scene := GameOverScene.new()
	scene.outcome = outcome
	add_child_autofree(scene)
	assert_eq(scene.result_label.text, "You abandoned the run on floor 4.")
	assert_eq(scene.outcome_label.text, "Lost 1 piece(s) of gear and 3 XP. Skills are safe.")
```

Add to `tests/unit/test_run_scene.gd`:

```gdscript
# Suspends a run at the first node of floor 1 with recognisable HP/gold,
# then simulates quit + relaunch (free the scene, wipe memory, boot fresh).
func _suspend_a_run_and_relaunch() -> RunScene:
	var scene := _boot_into_run()
	var next_node: MapNode = RunState.map.floors[1][0]
	RunState.player_current_hp = 13
	RunState.gold = 17
	RunState.mark_node_visited_and_advance(next_node)
	scene.free()
	MetaState.reset()
	SaveManager.run_snapshot = null
	var again := RunScene.new()
	add_child_autofree(again)
	return again

func test_boot_with_a_suspended_run_offers_continue_and_abandon():
	var scene := _suspend_a_run_and_relaunch()
	assert_eq(scene.camp_scene.get_parent(), scene)
	assert_true(scene.camp_scene.continue_run_button.visible)
	assert_true(scene.camp_scene.abandon_run_button.visible)
	assert_false(scene.camp_scene.start_run_button.visible)

func test_continue_resumes_at_the_saved_node_with_the_saved_hp_and_gold():
	var scene := _suspend_a_run_and_relaunch()
	var saved_node_id: int = int(SaveManager.run_snapshot["current_node_id"])
	scene.camp_scene.continue_run_button.pressed.emit()
	assert_true(scene.map_view.visible)
	assert_true(RunState.in_run)
	assert_eq(RunState.current_node.id, saved_node_id)
	assert_eq(RunState.current_floor, 1)
	assert_eq(RunState.player_current_hp, 13)
	assert_eq(RunState.gold, 17)

func test_abandon_shows_the_abandon_game_over_applies_the_penalty_and_returns_to_a_fresh_camp():
	MetaState.owned_equipment_ids = [&"leather_vest"]
	SaveManager.save_game()
	var scene := _suspend_a_run_and_relaunch()
	scene.camp_scene.abandon_run_button.pressed.emit()
	assert_eq(scene.game_over_scene.get_parent(), scene)
	assert_true(scene.game_over_scene.result_label.text.begins_with("You abandoned the run on floor 1."))
	assert_eq(MetaState.owned_equipment_ids.size(), 0)
	assert_false(SaveManager.has_run_snapshot())
	scene.game_over_scene.camp_button.pressed.emit()
	assert_eq(scene.camp_scene.get_parent(), scene)
	assert_true(scene.camp_scene.start_run_button.visible)
	assert_false(scene.camp_scene.continue_run_button.visible)

func test_continue_with_a_broken_snapshot_returns_to_camp_without_penalty():
	MetaState.owned_equipment_ids = [&"leather_vest"]
	SaveManager.save_game()
	var scene := _suspend_a_run_and_relaunch()
	SaveManager.run_snapshot["current_node_id"] = 9999
	scene.camp_scene.continue_run_button.pressed.emit()
	assert_eq(scene.camp_scene.get_parent(), scene)
	assert_false(scene.map_view.visible)
	assert_false(SaveManager.has_run_snapshot())
	assert_true(scene.camp_scene.start_run_button.visible)
	assert_eq(MetaState.owned_equipment_ids, [&"leather_vest"] as Array[StringName])

func test_finishing_a_run_leaves_no_suspended_run_on_the_next_boot():
	var scene := _boot_into_run()
	var boss_node := MapNode.new(9999, MapNode.NodeType.BOSS, 0)
	scene.map_view.node_selected.emit(boss_node)
	scene.combat_scene.combat_dismissed.emit(true)
	scene.free()
	MetaState.reset()
	SaveManager.run_snapshot = null
	var again := RunScene.new()
	add_child_autofree(again)
	assert_true(again.camp_scene.start_run_button.visible)
	assert_false(again.camp_scene.continue_run_button.visible)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: FAIL — the abandon headline is missing, and pressing Continue /
Abandon does nothing because `RunScene` does not connect those signals
(Continue test: `map_view` stays hidden; Abandon test: `game_over_scene`
is null).

- [ ] **Step 3: Update `GameOverScene`**

In `scripts/ui/run/game_over_scene.gd`, change:

```gdscript
	result_label = Label.new()
	result_label.text = "You died on floor %d." % RunState.current_floor
	vbox.add_child(result_label)
```

to:

```gdscript
	var abandoned: bool = outcome != null and outcome.abandoned
	result_label = Label.new()
	var headline: String = "You abandoned the run on floor %d." if abandoned else "You died on floor %d."
	result_label.text = headline % RunState.current_floor
	vbox.add_child(result_label)
```

- [ ] **Step 4: Wire `RunScene`**

In `scripts/ui/run/run_scene.gd`, change `_show_camp()` to:

```gdscript
func _show_camp() -> void:
	camp_scene = CampScene.new()
	camp_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	camp_scene.skill_tree_requested.connect(_on_skill_tree_requested)
	camp_scene.inventory_requested.connect(_on_inventory_requested)
	camp_scene.run_requested.connect(_on_run_requested)
	camp_scene.continue_requested.connect(_on_continue_requested)
	camp_scene.abandon_requested.connect(_on_abandon_requested)
	_swap_to(camp_scene)
```

Add, right after `_on_run_requested`:

```gdscript
func _on_continue_requested() -> void:
	if RunState.resume_run(DwarfContent.get_class_resource()):
		_show_map()
		return
	# A snapshot that cannot be restored is discarded with no penalty.
	SaveManager.run_snapshot = null
	SaveManager.save_game()
	_show_camp()

func _on_abandon_requested() -> void:
	var outcome := RunState.abandon_saved_run()
	if outcome.abandoned:
		_show_game_over(outcome)
	else:
		_show_camp()
```

- [ ] **Step 5: Run the full suite**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: PASS, 40 scripts, 301 tests: 259 (Plan 3A) + 7 (T1) + 4 (T2)
+ 6 (T3) + 6 (T4) + 9 (T5) + 4 (T6) + 6 (T7). A different total means a
script was not imported or a test was lost — stop and compare the
per-script list.

- [ ] **Step 6: Commit**

```bash
git checkout -- addons/
git add scripts/ui/run/game_over_scene.gd scripts/ui/run/run_scene.gd tests/unit/test_game_over_scene.gd tests/unit/test_run_scene.gd
git commit -m "feat: Continue Run and Abandon Run flows from Camp"
```

---

## Manual verification (non-negotiable, per the parent spec's standard)

Open the project in the Godot editor (`C:/Tools/Godot/Godot_v4.7-stable_win64.exe --path .` then F5) and:

1. **Suspend and resume:** Start Run, clear two nodes (note HP and gold),
   buy a card in a Shop if one appears, then enter a third node and **quit
   the game mid-fight**. Relaunch: Camp shows the suspended flavor line
   and only **Continue Run** / **Abandon Run**. Continue: the map shows
   the third node still unvisited, HP and gold as noted, the bought card
   in the deck (check via a Rest site's upgrade list or the next fight's
   hand).
2. **Same randomness:** before quitting in step 1, note which node types
   the *next* floor offers; after Continue they are identical (the map is
   restored, not regenerated).
3. **Abandon:** with a suspended run that found gear (win an Elite first),
   press Abandon Run. Game Over reads "You abandoned the run on floor N."
   with the gear/XP loss line; Return to Camp shows Start Run again, gear
   label empty, level unchanged.
4. **Finish clears:** win a Boss or die normally, quit, relaunch: Camp
   shows Start Run, not Continue.
5. **Old save:** with a Plan 3A `save.json` (`"version": 1`), relaunch:
   character loads, Camp shows Start Run, no `.bad` file appears.
6. **Corrupt run section:** quit mid-run, open `save.json`, replace the
   `"run": {...}` value with `"run": "x"`, relaunch: Camp shows Start Run,
   level intact, Output shows the "run section unreadable" warning.
   Then quit mid-run again, set `"current_node_id": 9999`, relaunch,
   press Continue: back at Camp with Start Run, gear and XP untouched.

Automated tests passing is not sufficient on its own to call this plan
done.
