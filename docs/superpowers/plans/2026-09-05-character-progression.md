# Character Progression (Plan 2C) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an in-run XP/leveling system with a branching Dwarf skill
tree, layered on the run/map loop Plan 2B established — Combat/Elite/Boss
wins and some Event choices grant XP, level-ups grant skill points, and the
player spends them anytime from a new map-screen button.

**Architecture:** `RunState` gains XP/level/skill-point fields and two new
methods (`grant_xp`, `unlock_skill_node`). A new `SkillNode` plain-data class
and a `DwarfSkillTree` content file describe the 7-node tree. Two small,
precedented additions to the combat engine (`CombatActor.baseline_block_bonus`,
mirroring the existing `baseline_strike_bonus`) let stat-bump nodes affect
combat without touching `CombatEncounter`'s turn loop at all; the two
capstone passives are pure build-time setup calls inside
`RunState.build_encounter_for_node`. A new `SkillTreeScene`, reachable via a
new always-visible button on `MapView`, lets the player spend points.

**Tech Stack:** Godot 4.7.stable, GDScript (strict typing throughout), GUT
9.6.1 for tests.

**Spec:** `docs/superpowers/specs/2026-09-05-character-progression-design.md`

## Global Constraints

- Every `var`, parameter, and return type is explicitly typed (project
  convention, no exceptions).
