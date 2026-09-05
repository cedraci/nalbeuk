extends GutTest

func test_get_skill_tree_returns_seven_well_formed_nodes():
	var nodes := DwarfSkillTree.get_skill_tree()
	assert_eq(nodes.size(), 7)
	for node in nodes:
		assert_ne(node.display_name, "")
		assert_ne(node.description, "")

func test_get_skill_tree_has_exactly_one_root_node():
	var nodes := DwarfSkillTree.get_skill_tree()
	var root_count := 0
	for node in nodes:
		if node.requires_id == &"":
			root_count += 1
	assert_eq(root_count, 1)

func test_get_skill_tree_offense_branch_chains_in_order():
	var nodes := DwarfSkillTree.get_skill_tree()
	var by_id: Dictionary = {}
	for node in nodes:
		by_id[node.id] = node
	assert_eq(by_id[&"sharpened_pick"].requires_id, &"dwarven_grit")
	assert_eq(by_id[&"heavy_swing"].requires_id, &"sharpened_pick")
	assert_eq(by_id[&"battle_fury"].requires_id, &"heavy_swing")
	assert_eq(by_id[&"battle_fury"].passive_id, &"battle_fury")

func test_get_skill_tree_defense_branch_chains_in_order():
	var nodes := DwarfSkillTree.get_skill_tree()
	var by_id: Dictionary = {}
	for node in nodes:
		by_id[node.id] = node
	assert_eq(by_id[&"thick_hide"].requires_id, &"dwarven_grit")
	assert_eq(by_id[&"reinforced_guard"].requires_id, &"thick_hide")
	assert_eq(by_id[&"unyielding"].requires_id, &"reinforced_guard")
	assert_eq(by_id[&"unyielding"].passive_id, &"unyielding")

func test_get_skill_tree_root_grants_strength_and_vitality():
	var nodes := DwarfSkillTree.get_skill_tree()
	var root: SkillNode = nodes[0]
	assert_eq(root.id, &"dwarven_grit")
	assert_eq(root.strength_delta, 1)
	assert_eq(root.vitality_delta, 1)
