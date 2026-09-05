extends GutTest

func test_start_new_run_resets_state_from_class_resource():
	var class_res := DwarfContent.get_class_resource()
	RunState.start_new_run(class_res)
	assert_eq(RunState.deck.size(), class_res.starting_deck.size())
	assert_eq(RunState.player_current_hp, RunState.player_max_hp)
	assert_eq(RunState.gold, 0)
	assert_eq(RunState.current_floor, 0)
	assert_eq(RunState.current_node.node_type, MapNode.NodeType.COMBAT)

func test_build_encounter_for_node_uses_current_hp_not_max_hp():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.player_current_hp = 5
	var combat_node := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	var encounter := RunState.build_encounter_for_node(combat_node)
	assert_eq(encounter.player.current_hp, 5)

func test_build_encounter_for_node_uses_elite_enemy_for_elite_nodes():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var elite_node := MapNode.new(0, MapNode.NodeType.ELITE, 0)
	var encounter := RunState.build_encounter_for_node(elite_node)
	assert_eq(encounter.enemy.display_name, "Alpha Cave Rat")

func test_build_encounter_for_node_uses_boss_enemy_for_boss_nodes():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var boss_node := MapNode.new(0, MapNode.NodeType.BOSS, 0)
	var encounter := RunState.build_encounter_for_node(boss_node)
	assert_eq(encounter.enemy.display_name, "Cave Rat Matriarch")

func test_build_encounter_for_node_applies_level_bonus_strength_and_block():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.level_bonus_strength = 4
	RunState.level_bonus_block = 3
	var combat_node := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	var encounter := RunState.build_encounter_for_node(combat_node)
	assert_eq(encounter.player.baseline_strike_bonus, 4)
	assert_eq(encounter.player.baseline_block_bonus, 3)

func test_build_encounter_for_node_uses_player_max_hp_as_source_of_truth():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.player_max_hp += 10
	RunState.player_current_hp = RunState.player_max_hp
	var combat_node := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	var encounter := RunState.build_encounter_for_node(combat_node)
	assert_eq(encounter.player.max_hp, RunState.player_max_hp)

func test_build_encounter_for_node_applies_battle_fury_passive():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.unlocked_skill_nodes.append(&"battle_fury")
	var combat_node := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	var encounter := RunState.build_encounter_for_node(combat_node)
	assert_eq(encounter.player.get_status_stacks(&"strength"), 2)

func test_build_encounter_for_node_applies_unyielding_passive():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.unlocked_skill_nodes.append(&"unyielding")
	var combat_node := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	var encounter := RunState.build_encounter_for_node(combat_node)
	assert_eq(encounter.player.starting_block, 5, "The bonus should be staged before the turn loop's first clear_block().")
	encounter.start_player_turn()
	assert_eq(encounter.player.block, 5, "Unyielding should actually grant 5 Block once the first turn begins.")
	assert_eq(encounter.player.starting_block, 0, "The one-shot bonus must not be available to reapply.")

func test_build_encounter_for_node_composes_all_level_bonuses_and_capstones_together():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.level_bonus_strength = 4
	RunState.level_bonus_block = 3
	RunState.unlocked_skill_nodes.append(&"battle_fury")
	RunState.unlocked_skill_nodes.append(&"unyielding")
	var combat_node := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	var encounter := RunState.build_encounter_for_node(combat_node)
	encounter.start_player_turn()
	assert_eq(encounter.player.baseline_strike_bonus, 4)
	assert_eq(encounter.player.baseline_block_bonus, 3)
	assert_eq(encounter.player.get_status_stacks(&"strength"), 2)
	assert_eq(encounter.player.block, 5)

func test_build_encounter_for_node_without_any_skill_nodes_has_no_bonuses():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var combat_node := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	var encounter := RunState.build_encounter_for_node(combat_node)
	assert_eq(encounter.player.baseline_strike_bonus, 0)
	assert_eq(encounter.player.baseline_block_bonus, 0)
	assert_eq(encounter.player.block, 0)

func test_heal_clamps_to_max_hp():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.player_current_hp = RunState.player_max_hp - 3
	RunState.heal(100)
	assert_eq(RunState.player_current_hp, RunState.player_max_hp)

func test_upgrade_card_replaces_matching_card_in_deck():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.upgrade_card(&"dwarf_guard")
	var found_upgraded := false
	for card in RunState.deck:
		if card.id == &"dwarf_guard_plus":
			found_upgraded = true
	assert_true(found_upgraded)

func test_apply_event_choice_applies_gold_and_hp_deltas_clamped():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.gold = 5
	RunState.player_current_hp = RunState.player_max_hp
	var choice := EventChoice.new()
	choice.gold_delta = -20
	choice.hp_delta = -3
	RunState.apply_event_choice(choice)
	assert_eq(RunState.gold, 0, "Gold should clamp at 0, not go negative.")
	assert_eq(RunState.player_current_hp, RunState.player_max_hp - 3)

func test_buy_card_deducts_gold_and_appends_card_when_affordable():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.gold = 20
	var deck_size_before := RunState.deck.size()
	var bought := RunState.buy_card(DwarfContent.get_upgraded_card(&"dwarf_strike"), 15)
	assert_true(bought)
	assert_eq(RunState.gold, 5)
	assert_eq(RunState.deck.size(), deck_size_before + 1)

func test_buy_card_fails_when_too_poor():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.gold = 5
	var deck_size_before := RunState.deck.size()
	var bought := RunState.buy_card(DwarfContent.get_upgraded_card(&"dwarf_strike"), 15)
	assert_false(bought)
	assert_eq(RunState.gold, 5)
	assert_eq(RunState.deck.size(), deck_size_before)

