extends Node

# Autoload singleton, registered in project.godot as "RunState" — do not
# add `class_name` here; autoloads are addressed by their global name,
# and a class_name on top of that would create a second, unused identity.

const COMBAT_GOLD_REWARD := 10
const ELITE_GOLD_REWARD := 20
const BOSS_GOLD_REWARD := 30
const SHOP_CARD_PRICE := 15
const MAX_LEVEL := 7
const XP_THRESHOLDS: Array[int] = [20, 30, 40, 55, 70, 90]
const COMBAT_XP_REWARD := 15
const ELITE_XP_REWARD := 30
const BOSS_XP_REWARD := 50
const MAX_POTIONS := 2

var class_resource: ClassResource
var persistent_stats: PersistentStats
var deck: Array[CardResource] = []
var player_max_hp: int = 0
var player_current_hp: int = 0
var gold: int = 0
var map: MapGraph
var current_floor: int = 0
var current_node: MapNode
var rng: RandomNumberGenerator
var level: int = 1
var xp: int = 0
var skill_points: int = 0
var unlocked_skill_nodes: Array[StringName] = []
var level_bonus_strength: int = 0
var level_bonus_block: int = 0
var owned_equipment: Array[EquipmentResource] = []
var equipped_weapon: EquipmentResource = null
var equipped_armor: EquipmentResource = null
var equipped_trinket: EquipmentResource = null
var unlocked_relics: Array[StringName] = []
var relic_bonus_strength: int = 0
var relic_bonus_block: int = 0
var relic_gold_bonus: int = 0
var potions: Array[PotionResource] = []

func start_new_run(p_class_resource: ClassResource) -> void:
	class_resource = p_class_resource
	persistent_stats = PersistentStats.new()
	deck = class_resource.starting_deck.duplicate()
	player_max_hp = persistent_stats.compute_max_hp(class_resource.base_hp)
	player_current_hp = player_max_hp
	gold = 0
	level = 1
	xp = 0
	skill_points = 0
	unlocked_skill_nodes = []
	level_bonus_strength = 0
	level_bonus_block = 0
	owned_equipment = []
	equipped_weapon = null
	equipped_armor = null
	equipped_trinket = null
	unlocked_relics = []
	relic_bonus_strength = 0
	relic_bonus_block = 0
	relic_gold_bonus = 0
	potions = []
	rng = RandomNumberGenerator.new()
	rng.randomize()
	map = MapGraph.generate(rng)
	current_floor = 0
	current_node = map.floors[0][0]

func build_encounter_for_node(node: MapNode) -> CombatEncounter:
	var player := ActorFactory.build_player_actor(class_resource, persistent_stats)
	player.max_hp = player_max_hp
	player.current_hp = min(player_current_hp, player.max_hp) as int
	player.baseline_strike_bonus += level_bonus_strength
	player.baseline_block_bonus += level_bonus_block
	if unlocked_skill_nodes.has(&"battle_fury"):
		player.add_status(&"strength", 2)
	if unlocked_skill_nodes.has(&"unyielding"):
		player.starting_block = 5
	var enemy_res: EnemyResource
	match node.node_type:
		MapNode.NodeType.ELITE:
			enemy_res = CaveRatContent.get_elite_enemy_resource()
		MapNode.NodeType.BOSS:
			enemy_res = CaveRatContent.get_boss_enemy_resource()
		_:
			enemy_res = CaveRatContent.get_enemy_resource()
	var enemy := ActorFactory.build_enemy_actor(enemy_res)
	return CombatEncounter.new(player, deck, enemy, enemy_res.moves, rng)

func grant_equipment(item: EquipmentResource) -> void:
	owned_equipment.append(item)

func equip_item(item: EquipmentResource) -> void:
	match item.slot:
		EquipmentResource.Slot.WEAPON:
			equipped_weapon = item
		EquipmentResource.Slot.ARMOR:
			equipped_armor = item
		EquipmentResource.Slot.TRINKET:
			equipped_trinket = item

func unequip_slot(slot: EquipmentResource.Slot) -> void:
	match slot:
		EquipmentResource.Slot.WEAPON:
			equipped_weapon = null
		EquipmentResource.Slot.ARMOR:
			equipped_armor = null
		EquipmentResource.Slot.TRINKET:
			equipped_trinket = null

func grant_relic(relic: RelicResource) -> void:
	unlocked_relics.append(relic.id)
	relic_bonus_strength += relic.strength_delta
	relic_bonus_block += relic.block_delta
	relic_gold_bonus += relic.gold_bonus_per_reward
	var hp_gain: int = relic.vitality_delta * 2
	player_max_hp += hp_gain
	player_current_hp += hp_gain

func add_potion(potion: PotionResource) -> bool:
	if potions.size() >= MAX_POTIONS:
		return false
	potions.append(potion)
	return true

func consume_potion(index: int) -> PotionResource:
	var potion: PotionResource = potions[index]
	potions.remove_at(index)
	return potion

func _apply_passive(passive_id: StringName, player: CombatActor) -> void:
	match passive_id:
		&"bonus_strength_stack":
			player.add_status(&"strength", 2)
		&"bonus_starting_block":
			player.starting_block += 5
		_:
			pass

func heal(amount: int) -> void:
	player_current_hp = min(player_current_hp + amount, player_max_hp) as int

func grant_xp(amount: int) -> void:
	if level >= MAX_LEVEL:
		return
	xp += amount
	while level < MAX_LEVEL and xp >= XP_THRESHOLDS[level - 1]:
		xp -= XP_THRESHOLDS[level - 1]
		level += 1
		skill_points += 1
	if level >= MAX_LEVEL:
		xp = 0

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

func upgrade_card(card_id: StringName) -> void:
	for i in range(deck.size()):
		if deck[i].id == card_id:
			var upgraded := DwarfContent.get_upgraded_card(card_id)
			if upgraded != null:
				deck[i] = upgraded
			return

func apply_event_choice(choice: EventChoice) -> void:
	var new_gold: int = gold + choice.gold_delta
	gold = max(new_gold, 0) as int
	var new_hp: int = player_current_hp + choice.hp_delta
	new_hp = max(new_hp, 0) as int
	player_current_hp = min(new_hp, player_max_hp) as int
	grant_xp(choice.xp_delta)

func buy_card(card_template: CardResource, price: int) -> bool:
	if gold < price:
		return false
	gold -= price
	deck.append(card_template.duplicate(true))
	return true

func apply_combat_reward(gold_reward: int, player_hp_after: int) -> void:
	gold += gold_reward + relic_gold_bonus
	player_current_hp = min(player_hp_after, player_max_hp) as int

func mark_node_visited_and_advance(node: MapNode) -> void:
	node.visited = true
	current_node = node
	current_floor = node.floor
