extends GutTest

func test_display_shows_intent_type_and_value_when_positive():
	var view := IntentView.new()
	add_child_autofree(view)
	var move := EnemyMove.new()
	move.intent_type = EnemyMove.IntentType.ATTACK
	move.display_value = 5
	move.description = "The Cave Rat lunges with its teeth."
	view.display(move)
	assert_eq(view.label.text, "ATTACK 5")
	assert_eq(view.label.tooltip_text, "The Cave Rat lunges with its teeth.")

func test_display_shows_only_intent_type_when_value_is_zero():
	var view := IntentView.new()
	add_child_autofree(view)
	var move := EnemyMove.new()
	move.intent_type = EnemyMove.IntentType.DEBUFF
	move.display_value = 0
	view.display(move)
	assert_eq(view.label.text, "DEBUFF")
