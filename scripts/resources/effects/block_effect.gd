extends CardEffect
class_name BlockEffect

@export var amount: int = 0

func apply(context: EffectContext) -> void:
	context.target.add_block(amount + context.source.baseline_block_bonus)
