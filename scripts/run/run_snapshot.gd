extends RefCounted
class_name RunSnapshot

# Captures the in-progress run held by RunState into an id-only, JSON-safe
# dictionary, and restores it. Level/XP/skills are deliberately absent:
# they are never-lost state that RunState.load_character_from_meta()
# already seeds from MetaState.

static func capture() -> Dictionary:
	if RunState.map == null or RunState.current_node == null or RunState.rng == null:
		push_warning("RunSnapshot.capture called with no run in progress")
		return {}
	var deck_ids: Array = []
	for card in RunState.deck:
		deck_ids.append(String(card.id))
	var relic_ids: Array = []
	for relic_id in RunState.unlocked_relics:
		relic_ids.append(String(relic_id))
	var potion_ids: Array = []
	for potion in RunState.potions:
		potion_ids.append(String(potion.id))
	var gear_ids: Array = []
	for item in RunState.owned_equipment:
		gear_ids.append(String(item.id))
	return {
		"current_floor": RunState.current_floor,
		"current_node_id": RunState.current_node.id,
		"map": RunState.map.to_dict(),
		"deck": deck_ids,
		"player_max_hp": RunState.player_max_hp,
		"player_current_hp": RunState.player_current_hp,
		"gold": RunState.gold,
		"relic_ids": relic_ids,
		"potion_ids": potion_ids,
		"owned_equipment_ids": gear_ids,
		"equipped_weapon_id": _slot_id(RunState.equipped_weapon),
		"equipped_armor_id": _slot_id(RunState.equipped_armor),
		"equipped_trinket_id": _slot_id(RunState.equipped_trinket),
		# 64-bit ints do not survive JSON's doubles; stored as strings.
		"rng_seed": str(RunState.rng.seed),
		"rng_state": str(RunState.rng.state),
	}

static func restore(data: Dictionary) -> bool:
	# Structural checks first: nothing is written unless the map and the
	# current node resolve.
	var raw_map: Variant = data.get("map", null)
	if not (raw_map is Dictionary):
		return false
	var graph := MapGraph.from_dict(raw_map)
	if graph == null:
		return false
	var node := graph.find_node(int(data.get("current_node_id", -1)))
	if node == null:
		return false

	RunState.map = graph
	RunState.current_node = node
	RunState.current_floor = int(data.get("current_floor", node.floor))

	var deck: Array[CardResource] = []
	for raw in _array(data, "deck"):
		var card := DwarfContent.get_card_by_id(StringName(str(raw)))
		if card == null:
			push_warning("RunSnapshot: unknown card '%s' skipped" % str(raw))
			continue
		deck.append(card)
	if deck.is_empty():
		push_warning("RunSnapshot: deck empty after restore; using the starting deck")
		deck = RunState.class_resource.starting_deck.duplicate()
	RunState.deck = deck

	var owned: Array[EquipmentResource] = []
	for raw in _array(data, "owned_equipment_ids"):
		var item := DwarfEquipment.get_by_id(StringName(str(raw)))
		if item == null:
			push_warning("RunSnapshot: unknown equipment '%s' skipped" % str(raw))
			continue
		owned.append(item)
	RunState.owned_equipment = owned
	RunState.equipped_weapon = _find_owned(owned, str(data.get("equipped_weapon_id", "")))
	RunState.equipped_armor = _find_owned(owned, str(data.get("equipped_armor_id", "")))
	RunState.equipped_trinket = _find_owned(owned, str(data.get("equipped_trinket_id", "")))

	var relic_ids: Array[StringName] = []
	var relic_strength: int = 0
	var relic_block: int = 0
	var relic_gold: int = 0
	for raw in _array(data, "relic_ids"):
		var relic := DwarfRelics.get_by_id(StringName(str(raw)))
		if relic == null:
			push_warning("RunSnapshot: unknown relic '%s' skipped" % str(raw))
			continue
		relic_ids.append(relic.id)
		relic_strength += relic.strength_delta
		relic_block += relic.block_delta
		relic_gold += relic.gold_bonus_per_reward
	# Relic vitality is not re-applied: it is already baked into the saved max HP.
	RunState.unlocked_relics = relic_ids
	RunState.relic_bonus_strength = relic_strength
	RunState.relic_bonus_block = relic_block
	RunState.relic_gold_bonus = relic_gold

	var potions: Array[PotionResource] = []
	for raw in _array(data, "potion_ids"):
		if potions.size() >= RunState.MAX_POTIONS:
			break
		var potion := DwarfPotions.get_by_id(StringName(str(raw)))
		if potion == null:
			push_warning("RunSnapshot: unknown potion '%s' skipped" % str(raw))
			continue
		potions.append(potion)
	RunState.potions = potions

	RunState.player_max_hp = maxi(int(data.get("player_max_hp", RunState.player_max_hp)), 1)
	RunState.player_current_hp = clampi(int(data.get("player_current_hp", RunState.player_max_hp)), 0, RunState.player_max_hp)
	RunState.gold = maxi(int(data.get("gold", 0)), 0)

	var rng := RandomNumberGenerator.new()
	rng.seed = str(data.get("rng_seed", "0")).to_int()
	rng.state = str(data.get("rng_state", "0")).to_int()
	RunState.rng = rng
	return true

static func _array(data: Dictionary, key: String) -> Array:
	var raw: Variant = data.get(key, [])
	if raw is Array:
		return raw
	return []

static func _slot_id(item: EquipmentResource) -> String:
	return String(item.id) if item != null else ""

static func _find_owned(owned: Array[EquipmentResource], raw_id: String) -> EquipmentResource:
	var item_id := StringName(raw_id)
	if item_id == &"":
		return null
	for item in owned:
		if item.id == item_id:
			return item
	return null
