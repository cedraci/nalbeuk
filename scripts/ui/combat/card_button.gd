extends Button
class_name CardButton

# A hand card: a type-coloured accent bar, cost, full-bleed art, name and
# description — all inside the Button itself so click/disable/hover stay
# native Button behaviour.

const SIZE := Vector2(172, 238)

const TYPE_COLOR := {
	CardResource.CardType.STRIKE: UiTokens.EMBER_DEEP,
	CardResource.CardType.TECHNIQUE: UiTokens.RUNE,
	CardResource.CardType.TRAIT: UiTokens.MOSS,
}
const TYPE_LABEL := {
	CardResource.CardType.STRIKE: "Strike",
	CardResource.CardType.TECHNIQUE: "Technique",
	CardResource.CardType.TRAIT: "Trait",
}

var _accent: ColorRect
var _cost_label: Label
var _name_label: Label
var _art: ArtPlaceholder
var _desc_label: Label
var _type_label: Label

func _init() -> void:
	theme_type_variation = &"Card"
	text = ""
	custom_minimum_size = SIZE
	size = SIZE

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, UiTokens.SPACE_2)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override(&"separation", UiTokens.SPACE_2)
	margin.add_child(vbox)

	_accent = ColorRect.new()
	_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_accent.custom_minimum_size = Vector2(0, 5)
	vbox.add_child(_accent)

	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(top_row)
	_cost_label = Label.new()
	_cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cost_label.theme_type_variation = &"Number"
	top_row.add_child(_cost_label)
	_name_label = Label.new()
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_name_label.clip_text = true
	top_row.add_child(_name_label)

	_art = ArtPlaceholder.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_art)

	_desc_label = Label.new()
	_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_desc_label)

	_type_label = Label.new()
	_type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_type_label.theme_type_variation = &"Muted"
	vbox.add_child(_type_label)

func setup(card: CardResource, playable: bool) -> void:
	disabled = not playable
	tooltip_text = card.description
	_cost_label.text = str(card.cost)
	_name_label.text = card.display_name
	var color: Color = TYPE_COLOR.get(card.card_type, UiTokens.EMBER)
	_accent.color = color
	_cost_label.add_theme_color_override(&"font_color", color)
	_name_label.add_theme_color_override(&"font_color", color)
	_art.setup(StringName("card_" + String(card.id)), "%s illustration" % card.display_name, Vector2(0, 88))
	_desc_label.text = card.description
	_type_label.text = TYPE_LABEL.get(card.card_type, "")
