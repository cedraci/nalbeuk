extends Control
class_name IntentView

# A badge floating above the enemy's head: icon + value, tooltipped with
# the move's full description. Replaces the old plain-text "ATTACK 5" label.

const SIZE := 46.0

const INTENT_ICON := {
	EnemyMove.IntentType.ATTACK: &"fang",
	EnemyMove.IntentType.DEFEND: &"shield",
	EnemyMove.IntentType.BUFF: &"bolt",
	EnemyMove.IntentType.DEBUFF: &"weak",
	EnemyMove.IntentType.SPECIAL: &"quest",
}
const INTENT_TINT := {
	EnemyMove.IntentType.ATTACK: UiTokens.BLOOD,
	EnemyMove.IntentType.DEFEND: UiTokens.RUNE,
	EnemyMove.IntentType.BUFF: UiTokens.EMBER,
	EnemyMove.IntentType.DEBUFF: UiTokens.BLOOD,
	EnemyMove.IntentType.SPECIAL: UiTokens.MUTED,
}

var icon_rect: TextureRect
var count_label: Label

var _circle: PanelContainer

func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_PASS

	_circle = PanelContainer.new()
	_circle.set_anchors_preset(Control.PRESET_FULL_RECT)
	_circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_circle)

	icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(20, 20)
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_circle.add_child(icon_rect)

	count_label = Label.new()
	count_label.theme_type_variation = &"Number"
	count_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(count_label)

func display(move: EnemyMove) -> void:
	var tint: Color = INTENT_TINT.get(move.intent_type, UiTokens.MUTED)

	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.SURFACE_2
	box.border_color = tint
	box.set_border_width_all(2)
	box.set_corner_radius_all(999)
	box.shadow_size = 12
	box.shadow_color = Color(tint.r, tint.g, tint.b, 0.35)
	_circle.add_theme_stylebox_override(&"panel", box)

	var icon_name: StringName = INTENT_ICON.get(move.intent_type, &"quest")
	icon_rect.texture = UiIcons.texture(icon_name)
	icon_rect.modulate = tint

	count_label.text = str(move.display_value)
	count_label.visible = move.display_value > 0
	count_label.add_theme_color_override(&"font_color", tint)

	tooltip_text = move.description
