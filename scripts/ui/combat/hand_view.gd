extends Control
class_name HandView

signal card_clicked(card: CardResource)

const CARD_GAP := 14.0

func display(hand: Array[CardResource], energy: int) -> void:
	for child in get_children():
		# queue_free(), not free(): this runs from inside a card button's own
		# "pressed" handler chain (state_changed -> _refresh -> display), so
		# freeing immediately would destroy a node still executing its own
		# signal dispatch.
		remove_child(child)
		child.queue_free()
	var count := hand.size()
	var total_width: float = count * CardButton.SIZE.x + maxf(count - 1, 0.0) * CARD_GAP
	var start_x: float = (size.x - total_width) / 2.0
	var center: float = (count - 1) / 2.0
	for i in range(count):
		var card: CardResource = hand[i]
		var button := CardButton.new()
		button.setup(card, card.cost <= energy)
		var offset: float = i - center
		button.position = Vector2(start_x + i * (CardButton.SIZE.x + CARD_GAP), absf(offset) * 9.0)
		button.pivot_offset = CardButton.SIZE / 2.0
		button.rotation_degrees = offset * 4.0
		button.pressed.connect(_on_card_button_pressed.bind(card))
		add_child(button)

func is_card_button_disabled(index: int) -> bool:
	return get_child(index).disabled

func _on_card_button_pressed(card: CardResource) -> void:
	card_clicked.emit(card)
