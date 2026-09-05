extends GutTest

func test_block_effect_adds_block_to_target():
	var effect: BlockEffect = BlockEffect.new()
	effect.amount = 5
	var source := CombatActor.new("Source", 10)
	var target := CombatActor.new("Target", 10)
	var context := EffectContext.new(source, target)
	effect.apply(context)
	assert_eq(target.block, 5)

func test_block_effect_adds_source_baseline_block_bonus():
	var effect: BlockEffect = BlockEffect.new()
	effect.amount = 5
	var source := CombatActor.new("Source", 10)
	source.baseline_block_bonus = 3
	var target := CombatActor.new("Target", 10)
	var context := EffectContext.new(source, target)
	effect.apply(context)
	assert_eq(target.block, 8)
