# Combat Scene (Plan 2A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a playable Godot combat scene, wired to Plan 1's pure-logic
combat engine, that can be opened and played standalone in the editor.

**Architecture:** Two small additions to Plan 1's engine/data layer
(`CombatEncounter` signals, authored display fields), then four
programmatic Control-derived UI classes (`ActorPanel`, `HandView`,
`IntentView`, `CombatScene`) built entirely in GDScript `_ready()` code
rather than hand-authored `.tscn` node trees — this project has no `.tscn`
files yet, and hand-transcribing Godot's scene resource format is far more
error-prone than building a Control tree in code, which is also fully
inspectable at runtime. A single trivial `.tscn` (`combat_demo.tscn`,
root `Control` + script, no children) is the only scene file this plan
creates — it exists only because Godot's `run/main_scene` project setting
requires an actual scene resource to launch.

**Tech Stack:** Godot 4.7, GDScript (strict typing), GUT 9.6.1 (vendored
at `addons/gut/`), headless CLI test runs.

**Spec:** `docs/superpowers/specs/2026-09-04-combat-scene-design.md`
(and its parent, `docs/superpowers/specs/2026-09-04-party-deckbuilder-design.md`)

## Global Constraints

- Godot 4.7, GDScript with strict typing (as established in Plan 1) —
  every `var`/function parameter/return gets an explicit type.
- No new `.tscn` files beyond `scripts/ui/combat/combat_demo.tscn`. All
  other UI structure is built in code (see Architecture above).
- No drag-and-drop, no card art, no sound, no animation/VFX — click-to-play
  only, instant state changes, text-only display.
- No new playable content — reuse Plan 1's `DwarfContent` /
  `CaveRatContent` exactly, only backfilling the two new display fields
  onto their existing resources.
- `CombatEncounter` only ever models one enemy — do not add multi-enemy
  support; that is out of scope for this plan.
- Every task's automated tests run via:
  `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
  from the repo root. If a newly added `class_name` isn't recognized,
  run `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless --editor --quit`
  once first to prime Godot's global class cache (a known, harmless,
  recurring quirk from Plan 1 — not a code defect).
- Commit after every task, following the existing repo's commit style
  (`feat: ...`, `test: ...`, `fix: ...`).

---

### Task 1: `CombatEncounter` signals

**Files:**
- Modify: `scripts/combat/combat_encounter.gd`
- Test: Create `tests/unit/test_combat_encounter_signals.gd`

**Interfaces:**
- Consumes: existing `CombatEncounter` public API (`_init`,
  `start_player_turn`, `can_play_card`, `play_card`, `end_player_turn`,
  `get_current_enemy_intent`, fields `is_over`, `player_won`) — unchanged.
- Produces: `signal state_changed` and `signal combat_ended(player_won: bool)`
  on `CombatEncounter`, consumed by Task 5 (`CombatScene`).

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_combat_encounter_signals.gd`:

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

func _make_attack_move(amount: int) -> EnemyMove:
	var move := EnemyMove.new()
	move.intent_type = EnemyMove.IntentType.ATTACK
	var effect := DamageEffect.new()
	effect.amount = amount
	move.effects = [effect]
	return move

func test_play_card_emits_state_changed():
	var player := _make_actor(20)
	var enemy := _make_actor(20)
	var deck: Array[CardResource] = [_make_strike(3)]
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(3)])
	watch_signals(encounter)
	encounter.start_player_turn()
	encounter.play_card(encounter.hand[0])
	assert_signal_emit_count(encounter, "state_changed", 1)

func test_end_player_turn_emits_state_changed_exactly_once():
	var player := _make_actor(20)
	var enemy := _make_actor(20)
	var deck: Array[CardResource] = [_make_strike(3)]
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(3)])
	encounter.start_player_turn()
	watch_signals(encounter)
	encounter.end_player_turn()
	assert_signal_emit_count(encounter, "state_changed", 1)

func test_combat_ended_emits_once_with_player_won_true():
	var player := _make_actor(20)
	var enemy := _make_actor(3)
	var deck: Array[CardResource] = [_make_strike(3)]
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(3)])
	watch_signals(encounter)
	encounter.start_player_turn()
	encounter.play_card(encounter.hand[0])
	assert_signal_emitted_with_parameters(encounter, "combat_ended", [true])
	assert_signal_emit_count(encounter, "combat_ended", 1)

