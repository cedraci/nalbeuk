extends RefCounted
class_name ForestContent

# The party's very first fight happens at the forest's edge, before the
# dungeon entrance proper — see docs/design/look-and-feel/Combat.dc.html.
# Wired to floor 0's regular combat nodes in RunState.build_encounter_for_node.

static func get_enemy_resource() -> EnemyResource:
	var enemy_res := EnemyResource.new()
	enemy_res.id = &"forest_wolf"
	enemy_res.display_name = "Forest Wolf"
	enemy_res.max_hp = 16
	enemy_res.moves = [_make_bite_move(), _make_howl_move()]
	return enemy_res

static func _make_bite_move() -> EnemyMove:
	var move := EnemyMove.new()
	move.intent_type = EnemyMove.IntentType.ATTACK
	var effect := DamageEffect.new()
	effect.amount = 4
	move.effects = [effect]
	move.description = "The wolf snaps at you with bared teeth."
	move.display_value = 4
	return move

static func _make_howl_move() -> EnemyMove:
	var move := EnemyMove.new()
	move.intent_type = EnemyMove.IntentType.BUFF
	var effect := ApplyStatusEffect.new()
	effect.status_id = &"strength"
	effect.stacks = 1
	effect.apply_to_source = true
	move.effects = [effect]
	move.description = "The wolf howls, its pack instinct sharpening its bite."
	move.display_value = 1
	return move
