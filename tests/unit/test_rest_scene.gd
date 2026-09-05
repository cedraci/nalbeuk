extends GutTest

var RestScene = preload("res://scripts/ui/run/rest_scene.gd")

func test_heal_button_heals_and_emits_node_completed():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.player_current_hp = RunState.player_max_hp - 20
	var scene = RestScene.new()
	add_child_autofree(scene)
	watch_signals(scene)
	scene.heal_button.pressed.emit()
	assert_eq(RunState.player_current_hp, RunState.player_max_hp - 20 + RestScene.HEAL_AMOUNT)
	assert_signal_emitted(scene, "node_completed")

func test_upgrade_button_reveals_one_button_per_deck_card():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var scene = RestScene.new()
	add_child_autofree(scene)
	scene.upgrade_button.pressed.emit()
	assert_true(scene.card_list_container.visible)
	assert_eq(scene.card_list_container.get_child_count(), RunState.deck.size())

func test_clicking_a_card_in_the_upgrade_list_upgrades_it_and_emits_node_completed():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var scene = RestScene.new()
	add_child_autofree(scene)
	scene.upgrade_button.pressed.emit()
	var guard_index: int = -1
	for i in range(RunState.deck.size()):
		if RunState.deck[i].id == &"dwarf_guard":
			guard_index = i
	watch_signals(scene)
	var guard_button: Button = scene.card_list_container.get_child(guard_index)
	guard_button.pressed.emit()
	assert_eq(RunState.deck[guard_index].id, &"dwarf_guard_plus")
	assert_signal_emitted(scene, "node_completed")
