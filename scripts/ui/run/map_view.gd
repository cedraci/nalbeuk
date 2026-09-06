extends Control
class_name MapView

signal node_selected(node: MapNode)
signal skill_tree_requested
signal inventory_requested

# Layout (1440x900): floors column on the left (60..940), right column at
# 1000 (400 wide). Floors are rows, bottom = floor 0 (start), top = boss.

const FLOORS_LEFT := 60
const FLOORS_TOP := 90
const FLOORS_WIDTH := 880
const FLOORS_HEIGHT := 760
const COLUMN_LEFT := 1000
const COLUMN_TOP := 100
const COLUMN_WIDTH := 400
const ROW_GAP := 48

var header: StatusHeader
var skill_tree_button: Button
var inventory_button: Button
var floors_container: VBoxContainer
var paths: MapPaths
var party_art: ArtPlaceholder
var banter_label: Label
var banter_who_label: Label
var relics_container: HBoxContainer
var potions_container: HBoxContainer

var _node_buttons: Array = []  # [floor][index] -> Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

func floor_count() -> int:
	return _node_buttons.size()

func node_button(floor_index: int, node_index: int) -> Button:
	return _node_buttons[floor_index][node_index]

func display(map: MapGraph, current_node: MapNode) -> void:
	for child in get_children():
		# queue_free(), not free(): display() can run again from inside a
		# node button's own "pressed" handler chain, so freeing immediately
		# would destroy a node still executing its own signal dispatch.
		remove_child(child)
		child.queue_free()
	_node_buttons = []

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_backdrop(root)
	_build_top_bar(root)
	_build_floors(root, map, current_node)
	_build_right_column(root)

func _build_backdrop(root: Control) -> void:
	var corridor := ArtPlaceholder.new()
	corridor.setup(&"map_corridor", "corridor backdrop — three parallax layers: far vault, mid pillars, near arch; scrolls as you climb", Vector2(FLOORS_WIDTH + 60, 900))
	corridor.position = Vector2(FLOORS_LEFT, 0)
	corridor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(corridor)
	var glow_top := TorchGlow.new()
	glow_top.set_radius(260)
	glow_top.position = Vector2(80, -200)
	root.add_child(glow_top)
	var glow_bottom := TorchGlow.new()
	glow_bottom.set_radius(240)
	glow_bottom.position = Vector2(520, 520)
	root.add_child(glow_bottom)

func _build_top_bar(root: Control) -> void:
	var bar := HBoxContainer.new()
	bar.position = Vector2(40, 16)
	bar.size = Vector2(1360, 52)
	bar.add_theme_constant_override(&"separation", UiTokens.SPACE_3)
	root.add_child(bar)
	header = StatusHeader.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.refresh()
	bar.add_child(header)
	skill_tree_button = Button.new()
	skill_tree_button.text = "Skill Tree"
	skill_tree_button.icon = UiIcons.texture(&"tree")
	skill_tree_button.pressed.connect(_on_skill_tree_button_pressed)
	ThemeBuilder.size_button(skill_tree_button)
	bar.add_child(skill_tree_button)
	inventory_button = Button.new()
	inventory_button.text = "Inventory"
	inventory_button.icon = UiIcons.texture(&"bag")
	inventory_button.pressed.connect(_on_inventory_button_pressed)
	ThemeBuilder.size_button(inventory_button)
	bar.add_child(inventory_button)

func _build_floors(root: Control, map: MapGraph, current_node: MapNode) -> void:
	var area := Control.new()
	area.position = Vector2(FLOORS_LEFT, FLOORS_TOP)
	area.size = Vector2(FLOORS_WIDTH, FLOORS_HEIGHT)
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(area)

	paths = MapPaths.new()
	paths.set_anchors_preset(Control.PRESET_FULL_RECT)
	area.add_child(paths)

	floors_container = VBoxContainer.new()
	floors_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	floors_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(floors_container)

	var reachable_ids: Array[int] = []
	if current_node.visited:
		reachable_ids = current_node.connections.duplicate()
	else:
		reachable_ids.append(current_node.id)

	var buttons_by_id: Dictionary = {}
	for floor_index in range(map.floors.size()):
		_node_buttons.append([])
	for floor_index in range(map.floors.size() - 1, -1, -1):
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override(&"separation", ROW_GAP)
		floors_container.add_child(row)
		for node: MapNode in map.floors[floor_index]:
			var button := _make_node_button(node, current_node, reachable_ids)
			row.add_child(button)
			_node_buttons[floor_index].append(button)
			buttons_by_id[node.id] = button

	var edges: Array[Dictionary] = []
	for floor_nodes in map.floors:
		for node: MapNode in floor_nodes:
			for target_id in node.connections:
				if not buttons_by_id.has(target_id):
					continue
				var target: Button = buttons_by_id[target_id]
				var lit: bool = node == current_node and not target.disabled
				edges.append({"from": buttons_by_id[node.id], "to": target, "lit": lit})
	paths.set_edges(edges)
	paths.queue_redraw.call_deferred()

