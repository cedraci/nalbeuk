extends Control
class_name CampScene

signal skill_tree_requested
signal inventory_requested
signal run_requested
signal continue_requested
signal abandon_requested

# The single story hook this layer ships; Camp dialogue proper comes later.
const FLAVOR_LINE := "The party argues over who lost the map."
const SUSPENDED_FLAVOR_LINE := "The party is still out there, arguing about which way is north."
const EMPTY_SLOT := "— empty —"

# Layout (1440x900): art fills the left 820px; the column sits at 880.
const ART_WIDTH := 820
const COLUMN_LEFT := 880
const COLUMN_TOP := 90
const COLUMN_WIDTH := 500

var camp_art: ArtPlaceholder
var flavor_label: Label
var header: StatusHeader
var gear_rows: Dictionary = {}
var skill_tree_button: Button
var inventory_button: Button
var start_run_button: Button
var continue_run_button: Button
var abandon_run_button: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	camp_art = ArtPlaceholder.new()
	camp_art.setup(&"camp_fire", "camp: a low fire in a stone alcove, packs against the wall, the party arguing in silhouette; one of them is trying to light the fire with a spellbook", Vector2(ART_WIDTH, 900))
	camp_art.position = Vector2.ZERO
	add_child(camp_art)
	var glow := TorchGlow.new()
	glow.set_radius(280)
	glow.position = Vector2(120, 300)
	add_child(glow)

	var column := VBoxContainer.new()
	column.position = Vector2(COLUMN_LEFT, COLUMN_TOP)
	column.size = Vector2(COLUMN_WIDTH, 760)
	column.add_theme_constant_override(&"separation", UiTokens.SPACE_5)
	add_child(column)

	var eyebrow := Label.new()
	eyebrow.theme_type_variation = &"Eyebrow"
	eyebrow.text = "BETWEEN EXPEDITIONS"
	column.add_child(eyebrow)
	var title := Label.new()
	title.theme_type_variation = &"Display"
	title.text = "CAMP"
	column.add_child(title)
	flavor_label = Label.new()
	flavor_label.theme_type_variation = &"Banter"
	flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(flavor_label)

	var status_panel := PanelContainer.new()
	column.add_child(status_panel)
	var status_box := VBoxContainer.new()
	status_box.add_theme_constant_override(&"separation", UiTokens.SPACE_3)
	status_panel.add_child(status_box)
	header = StatusHeader.new()
	header.set_gold_visible(false)
	header.set_hp_visible(false)
	status_box.add_child(header)
	for slot in [EquipmentResource.Slot.WEAPON, EquipmentResource.Slot.ARMOR, EquipmentResource.Slot.TRINKET]:
		var row := GearRow.new()
		status_box.add_child(row)
		gear_rows[slot] = row

	var actions := VBoxContainer.new()
	actions.add_theme_constant_override(&"separation", UiTokens.SPACE_3)
	column.add_child(actions)
	start_run_button = Button.new()
	start_run_button.text = "Start run"
	start_run_button.icon = UiIcons.texture(&"flame")
	start_run_button.theme_type_variation = &"Primary"
	start_run_button.custom_minimum_size = Vector2(0, 56)
	start_run_button.pressed.connect(_on_start_run_pressed)
	actions.add_child(start_run_button)
	var secondary := HBoxContainer.new()
	secondary.add_theme_constant_override(&"separation", UiTokens.SPACE_3)
	actions.add_child(secondary)
	skill_tree_button = Button.new()
	skill_tree_button.text = "Skill Tree"
	skill_tree_button.icon = UiIcons.texture(&"tree")
	skill_tree_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_tree_button.pressed.connect(_on_skill_tree_pressed)
	secondary.add_child(skill_tree_button)
	inventory_button = Button.new()
	inventory_button.text = "Inventory"
	inventory_button.icon = UiIcons.texture(&"bag")
	inventory_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_button.pressed.connect(_on_inventory_pressed)
	secondary.add_child(inventory_button)
	var suspended_row := HBoxContainer.new()
	suspended_row.add_theme_constant_override(&"separation", UiTokens.SPACE_3)
	actions.add_child(suspended_row)
	continue_run_button = Button.new()
	continue_run_button.text = "Continue run"
	continue_run_button.theme_type_variation = &"Primary"
	continue_run_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	continue_run_button.pressed.connect(_on_continue_run_pressed)
	suspended_row.add_child(continue_run_button)
	abandon_run_button = Button.new()
	abandon_run_button.text = "Abandon run"
	abandon_run_button.theme_type_variation = &"Danger"
	abandon_run_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	abandon_run_button.pressed.connect(_on_abandon_run_pressed)
	suspended_row.add_child(abandon_run_button)

	refresh()

func refresh() -> void:
	var suspended: bool = SaveManager.has_run_snapshot()
	header.refresh()
	gear_rows[EquipmentResource.Slot.WEAPON].set_item("Weapon", RunState.equipped_weapon)
	gear_rows[EquipmentResource.Slot.ARMOR].set_item("Armor", RunState.equipped_armor)
	gear_rows[EquipmentResource.Slot.TRINKET].set_item("Trinket", RunState.equipped_trinket)
	flavor_label.text = SUSPENDED_FLAVOR_LINE if suspended else FLAVOR_LINE
	# While a run is suspended, gear and skills are frozen with it: only
	# Continue / Abandon are offered (the map's own buttons return on resume).
	skill_tree_button.visible = not suspended
	inventory_button.visible = not suspended
	start_run_button.visible = not suspended
	continue_run_button.visible = suspended
	abandon_run_button.visible = suspended

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
