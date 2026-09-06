extends PanelContainer
class_name ArtPlaceholder

# Shows res://assets/art/<art_id>.png when it exists; otherwise a quiet
# panel carrying the image brief, so generated art drops in later with
# no code change. See assets/art/README.md.

const ART_DIR := "res://assets/art/"

var has_art: bool = false
var label: Label = null
var texture_rect: TextureRect = null

func setup(art_id: StringName, brief: String, art_size: Vector2) -> void:
	custom_minimum_size = art_size
	for child in get_children():
		remove_child(child)
		child.queue_free()
	label = null
	texture_rect = null
	var path: String = ART_DIR + String(art_id) + ".png"
	if ResourceLoader.exists(path):
		has_art = true
		add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
		texture_rect = TextureRect.new()
		texture_rect.texture = load(path) as Texture2D
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
		add_child(texture_rect)
		return
	has_art = false
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0.25)
	box.border_color = UiTokens.LINE
	box.set_border_width_all(1)
	box.set_corner_radius_all(UiTokens.RADIUS_PANEL)
	add_theme_stylebox_override(&"panel", box)
	label = Label.new()
	label.theme_type_variation = &"Muted"
	label.text = "[art: %s]" % brief
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
