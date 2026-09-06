extends Control
class_name TorchGlow

# A soft ember bloom that flickers — the one light source per screen.
# Purely decorative: ignores the mouse, never carries text.

const STEPS := 24
const PEAK_ALPHA := 0.02  # per ring; 24 rings stack to ~38% at the centre

var radius: float = 240.0
var _tween: Tween = null

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_radius(radius)

func _ready() -> void:
	_start_flicker()
	queue_redraw()

func set_radius(r: float) -> void:
	radius = r
	custom_minimum_size = Vector2(r * 2.0, r * 2.0)
	size = custom_minimum_size
	queue_redraw()

func is_flickering() -> bool:
	return _tween != null and _tween.is_valid()

func _draw() -> void:
	var center := Vector2(radius, radius)
	var ring := UiTokens.ember(PEAK_ALPHA)
	for i in range(STEPS):
		var ring_radius: float = radius * (1.0 - float(i) / STEPS)
		draw_circle(center, ring_radius, ring)

func _start_flicker() -> void:
	if Engine.is_editor_hint():
		return
	_tween = create_tween().set_loops()
	var half: float = UiTokens.FLICKER_SECONDS / 2.0
	_tween.tween_property(self, "modulate:a", 0.72, half).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "modulate:a", 1.0, half).set_trans(Tween.TRANS_SINE)
