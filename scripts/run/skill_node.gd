extends RefCounted
class_name SkillNode

enum Branch { ROOT, OFFENSE, DEFENSE }

var id: StringName
var display_name: String
var description: String
var branch: Branch
var requires_id: StringName
var strength_delta: int
var vitality_delta: int
var block_delta: int
var passive_id: StringName

func _init(
	p_id: StringName,
	p_display_name: String,
	p_description: String,
	p_branch: Branch,
	p_requires_id: StringName,
	p_strength_delta: int = 0,
	p_vitality_delta: int = 0,
	p_block_delta: int = 0,
	p_passive_id: StringName = &""
) -> void:
	id = p_id
	display_name = p_display_name
	description = p_description
	branch = p_branch
	requires_id = p_requires_id
	strength_delta = p_strength_delta
	vitality_delta = p_vitality_delta
	block_delta = p_block_delta
	passive_id = p_passive_id
