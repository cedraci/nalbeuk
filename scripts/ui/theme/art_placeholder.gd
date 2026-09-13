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
var accents_overlay: Control = null

func setup(art_id: StringName, brief: String, art_size: Vector2, use_torchlit_shader: bool = false, accent_markers: Array[Vector2] = []) -> void:
	custom_minimum_size = art_size
	for child in get_children():
		remove_child(child)
		# Safe to free immediately: none of the children we build (Label,
		# TextureRect, the accent overlay and its ArtAccentDots) connects to
		# anything outside its own subtree. ArtAccentDot's looping Tween is
		# node-bound (created via create_tween()), so freeing the node
		# invalidates the Tween with it rather than leaving it running.
		child.free()
	label = null
	texture_rect = null
	accents_overlay = null
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
		if not accent_markers.is_empty():
			# The dots cannot hang off this PanelContainer directly: its layout
			# pass calls fit_child_in_rect() on every sortable Control child,
			# which would overwrite each dot's hand-placed position and stretch
			# it across the whole panel. A plain Control does not re-layout its
			# own children, so nest them in one. The overlay itself does get
			# stretched to the panel's rect — that's exactly what we want, since
			# it should cover the full art area for the dots to sit inside.
			accents_overlay = Control.new()
			accents_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			accents_overlay.position = Vector2.ZERO
			accents_overlay.size = art_size
			add_child(accents_overlay)
			for marker in accent_markers:
				var dot := ArtAccentDot.new()
				dot.position = marker * art_size - dot.custom_minimum_size / 2.0
				accents_overlay.add_child(dot)
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
