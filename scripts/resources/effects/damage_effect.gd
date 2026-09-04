extends CardEffect
class_name DamageEffect

@export var amount: int = 0

func apply(context: EffectContext) -> void:
	var total := amount
	total += context.source.get_status_stacks(&"strength")
	total += context.source.baseline_strike_bonus
	context.target.take_damage(total)
