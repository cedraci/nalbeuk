# Design: Run & Map Structure (Plan 2B)

**Date:** 2026-09-05
**Status:** Approved, pending implementation plan
**Parent spec:** `docs/superpowers/specs/2026-09-04-party-deckbuilder-design.md`
**Builds on:** Plan 1 (core combat engine) and Plan 2A (Combat Scene UI),
merged to master at `f958828`.

## Summary

The second playable slice of the Fantasy Party Deckbuilder: a full,
structurally-complete single-Act run — a branching node map connecting
Combat, Elite, Event, Rest, Shop, and Boss encounters, backed by a new
`RunState` autoload that carries deck/HP/gold across encounters within a
run. This is sub-project 2B of Plan 2 (Run Structure & Playable Combat
Scene) from the parent spec. Two further sub-projects follow separately:
Plan 2C (in-run XP/leveling and per-class skill trees) and Plan 2D
(Equipment, Relics, and Potions) — both build on the reward/node
structure this plan establishes, neither is implemented here.

## 1. Scope

**In scope:**

- One full, structurally-complete Act: a branching node map (STS-style —
  several floors, 2-4 node choices per floor, converging paths, ending
  in a Boss), procedurally generated fresh at the start of each run.
- Node types: **Combat**, **Elite**, **Event**, **Rest**, **Shop**,
  **Boss**. (Treasure is deferred — see below.)
- A `RunState` autoload tracking what actually persists across combats
  within a run: current deck, player HP, gold, and map position/progress.
  `PersistentStats` stays zeroed — Camp/meta-progression (Plan 3) doesn't
  exist yet, so this is a documented stub, not a balance decision.
- A `MapView` scene rendering the node graph, letting the player click
  any node reachable from their current position.
- Elite and Boss reuse the existing Cave Rat content with reskinned
  display names and boosted numbers (more HP, a harder move) — no new
  enemy-authoring system yet.
- Rest: heal a flat amount, or upgrade one card in the deck (hand-authored
  "+" variants of Strike/Guard, the same hand-authored-over-introspected
  pattern already used for `description`/`display_value` in Plan 2A — not
  a generic upgrade-math engine, since there are only two cards to
  upgrade).
- Event: 1-2 hand-written events, each a short description plus 2-3
  choice buttons with simple gold/HP outcomes. A real, reusable branching
  mechanism; thin content.
- Shop: sells the two existing Dwarf cards for gold, plus a "Leave"
  button back to the map.
- Gold, a new `RunState` field, granted in small amounts by Combat/Elite/
  Boss rewards — the only other economy participant besides Shop right
  now.
- Victory/GameOver: a plain result screen with a "New Run" button that
  regenerates a fresh map and resets `RunState` from the same fixed Dwarf
  baseline.
- `CombatScene.play_again_requested` renamed to
  `combat_dismissed(player_won: bool)` (per the Plan 2A final review's
  recommendation), so the run loop can distinguish win from loss when a
  Combat/Elite/Boss node's fight ends and route accordingly (reward +
  return to map, vs. immediate GameOver).
- `CombatDemo` stays exactly as it is today — a standalone combat smoke
  test, still valuable per the 2A final review — but stops being the
  project's main scene; the new `RunScene` takes that slot in
  `project.godot`. `CombatDemo`'s internal signal handling is updated to
  match `CombatScene`'s renamed signal.

**Explicitly out of scope (deferred):**

- Treasure nodes — their spec'd payout is a relic (parent spec §4), which
  doesn't exist until Plan 2D. Dropped from this plan's node-type pool,
  reintroduced once Plan 2D ships relics.
- The full 3-Act structure — one Act only. Generating more Acts
  back-to-back is a later, largely mechanical extension once there's
  enough content variety to justify it; the generation code's shape
  won't need to change.
