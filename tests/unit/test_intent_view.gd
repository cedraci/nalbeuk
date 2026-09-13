extends GutTest

func test_display_shows_an_icon_and_the_value_when_positive():
	var view := IntentView.new()
	add_child_autofree(view)
	var move := EnemyMove.new()
	move.intent_type = EnemyMove.IntentType.ATTACK
	move.display_value = 5
	move.description = "The Cave Rat lunges with its teeth."
	view.display(move)
	assert_not_null(view.icon_rect.texture)
	assert_true(view.count_label.visible)
	assert_eq(view.count_label.text, "5")
	assert_eq(view.tooltip_text, "The Cave Rat lunges with its teeth.")

func test_display_hides_the_count_when_value_is_zero():
	var view := IntentView.new()
	add_child_autofree(view)
	var move := EnemyMove.new()
	move.intent_type = EnemyMove.IntentType.DEBUFF
	move.display_value = 0
	view.display(move)
	assert_false(view.count_label.visible)

func test_display_picks_a_distinct_icon_per_intent_type():
	var view := IntentView.new()
	add_child_autofree(view)
	var attack := EnemyMove.new()
	attack.intent_type = EnemyMove.IntentType.ATTACK
	view.display(attack)
	var attack_icon := view.icon_rect.texture
	var defend := EnemyMove.new()
	defend.intent_type = EnemyMove.IntentType.DEFEND
	view.display(defend)
	assert_ne(view.icon_rect.texture, attack_icon)
