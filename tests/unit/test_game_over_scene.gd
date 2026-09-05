extends RunStateTest

func test_ready_shows_the_floor_reached():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.current_floor = 3
	var scene := GameOverScene.new()
	add_child_autofree(scene)
	assert_eq(scene.result_label.text, "You died on floor 3.")

func test_ready_shows_what_was_lost():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.grant_equipment(DwarfEquipment.get_by_id(&"chainmail"))
	RunState.grant_equipment(DwarfEquipment.get_by_id(&"lucky_charm"))
	RunState.xp = 15
	var scene := GameOverScene.new()
	scene.outcome = RunState.finish_run(false)
	add_child_autofree(scene)
	assert_eq(scene.outcome_label.text, "Lost 2 piece(s) of gear and 8 XP. Skills are safe.")

func test_ready_without_an_outcome_shows_zero_losses():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var scene := GameOverScene.new()
	add_child_autofree(scene)
	assert_eq(scene.outcome_label.text, "Lost 0 piece(s) of gear and 0 XP. Skills are safe.")

func test_camp_button_emits_camp_requested():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var scene := GameOverScene.new()
	add_child_autofree(scene)
	watch_signals(scene)
	assert_eq(scene.camp_button.text, "Return to Camp")
	scene.camp_button.pressed.emit()
	assert_signal_emitted(scene, "camp_requested")
