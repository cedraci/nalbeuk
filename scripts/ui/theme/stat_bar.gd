extends VBoxContainer
class_name StatBar

# Caption row ("XP" ... "7 / 30") over a thin ProgressBar.

var caption_label: Label
var value_label: Label
var bar: ProgressBar

func _init() -> void:
	add_theme_constant_override(&"separation", UiTokens.SPACE_2)
	var row := HBoxContainer.new()
	add_child(row)
	caption_label = Label.new()
	caption_label.theme_type_variation = &"Muted"
	caption_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption_label)
	value_label = Label.new()
	value_label.theme_type_variation = &"Muted"
	row.add_child(value_label)
	bar = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	add_child(bar)

func setup(caption: String, fill: Color) -> void:
	caption_label.text = caption
	var fill_box := StyleBoxFlat.new()
	fill_box.bg_color = fill
	fill_box.set_corner_radius_all(4)
	bar.add_theme_stylebox_override(&"fill", fill_box)

func set_values(value: int, max_value: int) -> void:
	bar.max_value = maxi(max_value, 1)
	bar.value = value
	value_label.text = "%d / %d" % [value, max_value]
