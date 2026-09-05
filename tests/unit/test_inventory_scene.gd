extends RunStateTest

func test_equip_button_for_owned_item_equips_it_and_refreshes():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var sword: EquipmentResource = DwarfEquipment.get_all_equipment()[0]
	RunState.grant_equipment(sword)
	var scene := InventoryScene.new()
	add_child_autofree(scene)
	var options_container: VBoxContainer = scene.slot_options_containers[EquipmentResource.Slot.WEAPON]
	var equip_button: Button = options_container.get_child(0)
	equip_button.pressed.emit()
	assert_eq(RunState.equipped_weapon, sword)
	var equipped_label: Label = scene.slot_equipped_labels[EquipmentResource.Slot.WEAPON]
	assert_true(equipped_label.text.contains(sword.display_name))

func test_unequip_button_disabled_when_slot_empty():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var scene := InventoryScene.new()
	add_child_autofree(scene)
	var unequip_button: Button = scene.slot_unequip_buttons[EquipmentResource.Slot.WEAPON]
	assert_true(unequip_button.disabled)

func test_unequip_button_clears_the_slot():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var sword: EquipmentResource = DwarfEquipment.get_all_equipment()[0]
	RunState.grant_equipment(sword)
	RunState.equip_item(sword)
	var scene := InventoryScene.new()
	add_child_autofree(scene)
	var unequip_button: Button = scene.slot_unequip_buttons[EquipmentResource.Slot.WEAPON]
	unequip_button.pressed.emit()
	assert_null(RunState.equipped_weapon)

func test_relics_list_reflects_unlocked_relics():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var relic: RelicResource = DwarfRelics.get_all_relics()[0]
	RunState.grant_relic(relic)
	var scene := InventoryScene.new()
	add_child_autofree(scene)
	assert_eq(scene.relics_container.get_child_count(), 1)

func test_back_button_emits_back_requested():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var scene := InventoryScene.new()
	add_child_autofree(scene)
	watch_signals(scene)
	scene.back_button.pressed.emit()
	assert_signal_emitted(scene, "back_requested")
