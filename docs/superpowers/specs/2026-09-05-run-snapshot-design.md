# Design: Run Snapshot & Resume (Plan 3B)

**Date:** 2026-09-05
**Status:** Approved, pending implementation plan
**Parent spec:** `docs/superpowers/specs/2026-09-04-party-deckbuilder-design.md`
**Builds on:** Plan 3A (Persistent Character & Camp), merged to master at
`5c0b16f`.

## Summary

The second sub-project of Plan 3 (Meta-progression). An in-progress run
is snapshotted every time the player is back on the map, so quitting the
game and relaunching resumes the run from that map position: same map,
same deck, HP, gold, relics, potions, gear found during the run, and the
same random sequence. Camp shows **Continue Run** / **Abandon Run** while
a run is suspended; abandoning applies Plan 3A's death rules.

Snapshots are taken **between nodes only**. Quitting mid-fight, mid-event,
in a shop, or at a rest site resumes at the map with that node still
unvisited — the player re-enters it fresh. Mid-combat resume is
explicitly out of scope.

## 1. Scope

**In scope:**

- **`RunSnapshot`** — a static serializer that captures `RunState` into an
  id-only `Dictionary` and restores it.
- **`MapGraph.to_dict()` / `MapGraph.from_dict()`** — the map graph is the
  only non-trivial structure; nodes are addressed by their existing int
  ids.
- **Content lookups by id** for the three content types not yet
  addressable: `DwarfContent.get_card_by_id`, `DwarfRelics.get_by_id`,
  `DwarfPotions.get_by_id`.
- **`SaveManager`** — save file version 2 carrying both `meta` and `run`;
  one writer (`save_game()`), an in-memory `run_snapshot`, and
  `has_run_snapshot()`. Version-1 files (Plan 3A) still load.
- **`RunState` checkpoints** — snapshot refreshed at the end of
  `start_new_run` and of `mark_node_visited_and_advance`; cleared in
  `finish_run`. New `resume_run(class_res) -> bool` and
  `abandon_saved_run() -> RunOutcome`. `RunOutcome.abandoned: bool`.
- **`CampScene`** — Continue Run / Abandon Run when a snapshot exists;
  Skill Tree and Inventory hidden while a run is suspended; a second
  flavor line.
- **`RunScene` / `GameOverScene`** — the continue and abandon flows.

**Explicitly out of scope (deferred):**

- Mid-combat / mid-event / mid-shop resume (no `CombatEncounter`
  serialization).
- Confirmation dialogs (Abandon is one click).
- Save slots, save migration beyond "version 1 → no suspended run".
- Editing gear or skills at Camp while a run is suspended (deliberately
  hidden, see §4.1).
- Any Camp story copy beyond the second flavor constant.

## 2. Snapshot data

### 2.1 Shape (`RunSnapshot.capture() -> Dictionary`)

Ids and scalars only, JSON-safe:

```json
{
  "current_floor": 2,
  "current_node_id": 5,
  "map": {
    "floors": [
      [ { "id": 0, "type": 0, "floor": 0, "connections": [1, 2], "visited": true } ],
      [ { "id": 1, "type": 3, "floor": 1, "connections": [4], "visited": false },
        { "id": 2, "type": 0, "floor": 1, "connections": [4, 5], "visited": true } ]
    ]
  },
  "deck": ["dwarf_strike", "dwarf_strike_plus", "dwarf_guard"],
  "player_max_hp": 36,
  "player_current_hp": 21,
  "gold": 25,
  "relic_ids": ["whetstone"],
  "potion_ids": ["healing_draught"],
  "owned_equipment_ids": ["rusty_shortsword", "leather_vest"],
  "equipped_weapon_id": "rusty_shortsword",
  "equipped_armor_id": "",
  "equipped_trinket_id": "",
  "rng_seed": "1234567890123456789",
  "rng_state": "9876543210987654321"
}
```

- `type` is the `MapNode.NodeType` enum value as an int.
- `rng_seed` / `rng_state` are **strings**: both are 64-bit ints and JSON
  numbers round-trip through a double, which would corrupt them. Restored
  with `String.to_int()`.
- Gear is included because gear found during the run is at-risk state
  that exists only in `RunState` until `finish_run` commits it (Plan 3A
  §3.2). While a run is suspended the snapshot's gear list is the
  authoritative one and is a superset of `MetaState`'s.
- Level, XP, skill points, and unlocked skills are **not** in the
  snapshot: they are never-lost state already written through to
  `MetaState`, and `resume_run` seeds them from there exactly as
  `start_new_run` does.

### 2.2 `MapGraph.to_dict()` / `static from_dict(data) -> MapGraph`

