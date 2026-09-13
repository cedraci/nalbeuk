extends RefCounted
class_name ThemeBuilder

# Builds the Torchlit Theme in code (the project builds all UI in code;
# a .tres would be a second source of truth). RunScene applies it once
# at its root; every child scene inherits it.

const DISPLAY_FONT_PATH := "res://assets/fonts/Cinzel[wght].ttf"
const BODY_FONT_PATH := "res://assets/fonts/SourceSans3[wght].ttf"

static var _theme: Theme = null

static func build() -> Theme:
	if _theme != null:
		return _theme
	var theme := Theme.new()
	theme.default_font = body_font(400)
	theme.default_font_size = UiTokens.FONT_BODY
	_build_labels(theme)
	_build_buttons(theme)
	_build_panels(theme)
	_build_progress_bar(theme)
	_theme = theme
	return theme

static func size_button(button: Button) -> Button:
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, UiTokens.HIT_TARGET)
	return button

static func display_font(weight: int) -> FontVariation:
	return _variation(DISPLAY_FONT_PATH, weight)

static func body_font(weight: int) -> FontVariation:
	return _variation(BODY_FONT_PATH, weight)

static func _variation(path: String, weight: int) -> FontVariation:
	var variation := FontVariation.new()
	if ResourceLoader.exists(path):
		variation.base_font = load(path) as Font
	else:
		push_warning("ThemeBuilder: font %s missing, using the engine fallback" % path)
		variation.base_font = ThemeDB.fallback_font
	variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("weight"): weight}
	return variation

