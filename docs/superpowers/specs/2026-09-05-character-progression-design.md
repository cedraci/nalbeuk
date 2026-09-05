# Design: Character Progression (Plan 2C)

**Date:** 2026-09-05
**Status:** Approved, pending implementation plan
**Parent spec:** `docs/superpowers/specs/2026-09-04-party-deckbuilder-design.md`
**Builds on:** Plan 1 (core combat engine), Plan 2A (Combat Scene UI), and
Plan 2B (Run & Map Structure), merged to master at `56a72d7`.

## Summary

The third sub-project of Plan 2 (Run Structure & Playable Combat Scene): an
in-run XP/leveling system with a branching per-class skill tree, layered on
top of the run/map loop Plan 2B established. This is deliberately a
run-scoped, fully-resetting system — separate from the future persistent
Camp/Renown talent tree (Plan 3), per the explicit "two separate systems"
decision made during Plan 2B's brainstorming. Plan 2D (Equipment, Relics,
Potions) remains a separate, later sub-project.

## 1. Scope

**In scope:**

- In-run XP and leveling: level 1 → 7, resets to level 1 at the start of
  every run (`RunState.start_new_run`), fully independent of any future
  Camp/persistent-stats system.
- XP sources: Combat (15 XP), Elite (30 XP), and Boss (50 XP) rewards,
  granted alongside their existing gold rewards; plus a couple of Event
  choices that also carry a `xp_delta`, applied alongside their existing
  `gold_delta`/`hp_delta`.
- One skill point per level-up (6 skill points obtainable across a full
  level 1 → 7 arc).
- A branching Dwarf-only skill tree (the only class with content today): a
  shared Root node, a 3-node Offense branch, and a 3-node Defense branch (7
  nodes total). Because only 6 points are ever obtainable in one run, a
  player can clear Root plus one full branch, but never both branches
  fully — a deliberate, always-present tension.
- A dedicated, always-available "Skill Tree" button on the map screen,
  letting the player spend banked points at any time — not tied to a
  level-up popup or any specific map node.
- Two small, precedented additions to the combat engine (see §2): a
  `baseline_block_bonus` field on `CombatActor` mirroring the existing
  `baseline_strike_bonus`, and a fix making `RunState.player_max_hp` the
  actual source of truth for the combat actor's max HP (today it is tracked
  but never read when building the actor — harmless while every HP source
  is zero, but Vitality nodes need it to work).

**Explicitly out of scope (deferred):**

- Camp/Renown persistent talent tree (Plan 3) — a separate system by
  design, not merely deferred content.
- Skill trees for Elf Ranger, Wizard, or any other class — no class content
  exists for them yet (Dwarf remains the only implemented class).
- Equipment, Relics, and Potions (Plan 2D).
- Any new status effect beyond reusing the existing `strength` status
  stack for the Battle Fury capstone.
- Variable per-node point costs, alternate prerequisite shapes (e.g.
  multi-parent nodes), or tree respec/refund — the tree is a strict,
  single-parent-per-node chain, bought forward only.

## 2. Data model & XP curve

**`RunState` additions** (`scripts/run/run_state.gd`):

```gdscript
const MAX_LEVEL := 7
const XP_THRESHOLDS: Array[int] = [20, 30, 40, 55, 70, 90]  # index = level-1; XP needed to advance from that level
const COMBAT_XP_REWARD := 15
const ELITE_XP_REWARD := 30
const BOSS_XP_REWARD := 50

var level: int = 1
var xp: int = 0
var skill_points: int = 0
var unlocked_skill_nodes: Array[StringName] = []
var level_bonus_strength: int = 0
var level_bonus_block: int = 0
```

- `grant_xp(amount: int) -> void` — adds `amount` to `xp`, then loops while
  `level < MAX_LEVEL and xp >= XP_THRESHOLDS[level - 1]`: subtracts the
  threshold from `xp`, increments `level`, increments `skill_points`. A
  single large XP reward can cause multiple level-ups in one call. Once
  `level == MAX_LEVEL`, further `grant_xp` calls are a no-op (XP earned past
  the cap is simply discarded — no banking).
- `unlock_skill_node(node: SkillNode) -> bool` — returns `false` and makes
  no change if: `skill_points <= 0`, `node.id` is already in
  `unlocked_skill_nodes`, or `node.requires_id != &"" and not
  unlocked_skill_nodes.has(node.requires_id)`. On success: decrements
  `skill_points`, appends `node.id`, adds `node.strength_delta` to
  `level_bonus_strength`, adds `node.block_delta` to `level_bonus_block`,
  and adds `node.vitality_delta * 2` to both `player_max_hp` and
  `player_current_hp` (an immediate, felt HP gain — not just a raised cap
  the player has to Rest into).

