extends GutTest

func _make_card(display_name: String, cost: int) -> CardResource:
	var card := CardResource.new()
	card.display_name = display_name
	card.cost = cost
	card.description = "Test description."
	return card

func test_display_creates_one_button_per_card():
	var hand_view := HandView.new()
	add_child_autofree(hand_view)
	var hand: Array[CardResource] = [_make_card("Strike", 1), _make_card("Guard", 1)]
	hand_view.display(hand, 3)
	assert_eq(hand_view.get_child_count(), 2)

func test_display_disables_cards_that_cost_more_than_current_energy():
	var hand_view := HandView.new()
	add_child_autofree(hand_view)
	var hand: Array[CardResource] = [_make_card("Cheap", 1), _make_card("Expensive", 3)]
	hand_view.display(hand, 1)
	assert_false(hand_view.is_card_button_disabled(0), "Cost 1 with 1 energy should be playable.")
	assert_true(hand_view.is_card_button_disabled(1), "Cost 3 with 1 energy should be disabled.")

func test_clicking_a_card_button_emits_card_clicked():
	var hand_view := HandView.new()
	add_child_autofree(hand_view)
	var card := _make_card("Strike", 1)
	var hand: Array[CardResource] = [card]
	hand_view.display(hand, 3)
	watch_signals(hand_view)
	var button: Button = hand_view.get_child(0)
	button.pressed.emit()
	assert_signal_emitted_with_parameters(hand_view, "card_clicked", [card])
