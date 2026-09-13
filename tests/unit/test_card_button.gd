extends GutTest

func _make_card(name: String, cost: int, card_type: CardResource.CardType) -> CardResource:
	var card := CardResource.new()
	card.id = StringName(name.to_lower())
	card.display_name = name
	card.cost = cost
	card.card_type = card_type
	card.description = "Test description."
	return card

func test_setup_shows_cost_name_and_description():
	var button := CardButton.new()
	add_child_autofree(button)
	var card := _make_card("Strike", 1, CardResource.CardType.STRIKE)
	button.setup(card, true)
	assert_false(button.disabled)
	assert_eq(button.tooltip_text, "Test description.")

func test_setup_disables_when_not_playable():
	var button := CardButton.new()
	add_child_autofree(button)
	var card := _make_card("Strike", 3, CardResource.CardType.STRIKE)
	button.setup(card, false)
	assert_true(button.disabled)

func test_setup_is_a_button_so_it_can_be_pressed():
	var button := CardButton.new()
	add_child_autofree(button)
	var card := _make_card("Guard", 1, CardResource.CardType.TECHNIQUE)
	button.setup(card, true)
	watch_signals(button)
	button.pressed.emit()
	assert_signal_emitted(button, "pressed")
