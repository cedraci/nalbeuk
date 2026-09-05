# Design: Items — Equipment, Relics, Potions (Plan 2D)

**Date:** 2026-09-05
**Status:** Approved, pending implementation plan
**Parent spec:** `docs/superpowers/specs/2026-09-04-party-deckbuilder-design.md`
**Builds on:** Plan 2B (Run & Map Structure) and Plan 2C (Character
Progression), merged to master at `8162b57`.

## Summary

The third and final sub-project of Plan 2 (Run Structure & Playable Combat
Scene): Equipment, Relics, and Potions, plus the reintroduction of Treasure
nodes (deferred from Plan 2B until relics existed). Equipment is
run-scoped and swappable (3 slots, found or bought); Relics are run-scoped
and permanent, unlimited, all stacking; Potions are a 2-slot combat-only
consumable inventory. All three reuse the exact stat-bonus vocabulary and
"apply at build time, verify after a real turn" discipline established —
and, for one bug, hard-won — in Plan 2C.

## 1. Scope

**In scope:**

- **Equipment**: 3 slots (Weapon, Armor, Trinket), swappable anytime from
  a new Inventory screen. 6 hand-authored items (2 per slot). Weapon/Armor
  grant permanent-while-equipped Strength/Block bonuses; Trinket items
  grant a small passive (a Strength status-stack, or a starting-Block
  bonus) reusing the exact mechanisms Plan 2C's final-review fix wave
  proved correct. Equipment never touches max HP — swappable gear only
  affects stats already recomputed fresh every combat (Strength/Block),
  avoiding the complexity of a permanent bonus that would need to
  "un-bake" on unequip.
- **Relics**: permanent, unlimited, all stack. 4 hand-authored relics: one
  HP-flavored (bakes into `player_max_hp` permanently, like a skill-tree
  Vitality node, since relics are never removed), one Strength-flavored,
  one Block-flavored, one economic (bonus gold on every combat reward).
- **Potions**: 2 slots, usable only during combat as a free action (no
  Energy cost, doesn't end the turn). 2 hand-authored potions (a heal, a
  temporary-for-this-fight Strength boost). Requires a new
  `CombatActor.heal()` method and a new potion row in `CombatScene`.
- **Treasure node**: reintroduced as a 7th `MapNode.NodeType`, joining the
  existing weighted-random pool on middle floors (no special guarantee).
  Visiting one grants a random Relic.
- **Reward sources**: Combat stays gold+XP only. Elite additionally grants
  a random Equipment item. Boss additionally grants a random Relic.
  Treasure grants a random Relic. Shop sells Cards (existing) + Equipment
  + Potions (new) — Relics are never purchasable, only found.
- **A new "Inventory" screen**: a second persistent map button (alongside
  the existing "Skill Tree" one) showing owned Relics (read-only) and each
  Equipment slot with Equip/Unequip controls.
- **One opportunistic cleanup**: Plan 2C's final review flagged
  `SkillNode.passive_id` as dead data (dispatch was hardcoded on id
  strings). Since Equipment's Trinket items need the same kind of passive
  dispatch, this plan generalizes it into one real, shared mechanism
  (two well-known passive ids) instead of adding a second copy of the
  hardcoded-string pattern.

**Explicitly out of scope (deferred):**

- Camp/Renown persistent economy interactions with items (Plan 3).
- Equipment/Relic effects beyond the safe, already-proven vocabulary
  (Strength/Block bonuses, one-shot starting Block, Strength status
  stacks, gold bonus) — no new turn-loop hooks, no card-granting
  equipment, no equipment upgrade/enchanting system.
- Relic or Equipment rarity tiers or weighted drop tables — reward grants
  are a flat "one guaranteed X" per elevated node type, not a loot table.
- Potion crafting/combining, more than 2 potion slots.
- A forced Treasure-node guarantee.

## 2. Data model & the passive-dispatch cleanup

**New resources:**

- `EquipmentResource` (`scripts/resources/equipment_resource.gd`,
  `extends Resource`): `id: StringName`, `display_name: String`,
  `slot: Slot` enum `{WEAPON, ARMOR, TRINKET}`, `description: String`,
  `strength_delta: int = 0`, `block_delta: int = 0`,
  `passive_id: StringName = &""`.
