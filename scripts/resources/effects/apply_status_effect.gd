extends CardEffect
class_name ApplyStatusEffect

@export var status_id: StringName = &""
@export var stacks: int = 0
@export var apply_to_source: bool = false

func apply(context: EffectContext) -> void:
	var actor := context.source if apply_to_source else context.target
	actor.add_status(status_id, stacks)