- XP/leveling and class skill trees (Plan 2C).
- Equipment, Relics, and Potions (Plan 2D).
- CampHub, MainMenu, class selection, `MetaState`/`SaveManager`,
  persistence across app restarts (Plan 3 and later).
- New enemy types, new cards beyond hand-authored upgrades of the
  existing two.

## 2. `RunState` and the map data model

**`RunState`** (new autoload, `scripts/run/run_state.gd`) is the
run-scoped state that today lives only as local variables inside
`CombatDemo`. Fields:

- `class_resource: ClassResource`, `persistent_stats: PersistentStats`
  (zeroed for now)
- `deck: Array[CardResource]` — starts as
  `class_resource.starting_deck.duplicate()`; Rest-site upgrades and Shop
  purchases mutate this in place, so it is the one true deck across the
  whole run
- `player_max_hp: int`, `player_current_hp: int` — carried across
  encounters; only Rest (and, later, potions) changes
  `player_current_hp` outside of combat
- `gold: int`
- `map: MapGraph`, `current_floor: int`, `current_node: MapNode` (null
  before the run starts)

Two methods carry logic that today is duplicated per-encounter inside
`CombatDemo`:

- `start_new_run(class_resource: ClassResource) -> void` — resets every
  field above and generates a fresh `MapGraph`.
- `build_encounter_for_node(node: MapNode) -> CombatEncounter` — builds
  actors via `ActorFactory`, force-sets
  `player.current_hp = player_current_hp`, resolves which
  `EnemyResource` the node needs (plain Cave Rat for Combat, boosted
  variants for Elite/Boss), and returns a ready `CombatEncounter`. This
  is the one place that knows how to translate "which node did the
  player click" into "a playable fight."

**Map data model** (`scripts/run/map_node.gd`, `scripts/run/map_graph.gd`):

- `MapNode` (plain `RefCounted`): `id: int`, `node_type: NodeType` enum
  (`COMBAT, ELITE, EVENT, REST, SHOP, BOSS`), `floor: int`,
  `connections: Array[int]` (ids of reachable nodes on the next floor),
  `visited: bool`.