- `RelicResource` (`scripts/resources/relic_resource.gd`): `id`,
  `display_name`, `description`, `strength_delta: int = 0`,
  `block_delta: int = 0`, `vitality_delta: int = 0`,
  `gold_bonus_per_reward: int = 0`.
- `PotionResource` (`scripts/resources/potion_resource.gd`): `id`,
  `display_name`, `description`, `heal_amount: int = 0`,
  `strength_stacks: int = 0`, plus `func apply(actor: CombatActor) -> void`
  (calls `actor.heal(heal_amount)` if nonzero, `actor.add_status(&"strength",
  strength_stacks)` if nonzero).

**The passive-dispatch generalization:** today `build_encounter_for_node`
checks `unlocked_skill_nodes.has(&"battle_fury")` /
`.has(&"unyielding")` by literal id. This plan introduces two well-known,
reusable passive identifiers — `&"bonus_strength_stack"` and
`&"bonus_starting_block"` — and one small helper any *equipped or
unlocked* source (skill nodes, equipped items) can declare via its own
`passive_id` field:

```gdscript
func _apply_passive(passive_id: StringName, player: CombatActor) -> void:
	match passive_id:
		&"bonus_strength_stack":
			player.add_status(&"strength", 2)
		&"bonus_starting_block":
			player.starting_block += 5
		_:
			pass
```

`build_encounter_for_node` calls `_apply_passive(node.passive_id, player)`
for each unlocked skill node and `_apply_passive(item.passive_id, player)`
for each non-null equipped item, instead of separate hardcoded `.has(...)`
checks. The two existing skill nodes (`battle_fury`, `unyielding`) get
their `passive_id` fields changed to these two shared ids — their own
`id` is unchanged, so `unlocked_skill_nodes` and every existing Plan 2C
test keep working unmodified.

**`RunState` additions:**

```gdscript
# Equipment (swappable — never touches player_max_hp)
var owned_equipment: Array[EquipmentResource] = []
var equipped_weapon: EquipmentResource = null
var equipped_armor: EquipmentResource = null
var equipped_trinket: EquipmentResource = null

# Relics (permanent, unlimited)
var unlocked_relics: Array[StringName] = []
var relic_bonus_strength: int = 0
var relic_bonus_block: int = 0
var relic_gold_bonus: int = 0

# Potions (max 2)
const MAX_POTIONS := 2
var potions: Array[PotionResource] = []
```

All reset in `start_new_run`. New methods:

- `equip_item(item: EquipmentResource) -> void` — sets the slot matching
  `item.slot` (item must already be in `owned_equipment`).
- `unequip_slot(slot: EquipmentResource.Slot) -> void`.
- `grant_relic(relic: RelicResource) -> void` — mirrors
  `unlock_skill_node`'s effect-application shape exactly (adds deltas to
  the bonus fields, bakes `vitality_delta * 2` into `player_max_hp`/
  `player_current_hp` permanently, since relics are never removed).
- `grant_equipment(item: EquipmentResource) -> void` — appends to
  `owned_equipment` only (does not auto-equip).
- `add_potion(potion: PotionResource) -> bool` — returns `false` if
  already at `MAX_POTIONS`.
- `consume_potion(index: int) -> PotionResource` — removes and returns
  the potion at that index.

**`build_encounter_for_node`** gains, after the existing skill-node lines:

```gdscript
var equip_strength: int = 0
var equip_block: int = 0
for item in [equipped_weapon, equipped_armor, equipped_trinket]:
	if item != null:
		equip_strength += item.strength_delta
		equip_block += item.block_delta
		_apply_passive(item.passive_id, player)
player.baseline_strike_bonus += relic_bonus_strength + equip_strength
player.baseline_block_bonus += relic_bonus_block + equip_block
```

**`CombatActor.heal(amount: int) -> void`** (new, mirrors `take_damage`'s
clamping): `current_hp = min(current_hp + amount, max_hp) as int`.

**`apply_combat_reward`** gains `gold_reward += relic_gold_bonus` before
adding to `gold`.

## 3. Content

**Equipment** (`scripts/content/dwarf_equipment.gd`,
`static func get_all_equipment() -> Array[EquipmentResource]`):

