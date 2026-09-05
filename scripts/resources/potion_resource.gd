extends Resource
class_name PotionResource

@export var id: StringName
@export var display_name: String = ""
@export var description: String = ""
@export var heal_amount: int = 0
@export var strength_stacks: int = 0

func apply(actor: CombatActor) -> void:
	if heal_amount > 0:
		actor.heal(heal_amount)
	if strength_stacks > 0:
		actor.add_status(&"strength", strength_stacks)
