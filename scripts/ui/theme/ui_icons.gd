extends RefCounted
class_name UiIcons

# Stroke icons from the design (assets/icons/*.svg, imported by Godot as
# textures). Tint at use with `modulate`.

const ICON_DIR := "res://assets/icons/"
const NODE_ICONS: Dictionary = {
	MapNode.NodeType.COMBAT: &"sword",
	MapNode.NodeType.ELITE: &"skull",
	MapNode.NodeType.EVENT: &"quest",
	MapNode.NodeType.REST: &"flame",
	MapNode.NodeType.SHOP: &"coin",
	MapNode.NodeType.TREASURE: &"chest",
	MapNode.NodeType.BOSS: &"crown",
}

static func texture(name: StringName) -> Texture2D:
	var path: String = ICON_DIR + String(name) + ".svg"
	if not ResourceLoader.exists(path):
		push_warning("UiIcons: missing icon '%s'" % name)
		return null
	return load(path) as Texture2D

static func for_node_type(node_type: MapNode.NodeType) -> Texture2D:
	return texture(NODE_ICONS[node_type])