| id | display_name | slot | strength_delta | block_delta | passive_id |
|---|---|---|---|---|---|
| `&"rusty_shortsword"` | Rusty Shortsword | WEAPON | 2 | 0 | `&""` |
| `&"dwarven_warhammer"` | Dwarven Warhammer | WEAPON | 4 | 0 | `&""` |
| `&"leather_vest"` | Leather Vest | ARMOR | 0 | 2 | `&""` |
| `&"chainmail"` | Chainmail | ARMOR | 0 | 4 | `&""` |
| `&"lucky_charm"` | Lucky Charm | TRINKET | 0 | 0 | `&"bonus_strength_stack"` |
| `&"guardian_amulet"` | Guardian Amulet | TRINKET | 0 | 0 | `&"bonus_starting_block"` |

**Relics** (`scripts/content/dwarf_relics.gd`,
`static func get_all_relics() -> Array[RelicResource]`, one random relic
granted per Boss/Treasure via `get_random_relic(rng)`):

| id | display_name | strength_delta | block_delta | vitality_delta | gold_bonus_per_reward |
|---|---|---|---|---|---|
| `&"iron_ration"` | Iron Ration | 0 | 0 | 3 | 0 |
| `&"whetstone"` | Whetstone | 2 | 0 | 0 | 0 |
| `&"reinforced_buckle"` | Reinforced Buckle | 0 | 2 | 0 | 0 |
| `&"merchants_ledger"` | Merchant's Ledger | 0 | 0 | 0 | 5 |

**Potions** (`scripts/content/dwarf_potions.gd`,
`static func get_all_potions() -> Array[PotionResource]`, used to stock
the Shop):

| id | display_name | heal_amount | strength_stacks |
|---|---|---|---|
| `&"healing_draught"` | Healing Draught | 10 | 0 |
| `&"vigor_tonic"` | Vigor Tonic | 0 | 3 |

