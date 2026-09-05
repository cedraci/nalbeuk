extends RunStateTest

func test_root_node_available_when_a_point_is_banked():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.skill_points = 1
	var scene := SkillTreeScene.new()
	add_child_autofree(scene)
	var root_button: Button = scene.node_buttons[&"dwarven_grit"]
	var child_button: Button = scene.node_buttons[&"sharpened_pick"]
	assert_false(root_button.disabled, "Root has no prerequisite and a point is available.")
	assert_true(child_button.disabled, "Sharpened Pick requires Dwarven Grit, not yet unlocked.")

func test_clicking_an_available_node_unlocks_it_and_refreshes():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.skill_points = 1
	var scene := SkillTreeScene.new()
	add_child_autofree(scene)
	var root_button: Button = scene.node_buttons[&"dwarven_grit"]
	root_button.pressed.emit()
	assert_true(RunState.unlocked_skill_nodes.has(&"dwarven_grit"))
	var refreshed_root_button: Button = scene.node_buttons[&"dwarven_grit"]
	assert_true(refreshed_root_button.disabled, "Already-unlocked nodes should render disabled.")

func test_button_disabled_with_no_skill_points_even_if_prerequisite_met():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.skill_points = 1
	RunState.unlock_skill_node(DwarfSkillTree.get_skill_tree()[0])
	var scene := SkillTreeScene.new()
	add_child_autofree(scene)
	var offense_button: Button = scene.node_buttons[&"sharpened_pick"]
	assert_true(offense_button.disabled, "Prerequisite met but no skill points left.")

func test_back_button_emits_back_requested():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var scene := SkillTreeScene.new()
	add_child_autofree(scene)
	watch_signals(scene)
	scene.back_button.pressed.emit()
	assert_signal_emitted(scene, "back_requested")