func test_combat_ended_emits_once_with_player_won_false():
	var player := _make_actor(3)
	var enemy := _make_actor(20)
	var deck: Array[CardResource] = [_make_strike(0)]
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(5)])
	watch_signals(encounter)
	encounter.start_player_turn()
	encounter.end_player_turn()
	assert_signal_emitted_with_parameters(encounter, "combat_ended", [false])
	assert_signal_emit_count(encounter, "combat_ended", 1)

func test_combat_ended_never_fires_twice_across_multiple_calls():
	var player := _make_actor(20)
	var enemy := _make_actor(3)
	var deck: Array[CardResource] = [_make_strike(3)]
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(3)])
	watch_signals(encounter)
	encounter.start_player_turn()
	encounter.play_card(encounter.hand[0])
	assert_signal_emit_count(encounter, "combat_ended", 1)
	# Combat is already over. end_player_turn() has no is_over guard of
	# its own and always calls _check_combat_over() internally, so this
	# redundant call is exactly what would double-fire combat_ended if
	# _check_combat_over()'s own re-entry guard were missing or broken.
	encounter.end_player_turn()
	assert_signal_emit_count(encounter, "combat_ended", 1)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gselect=test_combat_encounter_signals -gexit`
Expected: FAIL — `state_changed` and `combat_ended` don't exist yet on `CombatEncounter`.

- [ ] **Step 3: Add the signals to `CombatEncounter`**

Edit `scripts/combat/combat_encounter.gd`. Add two signal declarations
right after the `class_name` line:

```gdscript
extends RefCounted
class_name CombatEncounter

signal state_changed
signal combat_ended(player_won: bool)

const MAX_HAND_SIZE := 5
```

Change `play_card` to emit `state_changed` after `_check_combat_over()`:

```gdscript
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
	state_changed.emit()
```

Change `end_player_turn` to emit `state_changed` as its last line:

```gdscript
func end_player_turn() -> void:
	discard_pile.append_array(hand)
	hand.clear()
	if not is_over:
		_run_enemy_turn()
	_check_combat_over()
	state_changed.emit()
```

Change `_check_combat_over` to guard against re-entry and emit
`combat_ended` exactly once:

```gdscript
func _check_combat_over() -> void:
	if is_over:
		return
	if enemy.current_hp <= 0:
		is_over = true
		player_won = true
	elif player.current_hp <= 0:
		is_over = true
		player_won = false
	if is_over:
		combat_ended.emit(player_won)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gselect=test_combat_encounter_signals -gexit`
Expected: PASS (5/5)

- [ ] **Step 5: Run the full suite to check for regressions**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: PASS, all tests including Plan 1's existing ones (the guard in
`_check_combat_over` and the new emits don't change any existing return
values or state transitions).

- [ ] **Step 6: Commit**

```bash
git add scripts/combat/combat_encounter.gd tests/unit/test_combat_encounter_signals.gd tests/unit/test_combat_encounter_signals.gd.uid
git commit -m "feat: add state_changed and combat_ended signals to CombatEncounter"
```

---

### Task 2: Authored display fields

**Files:**
- Modify: `scripts/resources/card_resource.gd`
- Modify: `scripts/resources/enemy_move.gd`
- Modify: `scripts/content/dwarf_content.gd`
- Modify: `scripts/content/cave_rat_content.gd`
- Test: Modify `tests/unit/test_data_resources.gd`
- Test: Modify `tests/unit/test_starter_content.gd`

**Interfaces:**
- Consumes: existing `CardResource`, `EnemyMove` resource classes.
- Produces: `CardResource.description: String`,
  `EnemyMove.description: String`, `EnemyMove.display_value: int` —
  consumed by Task 3 (`IntentView`) and Task 4 (`HandView`).

- [ ] **Step 1: Write the failing tests**

Add to `tests/unit/test_data_resources.gd` (new functions, keep the
existing ones untouched):

```gdscript
func test_card_resource_has_description_field():
	var card := CardResource.new()
	card.description = "Deal 6 damage."
	assert_eq(card.description, "Deal 6 damage.")

