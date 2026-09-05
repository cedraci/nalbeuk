extends Control
class_name SkillTreeScene

signal back_requested

var status_label: Label
var nodes_container: VBoxContainer
var back_button: Button
var node_buttons: Dictionary = {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root_vbox := VBoxContainer.new()
	add_child(root_vbox)

	status_label = Label.new()
	root_vbox.add_child(status_label)

	nodes_container = VBoxContainer.new()
	root_vbox.add_child(nodes_container)

	back_button = Button.new()
	back_button.text = "Back"
	back_button.pressed.connect(_on_back_pressed)
	root_vbox.add_child(back_button)

	refresh()

func refresh() -> void:
	status_label.text = _status_text()
	for child in nodes_container.get_children():
		nodes_container.remove_child(child)
		child.queue_free()
	node_buttons.clear()
	for node: SkillNode in DwarfSkillTree.get_skill_tree():
		var button := Button.new()
		var unlocked: bool = RunState.unlocked_skill_nodes.has(node.id)
		var prerequisite_met: bool = node.requires_id == &"" or RunState.unlocked_skill_nodes.has(node.requires_id)
		var available: bool = not unlocked and prerequisite_met and RunState.skill_points > 0
		var checkmark: String = " ✓" if unlocked else ""
		button.text = "%s: %s%s" % [node.display_name, node.description, checkmark]
		button.disabled = not available
		button.pressed.connect(_on_node_button_pressed.bind(node))
		nodes_container.add_child(button)
		node_buttons[node.id] = button

func _status_text() -> String:
	if RunState.level >= RunState.MAX_LEVEL:
		return "Lv %d (MAX)   Skill Points: %d" % [RunState.level, RunState.skill_points]
	var next_threshold: int = RunState.XP_THRESHOLDS[RunState.level - 1]
	return "Lv %d   XP: %d/%d   Skill Points: %d" % [RunState.level, RunState.xp, next_threshold, RunState.skill_points]

func _on_node_button_pressed(node: SkillNode) -> void:
	RunState.unlock_skill_node(node)
	refresh()

func _on_back_pressed() -> void:
	back_requested.emit()
