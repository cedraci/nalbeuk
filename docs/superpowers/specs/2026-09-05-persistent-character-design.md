# Design: Persistent Character & Camp (Plan 3A)

**Date:** 2026-09-05
**Status:** Approved, pending implementation plan
**Parent spec:** `docs/superpowers/specs/2026-09-04-party-deckbuilder-design.md`
**Builds on:** Plans 2A–2D, all merged to master at `407c5ef`.

## Summary

The first sub-project of Plan 3 (Meta-progression). The player's character
now outlives a run: level, XP, skill points, unlocked skill nodes, and
equipment persist across runs and across game sessions via a save file.
A run still resets its deck, gold, relics, potions, HP, and map. Death
punishes: all equipment is lost and half the current-level XP progress
is gone — but skills and levels are never lost. A minimal Camp screen
sits between runs.

**This supersedes the parent spec's §5 model** ("runs fully reset, only
Renown persists, spent on a talent tree"). The direction given on
2026-09-05 is that the player keeps equipment, skills, and experience
levels across runs, with the in-run skill tree from Plan 2C serving as
the persistent talent tree. Renown as a
separate currency is dropped; `PersistentStats` remains a zeroed
placeholder and is not touched by this plan.

**Plan 3B (next cycle, own spec):** snapshotting the in-progress run
(map, position, deck, HP, gold, relics, potions, RNG state) so quitting
mid-run resumes exactly. Until 3B lands, quitting mid-run abandons the
run with no death penalty; anything already written through (see §3)
is kept.

## 1. Scope

**In scope:**

- **`MetaState` autoload** — the committed persistent record (ids and
  integers only).
- **`SaveManager` autoload** — JSON save/load of `MetaState` to
  `user://save.json`, with safe handling of missing, corrupt, or
  out-of-date files.
- **`RunState` seeding and commit rules** — `start_new_run()` and a new
  `enter_camp()` seed `RunState` from `MetaState`; never-lost state
  writes through immediately; at-risk state commits at run end via a
  new `finish_run(victory) -> RunOutcome`.
- **Death and victory rules** exactly as stated in §3.
- **`CampScene`** — a minimal between-run hub reusing the existing
  `SkillTreeScene` and `InventoryScene`.
- **`RunScene` flow change** — boots to Camp instead of auto-starting a
  run; Victory/Game Over return to Camp and show what was kept or lost.
- **Test isolation base class** so write-through never leaks between
  tests or into the real save file.

**Explicitly out of scope (deferred):**

- Mid-run snapshot/resume (Plan 3B).
- Story beats, Camp dialogue, banter reacting to the last run — one
  static flavor line is the hook; copy comes once the loop is proven.
- Multiple save slots, cloud sync, save migration beyond "wrong version
  → fresh character".
- Persistent deck, persistent relics, persistent gold, class unlocks,
  difficulty scaling, an Ascension ladder.
- Any change to combat, map generation, content, or `PersistentStats`.

## 2. Data model

### 2.1 `MetaState` (autoload, `scripts/meta/meta_state.gd`)

Registered in `project.godot` as `MetaState`, listed **before**
`SaveManager` and `RunState`. No `class_name` (same rule as `RunState`).

```
var class_id: StringName = &"dwarf"
var level: int = 1
var xp: int = 0
var skill_points: int = 0
var unlocked_skill_nodes: Array[StringName] = []
var owned_equipment_ids: Array[StringName] = []   # duplicates allowed
var equipped_weapon_id: StringName = &""          # &"" = empty slot
var equipped_armor_id: StringName = &""
var equipped_trinket_id: StringName = &""

func reset() -> void
func to_dict() -> Dictionary
func from_dict(data: Dictionary) -> void
```

- No derived values are stored (max HP, strength/block bonuses): they are
  recomputed from `unlocked_skill_nodes` on load (§3.1).
- `owned_equipment_ids` allows duplicates: owning two Rusty Shortswords is
  two entries, mirroring `RunState.owned_equipment` holding two instances.
- An equipped id must also appear in `owned_equipment_ids`; `from_dict`
  clears any equipped slot whose id is not owned (with a warning).
- `from_dict` skips unknown skill-node or equipment ids with a warning
  (content may be removed later); it never throws.

### 2.2 Save file format (`SaveManager`, `scripts/meta/save_manager.gd`)

Autoload `SaveManager`. JSON via `FileAccess` + `JSON`, human-readable:

```json
{
  "version": 1,
  "meta": {
    "class_id": "dwarf",
    "level": 3, "xp": 12, "skill_points": 0,
    "unlocked_skill_nodes": ["dwarven_grit", "sharpened_pick"],
    "owned_equipment_ids": ["rusty_shortsword", "leather_vest"],
    "equipped_weapon_id": "rusty_shortsword",
    "equipped_armor_id": "",
    "equipped_trinket_id": ""
  }
}
```