static func _flat(fill: Color, border: Color, border_width: int, radius: int, margin_x: int, margin_y: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = margin_x
	box.content_margin_right = margin_x
	box.content_margin_top = margin_y
	box.content_margin_bottom = margin_y
	return box

static func _label_variation(theme: Theme, name: StringName, font: FontVariation, size: int, color: Color) -> void:
	theme.set_type_variation(name, &"Label")
	theme.set_font(&"font", name, font)
	theme.set_font_size(&"font_size", name, size)
	theme.set_color(&"font_color", name, color)

static func _build_labels(theme: Theme) -> void:
	theme.set_color(&"font_color", &"Label", UiTokens.TEXT)
	_label_variation(theme, &"Display", display_font(800), UiTokens.FONT_H1, UiTokens.EMBER)
	_label_variation(theme, &"Heading", display_font(800), UiTokens.FONT_H2, UiTokens.TEXT)
	_label_variation(theme, &"Eyebrow", display_font(800), UiTokens.FONT_EYEBROW, UiTokens.EMBER)
	_label_variation(theme, &"Number", display_font(800), UiTokens.FONT_NUMBER, UiTokens.EMBER)
	_label_variation(theme, &"Muted", body_font(400), UiTokens.FONT_BODY, UiTokens.MUTED)
	_label_variation(theme, &"Banter", body_font(400), UiTokens.FONT_BANTER, UiTokens.MUTED)

static func _button_colors(theme: Theme, type_name: StringName, color: Color) -> void:
	var disabled := Color(color.r, color.g, color.b, 0.4)
	for key in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color", &"icon_normal_color", &"icon_hover_color", &"icon_pressed_color", &"icon_focus_color"]:
		theme.set_color(key, type_name, color)
	theme.set_color(&"font_disabled_color", type_name, disabled)
	theme.set_color(&"icon_disabled_color", type_name, disabled)

static func _button_styles(theme: Theme, type_name: StringName, fill: Color, border: Color, border_width: int, radius: int, margin_x: int, margin_y: int) -> void:
	var hover := Color(fill.r, fill.g, fill.b, minf(fill.a * 2.0, 1.0))
	var pressed := Color(fill.r, fill.g, fill.b, minf(fill.a * 3.0, 1.0))
	var disabled_fill := Color(fill.r, fill.g, fill.b, fill.a * 0.4)
	var disabled_border := Color(border.r, border.g, border.b, border.a * 0.4)
	theme.set_stylebox(&"normal", type_name, _flat(fill, border, border_width, radius, margin_x, margin_y))
	theme.set_stylebox(&"hover", type_name, _flat(hover, border, border_width, radius, margin_x, margin_y))
	theme.set_stylebox(&"pressed", type_name, _flat(pressed, border, border_width, radius, margin_x, margin_y))
	theme.set_stylebox(&"disabled", type_name, _flat(disabled_fill, disabled_border, border_width, radius, margin_x, margin_y))
	theme.set_stylebox(&"focus", type_name, StyleBoxEmpty.new())

static func _build_buttons(theme: Theme) -> void:
	theme.set_font(&"font", &"Button", display_font(800))
	theme.set_font_size(&"font_size", &"Button", UiTokens.FONT_BODY - 1)
	_button_colors(theme, &"Button", UiTokens.EMBER)
	_button_styles(theme, &"Button", UiTokens.ember(0.07), UiTokens.ember(0.55), 1, UiTokens.RADIUS_BUTTON, 22, 12)

	theme.set_type_variation(&"Primary", &"Button")
	_button_colors(theme, &"Primary", UiTokens.BG)
	var primary := _flat(UiTokens.EMBER, UiTokens.EMBER_LIGHT, 1, UiTokens.RADIUS_BUTTON, 22, 12)
	theme.set_stylebox(&"normal", &"Primary", primary)
	theme.set_stylebox(&"hover", &"Primary", _flat(UiTokens.EMBER_LIGHT, UiTokens.EMBER_LIGHT, 1, UiTokens.RADIUS_BUTTON, 22, 12))
	theme.set_stylebox(&"pressed", &"Primary", _flat(UiTokens.EMBER_DEEP, UiTokens.EMBER_LIGHT, 1, UiTokens.RADIUS_BUTTON, 22, 12))
	theme.set_stylebox(&"disabled", &"Primary", _flat(UiTokens.ember(0.3), UiTokens.ember(0.3), 1, UiTokens.RADIUS_BUTTON, 22, 12))
	theme.set_stylebox(&"focus", &"Primary", StyleBoxEmpty.new())

	theme.set_type_variation(&"Ghost", &"Button")
	_button_colors(theme, &"Ghost", UiTokens.MUTED)
	_button_styles(theme, &"Ghost", Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, UiTokens.RADIUS_BUTTON, 22, 12)

	theme.set_type_variation(&"Danger", &"Button")
	_button_colors(theme, &"Danger", Color("#e07a66"))
	var blood := UiTokens.BLOOD
	_button_styles(theme, &"Danger", Color(blood.r, blood.g, blood.b, 0.08), Color(blood.r, blood.g, blood.b, 0.6), 1, UiTokens.RADIUS_BUTTON, 22, 12)

	theme.set_type_variation(&"Card", &"Button")
	_button_colors(theme, &"Card", UiTokens.TEXT)
	_button_styles(theme, &"Card", UiTokens.SURFACE_2, UiTokens.ember(0.35), 1, UiTokens.RADIUS_CARD, 0, 0)

	_node_variation(theme, &"NodeLocked", Color("#1a1613"), Color(1, 1, 1, 0.06), 1, Color("#4a423a"))
	_node_variation(theme, &"NodeVisited", Color("#221c17"), UiTokens.ember(0.18), 1, UiTokens.DIM)
	_node_variation(theme, &"NodeOpen", UiTokens.SURFACE_2, UiTokens.EMBER, 1, UiTokens.EMBER, 14, UiTokens.ember(0.25))
	_node_variation(theme, &"NodeCurrent", UiTokens.EMBER, UiTokens.EMBER_LIGHT, 2, UiTokens.BG, 26, UiTokens.ember(0.65))

static func _node_variation(theme: Theme, name: StringName, fill: Color, border: Color, border_width: int, icon_color: Color, glow_size: int = 0, glow_color: Color = Color(0, 0, 0, 0)) -> void:
	theme.set_type_variation(name, &"Button")
	_button_colors(theme, name, icon_color)
	var box := _flat(fill, border, border_width, 999, 0, 0)
	if glow_size > 0:
		box.shadow_size = glow_size
		box.shadow_color = glow_color
	theme.set_stylebox(&"normal", name, box)
	theme.set_stylebox(&"hover", name, box)
	theme.set_stylebox(&"pressed", name, box)
	theme.set_stylebox(&"disabled", name, box)
	theme.set_stylebox(&"focus", name, StyleBoxEmpty.new())

static func _build_panels(theme: Theme) -> void:
	var surface := UiTokens.SURFACE
	var panel := _flat(Color(surface.r, surface.g, surface.b, 0.94), UiTokens.LINE, 1, UiTokens.RADIUS_PANEL, 16, 14)
	panel.shadow_size = 10
	panel.shadow_color = Color(0, 0, 0, 0.5)
	theme.set_stylebox(&"panel", &"PanelContainer", panel)
	theme.set_type_variation(&"Chip", &"PanelContainer")
	theme.set_stylebox(&"panel", &"Chip", _flat(Color(1, 1, 1, 0.04), UiTokens.LINE_SOFT, 1, 999, 10, 5))

static func _build_progress_bar(theme: Theme) -> void:
	theme.set_stylebox(&"background", &"ProgressBar", _flat(UiTokens.SURFACE_2, Color(0, 0, 0, 0.4), 1, 4, 0, 0))
	theme.set_stylebox(&"fill", &"ProgressBar", _flat(UiTokens.EMBER, Color(0, 0, 0, 0), 0, 4, 0, 0))
