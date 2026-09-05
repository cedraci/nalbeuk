extends Control
class_name ShopScene

signal node_completed

var gold_label: Label
var offerings_container: VBoxContainer
var equipment_container: VBoxContainer
var potion_container: VBoxContainer
var leave_button: Button

var _offering_buttons: Array[Button] = []
var _offering_cards: Array[CardResource] = []
var _equipment_buttons: Array[Button] = []
var _equipment_items: Array[EquipmentResource] = []
var _potion_buttons: Array[Button] = []
var _potion_offerings: Array[PotionResource] = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root_vbox := VBoxContainer.new()
	add_child(root_vbox)

	gold_label = Label.new()
	root_vbox.add_child(gold_label)

	offerings_container = VBoxContainer.new()
	root_vbox.add_child(offerings_container)

	equipment_container = VBoxContainer.new()
	root_vbox.add_child(equipment_container)

	potion_container = VBoxContainer.new()
	root_vbox.add_child(potion_container)

	leave_button = Button.new()
	leave_button.text = "Leave"
	leave_button.pressed.connect(_on_leave_pressed)
	root_vbox.add_child(leave_button)

	_offering_cards = DwarfContent.get_shop_offerings()
	for card in _offering_cards:
		var button := Button.new()
		button.pressed.connect(_on_buy_card_button_pressed.bind(card))
		offerings_container.add_child(button)
		_offering_buttons.append(button)

	_equipment_items = DwarfEquipment.get_all_equipment()
	for item in _equipment_items:
		var button := Button.new()
		button.pressed.connect(_on_buy_equipment_button_pressed.bind(item))
		equipment_container.add_child(button)
		_equipment_buttons.append(button)

	_potion_offerings = DwarfPotions.get_all_potions()
	for potion in _potion_offerings:
		var button := Button.new()
		button.pressed.connect(_on_buy_potion_button_pressed.bind(potion))
		potion_container.add_child(button)
		_potion_buttons.append(button)

	_refresh()

func _refresh() -> void:
	gold_label.text = "Gold: %d" % RunState.gold
	for i in range(_offering_cards.size()):
		var card: CardResource = _offering_cards[i]
		var button: Button = _offering_buttons[i]
		button.text = "%s - %d gold" % [card.display_name, RunState.SHOP_CARD_PRICE]
		button.disabled = RunState.gold < RunState.SHOP_CARD_PRICE
	for i in range(_equipment_items.size()):
		var item: EquipmentResource = _equipment_items[i]
		var button: Button = _equipment_buttons[i]
		button.text = "%s - %d gold" % [item.display_name, RunState.SHOP_EQUIPMENT_PRICE]
		button.disabled = RunState.gold < RunState.SHOP_EQUIPMENT_PRICE
	for i in range(_potion_offerings.size()):
		var potion: PotionResource = _potion_offerings[i]
		var button: Button = _potion_buttons[i]
		button.text = "%s - %d gold" % [potion.display_name, RunState.SHOP_POTION_PRICE]
		button.disabled = RunState.gold < RunState.SHOP_POTION_PRICE or RunState.potions.size() >= RunState.MAX_POTIONS

func _on_buy_card_button_pressed(card: CardResource) -> void:
	RunState.buy_card(card, RunState.SHOP_CARD_PRICE)
	_refresh()

func _on_buy_equipment_button_pressed(item: EquipmentResource) -> void:
	RunState.buy_equipment(item, RunState.SHOP_EQUIPMENT_PRICE)
	_refresh()

func _on_buy_potion_button_pressed(potion: PotionResource) -> void:
	RunState.buy_potion(potion, RunState.SHOP_POTION_PRICE)
	_refresh()

func _on_leave_pressed() -> void:
	node_completed.emit()
