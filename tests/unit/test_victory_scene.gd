extends RunStateTest

func test_ready_shows_the_floor_reached():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.current_floor = 5
	var scene := VictoryScene.new()
	add_child_autofree(scene)
	assert_eq(scene.result_label.text, "Victory! You reached floor 5.")

func test_ready_tells_the_player_everything_is_kept():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var scene := VictoryScene.new()
	scene.outcome = RunState.finish_run(true)
	add_child_autofree(scene)
	assert_eq(scene.outcome_label.text, "Everything you found is yours to keep.")

func test_camp_button_emits_camp_requested():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var scene := VictoryScene.new()
	add_child_autofree(scene)
	watch_signals(scene)
	assert_eq(scene.camp_button.text, "Return to Camp")
	scene.camp_button.pressed.emit()
	assert_signal_emitted(scene, "camp_requested")
