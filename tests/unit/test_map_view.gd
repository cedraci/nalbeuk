extends RunStateTest

func _two_floor_graph() -> Array:
	var node_a := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	var node_b := MapNode.new(1, MapNode.NodeType.EVENT, 1)
	node_a.connections = [1]
	var graph := MapGraph.new()
	graph.floors = [[node_a] as Array[MapNode], [node_b] as Array[MapNode]]
	return [graph, node_a, node_b]

func test_display_creates_one_row_per_floor_with_floor_zero_at_the_bottom():
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var parts := _two_floor_graph()
	map_view.display(parts[0], parts[1])
	assert_eq(map_view.floor_count(), 2)
	assert_eq(map_view.floors_container.get_child_count(), 2)
	assert_eq(map_view.floors_container.get_child(1).get_child(0), map_view.node_button(0, 0), "Floor 0 is the LAST row (bottom).")
	assert_eq(map_view.floors_container.get_child(0).get_child(0), map_view.node_button(1, 0), "The top floor is the FIRST row.")

func test_display_enables_only_the_entry_node_before_the_run_has_moved():
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var parts := _two_floor_graph()
	map_view.display(parts[0], parts[1])
	assert_false(map_view.node_button(0, 0).disabled, "Entry node should be clickable before the run has moved.")
	assert_true(map_view.node_button(1, 0).disabled, "Floor 1 node isn't reachable until the entry node is played.")
	assert_eq(map_view.node_button(0, 0).theme_type_variation, &"NodeCurrent")
	assert_eq(map_view.node_button(1, 0).theme_type_variation, &"NodeLocked")

func test_display_enables_connections_of_a_visited_current_node():
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var node_a := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	node_a.visited = true
	var node_b := MapNode.new(1, MapNode.NodeType.EVENT, 1)
	var node_c := MapNode.new(2, MapNode.NodeType.SHOP, 1)
	node_a.connections = [1]
	var graph := MapGraph.new()
	graph.floors = [[node_a] as Array[MapNode], [node_b, node_c] as Array[MapNode]]
	map_view.display(graph, node_a)
	assert_false(map_view.node_button(1, 0).disabled, "node_b is in node_a's connections.")
	assert_true(map_view.node_button(1, 1).disabled, "node_c is not in node_a's connections.")
	assert_eq(map_view.node_button(1, 0).theme_type_variation, &"NodeOpen")
	assert_eq(map_view.node_button(1, 1).theme_type_variation, &"NodeLocked")
	assert_eq(map_view.node_button(0, 0).theme_type_variation, &"NodeCurrent")
	assert_true(map_view.node_button(0, 0).disabled, "A visited current node is not clickable again.")

func test_visited_nodes_behind_the_party_are_styled_visited():
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var node_a := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	node_a.visited = true
	var node_b := MapNode.new(1, MapNode.NodeType.EVENT, 1)
	node_b.visited = true
	node_a.connections = [1]
	var graph := MapGraph.new()
	graph.floors = [[node_a] as Array[MapNode], [node_b] as Array[MapNode]]
	map_view.display(graph, node_b)
	assert_eq(map_view.node_button(0, 0).theme_type_variation, &"NodeVisited")
	assert_eq(map_view.node_button(1, 0).theme_type_variation, &"NodeCurrent")

func test_node_buttons_carry_the_type_icon_and_no_text():
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var parts := _two_floor_graph()
	map_view.display(parts[0], parts[1])
	var button: Button = map_view.node_button(1, 0)
	assert_eq(button.text, "")
	assert_not_null(button.icon)
	assert_eq(button.tooltip_text, "EVENT")
	assert_eq(button.custom_minimum_size, Vector2(UiTokens.NODE_SIZE, UiTokens.NODE_SIZE))

func test_boss_nodes_are_larger():
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var node_a := MapNode.new(0, MapNode.NodeType.BOSS, 0)
	var graph := MapGraph.new()
	graph.floors = [[node_a] as Array[MapNode]]
	map_view.display(graph, node_a)
	assert_eq(map_view.node_button(0, 0).custom_minimum_size, Vector2(UiTokens.NODE_SIZE_BOSS, UiTokens.NODE_SIZE_BOSS))