`to_dict()` emits `{"floors": [[node, ...], ...]}` with each node
`{id, type, floor, connections, visited}`. `from_dict` rebuilds
`MapNode`s in the same floor order, restores `connections` and `visited`,
and returns `null` when `floors` is missing, empty, or any node lacks
`id`/`type`/`floor`. Node ids are preserved verbatim; `RunState`
re-resolves `current_node` by id after the graph is rebuilt.

### 2.3 Content lookups

- `static DwarfContent.get_card_by_id(card_id: StringName) ->
  CardResource` — fresh instance for `dwarf_strike`, `dwarf_guard`,
  `dwarf_strike_plus`, `dwarf_guard_plus`; `null` otherwise.
- `static DwarfRelics.get_by_id(relic_id) -> RelicResource`,
  `static DwarfPotions.get_by_id(potion_id) -> PotionResource` — same
  contract as `DwarfEquipment.get_by_id` (fresh instance, `null` if
  unknown).

## 3. Persistence and `RunState` rules

### 3.1 Save file version 2

```json
{ "version": 2, "meta": { ... Plan 3A ... }, "run": null | { ... §2.1 ... } }
```

`SaveManager` changes:

- `SAVE_VERSION := 2`. `load_game()` accepts `version == 1` (reads `meta`,
  sets `run_snapshot = null`) **and** `version == 2` (reads both). Any
  other version, or a non-Dictionary `meta`, follows Plan 3A's quarantine
  rule. A `run` that is neither `null` nor a Dictionary is treated as
  `null` with a warning (the character is never quarantined for a bad
  run section).
- `var run_snapshot: Variant = null` — the latest snapshot, or `null`.
- `save_game() -> bool` writes `meta` from `MetaState.to_dict()` and
  `run` from `run_snapshot`. `save_meta()` is renamed to `save_game()`
  and `load_meta()` to `load_game()`; every caller (Plan 3A write-through
  in `RunState`, `RunScene._ready`, tests) is updated. No aliases.
- `has_run_snapshot() -> bool` is `run_snapshot is Dictionary`.
- `delete_save()` also sets `run_snapshot = null`.

### 3.2 Checkpoints (when the snapshot changes)

| Moment | Effect |
|---|---|
| End of `start_new_run` | `SaveManager.run_snapshot = RunSnapshot.capture()`, `save_game()` |
| End of `mark_node_visited_and_advance` | same — this is "back on the map" |
| `finish_run` (victory, death, abandon) | `SaveManager.run_snapshot = null`, then the existing `save_game()` |
| `resume_run` | no new capture (the loaded snapshot already matches) |

Plan 3A's write-through saves (`grant_xp`, `unlock_skill_node`, Camp gear
changes) keep calling `save_game()`, which re-writes the cached snapshot
unchanged — a mid-fight XP save therefore never produces a mid-fight
snapshot. Exactly two places capture; nothing else does.

### 3.3 `resume_run(p_class_resource) -> bool`

1. If `not SaveManager.has_run_snapshot()` → return `false`.
2. `class_resource`, `persistent_stats`, `load_character_from_meta()` —
   identical to `start_new_run` (level/XP/skills from `MetaState`; this
   also sets the skill-derived `player_max_hp` baseline).
3. `RunSnapshot.restore(snapshot)`:
   - `map = MapGraph.from_dict(...)`; `current_node` = the node whose id
     is `current_node_id`. **If the map is `null` or the id is not found,
     return `false` without touching anything else.** These two checks
     run first, before any other field is written.
   - `deck` = cards by id (unknown ids skipped with a warning; an empty
     resulting deck falls back to the class starting deck with a warning).
   - Gear: `owned_equipment` and equipped slots from the snapshot's ids
     (same rehydration as `load_character_from_meta`), replacing what
     `MetaState` provided.
   - Relics: `unlocked_relics` = known ids; `relic_bonus_strength/block`
     and `relic_gold_bonus` = sums over those relics. **Relic vitality is
     not re-applied** — it is already baked into the saved
     `player_max_hp`.
   - `potions` = known ids (capped at `MAX_POTIONS`).
   - `player_max_hp`, `player_current_hp` (clamped to `[0, max]`),
     `gold`, `current_floor` from the snapshot.
   - `rng = RandomNumberGenerator.new()`; `rng.seed = rng_seed.to_int()`;
     `rng.state = rng_state.to_int()` (in that order — setting `seed`
     resets `state`).
4. `in_run = true`; return `true`.

On `false` from step 3, `RunScene` calls `SaveManager.run_snapshot = null`
+ `save_game()` and refreshes Camp: the run is gone, **no penalty**,
because a broken snapshot is not the player's fault.

### 3.4 `abandon_saved_run() -> RunOutcome`