func _make_node_button(node: MapNode, current_node: MapNode, reachable_ids: Array[int]) -> Button:
	var button := Button.new()
	var size: int = UiTokens.NODE_SIZE_BOSS if node.node_type == MapNode.NodeType.BOSS else UiTokens.NODE_SIZE
	button.custom_minimum_size = Vector2(size, size)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.icon = UiIcons.for_node_type(node.node_type)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.expand_icon = false
	button.tooltip_text = MapNode.NodeType.keys()[node.node_type]
	button.disabled = node.visited or not reachable_ids.has(node.id)
	button.theme_type_variation = _node_variation(node, current_node, reachable_ids)
	button.pressed.connect(_on_node_button_pressed.bind(node))
	return button

func _node_variation(node: MapNode, current_node: MapNode, reachable_ids: Array[int]) -> StringName:
	if node == current_node:
		return &"NodeCurrent"
	if node.visited:
		return &"NodeVisited"
	if reachable_ids.has(node.id):
		return &"NodeOpen"
	return &"NodeLocked"

func _build_right_column(root: Control) -> void:
	var column := VBoxContainer.new()
	column.position = Vector2(COLUMN_LEFT, COLUMN_TOP)
	column.size = Vector2(COLUMN_WIDTH, 760)
	column.add_theme_constant_override(&"separation", UiTokens.SPACE_4)
	root.add_child(column)

	party_art = ArtPlaceholder.new()
	party_art.setup(&"map_party", "the party, torchlit, mid-argument over which way the torch smoke is blowing — deeper corridor behind them each floor", Vector2(COLUMN_WIDTH, 300))
	column.add_child(party_art)

	var banter_panel := PanelContainer.new()
	column.add_child(banter_panel)
	var banter_box := VBoxContainer.new()
	banter_box.add_theme_constant_override(&"separation", UiTokens.SPACE_2)
	banter_panel.add_child(banter_box)
	banter_box.add_child(_eyebrow("Overheard"))
	var entry: Dictionary = BanterContent.get_overheard(RunState.rng)
	banter_label = Label.new()
	banter_label.theme_type_variation = &"Banter"
	banter_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banter_label.text = "“%s”" % String(entry["line"])
	banter_box.add_child(banter_label)
	banter_who_label = Label.new()
	banter_who_label.theme_type_variation = &"Muted"
	banter_who_label.text = "— %s" % String(entry["who"])
	banter_box.add_child(banter_who_label)

	var stock_panel := PanelContainer.new()
	column.add_child(stock_panel)
	var stock_box := VBoxContainer.new()
	stock_box.add_theme_constant_override(&"separation", UiTokens.SPACE_3)
	stock_panel.add_child(stock_box)
	stock_box.add_child(_eyebrow("Relics"))
	relics_container = HBoxContainer.new()
	relics_container.add_theme_constant_override(&"separation", UiTokens.SPACE_2)
	stock_box.add_child(relics_container)
	for relic_id in RunState.unlocked_relics:
		var relic := DwarfRelics.get_by_id(relic_id)
		if relic == null:
			continue
		var chip := StatChip.new()
		chip.setup(&"gem", relic.display_name, UiTokens.EMBER)
		relics_container.add_child(chip)
	stock_box.add_child(_eyebrow("Potions"))
	potions_container = HBoxContainer.new()
	potions_container.add_theme_constant_override(&"separation", UiTokens.SPACE_2)
	stock_box.add_child(potions_container)
	for potion in RunState.potions:
		var chip := StatChip.new()
		chip.setup(&"flask", potion.display_name, UiTokens.RUNE)
		potions_container.add_child(chip)
	for i in range(RunState.potions.size(), RunState.MAX_POTIONS):
		var empty := StatChip.new()
		empty.setup(&"flask", "empty", UiTokens.DIM)
		potions_container.add_child(empty)

func _eyebrow(text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"Eyebrow"
	label.text = text.to_upper()
	return label

func _on_node_button_pressed(node: MapNode) -> void:
	node_selected.emit(node)

func _on_skill_tree_button_pressed() -> void:
	skill_tree_requested.emit()

func _on_inventory_button_pressed() -> void:
	inventory_requested.emit()