```
const SAVE_VERSION := 1
const DEFAULT_SAVE_PATH := "user://save.json"
var save_path: String = DEFAULT_SAVE_PATH   # overridable for tests

func save_meta() -> bool        # false + push_warning on I/O failure; game continues
func load_meta() -> bool        # true only when a valid save was applied
func delete_save() -> void
```

`load_meta()` behaviour:

| File state | Result |
|---|---|
| Missing | `MetaState.reset()`, return `false` (fresh character, no warning) |
| Parses, `version == 1`, `meta` is a Dictionary | `MetaState.from_dict(meta)`, return `true` |
| Unparseable / not a Dictionary / missing or wrong `version` | rename file to `<save_path>.bad` (overwriting a previous `.bad`), `MetaState.reset()`, `push_warning`, return `false` |

A corrupt file is never silently overwritten — the rename preserves it
for inspection.

## 3. `RunState` seeding and commit rules

`RunState` keeps every existing field; scenes and existing tests keep
reading it unchanged. It becomes the **working copy**; `MetaState` is the
**committed record**.

### 3.1 Seeding from `MetaState`

New `in_run: bool = false`.

New `load_character_from_meta()`:
- `level`, `xp`, `skill_points`, `unlocked_skill_nodes` copied from
  `MetaState`.
- `owned_equipment` rehydrated from ids via a new
  `DwarfEquipment.get_by_id(id) -> EquipmentResource` (fresh instance per
  id, `null` for unknown). Each equipped slot is set to the first owned
  instance whose id matches; unmatched → slot stays `null`.
- Derived values recomputed via a new
  `DwarfSkillTree.get_node_by_id(id) -> SkillNode`:
  `level_bonus_strength = Σ strength_delta`, `level_bonus_block = Σ
  block_delta`, `player_max_hp = class_resource.base_hp + 2 · Σ
  vitality_delta` over unlocked nodes. `player_current_hp = player_max_hp`.

`start_new_run(class_resource)` calls `load_character_from_meta()`
instead of zeroing those fields, then resets what still resets: `deck`
(class starting deck), `gold = 0`, relics (ids and the three relic
bonuses), `potions`, `rng`, `map`, `current_floor`, `current_node`; sets
`in_run = true`.

New `enter_camp(class_resource)`: `load_character_from_meta()`, `map =
null`, `current_node = null`, `in_run = false`. (`deck`, `gold`, relics,
and potions are also reset so a stale run cannot bleed into Camp.)

`build_encounter_for_node` is unchanged — it already composes
`level_bonus_*`, relic bonuses, equipment, and passives.

### 3.2 Write-through: never-lost state

After mutating, these call `_commit_never_lost()` (copies `level`, `xp`,
`skill_points`, `unlocked_skill_nodes` into `MetaState`) then
`SaveManager.save_meta()`:

- `grant_xp` (also when it levels up)
- `unlock_skill_node` (only on success)
- `apply_event_choice` (through its `grant_xp` call)

`equip_item` / `unequip_slot` / `grant_equipment` / `buy_equipment` call
`_commit_equipment()` + save **only when `not in_run`** (i.e. at Camp).
Inside a run, gear is at risk and is committed by `finish_run`.

### 3.3 Run end: `finish_run(victory: bool) -> RunOutcome`

`RunOutcome` (`scripts/run/run_outcome.gd`, `RefCounted`): `victory:
bool`, `gear_lost: int`, `xp_lost: int`.

- **Victory:** `_commit_equipment()` (owned ids + equipped ids). `gear_lost
  = 0`, `xp_lost = 0`.
- **Death:** `gear_lost = owned_equipment.size()`; `owned_equipment = []`,
  all three equipped slots `null`; `xp_lost = xp - xp / 2`; `xp = xp / 2`
  (integer division; e.g. 15 → 7). `level`, `skill_points`, and
  `unlocked_skill_nodes` are untouched. Then `_commit_equipment()` and
  `_commit_never_lost()`.
- Both: `in_run = false`, `SaveManager.save_meta()`, return the outcome.

`RunScene` calls `finish_run` exactly once per run end, before the result
scene is built; a call while `not in_run` is a no-op (§5).

## 4. Scenes & orchestration

### 4.1 `CampScene` (`scripts/ui/camp/camp_scene.gd`)

`extends Control`, `class_name CampScene`. Built in code like every other
scene. Signals: `skill_tree_requested`, `inventory_requested`,
`run_requested`. Public nodes: `status_label`, `gear_label`,
`flavor_label`, `skill_tree_button`, `inventory_button`, `start_run_button`.

- `status_label`: `"Lv %d   XP: %d/%d   Skill Points: %d"` (`"Lv %d
  (MAX) ..."` at cap — same rule as `SkillTreeScene._status_text()`).
- `gear_label`: `"Weapon: X   Armor: Y   Trinket: Z"` with `"— empty —"`
  for empty slots.
- `flavor_label`: `const FLAVOR_LINE := "The party argues over who lost
  the map."` — the single story hook this plan ships.
