extends RunStateTest

func test_ready_shows_level_xp_and_skill_points():
	MetaState.level = 2
	MetaState.xp = 7
	MetaState.skill_points = 1
	RunState.enter_camp(DwarfContent.get_class_resource())
	var scene := CampScene.new()
	add_child_autofree(scene)
	assert_eq(scene.header.level_label.text, "LEVEL 2")
	assert_eq(scene.header.xp_bar.value_label.text, "7 / 30")
	assert_eq(scene.header.skill_points_chip.label.text, "1 skill point")
	assert_false(scene.header.gold_chip.visible, "Camp has no run, so no gold.")
	assert_false(scene.header.hp_chip.visible, "Camp has no run, so no HP.")

func test_ready_shows_max_level_without_an_xp_bar():
	MetaState.level = RunState.MAX_LEVEL
	RunState.enter_camp(DwarfContent.get_class_resource())
	var scene := CampScene.new()
	add_child_autofree(scene)
	assert_eq(scene.header.level_label.text, "LEVEL 7 · MAX")
	assert_false(scene.header.xp_bar.visible)

func test_ready_shows_equipped_gear_and_empty_slots():
	MetaState.owned_equipment_ids = [&"chainmail"]
	MetaState.equipped_armor_id = &"chainmail"
	RunState.enter_camp(DwarfContent.get_class_resource())
	var scene := CampScene.new()
	add_child_autofree(scene)
	assert_eq(scene.gear_rows[EquipmentResource.Slot.WEAPON].name_label.text, CampScene.EMPTY_SLOT)
	assert_eq(scene.gear_rows[EquipmentResource.Slot.ARMOR].name_label.text, "Chainmail")
	assert_eq(scene.gear_rows[EquipmentResource.Slot.ARMOR].effect_label.text, "+4 Block.")
	assert_eq(scene.gear_rows[EquipmentResource.Slot.TRINKET].name_label.text, CampScene.EMPTY_SLOT)
	assert_eq(scene.gear_rows[EquipmentResource.Slot.ARMOR].slot_label.text, "ARMOR")

func test_ready_shows_the_flavor_line_and_the_art_placeholder():
	RunState.enter_camp(DwarfContent.get_class_resource())
	var scene := CampScene.new()
	add_child_autofree(scene)
	assert_eq(scene.flavor_label.text, CampScene.FLAVOR_LINE)
	assert_false(scene.camp_art.has_art)

func test_buttons_emit_their_signals():
	RunState.enter_camp(DwarfContent.get_class_resource())
	var scene := CampScene.new()
	add_child_autofree(scene)
	watch_signals(scene)
	scene.skill_tree_button.pressed.emit()
	assert_signal_emitted(scene, "skill_tree_requested")
	scene.inventory_button.pressed.emit()
	assert_signal_emitted(scene, "inventory_requested")
	scene.start_run_button.pressed.emit()
	assert_signal_emitted(scene, "run_requested")

func test_refresh_rereads_run_state():
	RunState.enter_camp(DwarfContent.get_class_resource())
	var scene := CampScene.new()
	add_child_autofree(scene)
	RunState.grant_equipment(DwarfEquipment.get_by_id(&"lucky_charm"))
	RunState.equip_item(RunState.owned_equipment[0])
	scene.refresh()
	assert_eq(scene.gear_rows[EquipmentResource.Slot.TRINKET].name_label.text, "Lucky Charm")

func test_without_a_suspended_run_only_the_normal_buttons_show():
	RunState.enter_camp(DwarfContent.get_class_resource())
	var scene := CampScene.new()
	add_child_autofree(scene)
	assert_true(scene.skill_tree_button.visible)
	assert_true(scene.inventory_button.visible)
	assert_true(scene.start_run_button.visible)
	assert_false(scene.continue_run_button.visible)
	assert_false(scene.abandon_run_button.visible)
	assert_eq(scene.flavor_label.text, CampScene.FLAVOR_LINE)

func test_with_a_suspended_run_only_continue_and_abandon_show():
	RunState.enter_camp(DwarfContent.get_class_resource())
	SaveManager.run_snapshot = {"current_floor": 1}
	var scene := CampScene.new()
	add_child_autofree(scene)
	assert_false(scene.skill_tree_button.visible)
	assert_false(scene.inventory_button.visible)
	assert_false(scene.start_run_button.visible)
	assert_true(scene.continue_run_button.visible)
	assert_true(scene.abandon_run_button.visible)
	assert_eq(scene.flavor_label.text, CampScene.SUSPENDED_FLAVOR_LINE)

func test_continue_and_abandon_buttons_emit_their_signals():
	RunState.enter_camp(DwarfContent.get_class_resource())
	SaveManager.run_snapshot = {"current_floor": 1}
	var scene := CampScene.new()
	add_child_autofree(scene)
	watch_signals(scene)
	scene.continue_run_button.pressed.emit()
	assert_signal_emitted(scene, "continue_requested")
	scene.abandon_run_button.pressed.emit()
	assert_signal_emitted(scene, "abandon_requested")

func test_refresh_switches_button_sets_when_the_snapshot_goes_away():
	RunState.enter_camp(DwarfContent.get_class_resource())
	SaveManager.run_snapshot = {"current_floor": 1}
	var scene := CampScene.new()
	add_child_autofree(scene)
	SaveManager.run_snapshot = null
	scene.refresh()
	assert_true(scene.start_run_button.visible)
	assert_false(scene.continue_run_button.visible)
	assert_eq(scene.flavor_label.text, CampScene.FLAVOR_LINE)
