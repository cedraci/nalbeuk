extends Resource
class_name CardEffect

func apply(_context: EffectContext) -> void:
	push_error("CardEffect.apply() must be overridden by a subclass")
