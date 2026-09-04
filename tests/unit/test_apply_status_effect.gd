extends GutTest

func test_apply_status_effect_targets_target_by_default():
	var effect: ApplyStatusEffect = ApplyStatusEffect.new()
	effect.status_id = &"weak"
	effect.stacks = 2
	var source := CombatActor.new("Source", 10)
	var target := CombatActor.new("Target", 10)
	var context := EffectContext.new(source, target)
	effect.apply(context)
	assert_eq(target.get_status_stacks(&"weak"), 2)
	assert_eq(source.get_status_stacks(&"weak"), 0)

func test_apply_status_effect_can_target_source():
	var effect: ApplyStatusEffect = ApplyStatusEffect.new()
	effect.status_id = &"strength"
	effect.stacks = 3
	effect.apply_to_source = true
	var source := CombatActor.new("Source", 10)
	var target := CombatActor.new("Target", 10)
	var context := EffectContext.new(source, target)
	effect.apply(context)
	assert_eq(source.get_status_stacks(&"strength"), 3)
	assert_eq(target.get_status_stacks(&"strength"), 0)
