# Design: Combat Scene (Plan 2A)

**Date:** 2026-09-04
**Status:** Approved, pending implementation plan
**Parent spec:** `docs/superpowers/specs/2026-09-04-party-deckbuilder-design.md`
**Builds on:** Plan 1 (core combat engine), merged to master at `44a167e`

## Summary

The first playable slice of the Fantasy Party Deckbuilder: a Godot UI
layer wired directly to Plan 1's pure-logic combat engine
(`CombatEncounter`, `CombatActor`, `CardResource`, `EnemyMove`,
`ActorFactory`, `PersistentStats`), playable standalone via a bootstrap
demo scene. This is sub-project 2A of Plan 2 (Run Structure & Playable
Combat Scene) from the parent spec — Plan 2B (map generation, `RunState`,
Event/Rest/Shop/Victory/GameOver scenes) follows separately and replaces
this plan's hardcoded bootstrap with real run/map wiring.

## 1. Scope

**In scope:**

- A playable single combat between one player `CombatActor` and one
  enemy `CombatActor`, using the existing turn engine unchanged.
- Click-to-play card interaction (no drag-and-drop).
- A standalone bootstrap scene so this can be opened and played directly
  in the Godot editor, independent of any map/run system.
- Two small, targeted additions to Plan 1's engine/data layer (below) —
  no other behavior changes to `CombatEncounter`, `CombatActor`, or the
  effect-resolution system.

**Explicitly out of scope (deferred):**

- Map generation, node graph, `RunState`, Event/Rest/Shop scenes,
  Victory/GameOver scenes — all Plan 2B.
- Multiple enemies in one encounter — `CombatEncounter` only models one
  `enemy: CombatActor` today; supporting more is an engine change, not a
  UI change, and is out of scope here.
- Drag-and-drop card interaction, hand-reorder, card art, sound,
  animation/VFX beyond instant state changes — first playable pass only.
- New card/enemy content — this plan backfills two new authored fields
  (`description`, `display_value`) onto Plan 1's existing Dwarf/Cave Rat
  resources; it does not add new classes, cards, or enemies.
- Phase 2 classes, relics, potions, gold — not introduced yet anywhere in
  Plan 2.

## 2. Engine additions

Two small additions to Plan 1's code, otherwise unchanged:

- **`CombatEncounter` signals:**
  - `signal state_changed` — emitted once at the end of `play_card()`
    and once at the end of `end_player_turn()` (which itself runs the
    enemy turn synchronously before returning, so a single
    `end_player_turn()` call still yields exactly one emission). Views
    redraw fully from current state on every emission; there is no
    per-field diffing and no animation choreography in this pass.
  - `signal combat_ended(player_won: bool)` — emitted exactly once, the
    moment `_check_combat_over()` first flips `is_over` from `false` to
    `true`. Never emitted again afterward even if other methods are
    called post-combat.
- **Authored display fields (hand-written, not derived from effect
  resources):**
  - `CardResource.description: String` (`@export`, default `""`) — e.g.
    `"Deal 6 damage."`
  - `EnemyMove.description: String` (`@export`, default `""`) — e.g.
    `"Winds up a heavy bite."`
  - `EnemyMove.display_value: int` (`@export`, default `0`) — the number
    shown on the intent icon badge, e.g. `6`.

Rationale for hand-authored over introspected: `CardResource.cost` is
already hand-authored, and with only 3 effect types today, a generic
"sum the DamageEffect amounts" reflection scheme would be more fragile
than just writing the number down, for no present benefit.

Plan 1's existing `scripts/content/dwarf_content.gd` and
`cave_rat_content.gd` get their `description`/`display_value` fields
filled in as part of this plan — no new content files.

## 3. Components

All new files live under `scripts/ui/combat/` (scripts) with matching
`.tscn` scenes alongside them.

- **`ActorPanel`** (`actor_panel.gd` / `ActorPanel.tscn`) — displays one
  `CombatActor`: name, HP (current/max), block. Instanced twice (player,
  enemy). Public API: `func display(actor: CombatActor) -> void`.
- **`HandView`** (`hand_view.gd` / `HandView.tscn`) — an
  `HBoxContainer` of per-card buttons built from `Array[CardResource]`.
  Each button shows name, cost, and `description`; disabled when
  `card.cost` exceeds current energy. Emits
  `signal card_clicked(card: CardResource)`. Public API:
  `func display(hand: Array[CardResource], energy: int) -> void`.
