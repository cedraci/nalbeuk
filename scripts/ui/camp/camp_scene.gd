extends Control
class_name CampScene

signal skill_tree_requested
signal inventory_requested
signal run_requested
signal continue_requested
signal abandon_requested

# The single story hook this plan ships; Camp dialogue proper comes later.
const FLAVOR_LINE := "The party argues over who lost the map."
const SUSPENDED_FLAVOR_LINE := "The party is still out there, arguing about which way is north."
const EMPTY_SLOT := "— empty —"

var status_label: Label
var gear_label: Label
var flavor_label: Label
var skill_tree_button: Button
var inventory_button: Button
var start_run_button: Button
var continue_run_button: Button
var abandon_run_button: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root_vbox := VBoxContainer.new()
	add_child(root_vbox)

	var title := Label.new()
	title.text = "Camp"
	root_vbox.add_child(title)

	flavor_label = Label.new()
	flavor_label.text = FLAVOR_LINE
	root_vbox.add_child(flavor_label)

	status_label = Label.new()
	root_vbox.add_child(status_label)

	gear_label = Label.new()
	root_vbox.add_child(gear_label)

	var buttons_hbox := HBoxContainer.new()
	root_vbox.add_child(buttons_hbox)

	skill_tree_button = Button.new()
	skill_tree_button.text = "Skill Tree"
	skill_tree_button.pressed.connect(_on_skill_tree_pressed)
	buttons_hbox.add_child(skill_tree_button)

	inventory_button = Button.new()
	inventory_button.text = "Inventory"
	inventory_button.pressed.connect(_on_inventory_pressed)
	buttons_hbox.add_child(inventory_button)

	start_run_button = Button.new()
	start_run_button.text = "Start Run"
	start_run_button.pressed.connect(_on_start_run_pressed)
	buttons_hbox.add_child(start_run_button)

	continue_run_button = Button.new()
	continue_run_button.text = "Continue Run"
	continue_run_button.pressed.connect(_on_continue_run_pressed)
	buttons_hbox.add_child(continue_run_button)

	abandon_run_button = Button.new()
	abandon_run_button.text = "Abandon Run"
	abandon_run_button.pressed.connect(_on_abandon_run_pressed)
	buttons_hbox.add_child(abandon_run_button)

	refresh()

func refresh() -> void:
	var suspended: bool = SaveManager.has_run_snapshot()
	status_label.text = _status_text()
	gear_label.text = "Weapon: %s   Armor: %s   Trinket: %s" % [
		_slot_name(RunState.equipped_weapon),
		_slot_name(RunState.equipped_armor),
		_slot_name(RunState.equipped_trinket),
	]
	flavor_label.text = SUSPENDED_FLAVOR_LINE if suspended else FLAVOR_LINE
	# While a run is suspended, gear and skills are frozen with it: only
	# Continue / Abandon are offered (the map's own buttons return on resume).
	skill_tree_button.visible = not suspended
	inventory_button.visible = not suspended
	start_run_button.visible = not suspended
	continue_run_button.visible = suspended
	abandon_run_button.visible = suspended

func _status_text() -> String:
	if RunState.level >= RunState.MAX_LEVEL:
		return "Lv %d (MAX)   Skill Points: %d" % [RunState.level, RunState.skill_points]
	var next_threshold: int = RunState.XP_THRESHOLDS[RunState.level - 1]
	return "Lv %d   XP: %d/%d   Skill Points: %d" % [RunState.level, RunState.xp, next_threshold, RunState.skill_points]

func _slot_name(item: EquipmentResource) -> String:
	return item.display_name if item != null else EMPTY_SLOT

func _on_skill_tree_pressed() -> void:
	skill_tree_requested.emit()

func _on_inventory_pressed() -> void:
	inventory_requested.emit()

func _on_start_run_pressed() -> void:
	run_requested.emit()

func _on_continue_run_pressed() -> void:
	continue_requested.emit()

func _on_abandon_run_pressed() -> void:
	abandon_requested.emit()
