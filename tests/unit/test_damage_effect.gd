extends GutTest

func test_damage_effect_deals_flat_amount():
	var effect: DamageEffect = DamageEffect.new()
	effect.amount = 6
	var source := CombatActor.new("Source", 10)
	var target := CombatActor.new("Target", 20)
	var context := EffectContext.new(source, target)
	effect.apply(context)
	assert_eq(target.current_hp, 14)

func test_damage_effect_adds_source_strength_stacks():
	var effect: DamageEffect = DamageEffect.new()
	effect.amount = 6
	var source := CombatActor.new("Source", 10)
	source.add_status(&"strength", 3)
	var target := CombatActor.new("Target", 20)
	var context := EffectContext.new(source, target)
	effect.apply(context)
	assert_eq(target.current_hp, 11)

func test_damage_effect_adds_source_baseline_strike_bonus():
	var effect: DamageEffect = DamageEffect.new()
	effect.amount = 6
	var source := CombatActor.new("Source", 10, 4)
	var target := CombatActor.new("Target", 20)
	var context := EffectContext.new(source, target)
	effect.apply(context)
	assert_eq(target.current_hp, 10)
