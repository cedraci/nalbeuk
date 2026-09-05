extends Node

# Autoload singleton, registered in project.godot as "MetaState" — the
# committed persistent record of the character. Ids and integers only;
# derived values (max HP, strength/block bonuses) are recomputed by
# RunState.load_character_from_meta(). No class_name, same rule as RunState.

var class_id: StringName = &"dwarf"
var level: int = 1
var xp: int = 0
var skill_points: int = 0
var unlocked_skill_nodes: Array[StringName] = []
var owned_equipment_ids: Array[StringName] = []
var equipped_weapon_id: StringName = &""
var equipped_armor_id: StringName = &""
var equipped_trinket_id: StringName = &""

func reset() -> void:
	class_id = &"dwarf"
	level = 1
	xp = 0
	skill_points = 0
	unlocked_skill_nodes = []
	owned_equipment_ids = []
	equipped_weapon_id = &""
	equipped_armor_id = &""
	equipped_trinket_id = &""

func to_dict() -> Dictionary:
	var skill_ids: Array = []
	for node_id in unlocked_skill_nodes:
		skill_ids.append(String(node_id))
	var gear_ids: Array = []
	for item_id in owned_equipment_ids:
		gear_ids.append(String(item_id))
	return {
		"class_id": String(class_id),
		"level": level,
		"xp": xp,
		"skill_points": skill_points,
		"unlocked_skill_nodes": skill_ids,
		"owned_equipment_ids": gear_ids,
		"equipped_weapon_id": String(equipped_weapon_id),
		"equipped_armor_id": String(equipped_armor_id),
		"equipped_trinket_id": String(equipped_trinket_id),
	}

func from_dict(data: Dictionary) -> void:
	reset()
	class_id = StringName(str(data.get("class_id", "dwarf")))
	level = maxi(int(data.get("level", 1)), 1)
	xp = maxi(int(data.get("xp", 0)), 0)
	skill_points = maxi(int(data.get("skill_points", 0)), 0)
	var raw_skills: Variant = data.get("unlocked_skill_nodes", [])
	if raw_skills is Array:
		for raw in raw_skills:
			var node_id := StringName(str(raw))
			if DwarfSkillTree.get_node_by_id(node_id) == null:
				push_warning("MetaState: unknown skill node '%s' in save, skipped" % node_id)
				continue
			unlocked_skill_nodes.append(node_id)
	var raw_gear: Variant = data.get("owned_equipment_ids", [])
	if raw_gear is Array:
		for raw in raw_gear:
			var item_id := StringName(str(raw))
			if DwarfEquipment.get_by_id(item_id) == null:
				push_warning("MetaState: unknown equipment '%s' in save, skipped" % item_id)
				continue
			owned_equipment_ids.append(item_id)
	equipped_weapon_id = _owned_or_empty(str(data.get("equipped_weapon_id", "")))
	equipped_armor_id = _owned_or_empty(str(data.get("equipped_armor_id", "")))
	equipped_trinket_id = _owned_or_empty(str(data.get("equipped_trinket_id", "")))

func _owned_or_empty(raw: String) -> StringName:
	var item_id := StringName(raw)
	if item_id == &"":
		return &""
	if owned_equipment_ids.has(item_id):
		return item_id
	push_warning("MetaState: equipped item '%s' is not owned, slot cleared" % raw)
	return &""