func test_enemy_move_has_description_and_display_value_fields():
	var move := EnemyMove.new()
	move.description = "Winds up a heavy bite."
	move.display_value = 5
	assert_eq(move.description, "Winds up a heavy bite.")
	assert_eq(move.display_value, 5)
```

Add to `tests/unit/test_starter_content.gd` (new functions, keep the
existing ones untouched):

```gdscript
func test_dwarf_cards_have_descriptions():
	var class_res := DwarfContent.get_class_resource()
	for card in class_res.starting_deck:
		assert_ne(card.description, "", "Card '%s' should have a non-empty description." % card.display_name)

func test_cave_rat_moves_have_descriptions_and_display_values():
	var enemy_res := CaveRatContent.get_enemy_resource()
	for move in enemy_res.moves:
		assert_ne(move.description, "", "A Cave Rat move should have a non-empty description.")
	# Bite is a plain attack; its display_value should show the damage number.
	var bite: EnemyMove = enemy_res.moves[0]
	assert_eq(bite.display_value, 5)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gselect=test_data_resources -gexit`
Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gselect=test_starter_content -gexit`
Expected: FAIL — `description`/`display_value` don't exist yet, and
starter content descriptions are empty.

- [ ] **Step 3: Add the fields**

Edit `scripts/resources/card_resource.gd`, add after the `effects` line:

```gdscript
@export var effects: Array[CardEffect] = []
@export var description: String = ""
```

Edit `scripts/resources/enemy_move.gd`, add after the `effects` line:

```gdscript
@export var effects: Array[CardEffect] = []
@export var description: String = ""
@export var display_value: int = 0
```

- [ ] **Step 4: Backfill starter content**

Edit `scripts/content/dwarf_content.gd`. In `_make_strike_card()`, add
after `card.effects = [effect]`:

```gdscript
	card.description = "Deal 6 damage."
```

In `_make_guard_card()`, add after `card.effects = [effect]`:

```gdscript
	card.description = "Gain 5 Block."
```

Edit `scripts/content/cave_rat_content.gd`. In `_make_bite_move()`, add
after `move.effects = [effect]`:

```gdscript
	move.description = "The Cave Rat lunges with its teeth."
	move.display_value = 5
```

In `_make_screech_move()`, add after `move.effects = [effect]`:

```gdscript
	move.description = "The Cave Rat lets out a piercing screech, weakening its foe."
```

(No `display_value` for Screech — it applies a status, not a number
worth badging; `display_value` stays at its default `0`.)

- [ ] **Step 5: Run tests to verify they pass**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: PASS, full suite.

- [ ] **Step 6: Commit**

```bash
git add scripts/resources/card_resource.gd scripts/resources/enemy_move.gd scripts/content/dwarf_content.gd scripts/content/cave_rat_content.gd tests/unit/test_data_resources.gd tests/unit/test_starter_content.gd
git commit -m "feat: add authored description/display_value fields to card and enemy move data"
```

---

### Task 3: `ActorPanel` and `IntentView`

**Files:**
- Create: `scripts/ui/combat/actor_panel.gd`
- Create: `scripts/ui/combat/intent_view.gd`
- Test: Create `tests/unit/test_actor_panel.gd`
- Test: Create `tests/unit/test_intent_view.gd`

**Interfaces:**
- Consumes: `CombatActor` (fields `display_name`, `current_hp`, `max_hp`,
  `block`), `EnemyMove` (fields `intent_type`, `display_value`,
  `description`, enum `IntentType`).
- Produces: `class_name ActorPanel` with `func display(actor: CombatActor) -> void`
  and fields `name_label: Label`, `hp_label: Label`, `block_label: Label`.
  `class_name IntentView` with `func display(move: EnemyMove) -> void`
  and field `label: Label`. Both consumed by Task 5 (`CombatScene`).

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_actor_panel.gd`:

```gdscript
extends GutTest

func test_display_shows_name_hp_and_block():
	var panel := ActorPanel.new()
	add_child_autofree(panel)
	var actor := CombatActor.new("Dwarf", 30)
	actor.block = 5
	actor.take_damage(4)
	panel.display(actor)
	assert_eq(panel.name_label.text, "Dwarf")
	assert_eq(panel.hp_label.text, "HP: 30 / 30")
	assert_eq(panel.block_label.text, "Block: 1")