- `MapGraph`: `floors: Array[Array[MapNode]]`, plus a static
  `generate(rng: RandomNumberGenerator) -> MapGraph`. Floor 0 is a single
  forced Combat node (the run's entry point); the last floor is a single
  forced Boss node; middle floors have 2-4 nodes each with
  weighted-random types (no two Rest nodes on the same floor);
  connections are generated with the standard node-graph trick — each
  node picks 1-2 targets on the next floor, then a repair pass guarantees
  every next-floor node has at least one incoming connection, so there
  is never an unreachable node.

## 3. Scenes and orchestration

**`RunScene`** (new, `scripts/ui/run/run_scene.gd`) is the new
orchestrator and becomes the project's `run/main_scene`, replacing
`CombatDemo` in that slot. It owns one child at a time, swapped based on
what the player is doing:

- On `_ready()`: calls
  `RunState.start_new_run(DwarfContent.get_class_resource())`, then shows
  `MapView`.
- **`MapView`** (`scripts/ui/run/map_view.gd`): renders `RunState.map` as
  columns of node buttons (one column per floor), enabling only the
  buttons for nodes reachable from `RunState.current_node`'s
  `connections` (or just the single forced entry node, before the run
  has moved at all). Clicking a node emits
  `signal node_selected(node: MapNode)`.
- `RunScene` handles `node_selected` by hiding `MapView` and instancing
  the right child for `node.node_type`:
  - **Combat / Elite / Boss** — `RunState.build_encounter_for_node(node)`
    feeds a `CombatEncounter` into a `CombatScene`, exactly like
    `CombatDemo` does today. `RunScene` listens for
    `combat_dismissed(player_won)`: on win, it applies the reward (gold),
    writes `encounter.player.current_hp` back into
    `RunState.player_current_hp`, marks the node visited, advances
    `current_node`/`current_floor`, and — if this was the Boss node —
    shows `VictoryScene` instead of returning to `MapView`. On loss, it
    shows `GameOverScene` immediately.
  - **Rest** — `RestScene` (`scripts/ui/run/rest_scene.gd`): two
    buttons, "Heal" (raises `RunState.player_current_hp` by a flat
    amount, clamped to max) and "Upgrade a Card" (lists the current deck,
    clicking a card swaps it for its hand-authored "+" counterpart
    looked up by `id`). Either choice ends the node.
  - **Event** — `EventScene` (`scripts/ui/run/event_scene.gd`), driven by
    a small data resource: `EventResource` (`description: String`,
    `choices: Array[EventChoice]`), `EventChoice` (`label: String`,
    `gold_delta: int`, `hp_delta: int`, `outcome_text: String`). Clicking
    a choice applies both deltas to `RunState` and shows the outcome text
    before returning to the map. 1-2 hand-written `EventResource`
    instances live in a new `scripts/content/events_content.gd`, picked
    randomly when an Event node is entered.
  - **Shop** — `ShopScene` (`scripts/ui/run/shop_scene.gd`): lists the
    two Dwarf cards with a price and a Buy button (disabled if gold is
    too low; buying appends a duplicate to `RunState.deck` and deducts
    gold), plus a "Leave" button.
  - Every non-combat node scene, on completion, marks its node visited,
    advances position, and returns control to `RunScene`, which re-shows
    `MapView`.
- **`VictoryScene`** / **`GameOverScene`**: near-identical plain result
  screens (floor reached, win/loss text) with a "New Run" button wired to
  `RunState.start_new_run(...)` followed by re-showing `MapView` — the
  same restart pattern `CombatDemo`'s "Play Again" already established,
  one level up.

`CombatDemo` is otherwise unchanged from Plan 2A, and stops being
`run/main_scene` in favor of `RunScene`.

## 4. Testing

- **GUT unit tests**, following Plan 1/2A's existing test patterns:
  - `MapGraph.generate()`: floor 0 is exactly one forced Combat node, the
    last floor is exactly one forced Boss node, every node above floor 0
    has at least one incoming connection (no dead nodes), no two Rest
    nodes on the same floor, connections only ever point at the
    immediately next floor.
  - `RunState.start_new_run()`: resets deck/HP/gold/map/position from a
    given `ClassResource`.
  - `RunState.build_encounter_for_node()`: the player actor's
    `current_hp` matches `RunState.player_current_hp` (not a full heal),
    Elite/Boss nodes get boosted `EnemyResource` variants, Combat gets
    the plain one.
  - Reward/HP write-back after a won Combat/Elite/Boss node.
  - Rest's card-upgrade swap (by id, deck mutated in place), and Heal's
    clamped HP gain.
  - Event's gold/HP delta application.
  - Shop's buy logic: gold deducted, card appended, Buy disabled when
    gold is less than price.
  - Per the Plan 2A final review's checklist addition: every test drives
    the real entry point (the signal a click would emit, e.g.
    `node_selected.emit(node)`) rather than calling a private handler
    directly.
- **Manual verification** (same standard as Plan 2A, non-negotiable per
  the parent spec): open `RunScene` in the editor and play at least one
  full Act, passing through at least one of each node type (Combat,
  Elite, Event, Rest, Shop, Boss), to both a win and a loss, confirming
  HP/gold/deck carry over correctly between nodes and the map only lets
  you click reachable nodes. Automated tests passing is not sufficient on
  its own to call this plan done.

## Open items for later (explicitly out of scope now)

- Treasure nodes (needs Plan 2D's relics).
- 3-Act structure.
- Plan 2C: in-run XP/leveling, per-class skill trees.
- Plan 2D: Equipment, Relics, Potions.
- CampHub, MainMenu, class selection, `MetaState`/`SaveManager`,
  cross-session persistence.
- New enemy types, new cards beyond hand-authored card upgrades.