Elite nodes grant a random `EquipmentResource` from the full 6-item pool
(regardless of slot). Boss and Treasure nodes each grant a random Relic
from the 4. Shop sells all 6 equipment items and both potions for gold
(exact prices pinned in the implementation plan, following
`SHOP_CARD_PRICE`'s precedent).

## 4. Scenes & orchestration

- **`MapNode.NodeType`** gains `TREASURE`.
  **`MapGraph._pick_weighted_node_type`** adds `MapNode.NodeType.TREASURE`
  once to the existing weighted pool (same weight as `SHOP`/`ELITE`) — no
  per-floor cap needed (unlike Rest).
- **`RunScene._on_map_node_selected`**'s `match` gains a `TREASURE` case:
  grants a random relic via `RunState.grant_relic(DwarfRelics.get_random_relic(RunState.rng))`,
  then behaves like Rest/Event/Shop — marks the node visited and returns
  to the map immediately, no dedicated scene, no popup.
- **`RunScene._on_combat_dismissed`**'s win branch gains: for `ELITE`
  nodes, `RunState.grant_equipment(DwarfEquipment.get_random_equipment(RunState.rng))`;
  for `BOSS` nodes, `RunState.grant_relic(DwarfRelics.get_random_relic(RunState.rng))`
  (applied before the existing Victory-screen branch).
- **`MapView`** gains a second persistent button, `inventory_button`,
  next to `skill_tree_button`, emitting `signal inventory_requested`.
  `RunScene` wires it to swap to a new `InventoryScene` exactly like
  `SkillTreeScene` (a `back_requested` signal returning to the map, no
  node advancement).
- **`InventoryScene`** (new, `scripts/ui/run/inventory_scene.gd`): three
  sections — **Relics** (read-only list of `RunState.unlocked_relics`,
  rendered `"{display_name}: {description}"`); **Equipment** (one row per
  slot showing the currently equipped item or "— empty —" with an
  Unequip button, plus owned-but-unequipped items for that slot with an
  Equip button each — clicking Equip calls `RunState.equip_item(item)`
  and refreshes, Unequip calls `RunState.unequip_slot(slot)`); **Potions**
  (read-only list of `RunState.potions`). A `back_button` emits
  `back_requested`.
- **`ShopScene`** gains two more sections alongside the existing card
  offerings: Equipment (all 6 items, same buy-disabled-when-poor pattern
  as cards) and Potions (both potions, disabled when
  `RunState.potions.size() >= MAX_POTIONS` in addition to the gold
  check). Buying equipment calls `RunState.grant_equipment(item)` (not
  auto-equipped); buying a potion calls `RunState.add_potion(potion)`.
- **`CombatScene`** gains a `potion_container` row (visible only when
  `RunState.potions` is non-empty), one button per potion, text
  `"{display_name}: {description}"`. Clicking one calls
  `potion.apply(encounter.player)`, then
  `RunState.consume_potion(index)`, then refreshes — no energy cost,
  doesn't end the turn, doesn't call `encounter.play_card`.

## 5. Testing

Explicitly carrying forward the lesson from Plan 2C's final review: a
test that only checks state *immediately after* `build_encounter_for_node`
(before any turn has started) can miss a bug where the turn loop clears
that state. Every passive-effect test here must call
`encounter.start_player_turn()` before asserting on anything the turn
loop touches.

- **`EquipmentResource`/`DwarfEquipment`**: 6 well-formed items, correct
  slot per item, `get_random_equipment` returns one of the known 6.
- **`RelicResource`/`DwarfRelics`**: 4 well-formed relics,
  `get_random_relic` returns one of the known 4.
- **`PotionResource`/`DwarfPotions`**: 2 well-formed potions;
  `PotionResource.apply()` correctly heals or grants Strength stacks.
- **`CombatActor.heal()`**: clamps to `max_hp`, doesn't affect `block`.
- **`RunState.equip_item`/`unequip_slot`**: equipping fills the right
  slot without touching others; equipping a second item in the same slot
  replaces the first (the replaced item stays in `owned_equipment`, just
  unequipped); unequip sets the slot back to `null`.
- **`RunState.grant_relic`**: applies deltas like `unlock_skill_node`
  (strength/block bonus fields, permanent HP increase for vitality);
  granting the same relic twice stacks (no "already unlocked" rejection —
  relics aren't a limited-points system).
- **`RunState.grant_equipment`**: appends to `owned_equipment` without
  auto-equipping.
- **`RunState.add_potion`/`consume_potion`**: rejects past `MAX_POTIONS`;
  consuming removes and returns the right potion.
- **`RunState.apply_combat_reward`**: gold reward increases by
  `relic_gold_bonus` when `merchants_ledger` is unlocked.
- **`RunState.build_encounter_for_node`** (extending Plan 2C's existing
  tests): equipped Weapon/Armor/Trinket bonuses show up in
  `baseline_strike_bonus`/`baseline_block_bonus`; a Trinket's
  `bonus_strength_stack`/`bonus_starting_block` passive is verified
  **after** `encounter.start_player_turn()`; relic bonuses stack
  additively alongside skill-tree and equipment bonuses in one composed
  test.
- **`MapGraph.generate`**: `TREASURE` appears in generated maps across
  enough seeds to confirm reachability (a probabilistic check across
  seeds 1-20, matching the existing per-seed loop pattern).
- **`InventoryScene`**: Equip/Unequip buttons call the real `RunState`
  methods via real `pressed` signals and refresh correctly; Relic list
  reflects `RunState.unlocked_relics`; `back_button` emits
  `back_requested`.
- **`ShopScene`** (extending Plan 2B's tests): Equipment/Potion buy
  buttons disabled appropriately (poor, or potions-full); buying calls
  the right `RunState` methods.
- **`CombatScene`** (extending Plan 2A's tests): clicking a potion button
  applies its effect and removes it from `RunState.potions`, without
  ending the turn or spending Energy — verified by checking
  `encounter.energy` is unchanged and the turn UI is still showing.
- **`RunScene`** (extending Plan 2B/2C's tests): selecting a `TREASURE`
  node grants a relic and returns to the map without a dedicated scene;
  winning an Elite grants equipment; winning the Boss grants a relic; the
  Inventory button swaps to `InventoryScene` and back without advancing
  run position.

**Manual verification** (same non-negotiable standard as every prior
plan): play a full Act, visit a Treasure node, win an Elite and the Boss,
confirm equipment/relics appear in the Inventory screen, equip/unequip
gear and confirm Strength/Block numbers change in the next fight, buy a
potion from the Shop and use it mid-combat, and specifically re-verify in
an actual fight that a Trinket's passive is visible at the start of the
very first turn.

## Open items for later (explicitly out of scope now)

- Camp/Renown persistent economy interactions with items.
- Rarity tiers, weighted drop tables.
- Potion crafting, more potion slots.
- A forced Treasure-node guarantee.
- Equipment/Relic effects beyond the safe, proven stat/passive vocabulary.
