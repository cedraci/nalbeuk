extends PanelContainer
class_name StatChip

# A pill with an icon and a short value ("21 / 36", "25 gold").

var icon_rect: TextureRect
var label: Label

func _init() -> void:
	theme_type_variation = &"Chip"
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override(&"separation", UiTokens.SPACE_2)
	add_child(hbox)
	icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(16, 16)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(icon_rect)
	label = Label.new()
	hbox.add_child(label)

func setup(icon: StringName, text: String, tint: Color = UiTokens.TEXT) -> void:
	icon_rect.texture = UiIcons.texture(icon)
	icon_rect.modulate = tint
	label.text = text
	label.add_theme_color_override(&"font_color", tint)

func set_text(text: String) -> void:
	label.text = text
