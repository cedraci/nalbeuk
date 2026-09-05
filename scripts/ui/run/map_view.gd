extends Control
class_name MapView

signal node_selected(node: MapNode)
signal skill_tree_requested

var status_label: Label
var skill_tree_button: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

func display(map: MapGraph, current_node: MapNode) -> void:
	for child in get_children():
		# queue_free(), not free(): display() can run again from inside a
		# node button's own "pressed" handler chain (the same reason
		# HandView.display() needed this in Plan 2A), so freeing
		# immediately would destroy a node still executing its own
		# signal dispatch.
		remove_child(child)
		child.queue_free()

	var reachable_ids: Array[int] = []
	if current_node.visited:
		reachable_ids = current_node.connections.duplicate()
	else:
		reachable_ids.append(current_node.id)

	var floors_hbox := HBoxContainer.new()
	add_child(floors_hbox)
	for floor_nodes in map.floors:
		var floor_vbox := VBoxContainer.new()
		floors_hbox.add_child(floor_vbox)
		for node: MapNode in floor_nodes:
			var button := Button.new()
			var node_type_name: String = MapNode.NodeType.keys()[node.node_type]
			button.text = node_type_name
			button.disabled = node.visited or not reachable_ids.has(node.id)
			button.pressed.connect(_on_node_button_pressed.bind(node))
			floor_vbox.add_child(button)

	var header_hbox := HBoxContainer.new()
	add_child(header_hbox)

	status_label = Label.new()
	status_label.text = _status_text()
	header_hbox.add_child(status_label)

	skill_tree_button = Button.new()
	skill_tree_button.text = "Skill Tree"
	skill_tree_button.pressed.connect(_on_skill_tree_button_pressed)
	header_hbox.add_child(skill_tree_button)

func _status_text() -> String:
	if RunState.level >= RunState.MAX_LEVEL:
		return "Lv %d (MAX)   Skill Points: %d" % [RunState.level, RunState.skill_points]
	var next_threshold: int = RunState.XP_THRESHOLDS[RunState.level - 1]
	return "Lv %d   XP: %d/%d   Skill Points: %d" % [RunState.level, RunState.xp, next_threshold, RunState.skill_points]

func _on_node_button_pressed(node: MapNode) -> void:
	node_selected.emit(node)

func _on_skill_tree_button_pressed() -> void:
	skill_tree_requested.emit()