```

Create `tests/unit/test_intent_view.gd`:

```gdscript
extends GutTest

func test_display_shows_intent_type_and_value_when_positive():
	var view := IntentView.new()
	add_child_autofree(view)
	var move := EnemyMove.new()
	move.intent_type = EnemyMove.IntentType.ATTACK
	move.display_value = 5
	move.description = "The Cave Rat lunges with its teeth."
	view.display(move)
	assert_eq(view.label.text, "ATTACK 5")
	assert_eq(view.label.tooltip_text, "The Cave Rat lunges with its teeth.")

func test_display_shows_only_intent_type_when_value_is_zero():
	var view := IntentView.new()
	add_child_autofree(view)
	var move := EnemyMove.new()
	move.intent_type = EnemyMove.IntentType.DEBUFF
	move.display_value = 0
	view.display(move)
	assert_eq(view.label.text, "DEBUFF")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gselect=test_actor_panel -gexit`
Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gselect=test_intent_view -gexit`
Expected: FAIL — `ActorPanel`/`IntentView` classes don't exist yet.

- [ ] **Step 3: Write `ActorPanel`**

Create `scripts/ui/combat/actor_panel.gd`:

```gdscript
extends PanelContainer
class_name ActorPanel

var name_label: Label
var hp_label: Label
var block_label: Label

func _ready() -> void:
	var vbox := VBoxContainer.new()
	add_child(vbox)
	name_label = Label.new()
	hp_label = Label.new()
	block_label = Label.new()
	vbox.add_child(name_label)
	vbox.add_child(hp_label)
	vbox.add_child(block_label)

func display(actor: CombatActor) -> void:
	name_label.text = actor.display_name
	hp_label.text = "HP: %d / %d" % [actor.current_hp, actor.max_hp]
	block_label.text = "Block: %d" % actor.block
```

- [ ] **Step 4: Write `IntentView`**

Create `scripts/ui/combat/intent_view.gd`:

```gdscript
extends HBoxContainer
class_name IntentView

var label: Label

func _ready() -> void:
	label = Label.new()
	add_child(label)

func display(move: EnemyMove) -> void:
	var intent_name := EnemyMove.IntentType.keys()[move.intent_type]
	if move.display_value > 0:
		label.text = "%s %d" % [intent_name, move.display_value]
	else:
		label.text = intent_name
	label.tooltip_text = move.description
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: PASS, full suite. (If `ActorPanel`/`IntentView` aren't found,
run `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless --editor --quit`
once to prime the class cache, then re-run.)

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/combat/actor_panel.gd scripts/ui/combat/intent_view.gd tests/unit/test_actor_panel.gd tests/unit/test_intent_view.gd
git commit -m "feat: add ActorPanel and IntentView combat UI components"
```

---

### Task 4: `HandView`

**Files:**
- Create: `scripts/ui/combat/hand_view.gd`
- Test: Create `tests/unit/test_hand_view.gd`

**Interfaces:**
- Consumes: `CardResource` (fields `display_name`, `cost`, `description`).
- Produces: `class_name HandView` extending `HBoxContainer`, with
  `func display(hand: Array[CardResource], energy: int) -> void`,
  `signal card_clicked(card: CardResource)`, and
  `func is_card_button_disabled(index: int) -> bool`. Consumed by
  Task 5 (`CombatScene`).

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_hand_view.gd`:

```gdscript
extends GutTest

func _make_card(display_name: String, cost: int) -> CardResource:
	var card := CardResource.new()
	card.display_name = display_name
	card.cost = cost
	card.description = "Test description."
	return card

func test_display_creates_one_button_per_card():
	var hand_view := HandView.new()
	add_child_autofree(hand_view)
	var hand: Array[CardResource] = [_make_card("Strike", 1), _make_card("Guard", 1)]
	hand_view.display(hand, 3)
	assert_eq(hand_view.get_child_count(), 2)

func test_display_disables_cards_that_cost_more_than_current_energy():
	var hand_view := HandView.new()
	add_child_autofree(hand_view)
	var hand: Array[CardResource] = [_make_card("Cheap", 1), _make_card("Expensive", 3)]
	hand_view.display(hand, 1)
	assert_false(hand_view.is_card_button_disabled(0), "Cost 1 with 1 energy should be playable.")
	assert_true(hand_view.is_card_button_disabled(1), "Cost 3 with 1 energy should be disabled.")

