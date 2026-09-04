# Run & Map Structure (Plan 2B) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a full, structurally-complete single-Act run — a
procedurally generated branching node map (Combat/Elite/Event/Rest/Shop/
Boss) backed by a `RunState` autoload that carries deck/HP/gold across
encounters — replacing `CombatDemo` as the project's playable entry point.

**Architecture:** A new `RunState` autoload is the single source of truth
for what persists across a run. A new `MapGraph`/`MapNode` pair is pure
data (no scene tree) generated fresh per run. A new `RunScene` orchestrator
swaps between a `MapView` and one of five per-node-type scenes (reusing
`CombatScene` unchanged for Combat/Elite/Boss), routing on the node's type
and, for combat, on `CombatScene`'s renamed `combat_dismissed(player_won)`
signal.

**Tech Stack:** Godot 4.7.stable, GDScript (strict typing throughout), GUT
9.6.1 for tests.

**Spec:** `docs/superpowers/specs/2026-09-05-run-map-structure-design.md`

## Global Constraints

- Every `var`, parameter, and return type is explicitly typed (project
  convention, no exceptions).
- No new content system beyond what the spec calls for: card upgrades and
  enemy variants are hand-authored (not computed/introspected), matching
  the precedent set in Plan 2A for `description`/`display_value`.
