extends GutTest

func test_display_creates_one_column_per_floor():
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var node_a := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	var node_b := MapNode.new(1, MapNode.NodeType.EVENT, 1)
	node_a.connections = [1]
	var graph := MapGraph.new()
	graph.floors = [[node_a] as Array[MapNode], [node_b] as Array[MapNode]]
	map_view.display(graph, node_a)
	var floors_hbox: HBoxContainer = map_view.get_child(0)
	assert_eq(floors_hbox.get_child_count(), 2)

func test_display_enables_only_the_entry_node_before_the_run_has_moved():
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var node_a := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	var node_b := MapNode.new(1, MapNode.NodeType.EVENT, 1)
	node_a.connections = [1]
	var graph := MapGraph.new()
	graph.floors = [[node_a] as Array[MapNode], [node_b] as Array[MapNode]]
	map_view.display(graph, node_a)
	var floors_hbox: HBoxContainer = map_view.get_child(0)
	var floor0_vbox: VBoxContainer = floors_hbox.get_child(0)
	var floor1_vbox: VBoxContainer = floors_hbox.get_child(1)
	var entry_button: Button = floor0_vbox.get_child(0)
	var next_button: Button = floor1_vbox.get_child(0)
	assert_false(entry_button.disabled, "Entry node should be clickable before the run has moved.")
	assert_true(next_button.disabled, "Floor 1 node isn't reachable until the entry node is played.")

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
	var floors_hbox: HBoxContainer = map_view.get_child(0)
	var floor1_vbox: VBoxContainer = floors_hbox.get_child(1)
	var reachable_button: Button = floor1_vbox.get_child(0)
	var unreachable_button: Button = floor1_vbox.get_child(1)
	assert_false(reachable_button.disabled, "node_b is in node_a's connections.")
	assert_true(unreachable_button.disabled, "node_c is not in node_a's connections.")

func test_clicking_a_node_button_emits_node_selected():
	var map_view := MapView.new()
	add_child_autofree(map_view)
	var node_a := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	var graph := MapGraph.new()
	graph.floors = [[node_a] as Array[MapNode]]
	map_view.display(graph, node_a)
	watch_signals(map_view)
	var floors_hbox: HBoxContainer = map_view.get_child(0)
	var floor0_vbox: VBoxContainer = floors_hbox.get_child(0)
	var button: Button = floor0_vbox.get_child(0)
	button.pressed.emit()
	assert_signal_emitted_with_parameters(map_view, "node_selected", [node_a])

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
	assert_eq(map_view.get_child_count(), 1, "Only the second display() call's floor container should remain; remove_child() must detach the old one immediately, not just queue_free() it.")