func test_clicking_a_card_button_emits_card_clicked():
	var hand_view := HandView.new()
	add_child_autofree(hand_view)
	var card := _make_card("Strike", 1)
	var hand: Array[CardResource] = [card]
	hand_view.display(hand, 3)
	watch_signals(hand_view)
	var button: Button = hand_view.get_child(0)
	button.pressed.emit()
	assert_signal_emitted_with_parameters(hand_view, "card_clicked", [card])
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gselect=test_hand_view -gexit`
Expected: FAIL — `HandView` doesn't exist yet.

- [ ] **Step 3: Write `HandView`**

Create `scripts/ui/combat/hand_view.gd`:

```gdscript
extends HBoxContainer
class_name HandView

signal card_clicked(card: CardResource)

func display(hand: Array[CardResource], energy: int) -> void:
	for child in get_children():
		child.queue_free()
	for card in hand:
		var button := Button.new()
		button.text = "%s (%d)\n%s" % [card.display_name, card.cost, card.description]
		button.disabled = card.cost > energy
		button.pressed.connect(_on_card_button_pressed.bind(card))
		add_child(button)

func is_card_button_disabled(index: int) -> bool:
	return get_child(index).disabled

func _on_card_button_pressed(card: CardResource) -> void:
	card_clicked.emit(card)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: PASS, full suite.

Note: `display()` uses `queue_free()` to clear old buttons, which does
not remove them from `get_children()` until the next idle frame. Because
GUT tests call `display()` once per test (no re-display within the same
frame), this doesn't affect `get_child_count()` assertions above — but
be aware a test that calls `display()` twice in a row and immediately
asserts on child count would need `await get_tree().process_frame`
between the two calls. None of the tests in this task do that.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/combat/hand_view.gd tests/unit/test_hand_view.gd
git commit -m "feat: add HandView combat UI component"
```

---

### Task 5: `CombatScene` controller

**Files:**
- Create: `scripts/ui/combat/combat_scene.gd`
- Test: Create `tests/unit/test_combat_scene.gd`

**Interfaces:**
- Consumes: `CombatEncounter` (Task 1 signals plus its existing public
  API), `ActorPanel`/`IntentView` (Task 3), `HandView` (Task 4).
- Produces: `class_name CombatScene` extending `Control`, with
  `func start(p_encounter: CombatEncounter) -> void` and
  `signal play_again_requested`. Fields `player_panel: ActorPanel`,
  `enemy_panel: ActorPanel`, `hand_view: HandView`,
  `intent_view: IntentView`, `energy_label: Label`,
  `end_turn_button: Button`, `result_label: Label`,
  `play_again_button: Button`, `turn_ui_container: Control`,
  `result_container: Control`. Consumed by Task 6 (`CombatDemo`).

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_combat_scene.gd`:

```gdscript
extends GutTest

func _make_actor(hp: int) -> CombatActor:
	return CombatActor.new("Test", hp)

func _make_strike(amount: int) -> CardResource:
	var card := CardResource.new()
	card.display_name = "Strike"
	card.cost = 1
	card.description = "Deal damage."
	var effect := DamageEffect.new()
	effect.amount = amount
	card.effects = [effect]
	return card

func _make_attack_move(amount: int) -> EnemyMove:
	var move := EnemyMove.new()
	move.intent_type = EnemyMove.IntentType.ATTACK
	move.display_value = amount
	move.description = "It attacks."
	var effect := DamageEffect.new()
	effect.amount = amount
	move.effects = [effect]
	return move

func test_start_shows_turn_ui_and_hides_result():
	var scene := CombatScene.new()
	add_child_autofree(scene)
	var player := _make_actor(20)
	var enemy := _make_actor(20)
	var deck: Array[CardResource] = [_make_strike(3)]
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(3)])
	scene.start(encounter)
	assert_true(scene.turn_ui_container.visible)
	assert_false(scene.result_container.visible)
	assert_eq(scene.player_panel.hp_label.text, "HP: 20 / 20")

func test_playing_a_card_updates_the_view():
	var scene := CombatScene.new()
	add_child_autofree(scene)
	var player := _make_actor(20)
	var enemy := _make_actor(20)
	var deck: Array[CardResource] = [_make_strike(3)]
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(3)])
	scene.start(encounter)
	var card := encounter.hand[0]
	scene._on_hand_card_clicked(card)
	assert_eq(scene.enemy_panel.hp_label.text, "HP: 17 / 20")

func test_combat_ended_shows_result_overlay_with_win_message():
	var scene := CombatScene.new()
	add_child_autofree(scene)
	var player := _make_actor(20)
	var enemy := _make_actor(3)
	var deck: Array[CardResource] = [_make_strike(3)]
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(3)])
	scene.start(encounter)
	scene._on_hand_card_clicked(encounter.hand[0])
	assert_false(scene.turn_ui_container.visible)
	assert_true(scene.result_container.visible)
	assert_eq(scene.result_label.text, "You Won")

func test_play_again_button_emits_play_again_requested():
	var scene := CombatScene.new()
	add_child_autofree(scene)
	watch_signals(scene)
	scene._on_play_again_pressed()
	assert_signal_emitted(scene, "play_again_requested")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gselect=test_combat_scene -gexit`
