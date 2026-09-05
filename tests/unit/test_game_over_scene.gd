extends GutTest

func test_ready_shows_the_floor_reached():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.current_floor = 3
	var scene := GameOverScene.new()
	add_child_autofree(scene)
	assert_eq(scene.result_label.text, "You died on floor 3.")

func test_new_run_button_emits_new_run_requested():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var scene := GameOverScene.new()
	add_child_autofree(scene)
	watch_signals(scene)
	scene.new_run_button.pressed.emit()
	assert_signal_emitted(scene, "new_run_requested")