- Tests drive the same entry point a real click would (emit the button's
  `pressed` signal, or the view's own public signal) — never call a
  private `_on_*` handler directly. Standing checklist item from the 2A/2B
  final reviews; do not repeat that finding here.
- `RunState` is a Godot autoload singleton (accessed as the global
  identifier `RunState`, no instance passed around) — every test that reads
  or mutates its state must call `RunState.start_new_run(...)` first to
  reset it, since it is a shared singleton across the whole test run, not a
  fresh instance per test.
- Reuse existing engine hooks over inventing new ones: stat-bump skill
  nodes work by adding to `CombatActor.baseline_strike_bonus` /
  `baseline_block_bonus` (both already read by `DamageEffect`/`BlockEffect`)
  and to `RunState.player_max_hp`; the two capstone passives
  (`battle_fury`, `unyielding`) are applied as one-time setup calls in
  `RunState.build_encounter_for_node`, not new hooks inside
  `CombatEncounter`'s turn loop.
- Camp/Renown persistent talent tree, skill trees for classes beyond Dwarf,
  and Equipment/Relics/Potions (Plan 2D) are out of scope — do not add
  stubs, placeholders, or "TODO: wire this up later" hooks for them
  anywhere in this plan.
- No tree respec/refund, no variable per-node point costs, no multi-parent
  prerequisites — every node costs exactly 1 skill point and has at most
  one `requires_id`.

---

## Pre-existing code this plan builds on (read-only context, not modified except where a task says so)

- `scripts/combat/combat_actor.gd` — `CombatActor`: `display_name`,
  `max_hp`, `current_hp`, `block`, `baseline_strike_bonus`,
  `status_stacks`; `_init(p_display_name, p_max_hp, p_baseline_strike_bonus := 0)`;
  `take_damage(amount)`, `add_block(amount)`, `clear_block()`,
  `get_status_stacks(status_id)`, `add_status(status_id, stacks)`.
- `scripts/combat/effect_context.gd` — `EffectContext`: `source: CombatActor`,
  `target: CombatActor`.
- `scripts/resources/effects/damage_effect.gd` — `DamageEffect.apply()`
  already adds `context.source.baseline_strike_bonus` on top of its own
  `amount`; this plan's `BlockEffect` change (Task 2) mirrors this exactly.
- `scripts/resources/effects/block_effect.gd` — currently
  `context.target.add_block(amount)`, modified by Task 2.
- `scripts/run/run_state.gd` — `RunState` autoload. Current relevant
  fields: `deck: Array[CardResource]`, `player_max_hp: int`,
  `player_current_hp: int`, `gold: int`, `rng: RandomNumberGenerator`.
  Current relevant methods: `start_new_run(class_resource)`,
  `build_encounter_for_node(node) -> CombatEncounter`,
  `apply_event_choice(choice: EventChoice)`,
  `apply_combat_reward(gold_reward, player_hp_after)`.
- `scripts/resources/event_choice.gd` — `EventChoice`: `label`,
  `gold_delta`, `hp_delta`, `outcome_text`, modified by Task 4.
- `scripts/content/events_content.gd` — `EventsContent.get_all_events()`,
  `get_random_event(rng)`; two hand-authored events (`toll_troll`,
  `unattended_cart`), each with two `EventChoice`s, modified by Task 4.
- `scripts/run/map_node.gd` — `MapNode`: `id: int`, `node_type: NodeType`,
  `floor: int`, `connections: Array[int]`, `visited: bool`;
  `_init(p_id, p_node_type, p_floor)`.
- `scripts/ui/run/map_view.gd` — `MapView extends Control`,
  `signal node_selected(node: MapNode)`,
  `func display(map: MapGraph, current_node: MapNode) -> void`. Current
  `display()` clears all children, then adds exactly one `HBoxContainer`
  (the floor columns) as `get_child(0)`. Modified by Task 6.
- `scripts/ui/run/run_scene.gd` — `RunScene extends Control`, the project's
  main scene. Owns `map_view`, `combat_scene`, `rest_scene`, `event_scene`,
  `shop_scene`, `victory_scene`, `game_over_scene`; `_swap_to(node: Control)`
  swaps the visible child; `_on_combat_dismissed(player_won, node)` applies
  the gold reward on a win via `_gold_reward_for(node_type) -> int`.
  Modified by Task 8.
- `project.godot` — no changes needed; `SkillNode`/`DwarfSkillTree` are
  plain classes and content, not autoloads.

---

### Task 1: `SkillNode` data class and Dwarf skill tree content

**Files:**
- Create: `scripts/run/skill_node.gd`
- Create: `scripts/content/dwarf_skill_tree.gd`
- Test: `tests/unit/test_dwarf_skill_tree.gd`

**Interfaces:**
- Produces: `class_name SkillNode extends RefCounted` with fields `id: StringName`,
  `display_name: String`, `description: String`, `branch: SkillNode.Branch`,
  `requires_id: StringName`, `strength_delta: int`, `vitality_delta: int`,
  `block_delta: int`, `passive_id: StringName`; and
  `class_name DwarfSkillTree`, `static func get_skill_tree() -> Array[SkillNode]`
  returning exactly 7 nodes in this order: `dwarven_grit`, `sharpened_pick`,
  `heavy_swing`, `battle_fury`, `thick_hide`, `reinforced_guard`, `unyielding`.
  Later tasks (3, 5, 7) consume both.

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_dwarf_skill_tree.gd`:

```gdscript
extends GutTest

func test_get_skill_tree_returns_seven_well_formed_nodes():
	var nodes := DwarfSkillTree.get_skill_tree()
	assert_eq(nodes.size(), 7)
	for node in nodes:
		assert_ne(node.display_name, "")
		assert_ne(node.description, "")

func test_get_skill_tree_has_exactly_one_root_node():
	var nodes := DwarfSkillTree.get_skill_tree()
	var root_count := 0
	for node in nodes:
		if node.requires_id == &"":
			root_count += 1
	assert_eq(root_count, 1)

func test_get_skill_tree_offense_branch_chains_in_order():
	var nodes := DwarfSkillTree.get_skill_tree()
	var by_id: Dictionary = {}
	for node in nodes:
		by_id[node.id] = node
	assert_eq(by_id[&"sharpened_pick"].requires_id, &"dwarven_grit")
	assert_eq(by_id[&"heavy_swing"].requires_id, &"sharpened_pick")
	assert_eq(by_id[&"battle_fury"].requires_id, &"heavy_swing")
	assert_eq(by_id[&"battle_fury"].passive_id, &"battle_fury")

func test_get_skill_tree_defense_branch_chains_in_order():
	var nodes := DwarfSkillTree.get_skill_tree()
	var by_id: Dictionary = {}
	for node in nodes:
		by_id[node.id] = node
	assert_eq(by_id[&"thick_hide"].requires_id, &"dwarven_grit")
	assert_eq(by_id[&"reinforced_guard"].requires_id, &"thick_hide")
	assert_eq(by_id[&"unyielding"].requires_id, &"reinforced_guard")
	assert_eq(by_id[&"unyielding"].passive_id, &"unyielding")

func test_get_skill_tree_root_grants_strength_and_vitality():
	var nodes := DwarfSkillTree.get_skill_tree()
	var root: SkillNode = nodes[0]
	assert_eq(root.id, &"dwarven_grit")
	assert_eq(root.strength_delta, 1)
	assert_eq(root.vitality_delta, 1)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_dwarf_skill_tree.gd -gexit`
Expected: FAIL — `DwarfSkillTree` / `SkillNode` do not exist yet.

- [ ] **Step 3: Write `SkillNode`**

Create `scripts/run/skill_node.gd`:

```gdscript
extends RefCounted
class_name SkillNode

enum Branch { ROOT, OFFENSE, DEFENSE }

var id: StringName
var display_name: String
var description: String
var branch: Branch
var requires_id: StringName
var strength_delta: int
var vitality_delta: int
var block_delta: int
var passive_id: StringName

func _init(
	p_id: StringName,
	p_display_name: String,
	p_description: String,
	p_branch: Branch,
	p_requires_id: StringName,
	p_strength_delta: int = 0,
	p_vitality_delta: int = 0,
	p_block_delta: int = 0,
	p_passive_id: StringName = &""
) -> void:
	id = p_id
	display_name = p_display_name
	description = p_description
	branch = p_branch
	requires_id = p_requires_id
	strength_delta = p_strength_delta
	vitality_delta = p_vitality_delta
	block_delta = p_block_delta
	passive_id = p_passive_id
```

- [ ] **Step 4: Write `DwarfSkillTree` content**

Create `scripts/content/dwarf_skill_tree.gd`:

```gdscript
extends RefCounted
class_name DwarfSkillTree

static func get_skill_tree() -> Array[SkillNode]:
	var nodes: Array[SkillNode] = [
		SkillNode.new(
			&"dwarven_grit", "Dwarven Grit",
			"A dwarf's stubborn constitution.",
			SkillNode.Branch.ROOT, &"", 1, 1, 0, &""
		),
		SkillNode.new(
			&"sharpened_pick", "Sharpened Pick",
			"Keep the edge keen.",
			SkillNode.Branch.OFFENSE, &"dwarven_grit", 2, 0, 0, &""
		),
		SkillNode.new(
			&"heavy_swing", "Heavy Swing",
			"Put your whole back into it.",
			SkillNode.Branch.OFFENSE, &"sharpened_pick", 3, 0, 0, &""
		),
		SkillNode.new(
			&"battle_fury", "Battle Fury",
			"Start every fight already furious: +2 Strength stacks.",
			SkillNode.Branch.OFFENSE, &"heavy_swing", 0, 0, 0, &"battle_fury"
		),
		SkillNode.new(
			&"thick_hide", "Thick Hide",
			"Dwarven skin, dwarven stubbornness.",
			SkillNode.Branch.DEFENSE, &"dwarven_grit", 0, 3, 0, &""
		),
		SkillNode.new(
			&"reinforced_guard", "Reinforced Guard",
			"A shield worth trusting.",
			SkillNode.Branch.DEFENSE, &"thick_hide", 0, 0, 3, &""
		),
		SkillNode.new(
			&"unyielding", "Unyielding",
			"Brace before the first blow lands: start combat with 5 Block.",
			SkillNode.Branch.DEFENSE, &"reinforced_guard", 0, 0, 0, &"unyielding"
		),
	]
	return nodes
```

- [ ] **Step 5: Run test to verify it passes**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_dwarf_skill_tree.gd -gexit`
Expected: PASS, 5/5 assertions.

Note for whichever agent runs this: the `-gtest=` filter flag has been
observed to not reliably scope to a single file in this project. If the
output doesn't look scoped to `test_dwarf_skill_tree.gd`, run the whole
suite (`-gdir=tests/unit -gexit`, no `-gtest`) and read this file's section
of the output instead.

- [ ] **Step 6: Commit**

```bash
git add scripts/run/skill_node.gd scripts/content/dwarf_skill_tree.gd tests/unit/test_dwarf_skill_tree.gd
git commit -m "feat: add SkillNode data class and Dwarf skill tree content"
```

---

### Task 2: `CombatActor.baseline_block_bonus` + `BlockEffect` wiring

**Files:**
- Modify: `scripts/combat/combat_actor.gd`
- Modify: `scripts/resources/effects/block_effect.gd`
- Modify: `tests/unit/test_block_effect.gd`
- Modify: `tests/unit/test_combat_actor.gd`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: `CombatActor.baseline_block_bonus: int` (default `0`), read by
  `BlockEffect.apply()`. Later tasks (5) set this field via
  `RunState.build_encounter_for_node`.

- [ ] **Step 1: Write the failing tests**

Add to `tests/unit/test_combat_actor.gd`:

```gdscript
func test_baseline_block_bonus_defaults_to_zero():
	var actor := CombatActor.new("Hero", 20)
	assert_eq(actor.baseline_block_bonus, 0)
```

Add to `tests/unit/test_block_effect.gd`:

```gdscript
func test_block_effect_adds_source_baseline_block_bonus():
	var effect: BlockEffect = BlockEffect.new()
	effect.amount = 5
	var source := CombatActor.new("Source", 10)
	source.baseline_block_bonus = 3
	var target := CombatActor.new("Target", 10)
	var context := EffectContext.new(source, target)
	effect.apply(context)
	assert_eq(target.block, 8)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_combat_actor.gd,test_block_effect.gd -gexit`
Expected: FAIL — `baseline_block_bonus` does not exist on `CombatActor` yet.

- [ ] **Step 3: Add the field to `CombatActor`**

In `scripts/combat/combat_actor.gd`, add the field alongside the existing
`baseline_strike_bonus` (do not change `_init`'s signature — this field is
always set directly by `RunState.build_encounter_for_node`, never via the
constructor, since it is a per-run bonus, not a per-actor-creation one):

```gdscript
var baseline_strike_bonus: int = 0
var baseline_block_bonus: int = 0
```

- [ ] **Step 4: Wire it into `BlockEffect`**

In `scripts/resources/effects/block_effect.gd`, change:

```gdscript
func apply(context: EffectContext) -> void:
	context.target.add_block(amount)
```

to:

```gdscript
func apply(context: EffectContext) -> void:
	context.target.add_block(amount + context.source.baseline_block_bonus)
```

This exactly mirrors how `DamageEffect.apply()` already adds
`context.source.baseline_strike_bonus` on top of its own `amount`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_combat_actor.gd,test_block_effect.gd -gexit`
Expected: PASS. Also re-run the full suite once
(`-gdir=tests/unit -gexit`, no `-gtest`) to confirm the pre-existing
`test_block_effect_adds_block_to_target` test still passes — it doesn't set
`baseline_block_bonus`, so it stays at its default of `0` and that test's
assertion (`target.block == 5`) is unaffected.

- [ ] **Step 6: Commit**

```bash
git add scripts/combat/combat_actor.gd scripts/resources/effects/block_effect.gd tests/unit/test_combat_actor.gd tests/unit/test_block_effect.gd
git commit -m "feat: add CombatActor.baseline_block_bonus, mirroring baseline_strike_bonus"
```

---

### Task 3: `RunState` — leveling core (XP, levels, skill points, `unlock_skill_node`)

**Files:**
- Modify: `scripts/run/run_state.gd`
- Modify: `tests/unit/test_run_state.gd`

**Interfaces:**
- Consumes: `SkillNode` (Task 1) as the parameter type for
  `unlock_skill_node`.
- Produces: `RunState.MAX_LEVEL`, `RunState.XP_THRESHOLDS`,
  `RunState.COMBAT_XP_REWARD`, `RunState.ELITE_XP_REWARD`,
  `RunState.BOSS_XP_REWARD` (consts); `RunState.level: int`,
  `RunState.xp: int`, `RunState.skill_points: int`,
  `RunState.unlocked_skill_nodes: Array[StringName]`,
  `RunState.level_bonus_strength: int`, `RunState.level_bonus_block: int`
  (fields, all reset by `start_new_run`); `func grant_xp(amount: int) -> void`;
  `func unlock_skill_node(node: SkillNode) -> bool`. Later tasks (4, 5, 6, 7,
  8) all consume these.

- [ ] **Step 1: Write the failing tests**

Add to `tests/unit/test_run_state.gd`:

```gdscript
func test_start_new_run_resets_leveling_state():
	RunState.level = 5
	RunState.xp = 40
	RunState.skill_points = 3
	RunState.unlocked_skill_nodes = [&"dwarven_grit"]
	RunState.level_bonus_strength = 6
	RunState.level_bonus_block = 3
	RunState.start_new_run(DwarfContent.get_class_resource())
	assert_eq(RunState.level, 1)
	assert_eq(RunState.xp, 0)
	assert_eq(RunState.skill_points, 0)
	assert_eq(RunState.unlocked_skill_nodes.size(), 0)
	assert_eq(RunState.level_bonus_strength, 0)
	assert_eq(RunState.level_bonus_block, 0)

func test_grant_xp_levels_up_and_grants_a_skill_point_at_threshold():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.grant_xp(RunState.XP_THRESHOLDS[0])
	assert_eq(RunState.level, 2)
	assert_eq(RunState.skill_points, 1)
	assert_eq(RunState.xp, 0)

func test_grant_xp_can_cause_multiple_level_ups_in_one_call():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var big_reward: int = RunState.XP_THRESHOLDS[0] + RunState.XP_THRESHOLDS[1]
	RunState.grant_xp(big_reward)
	assert_eq(RunState.level, 3)
	assert_eq(RunState.skill_points, 2)
	assert_eq(RunState.xp, 0)

func test_grant_xp_leaves_remainder_below_the_next_threshold():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.grant_xp(RunState.XP_THRESHOLDS[0] + 5)
	assert_eq(RunState.level, 2)
	assert_eq(RunState.xp, 5)

func test_grant_xp_does_nothing_once_at_max_level():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.level = RunState.MAX_LEVEL
	RunState.skill_points = 0
	RunState.xp = 0
	RunState.grant_xp(1000)
	assert_eq(RunState.level, RunState.MAX_LEVEL)
	assert_eq(RunState.skill_points, 0)
	assert_eq(RunState.xp, 0)

func test_unlock_skill_node_spends_a_point_and_applies_deltas():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.skill_points = 1
	var max_hp_before: int = RunState.player_max_hp
	var node := SkillNode.new(&"test_node", "Test Node", "desc", SkillNode.Branch.ROOT, &"", 2, 3, 1, &"")
	var unlocked := RunState.unlock_skill_node(node)
	assert_true(unlocked)
	assert_eq(RunState.skill_points, 0)
	assert_eq(RunState.level_bonus_strength, 2)
	assert_eq(RunState.level_bonus_block, 1)
	assert_eq(RunState.player_max_hp, max_hp_before + 6)
	assert_eq(RunState.player_current_hp, RunState.player_max_hp)
	assert_true(RunState.unlocked_skill_nodes.has(&"test_node"))

func test_unlock_skill_node_fails_with_no_points():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.skill_points = 0
	var node := SkillNode.new(&"test_node", "Test Node", "desc", SkillNode.Branch.ROOT, &"")
	var unlocked := RunState.unlock_skill_node(node)
	assert_false(unlocked)
	assert_false(RunState.unlocked_skill_nodes.has(&"test_node"))

func test_unlock_skill_node_fails_when_prerequisite_unmet():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.skill_points = 1
	var node := SkillNode.new(&"child_node", "Child", "desc", SkillNode.Branch.OFFENSE, &"parent_node")
	var unlocked := RunState.unlock_skill_node(node)
	assert_false(unlocked)
	assert_eq(RunState.skill_points, 1)

func test_unlock_skill_node_fails_when_already_unlocked():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.skill_points = 2
	var node := SkillNode.new(&"test_node", "Test Node", "desc", SkillNode.Branch.ROOT, &"", 2)
	RunState.unlock_skill_node(node)
	var unlocked_again := RunState.unlock_skill_node(node)
	assert_false(unlocked_again)
	assert_eq(RunState.skill_points, 1)
	assert_eq(RunState.level_bonus_strength, 2, "Buying the same node twice must not double-apply its bonus.")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_run_state.gd -gexit`
Expected: FAIL — none of the new fields/methods/consts exist yet.

- [ ] **Step 3: Add consts and fields to `RunState`**

In `scripts/run/run_state.gd`, add alongside the existing consts:

```gdscript
const MAX_LEVEL := 7
const XP_THRESHOLDS: Array[int] = [20, 30, 40, 55, 70, 90]
const COMBAT_XP_REWARD := 15
const ELITE_XP_REWARD := 30
const BOSS_XP_REWARD := 50
```

and alongside the existing fields:

```gdscript
var level: int = 1
var xp: int = 0
var skill_points: int = 0
var unlocked_skill_nodes: Array[StringName] = []
var level_bonus_strength: int = 0
var level_bonus_block: int = 0
```

- [ ] **Step 4: Reset the new fields in `start_new_run`**

In `scripts/run/run_state.gd`, `start_new_run` currently ends with:

```gdscript
	gold = 0
	rng = RandomNumberGenerator.new()
```

Change it to:

```gdscript
	gold = 0
	level = 1
	xp = 0
	skill_points = 0
	unlocked_skill_nodes = []
	level_bonus_strength = 0
	level_bonus_block = 0
	rng = RandomNumberGenerator.new()
```

- [ ] **Step 5: Add `grant_xp` and `unlock_skill_node`**

Add these two methods to `scripts/run/run_state.gd` (anywhere among the
other methods, e.g. after `heal`):

```gdscript
func grant_xp(amount: int) -> void:
	if level >= MAX_LEVEL:
		return
	xp += amount
	while level < MAX_LEVEL and xp >= XP_THRESHOLDS[level - 1]:
		xp -= XP_THRESHOLDS[level - 1]
		level += 1
		skill_points += 1

func unlock_skill_node(node: SkillNode) -> bool:
	if skill_points <= 0:
		return false
	if unlocked_skill_nodes.has(node.id):
		return false
	if node.requires_id != &"" and not unlocked_skill_nodes.has(node.requires_id):
		return false
	skill_points -= 1
	unlocked_skill_nodes.append(node.id)
	level_bonus_strength += node.strength_delta
	level_bonus_block += node.block_delta
	var hp_gain: int = node.vitality_delta * 2
	player_max_hp += hp_gain
	player_current_hp += hp_gain
	return true
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_run_state.gd -gexit`
Expected: PASS, including all pre-existing `test_run_state.gd` tests (they
don't touch the new fields, so `start_new_run`'s reset lines don't change
their behavior).

- [ ] **Step 7: Commit**

```bash
git add scripts/run/run_state.gd tests/unit/test_run_state.gd
git commit -m "feat: add XP/leveling core to RunState (grant_xp, unlock_skill_node)"
```

---

### Task 4: `EventChoice.xp_delta` + events content + `apply_event_choice` wiring

**Files:**
- Modify: `scripts/resources/event_choice.gd`
- Modify: `scripts/content/events_content.gd`
- Modify: `scripts/run/run_state.gd`
- Modify: `tests/unit/test_events_content.gd`
- Modify: `tests/unit/test_run_state.gd`

**Interfaces:**
- Consumes: `RunState.grant_xp` (Task 3).
- Produces: `EventChoice.xp_delta: int` (default `0`), applied by
  `RunState.apply_event_choice`. No later task consumes this beyond the
  existing `EventScene` UI (unchanged — it already applies whatever
  `RunState.apply_event_choice` does).

- [ ] **Step 1: Write the failing tests**

Add to `tests/unit/test_events_content.gd`:

```gdscript
func test_at_least_one_choice_grants_xp():
	var events := EventsContent.get_all_events()
	var found_xp_choice := false
	for event in events:
		for choice in event.choices:
			if choice.xp_delta > 0:
				found_xp_choice = true
	assert_true(found_xp_choice)
```

Add to `tests/unit/test_run_state.gd`:

```gdscript
func test_apply_event_choice_grants_xp():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var choice := EventChoice.new()
	choice.xp_delta = 5
	RunState.apply_event_choice(choice)
	assert_eq(RunState.xp, 5)

func test_apply_event_choice_xp_can_trigger_a_level_up():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var choice := EventChoice.new()
	choice.xp_delta = RunState.XP_THRESHOLDS[0]
	RunState.apply_event_choice(choice)
	assert_eq(RunState.level, 2)
	assert_eq(RunState.skill_points, 1)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_events_content.gd,test_run_state.gd -gexit`
Expected: FAIL — `EventChoice.xp_delta` doesn't exist yet, and no event
choice grants XP yet.

- [ ] **Step 3: Add the field to `EventChoice`**

In `scripts/resources/event_choice.gd`, add:

```gdscript
@export var xp_delta: int = 0
```

- [ ] **Step 4: Wire `apply_event_choice` to grant XP**

In `scripts/run/run_state.gd`, `apply_event_choice` currently reads:

```gdscript
func apply_event_choice(choice: EventChoice) -> void:
	var new_gold: int = gold + choice.gold_delta
	gold = max(new_gold, 0) as int
	var new_hp: int = player_current_hp + choice.hp_delta
	new_hp = max(new_hp, 0) as int
	player_current_hp = min(new_hp, player_max_hp) as int
```

Add a call to `grant_xp` at the end:

```gdscript
func apply_event_choice(choice: EventChoice) -> void:
	var new_gold: int = gold + choice.gold_delta
	gold = max(new_gold, 0) as int
	var new_hp: int = player_current_hp + choice.hp_delta
	new_hp = max(new_hp, 0) as int
	player_current_hp = min(new_hp, player_max_hp) as int
	grant_xp(choice.xp_delta)
```

- [ ] **Step 5: Give two existing event choices a nonzero `xp_delta`**

In `scripts/content/events_content.gd`, in `_make_toll_troll_event()`, add
one line to the `refuse` choice:

```gdscript
	var refuse := EventChoice.new()
	refuse.label = "Refuse and push through"
	refuse.gold_delta = 0
	refuse.hp_delta = -5
	refuse.xp_delta = 15
	refuse.outcome_text = "The troll wasn't bluffing about the shoving."
```

In `_make_unattended_cart_event()`, add one line to the `take` choice:

```gdscript
	var take := EventChoice.new()
	take.label = "Take what you can"
	take.gold_delta = 8
	take.hp_delta = 0
	take.xp_delta = 5
	take.outcome_text = "Some coins were tucked under a tarp."
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_events_content.gd,test_run_state.gd -gexit`
Expected: PASS, including all pre-existing tests in both files (the
existing `test_apply_event_choice_applies_gold_and_hp_deltas_clamped` test
uses a bare `EventChoice.new()` with `xp_delta` left at its default `0`, so
`grant_xp(0)` is a no-op and that test's assertions are unaffected).

- [ ] **Step 7: Commit**

```bash
git add scripts/resources/event_choice.gd scripts/content/events_content.gd scripts/run/run_state.gd tests/unit/test_events_content.gd tests/unit/test_run_state.gd
git commit -m "feat: add EventChoice.xp_delta and wire it into apply_event_choice"
```

---

### Task 5: `RunState.build_encounter_for_node` — apply level bonuses and capstones

**Files:**
- Modify: `scripts/run/run_state.gd`
- Modify: `tests/unit/test_run_state.gd`

**Interfaces:**
- Consumes: `CombatActor.baseline_block_bonus` (Task 2),
  `RunState.level_bonus_strength`/`level_bonus_block`/`unlocked_skill_nodes`
  (Task 3).
- Produces: nothing new for later tasks — this task makes the existing
  `build_encounter_for_node` reflect leveling state in the `CombatActor` it
  builds.

- [ ] **Step 1: Write the failing tests**

Add to `tests/unit/test_run_state.gd`:

```gdscript
func test_build_encounter_for_node_applies_level_bonus_strength_and_block():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.level_bonus_strength = 4
	RunState.level_bonus_block = 3
	var combat_node := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	var encounter := RunState.build_encounter_for_node(combat_node)
	assert_eq(encounter.player.baseline_strike_bonus, 4)
	assert_eq(encounter.player.baseline_block_bonus, 3)

func test_build_encounter_for_node_uses_player_max_hp_as_source_of_truth():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.player_max_hp += 10
	RunState.player_current_hp = RunState.player_max_hp
	var combat_node := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	var encounter := RunState.build_encounter_for_node(combat_node)
	assert_eq(encounter.player.max_hp, RunState.player_max_hp)

func test_build_encounter_for_node_applies_battle_fury_passive():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.unlocked_skill_nodes.append(&"battle_fury")
	var combat_node := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	var encounter := RunState.build_encounter_for_node(combat_node)
	assert_eq(encounter.player.get_status_stacks(&"strength"), 2)

func test_build_encounter_for_node_applies_unyielding_passive():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.unlocked_skill_nodes.append(&"unyielding")
	var combat_node := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	var encounter := RunState.build_encounter_for_node(combat_node)
	assert_eq(encounter.player.block, 5)

func test_build_encounter_for_node_without_any_skill_nodes_has_no_bonuses():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var combat_node := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	var encounter := RunState.build_encounter_for_node(combat_node)
	assert_eq(encounter.player.baseline_strike_bonus, 0)
	assert_eq(encounter.player.baseline_block_bonus, 0)
	assert_eq(encounter.player.block, 0)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_run_state.gd -gexit`
Expected: FAIL — `build_encounter_for_node` doesn't yet apply any of this.

- [ ] **Step 3: Update `build_encounter_for_node`**

In `scripts/run/run_state.gd`, `build_encounter_for_node` currently starts:

```gdscript
func build_encounter_for_node(node: MapNode) -> CombatEncounter:
	var player := ActorFactory.build_player_actor(class_resource, persistent_stats)
	player.current_hp = min(player_current_hp, player.max_hp) as int
	var enemy_res: EnemyResource
```

Change it to:

```gdscript
func build_encounter_for_node(node: MapNode) -> CombatEncounter:
	var player := ActorFactory.build_player_actor(class_resource, persistent_stats)
	player.max_hp = player_max_hp
	player.current_hp = min(player_current_hp, player.max_hp) as int
	player.baseline_strike_bonus += level_bonus_strength
	player.baseline_block_bonus += level_bonus_block
	if unlocked_skill_nodes.has(&"battle_fury"):
		player.add_status(&"strength", 2)
	if unlocked_skill_nodes.has(&"unyielding"):
		player.add_block(5)
	var enemy_res: EnemyResource
```

The rest of the function (the `match node.node_type` block and the
`return CombatEncounter.new(...)` line) is unchanged.

- [ ] **Step 4: Run tests to verify they pass**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_run_state.gd -gexit`
Expected: PASS, including the pre-existing
`test_build_encounter_for_node_uses_current_hp_not_max_hp`,
`test_build_encounter_for_node_uses_elite_enemy_for_elite_nodes`, and
`test_build_encounter_for_node_uses_boss_enemy_for_boss_nodes` tests —
`persistent_stats` is still always zeroed at this point in the plan, so
`player.max_hp = player_max_hp` computes to the same value
`ActorFactory` already produced in those tests, and none of the new lines
change enemy selection.

- [ ] **Step 5: Commit**

```bash
git add scripts/run/run_state.gd tests/unit/test_run_state.gd
git commit -m "feat: apply level bonuses and capstone passives in build_encounter_for_node"
```

---

### Task 6: `MapView` — status header and Skill Tree button

**Files:**
- Modify: `scripts/ui/run/map_view.gd`
- Modify: `tests/unit/test_map_view.gd`

**Interfaces:**
- Consumes: `RunState.level`, `RunState.xp`, `RunState.skill_points`,
  `RunState.MAX_LEVEL`, `RunState.XP_THRESHOLDS` (Task 3).
- Produces: `MapView.status_label: Label`, `MapView.skill_tree_button: Button`,
  `signal skill_tree_requested`. Task 8 consumes the signal.

- [ ] **Step 1: Write the failing tests**

Add to `tests/unit/test_map_view.gd`:

```gdscript
func test_display_adds_a_skill_tree_button_that_emits_skill_tree_requested():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var node_a := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	var graph := MapGraph.new()
	graph.floors = [[node_a] as Array[MapNode]]
	map_view.display(graph, node_a)
	watch_signals(map_view)
	map_view.skill_tree_button.pressed.emit()
	assert_signal_emitted(map_view, "skill_tree_requested")

func test_display_shows_current_level_and_skill_points():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.level = 3
	RunState.skill_points = 2
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var node_a := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	var graph := MapGraph.new()
	graph.floors = [[node_a] as Array[MapNode]]
	map_view.display(graph, node_a)
	assert_true(map_view.status_label.text.contains("Lv 3"))
	assert_true(map_view.status_label.text.contains("Skill Points: 2"))

func test_display_shows_max_level_without_an_xp_fraction():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.level = RunState.MAX_LEVEL
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var node_a := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	var graph := MapGraph.new()
	graph.floors = [[node_a] as Array[MapNode]]
	map_view.display(graph, node_a)
	assert_true(map_view.status_label.text.contains("MAX"))
```

Also update the existing
`test_display_called_twice_leaves_only_the_current_floors_as_children` test
— `display()` now adds a header container in addition to the floors
container, so the expected child count changes from `1` to `2`:

```gdscript
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
	assert_eq(map_view.get_child_count(), 2, "Only the second display() call's floors container and header should remain; remove_child() must detach the old ones immediately, not just queue_free() them.")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_map_view.gd -gexit`
Expected: FAIL — `skill_tree_button`/`status_label`/`skill_tree_requested`
don't exist yet, and the child-count test still expects `1`.

- [ ] **Step 3: Update `MapView`**

Replace the full contents of `scripts/ui/run/map_view.gd` with:

```gdscript
extends Control
class_name MapView

signal node_selected(node: MapNode)
signal skill_tree_requested

var status_label: Label
var skill_tree_button: Button

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

	var header_hbox := HBoxContainer.new()
	add_child(header_hbox)

	status_label = Label.new()
	status_label.text = _status_text()
	header_hbox.add_child(status_label)

	skill_tree_button = Button.new()
	skill_tree_button.text = "Skill Tree"
	skill_tree_button.pressed.connect(_on_skill_tree_button_pressed)
	header_hbox.add_child(skill_tree_button)

func _status_text() -> String:
	if RunState.level >= RunState.MAX_LEVEL:
		return "Lv %d (MAX)   Skill Points: %d" % [RunState.level, RunState.skill_points]
	var next_threshold: int = RunState.XP_THRESHOLDS[RunState.level - 1]
	return "Lv %d   XP: %d/%d   Skill Points: %d" % [RunState.level, RunState.xp, next_threshold, RunState.skill_points]

func _on_node_button_pressed(node: MapNode) -> void:
	node_selected.emit(node)

func _on_skill_tree_button_pressed() -> void:
	skill_tree_requested.emit()
```

Note that `floors_hbox` is still added first (`get_child(0)`), preserving
every pre-existing test that indexes into it directly — only the trailing
`header_hbox` is new (`get_child(1)`).

- [ ] **Step 4: Run tests to verify they pass**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_map_view.gd -gexit`
Expected: PASS, all tests including the pre-existing ones that index
`get_child(0)` as the floors container.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/run/map_view.gd tests/unit/test_map_view.gd
git commit -m "feat: add level/XP status header and Skill Tree button to MapView"
```

---

### Task 7: `SkillTreeScene`

**Files:**
- Create: `scripts/ui/run/skill_tree_scene.gd`
- Test: `tests/unit/test_skill_tree_scene.gd`

**Interfaces:**
- Consumes: `DwarfSkillTree.get_skill_tree()` (Task 1),
  `RunState.unlock_skill_node`/`unlocked_skill_nodes`/`skill_points`/`level`/
  `xp`/`MAX_LEVEL`/`XP_THRESHOLDS` (Task 3).
- Produces: `class_name SkillTreeScene extends Control`,
  `signal back_requested`, public fields `status_label: Label`,
  `nodes_container: VBoxContainer`, `back_button: Button`,
  `node_buttons: Dictionary` (keyed by `SkillNode.id`, values `Button`).
  Task 8 consumes `back_requested` and instantiates this scene.

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_skill_tree_scene.gd`:

```gdscript
extends GutTest

func test_root_node_available_when_a_point_is_banked():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.skill_points = 1
	var scene := SkillTreeScene.new()
	add_child_autofree(scene)
	var root_button: Button = scene.node_buttons[&"dwarven_grit"]
	var child_button: Button = scene.node_buttons[&"sharpened_pick"]
	assert_false(root_button.disabled, "Root has no prerequisite and a point is available.")
	assert_true(child_button.disabled, "Sharpened Pick requires Dwarven Grit, not yet unlocked.")

func test_clicking_an_available_node_unlocks_it_and_refreshes():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.skill_points = 1
	var scene := SkillTreeScene.new()
	add_child_autofree(scene)
	var root_button: Button = scene.node_buttons[&"dwarven_grit"]
	root_button.pressed.emit()
	assert_true(RunState.unlocked_skill_nodes.has(&"dwarven_grit"))
	var refreshed_root_button: Button = scene.node_buttons[&"dwarven_grit"]
	assert_true(refreshed_root_button.disabled, "Already-unlocked nodes should render disabled.")

func test_button_disabled_with_no_skill_points_even_if_prerequisite_met():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.skill_points = 1
	RunState.unlock_skill_node(DwarfSkillTree.get_skill_tree()[0])
	var scene := SkillTreeScene.new()
	add_child_autofree(scene)
	var offense_button: Button = scene.node_buttons[&"sharpened_pick"]
	assert_true(offense_button.disabled, "Prerequisite met but no skill points left.")

func test_back_button_emits_back_requested():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var scene := SkillTreeScene.new()
	add_child_autofree(scene)
	watch_signals(scene)
	scene.back_button.pressed.emit()
	assert_signal_emitted(scene, "back_requested")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_skill_tree_scene.gd -gexit`
Expected: FAIL — `SkillTreeScene` does not exist yet.

- [ ] **Step 3: Write `SkillTreeScene`**

Create `scripts/ui/run/skill_tree_scene.gd`:

```gdscript
extends Control
class_name SkillTreeScene

signal back_requested

var status_label: Label
var nodes_container: VBoxContainer
var back_button: Button
var node_buttons: Dictionary = {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root_vbox := VBoxContainer.new()
	add_child(root_vbox)

	status_label = Label.new()
	root_vbox.add_child(status_label)

	nodes_container = VBoxContainer.new()
	root_vbox.add_child(nodes_container)

	back_button = Button.new()
	back_button.text = "Back"
	back_button.pressed.connect(_on_back_pressed)
	root_vbox.add_child(back_button)

	refresh()

func refresh() -> void:
	status_label.text = _status_text()
	for child in nodes_container.get_children():
		nodes_container.remove_child(child)
		child.queue_free()
	node_buttons.clear()
	for node: SkillNode in DwarfSkillTree.get_skill_tree():
		var button := Button.new()
		var unlocked: bool = RunState.unlocked_skill_nodes.has(node.id)
		var prerequisite_met: bool = node.requires_id == &"" or RunState.unlocked_skill_nodes.has(node.requires_id)
		var available: bool = not unlocked and prerequisite_met and RunState.skill_points > 0
		var checkmark: String = " \u2713" if unlocked else ""
		button.text = "%s: %s%s" % [node.display_name, node.description, checkmark]
		button.disabled = not available
		button.pressed.connect(_on_node_button_pressed.bind(node))
		nodes_container.add_child(button)
		node_buttons[node.id] = button

func _status_text() -> String:
	if RunState.level >= RunState.MAX_LEVEL:
		return "Lv %d (MAX)   Skill Points: %d" % [RunState.level, RunState.skill_points]
	var next_threshold: int = RunState.XP_THRESHOLDS[RunState.level - 1]
	return "Lv %d   XP: %d/%d   Skill Points: %d" % [RunState.level, RunState.xp, next_threshold, RunState.skill_points]

func _on_node_button_pressed(node: SkillNode) -> void:
	RunState.unlock_skill_node(node)
	refresh()

func _on_back_pressed() -> void:
	back_requested.emit()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_skill_tree_scene.gd -gexit`
Expected: PASS, 4/4 tests.

If Godot reports `SkillTreeScene`/`DwarfSkillTree`/`SkillNode` as
unrecognized global classes even though the files exist and are correct,
this is the known fresh-`class_name`-registration cache-staleness quirk
from Plans 2A/2B — run
`"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless --editor --path . --quit`
once to prime the class cache, then re-run the test. Do **not** work
around this by adding a `preload()` shim for any of these classes in the
test file — that masks whether the real global `class_name` registration
actually works, which is exactly the anti-pattern a Plan 2B task review
caught and required removing.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/run/skill_tree_scene.gd tests/unit/test_skill_tree_scene.gd
git commit -m "feat: add SkillTreeScene for spending banked skill points"
```

---

### Task 8: `RunScene` — wire Skill Tree navigation and XP rewards

**Files:**
- Modify: `scripts/ui/run/run_scene.gd`
- Modify: `tests/unit/test_run_scene.gd`

**Interfaces:**
- Consumes: `MapView.skill_tree_requested` (Task 6), `SkillTreeScene` and
  its `back_requested` signal (Task 7), `RunState.grant_xp`,
  `RunState.COMBAT_XP_REWARD`/`ELITE_XP_REWARD`/`BOSS_XP_REWARD` (Task 3).
- Produces: `RunScene.skill_tree_scene: SkillTreeScene` field. No later
  task in this plan consumes it.

- [ ] **Step 1: Write the failing tests**

Add to `tests/unit/test_run_scene.gd`:

```gdscript
func test_pressing_skill_tree_button_shows_skill_tree_scene():
	var scene := RunScene.new()
	add_child_autofree(scene)
	scene.map_view.skill_tree_requested.emit()
	assert_eq(scene.skill_tree_scene.get_parent(), scene)

func test_skill_tree_back_returns_to_map_without_advancing_position():
	var scene := RunScene.new()
	add_child_autofree(scene)
	var starting_node := RunState.current_node
	scene.map_view.skill_tree_requested.emit()
	scene.skill_tree_scene.back_requested.emit()
	assert_eq(scene.map_view.get_parent(), scene)
	assert_eq(RunState.current_node, starting_node)

func test_winning_a_combat_node_grants_xp():
	var scene := RunScene.new()
	add_child_autofree(scene)
	var combat_node := MapNode.new(9999, MapNode.NodeType.COMBAT, 0)
	scene.map_view.node_selected.emit(combat_node)
	scene.combat_scene.combat_dismissed.emit(true)
	assert_eq(RunState.xp, RunState.COMBAT_XP_REWARD)

func test_winning_an_elite_node_grants_enough_xp_to_level_up():
	var scene := RunScene.new()
	add_child_autofree(scene)
	var elite_node := MapNode.new(9999, MapNode.NodeType.ELITE, 0)
	scene.map_view.node_selected.emit(elite_node)
	scene.combat_scene.combat_dismissed.emit(true)
	assert_eq(RunState.level, 2)
	assert_eq(RunState.skill_points, 1)
```

The elite test relies on the exact numbers already established:
`ELITE_XP_REWARD` (30) exceeds `XP_THRESHOLDS[0]` (20) by 10, which is
below `XP_THRESHOLDS[1]` (30) — so it produces exactly one level-up
(level 2, 1 skill point), not two.

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_run_scene.gd -gexit`
Expected: FAIL — `skill_tree_scene` doesn't exist yet, and combat wins
don't grant XP yet.

- [ ] **Step 3: Add the field and wire the skill-tree swap**

In `scripts/ui/run/run_scene.gd`, add the field alongside the other scene
fields:

```gdscript
var victory_scene: VictoryScene
var game_over_scene: GameOverScene
var skill_tree_scene: SkillTreeScene
```

Update `_ready()` to connect the new signal:

```gdscript
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	map_view = MapView.new()
	map_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_view.node_selected.connect(_on_map_node_selected)
	map_view.skill_tree_requested.connect(_on_skill_tree_requested)
	add_child(map_view)
	RunState.start_new_run(DwarfContent.get_class_resource())
	_show_map()
```

Add two new handler methods (e.g. after `_show_map`):

```gdscript
func _on_skill_tree_requested() -> void:
	skill_tree_scene = SkillTreeScene.new()
	skill_tree_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	skill_tree_scene.back_requested.connect(_on_skill_tree_back_requested)
	_swap_to(skill_tree_scene)

func _on_skill_tree_back_requested() -> void:
	_show_map()
```

- [ ] **Step 4: Grant XP on a combat win**

In `scripts/ui/run/run_scene.gd`, `_on_combat_dismissed` currently reads:

```gdscript
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
		RunState.current_floor = node.floor
		_show_game_over()
```

Change it to also grant XP:

```gdscript
func _on_combat_dismissed(player_won: bool, node: MapNode) -> void:
	if player_won:
		var gold_reward: int = _gold_reward_for(node.node_type)
		var xp_reward: int = _xp_reward_for(node.node_type)
		RunState.apply_combat_reward(gold_reward, combat_scene.encounter.player.current_hp)
		RunState.grant_xp(xp_reward)
		RunState.mark_node_visited_and_advance(node)
		if node.node_type == MapNode.NodeType.BOSS:
			_show_victory()
		else:
			_show_map()
	else:
		RunState.current_floor = node.floor
		_show_game_over()
```

Add a new private method mirroring `_gold_reward_for` (placed right after
it):

```gdscript
func _xp_reward_for(node_type: MapNode.NodeType) -> int:
	match node_type:
		MapNode.NodeType.ELITE:
			return RunState.ELITE_XP_REWARD
		MapNode.NodeType.BOSS:
			return RunState.BOSS_XP_REWARD
		_:
			return RunState.COMBAT_XP_REWARD
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gtest=test_run_scene.gd -gexit`
Expected: PASS, including all pre-existing `test_run_scene.gd` tests
(`test_winning_a_combat_node_grants_gold_and_returns_to_map` only asserts
on `RunState.gold`, so the added XP grant doesn't affect it).

- [ ] **Step 6: Run the full suite once**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: PASS, every test in the project.

- [ ] **Step 7: Commit**

```bash
git add scripts/ui/run/run_scene.gd tests/unit/test_run_scene.gd
git commit -m "feat: wire Skill Tree navigation and XP rewards into RunScene"
```

---

## Manual verification (non-negotiable, per the parent spec's standard)

Open the project in the Godot editor and play at least one full Act:

1. Confirm the map screen shows `Lv 1   XP: 0/20   Skill Points: 0` at the
   start of a fresh run.
2. Win a Combat, Elite, and the Boss fight; confirm the XP number advances
   and that leveling up increases Skill Points and (once, near level 2 or
   3) changes the header to reflect the new level and threshold.
3. Open the Skill Tree from the map button at least twice across a run —
   once before you have any points (all nodes locked), and once after
   leveling up. Confirm Dwarven Grit is the only node initially available,
   and that its children unlock only after it's bought.
4. Spend enough points to reach at least one capstone (Battle Fury or
   Unyielding) and confirm, in an actual fight, that: Strike cards deal
   visibly more damage, Guard cards block visibly more, and the capstone's
   effect (extra Strength stacks or starting Block, shown at the start of
   the very first turn) is present.
5. Confirm you cannot fully clear both branches in one run (6 points,
   7 nodes) — the tree should always leave at least one node you can't
   afford.
6. Confirm pressing "Back" from the Skill Tree returns to the map without
   marking any node visited or otherwise disturbing your run position.

Automated tests passing is not sufficient on its own to call this plan
done.
