# Core Combat Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and prove, with automated tests, the pure-logic core of the
STS2-style combat engine: card effects, actor HP/block/status state, the
persistent-stat-to-baseline mapping, one playable class (Dwarf), one enemy
(Cave Rat), and the turn-resolution engine that ties them together — no
Godot scenes/UI yet.

**Architecture:** All gameplay logic lives in plain GDScript classes
(`RefCounted`/`Resource`), decoupled from any Scene/Node so it can be unit
tested headlessly with GUT. Cards and enemy moves are built from small,
composable `CardEffect` resources (Damage, Block, ApplyStatus) resolved
against an `EffectContext`. A `CombatEncounter` class orchestrates the
turn loop (draw, spend, play, enemy act, win/loss) against two
`CombatActor` instances. Content (the Dwarf's deck, the Cave Rat) is
authored as GDScript factory functions rather than hand-written `.tres`
files for this plan — see Global Constraints.

**Tech Stack:** Godot 4.7, GDScript only, GUT (bitwes/Gut) for automated
tests.

**Spec:** `docs/superpowers/specs/2026-09-04-party-deckbuilder-design.md`

## Global Constraints

- Engine: **Godot 4.7**, **GDScript only** (spec §7) — no C#.
- Persistent stats (STR/AGI/INT/VIT/LUK) set a run's *baseline* only; they
  never modify in-run status-effect math directly (spec §3). In this
  plan that means `CombatActor.baseline_strike_bonus` (from persistent
  STR) is a field wholly separate from `status_stacks["strength"]`
  (an in-run buff) — `DamageEffect` adds both, independently.
- No copyrighted *Donjon de Naheulbeuk* names, dialogue, or plot in any
  content string (spec §6) — the Dwarf/Cave Rat content in this plan
  uses only generic fantasy naming.
- **Content-as-code for this plan only:** the spec's long-term intent is
  data-driven `.tres` resources authored in the Godot editor (spec §7).
  Hand-typing `.tres` text by hand is error-prone and can't be validated
  without opening the editor, and this plan has no editor UI yet to
  validate against — so Dwarf's deck and the Cave Rat are built via
  GDScript static factory functions (Task 10) instead. The underlying
  `Resource` subclasses (Task 8) are the same ones the editor Inspector
  will produce `.tres` files for once Plan 2 adds scenes to look at —
  nothing here blocks switching to editor-authored `.tres` content later.
- **Single-enemy combat only** in this plan (`CombatEncounter` takes one
  `enemy: CombatActor`). Multi-enemy fights are deferred to a
  content-focused plan once the engine's single-enemy path is proven.
- `ApplyStatusEffect` stores arbitrary status stacks (e.g. `weak`) but
  **only `strength` is consumed** by `DamageEffect` in this plan, matching
  the spec's own worked example (spec §3). Vulnerable/Weak damage
  modifiers are real future work, not implemented here.
- Every `Run:` command below assumes a Godot 4.7 executable resolved in
  Task 1 as `$GODOT_BIN` — substitute the actual path/command found or
  installed in that task.

---

## Task 1: Scaffold the Godot project

**Files:**
- Create: `project.godot`
- Create: `.gitignore`

**Interfaces:**
- Produces: a valid Godot 4.7 project at the repo root that opens
  headlessly without errors.

- [ ] **Step 1: Locate or install Godot 4.7**

Run: `where godot`

If that finds nothing, download and extract the official Windows build:

```bash
curl -L -o /tmp/godot.zip "https://github.com/godotengine/godot/releases/download/4.7-stable/Godot_v4.7-stable_win64.exe.zip"
powershell -NoProfile -Command "Expand-Archive -Path '/tmp/godot.zip' -DestinationPath 'C:/Tools/Godot' -Force"
```

The binary will be at `C:/Tools/Godot/Godot_v4.7-stable_win64.exe`. Use
whichever path actually works (`godot` on PATH, or this extracted path)
as `$GODOT_BIN` for every command in this and later tasks.

- [ ] **Step 2: Create `project.godot`**

```ini
config_version=5

[application]

config/name="Party Deckbuilder"
config/features=PackedStringArray("4.7", "Forward Plus")
```

- [ ] **Step 3: Create `.gitignore`**

```
.godot/
.import/
export_presets.cfg
*.translation
```

- [ ] **Step 4: Verify the project opens headlessly**

Run: `"$GODOT_BIN" --headless --path . --quit`

Expected: exits 0, creates a `.godot/` cache directory, no "Failed to
load" or parse-error output referencing `project.godot`.

- [ ] **Step 5: Commit**

```bash
git add project.godot .gitignore
git commit -m "chore: scaffold Godot 4.7 project"
```

---

## Task 2: Install GUT and verify headless test running

**Files:**
- Create: `addons/gut/` (vendored copy of the GUT addon)
- Modify: `project.godot`
- Create: `tests/unit/test_smoke.gd`

**Interfaces:**
- Produces: a working headless test command,
  `"$GODOT_BIN" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`,
  used by every subsequent task.

- [ ] **Step 1: Vendor the GUT addon**

GUT is vendored directly (its files copied into the repo) rather than
added as a git submodule, so later tasks don't depend on network access
to check it out again.

```bash
git clone --depth 1 https://github.com/bitwes/Gut.git /tmp/gut_src_tmp
cp -r /tmp/gut_src_tmp/addons/gut ./addons/gut
rm -rf /tmp/gut_src_tmp
```

- [ ] **Step 2: Enable the plugin**

Append to `project.godot`:

```ini

[editor_plugins]

enabled=PackedStringArray("res://addons/gut/plugin.cfg")
```

- [ ] **Step 3: Write a smoke test**

`tests/unit/test_smoke.gd`:

```gdscript
extends GutTest

func test_gut_is_working():
	assert_eq(1 + 1, 2)
```

- [ ] **Step 4: Run it**

Run: `"$GODOT_BIN" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`

Expected: output reports 1 test run, 1 passing, 0 failing; process exits 0.
If the exact CLI flags differ for the vendored GUT version, check
`addons/gut/gut_cmdln.gd`'s `-h` output — the addon is self-documenting.

- [ ] **Step 5: Commit**

```bash
git add addons/gut project.godot tests/unit/test_smoke.gd
git commit -m "test: vendor GUT and verify headless test running"
```

---

## Task 3: CombatActor

**Files:**
- Create: `scripts/combat/combat_actor.gd`
- Test: `tests/unit/test_combat_actor.gd`

**Interfaces:**
- Produces: `class_name CombatActor extends RefCounted` with
  `signal died`, fields `display_name: String`, `max_hp: int`,
  `current_hp: int`, `block: int`, `baseline_strike_bonus: int`,
  `status_stacks: Dictionary`, constructor
  `_init(p_display_name: String, p_max_hp: int, p_baseline_strike_bonus: int = 0)`,
  and methods `take_damage(amount: int) -> void`,
  `add_block(amount: int) -> void`, `clear_block() -> void`,
  `get_status_stacks(status_id: StringName) -> int`,
  `add_status(status_id: StringName, stacks: int) -> void`.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_combat_actor.gd`:

```gdscript
extends GutTest

func test_new_actor_starts_at_max_hp():
	var actor := CombatActor.new("Hero", 20)
	assert_eq(actor.current_hp, 20)
	assert_eq(actor.max_hp, 20)

func test_take_damage_reduces_hp():
	var actor := CombatActor.new("Hero", 20)
	actor.take_damage(5)
	assert_eq(actor.current_hp, 15)

func test_take_damage_is_absorbed_by_block_first():
	var actor := CombatActor.new("Hero", 20)
	actor.add_block(4)
	actor.take_damage(6)
	assert_eq(actor.block, 0)
	assert_eq(actor.current_hp, 18)

func test_take_damage_cannot_reduce_hp_below_zero():
	var actor := CombatActor.new("Hero", 10)
	actor.take_damage(999)
	assert_eq(actor.current_hp, 0)

func test_clear_block_resets_to_zero():
	var actor := CombatActor.new("Hero", 20)
	actor.add_block(5)
	actor.clear_block()
	assert_eq(actor.block, 0)

func test_status_stacks_default_to_zero_and_can_be_added():
	var actor := CombatActor.new("Hero", 20)
	assert_eq(actor.get_status_stacks(&"strength"), 0)
	actor.add_status(&"strength", 3)
	assert_eq(actor.get_status_stacks(&"strength"), 3)
	actor.add_status(&"strength", 2)
	assert_eq(actor.get_status_stacks(&"strength"), 5)

func test_died_signal_emitted_when_hp_reaches_zero():
	var actor := CombatActor.new("Hero", 5)
	watch_signals(actor)
	actor.take_damage(5)
	assert_signal_emitted(actor, "died")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `"$GODOT_BIN" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: FAIL — `CombatActor` does not exist.

- [ ] **Step 3: Implement**

`scripts/combat/combat_actor.gd`:

```gdscript
extends RefCounted
class_name CombatActor

signal died

var display_name: String
var max_hp: int
var current_hp: int
var block: int = 0
var baseline_strike_bonus: int = 0
var status_stacks: Dictionary = {}

func _init(p_display_name: String, p_max_hp: int, p_baseline_strike_bonus: int = 0) -> void:
	display_name = p_display_name
	max_hp = p_max_hp
	current_hp = p_max_hp
	baseline_strike_bonus = p_baseline_strike_bonus

func take_damage(amount: int) -> void:
	var incoming := max(amount, 0)
	var absorbed := min(block, incoming)
	block -= absorbed
	var remaining := incoming - absorbed
	current_hp = max(current_hp - remaining, 0)
	if current_hp == 0:
		died.emit()

func add_block(amount: int) -> void:
	block += amount

func clear_block() -> void:
	block = 0

func get_status_stacks(status_id: StringName) -> int:
	return status_stacks.get(status_id, 0)

func add_status(status_id: StringName, stacks: int) -> void:
	status_stacks[status_id] = get_status_stacks(status_id) + stacks
```

- [ ] **Step 4: Run test to verify it passes**

Run: `"$GODOT_BIN" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: PASS, all 7 assertions.

- [ ] **Step 5: Commit**

```bash
git add scripts/combat/combat_actor.gd tests/unit/test_combat_actor.gd
git commit -m "feat: add CombatActor with HP/block/status state"
```

---

## Task 4: EffectContext and CardEffect base class

**Files:**
- Create: `scripts/combat/effect_context.gd`
- Create: `scripts/resources/card_effect.gd`
- Test: `tests/unit/test_effect_context.gd`

**Interfaces:**
- Consumes: `CombatActor` (Task 3).
- Produces: `class_name EffectContext extends RefCounted` with fields
  `source: CombatActor`, `target: CombatActor`,
  `_init(p_source: CombatActor, p_target: CombatActor)`; and
  `class_name CardEffect extends Resource` with virtual method
  `apply(context: EffectContext) -> void` for later effect subclasses
  (Tasks 5-7) to override.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_effect_context.gd`:

```gdscript
extends GutTest

func test_context_stores_source_and_target():
	var source := CombatActor.new("Source", 10)
	var target := CombatActor.new("Target", 10)
	var context := EffectContext.new(source, target)
	assert_eq(context.source, source)
	assert_eq(context.target, target)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `"$GODOT_BIN" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: FAIL — `EffectContext` does not exist.

- [ ] **Step 3: Implement**

`scripts/combat/effect_context.gd`:

```gdscript
extends RefCounted
class_name EffectContext

var source: CombatActor
var target: CombatActor

func _init(p_source: CombatActor, p_target: CombatActor) -> void:
	source = p_source
	target = p_target
```

`scripts/resources/card_effect.gd`:

```gdscript
extends Resource
class_name CardEffect

func apply(_context: EffectContext) -> void:
	push_error("CardEffect.apply() must be overridden by a subclass")
```

- [ ] **Step 4: Run test to verify it passes**

Run: `"$GODOT_BIN" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/combat/effect_context.gd scripts/resources/card_effect.gd tests/unit/test_effect_context.gd
git commit -m "feat: add EffectContext and CardEffect base class"
```

---

## Task 5: DamageEffect

**Files:**
- Create: `scripts/resources/effects/damage_effect.gd`
- Test: `tests/unit/test_damage_effect.gd`

**Interfaces:**
- Consumes: `CardEffect`, `EffectContext` (Task 4), `CombatActor` (Task 3).
- Produces: `class_name DamageEffect extends CardEffect` with
  `@export var amount: int = 0`.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_damage_effect.gd`:

```gdscript
extends GutTest

func test_damage_effect_deals_flat_amount():
	var effect := DamageEffect.new()
	effect.amount = 6
	var source := CombatActor.new("Source", 10)
	var target := CombatActor.new("Target", 20)
	var context := EffectContext.new(source, target)
	effect.apply(context)
	assert_eq(target.current_hp, 14)

func test_damage_effect_adds_source_strength_stacks():
	var effect := DamageEffect.new()
	effect.amount = 6
	var source := CombatActor.new("Source", 10)
	source.add_status(&"strength", 3)
	var target := CombatActor.new("Target", 20)
	var context := EffectContext.new(source, target)
	effect.apply(context)
	assert_eq(target.current_hp, 11)

func test_damage_effect_adds_source_baseline_strike_bonus():
	var effect := DamageEffect.new()
	effect.amount = 6
	var source := CombatActor.new("Source", 10, 4)
	var target := CombatActor.new("Target", 20)
	var context := EffectContext.new(source, target)
	effect.apply(context)
	assert_eq(target.current_hp, 10)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `"$GODOT_BIN" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: FAIL — `DamageEffect` does not exist.

- [ ] **Step 3: Implement**

`scripts/resources/effects/damage_effect.gd`:

```gdscript
extends CardEffect
class_name DamageEffect

@export var amount: int = 0

func apply(context: EffectContext) -> void:
	var total := amount
	total += context.source.get_status_stacks(&"strength")
	total += context.source.baseline_strike_bonus
	context.target.take_damage(total)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `"$GODOT_BIN" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/resources/effects/damage_effect.gd tests/unit/test_damage_effect.gd
git commit -m "feat: add DamageEffect"
```

---

## Task 6: BlockEffect

**Files:**
- Create: `scripts/resources/effects/block_effect.gd`
- Test: `tests/unit/test_block_effect.gd`

**Interfaces:**
- Consumes: `CardEffect`, `EffectContext` (Task 4).
- Produces: `class_name BlockEffect extends CardEffect` with
  `@export var amount: int = 0`.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_block_effect.gd`:

```gdscript
extends GutTest

func test_block_effect_adds_block_to_target():
	var effect := BlockEffect.new()
	effect.amount = 5
	var source := CombatActor.new("Source", 10)
	var target := CombatActor.new("Target", 10)
	var context := EffectContext.new(source, target)
	effect.apply(context)
	assert_eq(target.block, 5)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `"$GODOT_BIN" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: FAIL — `BlockEffect` does not exist.

- [ ] **Step 3: Implement**

`scripts/resources/effects/block_effect.gd`:

```gdscript
extends CardEffect
class_name BlockEffect

@export var amount: int = 0

func apply(context: EffectContext) -> void:
	context.target.add_block(amount)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `"$GODOT_BIN" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/resources/effects/block_effect.gd tests/unit/test_block_effect.gd
git commit -m "feat: add BlockEffect"
```

---

## Task 7: ApplyStatusEffect

**Files:**
- Create: `scripts/resources/effects/apply_status_effect.gd`
- Test: `tests/unit/test_apply_status_effect.gd`

**Interfaces:**
- Consumes: `CardEffect`, `EffectContext` (Task 4).
- Produces: `class_name ApplyStatusEffect extends CardEffect` with
  `@export var status_id: StringName = &""`,
  `@export var stacks: int = 0`,
  `@export var apply_to_source: bool = false`.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_apply_status_effect.gd`:

```gdscript
extends GutTest

func test_apply_status_effect_targets_target_by_default():
	var effect := ApplyStatusEffect.new()
	effect.status_id = &"weak"
	effect.stacks = 2
	var source := CombatActor.new("Source", 10)
	var target := CombatActor.new("Target", 10)
	var context := EffectContext.new(source, target)
	effect.apply(context)
	assert_eq(target.get_status_stacks(&"weak"), 2)
	assert_eq(source.get_status_stacks(&"weak"), 0)

func test_apply_status_effect_can_target_source():
	var effect := ApplyStatusEffect.new()
	effect.status_id = &"strength"
	effect.stacks = 3
	effect.apply_to_source = true
	var source := CombatActor.new("Source", 10)
	var target := CombatActor.new("Target", 10)
	var context := EffectContext.new(source, target)
	effect.apply(context)
	assert_eq(source.get_status_stacks(&"strength"), 3)
	assert_eq(target.get_status_stacks(&"strength"), 0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `"$GODOT_BIN" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: FAIL — `ApplyStatusEffect` does not exist.

- [ ] **Step 3: Implement**

`scripts/resources/effects/apply_status_effect.gd`:

```gdscript
extends CardEffect
class_name ApplyStatusEffect

@export var status_id: StringName = &""
@export var stacks: int = 0
@export var apply_to_source: bool = false

func apply(context: EffectContext) -> void:
	var actor := context.source if apply_to_source else context.target
	actor.add_status(status_id, stacks)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `"$GODOT_BIN" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/resources/effects/apply_status_effect.gd tests/unit/test_apply_status_effect.gd
git commit -m "feat: add ApplyStatusEffect"
```

---

## Task 8: Data model resources (CardResource, EnemyMove, EnemyResource, ClassResource)

**Files:**
- Create: `scripts/resources/card_resource.gd`
- Create: `scripts/resources/enemy_move.gd`
- Create: `scripts/resources/enemy_resource.gd`
- Create: `scripts/resources/class_resource.gd`
- Test: `tests/unit/test_data_resources.gd`

**Interfaces:**
- Consumes: `CardEffect` (Task 4).
- Produces:
  - `class_name CardResource extends Resource`: enums `CardType {STRIKE, TECHNIQUE, TRAIT}`
    and `TargetType {SINGLE_ENEMY, SELF}`; fields `id: StringName`,
    `display_name: String`, `cost: int = 1`,
    `card_type: CardType = CardType.STRIKE`,
    `target_type: TargetType = TargetType.SINGLE_ENEMY`,
    `effects: Array[CardEffect] = []`.
  - `class_name EnemyMove extends Resource`: enum
    `IntentType {ATTACK, DEFEND, BUFF, DEBUFF, SPECIAL}`; fields
    `intent_type: IntentType = IntentType.ATTACK`,
    `effects: Array[CardEffect] = []`.
  - `class_name EnemyResource extends Resource`: fields `id: StringName`,
    `display_name: String`, `max_hp: int = 1`,
    `moves: Array[EnemyMove] = []`.
  - `class_name ClassResource extends Resource`: fields `id: StringName`,
    `display_name: String`, `base_hp: int = 1`,
    `starting_deck: Array[CardResource] = []`.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_data_resources.gd`:

```gdscript
extends GutTest

func test_card_resource_holds_configured_fields():
	var card := CardResource.new()
	card.id = &"test_card"
	card.display_name = "Test Card"
	card.cost = 2
	card.card_type = CardResource.CardType.TECHNIQUE
	card.target_type = CardResource.TargetType.SELF
	var effect := BlockEffect.new()
	effect.amount = 5
	card.effects = [effect]
	assert_eq(card.cost, 2)
	assert_eq(card.card_type, CardResource.CardType.TECHNIQUE)
	assert_eq(card.effects.size(), 1)

func test_enemy_move_holds_intent_and_effects():
	var move := EnemyMove.new()
	move.intent_type = EnemyMove.IntentType.ATTACK
	var effect := DamageEffect.new()
	effect.amount = 5
	move.effects = [effect]
	assert_eq(move.intent_type, EnemyMove.IntentType.ATTACK)
	assert_eq(move.effects.size(), 1)

func test_enemy_resource_holds_moves():
	var enemy := EnemyResource.new()
	enemy.id = &"test_enemy"
	enemy.display_name = "Test Enemy"
	enemy.max_hp = 15
	var move := EnemyMove.new()
	enemy.moves = [move]
	assert_eq(enemy.max_hp, 15)
	assert_eq(enemy.moves.size(), 1)

func test_class_resource_holds_starting_deck():
	var class_res := ClassResource.new()
	class_res.id = &"test_class"
	class_res.display_name = "Test Class"
	class_res.base_hp = 20
	var card := CardResource.new()
	class_res.starting_deck = [card]
	assert_eq(class_res.base_hp, 20)
	assert_eq(class_res.starting_deck.size(), 1)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `"$GODOT_BIN" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: FAIL — none of the four classes exist.

- [ ] **Step 3: Implement**

`scripts/resources/card_resource.gd`:

```gdscript
extends Resource
class_name CardResource

enum CardType { STRIKE, TECHNIQUE, TRAIT }
enum TargetType { SINGLE_ENEMY, SELF }

@export var id: StringName = &""
@export var display_name: String = ""
@export var cost: int = 1
@export var card_type: CardType = CardType.STRIKE
@export var target_type: TargetType = TargetType.SINGLE_ENEMY
@export var effects: Array[CardEffect] = []
```

`scripts/resources/enemy_move.gd`:

```gdscript
extends Resource
class_name EnemyMove

enum IntentType { ATTACK, DEFEND, BUFF, DEBUFF, SPECIAL }

@export var intent_type: IntentType = IntentType.ATTACK
@export var effects: Array[CardEffect] = []
```

`scripts/resources/enemy_resource.gd`:

```gdscript
extends Resource
class_name EnemyResource

@export var id: StringName = &""
@export var display_name: String = ""
@export var max_hp: int = 1
@export var moves: Array[EnemyMove] = []
```

`scripts/resources/class_resource.gd`:

```gdscript
extends Resource
class_name ClassResource

@export var id: StringName = &""
@export var display_name: String = ""
@export var base_hp: int = 1
@export var starting_deck: Array[CardResource] = []
```

- [ ] **Step 4: Run test to verify it passes**

Run: `"$GODOT_BIN" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/resources/card_resource.gd scripts/resources/enemy_move.gd scripts/resources/enemy_resource.gd scripts/resources/class_resource.gd tests/unit/test_data_resources.gd
git commit -m "feat: add card/enemy/class data resources"
```

---

## Task 9: PersistentStats and ActorFactory

**Files:**
- Create: `scripts/stats/persistent_stats.gd`
- Create: `scripts/combat/actor_factory.gd`
- Test: `tests/unit/test_persistent_stats_and_actor_factory.gd`

**Interfaces:**
- Consumes: `CombatActor` (Task 3), `ClassResource`, `EnemyResource` (Task 8).
- Produces: `class_name PersistentStats extends Resource` with
  `@export var strength/agility/intellect/vitality/luck: int = 0` and
  methods `compute_max_hp(base_hp: int) -> int`,
  `compute_base_strike_bonus() -> int`; and
  `class_name ActorFactory extends RefCounted` with static methods
  `build_player_actor(class_resource: ClassResource, stats: PersistentStats) -> CombatActor`
  and `build_enemy_actor(enemy_resource: EnemyResource) -> CombatActor`.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_persistent_stats_and_actor_factory.gd`:

```gdscript
extends GutTest

func test_compute_max_hp_adds_vitality_bonus():
	var stats := PersistentStats.new()
	stats.vitality = 5
	assert_eq(stats.compute_max_hp(30), 40)

func test_compute_base_strike_bonus_equals_strength():
	var stats := PersistentStats.new()
	stats.strength = 4
	assert_eq(stats.compute_base_strike_bonus(), 4)

func test_build_player_actor_applies_baseline_stats():
	var class_res := ClassResource.new()
	class_res.display_name = "Dwarf"
	class_res.base_hp = 30
	var stats := PersistentStats.new()
	stats.vitality = 5
	stats.strength = 4
	var actor := ActorFactory.build_player_actor(class_res, stats)
	assert_eq(actor.display_name, "Dwarf")
	assert_eq(actor.max_hp, 40)
	assert_eq(actor.current_hp, 40)
	assert_eq(actor.baseline_strike_bonus, 4)

func test_build_enemy_actor_uses_enemy_resource_fields():
	var enemy_res := EnemyResource.new()
	enemy_res.display_name = "Cave Rat"
	enemy_res.max_hp = 12
	var actor := ActorFactory.build_enemy_actor(enemy_res)
	assert_eq(actor.display_name, "Cave Rat")
	assert_eq(actor.max_hp, 12)
	assert_eq(actor.baseline_strike_bonus, 0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `"$GODOT_BIN" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: FAIL — `PersistentStats`/`ActorFactory` do not exist.

- [ ] **Step 3: Implement**

`scripts/stats/persistent_stats.gd`:

```gdscript
extends Resource
class_name PersistentStats

@export var strength: int = 0
@export var agility: int = 0
@export var intellect: int = 0
@export var vitality: int = 0
@export var luck: int = 0

func compute_max_hp(base_hp: int) -> int:
	return base_hp + vitality * 2

func compute_base_strike_bonus() -> int:
	return strength
```

`scripts/combat/actor_factory.gd`:

```gdscript
extends RefCounted
class_name ActorFactory

static func build_player_actor(class_resource: ClassResource, stats: PersistentStats) -> CombatActor:
	var max_hp := stats.compute_max_hp(class_resource.base_hp)
	return CombatActor.new(class_resource.display_name, max_hp, stats.compute_base_strike_bonus())

static func build_enemy_actor(enemy_resource: EnemyResource) -> CombatActor:
	return CombatActor.new(enemy_resource.display_name, enemy_resource.max_hp)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `"$GODOT_BIN" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/stats/persistent_stats.gd scripts/combat/actor_factory.gd tests/unit/test_persistent_stats_and_actor_factory.gd
git commit -m "feat: add PersistentStats and ActorFactory baseline mapping"
```

---

## Task 10: Dwarf and Cave Rat starter content

**Files:**
- Create: `scripts/content/dwarf_content.gd`
- Create: `scripts/content/cave_rat_content.gd`
- Test: `tests/unit/test_starter_content.gd`

**Interfaces:**
- Consumes: `ClassResource`, `CardResource`, `EnemyResource`, `EnemyMove`
  (Task 8), `DamageEffect`, `BlockEffect`, `ApplyStatusEffect` (Tasks 5-7).
- Produces: `class_name DwarfContent extends RefCounted` with static
  `get_class_resource() -> ClassResource`; and
  `class_name CaveRatContent extends RefCounted` with static
  `get_enemy_resource() -> EnemyResource`.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_starter_content.gd`:

```gdscript
extends GutTest

func test_dwarf_class_resource_has_expected_shape():
	var class_res := DwarfContent.get_class_resource()
	assert_eq(class_res.display_name, "Dwarf")
	assert_eq(class_res.base_hp, 30)
	assert_eq(class_res.starting_deck.size(), 5)

func test_dwarf_deck_includes_strike_and_guard():
	var class_res := DwarfContent.get_class_resource()
	var names := []
	for card in class_res.starting_deck:
		names.append(card.display_name)
	assert_true(names.count("Strike") >= 3)
	assert_true(names.count("Guard") >= 1)

func test_cave_rat_enemy_resource_has_expected_shape():
	var enemy_res := CaveRatContent.get_enemy_resource()
	assert_eq(enemy_res.display_name, "Cave Rat")
	assert_eq(enemy_res.max_hp, 18)
	assert_eq(enemy_res.moves.size(), 2)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `"$GODOT_BIN" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: FAIL — `DwarfContent`/`CaveRatContent` do not exist.

- [ ] **Step 3: Implement**

`scripts/content/dwarf_content.gd`:

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
	return card
```

`scripts/content/cave_rat_content.gd`:

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

static func _make_bite_move() -> EnemyMove:
	var move := EnemyMove.new()
	move.intent_type = EnemyMove.IntentType.ATTACK
	var effect := DamageEffect.new()
	effect.amount = 5
	move.effects = [effect]
	return move

static func _make_screech_move() -> EnemyMove:
	var move := EnemyMove.new()
	move.intent_type = EnemyMove.IntentType.DEBUFF
	var effect := ApplyStatusEffect.new()
	effect.status_id = &"weak"
	effect.stacks = 1
	effect.apply_to_source = false
	move.effects = [effect]
	return move
```

- [ ] **Step 4: Run test to verify it passes**

Run: `"$GODOT_BIN" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/content/dwarf_content.gd scripts/content/cave_rat_content.gd tests/unit/test_starter_content.gd
git commit -m "feat: add Dwarf and Cave Rat starter content"
```

---

## Task 11: CombatEncounter turn engine

**Files:**
- Create: `scripts/combat/combat_encounter.gd`
- Test: `tests/unit/test_combat_encounter.gd`

**Interfaces:**
- Consumes: `CombatActor` (Task 3), `EffectContext` (Task 4),
  `CardResource`, `EnemyMove` (Task 8).
- Produces: `class_name CombatEncounter extends RefCounted` with
  constants `MAX_HAND_SIZE := 5`, `MAX_ENERGY := 3`; fields
  `player: CombatActor`, `enemy: CombatActor`,
  `enemy_moves: Array[EnemyMove]`, `draw_pile/hand/discard_pile: Array[CardResource]`,
  `energy: int`, `is_over: bool`, `player_won: bool`; constructor
  `_init(p_player: CombatActor, p_deck: Array[CardResource], p_enemy: CombatActor, p_enemy_moves: Array[EnemyMove])`;
  methods `start_player_turn() -> void`,
  `can_play_card(card: CardResource) -> bool`,
  `play_card(card: CardResource) -> void`,
  `end_player_turn() -> void`,
  `get_current_enemy_intent() -> EnemyMove`.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_combat_encounter.gd`:

```gdscript
extends GutTest

func _make_actor(hp: int) -> CombatActor:
	return CombatActor.new("Test", hp)

func _make_strike(amount: int) -> CardResource:
	var card := CardResource.new()
	card.display_name = "Strike"
	card.cost = 1
	var effect := DamageEffect.new()
	effect.amount = amount
	card.effects = [effect]
	return card

func _make_guard(amount: int) -> CardResource:
	var card := CardResource.new()
	card.display_name = "Guard"
	card.cost = 1
	card.target_type = CardResource.TargetType.SELF
	var effect := BlockEffect.new()
	effect.amount = amount
	card.effects = [effect]
	return card

func _make_attack_move(amount: int) -> EnemyMove:
	var move := EnemyMove.new()
	move.intent_type = EnemyMove.IntentType.ATTACK
	var effect := DamageEffect.new()
	effect.amount = amount
	move.effects = [effect]
	return move

func test_start_player_turn_draws_up_to_hand_size():
	var player := _make_actor(20)
	var enemy := _make_actor(20)
	var deck: Array[CardResource] = []
	for i in range(8):
		deck.append(_make_strike(3))
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(3)])
	encounter.start_player_turn()
	assert_eq(encounter.hand.size(), 5)
	assert_eq(encounter.energy, 3)

func test_play_card_spends_energy_and_moves_card_to_discard():
	var player := _make_actor(20)
	var enemy := _make_actor(20)
	var deck: Array[CardResource] = [_make_strike(3)]
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(3)])
	encounter.start_player_turn()
	var card = encounter.hand[0]
	encounter.play_card(card)
	assert_eq(encounter.energy, 2)
	assert_false(encounter.hand.has(card))
	assert_true(encounter.discard_pile.has(card))
	assert_eq(enemy.current_hp, 17)

func test_self_targeted_card_applies_effect_to_player_not_enemy():
	var player := _make_actor(20)
	var enemy := _make_actor(20)
	var deck: Array[CardResource] = [_make_guard(5)]
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(3)])
	encounter.start_player_turn()
	encounter.play_card(encounter.hand[0])
	assert_eq(player.block, 5)
	assert_eq(enemy.block, 0)

func test_cannot_play_card_without_enough_energy():
	var player := _make_actor(20)
	var enemy := _make_actor(20)
	var expensive_card := _make_strike(3)
	expensive_card.cost = 99
	var encounter := CombatEncounter.new(player, [expensive_card], enemy, [_make_attack_move(3)])
	encounter.start_player_turn()
	assert_false(encounter.can_play_card(expensive_card))

func test_end_player_turn_discards_hand_and_runs_enemy_attack():
	var player := _make_actor(20)
	var enemy := _make_actor(20)
	var deck: Array[CardResource] = []
	for i in range(5):
		deck.append(_make_strike(3))
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(4)])
	encounter.start_player_turn()
	encounter.end_player_turn()
	assert_eq(encounter.hand.size(), 0)
	assert_eq(player.current_hp, 16)

func test_reshuffles_discard_into_draw_pile_when_empty():
	var player := _make_actor(20)
	var enemy := _make_actor(20)
	var deck: Array[CardResource] = []
	for i in range(5):
		deck.append(_make_strike(1))
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(1)])
	encounter.start_player_turn()
	encounter.end_player_turn()
	encounter.start_player_turn()
	assert_eq(encounter.hand.size(), 5)
	assert_eq(encounter.draw_pile.size() + encounter.hand.size() + encounter.discard_pile.size(), 5)

func test_combat_ends_when_enemy_hp_reaches_zero():
	var player := _make_actor(20)
	var enemy := _make_actor(5)
	var deck: Array[CardResource] = [_make_strike(10)]
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(1)])
	encounter.start_player_turn()
	encounter.play_card(encounter.hand[0])
	assert_true(encounter.is_over)
	assert_true(encounter.player_won)

func test_combat_ends_when_player_hp_reaches_zero():
	var player := _make_actor(3)
	var enemy := _make_actor(20)
	var deck: Array[CardResource] = []
	for i in range(5):
		deck.append(_make_strike(0))
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(10)])
	encounter.start_player_turn()
	encounter.end_player_turn()
	assert_true(encounter.is_over)
	assert_false(encounter.player_won)

func test_get_current_enemy_intent_cycles_through_moves():
	var player := _make_actor(20)
	var enemy := _make_actor(20)
	var deck: Array[CardResource] = []
	for i in range(5):
		deck.append(_make_strike(0))
	var move_a := _make_attack_move(3)
	var move_b := _make_attack_move(5)
	var encounter := CombatEncounter.new(player, deck, enemy, [move_a, move_b])
	assert_eq(encounter.get_current_enemy_intent(), move_a)
	encounter.start_player_turn()
	encounter.end_player_turn()
	assert_eq(encounter.get_current_enemy_intent(), move_b)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `"$GODOT_BIN" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: FAIL — `CombatEncounter` does not exist.

- [ ] **Step 3: Implement**

`scripts/combat/combat_encounter.gd`:

```gdscript
extends RefCounted
class_name CombatEncounter

const MAX_HAND_SIZE := 5
const MAX_ENERGY := 3

var player: CombatActor
var enemy: CombatActor
var enemy_moves: Array[EnemyMove] = []
var enemy_move_index: int = 0

var draw_pile: Array[CardResource] = []
var hand: Array[CardResource] = []
var discard_pile: Array[CardResource] = []

var energy: int = 0
var is_over: bool = false
var player_won: bool = false

func _init(p_player: CombatActor, p_deck: Array[CardResource], p_enemy: CombatActor, p_enemy_moves: Array[EnemyMove]) -> void:
	player = p_player
	enemy = p_enemy
	enemy_moves = p_enemy_moves
	draw_pile = p_deck.duplicate()
	draw_pile.shuffle()

func start_player_turn() -> void:
	energy = MAX_ENERGY
	player.clear_block()
	_draw_hand()

func can_play_card(card: CardResource) -> bool:
	return not is_over and hand.has(card) and card.cost <= energy

func play_card(card: CardResource) -> void:
	if not can_play_card(card):
		push_error("Cannot play card: %s" % card.display_name)
		return
	energy -= card.cost
	hand.erase(card)
	discard_pile.append(card)
	var target := player if card.target_type == CardResource.TargetType.SELF else enemy
	var context := EffectContext.new(player, target)
	for effect in card.effects:
		effect.apply(context)
	_check_combat_over()

func end_player_turn() -> void:
	discard_pile.append_array(hand)
	hand.clear()
	if not is_over:
		_run_enemy_turn()
	_check_combat_over()

func get_current_enemy_intent() -> EnemyMove:
	return enemy_moves[enemy_move_index % enemy_moves.size()]

func _draw_hand() -> void:
	while hand.size() < MAX_HAND_SIZE:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile = discard_pile.duplicate()
			draw_pile.shuffle()
			discard_pile.clear()
		hand.append(draw_pile.pop_back())

func _run_enemy_turn() -> void:
	enemy.clear_block()
	var move := get_current_enemy_intent()
	var context := EffectContext.new(enemy, player)
	for effect in move.effects:
		effect.apply(context)
	enemy_move_index += 1
	_check_combat_over()

func _check_combat_over() -> void:
	if enemy.current_hp <= 0:
		is_over = true
		player_won = true
	elif player.current_hp <= 0:
		is_over = true
		player_won = false
```

- [ ] **Step 4: Run test to verify it passes**

Run: `"$GODOT_BIN" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: PASS, all cases.

- [ ] **Step 5: Commit**

```bash
git add scripts/combat/combat_encounter.gd tests/unit/test_combat_encounter.gd
git commit -m "feat: add CombatEncounter turn engine"
```

---

## Task 12: End-to-end integration test — Dwarf vs. Cave Rat

**Files:**
- Test: `tests/unit/test_dwarf_vs_cave_rat_integration.gd`

**Interfaces:**
- Consumes: `DwarfContent`, `CaveRatContent` (Task 10), `PersistentStats`,
  `ActorFactory` (Task 9), `CombatEncounter` (Task 11). Produces nothing
  further — this is the proof that all prior tasks compose correctly.

- [ ] **Step 1: Write the test**

`tests/unit/test_dwarf_vs_cave_rat_integration.gd`:

```gdscript
extends GutTest

func test_dwarf_defeats_cave_rat_with_repeated_strikes():
	var class_res := DwarfContent.get_class_resource()
	var stats := PersistentStats.new()
	stats.strength = 2
	stats.vitality = 3
	var player := ActorFactory.build_player_actor(class_res, stats)
	var enemy_res := CaveRatContent.get_enemy_resource()
	var enemy := ActorFactory.build_enemy_actor(enemy_res)
	var encounter := CombatEncounter.new(player, class_res.starting_deck, enemy, enemy_res.moves)

	var safety_turns := 0
	while not encounter.is_over and safety_turns < 20:
		encounter.start_player_turn()
		for card in encounter.hand.duplicate():
			if encounter.can_play_card(card):
				encounter.play_card(card)
			if encounter.is_over:
				break
		if not encounter.is_over:
			encounter.end_player_turn()
		safety_turns += 1

	assert_true(encounter.is_over)
	assert_true(encounter.player_won)
	assert_true(safety_turns < 20)
	assert_true(player.current_hp > 0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `"$GODOT_BIN" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: FAIL if any prior task is incomplete/broken — this test only
passes once the whole engine composes correctly end to end.

- [ ] **Step 3: Run test to verify it passes**

No new implementation code — this task only adds the test. If it fails,
the bug is in an earlier task's implementation; fix there, not here.

Run: `"$GODOT_BIN" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: PASS.

- [ ] **Step 4: Manual sanity check in the editor**

Per the spec's testing approach (§8), pure logic is GUT-tested but the
engineer should also confirm the project still opens cleanly in the
actual Godot editor before calling this plan done:

Run: `"$GODOT_BIN" --headless --path . --quit`
Expected: exits 0, no script parse errors reported for any file under
`scripts/`.

- [ ] **Step 5: Commit**

```bash
git add tests/unit/test_dwarf_vs_cave_rat_integration.gd
git commit -m "test: add Dwarf vs Cave Rat end-to-end integration test"
```

---

## Done criteria

All 12 tasks committed, full suite green:

```bash
"$GODOT_BIN" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

Next: Plan 2 — Run Structure & Playable Combat Scene (Godot scenes/UI,
map generation, a playable single-Act run using this engine).
