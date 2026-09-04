extends RefCounted
class_name CaveRatContent

static func get_enemy_resource() -> EnemyResource:
	var enemy_res := EnemyResource.new()
	enemy_res.id = &"cave_rat"
	enemy_res.display_name = "Cave Rat"
	enemy_res.max_hp = 18
	enemy_res.moves = [_make_bite_move(), _make_screech_move()]
	return enemy_res

static func _make_bite_move() -> EnemyMove:
	var move := EnemyMove.new()
	move.intent_type = EnemyMove.IntentType.ATTACK
	var effect := DamageEffect.new()
	effect.amount = 5
	move.effects = [effect]
	move.description = "The Cave Rat lunges with its teeth."
	move.display_value = 5
	return move

static func _make_screech_move() -> EnemyMove:
	var move := EnemyMove.new()
	move.intent_type = EnemyMove.IntentType.DEBUFF
	var effect := ApplyStatusEffect.new()
	effect.status_id = &"weak"
	effect.stacks = 1
	effect.apply_to_source = false
	move.effects = [effect]
	move.description = "The Cave Rat lets out a piercing screech, weakening its foe."
	return move
