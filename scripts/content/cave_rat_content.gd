extends RefCounted
class_name CaveRatContent

static func get_enemy_resource() -> EnemyResource:
	var enemy_res := EnemyResource.new()
	enemy_res.id = &"cave_rat"
	enemy_res.display_name = "Cave Rat"
	enemy_res.max_hp = 18
	enemy_res.moves = [_make_bite_move(), _make_screech_move()]
	return enemy_res

static func get_elite_enemy_resource() -> EnemyResource:
	var enemy_res := EnemyResource.new()
	enemy_res.id = &"alpha_cave_rat"
	enemy_res.display_name = "Alpha Cave Rat"
	enemy_res.max_hp = 32
	enemy_res.moves = [_make_elite_bite_move(), _make_screech_move()]
	return enemy_res

static func get_boss_enemy_resource() -> EnemyResource:
	var enemy_res := EnemyResource.new()
	enemy_res.id = &"cave_rat_matriarch"
	enemy_res.display_name = "Cave Rat Matriarch"
	enemy_res.max_hp = 45
	enemy_res.moves = [_make_boss_bite_move(), _make_boss_screech_move()]
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

static func _make_elite_bite_move() -> EnemyMove:
	var move := EnemyMove.new()
	move.intent_type = EnemyMove.IntentType.ATTACK
	var effect := DamageEffect.new()
	effect.amount = 8
	move.effects = [effect]
	move.description = "The Alpha Cave Rat lunges hard with its teeth."
	move.display_value = 8
	return move

static func _make_boss_bite_move() -> EnemyMove:
	var move := EnemyMove.new()
	move.intent_type = EnemyMove.IntentType.ATTACK
	var effect := DamageEffect.new()
	effect.amount = 10
	move.effects = [effect]
	move.description = "The Cave Rat Matriarch bites down with bone-cracking force."
	move.display_value = 10
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

static func _make_boss_screech_move() -> EnemyMove:
	var move := EnemyMove.new()
	move.intent_type = EnemyMove.IntentType.DEBUFF
	var effect := ApplyStatusEffect.new()
	effect.status_id = &"weak"
	effect.stacks = 2
	effect.apply_to_source = false
	move.effects = [effect]
	move.description = "The Cave Rat Matriarch's shriek rattles your resolve."
	return move
