extends RefCounted
class_name MapGraph

const FLOOR_COUNT := 8
const MIN_NODES_PER_FLOOR := 2
const MAX_NODES_PER_FLOOR := 4

var floors: Array = []

static func generate(rng: RandomNumberGenerator) -> MapGraph:
	var graph := MapGraph.new()
	var next_id := 0

	var entry_node := MapNode.new(next_id, MapNode.NodeType.COMBAT, 0)
	next_id += 1
	graph.floors.append([entry_node] as Array[MapNode])

	for f in range(1, FLOOR_COUNT - 1):
		var node_count: int = rng.randi_range(MIN_NODES_PER_FLOOR, MAX_NODES_PER_FLOOR)
		var floor_nodes: Array[MapNode] = []
		var rest_used_this_floor := false
		for i in range(node_count):
			var node_type: MapNode.NodeType = _pick_weighted_node_type(rng, rest_used_this_floor)
			if node_type == MapNode.NodeType.REST:
				rest_used_this_floor = true
			floor_nodes.append(MapNode.new(next_id, node_type, f))
			next_id += 1
		graph.floors.append(floor_nodes)

	var boss_node := MapNode.new(next_id, MapNode.NodeType.BOSS, FLOOR_COUNT - 1)
	next_id += 1
	graph.floors.append([boss_node] as Array[MapNode])

	for f in range(graph.floors.size() - 1):
		_connect_floors(graph.floors[f], graph.floors[f + 1], rng)

	return graph

static func _pick_weighted_node_type(rng: RandomNumberGenerator, rest_already_used: bool) -> MapNode.NodeType:
	var pool: Array[MapNode.NodeType] = [
		MapNode.NodeType.COMBAT,
		MapNode.NodeType.COMBAT,
		MapNode.NodeType.ELITE,
		MapNode.NodeType.EVENT,
		MapNode.NodeType.EVENT,
		MapNode.NodeType.SHOP,
	]
	if not rest_already_used:
		pool.append(MapNode.NodeType.REST)
	return pool[rng.randi_range(0, pool.size() - 1)]

static func _connect_floors(from_floor: Array[MapNode], to_floor: Array[MapNode], rng: RandomNumberGenerator) -> void:
	var incoming_counts: Dictionary = {}
	for to_node in to_floor:
		incoming_counts[to_node.id] = 0

	for from_node in from_floor:
		var connection_count: int = min(rng.randi_range(1, 2), to_floor.size())
		var chosen_indices: Array[int] = []
		while chosen_indices.size() < connection_count:
			var idx: int = rng.randi_range(0, to_floor.size() - 1)
			if not chosen_indices.has(idx):
				chosen_indices.append(idx)
		for idx in chosen_indices:
			var to_node: MapNode = to_floor[idx]
			from_node.connections.append(to_node.id)
			incoming_counts[to_node.id] += 1

	for to_node in to_floor:
		if incoming_counts[to_node.id] == 0:
			var from_node: MapNode = from_floor[rng.randi_range(0, from_floor.size() - 1)]
			from_node.connections.append(to_node.id)
			incoming_counts[to_node.id] += 1
