extends RunStateTest

func test_ready_shows_gold_and_one_button_per_offering():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.gold = 50
	var scene := ShopScene.new()
	add_child_autofree(scene)
	assert_eq(scene.gold_label.text, "Gold: 50")
	assert_eq(scene.offerings_container.get_child_count(), DwarfContent.get_shop_offerings().size())

func test_buy_button_disabled_when_too_poor():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.gold = 5
	var scene := ShopScene.new()
	add_child_autofree(scene)
	var button: Button = scene.offerings_container.get_child(0)
	assert_true(button.disabled)

func test_clicking_buy_deducts_gold_and_adds_a_card_to_the_deck():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.gold = 50
	var scene := ShopScene.new()
	add_child_autofree(scene)
	var deck_size_before: int = RunState.deck.size()
	var button: Button = scene.offerings_container.get_child(0)
	button.pressed.emit()
	assert_eq(RunState.gold, 50 - RunState.SHOP_CARD_PRICE)
	assert_eq(RunState.deck.size(), deck_size_before + 1)

func test_leave_button_emits_node_completed():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var scene := ShopScene.new()
	add_child_autofree(scene)
	watch_signals(scene)
	scene.leave_button.pressed.emit()
	assert_signal_emitted(scene, "node_completed")

func test_ready_shows_one_button_per_equipment_and_potion_offering():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.gold = 50
	var scene := ShopScene.new()
	add_child_autofree(scene)
	assert_eq(scene.equipment_container.get_child_count(), DwarfEquipment.get_all_equipment().size())
	assert_eq(scene.potion_container.get_child_count(), DwarfPotions.get_all_potions().size())

func test_equipment_buy_button_disabled_when_too_poor():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.gold = 5
	var scene := ShopScene.new()
	add_child_autofree(scene)
	var button: Button = scene.equipment_container.get_child(0)
	assert_true(button.disabled)

func test_clicking_buy_equipment_deducts_gold_and_adds_to_owned():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.gold = 50
	var scene := ShopScene.new()
	add_child_autofree(scene)
	var owned_before: int = RunState.owned_equipment.size()
	var button: Button = scene.equipment_container.get_child(0)
	button.pressed.emit()
	assert_eq(RunState.gold, 50 - RunState.SHOP_EQUIPMENT_PRICE)
	assert_eq(RunState.owned_equipment.size(), owned_before + 1)

func test_potion_buy_button_disabled_when_potions_full():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.gold = 50
	var potions := DwarfPotions.get_all_potions()
	RunState.add_potion(potions[0])
	RunState.add_potion(potions[1])
	var scene := ShopScene.new()
	add_child_autofree(scene)
	var button: Button = scene.potion_container.get_child(0)
	assert_true(button.disabled)

func test_clicking_buy_potion_deducts_gold_and_adds_to_potions():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.gold = 50
	var scene := ShopScene.new()
	add_child_autofree(scene)
	var button: Button = scene.potion_container.get_child(0)
	button.pressed.emit()
	assert_eq(RunState.gold, 50 - RunState.SHOP_POTION_PRICE)
	assert_eq(RunState.potions.size(), 1)
