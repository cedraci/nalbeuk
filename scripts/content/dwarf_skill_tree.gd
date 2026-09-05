extends RefCounted
class_name DwarfSkillTree

static func get_skill_tree() -> Array[SkillNode]:
	var nodes: Array[SkillNode] = [
		SkillNode.new(
			&"dwarven_grit", "Dwarven Grit",
			"A dwarf's stubborn constitution.",
			SkillNode.Branch.ROOT, &"", 1, 1, 0, &""
		),
		SkillNode.new(
			&"sharpened_pick", "Sharpened Pick",
			"Keep the edge keen.",
			SkillNode.Branch.OFFENSE, &"dwarven_grit", 2, 0, 0, &""
		),
		SkillNode.new(
			&"heavy_swing", "Heavy Swing",
			"Put your whole back into it.",
			SkillNode.Branch.OFFENSE, &"sharpened_pick", 3, 0, 0, &""
		),
		SkillNode.new(
			&"battle_fury", "Battle Fury",
			"Start every fight already furious: +2 Strength stacks.",
			SkillNode.Branch.OFFENSE, &"heavy_swing", 0, 0, 0, &"bonus_strength_stack"
		),
		SkillNode.new(
			&"thick_hide", "Thick Hide",
			"Dwarven skin, dwarven stubbornness.",
			SkillNode.Branch.DEFENSE, &"dwarven_grit", 0, 3, 0, &""
		),
		SkillNode.new(
			&"reinforced_guard", "Reinforced Guard",
			"A shield worth trusting.",
			SkillNode.Branch.DEFENSE, &"thick_hide", 0, 0, 3, &""
		),
		SkillNode.new(
			&"unyielding", "Unyielding",
			"Brace before the first blow lands: start combat with 5 Block.",
			SkillNode.Branch.DEFENSE, &"reinforced_guard", 0, 0, 0, &"bonus_starting_block"
		),
	]
	return nodes
