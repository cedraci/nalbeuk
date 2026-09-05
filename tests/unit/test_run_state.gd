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
