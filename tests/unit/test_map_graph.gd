extends GutTest

func test_floor_zero_is_a_single_forced_combat_node():
	for seed_value in range(1, 11):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var graph := MapGraph.generate(rng)
		assert_eq(graph.floors[0].size(), 1, "seed %d" % seed_value)
		var first_node: MapNode = graph.floors[0][0]
		assert_eq(first_node.node_type, MapNode.NodeType.COMBAT, "seed %d" % seed_value)

func test_last_floor_is_a_single_forced_boss_node():
	for seed_value in range(1, 11):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var graph := MapGraph.generate(rng)
		var last_floor: Array = graph.floors[graph.floors.size() - 1]
		assert_eq(last_floor.size(), 1, "seed %d" % seed_value)
		var boss_node: MapNode = last_floor[0]
		assert_eq(boss_node.node_type, MapNode.NodeType.BOSS, "seed %d" % seed_value)

func test_every_node_above_floor_zero_has_an_incoming_connection():
	for seed_value in range(1, 11):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var graph := MapGraph.generate(rng)
		for f in range(1, graph.floors.size()):
			var incoming_ids: Dictionary = {}
			var previous_floor: Array = graph.floors[f - 1]
			for from_node in previous_floor:
				for connected_id in from_node.connections:
					incoming_ids[connected_id] = true
			var current_floor: Array = graph.floors[f]
			for node in current_floor:
				assert_true(incoming_ids.has(node.id), "seed %d floor %d node %d" % [seed_value, f, node.id])

func test_no_two_rest_nodes_share_a_floor():
	for seed_value in range(1, 11):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var graph := MapGraph.generate(rng)
		for floor_nodes in graph.floors:
			var rest_count := 0
			for node in floor_nodes:
				if node.node_type == MapNode.NodeType.REST:
					rest_count += 1
			assert_true(rest_count <= 1, "seed %d" % seed_value)

func test_connections_only_point_at_the_immediately_next_floor():
	for seed_value in range(1, 11):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var graph := MapGraph.generate(rng)
		for f in range(graph.floors.size() - 1):
			var next_floor_ids: Dictionary = {}
			var next_floor: Array = graph.floors[f + 1]
			for node in next_floor:
				next_floor_ids[node.id] = true
			var current_floor: Array = graph.floors[f]
			for node in current_floor:
				for connected_id in node.connections:
					assert_true(next_floor_ids.has(connected_id), "seed %d floor %d" % [seed_value, f])

func test_treasure_nodes_are_reachable_across_enough_seeds():
	var found_treasure := false
	for seed_value in range(1, 21):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var graph := MapGraph.generate(rng)
		for floor_nodes in graph.floors:
			for node in floor_nodes:
				if node.node_type == MapNode.NodeType.TREASURE:
					found_treasure = true
	assert_true(found_treasure, "TREASURE should appear in at least one of 20 generated maps.")

func _signature(graph: MapGraph) -> Array:
	var out: Array = []
	for floor_nodes in graph.floors:
		for node in floor_nodes:
			out.append("%d:%d:%d:%s:%s" % [node.id, node.node_type, node.floor, str(node.connections), str(node.visited)])
	return out

func test_to_dict_from_dict_round_trips_a_generated_graph():
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var graph := MapGraph.generate(rng)
	graph.floors[1][0].visited = true
	var rebuilt := MapGraph.from_dict(graph.to_dict())
	assert_not_null(rebuilt)
	assert_eq(rebuilt.floors.size(), graph.floors.size())
	assert_eq(_signature(rebuilt), _signature(graph))

func test_to_dict_survives_json():
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var graph := MapGraph.generate(rng)
	var parsed: Variant = JSON.parse_string(JSON.stringify(graph.to_dict()))
	var rebuilt := MapGraph.from_dict(parsed)
	assert_eq(_signature(rebuilt), _signature(graph))

func test_find_node_returns_the_node_or_null():
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var graph := MapGraph.generate(rng)
	var target: MapNode = graph.floors[2][0]
	assert_eq(graph.find_node(target.id), target)
	assert_null(graph.find_node(9999))

func test_from_dict_returns_null_for_malformed_data():
	assert_null(MapGraph.from_dict({}))
	assert_null(MapGraph.from_dict({"floors": []}))
	assert_null(MapGraph.from_dict({"floors": [[{"type": 0, "floor": 0}]]}), "A node without an id is malformed.")
	assert_null(MapGraph.from_dict({"floors": ["not a floor"]}))

func test_from_dict_returns_null_when_id_type_or_floor_is_not_a_number():
	assert_null(MapGraph.from_dict({"floors": [[{"id": {}, "type": 0, "floor": 0}]]}))
	assert_null(MapGraph.from_dict({"floors": [[{"id": 0, "type": "combat", "floor": 0}]]}))
	assert_null(MapGraph.from_dict({"floors": [[{"id": 0, "type": 0, "floor": [0]}]]}))
	assert_not_null(MapGraph.from_dict({"floors": [[{"id": 0.0, "type": 0.0, "floor": 0.0}]]}), "JSON floats are numbers and must still be accepted.")

func test_from_dict_returns_null_for_an_out_of_range_node_type():
	assert_null(MapGraph.from_dict({"floors": [[{"id": 0, "type": 99, "floor": 0}]]}), "99 is not a NodeType.")
	assert_null(MapGraph.from_dict({"floors": [[{"id": 0, "type": -1, "floor": 0}]]}), "-1 is not a NodeType.")
	var last_type: int = MapNode.NodeType.size() - 1
	assert_not_null(MapGraph.from_dict({"floors": [[{"id": 0, "type": last_type, "floor": 0}]]}), "The last NodeType is still valid.")

func test_from_dict_returns_null_when_a_connection_is_not_a_number():
	assert_null(MapGraph.from_dict({"floors": [[{"id": 0, "type": 0, "floor": 0, "connections": ["x"]}]]}))
	assert_null(MapGraph.from_dict({"floors": [[{"id": 0, "type": 0, "floor": 0, "connections": [1, {}]}]]}))
	assert_not_null(MapGraph.from_dict({"floors": [[{"id": 0, "type": 0, "floor": 0, "connections": [1, 2.0]}]]}), "JSON floats are still accepted.")
