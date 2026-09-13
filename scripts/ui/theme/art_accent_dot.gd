extends Control
class_name ArtAccentDot

# A small glowing dot for a creature art's eye/mouth accent — the same
# stacked-rings-plus-pulse technique as TorchGlow, but tiny, tintable, and
# positioned inside another Control rather than centred on itself.

const STEPS := 10
const PEAK_ALPHA := 0.05

var tint: Color
var _tween: Tween = null

func _init(p_tint: Color = UiTokens.EMBER_LIGHT, p_radius: float = 6.0) -> void:
	tint = p_tint
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(p_radius * 2.0, p_radius * 2.0)
	size = custom_minimum_size

func _ready() -> void:
	_start_pulse()
	queue_redraw()

func is_pulsing() -> bool:
	return _tween != null and _tween.is_valid()

func _draw() -> void:
	var center := size / 2.0
	var radius: float = size.x / 2.0
	for i in range(STEPS):
		var ring_radius: float = radius * (1.0 - float(i) / STEPS)
		draw_circle(center, ring_radius, Color(tint.r, tint.g, tint.b, PEAK_ALPHA))

func _start_pulse() -> void:
	if Engine.is_editor_hint():
		return
	_tween = create_tween().set_loops()
	var half: float = UiTokens.PULSE_SECONDS / 2.0
	_tween.tween_property(self, "modulate:a", 0.5, half).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "modulate:a", 1.0, half).set_trans(Tween.TRANS_SINE)