func test_clicking_a_node_button_emits_node_selected():
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var node_a := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	var graph := MapGraph.new()
	graph.floors = [[node_a] as Array[MapNode]]
	map_view.display(graph, node_a)
	watch_signals(map_view)
	map_view.node_button(0, 0).pressed.emit()
	assert_signal_emitted_with_parameters(map_view, "node_selected", [node_a])

func test_paths_get_one_edge_per_connection_and_light_the_open_ones():
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var node_a := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	node_a.visited = true
	var node_b := MapNode.new(1, MapNode.NodeType.EVENT, 1)
	var node_c := MapNode.new(2, MapNode.NodeType.SHOP, 1)
	node_a.connections = [1, 2]
	var graph := MapGraph.new()
	graph.floors = [[node_a] as Array[MapNode], [node_b, node_c] as Array[MapNode]]
	map_view.display(graph, node_a)
	assert_eq(map_view.paths.edge_count(), 2)
	assert_true(map_view.paths.lit_edge_count() == 2, "Both edges leave the current node towards open nodes.")

func test_display_called_twice_leaves_only_the_current_floors_as_children():
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var node_a := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	var graph1 := MapGraph.new()
	graph1.floors = [[node_a] as Array[MapNode]]
	map_view.display(graph1, node_a)
	var node_b := MapNode.new(1, MapNode.NodeType.EVENT, 0)
	var graph2 := MapGraph.new()
	graph2.floors = [[node_b] as Array[MapNode]]
	map_view.display(graph2, node_b)
	assert_eq(map_view.get_child_count(), 1, "Only the second display() call's root remains; remove_child() must detach the old one immediately.")
	assert_eq(map_view.floor_count(), 1)

func test_display_adds_a_skill_tree_button_that_emits_skill_tree_requested():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var parts := _two_floor_graph()
	map_view.display(parts[0], parts[1])
	watch_signals(map_view)
	map_view.skill_tree_button.pressed.emit()
	assert_signal_emitted(map_view, "skill_tree_requested")

func test_display_adds_an_inventory_button_that_emits_inventory_requested():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var parts := _two_floor_graph()
	map_view.display(parts[0], parts[1])
	watch_signals(map_view)
	map_view.inventory_button.pressed.emit()
	assert_signal_emitted(map_view, "inventory_requested")

func test_header_shows_current_level_and_skill_points():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.level = 3
	RunState.skill_points = 2
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var parts := _two_floor_graph()
	map_view.display(parts[0], parts[1])
	assert_eq(map_view.header.level_label.text, "LEVEL 3")
	assert_eq(map_view.header.skill_points_chip.label.text, "2 skill points")

func test_header_shows_max_level():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.level = RunState.MAX_LEVEL
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var parts := _two_floor_graph()
	map_view.display(parts[0], parts[1])
	assert_true(map_view.header.level_label.text.contains("MAX"))

func test_the_current_node_pulses_and_survives_a_second_display():
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var parts := _two_floor_graph()
	map_view.display(parts[0], parts[1])
	assert_true(map_view.is_pulsing(), "The current node's button pulses.")
	map_view.display(parts[0], parts[1])
	assert_true(map_view.is_pulsing(), "The second display() call's tween replaces the first.")

func test_header_buttons_meet_the_hit_target():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var parts := _two_floor_graph()
	map_view.display(parts[0], parts[1])
	assert_true(map_view.skill_tree_button.custom_minimum_size.y >= UiTokens.HIT_TARGET)
	assert_true(map_view.inventory_button.custom_minimum_size.y >= UiTokens.HIT_TARGET)

func test_right_column_lists_relics_potions_and_a_banter_line():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.grant_relic(DwarfRelics.get_by_id(&"whetstone"))
	RunState.grant_relic(DwarfRelics.get_by_id(&"iron_ration"))
	RunState.add_potion(DwarfPotions.get_by_id(&"healing_draught"))
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var parts := _two_floor_graph()
	map_view.display(parts[0], parts[1])
	assert_eq(map_view.relics_container.get_child_count(), 2)
	assert_eq(map_view.potions_container.get_child_count(), RunState.MAX_POTIONS, "One chip per held potion plus dashed empties up to the cap.")
	assert_ne(map_view.banter_label.text, "")
	assert_ne(map_view.banter_who_label.text, "")
	assert_false(map_view.party_art.has_art)