- Tests drive the same entry point a real click would (emit the button's
  `pressed` signal, or the view's own public signal) — never call a
  private `_on_*` handler directly. This was a Plan 2A final-review
  finding; do not repeat it here.
- `RunState` is a Godot autoload singleton (accessed as the global
  identifier `RunState` from any script, no instance passed around) —
  this matches the parent spec's explicit architecture choice (§7).
- Treasure nodes, XP/leveling, equipment/relics/potions, and Camp/
  MainMenu/MetaState are out of scope — do not add stubs, placeholders,
  or "TODO: wire this up later" hooks for them anywhere in this plan.
- `PersistentStats` stays a zeroed `PersistentStats.new()` wherever a run
  starts — there is no Camp system yet to source real values from.

---

## Pre-existing code this plan builds on (read-only context, not modified except where a task says so)

- `scripts/combat/combat_encounter.gd` — `CombatEncounter` engine, unchanged.
- `scripts/combat/actor_factory.gd` — `ActorFactory.build_player_actor(class_resource, stats)`, `ActorFactory.build_enemy_actor(enemy_resource)`.
- `scripts/resources/class_resource.gd` — `ClassResource`: `id`, `display_name`, `base_hp`, `starting_deck: Array[CardResource]`.
- `scripts/resources/enemy_resource.gd` — `EnemyResource`: `id`, `display_name`, `max_hp`, `moves: Array[EnemyMove]`.
- `scripts/resources/card_resource.gd` — `CardResource`: `id`, `display_name`, `cost`, `card_type`, `target_type`, `effects: Array[CardEffect]`, `description`.
- `scripts/content/dwarf_content.gd` — `DwarfContent.get_class_resource()`, private `_make_strike_card()` / `_make_guard_card()`.
- `scripts/content/cave_rat_content.gd` — `CaveRatContent.get_enemy_resource()`, private `_make_bite_move()` / `_make_screech_move()`.
- `scripts/ui/combat/combat_scene.gd` — `CombatScene`, `func start(p_encounter: CombatEncounter) -> void`, currently `signal play_again_requested` (renamed by Task 2).
- `scripts/ui/combat/combat_demo.gd` — `CombatDemo`, currently the project's `run/main_scene`; stays as a standalone smoke-test scene after this plan, no longer the main scene.
- `project.godot` — currently has no `[autoload]` section and `run/main_scene="res://scripts/ui/combat/combat_demo.tscn"`.

---

### Task 1: Map data model — `MapNode` and `MapGraph`

**Files:**
- Create: `scripts/run/map_node.gd`
- Create: `scripts/run/map_graph.gd`
- Test: `tests/unit/test_map_graph.gd`

**Interfaces:**
- Consumes: nothing from this plan (pure new data classes); uses only
  Godot's built-in `RandomNumberGenerator`.
- Produces:
  - `class_name MapNode`, `extends RefCounted`. Enum
    `MapNode.NodeType { COMBAT, ELITE, EVENT, REST, SHOP, BOSS }`. Fields:
    `id: int`, `node_type: NodeType`, `floor: int`,
    `connections: Array[int] = []`, `visited: bool = false`. Constructor
    `func _init(p_id: int, p_node_type: NodeType, p_floor: int) -> void`.
  - `class_name MapGraph`, `extends RefCounted`. Field
    `floors: Array = []` (each element is an `Array[MapNode]`). Static
    `func generate(rng: RandomNumberGenerator) -> MapGraph`.
  - Later tasks rely on: `MapGraph.FLOOR_COUNT` being the exact number of
    entries in `floors`, `floors[0]` always being exactly one `COMBAT`
    node, `floors[floors.size() - 1]` always being exactly one `BOSS`
    node, and every node's `connections` containing only ids that exist
    in the immediately next floor.

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_map_graph.gd`:

```gdscript
extends GutTest

func test_floor_zero_is_a_single_forced_combat_node():
	for seed_value in range(1, 11):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var graph := MapGraph.generate(rng)
		assert_eq(graph.floors[0].size(), 1, "seed %d" % seed_value)
		var first_node: MapNode = graph.floors[0][0]
		assert_eq(first_node.node_type, MapNode.NodeType.COMBAT, "seed %d" % seed_value)

func test_last_floor_is_a_single_forced_boss_node():
	for seed_value in range(1, 11):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var graph := MapGraph.generate(rng)
		var last_floor: Array = graph.floors[graph.floors.size() - 1]
		assert_eq(last_floor.size(), 1, "seed %d" % seed_value)
		var boss_node: MapNode = last_floor[0]
		assert_eq(boss_node.node_type, MapNode.NodeType.BOSS, "seed %d" % seed_value)

func test_every_node_above_floor_zero_has_an_incoming_connection():
	for seed_value in range(1, 11):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var graph := MapGraph.generate(rng)
		for f in range(1, graph.floors.size()):
			var incoming_ids: Dictionary = {}
			var previous_floor: Array = graph.floors[f - 1]
			for from_node in previous_floor:
				for connected_id in from_node.connections:
					incoming_ids[connected_id] = true
			var current_floor: Array = graph.floors[f]
			for node in current_floor:
				assert_true(incoming_ids.has(node.id), "seed %d floor %d node %d" % [seed_value, f, node.id])

func test_no_two_rest_nodes_share_a_floor():
	for seed_value in range(1, 11):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var graph := MapGraph.generate(rng)
		for floor_nodes in graph.floors:
			var rest_count := 0
			for node in floor_nodes:
				if node.node_type == MapNode.NodeType.REST:
					rest_count += 1
			assert_true(rest_count <= 1, "seed %d" % seed_value)

func test_connections_only_point_at_the_immediately_next_floor():
	for seed_value in range(1, 11):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var graph := MapGraph.generate(rng)
		for f in range(graph.floors.size() - 1):
			var next_floor_ids: Dictionary = {}
			var next_floor: Array = graph.floors[f + 1]
			for node in next_floor:
				next_floor_ids[node.id] = true
			var current_floor: Array = graph.floors[f]
			for node in current_floor:
				for connected_id in node.connections:
					assert_true(next_floor_ids.has(connected_id), "seed %d floor %d" % [seed_value, f])
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_map_graph.gd -gexit`
Expected: FAIL — `MapNode`/`MapGraph` do not exist yet (parse/identifier errors).

- [ ] **Step 3: Implement `MapNode`**

Create `scripts/run/map_node.gd`:

```gdscript
extends RefCounted
class_name MapNode

enum NodeType { COMBAT, ELITE, EVENT, REST, SHOP, BOSS }

var id: int
var node_type: NodeType
var floor: int
var connections: Array[int] = []
var visited: bool = false

func _init(p_id: int, p_node_type: NodeType, p_floor: int) -> void:
	id = p_id
	node_type = p_node_type
	floor = p_floor
```

- [ ] **Step 4: Implement `MapGraph`**

Create `scripts/run/map_graph.gd`:

```gdscript
extends RefCounted
class_name MapGraph

const FLOOR_COUNT := 8
const MIN_NODES_PER_FLOOR := 2
const MAX_NODES_PER_FLOOR := 4

var floors: Array = []

static func generate(rng: RandomNumberGenerator) -> MapGraph:
	var graph := MapGraph.new()
	var next_id := 0

	var entry_node := MapNode.new(next_id, MapNode.NodeType.COMBAT, 0)
	next_id += 1
	graph.floors.append([entry_node] as Array[MapNode])

	for f in range(1, FLOOR_COUNT - 1):
		var node_count: int = rng.randi_range(MIN_NODES_PER_FLOOR, MAX_NODES_PER_FLOOR)
		var floor_nodes: Array[MapNode] = []
		var rest_used_this_floor := false
		for i in range(node_count):
			var node_type: MapNode.NodeType = _pick_weighted_node_type(rng, rest_used_this_floor)
			if node_type == MapNode.NodeType.REST:
				rest_used_this_floor = true
			floor_nodes.append(MapNode.new(next_id, node_type, f))
			next_id += 1
		graph.floors.append(floor_nodes)

	var boss_node := MapNode.new(next_id, MapNode.NodeType.BOSS, FLOOR_COUNT - 1)
	next_id += 1
	graph.floors.append([boss_node] as Array[MapNode])

	for f in range(graph.floors.size() - 1):
		_connect_floors(graph.floors[f], graph.floors[f + 1], rng)

	return graph

static func _pick_weighted_node_type(rng: RandomNumberGenerator, rest_already_used: bool) -> MapNode.NodeType:
	var pool: Array[MapNode.NodeType] = [
		MapNode.NodeType.COMBAT,
		MapNode.NodeType.COMBAT,
		MapNode.NodeType.ELITE,
		MapNode.NodeType.EVENT,
		MapNode.NodeType.EVENT,
		MapNode.NodeType.SHOP,
	]
	if not rest_already_used:
		pool.append(MapNode.NodeType.REST)
	return pool[rng.randi_range(0, pool.size() - 1)]

static func _connect_floors(from_floor: Array[MapNode], to_floor: Array[MapNode], rng: RandomNumberGenerator) -> void:
	var incoming_counts: Dictionary = {}
	for to_node in to_floor:
		incoming_counts[to_node.id] = 0

	for from_node in from_floor:
		var connection_count: int = min(rng.randi_range(1, 2), to_floor.size())
		var chosen_indices: Array[int] = []
		while chosen_indices.size() < connection_count:
			var idx: int = rng.randi_range(0, to_floor.size() - 1)
			if not chosen_indices.has(idx):
				chosen_indices.append(idx)
		for idx in chosen_indices:
			var to_node: MapNode = to_floor[idx]
			from_node.connections.append(to_node.id)
			incoming_counts[to_node.id] += 1

	for to_node in to_floor:
		if incoming_counts[to_node.id] == 0:
			var from_node: MapNode = from_floor[rng.randi_range(0, from_floor.size() - 1)]
			from_node.connections.append(to_node.id)
			incoming_counts[to_node.id] += 1
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_map_graph.gd -gexit`
Expected: PASS, 5/5.

Note: this is a fresh `class_name` registration. If GUT reports the
scripts don't exist even after Step 4, run
`"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless --editor --quit`
once to prime the class cache, then re-run the test command.

- [ ] **Step 6: Commit**

```bash
git add scripts/run/map_node.gd scripts/run/map_graph.gd tests/unit/test_map_graph.gd
git commit -m "feat: add MapNode/MapGraph procedural map data model"
```

---

### Task 2: Rename `CombatScene.play_again_requested` to `combat_dismissed(player_won: bool)`

**Files:**
- Modify: `scripts/ui/combat/combat_scene.gd`
- Modify: `scripts/ui/combat/combat_demo.gd`
- Modify: `tests/unit/test_combat_scene.gd`

**Interfaces:**
- Consumes: nothing new.
- Produces: `CombatScene.signal combat_dismissed(player_won: bool)`,
  emitted by the existing "Play Again"/dismiss button's press handler.
  Later tasks (the `RunScene` orchestrator, Task 10) connect to this
  signal to learn whether a Combat/Elite/Boss node's fight was won or
  lost.

This is a pure rename plus one payload addition — `CombatScene` already
knows `player_won` internally (its own `_on_combat_ended(player_won)`
handler set `result_label.text` from it); this task threads that same
value into the renamed signal instead of discarding it.

- [ ] **Step 1: Update the failing test first**

In `tests/unit/test_combat_scene.gd`, replace this test:

```gdscript
func test_play_again_button_emits_play_again_requested():
	var scene := CombatScene.new()
	add_child_autofree(scene)
	watch_signals(scene)
	scene.play_again_button.pressed.emit()
	assert_signal_emitted(scene, "play_again_requested")
```

with:

```gdscript
func test_play_again_button_emits_combat_dismissed_with_player_won():
	var scene := CombatScene.new()
	add_child_autofree(scene)
	var player := _make_actor(3)
	var enemy := _make_actor(20)
	var deck: Array[CardResource] = [_make_strike(3)]
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(5)])
	scene.start(encounter)
	scene.end_turn_button.pressed.emit()
	watch_signals(scene)
	scene.play_again_button.pressed.emit()
	assert_signal_emitted_with_parameters(scene, "combat_dismissed", [false])
```

(This drives a real loss first — `end_turn_button.pressed.emit()` with a
3-HP player against a 5-damage move — so `player_won` is a concrete
`false` the test can assert on, rather than an untested default.)

- [ ] **Step 2: Run test to verify it fails**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_combat_scene.gd -gexit`
Expected: FAIL — `combat_dismissed` signal does not exist / is never emitted.

- [ ] **Step 3: Rename the signal and thread `player_won` through**

In `scripts/ui/combat/combat_scene.gd`:

Change:
```gdscript
signal play_again_requested
```
to:
```gdscript
signal combat_dismissed(player_won: bool)
```

Add a field to remember the outcome (near the other `var` declarations at the top of the class):
```gdscript
var _last_result_player_won: bool = false
```

Change `_on_combat_ended`:
```gdscript
func _on_combat_ended(player_won: bool) -> void:
	turn_ui_container.hide()
	result_container.show()
	result_label.text = "You Won" if player_won else "You Lost"
	_last_result_player_won = player_won
```

Change the button handler:
```gdscript
func _on_play_again_pressed() -> void:
	combat_dismissed.emit(_last_result_player_won)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_combat_scene.gd -gexit`
Expected: PASS, all tests in the file.

- [ ] **Step 5: Update `CombatDemo` to match the renamed signal**

In `scripts/ui/combat/combat_demo.gd`, change:
```gdscript
	combat_scene.play_again_requested.connect(_start_new_fight)
```
to:
```gdscript
	combat_scene.combat_dismissed.connect(_on_combat_dismissed)
```

Add the new handler (replacing the old direct connection to
`_start_new_fight`, since the signal now carries a parameter):
```gdscript
func _on_combat_dismissed(_player_won: bool) -> void:
	_start_new_fight()
```

`CombatDemo`'s own behavior is unchanged — it always starts a fresh fight
regardless of outcome, matching its existing standalone-smoke-test role.

- [ ] **Step 6: Run the full test suite to confirm no regressions**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: PASS, all tests (no other file references the old signal name).

- [ ] **Step 7: Commit**

```bash
git add scripts/ui/combat/combat_scene.gd scripts/ui/combat/combat_demo.gd tests/unit/test_combat_scene.gd
git commit -m "refactor: rename CombatScene.play_again_requested to combat_dismissed(player_won)"
```

---

### Task 3: Content additions — card upgrades, Elite/Boss enemy variants, Event content

**Files:**
- Modify: `scripts/content/dwarf_content.gd` (full replacement below)
- Modify: `scripts/content/cave_rat_content.gd` (full replacement below)
- Create: `scripts/resources/event_choice.gd`
- Create: `scripts/resources/event_resource.gd`
- Create: `scripts/content/events_content.gd`
- Test: `tests/unit/test_card_upgrades.gd`
- Test: `tests/unit/test_enemy_variants.gd`
- Test: `tests/unit/test_events_content.gd`

**Interfaces:**
- Consumes: `CardResource`, `DamageEffect`, `BlockEffect` (existing),
  `EnemyResource`, `EnemyMove`, `ApplyStatusEffect` (existing).
- Produces:
  - `DwarfContent.get_upgraded_card(card_id: StringName) -> CardResource`
    — returns the hand-authored "+" variant for a known base card id, or
    `null` for any other id. Later tasks (Rest scene, Task 6) rely on
    this exact signature.
  - `CaveRatContent.get_elite_enemy_resource() -> EnemyResource` and
    `CaveRatContent.get_boss_enemy_resource() -> EnemyResource`. Later
    tasks (`RunState`, Task 4) rely on these exact names.
  - `class_name EventChoice extends Resource`: `label: String`,
    `gold_delta: int`, `hp_delta: int`, `outcome_text: String`.
  - `class_name EventResource extends Resource`: `id: StringName`,
    `description: String`, `choices: Array[EventChoice]`.
  - `EventsContent.get_all_events() -> Array[EventResource]` and
    `EventsContent.get_random_event(rng: RandomNumberGenerator) -> EventResource`.
    Later tasks (`EventScene`, Task 7; `RunScene`, Task 10) rely on these
    exact names.

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_card_upgrades.gd`:

```gdscript
extends GutTest

func test_get_upgraded_card_returns_a_stronger_strike():
	var upgraded := DwarfContent.get_upgraded_card(&"dwarf_strike")
	assert_eq(upgraded.display_name, "Strike+")
	assert_eq(upgraded.effects[0].amount, 9)

func test_get_upgraded_card_returns_a_stronger_guard():
	var upgraded := DwarfContent.get_upgraded_card(&"dwarf_guard")
	assert_eq(upgraded.display_name, "Guard+")
	assert_eq(upgraded.effects[0].amount, 8)

func test_get_upgraded_card_returns_null_for_an_unknown_id():
	var upgraded := DwarfContent.get_upgraded_card(&"not_a_real_card")
	assert_null(upgraded)
```

Create `tests/unit/test_enemy_variants.gd`:

```gdscript
extends GutTest

func test_elite_enemy_is_stronger_than_base():
	var base := CaveRatContent.get_enemy_resource()
	var elite := CaveRatContent.get_elite_enemy_resource()
	assert_true(elite.max_hp > base.max_hp)
	assert_ne(elite.display_name, base.display_name)

func test_boss_enemy_is_stronger_than_elite():
	var elite := CaveRatContent.get_elite_enemy_resource()
	var boss := CaveRatContent.get_boss_enemy_resource()
	assert_true(boss.max_hp > elite.max_hp)
	assert_ne(boss.display_name, elite.display_name)

func test_elite_and_boss_moves_have_descriptions():
	var enemies: Array[EnemyResource] = [CaveRatContent.get_elite_enemy_resource(), CaveRatContent.get_boss_enemy_resource()]
	for enemy_res in enemies:
		for move in enemy_res.moves:
			assert_ne(move.description, "")
```

Create `tests/unit/test_events_content.gd`:

```gdscript
extends GutTest

func test_get_all_events_returns_well_formed_events():
	var events := EventsContent.get_all_events()
	assert_true(events.size() >= 2)
	for event in events:
		assert_ne(event.description, "")
		assert_eq(event.choices.size(), 2)
		for choice in event.choices:
			assert_ne(choice.label, "")
			assert_ne(choice.outcome_text, "")

func test_get_random_event_returns_one_of_the_known_events():
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var all_events := EventsContent.get_all_events()
	var all_ids: Array[StringName] = []
	for event in all_events:
		all_ids.append(event.id)
	var picked := EventsContent.get_random_event(rng)
	assert_true(all_ids.has(picked.id))
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_card_upgrades.gd,test_enemy_variants.gd,test_events_content.gd -gexit`
Expected: FAIL — none of the new methods/classes exist yet.

- [ ] **Step 3: Replace `scripts/content/dwarf_content.gd` in full**

```gdscript
extends RefCounted
class_name DwarfContent

static func get_class_resource() -> ClassResource:
	var class_res := ClassResource.new()
	class_res.id = &"dwarf"
	class_res.display_name = "Dwarf"
	class_res.base_hp = 30
	var deck: Array[CardResource] = []
	for i in range(4):
		deck.append(_make_strike_card())
	deck.append(_make_guard_card())
	class_res.starting_deck = deck
	return class_res

static func get_upgraded_card(card_id: StringName) -> CardResource:
	match card_id:
		&"dwarf_strike":
			return _make_strike_plus_card()
		&"dwarf_guard":
			return _make_guard_plus_card()
		_:
			return null

static func _make_strike_card() -> CardResource:
	var card := CardResource.new()
	card.id = &"dwarf_strike"
	card.display_name = "Strike"
	card.cost = 1
	card.card_type = CardResource.CardType.STRIKE
	card.target_type = CardResource.TargetType.SINGLE_ENEMY
	var effect := DamageEffect.new()
	effect.amount = 6
	card.effects = [effect]
	card.description = "Deal 6 damage."
	return card

static func _make_guard_card() -> CardResource:
	var card := CardResource.new()
	card.id = &"dwarf_guard"
	card.display_name = "Guard"
	card.cost = 1
	card.card_type = CardResource.CardType.TECHNIQUE
	card.target_type = CardResource.TargetType.SELF
	var effect := BlockEffect.new()
	effect.amount = 5
	card.effects = [effect]
	card.description = "Gain 5 Block."
	return card

static func _make_strike_plus_card() -> CardResource:
	var card := CardResource.new()
	card.id = &"dwarf_strike_plus"
	card.display_name = "Strike+"
	card.cost = 1
	card.card_type = CardResource.CardType.STRIKE
	card.target_type = CardResource.TargetType.SINGLE_ENEMY
	var effect := DamageEffect.new()
	effect.amount = 9
	card.effects = [effect]
	card.description = "Deal 9 damage."
	return card

static func _make_guard_plus_card() -> CardResource:
	var card := CardResource.new()
	card.id = &"dwarf_guard_plus"
	card.display_name = "Guard+"
	card.cost = 1
	card.card_type = CardResource.CardType.TECHNIQUE
	card.target_type = CardResource.TargetType.SELF
	var effect := BlockEffect.new()
	effect.amount = 8
	card.effects = [effect]
	card.description = "Gain 8 Block."
	return card
```

- [ ] **Step 4: Replace `scripts/content/cave_rat_content.gd` in full**

```gdscript
extends RefCounted
class_name CaveRatContent

static func get_enemy_resource() -> EnemyResource:
	var enemy_res := EnemyResource.new()
	enemy_res.id = &"cave_rat"
	enemy_res.display_name = "Cave Rat"
	enemy_res.max_hp = 18
	enemy_res.moves = [_make_bite_move(), _make_screech_move()]
	return enemy_res

static func get_elite_enemy_resource() -> EnemyResource:
	var enemy_res := EnemyResource.new()
	enemy_res.id = &"alpha_cave_rat"
	enemy_res.display_name = "Alpha Cave Rat"
	enemy_res.max_hp = 32
	enemy_res.moves = [_make_elite_bite_move(), _make_screech_move()]
	return enemy_res

static func get_boss_enemy_resource() -> EnemyResource:
	var enemy_res := EnemyResource.new()
	enemy_res.id = &"cave_rat_matriarch"
	enemy_res.display_name = "Cave Rat Matriarch"
	enemy_res.max_hp = 45
	enemy_res.moves = [_make_boss_bite_move(), _make_boss_screech_move()]
	return enemy_res

static func _make_bite_move() -> EnemyMove:
	var move := EnemyMove.new()
	move.intent_type = EnemyMove.IntentType.ATTACK
	var effect := DamageEffect.new()
	effect.amount = 5
	move.effects = [effect]
	move.description = "The Cave Rat lunges with its teeth."
	move.display_value = 5
	return move

static func _make_elite_bite_move() -> EnemyMove:
	var move := EnemyMove.new()
	move.intent_type = EnemyMove.IntentType.ATTACK
	var effect := DamageEffect.new()
	effect.amount = 8
	move.effects = [effect]
	move.description = "The Alpha Cave Rat lunges hard with its teeth."
	move.display_value = 8
	return move

static func _make_boss_bite_move() -> EnemyMove:
	var move := EnemyMove.new()
	move.intent_type = EnemyMove.IntentType.ATTACK
	var effect := DamageEffect.new()
	effect.amount = 10
	move.effects = [effect]
	move.description = "The Cave Rat Matriarch bites down with bone-cracking force."
	move.display_value = 10
	return move

static func _make_screech_move() -> EnemyMove:
	var move := EnemyMove.new()
	move.intent_type = EnemyMove.IntentType.DEBUFF
	var effect := ApplyStatusEffect.new()
	effect.status_id = &"weak"
	effect.stacks = 1
	effect.apply_to_source = false
	move.effects = [effect]
	move.description = "The Cave Rat lets out a piercing screech, weakening its foe."
	return move

static func _make_boss_screech_move() -> EnemyMove:
	var move := EnemyMove.new()
	move.intent_type = EnemyMove.IntentType.DEBUFF
	var effect := ApplyStatusEffect.new()
	effect.status_id = &"weak"
	effect.stacks = 2
	effect.apply_to_source = false
	move.effects = [effect]
	move.description = "The Cave Rat Matriarch's shriek rattles your resolve."
	return move
```

- [ ] **Step 5: Create the Event resource classes**

Create `scripts/resources/event_choice.gd`:

```gdscript
extends Resource
class_name EventChoice

@export var label: String = ""
@export var gold_delta: int = 0
@export var hp_delta: int = 0
@export var outcome_text: String = ""
```

Create `scripts/resources/event_resource.gd`:

```gdscript
extends Resource
class_name EventResource

@export var id: StringName = &""
@export var description: String = ""
@export var choices: Array[EventChoice] = []
```

- [ ] **Step 6: Create `EventsContent`**

Create `scripts/content/events_content.gd`:

```gdscript
extends RefCounted
class_name EventsContent

static func get_all_events() -> Array[EventResource]:
	return [_make_toll_troll_event(), _make_unattended_cart_event()]

static func get_random_event(rng: RandomNumberGenerator) -> EventResource:
	var events := get_all_events()
	return events[rng.randi_range(0, events.size() - 1)]

static func _make_toll_troll_event() -> EventResource:
	var event := EventResource.new()
	event.id = &"toll_troll"
	event.description = "A toll-troll blocks the path, muttering about \"union rules\" and demanding payment."
	var pay := EventChoice.new()
	pay.label = "Pay the toll (10 gold)"
	pay.gold_delta = -10
	pay.hp_delta = 0
	pay.outcome_text = "The troll grunts approvingly and steps aside."
	var refuse := EventChoice.new()
	refuse.label = "Refuse and push through"
	refuse.gold_delta = 0
	refuse.hp_delta = -5
	refuse.outcome_text = "The troll wasn't bluffing about the shoving."
	event.choices = [pay, refuse]
	return event

static func _make_unattended_cart_event() -> EventResource:
	var event := EventResource.new()
	event.id = &"unattended_cart"
	event.description = "You find a cart of unattended supplies. No one's around."
	var take := EventChoice.new()
	take.label = "Take what you can"
	take.gold_delta = 8
	take.hp_delta = 0
	take.outcome_text = "Some coins were tucked under a tarp."
	var leave := EventChoice.new()
	leave.label = "Leave it be"
	leave.gold_delta = 0
	leave.hp_delta = 0
	leave.outcome_text = "Your conscience remains intact, for now."
	event.choices = [take, leave]
	return event
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_card_upgrades.gd,test_enemy_variants.gd,test_events_content.gd -gexit`
Expected: PASS, all tests in these three files.

- [ ] **Step 8: Run the full test suite to confirm no regressions**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: PASS, all tests (existing `test_starter_content.gd` assertions about `DwarfContent`/`CaveRatContent`'s base behavior are untouched by this rewrite).

- [ ] **Step 9: Commit**

```bash
git add scripts/content/dwarf_content.gd scripts/content/cave_rat_content.gd scripts/resources/event_choice.gd scripts/resources/event_resource.gd scripts/content/events_content.gd tests/unit/test_card_upgrades.gd tests/unit/test_enemy_variants.gd tests/unit/test_events_content.gd
git commit -m "feat: add card upgrades, Elite/Boss enemy variants, and Event content"
```

---

### Task 4: `RunState` autoload

**Files:**
- Create: `scripts/run/run_state.gd`
- Modify: `project.godot` (add `[autoload]` section only — do NOT touch
  `run/main_scene` yet, that happens in Task 10 once `RunScene` exists)
- Test: `tests/unit/test_run_state.gd`

**Interfaces:**
- Consumes: `MapGraph`/`MapNode` (Task 1), `DwarfContent.get_upgraded_card`
  (Task 3), `CaveRatContent.get_elite_enemy_resource`/
  `get_boss_enemy_resource` (Task 3), `EventChoice` (Task 3), and the
  pre-existing `ActorFactory`, `CombatEncounter`, `ClassResource`,
  `PersistentStats`.
- Produces: the global autoload `RunState` with fields
  `class_resource: ClassResource`, `persistent_stats: PersistentStats`,
  `deck: Array[CardResource]`, `player_max_hp: int`,
  `player_current_hp: int`, `gold: int`, `map: MapGraph`,
  `current_floor: int`, `current_node: MapNode`, and methods
  `start_new_run(p_class_resource: ClassResource) -> void`,
  `build_encounter_for_node(node: MapNode) -> CombatEncounter`,
  `heal(amount: int) -> void`, `upgrade_card(card_id: StringName) -> void`,
  `apply_event_choice(choice: EventChoice) -> void`,
  `buy_card(card_template: CardResource, price: int) -> bool`,
  `apply_combat_reward(gold_reward: int, player_hp_after: int) -> void`,
  `mark_node_visited_and_advance(node: MapNode) -> void`. Later tasks
  (`MapView`, `RestScene`, `EventScene`, `ShopScene`, `RunScene` — Tasks
  5-10) call these by name; treat every name and signature above as
  fixed.

Because `RunState` is an autoload, it is a single instance that persists
for the whole test run — every test below calls `RunState.start_new_run(...)`
first to establish known state, rather than assuming a pristine one.

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_run_state.gd`:

```gdscript
extends GutTest

func test_start_new_run_resets_state_from_class_resource():
	var class_res := DwarfContent.get_class_resource()
	RunState.start_new_run(class_res)
	assert_eq(RunState.deck.size(), class_res.starting_deck.size())
	assert_eq(RunState.player_current_hp, RunState.player_max_hp)
	assert_eq(RunState.gold, 0)
	assert_eq(RunState.current_floor, 0)
	assert_eq(RunState.current_node.node_type, MapNode.NodeType.COMBAT)

func test_build_encounter_for_node_uses_current_hp_not_max_hp():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.player_current_hp = 5
	var combat_node := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	var encounter := RunState.build_encounter_for_node(combat_node)
	assert_eq(encounter.player.current_hp, 5)

func test_build_encounter_for_node_uses_elite_enemy_for_elite_nodes():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var elite_node := MapNode.new(0, MapNode.NodeType.ELITE, 0)
	var encounter := RunState.build_encounter_for_node(elite_node)
	assert_eq(encounter.enemy.display_name, "Alpha Cave Rat")

func test_build_encounter_for_node_uses_boss_enemy_for_boss_nodes():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var boss_node := MapNode.new(0, MapNode.NodeType.BOSS, 0)
	var encounter := RunState.build_encounter_for_node(boss_node)
	assert_eq(encounter.enemy.display_name, "Cave Rat Matriarch")

func test_heal_clamps_to_max_hp():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.player_current_hp = RunState.player_max_hp - 3
	RunState.heal(100)
	assert_eq(RunState.player_current_hp, RunState.player_max_hp)

func test_upgrade_card_replaces_matching_card_in_deck():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.upgrade_card(&"dwarf_guard")
	var found_upgraded := false
	for card in RunState.deck:
		if card.id == &"dwarf_guard_plus":
			found_upgraded = true
	assert_true(found_upgraded)

func test_apply_event_choice_applies_gold_and_hp_deltas_clamped():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.gold = 5
	RunState.player_current_hp = RunState.player_max_hp
	var choice := EventChoice.new()
	choice.gold_delta = -20
	choice.hp_delta = -3
	RunState.apply_event_choice(choice)
	assert_eq(RunState.gold, 0, "Gold should clamp at 0, not go negative.")
	assert_eq(RunState.player_current_hp, RunState.player_max_hp - 3)

func test_buy_card_deducts_gold_and_appends_card_when_affordable():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.gold = 20
	var deck_size_before := RunState.deck.size()
	var bought := RunState.buy_card(DwarfContent.get_upgraded_card(&"dwarf_strike"), 15)
	assert_true(bought)
	assert_eq(RunState.gold, 5)
	assert_eq(RunState.deck.size(), deck_size_before + 1)

func test_buy_card_fails_when_too_poor():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.gold = 5
	var deck_size_before := RunState.deck.size()
	var bought := RunState.buy_card(DwarfContent.get_upgraded_card(&"dwarf_strike"), 15)
	assert_false(bought)
	assert_eq(RunState.gold, 5)
	assert_eq(RunState.deck.size(), deck_size_before)

func test_apply_combat_reward_adds_gold_and_writes_back_hp():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.gold = 0
	RunState.apply_combat_reward(10, 12)
	assert_eq(RunState.gold, 10)
	assert_eq(RunState.player_current_hp, 12)

func test_mark_node_visited_and_advance_updates_position():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var next_node := MapNode.new(99, MapNode.NodeType.EVENT, 1)
	RunState.mark_node_visited_and_advance(next_node)
	assert_true(next_node.visited)
	assert_eq(RunState.current_node, next_node)
	assert_eq(RunState.current_floor, 1)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_run_state.gd -gexit`
Expected: FAIL — `RunState` is not yet a registered global.

- [ ] **Step 3: Implement `RunState`**

Create `scripts/run/run_state.gd`:

```gdscript
extends Node

# Autoload singleton, registered in project.godot as "RunState" — do not
# add `class_name` here; autoloads are addressed by their global name,
# and a class_name on top of that would create a second, unused identity.

const COMBAT_GOLD_REWARD := 10
const ELITE_GOLD_REWARD := 20
const BOSS_GOLD_REWARD := 30
const SHOP_CARD_PRICE := 15

var class_resource: ClassResource
var persistent_stats: PersistentStats
var deck: Array[CardResource] = []
var player_max_hp: int = 0
var player_current_hp: int = 0
var gold: int = 0
var map: MapGraph
var current_floor: int = 0
var current_node: MapNode
var rng: RandomNumberGenerator

func start_new_run(p_class_resource: ClassResource) -> void:
	class_resource = p_class_resource
	persistent_stats = PersistentStats.new()
	deck = class_resource.starting_deck.duplicate()
	player_max_hp = persistent_stats.compute_max_hp(class_resource.base_hp)
	player_current_hp = player_max_hp
	gold = 0
	rng = RandomNumberGenerator.new()
	rng.randomize()
	map = MapGraph.generate(rng)
	current_floor = 0
	current_node = map.floors[0][0]

func build_encounter_for_node(node: MapNode) -> CombatEncounter:
	var player := ActorFactory.build_player_actor(class_resource, persistent_stats)
	player.current_hp = min(player_current_hp, player.max_hp) as int
	var enemy_res: EnemyResource
	match node.node_type:
		MapNode.NodeType.ELITE:
			enemy_res = CaveRatContent.get_elite_enemy_resource()
		MapNode.NodeType.BOSS:
			enemy_res = CaveRatContent.get_boss_enemy_resource()
		_:
			enemy_res = CaveRatContent.get_enemy_resource()
	var enemy := ActorFactory.build_enemy_actor(enemy_res)
	return CombatEncounter.new(player, deck, enemy, enemy_res.moves, rng)

func heal(amount: int) -> void:
	player_current_hp = min(player_current_hp + amount, player_max_hp) as int

func upgrade_card(card_id: StringName) -> void:
	for i in range(deck.size()):
		if deck[i].id == card_id:
			var upgraded := DwarfContent.get_upgraded_card(card_id)
			if upgraded != null:
				deck[i] = upgraded
			return

func apply_event_choice(choice: EventChoice) -> void:
	var new_gold: int = gold + choice.gold_delta
	gold = max(new_gold, 0) as int
	var new_hp: int = player_current_hp + choice.hp_delta
	new_hp = max(new_hp, 0) as int
	player_current_hp = min(new_hp, player_max_hp) as int

func buy_card(card_template: CardResource, price: int) -> bool:
	if gold < price:
		return false
	gold -= price
	deck.append(card_template.duplicate(true))
	return true

func apply_combat_reward(gold_reward: int, player_hp_after: int) -> void:
	gold += gold_reward
	player_current_hp = min(player_hp_after, player_max_hp) as int

func mark_node_visited_and_advance(node: MapNode) -> void:
	node.visited = true
	current_node = node
	current_floor = node.floor
```

- [ ] **Step 4: Register the autoload**

In `project.godot`, add a new `[autoload]` section after `[application]`
and before `[editor_plugins]`, so the file reads:

```ini
config_version=5

[application]

config/name="Party Deckbuilder"
config/features=PackedStringArray("4.7", "Forward Plus")
run/main_scene="res://scripts/ui/combat/combat_demo.tscn"

[autoload]

RunState="*res://scripts/run/run_state.gd"

[editor_plugins]

enabled=PackedStringArray("res://addons/gut/plugin.cfg")
```

(`run/main_scene` stays pointed at `combat_demo.tscn` for now — Task 10
repoints it once `RunScene` exists.)

- [ ] **Step 5: Run tests to verify they pass**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_run_state.gd -gexit`
Expected: PASS, all 11 tests.

If GUT reports `RunState` as an unknown identifier even after Step 4,
run `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless --editor --quit`
once (autoload registration, like `class_name` registration, needs one
editor pass to take effect in a fresh checkout), then re-run.

- [ ] **Step 6: Run the full test suite to confirm no regressions**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: PASS, all tests.

- [ ] **Step 7: Commit**

```bash
git add scripts/run/run_state.gd project.godot tests/unit/test_run_state.gd
git commit -m "feat: add RunState autoload for run-scoped deck/HP/gold/map state"
```

---

### Task 5: `MapView` scene

**Files:**
- Create: `scripts/ui/run/map_view.gd`
- Test: `tests/unit/test_map_view.gd`

**Interfaces:**
- Consumes: `MapGraph`/`MapNode` (Task 1) only — deliberately does NOT
  read `RunState` directly, so it stays as unit-testable as `HandView`
  was in Plan 2A: fed data via `display()`, driven in tests by
  hand-built `MapGraph`/`MapNode` instances, no autoload dependency.
- Produces: `class_name MapView extends Control`,
  `signal node_selected(node: MapNode)`,
  `func display(map: MapGraph, current_node: MapNode) -> void`. Later
  tasks (`RunScene`, Task 10) call `display()` and connect to
  `node_selected`; treat both signatures as fixed.

Reachability rule: a node is clickable when it is one of
`current_node`'s `connections` — except at the very start of a run, when
`current_node` is floor 0's single entry node and hasn't been visited
yet, in which case the entry node itself is the only clickable one (there
is nothing to have "come from" yet). Concretely:
`reachable_ids = current_node.connections` if `current_node.visited` is
already `true`, else `reachable_ids = [current_node.id]`. This covers
every step of a run uniformly: `RunState.mark_node_visited_and_advance()`
(Task 4) always sets `visited = true` on the node it moves onto, so after
the very first move this rule always takes the "connections" branch.

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_map_view.gd`:

```gdscript
extends GutTest

func test_display_creates_one_column_per_floor():
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var node_a := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	var node_b := MapNode.new(1, MapNode.NodeType.EVENT, 1)
	node_a.connections = [1]
	var graph := MapGraph.new()
	graph.floors = [[node_a] as Array[MapNode], [node_b] as Array[MapNode]]
	map_view.display(graph, node_a)
	var floors_hbox: HBoxContainer = map_view.get_child(0)
	assert_eq(floors_hbox.get_child_count(), 2)

func test_display_enables_only_the_entry_node_before_the_run_has_moved():
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var node_a := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	var node_b := MapNode.new(1, MapNode.NodeType.EVENT, 1)
	node_a.connections = [1]
	var graph := MapGraph.new()
	graph.floors = [[node_a] as Array[MapNode], [node_b] as Array[MapNode]]
	map_view.display(graph, node_a)
	var floors_hbox: HBoxContainer = map_view.get_child(0)
	var floor0_vbox: VBoxContainer = floors_hbox.get_child(0)
	var floor1_vbox: VBoxContainer = floors_hbox.get_child(1)
	var entry_button: Button = floor0_vbox.get_child(0)
	var next_button: Button = floor1_vbox.get_child(0)
	assert_false(entry_button.disabled, "Entry node should be clickable before the run has moved.")
	assert_true(next_button.disabled, "Floor 1 node isn't reachable until the entry node is played.")

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
	var floors_hbox: HBoxContainer = map_view.get_child(0)
	var floor1_vbox: VBoxContainer = floors_hbox.get_child(1)
	var reachable_button: Button = floor1_vbox.get_child(0)
	var unreachable_button: Button = floor1_vbox.get_child(1)
	assert_false(reachable_button.disabled, "node_b is in node_a's connections.")
	assert_true(unreachable_button.disabled, "node_c is not in node_a's connections.")

func test_clicking_a_node_button_emits_node_selected():
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var node_a := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	var graph := MapGraph.new()
	graph.floors = [[node_a] as Array[MapNode]]
	map_view.display(graph, node_a)
	watch_signals(map_view)
	var floors_hbox: HBoxContainer = map_view.get_child(0)
	var floor0_vbox: VBoxContainer = floors_hbox.get_child(0)
	var button: Button = floor0_vbox.get_child(0)
	button.pressed.emit()
	assert_signal_emitted_with_parameters(map_view, "node_selected", [node_a])

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
	assert_eq(map_view.get_child_count(), 1, "Only the second display() call's floor container should remain; remove_child() must detach the old one immediately, not just queue_free() it.")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_map_view.gd -gexit`
Expected: FAIL — `MapView` does not exist yet.

- [ ] **Step 3: Implement `MapView`**

Create `scripts/ui/run/map_view.gd`:

```gdscript
extends Control
class_name MapView

signal node_selected(node: MapNode)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

func display(map: MapGraph, current_node: MapNode) -> void:
	for child in get_children():
		# queue_free(), not free(): display() can run again from inside a
		# node button's own "pressed" handler chain (the same reason
		# HandView.display() needed this in Plan 2A), so freeing
		# immediately would destroy a node still executing its own
		# signal dispatch.
		remove_child(child)
		child.queue_free()

	var reachable_ids: Array[int] = []
	if current_node.visited:
		reachable_ids = current_node.connections.duplicate()
	else:
		reachable_ids.append(current_node.id)

	var floors_hbox := HBoxContainer.new()
	add_child(floors_hbox)
	for floor_nodes in map.floors:
		var floor_vbox := VBoxContainer.new()
		floors_hbox.add_child(floor_vbox)
		for node: MapNode in floor_nodes:
			var button := Button.new()
			var node_type_name: String = MapNode.NodeType.keys()[node.node_type]
			button.text = node_type_name
			button.disabled = node.visited or not reachable_ids.has(node.id)
			button.pressed.connect(_on_node_button_pressed.bind(node))
			floor_vbox.add_child(button)

func _on_node_button_pressed(node: MapNode) -> void:
	node_selected.emit(node)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_map_view.gd -gexit`
Expected: PASS, all 5 tests.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/run/map_view.gd tests/unit/test_map_view.gd
git commit -m "feat: add MapView scene rendering the node graph"
```

---

### Task 6: `RestScene`

**Files:**
- Create: `scripts/ui/run/rest_scene.gd`
- Test: `tests/unit/test_rest_scene.gd`

**Interfaces:**
- Consumes: the global `RunState` (Task 4) directly — `RunState.heal()`,
  `RunState.upgrade_card()`, `RunState.deck`, `RunState.player_max_hp`,
  `RunState.player_current_hp`.
- Produces: `class_name RestScene extends Control`,
  `signal node_completed`, public fields `heal_button: Button`,
  `upgrade_button: Button`, `card_list_container: VBoxContainer` (exposed
  the same way `CombatScene` exposes `end_turn_button` etc., so tests and
  `RunScene` (Task 10) can reach them directly without path lookups).

Since `RestScene` reads/writes the `RunState` autoload directly, every
test below calls `RunState.start_new_run(...)` first to establish known
state.

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_rest_scene.gd`:

```gdscript
extends GutTest

func test_heal_button_heals_and_emits_node_completed():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.player_current_hp = RunState.player_max_hp - 20
	var scene := RestScene.new()
	add_child_autofree(scene)
	watch_signals(scene)
	scene.heal_button.pressed.emit()
	assert_eq(RunState.player_current_hp, RunState.player_max_hp - 20 + RestScene.HEAL_AMOUNT)
	assert_signal_emitted(scene, "node_completed")

func test_upgrade_button_reveals_one_button_per_deck_card():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var scene := RestScene.new()
	add_child_autofree(scene)
	scene.upgrade_button.pressed.emit()
	assert_true(scene.card_list_container.visible)
	assert_eq(scene.card_list_container.get_child_count(), RunState.deck.size())

func test_clicking_a_card_in_the_upgrade_list_upgrades_it_and_emits_node_completed():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var scene := RestScene.new()
	add_child_autofree(scene)
	scene.upgrade_button.pressed.emit()
	var guard_index := -1
	for i in range(RunState.deck.size()):
		if RunState.deck[i].id == &"dwarf_guard":
			guard_index = i
	watch_signals(scene)
	var guard_button: Button = scene.card_list_container.get_child(guard_index)
	guard_button.pressed.emit()
	assert_eq(RunState.deck[guard_index].id, &"dwarf_guard_plus")
	assert_signal_emitted(scene, "node_completed")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_rest_scene.gd -gexit`
Expected: FAIL — `RestScene` does not exist yet.

- [ ] **Step 3: Implement `RestScene`**

Create `scripts/ui/run/rest_scene.gd`:

```gdscript
extends Control
class_name RestScene

signal node_completed

const HEAL_AMOUNT := 8

var heal_button: Button
var upgrade_button: Button
var card_list_container: VBoxContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root_vbox := VBoxContainer.new()
	add_child(root_vbox)

	heal_button = Button.new()
	heal_button.text = "Heal"
	heal_button.pressed.connect(_on_heal_pressed)
	root_vbox.add_child(heal_button)

	upgrade_button = Button.new()
	upgrade_button.text = "Upgrade a Card"
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	root_vbox.add_child(upgrade_button)

	card_list_container = VBoxContainer.new()
	root_vbox.add_child(card_list_container)
	card_list_container.hide()

func _on_heal_pressed() -> void:
	RunState.heal(HEAL_AMOUNT)
	node_completed.emit()

func _on_upgrade_pressed() -> void:
	heal_button.hide()
	upgrade_button.hide()
	for card in RunState.deck:
		var button := Button.new()
		button.text = card.display_name
		button.pressed.connect(_on_card_button_pressed.bind(card))
		card_list_container.add_child(button)
	card_list_container.show()

func _on_card_button_pressed(card: CardResource) -> void:
	RunState.upgrade_card(card.id)
	node_completed.emit()
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_rest_scene.gd -gexit`
Expected: PASS, all 3 tests.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/run/rest_scene.gd tests/unit/test_rest_scene.gd
git commit -m "feat: add RestScene (heal or upgrade a card)"
```

---

### Task 7: `EventScene`

**Files:**
- Create: `scripts/ui/run/event_scene.gd`
- Test: `tests/unit/test_event_scene.gd`

**Interfaces:**
- Consumes: `EventResource`/`EventChoice` (Task 3),
  `RunState.apply_event_choice()` (Task 4).
- Produces: `class_name EventScene extends Control`,
  `signal node_completed`, `func display(event: EventResource) -> void`,
  public fields `description_label: Label`,
  `choices_container: VBoxContainer`, `outcome_label: Label`,
  `continue_button: Button`. Later tasks (`RunScene`, Task 10) call
  `display()` and connect to `node_completed`; treat both as fixed.

Every test below calls `RunState.start_new_run(...)` first, since
`_on_choice_button_pressed` writes into the `RunState` autoload.

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_event_scene.gd`:

```gdscript
extends GutTest

func test_display_shows_description_and_one_button_per_choice():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var scene := EventScene.new()
	add_child_autofree(scene)
	var event := EventsContent.get_all_events()[0]
	scene.display(event)
	assert_eq(scene.description_label.text, event.description)
	assert_eq(scene.choices_container.get_child_count(), event.choices.size())
	assert_true(scene.choices_container.visible)
	assert_false(scene.outcome_label.visible)
	assert_false(scene.continue_button.visible)

func test_clicking_a_choice_applies_it_and_shows_the_outcome():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var initial_gold: int = RunState.gold
	var scene := EventScene.new()
	add_child_autofree(scene)
	# get_all_events()[0] is the toll-troll event; its first choice pays 10 gold.
	var event := EventsContent.get_all_events()[0]
	scene.display(event)
	var pay_button: Button = scene.choices_container.get_child(0)
	pay_button.pressed.emit()
	assert_eq(RunState.gold, initial_gold - 10)
	assert_false(scene.choices_container.visible)
	assert_true(scene.outcome_label.visible)
	assert_eq(scene.outcome_label.text, event.choices[0].outcome_text)
	assert_true(scene.continue_button.visible)

func test_continue_button_emits_node_completed():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var scene := EventScene.new()
	add_child_autofree(scene)
	scene.display(EventsContent.get_all_events()[0])
	watch_signals(scene)
	scene.continue_button.pressed.emit()
	assert_signal_emitted(scene, "node_completed")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_event_scene.gd -gexit`
Expected: FAIL — `EventScene` does not exist yet.

- [ ] **Step 3: Implement `EventScene`**

Create `scripts/ui/run/event_scene.gd`:

```gdscript
extends Control
class_name EventScene

signal node_completed

var description_label: Label
var choices_container: VBoxContainer
var outcome_label: Label
var continue_button: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root_vbox := VBoxContainer.new()
	add_child(root_vbox)

	description_label = Label.new()
	root_vbox.add_child(description_label)

	choices_container = VBoxContainer.new()
	root_vbox.add_child(choices_container)

	outcome_label = Label.new()
	root_vbox.add_child(outcome_label)
	outcome_label.hide()

	continue_button = Button.new()
	continue_button.text = "Continue"
	continue_button.pressed.connect(_on_continue_pressed)
	root_vbox.add_child(continue_button)
	continue_button.hide()

func display(event: EventResource) -> void:
	description_label.text = event.description
	for child in choices_container.get_children():
		choices_container.remove_child(child)
		child.queue_free()
	for choice in event.choices:
		var button := Button.new()
		button.text = choice.label
		button.pressed.connect(_on_choice_button_pressed.bind(choice))
		choices_container.add_child(button)
	choices_container.show()
	outcome_label.hide()
	continue_button.hide()

func _on_choice_button_pressed(choice: EventChoice) -> void:
	RunState.apply_event_choice(choice)
	choices_container.hide()
	outcome_label.text = choice.outcome_text
	outcome_label.show()
	continue_button.show()

func _on_continue_pressed() -> void:
	node_completed.emit()
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_event_scene.gd -gexit`
Expected: PASS, all 3 tests.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/run/event_scene.gd tests/unit/test_event_scene.gd
git commit -m "feat: add EventScene (description + choices + outcome)"
```

---

### Task 8: `ShopScene`

**Files:**
- Modify: `scripts/content/dwarf_content.gd` (add one method, do not
  otherwise change the file from Task 3's version)
- Create: `scripts/ui/run/shop_scene.gd`
- Test: `tests/unit/test_shop_scene.gd`

**Interfaces:**
- Consumes: `RunState.gold`, `RunState.buy_card()`,
  `RunState.SHOP_CARD_PRICE` (all Task 4), a new
  `DwarfContent.get_shop_offerings() -> Array[CardResource]` (added by
  this task).
- Produces: `class_name ShopScene extends Control`,
  `signal node_completed`, public fields `gold_label: Label`,
  `offerings_container: VBoxContainer`, `leave_button: Button`. Later
  tasks (`RunScene`, Task 10) instance this and connect to
  `node_completed`.

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_shop_scene.gd`:

```gdscript
extends GutTest

func test_ready_shows_gold_and_one_button_per_offering():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.gold = 50
	var scene := ShopScene.new()
	add_child_autofree(scene)
	assert_eq(scene.gold_label.text, "Gold: 50")
	assert_eq(scene.offerings_container.get_child_count(), DwarfContent.get_shop_offerings().size())

func test_buy_button_disabled_when_too_poor():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.gold = 5
	var scene := ShopScene.new()
	add_child_autofree(scene)
	var button: Button = scene.offerings_container.get_child(0)
	assert_true(button.disabled)

func test_clicking_buy_deducts_gold_and_adds_a_card_to_the_deck():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.gold = 50
	var scene := ShopScene.new()
	add_child_autofree(scene)
	var deck_size_before: int = RunState.deck.size()
	var button: Button = scene.offerings_container.get_child(0)
	button.pressed.emit()
	assert_eq(RunState.gold, 50 - RunState.SHOP_CARD_PRICE)
	assert_eq(RunState.deck.size(), deck_size_before + 1)

func test_leave_button_emits_node_completed():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var scene := ShopScene.new()
	add_child_autofree(scene)
	watch_signals(scene)
	scene.leave_button.pressed.emit()
	assert_signal_emitted(scene, "node_completed")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_shop_scene.gd -gexit`
Expected: FAIL — `ShopScene` and `DwarfContent.get_shop_offerings()` do not exist yet.

- [ ] **Step 3: Add `get_shop_offerings()` to `DwarfContent`**

In `scripts/content/dwarf_content.gd`, add this method (anywhere in the
class — e.g. directly below `get_upgraded_card`):

```gdscript
static func get_shop_offerings() -> Array[CardResource]:
	return [_make_strike_card(), _make_guard_card()]
```

- [ ] **Step 4: Implement `ShopScene`**

Create `scripts/ui/run/shop_scene.gd`:

```gdscript
extends Control
class_name ShopScene

signal node_completed

var gold_label: Label
var offerings_container: VBoxContainer
var leave_button: Button

var _offering_buttons: Array[Button] = []
var _offering_cards: Array[CardResource] = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root_vbox := VBoxContainer.new()
	add_child(root_vbox)

	gold_label = Label.new()
	root_vbox.add_child(gold_label)

	offerings_container = VBoxContainer.new()
	root_vbox.add_child(offerings_container)

	leave_button = Button.new()
	leave_button.text = "Leave"
	leave_button.pressed.connect(_on_leave_pressed)
	root_vbox.add_child(leave_button)

	_offering_cards = DwarfContent.get_shop_offerings()
	for card in _offering_cards:
		var button := Button.new()
		button.pressed.connect(_on_buy_button_pressed.bind(card))
		offerings_container.add_child(button)
		_offering_buttons.append(button)

	_refresh()

func _refresh() -> void:
	gold_label.text = "Gold: %d" % RunState.gold
	for i in range(_offering_cards.size()):
		var card: CardResource = _offering_cards[i]
		var button: Button = _offering_buttons[i]
		button.text = "%s - %d gold" % [card.display_name, RunState.SHOP_CARD_PRICE]
		button.disabled = RunState.gold < RunState.SHOP_CARD_PRICE

func _on_buy_button_pressed(card: CardResource) -> void:
	RunState.buy_card(card, RunState.SHOP_CARD_PRICE)
	_refresh()

func _on_leave_pressed() -> void:
	node_completed.emit()
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_shop_scene.gd -gexit`
Expected: PASS, all 4 tests.

- [ ] **Step 6: Run the full test suite to confirm no regressions**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: PASS, all tests.

- [ ] **Step 7: Commit**

```bash
git add scripts/content/dwarf_content.gd scripts/ui/run/shop_scene.gd tests/unit/test_shop_scene.gd
git commit -m "feat: add ShopScene (buy cards with gold)"
```

---

### Task 9: `VictoryScene` and `GameOverScene`

**Files:**
- Create: `scripts/ui/run/victory_scene.gd`
- Create: `scripts/ui/run/game_over_scene.gd`
- Test: `tests/unit/test_victory_scene.gd`
- Test: `tests/unit/test_game_over_scene.gd`

**Interfaces:**
- Consumes: `RunState.current_floor` (Task 4), read directly — same
  direct-autoload-access convention `RestScene`/`ShopScene`/`EventScene`
  already use, since these are run-scoped screens, not general reusable
  views.
- Produces: `class_name VictoryScene extends Control` and
  `class_name GameOverScene extends Control`, each with
  `signal new_run_requested`, and public fields `result_label: Label`,
  `new_run_button: Button`. Later tasks (`RunScene`, Task 10) instance
  whichever one applies and connect to `new_run_requested`.

These two are intentionally near-identical (a result label plus a "New
Run" button) — not merged into one shared base class for two ~15-line
files; that would be premature abstraction for this little duplication.

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_victory_scene.gd`:

```gdscript
extends GutTest

func test_ready_shows_the_floor_reached():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.current_floor = 5
	var scene := VictoryScene.new()
	add_child_autofree(scene)
	assert_eq(scene.result_label.text, "Victory! You reached floor 5.")

func test_new_run_button_emits_new_run_requested():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var scene := VictoryScene.new()
	add_child_autofree(scene)
	watch_signals(scene)
	scene.new_run_button.pressed.emit()
	assert_signal_emitted(scene, "new_run_requested")
```

Create `tests/unit/test_game_over_scene.gd`:

```gdscript
extends GutTest

func test_ready_shows_the_floor_reached():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.current_floor = 3
	var scene := GameOverScene.new()
	add_child_autofree(scene)
	assert_eq(scene.result_label.text, "You died on floor 3.")

func test_new_run_button_emits_new_run_requested():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var scene := GameOverScene.new()
	add_child_autofree(scene)
	watch_signals(scene)
	scene.new_run_button.pressed.emit()
	assert_signal_emitted(scene, "new_run_requested")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_victory_scene.gd,test_game_over_scene.gd -gexit`
Expected: FAIL — neither class exists yet.

- [ ] **Step 3: Implement `VictoryScene`**

Create `scripts/ui/run/victory_scene.gd`:

```gdscript
extends Control
class_name VictoryScene

signal new_run_requested

var result_label: Label
var new_run_button: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var vbox := VBoxContainer.new()
	add_child(vbox)

	result_label = Label.new()
	result_label.text = "Victory! You reached floor %d." % RunState.current_floor
	vbox.add_child(result_label)

	new_run_button = Button.new()
	new_run_button.text = "New Run"
	new_run_button.pressed.connect(_on_new_run_pressed)
	vbox.add_child(new_run_button)

func _on_new_run_pressed() -> void:
	new_run_requested.emit()
```

- [ ] **Step 4: Implement `GameOverScene`**

Create `scripts/ui/run/game_over_scene.gd`:

```gdscript
extends Control
class_name GameOverScene

signal new_run_requested

var result_label: Label
var new_run_button: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var vbox := VBoxContainer.new()
	add_child(vbox)

	result_label = Label.new()
	result_label.text = "You died on floor %d." % RunState.current_floor
	vbox.add_child(result_label)

	new_run_button = Button.new()
	new_run_button.text = "New Run"
	new_run_button.pressed.connect(_on_new_run_pressed)
	vbox.add_child(new_run_button)

func _on_new_run_pressed() -> void:
	new_run_requested.emit()
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_victory_scene.gd,test_game_over_scene.gd -gexit`
Expected: PASS, all 4 tests.

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/run/victory_scene.gd scripts/ui/run/game_over_scene.gd tests/unit/test_victory_scene.gd tests/unit/test_game_over_scene.gd
git commit -m "feat: add VictoryScene and GameOverScene result screens"
```

---

### Task 10: `RunScene` orchestrator — wires everything together, replaces `CombatDemo` as the main scene

**Files:**
- Create: `scripts/ui/run/run_scene.gd`
- Create: `scripts/ui/run/run_scene.tscn`
- Modify: `project.godot` (repoint `run/main_scene`)
- Test: `tests/unit/test_run_scene.gd`

**Interfaces:**
- Consumes: everything from Tasks 1-9 — `MapNode`/`MapGraph` (1),
  `CombatScene.combat_dismissed(player_won)` (2), `DwarfContent`/
  `CaveRatContent`/`EventsContent` (3), `RunState` (4), `MapView` (5),
  `RestScene` (6), `EventScene` (7), `ShopScene` (8), `VictoryScene`/
  `GameOverScene` (9).
- Produces: `class_name RunScene extends Control`, the project's new
  `run/main_scene`. Nothing downstream depends on it — this is the last
  task in the plan.

`RunScene` shows exactly one child at a time, swapped by `_swap_to()`.
`MapView` is created once in `_ready()` and reused for the whole run (it
is only ever detached, never freed); every per-node scene
(`CombatScene`, `RestScene`, `EventScene`, `ShopScene`, `VictoryScene`,
`GameOverScene`) is a fresh instance created when its node is entered and
freed when left — `_swap_to()` tells the two cases apart by identity
(`!= map_view`).

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_run_scene.gd`. These tests avoid depending on
`RunState.map`'s actual (randomized) contents by emitting `map_view`'s
own `node_selected` signal with hand-built `MapNode` instances — this
still drives the real entry point (the signal `RunScene` actually
listens to), it just doesn't require MapGraph.generate() to have
produced a node of a particular type on a particular run. Likewise,
`combat_scene.combat_dismissed` is emitted directly to test `RunScene`'s
reaction to a win/loss, rather than playing a full fight through the UI —
`CombatEncounter`'s and `CombatScene`'s own win/loss and signal-emission
behavior are already covered by their own test suites (Plan 1 and Plan
2A); this file's job is to test `RunScene`'s routing and reward logic.

```gdscript
extends GutTest

func test_ready_starts_a_run_and_shows_the_map():
	var scene := RunScene.new()
	add_child_autofree(scene)
	assert_eq(scene.map_view.get_parent(), scene)

func test_selecting_a_combat_node_shows_combat_scene():
	var scene := RunScene.new()
	add_child_autofree(scene)
	var combat_node := MapNode.new(9999, MapNode.NodeType.COMBAT, 0)
	scene.map_view.node_selected.emit(combat_node)
	assert_eq(scene.combat_scene.get_parent(), scene)

func test_selecting_an_elite_node_builds_the_elite_encounter():
	var scene := RunScene.new()
	add_child_autofree(scene)
	var elite_node := MapNode.new(9999, MapNode.NodeType.ELITE, 0)
	scene.map_view.node_selected.emit(elite_node)
	assert_eq(scene.combat_scene.encounter.enemy.display_name, "Alpha Cave Rat")

func test_selecting_an_event_node_shows_event_scene():
	var scene := RunScene.new()
	add_child_autofree(scene)
	var event_node := MapNode.new(9999, MapNode.NodeType.EVENT, 0)
	scene.map_view.node_selected.emit(event_node)
	assert_eq(scene.event_scene.get_parent(), scene)

func test_selecting_a_rest_node_shows_rest_scene():
	var scene := RunScene.new()
	add_child_autofree(scene)
	var rest_node := MapNode.new(9999, MapNode.NodeType.REST, 0)
	scene.map_view.node_selected.emit(rest_node)
	assert_eq(scene.rest_scene.get_parent(), scene)

func test_selecting_a_shop_node_shows_shop_scene():
	var scene := RunScene.new()
	add_child_autofree(scene)
	var shop_node := MapNode.new(9999, MapNode.NodeType.SHOP, 0)
	scene.map_view.node_selected.emit(shop_node)
	assert_eq(scene.shop_scene.get_parent(), scene)

func test_completing_a_rest_node_marks_it_visited_and_returns_to_map():
	var scene := RunScene.new()
	add_child_autofree(scene)
	var rest_node := MapNode.new(9999, MapNode.NodeType.REST, 0)
	scene.map_view.node_selected.emit(rest_node)
	scene.rest_scene.heal_button.pressed.emit()
	assert_true(rest_node.visited)
	assert_eq(RunState.current_node, rest_node)
	assert_eq(scene.map_view.get_parent(), scene)
	assert_null(scene.rest_scene.get_parent())

func test_winning_a_combat_node_grants_gold_and_returns_to_map():
	var scene := RunScene.new()
	add_child_autofree(scene)
	var combat_node := MapNode.new(9999, MapNode.NodeType.COMBAT, 0)
	scene.map_view.node_selected.emit(combat_node)
	scene.combat_scene.combat_dismissed.emit(true)
	assert_eq(RunState.gold, RunState.COMBAT_GOLD_REWARD)
	assert_true(combat_node.visited)
	assert_eq(RunState.current_node, combat_node)
	assert_eq(scene.map_view.get_parent(), scene)

func test_losing_a_combat_node_shows_game_over():
	var scene := RunScene.new()
	add_child_autofree(scene)
	var combat_node := MapNode.new(9999, MapNode.NodeType.COMBAT, 0)
	scene.map_view.node_selected.emit(combat_node)
	scene.combat_scene.combat_dismissed.emit(false)
	assert_eq(scene.game_over_scene.get_parent(), scene)

func test_winning_the_boss_node_shows_victory():
	var scene := RunScene.new()
	add_child_autofree(scene)
	var boss_node := MapNode.new(9999, MapNode.NodeType.BOSS, 0)
	scene.map_view.node_selected.emit(boss_node)
	scene.combat_scene.combat_dismissed.emit(true)
	assert_eq(scene.victory_scene.get_parent(), scene)

func test_new_run_requested_from_game_over_starts_a_fresh_run_and_shows_map():
	var scene := RunScene.new()
	add_child_autofree(scene)
	var combat_node := MapNode.new(9999, MapNode.NodeType.COMBAT, 0)
	scene.map_view.node_selected.emit(combat_node)
	scene.combat_scene.combat_dismissed.emit(false)
	scene.game_over_scene.new_run_button.pressed.emit()
	assert_eq(scene.map_view.get_parent(), scene)
	assert_eq(RunState.current_floor, 0)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_run_scene.gd -gexit`
Expected: FAIL — `RunScene` does not exist yet.

- [ ] **Step 3: Implement `RunScene`**

Create `scripts/ui/run/run_scene.gd`:

```gdscript
extends Control
class_name RunScene

var map_view: MapView
var combat_scene: CombatScene
var rest_scene: RestScene
var event_scene: EventScene
var shop_scene: ShopScene
var victory_scene: VictoryScene
var game_over_scene: GameOverScene

var _current_child: Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	map_view = MapView.new()
	map_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_view.node_selected.connect(_on_map_node_selected)
	RunState.start_new_run(DwarfContent.get_class_resource())
	_show_map()

func _swap_to(node: Control) -> void:
	if _current_child != null and _current_child.get_parent() == self:
		remove_child(_current_child)
		if _current_child != map_view:
			# queue_free(), not free(): this can run from inside the
			# outgoing scene's own signal-dispatch call stack (e.g. a
			# button's "pressed" handler chain), so freeing immediately
			# would destroy a node still executing its own dispatch —
			# the same bug class HandView and CombatDemo were fixed for
			# in Plan 2A.
			_current_child.queue_free()
	_current_child = node
	add_child(node)

func _show_map() -> void:
	map_view.display(RunState.map, RunState.current_node)
	_swap_to(map_view)

func _on_map_node_selected(node: MapNode) -> void:
	match node.node_type:
		MapNode.NodeType.COMBAT, MapNode.NodeType.ELITE, MapNode.NodeType.BOSS:
			_start_combat(node)
		MapNode.NodeType.EVENT:
			_start_event(node)
		MapNode.NodeType.REST:
			_start_rest(node)
		MapNode.NodeType.SHOP:
			_start_shop(node)

func _start_combat(node: MapNode) -> void:
	var encounter := RunState.build_encounter_for_node(node)
	combat_scene = CombatScene.new()
	combat_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	combat_scene.combat_dismissed.connect(_on_combat_dismissed.bind(node))
	_swap_to(combat_scene)
	combat_scene.start(encounter)

func _on_combat_dismissed(player_won: bool, node: MapNode) -> void:
	if player_won:
		var gold_reward: int = _gold_reward_for(node.node_type)
		RunState.apply_combat_reward(gold_reward, combat_scene.encounter.player.current_hp)
		RunState.mark_node_visited_and_advance(node)
		if node.node_type == MapNode.NodeType.BOSS:
			_show_victory()
		else:
			_show_map()
	else:
		_show_game_over()

func _gold_reward_for(node_type: MapNode.NodeType) -> int:
	match node_type:
		MapNode.NodeType.ELITE:
			return RunState.ELITE_GOLD_REWARD
		MapNode.NodeType.BOSS:
			return RunState.BOSS_GOLD_REWARD
		_:
			return RunState.COMBAT_GOLD_REWARD

func _start_event(node: MapNode) -> void:
	event_scene = EventScene.new()
	event_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	event_scene.node_completed.connect(_on_node_completed.bind(node))
	_swap_to(event_scene)
	event_scene.display(EventsContent.get_random_event(RunState.rng))

func _start_rest(node: MapNode) -> void:
	rest_scene = RestScene.new()
	rest_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	rest_scene.node_completed.connect(_on_node_completed.bind(node))
	_swap_to(rest_scene)

func _start_shop(node: MapNode) -> void:
	shop_scene = ShopScene.new()
	shop_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	shop_scene.node_completed.connect(_on_node_completed.bind(node))
	_swap_to(shop_scene)

func _on_node_completed(node: MapNode) -> void:
	RunState.mark_node_visited_and_advance(node)
	_show_map()

func _show_victory() -> void:
	victory_scene = VictoryScene.new()
	victory_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	victory_scene.new_run_requested.connect(_on_new_run_requested)
	_swap_to(victory_scene)

func _show_game_over() -> void:
	game_over_scene = GameOverScene.new()
	game_over_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_over_scene.new_run_requested.connect(_on_new_run_requested)
	_swap_to(game_over_scene)

func _on_new_run_requested() -> void:
	RunState.start_new_run(DwarfContent.get_class_resource())
	_show_map()
```

- [ ] **Step 4: Create the main scene file**

Create `scripts/ui/run/run_scene.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/run/run_scene.gd" id="1"]

[node name="RunScene" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")
```

- [ ] **Step 5: Repoint the project's main scene**

In `project.godot`, change:
```ini
run/main_scene="res://scripts/ui/combat/combat_demo.tscn"
```
to:
```ini
run/main_scene="res://scripts/ui/run/run_scene.tscn"
```
(`combat_demo.tscn` still exists and still works as a standalone smoke
test — it is simply no longer what launches when the project is run.)

- [ ] **Step 6: Run tests to verify they pass**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_run_scene.gd -gexit`
Expected: PASS, all 11 tests.

- [ ] **Step 7: Run the full test suite to confirm no regressions**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: PASS, all tests.

- [ ] **Step 8: Commit**

```bash
git add scripts/ui/run/run_scene.gd scripts/ui/run/run_scene.tscn project.godot tests/unit/test_run_scene.gd
git commit -m "feat: add RunScene orchestrator, replace CombatDemo as main scene"
```

- [ ] **Step 9: Manual verification (non-negotiable per the parent spec)**

Open the project in the Godot editor and press Play. Confirm:

- The game launches straight into the map view (not `CombatDemo`).
- You can click the entry Combat node and play a fight to completion.
- Winning returns you to the map with a new node reachable and your gold
  increased; losing shows the GameOver screen.
- Playing through at least one Event, one Rest, and one Shop node each
  behaves as designed (event outcome text shown; heal or upgrade choice
  applied; shop purchase deducts gold and adds a card), and each returns
  you to the map afterward.
- Reaching and winning the Boss node shows the Victory screen, and its
  "New Run" button generates a fresh map and returns you to floor 0.
- Losing anywhere shows the GameOver screen, and its "New Run" button
  also generates a fresh map and returns you to floor 0.

This step cannot be automated — no subagent or test can click through a
live GUI window. Do not report this plan complete without it.
