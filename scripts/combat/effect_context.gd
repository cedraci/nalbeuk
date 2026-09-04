extends RefCounted
class_name EffectContext

var source: CombatActor
var target: CombatActor

func _init(p_source: CombatActor, p_target: CombatActor) -> void:
	source = p_source
	target = p_target
