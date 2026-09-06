extends Control
class_name MapPaths

# Draws the connections between map node buttons: dashed ember for
# ordinary edges, solid ember for edges leaving the current node towards
# an open node. Positions are read from the buttons' global rects, so it
# redraws after layout settles (call_deferred from MapView.display) and
# on resize.

const SAMPLES := 24
const CONTROL_OFFSET := 40.0
const LINE_WIDTH := 2.0

var _edges: Array[Dictionary] = []

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func set_edges(edges: Array[Dictionary]) -> void:
	_edges = edges
	queue_redraw()

func edge_count() -> int:
	return _edges.size()

func lit_edge_count() -> int:
	var count: int = 0
	for edge in _edges:
		if edge["lit"]:
			count += 1
	return count

func _draw() -> void:
	var inverse: Transform2D = get_global_transform().affine_inverse()
	for edge in _edges:
		var from_control: Control = edge["from"]
		var to_control: Control = edge["to"]
		var from_rect: Rect2 = from_control.get_global_rect()
		var to_rect: Rect2 = to_control.get_global_rect()
		var start: Vector2 = inverse * Vector2(from_rect.position.x + from_rect.size.x / 2.0, from_rect.position.y)
		var end: Vector2 = inverse * Vector2(to_rect.position.x + to_rect.size.x / 2.0, to_rect.position.y + to_rect.size.y)
		var points := PackedVector2Array()
		for i in range(SAMPLES + 1):
			var t: float = float(i) / SAMPLES
			points.append(start.bezier_interpolate(start + Vector2(0, -CONTROL_OFFSET), end + Vector2(0, CONTROL_OFFSET), end, t))
		if edge["lit"]:
			draw_polyline(points, UiTokens.EMBER, LINE_WIDTH, true)
		else:
			for i in range(0, SAMPLES, 2):
				draw_line(points[i], points[i + 1], UiTokens.LINE, LINE_WIDTH, true)