**`SkillNode`** (new, `scripts/run/skill_node.gd`, plain `RefCounted`):

```gdscript
class_name SkillNode
extends RefCounted

enum Branch { ROOT, OFFENSE, DEFENSE }

var id: StringName
var display_name: String
var description: String
var branch: Branch
var requires_id: StringName       # &"" for the Root node
var strength_delta: int = 0
var vitality_delta: int = 0
var block_delta: int = 0
var passive_id: StringName = &""  # &"battle_fury", &"unyielding", or &"" for none
```

A flat `requires_id` prerequisite (rather than branch-aware logic in code)
keeps `unlock_skill_node` generic — the branch structure lives entirely in
content data (§3), not in `RunState`.

**`build_encounter_for_node`** gains these lines, inserted after the
existing `player := ActorFactory.build_player_actor(...)` call and before
returning the `CombatEncounter`:

```gdscript
player.max_hp = player_max_hp
player.current_hp = min(player_current_hp, player.max_hp) as int
player.baseline_strike_bonus += level_bonus_strength
player.baseline_block_bonus += level_bonus_block
if unlocked_skill_nodes.has(&"battle_fury"):
    player.add_status(&"strength", 2)
if unlocked_skill_nodes.has(&"unyielding"):
    player.add_block(5)
```

This replaces the existing `player.current_hp = min(player_current_hp,
player.max_hp) as int` line (which today clamps against a `player.max_hp`
computed solely from `persistent_stats.compute_max_hp(...)`, ignoring
`RunState.player_max_hp` entirely) — after this change, `RunState.player_max_hp`
is the one authoritative max-HP value for the run, and `ActorFactory`'s own
computation is overridden by it. Both capstone passives (`battle_fury`,
`unyielding`) are pure build-time setup calls; no changes are needed to
`CombatEncounter`'s turn loop.

**Engine touches (small, precedented — mirror existing Strength/damage wiring):**

- `CombatActor` (`scripts/combat/combat_actor.gd`): add
  `var baseline_block_bonus: int = 0`.
- `BlockEffect.apply()` (`scripts/resources/effects/block_effect.gd`):
  changes from `context.target.add_block(amount)` to
  `context.target.add_block(amount + context.source.baseline_block_bonus)`
  — an exact mirror of how `DamageEffect.apply()` already adds
  `context.source.baseline_strike_bonus` on top of the card's own `amount`.
- `EventChoice` (`scripts/resources/event_choice.gd`): add
  `var xp_delta: int = 0`.
- `RunState.apply_event_choice(choice: EventChoice)`: gains a call to
  `grant_xp(choice.xp_delta)` alongside its existing gold/HP delta logic.

## 3. Dwarf skill tree content

New file `scripts/content/dwarf_skill_tree.gd`,
`static func get_skill_tree() -> Array[SkillNode]`, returning exactly these
7 nodes:

| id | display_name | branch | requires_id | strength_delta | vitality_delta | block_delta | passive_id | description |
|---|---|---|---|---|---|---|---|---|
| `&"dwarven_grit"` | Dwarven Grit | ROOT | `&""` | 1 | 1 | 0 | `&""` | A dwarf's stubborn constitution. |
| `&"sharpened_pick"` | Sharpened Pick | OFFENSE | `&"dwarven_grit"` | 2 | 0 | 0 | `&""` | Keep the edge keen. |
| `&"heavy_swing"` | Heavy Swing | OFFENSE | `&"sharpened_pick"` | 3 | 0 | 0 | `&""` | Put your whole back into it. |
| `&"battle_fury"` | Battle Fury | OFFENSE | `&"heavy_swing"` | 0 | 0 | 0 | `&"battle_fury"` | Start every fight already furious: +2 Strength stacks. |
| `&"thick_hide"` | Thick Hide | DEFENSE | `&"dwarven_grit"` | 0 | 3 | 0 | `&""` | Dwarven skin, dwarven stubbornness. |
| `&"reinforced_guard"` | Reinforced Guard | DEFENSE | `&"thick_hide"` | 0 | 0 | 3 | `&""` | A shield worth trusting. |
| `&"unyielding"` | Unyielding | DEFENSE | `&"reinforced_guard"` | 0 | 0 | 0 | `&"unyielding"` | Brace before the first blow lands: start combat with 5 Block. |

Every node costs exactly 1 skill point. A typical single-Act run (roughly 3
Combats + 1 Elite + 1 Boss + a couple of XP-granting Events, ≈140-150 XP)
reaches level 4-5 — Root plus 3 more nodes, enough to nearly finish one
branch but not both. These numbers are a first pass, tunable later, matching
this project's established "thin content now, balance later" approach.

