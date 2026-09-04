extends HBoxContainer
class_name HandView

signal card_clicked(card: CardResource)

func display(hand: Array[CardResource], energy: int) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for card in hand:
		var button := Button.new()
		button.text = "%s (%d)\n%s" % [card.display_name, card.cost, card.description]
		button.disabled = card.cost > energy
		button.pressed.connect(_on_card_button_pressed.bind(card))
		add_child(button)

func is_card_button_disabled(index: int) -> bool:
	return get_child(index).disabled

func _on_card_button_pressed(card: CardResource) -> void:
	card_clicked.emit(card)