- `refresh()` rebuilds the two labels from `RunState` (which mirrors
  `MetaState` at Camp).

### 4.2 `RunScene` flow

- `_ready()`: `SaveManager.load_meta()` → `RunState.enter_camp(DwarfContent
  .get_class_resource())` → `_show_camp()`. No run starts automatically.
- `_show_camp()`: builds a `CampScene`, connects its three signals, swaps
  to it (same `_swap_to` mechanics; `camp_scene` becomes a field like the
  other scenes).
- Skill Tree / Inventory requested from Camp or Map: same handlers as
  today. Their `back_requested` now routes through `_show_home()`, which
  is `_show_map()` when `RunState.in_run` and `_show_camp()` otherwise.
- `run_requested` from Camp: `RunState.start_new_run(...)` → `_show_map()`.
- Boss win: after the existing reward/grant lines, `var outcome :=
  RunState.finish_run(true)` → `_show_victory(outcome)`.
- Death: `RunState.current_floor = node.floor` → `var outcome :=
  RunState.finish_run(false)` → `_show_game_over(outcome)`.
- `VictoryScene` / `GameOverScene`: each gains `var outcome: RunOutcome`,
  set by `RunScene` before `add_child` and read in `_ready` (they build
  their labels in `_ready`, like every other scene). Their button is
  renamed **Return to Camp**, signal renamed `camp_requested` →
  `RunScene._show_camp()`. `GameOverScene` adds a second label:
  `"Lost %d piece(s) of gear and %d XP. Skills are safe."`;
  `VictoryScene` adds `"Everything you found is yours to keep."`.

### 4.3 `project.godot`

Autoload order: `MetaState`, `SaveManager`, `RunState`. Main scene
unchanged (`run_scene.tscn`).

## 5. Error handling summary

- Save I/O failure → `push_warning`, return `false`, play continues.
- Load: missing → fresh; corrupt/wrong version → renamed `.bad`, fresh,
  warning. Never a crash, never an overwrite of a bad file.
- Unknown ids in a save → skipped with warning; equipped-but-not-owned →
  slot cleared.
- `finish_run` called while `not in_run` → `push_warning`, returns a
  zero `RunOutcome`, does nothing else.

## 6. Testing

**Isolation first.** New `tests/unit/run_state_test.gd`: `class_name
RunStateTest extends GutTest` with

```
func before_each() -> void:
	SaveManager.save_path = "user://test_save.json"
	SaveManager.delete_save()
	MetaState.reset()
```

Every existing test file that calls `RunState.start_new_run` switches
`extends GutTest` → `extends RunStateTest`. Without this, write-through
from one test leaks level/skills into the next and writes the real
`user://save.json`.

**Unit coverage (GUT):**

- `MetaState`: `reset()` defaults; `to_dict()`/`from_dict()` round-trip;
  unknown ids skipped; equipped-but-not-owned cleared.
- `SaveManager`: save then load round-trip on the temp path; missing file
  → `false` and defaults; corrupt JSON → `.bad` exists, defaults, `false`;
  wrong version → same; `delete_save()`.
- `DwarfEquipment.get_by_id`, `DwarfSkillTree.get_node_by_id` (known and
  unknown ids).
- `RunState`: `start_new_run` seeds level/XP/skills/gear from `MetaState`;
  recomputed `player_max_hp` and `level_bonus_*` match the unlocked nodes;
  deck/gold/relics/potions still reset; `grant_xp` and `unlock_skill_node`
  write through (assert on `MetaState` **and** on a reloaded save);
  `equip_item` writes through at Camp but not in a run; `finish_run(true)`
  commits gear; `finish_run(false)` wipes gear, halves XP (15 → 7,
  `xp_lost == 8`), keeps level and skills; `enter_camp` leaves `in_run`
  false and `map` null.
- `CampScene`: three buttons emit their signals; labels reflect
  `RunState`.
- `RunScene`: `_ready` shows Camp, not the map; Start Run reaches the map
  with `in_run` true; death path applies the penalty and Return to Camp
  shows Camp; Skill Tree opened from Camp returns to Camp; opened from
  Map returns to Map; a skill unlocked mid-run is present in
  `MetaState` immediately.
- Any test asserting on a value the combat turn loop can touch still
  calls `encounter.start_player_turn()` first (Plan 2C/2D rule).

**Manual verification (non-negotiable):** play in the editor — unlock a
skill and equip gear at Camp, start a run, die: confirm gear is gone,
XP halved, skills present. Unlock a skill mid-run, quit the game,
relaunch: Camp shows the skill. Win a run: gear found during the run is
listed at Camp. Delete `user://save.json`: Camp shows a level-1 character.

## Open items for later (explicitly out of scope now)

- Plan 3B: mid-run snapshot/resume.
- Camp dialogue and story beats reacting to the last run (§6 of the
  parent spec).
- Save-file migration beyond version rejection.
- Class selection at Camp once a second class exists.
