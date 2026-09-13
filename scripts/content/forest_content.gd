extends RefCounted
class_name ForestContent

# An Act's first fight happens at the forest's edge, before the dungeon
# entrance proper — see docs/design/look-and-feel/Combat.dc.html. Wired
# to an Act's first-floor combat nodes in RunState.build_encounter_for_node
# (only one Act exists today, so this is the run's first fight for now).

static func get_enemy_resource() -> EnemyResource:
	var enemy_res := EnemyResource.new()
	enemy_res.id = &"coypu"
	enemy_res.display_name = "Coypu"
	enemy_res.max_hp = 16
	enemy_res.moves = [_make_bite_move(), _make_hiss_move()]
	return enemy_res

static func _make_bite_move() -> EnemyMove:
	var move := EnemyMove.new()
	move.intent_type = EnemyMove.IntentType.ATTACK
	var effect := DamageEffect.new()
	effect.amount = 4
	move.effects = [effect]
	move.description = "The coypu lunges, its orange incisors bared."
	move.display_value = 4
	return move

static func _make_hiss_move() -> EnemyMove:
	var move := EnemyMove.new()
	move.intent_type = EnemyMove.IntentType.BUFF
	var effect := ApplyStatusEffect.new()
	effect.status_id = &"strength"
	effect.stacks = 1
	effect.apply_to_source = true
	move.effects = [effect]
	move.description = "The coypu hisses, puffing up to guard its burrow."
	move.display_value = 1
	return move
