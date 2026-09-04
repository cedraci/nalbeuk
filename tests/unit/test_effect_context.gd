extends GutTest

func test_context_stores_source_and_target():
	var source := CombatActor.new("Source", 10)
	var target := CombatActor.new("Target", 10)
	var context := EffectContext.new(source, target)
	assert_eq(context.source, source)
	assert_eq(context.target, target)