func test_apply_combat_reward_adds_gold_and_writes_back_hp():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.gold = 0
	RunState.apply_combat_reward(10, 12)
	assert_eq(RunState.gold, 10)
	assert_eq(RunState.player_current_hp, 12)

func test_mark_node_visited_and_advance_updates_position():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var next_node := MapNode.new(99, MapNode.NodeType.EVENT, 1)
	RunState.mark_node_visited_and_advance(next_node)
	assert_true(next_node.visited)
	assert_eq(RunState.current_node, next_node)
	assert_eq(RunState.current_floor, 1)

func test_start_new_run_resets_leveling_state():
	RunState.level = 5
	RunState.xp = 40
	RunState.skill_points = 3
	RunState.unlocked_skill_nodes = [&"dwarven_grit"]
	RunState.level_bonus_strength = 6
	RunState.level_bonus_block = 3
	RunState.start_new_run(DwarfContent.get_class_resource())
	assert_eq(RunState.level, 1)
	assert_eq(RunState.xp, 0)
	assert_eq(RunState.skill_points, 0)
	assert_eq(RunState.unlocked_skill_nodes.size(), 0)
	assert_eq(RunState.level_bonus_strength, 0)
	assert_eq(RunState.level_bonus_block, 0)

func test_grant_xp_levels_up_and_grants_a_skill_point_at_threshold():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.grant_xp(RunState.XP_THRESHOLDS[0])
	assert_eq(RunState.level, 2)
	assert_eq(RunState.skill_points, 1)
	assert_eq(RunState.xp, 0)

func test_grant_xp_can_cause_multiple_level_ups_in_one_call():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var big_reward: int = RunState.XP_THRESHOLDS[0] + RunState.XP_THRESHOLDS[1]
	RunState.grant_xp(big_reward)
	assert_eq(RunState.level, 3)
	assert_eq(RunState.skill_points, 2)
	assert_eq(RunState.xp, 0)

func test_grant_xp_leaves_remainder_below_the_next_threshold():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.grant_xp(RunState.XP_THRESHOLDS[0] + 5)
	assert_eq(RunState.level, 2)
	assert_eq(RunState.xp, 5)

func test_grant_xp_does_nothing_once_at_max_level():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.level = RunState.MAX_LEVEL
	RunState.skill_points = 0
	RunState.xp = 0
	RunState.grant_xp(1000)
	assert_eq(RunState.level, RunState.MAX_LEVEL)
	assert_eq(RunState.skill_points, 0)
	assert_eq(RunState.xp, 0)

func test_unlock_skill_node_spends_a_point_and_applies_deltas():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.skill_points = 1
	var max_hp_before: int = RunState.player_max_hp
	var node := SkillNode.new(&"test_node", "Test Node", "desc", SkillNode.Branch.ROOT, &"", 2, 3, 1, &"")
	var unlocked := RunState.unlock_skill_node(node)
	assert_true(unlocked)
	assert_eq(RunState.skill_points, 0)
	assert_eq(RunState.level_bonus_strength, 2)
	assert_eq(RunState.level_bonus_block, 1)
	assert_eq(RunState.player_max_hp, max_hp_before + 6)
	assert_eq(RunState.player_current_hp, RunState.player_max_hp)
	assert_true(RunState.unlocked_skill_nodes.has(&"test_node"))

func test_unlock_skill_node_fails_with_no_points():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.skill_points = 0
	var node := SkillNode.new(&"test_node", "Test Node", "desc", SkillNode.Branch.ROOT, &"")
	var unlocked := RunState.unlock_skill_node(node)
	assert_false(unlocked)
	assert_false(RunState.unlocked_skill_nodes.has(&"test_node"))

func test_unlock_skill_node_fails_when_prerequisite_unmet():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.skill_points = 1
	var node := SkillNode.new(&"child_node", "Child", "desc", SkillNode.Branch.OFFENSE, &"parent_node")
	var unlocked := RunState.unlock_skill_node(node)
	assert_false(unlocked)
	assert_eq(RunState.skill_points, 1)

func test_unlock_skill_node_fails_when_already_unlocked():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.skill_points = 2
	var node := SkillNode.new(&"test_node", "Test Node", "desc", SkillNode.Branch.ROOT, &"", 2)
	RunState.unlock_skill_node(node)
	var unlocked_again := RunState.unlock_skill_node(node)
	assert_false(unlocked_again)
	assert_eq(RunState.skill_points, 1)
	assert_eq(RunState.level_bonus_strength, 2, "Buying the same node twice must not double-apply its bonus.")

func test_apply_event_choice_grants_xp():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var choice := EventChoice.new()
	choice.xp_delta = 5
	RunState.apply_event_choice(choice)
	assert_eq(RunState.xp, 5)

func test_apply_event_choice_xp_can_trigger_a_level_up():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var choice := EventChoice.new()
	choice.xp_delta = RunState.XP_THRESHOLDS[0]
	RunState.apply_event_choice(choice)
	assert_eq(RunState.level, 2)
	assert_eq(RunState.skill_points, 1)

func test_grant_xp_zeroes_leftover_xp_when_reaching_max_level():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.level = RunState.MAX_LEVEL - 1
	RunState.xp = 0
	var threshold_to_max: int = RunState.XP_THRESHOLDS[RunState.MAX_LEVEL - 2]
	RunState.grant_xp(threshold_to_max + 500)
	assert_eq(RunState.level, RunState.MAX_LEVEL)
	assert_eq(RunState.xp, 0)
