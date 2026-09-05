extends RefCounted
class_name CombatEncounter

signal state_changed
signal combat_ended(player_won: bool)

const MAX_HAND_SIZE := 5
const MAX_ENERGY := 3

var player: CombatActor
var enemy: CombatActor
var enemy_moves: Array[EnemyMove] = []
var enemy_move_index: int = 0

var draw_pile: Array[CardResource] = []
var hand: Array[CardResource] = []
var discard_pile: Array[CardResource] = []

var energy: int = 0
var is_over: bool = false
var player_won: bool = false

var rng: RandomNumberGenerator

func _init(p_player: CombatActor, p_deck: Array[CardResource], p_enemy: CombatActor, p_enemy_moves: Array[EnemyMove], p_rng: RandomNumberGenerator = null) -> void:
	player = p_player
	enemy = p_enemy
	enemy_moves = p_enemy_moves
	if p_rng != null:
		rng = p_rng
	else:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	draw_pile = p_deck.duplicate()
	_shuffle_draw_pile()

func start_player_turn() -> void:
	energy = MAX_ENERGY
	player.clear_block()
	if player.starting_block > 0:
		player.add_block(player.starting_block)
		player.starting_block = 0
	_draw_hand()

func can_play_card(card: CardResource) -> bool:
	return not is_over and hand.has(card) and card.cost <= energy

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

func end_player_turn() -> void:
	discard_pile.append_array(hand)
	hand.clear()
	if not is_over:
		_run_enemy_turn()
	_check_combat_over()
	state_changed.emit()

func get_current_enemy_intent() -> EnemyMove:
	if enemy_moves.is_empty():
		push_error("EnemyMove list is empty for this encounter")
		return null
	return enemy_moves[enemy_move_index % enemy_moves.size()]

func _draw_hand() -> void:
	while hand.size() < MAX_HAND_SIZE:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile = discard_pile.duplicate()
			_shuffle_draw_pile()
			discard_pile.clear()
		hand.append(draw_pile.pop_back())

func _shuffle_draw_pile() -> void:
	# Fisher-Yates shuffle driven by `rng` so draws are reproducible when a
	# seeded RandomNumberGenerator is supplied to _init (Array.shuffle() always
	# consumes the engine-global RNG stream, not an external instance).
	for i in range(draw_pile.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp := draw_pile[i]
		draw_pile[i] = draw_pile[j]
		draw_pile[j] = tmp

func _run_enemy_turn() -> void:
	enemy.clear_block()
	var move := get_current_enemy_intent()
	if move == null:
		return
	var context := EffectContext.new(enemy, player)
	for effect in move.effects:
		effect.apply(context)
	enemy_move_index += 1
	_check_combat_over()

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