Expected: FAIL — `CombatScene` doesn't exist yet.

- [ ] **Step 3: Write `CombatScene`**

Create `scripts/ui/combat/combat_scene.gd`:

```gdscript
extends Control
class_name CombatScene

signal play_again_requested

var encounter: CombatEncounter

var player_panel: ActorPanel
var enemy_panel: ActorPanel
var hand_view: HandView
var intent_view: IntentView
var energy_label: Label
var end_turn_button: Button
var result_label: Label
var play_again_button: Button
var turn_ui_container: Control
var result_container: Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var root_vbox := VBoxContainer.new()
	add_child(root_vbox)
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)

	turn_ui_container = VBoxContainer.new()
	root_vbox.add_child(turn_ui_container)

	var actors_hbox := HBoxContainer.new()
	turn_ui_container.add_child(actors_hbox)
	player_panel = ActorPanel.new()
	enemy_panel = ActorPanel.new()
	actors_hbox.add_child(player_panel)
	actors_hbox.add_child(enemy_panel)

	intent_view = IntentView.new()
	turn_ui_container.add_child(intent_view)

	hand_view = HandView.new()
	hand_view.card_clicked.connect(_on_hand_card_clicked)
	turn_ui_container.add_child(hand_view)

	var bottom_hbox := HBoxContainer.new()
	turn_ui_container.add_child(bottom_hbox)
	energy_label = Label.new()
	bottom_hbox.add_child(energy_label)
	end_turn_button = Button.new()
	end_turn_button.text = "End Turn"
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	bottom_hbox.add_child(end_turn_button)

	result_container = VBoxContainer.new()
	root_vbox.add_child(result_container)
	result_container.hide()
	result_label = Label.new()
	result_container.add_child(result_label)
	play_again_button = Button.new()
	play_again_button.text = "Play Again"
	play_again_button.pressed.connect(_on_play_again_pressed)
	result_container.add_child(play_again_button)

func start(p_encounter: CombatEncounter) -> void:
	encounter = p_encounter
	encounter.state_changed.connect(_refresh)
	encounter.combat_ended.connect(_on_combat_ended)
	result_container.hide()
	turn_ui_container.show()
	encounter.start_player_turn()
	_refresh()

func _refresh() -> void:
	player_panel.display(encounter.player)
	enemy_panel.display(encounter.enemy)
	hand_view.display(encounter.hand, encounter.energy)
	var intent := encounter.get_current_enemy_intent()
	if intent != null:
		intent_view.display(intent)
	energy_label.text = "Energy: %d / %d" % [encounter.energy, CombatEncounter.MAX_ENERGY]

func _on_hand_card_clicked(card: CardResource) -> void:
	if encounter.can_play_card(card):
		encounter.play_card(card)

func _on_end_turn_pressed() -> void:
	encounter.end_player_turn()
	if not encounter.is_over:
		encounter.start_player_turn()
		_refresh()

func _on_combat_ended(player_won: bool) -> void:
	turn_ui_container.hide()
	result_container.show()
	result_label.text = "You Won" if player_won else "You Lost"

func _on_play_again_pressed() -> void:
	play_again_requested.emit()
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: PASS, full suite.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/combat/combat_scene.gd tests/unit/test_combat_scene.gd
git commit -m "feat: add CombatScene controller wiring engine to combat UI components"
```

