extends GutTest

func test_block_effect_adds_block_to_target():
	var effect: BlockEffect = BlockEffect.new()
	effect.amount = 5
	var source := CombatActor.new("Source", 10)
	var target := CombatActor.new("Target", 10)
	var context := EffectContext.new(source, target)
	effect.apply(context)
	assert_eq(target.block, 5)
