extends Control
class_name InventoryScene

signal back_requested

const SLOT_NAMES: Dictionary = {
	EquipmentResource.Slot.WEAPON: "Weapon",
	EquipmentResource.Slot.ARMOR: "Armor",
	EquipmentResource.Slot.TRINKET: "Trinket",
}

var slot_equipped_labels: Dictionary = {}
var slot_unequip_buttons: Dictionary = {}
var slot_options_containers: Dictionary = {}
var relics_container: VBoxContainer
var potions_container: VBoxContainer
var back_button: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root_vbox := VBoxContainer.new()
	add_child(root_vbox)

	for slot in [EquipmentResource.Slot.WEAPON, EquipmentResource.Slot.ARMOR, EquipmentResource.Slot.TRINKET]:
		var slot_vbox := VBoxContainer.new()
		root_vbox.add_child(slot_vbox)

		var equipped_label := Label.new()
		slot_vbox.add_child(equipped_label)
		slot_equipped_labels[slot] = equipped_label

		var unequip_button := Button.new()
		unequip_button.text = "Unequip"
		unequip_button.pressed.connect(_on_unequip_button_pressed.bind(slot))
		slot_vbox.add_child(unequip_button)
		slot_unequip_buttons[slot] = unequip_button

		var options_container := VBoxContainer.new()
		slot_vbox.add_child(options_container)
		slot_options_containers[slot] = options_container

	relics_container = VBoxContainer.new()
	root_vbox.add_child(relics_container)

	potions_container = VBoxContainer.new()
	root_vbox.add_child(potions_container)

	back_button = Button.new()
	back_button.text = "Back"
	back_button.pressed.connect(_on_back_pressed)
	root_vbox.add_child(back_button)

	refresh()

func refresh() -> void:
	var equipped_by_slot: Dictionary = {
		EquipmentResource.Slot.WEAPON: RunState.equipped_weapon,
		EquipmentResource.Slot.ARMOR: RunState.equipped_armor,
		EquipmentResource.Slot.TRINKET: RunState.equipped_trinket,
	}
	for slot in slot_equipped_labels.keys():
		var equipped: EquipmentResource = equipped_by_slot[slot]
		var equipped_label: Label = slot_equipped_labels[slot]
		var equipped_name: String = equipped.display_name if equipped != null else "— empty —"
		equipped_label.text = "%s: %s" % [SLOT_NAMES[slot], equipped_name]
		var unequip_button: Button = slot_unequip_buttons[slot]
		unequip_button.disabled = equipped == null

		var options_container: VBoxContainer = slot_options_containers[slot]
		for child in options_container.get_children():
			options_container.remove_child(child)
			child.queue_free()
		for item: EquipmentResource in RunState.owned_equipment:
			if item.slot == slot and item != equipped:
				var button := Button.new()
				button.text = "Equip %s" % item.display_name
				button.pressed.connect(_on_equip_button_pressed.bind(item))
				options_container.add_child(button)

	for child in relics_container.get_children():
		relics_container.remove_child(child)
		child.queue_free()
	var all_relics := DwarfRelics.get_all_relics()
	for relic_id in RunState.unlocked_relics:
		for relic in all_relics:
			if relic.id == relic_id:
				var label := Label.new()
				label.text = "%s: %s" % [relic.display_name, relic.description]
				relics_container.add_child(label)

	for child in potions_container.get_children():
		potions_container.remove_child(child)
		child.queue_free()
	for potion: PotionResource in RunState.potions:
		var label := Label.new()
		label.text = "%s: %s" % [potion.display_name, potion.description]
		potions_container.add_child(label)

func _on_equip_button_pressed(item: EquipmentResource) -> void:
	RunState.equip_item(item)
	refresh()

func _on_unequip_button_pressed(slot: EquipmentResource.Slot) -> void:
	RunState.unequip_slot(slot)
	refresh()

func _on_back_pressed() -> void:
	back_requested.emit()
