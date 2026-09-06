extends HBoxContainer
class_name GearRow

# One line of Camp's gear table: SLOT · item name · effect.

var slot_label: Label
var name_label: Label
var effect_label: Label

func _init() -> void:
	add_theme_constant_override(&"separation", UiTokens.SPACE_3)
	slot_label = Label.new()
	slot_label.theme_type_variation = &"Eyebrow"
	slot_label.custom_minimum_size = Vector2(90, 0)
	add_child(slot_label)
	name_label = Label.new()
	name_label.custom_minimum_size = Vector2(170, 0)
	add_child(name_label)
	effect_label = Label.new()
	effect_label.theme_type_variation = &"Muted"
	effect_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(effect_label)

func set_item(slot_name: String, item: EquipmentResource) -> void:
	slot_label.text = slot_name.to_upper()
	if item == null:
		name_label.text = CampScene.EMPTY_SLOT
		name_label.add_theme_color_override(&"font_color", UiTokens.DIM)
		effect_label.text = ""
		return
	name_label.text = item.display_name
	name_label.remove_theme_color_override(&"font_color")
	effect_label.text = item.description
