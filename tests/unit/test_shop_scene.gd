extends GutTest

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
