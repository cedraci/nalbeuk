extends RunStateTest

func test_display_shows_description_and_one_button_per_choice():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var scene := EventScene.new()
	add_child_autofree(scene)
	var event := EventsContent.get_all_events()[0]
	scene.display(event)
	assert_eq(scene.description_label.text, event.description)
	assert_eq(scene.choices_container.get_child_count(), event.choices.size())
	assert_true(scene.choices_container.visible)
	assert_false(scene.outcome_label.visible)
	assert_false(scene.continue_button.visible)

func test_clicking_a_choice_applies_it_and_shows_the_outcome():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.gold = 15
	var initial_gold: int = RunState.gold
	var scene := EventScene.new()
	add_child_autofree(scene)
	# get_all_events()[0] is the toll-troll event; its first choice pays 10 gold.
	var event := EventsContent.get_all_events()[0]
	scene.display(event)
	var pay_button: Button = scene.choices_container.get_child(0)
	pay_button.pressed.emit()
	assert_eq(RunState.gold, initial_gold - 10)
	assert_false(scene.choices_container.visible)
	assert_true(scene.outcome_label.visible)
	assert_eq(scene.outcome_label.text, event.choices[0].outcome_text)
	assert_true(scene.continue_button.visible)

func test_continue_button_emits_node_completed():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var scene := EventScene.new()
	add_child_autofree(scene)
	scene.display(EventsContent.get_all_events()[0])
	watch_signals(scene)
	scene.continue_button.pressed.emit()
	assert_signal_emitted(scene, "node_completed")