---

### Task 6: `CombatDemo` bootstrap and manual playtest

**Files:**
- Create: `scripts/ui/combat/combat_demo.gd`
- Create: `scripts/ui/combat/combat_demo.tscn`
- Modify: `project.godot`

**Interfaces:**
- Consumes: `DwarfContent.get_class_resource()`,
  `CaveRatContent.get_enemy_resource()`, `PersistentStats`,
  `ActorFactory.build_player_actor` / `build_enemy_actor`,
  `CombatEncounter`, `CombatScene.start()` and
  `CombatScene.play_again_requested` (Task 5).
- Produces: the project's main scene — nothing downstream in this plan
  consumes it further; Plan 2B replaces it.

- [ ] **Step 1: Write `CombatDemo`**

Create `scripts/ui/combat/combat_demo.gd`:

```gdscript
extends Control
class_name CombatDemo

var combat_scene: CombatScene

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_start_new_fight()

func _start_new_fight() -> void:
	if combat_scene != null:
		combat_scene.queue_free()

	var class_res := DwarfContent.get_class_resource()
	var stats := PersistentStats.new()
	var player := ActorFactory.build_player_actor(class_res, stats)

	var enemy_res := CaveRatContent.get_enemy_resource()
	var enemy := ActorFactory.build_enemy_actor(enemy_res)

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var encounter := CombatEncounter.new(player, class_res.starting_deck, enemy, enemy_res.moves, rng)

	combat_scene = CombatScene.new()
	combat_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(combat_scene)
	combat_scene.play_again_requested.connect(_start_new_fight)
	combat_scene.start(encounter)
```

- [ ] **Step 2: Create the bootstrap scene file**

Create `scripts/ui/combat/combat_demo.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/combat/combat_demo.gd" id="1"]

[node name="CombatDemo" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")
```

- [ ] **Step 3: Set it as the project's main scene**

Edit `project.godot`. Under the `[application]` section, add a
`run/main_scene` line:

```
[application]

config/name="Party Deckbuilder"
config/features=PackedStringArray("4.7", "Forward Plus")
run/main_scene="res://scripts/ui/combat/combat_demo.tscn"
```

- [ ] **Step 4: Run the full automated suite**

Run: `"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit -gexit`
Expected: PASS, full suite (this task adds no new automated tests — the
bootstrap and main-scene wiring can only be meaningfully verified by
actually playing the game, next).

- [ ] **Step 5: Manually verify by playing the game**

This step cannot be skipped or replaced by "the tests pass" — the spec
requires actually playing it. Open the project in the Godot 4.7 editor
(`"C:/Tools/Godot/Godot_v4.7-stable_win64.exe" --editor --path .`) and
press Play (F5, or the equivalent play-current-scene if prompted to pick
one — choose `combat_demo.tscn` if asked, or rely on the main scene you
just set). Confirm all of the following in one sitting:

- The Dwarf's HP, the Cave Rat's HP, and both actors' Block values are
  visible and correct at fight start (Dwarf 30/30, Cave Rat 18/18, both
  Block 0).
- The enemy's intent (Bite: "ATTACK 5", or Screech: "DEBUFF") is shown
  before you act each turn.
- Clicking a Strike card reduces the Cave Rat's HP by the expected
  amount and moves energy down by 1; clicking Guard raises the Dwarf's
  Block instead of damaging the enemy.
- A card whose cost exceeds remaining energy is visibly disabled and
  does not respond to clicks.
- Clicking "End Turn" resolves the Cave Rat's telegraphed move against
  the Dwarf, then a new player turn begins with hand/energy refreshed.
- Play at least one fight through to a win (result screen reads "You
  Won") and, separately, deplete the Dwarf's HP to reach a loss (result
  screen reads "You Lost") — restarting via "Play Again" between
  attempts if needed.
- "Play Again" starts a fresh fight with both actors back at full HP.

If anything above doesn't hold, fix it before proceeding — this is the
plan's actual acceptance bar, not the automated suite alone.

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/combat/combat_demo.gd scripts/ui/combat/combat_demo.tscn project.godot
git commit -m "feat: add standalone CombatDemo bootstrap and set it as the main scene"
```
