extends Control
class_name RestScene

signal node_completed

const HEAL_AMOUNT := 8

var heal_button: Button
var upgrade_button: Button
var card_list_container: VBoxContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root_vbox := VBoxContainer.new()
	add_child(root_vbox)

	heal_button = Button.new()
	heal_button.text = "Heal"
	heal_button.pressed.connect(_on_heal_pressed)
	root_vbox.add_child(heal_button)

	upgrade_button = Button.new()
	upgrade_button.text = "Upgrade a Card"
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	root_vbox.add_child(upgrade_button)

	card_list_container = VBoxContainer.new()
	root_vbox.add_child(card_list_container)
	card_list_container.hide()

func _on_heal_pressed() -> void:
	RunState.heal(HEAL_AMOUNT)
	node_completed.emit()

func _on_upgrade_pressed() -> void:
	heal_button.hide()
	upgrade_button.hide()
	for card in RunState.deck:
		var button := Button.new()
		button.text = card.display_name
		button.pressed.connect(_on_card_button_pressed.bind(card))
		card_list_container.add_child(button)
	card_list_container.show()

func _on_card_button_pressed(card: CardResource) -> void:
	RunState.upgrade_card(card.id)
	node_completed.emit()
