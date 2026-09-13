extends PanelContainer
class_name ArtPlaceholder

# Shows res://assets/art/<art_id>.svg or .png when either exists (svg is
# checked first — the traced-from-photo pipeline's output; see
# docs/superpowers/specs/2026-09-13-creature-art-pipeline-design.md);
# otherwise a quiet panel carrying the image brief, so art drops in later
# with no code change. See assets/art/README.md.

const ART_DIR := "res://assets/art/"
const TORCHLIT_SHADER := preload("res://scripts/ui/theme/torchlit_creature.gdshader")

var has_art: bool = false
var label: Label = null
var texture_rect: TextureRect = null

func setup(art_id: StringName, brief: String, art_size: Vector2, use_torchlit_shader: bool = false) -> void:
	custom_minimum_size = art_size
	for child in get_children():
		remove_child(child)
		# Safe to free immediately: Label and TextureRect have no signal handlers
		child.free()
	label = null
	texture_rect = null
	var path := _resolve_art_path(art_id)
	if path != "":
		has_art = true
		add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
		texture_rect = TextureRect.new()
		texture_rect.texture = load(path) as Texture2D
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
		add_child(texture_rect)
		if use_torchlit_shader:
			var mat := ShaderMaterial.new()
			mat.shader = TORCHLIT_SHADER
			texture_rect.material = mat
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

func _resolve_art_path(art_id: StringName) -> String:
	var svg_path: String = ART_DIR + String(art_id) + ".svg"
	if ResourceLoader.exists(svg_path):
		return svg_path
	var png_path: String = ART_DIR + String(art_id) + ".png"
	if ResourceLoader.exists(png_path):
		return png_path
	return ""