`resume_run(...)`, then `finish_run(false)` with `outcome.abandoned =
true`. Because it goes through `resume_run`, the gear found during the
suspended run is included in what's lost, and `finish_run` clears the
snapshot and saves. If `resume_run` returns `false`, the snapshot is
discarded without penalty and a zero `RunOutcome` is returned.

`RunOutcome` gains `var abandoned: bool = false`. `finish_run` itself is
unchanged except for clearing the snapshot (§3.2).

## 4. Scenes

### 4.1 `CampScene`

New public nodes `continue_run_button`, `abandon_run_button`; new signals
`continue_requested`, `abandon_requested`. `refresh()` now also toggles
visibility:

| `SaveManager.has_run_snapshot()` | Visible |
|---|---|
| `false` | Skill Tree, Inventory, Start Run (today's Camp) |
| `true` | Continue Run, Abandon Run — Skill Tree, Inventory, Start Run hidden |

Hiding Skill Tree and Inventory while a run is suspended removes every
"gear or max-HP changed at Camp while the snapshot still holds the old
values" case; the map's own Skill Tree / Inventory buttons remain
available once the run is resumed.

`flavor_label` shows `FLAVOR_LINE` ("The party argues over who lost the
map.") normally and a second constant `SUSPENDED_FLAVOR_LINE` ("The party
is still out there, arguing about which way is north.") while a run is
suspended.

### 4.2 `RunScene`

- `_ready()`: `SaveManager.load_game()` → `RunState.enter_camp(...)` →
  `_show_camp()` — unchanged shape; Camp decides what to show.
- `continue_requested` → `if RunState.resume_run(class_res): _show_map()`
  else discard the snapshot (§3.3) and `_show_camp()`.
- `abandon_requested` → `var outcome := RunState.abandon_saved_run()`;
  if `outcome.abandoned` → `_show_game_over(outcome)`, else (the snapshot
  was broken and has been discarded) → `_show_camp()`.
- Everything else (Start Run, death, victory, Back routing) unchanged.

### 4.3 `GameOverScene`

`result_label` reads `"You abandoned the run on floor %d."` when
`outcome != null and outcome.abandoned`, else the existing
`"You died on floor %d."`. The loss line and Return to Camp are unchanged.

## 5. Error handling summary

- Broken or unresolvable snapshot → discarded, no penalty, warning.
- Unknown card/relic/potion/equipment ids → skipped with a warning;
  an empty deck falls back to the starting deck.
- Version-1 save → loads, no suspended run, no warning.
- Malformed `run` section in an otherwise valid file → `null`, warning,
  character kept.
- Save I/O failure → as Plan 3A (warning, play continues).

## 6. Testing

All new test files `extends RunStateTest` (Plan 3A). `RunStateTest.
before_each` additionally sets `SaveManager.run_snapshot = null`.

- **`RunSnapshot` round-trip:** after `start_new_run` + a few mutations
  (visit a node, buy a card, upgrade a card, grant a relic with vitality,
  add potions, grant + equip gear, spend gold), `capture()` →
  fresh `MetaState`-seeded `RunState` → `restore()` reproduces: every
  floor's node ids, types, connections, and `visited` flags;
  `current_node.id` and `current_floor`; deck ids in order; `player_max_hp`
  and `player_current_hp`; `gold`; `unlocked_relics` and all three relic
  bonuses; potion ids; owned and equipped gear ids; and **the next
  `rng.randi()` value**.
- **`MapGraph`:** `to_dict`/`from_dict` round-trip on a generated graph;
  `from_dict` returns `null` for `{}`, empty floors, and a node missing
  `id`.
- **Content lookups:** known and unknown ids for cards, relics, potions.
- **`SaveManager`:** version-2 round-trip with and without a run;
  version-1 file loads with `run_snapshot == null`; malformed `run` →
  `null` with the character intact; `delete_save()` clears
  `run_snapshot`; `has_run_snapshot()`.
- **`RunState` checkpoints:** `start_new_run` leaves a snapshot on disk;
  `mark_node_visited_and_advance` refreshes it (saved `current_node_id`
  changes); `grant_xp` mid-run re-saves without changing the snapshot;
  `finish_run` clears it; `resume_run` returns `false` and changes nothing
  when there is no snapshot or when `current_node_id` is unknown;
  `abandon_saved_run` applies the death rules including gear found during
  the run and sets `abandoned`.
- **`CampScene`:** button visibility in both states; both new signals;
  the suspended flavor line.
- **`RunScene`:** boot with a snapshot shows Continue/Abandon; Continue
  lands on the map at the saved node with `in_run` true; Abandon shows
  the abandon text on Game Over, applies the penalty, and Return to Camp
  shows Start Run again; a broken snapshot on Continue returns to Camp
  with Start Run and no penalty; **quit-and-relaunch mid-run** (free the
  `RunScene`, reset `MetaState`, boot a new one) resumes at the same node
  with the same HP and gold.
- Any test asserting on a value the combat turn loop can touch still
  calls `encounter.start_player_turn()` first.

**Manual verification (non-negotiable):** in the editor — start a run,
clear two nodes, buy a card, quit mid-fight on the third; relaunch: Camp
shows Continue/Abandon with the suspended flavor line; Continue lands on
the map with the third node unvisited, the bought card in the deck, HP
and gold as they were. Abandon a run: Game Over says abandoned, gear gone,
XP halved, Camp shows Start Run. Corrupt only the `run` section of
`save.json`: Camp shows Start Run, level intact, warning in Output.

## Open items for later (explicitly out of scope now)

- Mid-combat resume (serialize `CombatEncounter`).
- A confirm step on Abandon Run.
- Camp dialogue reacting to a suspended or abandoned run.

## Amendments (2026-09-06)

Findings from the whole-branch review of the Plan 3B implementation, and
the rulings applied. Each one supersedes the section it names.

- **F1 — Event choices apply on Continue (supersedes §3.2's reasoning).**
  `EventScene` used to call `RunState.apply_event_choice()` the moment a
  choice button was pressed, while `node_completed` — and therefore
  `mark_node_visited_and_advance()`'s checkpoint — only fired from
  Continue. `apply_event_choice` → `grant_xp` writes XP, level and skill
  points through to `MetaState` and saves, so quitting on the outcome
  panel kept the XP while the snapshot still held the node unvisited and
  the pre-event HP and gold: repeatable for unbounded XP. The choice is
  now held in `_pending_choice` and applied in `_on_continue_pressed()`
  immediately before `node_completed`, so the mutation and the checkpoint
  are one synchronous burst. §3.2's claim that write-through saves are
  harmless mid-node was wrong for Events: it holds only while nothing
  mid-node mutates never-lost state.
- **F2 — `RunSnapshot.restore` validates every scalar before writing
  anything (extends §3.3's "these two checks run first").** `int(null)`,
  `int({})` and `int([])` abort the enclosing function in GDScript, so a
  bad scalar returned `false` with map, node, deck, gear, relics and
  potions already written — leaving the run's gear live at Camp, where
  the Inventory would commit it to `MetaState`. `current_node_id`,
  `current_floor`, `player_max_hp`, `player_current_hp` and `gold` must
  now be numbers, and `rng_seed`/`rng_state` a string or a number; all of
  them are checked in the same structural block as the map and the node,
  before the first write. Belt and braces, `RunState.resume_run` re-seeds
  a clean Camp state (`load_character_from_meta()`,
  `_reset_run_only_state()`, `map = null`, `current_node = null`,
  `current_floor = 0`, `in_run = false`) when `restore` returns `false`.
- **F3 — node type is range-checked (extends §2.2).** `from_dict`
  accepted any numeric `type`; an out-of-range value (99, -1) produced a
  `MapNode` that crashed `MapView.display()` on
  `MapNode.NodeType.keys()[node.node_type]` instead of being reported as
  a broken snapshot. A node whose `type` falls outside
  `MapNode.NodeType`, or whose `connections` hold a non-numeric element,
  is now rejected with `null`.
- **F4 — max HP on restore is derived, not read back (supersedes §3.3's
  "relic vitality is not re-applied — it is already baked into the saved
  `player_max_hp`").** A skill unlocked mid-run and then quit before the
  next checkpoint lost its +2 per vitality on resume, because `restore`
  overwrote the baseline `load_character_from_meta()` had just computed.
  `restore` now sets `player_max_hp` to that meta-derived baseline plus
  2 × Σ vitality over the restored relics, then clamps the snapshot's
  `player_current_hp` into `[0, player_max_hp]`. `capture()` still writes
  `player_max_hp`, for diagnostics only.
- **F5 — `has_run_snapshot()` rejects `{}` (supersedes §3.1's "is
  `run_snapshot is Dictionary`").** `{}` is exactly what `capture()`
  returns when there is no run to capture, so it must not read as a
  suspended run.
- **F6 — the save version is read defensively (extends §3.1).**
  `int(data.get("version", -1))` aborted `load_game()` on
  `"version": null`, skipping the quarantine and reset entirely. A
  non-numeric version is now treated as `-1` and follows the existing
  quarantine path.
- **F7 — the `run` section is only read when `version >= 2` (conformance
  with §3.1).** A version-1 file carrying a stray `run` key had it
  honoured; version 1 now always loads with `run_snapshot = null`.