## 4. Scenes & orchestration

- **`MapView`** (`scripts/ui/run/map_view.gd`) gains an always-visible
  header label showing `"Lv {level}   XP: {xp}/{next_threshold}   Skill
  Points: {skill_points}"` (where `next_threshold` is
  `RunState.XP_THRESHOLDS[level - 1]`), or `"Lv 7 (MAX)"` in place of the
  XP fraction once `level == MAX_LEVEL`. It also gains a persistent
  `skill_tree_button`, always enabled regardless of which map nodes are
  currently reachable. Clicking it emits `signal skill_tree_requested`.
- **`RunScene`** connects `MapView.skill_tree_requested` to swap its
  current child to a new `SkillTreeScene`, via the existing `_swap_to()`
  mechanism. This swap does not touch `current_node`, `current_floor`, or
  mark anything visited — opening the skill tree is not visiting a map
  node. `SkillTreeScene`'s `back_button` swaps back to `MapView`.
- **`SkillTreeScene`** (new, `scripts/ui/run/skill_tree_scene.gd` +
  `.tscn`): a header showing the same level/XP/points text as `MapView`,
  then one button per node from `DwarfSkillTree.get_skill_tree()`, text
  `"{display_name}: {description}"`. Button state per node:
  - **Unlocked** — already in `RunState.unlocked_skill_nodes`: disabled,
    labeled with a trailing `" ✓"`.
  - **Available** — prerequisite met, `skill_points > 0`, not yet unlocked:
    enabled; clicking calls `RunState.unlock_skill_node(node)` and
    refreshes every button's state.
  - **Locked** — prerequisite unmet, or no points left: disabled.
  A `back_button` returns control to `RunScene`, which re-shows `MapView`.
- **`RunScene._on_combat_dismissed`** (win path) is extended: alongside its
  existing gold-reward `match` on node type, it now also calls
  `RunState.grant_xp(...)` with `COMBAT_XP_REWARD` / `ELITE_XP_REWARD` /
  `BOSS_XP_REWARD` matched the same way.

## 5. Testing

**GUT unit tests** (new tests added to existing files where a natural home
exists, e.g. `test_run_state.gd`, `test_data_resources.gd`, plus one new
`test_skill_tree_scene.gd`):

- `RunState.grant_xp()`: an exact-threshold reward grants exactly 1 skill
  point and advances `level` by 1; a large enough single reward causes two
  level-ups in one call; once `level == MAX_LEVEL`, further XP changes
  neither `level` nor `skill_points`.
- `RunState.unlock_skill_node()`: a valid purchase spends a point and
  applies the correct delta(s); rejected (no state change) when
  `skill_points == 0`; rejected when `requires_id` isn't yet unlocked;
  rejected (no double-spend, no double-applied bonus) when the node is
  already unlocked.
- `RunState.build_encounter_for_node()`: `player.max_hp` reflects
  `player_max_hp` including any Vitality nodes bought so far;
  `player.baseline_strike_bonus` includes `level_bonus_strength`;
  `player.baseline_block_bonus` includes `level_bonus_block`; with
  `battle_fury` unlocked the player enters combat with 2 Strength stacks;
  with `unyielding` unlocked the player enters combat with 5 Block.
- `BlockEffect.apply()`: block gained equals `amount +
  source.baseline_block_bonus`.
- `EventChoice` / `RunState.apply_event_choice()`: a choice with
  `xp_delta > 0` grants XP through `grant_xp`, including a case where the
  grant is enough to trigger a level-up.
- `SkillTreeScene`: node buttons reflect locked/available/unlocked state
  correctly for a given `RunState`-like scenario; clicking an available
  node's button calls `unlock_skill_node` and the whole list refreshes;
  `back_button.pressed` returns control to `RunScene` — driven through the
  real signal, not a private method call directly (standing checklist item
  from the 2A/2B final reviews).
- `MapView`: the skill-tree button is present and enabled regardless of
  which combat nodes are reachable; pressing it emits
  `skill_tree_requested`; the level/XP header text matches `RunState`.

**Manual verification** (same non-negotiable standard as 2A/2B): play a
full Act, level up at least twice, spend points into both branches
(confirming the run eventually can't afford to finish both), and confirm
in an actual fight that Strike damage, Block gained, and both capstone
passives are visibly different from a fresh level-1 run. Automated tests
passing is not sufficient on its own to call this plan done.

## Open items for later (explicitly out of scope now)

- Camp/Renown persistent talent tree (Plan 3).
- Skill trees for classes beyond Dwarf.
- Plan 2D: Equipment, Relics, Potions.
- Tree respec/refund, variable node costs, multi-parent prerequisites.
