extends Node

# Autoload singleton, registered in project.godot as "RunState" — do not
# add `class_name` here; autoloads are addressed by their global name,
# and a class_name on top of that would create a second, unused identity.

const COMBAT_GOLD_REWARD := 10
const ELITE_GOLD_REWARD := 20
const BOSS_GOLD_REWARD := 30
const SHOP_CARD_PRICE := 15

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

func start_new_run(p_class_resource: ClassResource) -> void:
	class_resource = p_class_resource
	persistent_stats = PersistentStats.new()
	deck = class_resource.starting_deck.duplicate()
	player_max_hp = persistent_stats.compute_max_hp(class_resource.base_hp)
	player_current_hp = player_max_hp
	gold = 0
	rng = RandomNumberGenerator.new()
	rng.randomize()
	map = MapGraph.generate(rng)
	current_floor = 0
	current_node = map.floors[0][0]

func build_encounter_for_node(node: MapNode) -> CombatEncounter:
	var player := ActorFactory.build_player_actor(class_resource, persistent_stats)
	player.current_hp = min(player_current_hp, player.max_hp) as int
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

func heal(amount: int) -> void:
	player_current_hp = min(player_current_hp + amount, player_max_hp) as int

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

func buy_card(card_template: CardResource, price: int) -> bool:
	if gold < price:
		return false
	gold -= price
	deck.append(card_template.duplicate(true))
	return true

func apply_combat_reward(gold_reward: int, player_hp_after: int) -> void:
	gold += gold_reward
	player_current_hp = min(player_hp_after, player_max_hp) as int

func mark_node_visited_and_advance(node: MapNode) -> void:
	node.visited = true
	current_node = node
	current_floor = node.floor
