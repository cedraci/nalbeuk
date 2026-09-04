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
