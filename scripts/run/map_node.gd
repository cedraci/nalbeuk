extends RefCounted
class_name MapNode

enum NodeType { COMBAT, ELITE, EVENT, REST, SHOP, BOSS }

var id: int
var node_type: NodeType
var floor: int
var connections: Array[int] = []
var visited: bool = false

func _init(p_id: int, p_node_type: NodeType, p_floor: int) -> void:
	id = p_id
	node_type = p_node_type
	floor = p_floor