- **`IntentView`** (`intent_view.gd` / small scene) — icon keyed off
  `EnemyMove.IntentType`, the `display_value` number, and
  `description` as a tooltip. Public API:
  `func display(move: EnemyMove) -> void`.
- **`CombatScene`** (`combat_scene.gd` / `CombatScene.tscn`) — owns a
  `CombatEncounter` instance passed in at construction. Instances the
  three views above plus an Energy label and an "End Turn" button.
  Wires `HandView.card_clicked → CombatEncounter.play_card`, End Turn
  button → `CombatEncounter.end_player_turn`, and both
  `CombatEncounter.state_changed` / `combat_ended` into a single
  `_refresh()` that re-`display()`s every view. On `combat_ended`,
  replaces the turn UI with a plain result `Label` ("You Won" / "You
  Lost") and a "Play Again" button. Public API:
  `func start(encounter: CombatEncounter) -> void`.
- **`CombatDemo`** (`combat_demo.gd` / `CombatDemo.tscn`) — standalone
  bootstrap. Builds a Dwarf `CombatActor` via
  `ActorFactory.build_player_actor` with a zeroed `PersistentStats`, a
  Cave Rat `CombatActor` via `ActorFactory.build_enemy_actor`,
  constructs a `CombatEncounter` with those actors, the Dwarf's
  `starting_deck`, and the Cave Rat's `moves`, then instances
  `CombatScene` and calls `start()` on it. Set as the project's main
  scene (`run/main_scene` in `project.godot`) so opening the project and
  pressing Play launches straight into a playable fight. "Play Again"
  reconstructs a fresh `CombatEncounter` the same way and calls `start()`
  again.

## 4. Turn flow

1. `CombatDemo` builds actors/deck/encounter, instances `CombatScene`,
   calls `start(encounter)`. `CombatScene` calls
   `encounter.start_player_turn()` and does an initial `_refresh()`.
2. Player clicks an affordable card in `HandView` → `card_clicked` →
   `CombatScene` calls `encounter.play_card(card)` → engine resolves the
   effect against the single enemy (or self) → `state_changed` fires →
   `_refresh()` redraws HP/block/hand/energy.
3. Player clicks "End Turn" → `encounter.end_player_turn()` → engine
   discards the hand and runs the enemy turn synchronously (no delay;
   matches how the Plan 1 engine already resolves turns) → `state_changed`
   (and `combat_ended`, if the fight just ended) fires → `_refresh()`.
4. If `combat_ended` fired, `CombatScene` shows the result overlay
   instead of starting a new turn. Otherwise it calls
   `encounter.start_player_turn()` again and continues from step 2.
5. "Play Again" on the result overlay tells `CombatDemo` to rebuild a
   fresh encounter and call `start()` again — no process restart needed.

## 5. Testing

- **GUT unit tests** (pure logic, following Plan 1's existing test
  patterns in `tests/unit/`):
  - `CombatEncounter.state_changed` fires on `play_card`,
    `end_player_turn`, and after the enemy turn resolves.
  - `CombatEncounter.combat_ended` fires exactly once, with the correct
    `player_won` value, and never fires again on subsequent calls after
    combat is already over.
  - `HandView` correctly disables a card whose cost exceeds the current
    energy and enables it otherwise (test the disabling logic directly;
    it does not require a running scene tree beyond instancing the
    control).
- **Manual verification**, per the parent spec's testing section: open
  `CombatDemo.tscn` in the Godot editor and play at least one full fight
  to both a win and a loss, confirming cards play correctly, the enemy
  intent telegraphs and then resolves as shown, energy/block/HP track
  correctly, and the result overlay + "Play Again" work. Automated tests
  passing is not sufficient on its own to call this plan done.

## Open items for later (explicitly out of scope now)

- Plan 2B: map generation, `RunState`, Event/Rest/Shop/Victory/GameOver
  scenes, and replacing `CombatDemo`'s hardcoded bootstrap with real
  run/map wiring.
- Multiple enemies per encounter (engine change).
- Drag-and-drop card interaction, animation/VFX, card art, sound.
- New playable content (classes, cards, enemies) beyond Plan 1's
  Dwarf/Cave Rat.
