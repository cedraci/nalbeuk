extends Control
class_name ShopScene

signal node_completed

var gold_label: Label
var offerings_container: VBoxContainer
var leave_button: Button

var _offering_buttons: Array[Button] = []
var _offering_cards: Array[CardResource] = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root_vbox := VBoxContainer.new()
	add_child(root_vbox)

	gold_label = Label.new()
	root_vbox.add_child(gold_label)

	offerings_container = VBoxContainer.new()
	root_vbox.add_child(offerings_container)

	leave_button = Button.new()
	leave_button.text = "Leave"
	leave_button.pressed.connect(_on_leave_pressed)
	root_vbox.add_child(leave_button)

	_offering_cards = DwarfContent.get_shop_offerings()
	for card in _offering_cards:
		var button := Button.new()
		button.pressed.connect(_on_buy_button_pressed.bind(card))
		offerings_container.add_child(button)
		_offering_buttons.append(button)

	_refresh()

func _refresh() -> void:
	gold_label.text = "Gold: %d" % RunState.gold
	for i in range(_offering_cards.size()):
		var card: CardResource = _offering_cards[i]
		var button: Button = _offering_buttons[i]
		button.text = "%s - %d gold" % [card.display_name, RunState.SHOP_CARD_PRICE]
		button.disabled = RunState.gold < RunState.SHOP_CARD_PRICE

func _on_buy_button_pressed(card: CardResource) -> void:
	RunState.buy_card(card, RunState.SHOP_CARD_PRICE)
	_refresh()

func _on_leave_pressed() -> void:
	node_completed.emit()
