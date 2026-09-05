extends RunStateTest

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

func test_start_new_run_resets_equipment_state():
	RunState.owned_equipment = [DwarfEquipment.get_all_equipment()[0]]
	RunState.equipped_weapon = DwarfEquipment.get_all_equipment()[0]
	RunState.start_new_run(DwarfContent.get_class_resource())
	assert_eq(RunState.owned_equipment.size(), 0)
	assert_null(RunState.equipped_weapon)
	assert_null(RunState.equipped_armor)
	assert_null(RunState.equipped_trinket)

func test_grant_equipment_adds_to_owned_without_equipping():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var sword: EquipmentResource = DwarfEquipment.get_all_equipment()[0]
	RunState.grant_equipment(sword)
	assert_true(RunState.owned_equipment.has(sword))
	assert_null(RunState.equipped_weapon)

func test_equip_item_fills_the_matching_slot():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var sword: EquipmentResource = DwarfEquipment.get_all_equipment()[0]
	RunState.grant_equipment(sword)
	RunState.equip_item(sword)
	assert_eq(RunState.equipped_weapon, sword)
	assert_null(RunState.equipped_armor)
	assert_null(RunState.equipped_trinket)

func test_equipping_a_second_item_in_the_same_slot_replaces_the_first():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var equipment := DwarfEquipment.get_all_equipment()
	var sword: EquipmentResource = equipment[0]
	var hammer: EquipmentResource = equipment[1]
	RunState.grant_equipment(sword)
	RunState.grant_equipment(hammer)
	RunState.equip_item(sword)
	RunState.equip_item(hammer)
	assert_eq(RunState.equipped_weapon, hammer)
	assert_true(RunState.owned_equipment.has(sword), "The replaced item stays owned, just unequipped.")

func test_unequip_slot_clears_it():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var sword: EquipmentResource = DwarfEquipment.get_all_equipment()[0]
	RunState.grant_equipment(sword)
	RunState.equip_item(sword)
	RunState.unequip_slot(EquipmentResource.Slot.WEAPON)
	assert_null(RunState.equipped_weapon)
	assert_true(RunState.owned_equipment.has(sword))

func test_start_new_run_resets_relic_state():
	RunState.unlocked_relics = [&"iron_ration"]
	RunState.relic_bonus_strength = 2
	RunState.relic_bonus_block = 2
	RunState.relic_gold_bonus = 5
	RunState.start_new_run(DwarfContent.get_class_resource())
	assert_eq(RunState.unlocked_relics.size(), 0)
	assert_eq(RunState.relic_bonus_strength, 0)
	assert_eq(RunState.relic_bonus_block, 0)
	assert_eq(RunState.relic_gold_bonus, 0)

func test_grant_relic_applies_strength_and_block_deltas():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var relic := RelicResource.new()
	relic.id = &"test_relic"
	relic.strength_delta = 2
	relic.block_delta = 3
	RunState.grant_relic(relic)
	assert_eq(RunState.relic_bonus_strength, 2)
	assert_eq(RunState.relic_bonus_block, 3)
	assert_true(RunState.unlocked_relics.has(&"test_relic"))

func test_grant_relic_bakes_vitality_into_max_hp_permanently():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var max_hp_before: int = RunState.player_max_hp
	var relic := RelicResource.new()
	relic.id = &"test_relic"
	relic.vitality_delta = 3
	RunState.grant_relic(relic)
	assert_eq(RunState.player_max_hp, max_hp_before + 6)
	assert_eq(RunState.player_current_hp, RunState.player_max_hp)

func test_grant_relic_applies_gold_bonus():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var relic := RelicResource.new()
	relic.id = &"test_relic"
	relic.gold_bonus_per_reward = 5
	RunState.grant_relic(relic)
	assert_eq(RunState.relic_gold_bonus, 5)

func test_granting_the_same_relic_twice_stacks():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var relic := RelicResource.new()
	relic.id = &"test_relic"
	relic.strength_delta = 2
	RunState.grant_relic(relic)
	RunState.grant_relic(relic)
	assert_eq(RunState.relic_bonus_strength, 4)
	assert_eq(RunState.unlocked_relics.count(&"test_relic"), 2)

func test_start_new_run_resets_potions():
	RunState.potions = [DwarfPotions.get_all_potions()[0]]
	RunState.start_new_run(DwarfContent.get_class_resource())
	assert_eq(RunState.potions.size(), 0)

func test_add_potion_appends_up_to_the_cap():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var potions := DwarfPotions.get_all_potions()
	var added_first := RunState.add_potion(potions[0])
	var added_second := RunState.add_potion(potions[1])
	assert_true(added_first)
	assert_true(added_second)
	assert_eq(RunState.potions.size(), 2)

func test_add_potion_rejects_past_the_cap():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var potions := DwarfPotions.get_all_potions()
	RunState.add_potion(potions[0])
	RunState.add_potion(potions[1])
	var added_third := RunState.add_potion(potions[0])
	assert_false(added_third)
	assert_eq(RunState.potions.size(), 2)

func test_consume_potion_removes_and_returns_it():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var potions := DwarfPotions.get_all_potions()
	RunState.add_potion(potions[0])
	RunState.add_potion(potions[1])
	var consumed := RunState.consume_potion(0)
	assert_eq(consumed.id, potions[0].id)
	assert_eq(RunState.potions.size(), 1)
	assert_eq(RunState.potions[0].id, potions[1].id)

func test_apply_combat_reward_adds_relic_gold_bonus():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.relic_gold_bonus = 5
	RunState.gold = 0
	RunState.apply_combat_reward(10, RunState.player_current_hp)
	assert_eq(RunState.gold, 15)

func test_build_encounter_for_node_applies_equipped_weapon_and_armor():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var equipment := DwarfEquipment.get_all_equipment()
	var sword: EquipmentResource = equipment[0]
	var vest: EquipmentResource = equipment[2]
	RunState.grant_equipment(sword)
	RunState.grant_equipment(vest)
	RunState.equip_item(sword)
	RunState.equip_item(vest)
	var combat_node := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	var encounter := RunState.build_encounter_for_node(combat_node)
	assert_eq(encounter.player.baseline_strike_bonus, sword.strength_delta)
	assert_eq(encounter.player.baseline_block_bonus, vest.block_delta)

func test_build_encounter_for_node_applies_equipped_trinket_passive():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var guardian_amulet: EquipmentResource = DwarfEquipment.get_all_equipment()[5]
	RunState.grant_equipment(guardian_amulet)
	RunState.equip_item(guardian_amulet)
	var combat_node := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	var encounter := RunState.build_encounter_for_node(combat_node)
	encounter.start_player_turn()
	assert_eq(encounter.player.block, 5, "Guardian Amulet's starting-block passive should apply after the first turn begins.")

func test_build_encounter_for_node_applies_relic_bonuses():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.relic_bonus_strength = 2
	RunState.relic_bonus_block = 3
	var combat_node := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	var encounter := RunState.build_encounter_for_node(combat_node)
	assert_eq(encounter.player.baseline_strike_bonus, 2)
	assert_eq(encounter.player.baseline_block_bonus, 3)

func test_build_encounter_for_node_composes_skill_tree_equipment_and_relics():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.level_bonus_strength = 4
	RunState.relic_bonus_strength = 2
	var equipment := DwarfEquipment.get_all_equipment()
	var hammer: EquipmentResource = equipment[1]
	RunState.grant_equipment(hammer)
	RunState.equip_item(hammer)
	var combat_node := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	var encounter := RunState.build_encounter_for_node(combat_node)
	assert_eq(encounter.player.baseline_strike_bonus, 4 + 2 + hammer.strength_delta)

func test_start_new_run_seeds_level_xp_and_skills_from_meta_state():
	MetaState.level = 3
	MetaState.xp = 7
	MetaState.skill_points = 1
	MetaState.unlocked_skill_nodes = [&"dwarven_grit", &"sharpened_pick"]
	RunState.start_new_run(DwarfContent.get_class_resource())
	assert_eq(RunState.level, 3)
	assert_eq(RunState.xp, 7)
	assert_eq(RunState.skill_points, 1)
	assert_eq(RunState.unlocked_skill_nodes, [&"dwarven_grit", &"sharpened_pick"] as Array[StringName])
	assert_true(RunState.in_run)

func test_start_new_run_recomputes_bonuses_and_max_hp_from_unlocked_nodes():
	# dwarven_grit: +1 STR, +1 VIT. sharpened_pick: +2 STR. thick_hide: +3 VIT. reinforced_guard: +3 BLK.
	MetaState.unlocked_skill_nodes = [&"dwarven_grit", &"sharpened_pick", &"thick_hide", &"reinforced_guard"]
	var class_res := DwarfContent.get_class_resource()
	RunState.start_new_run(class_res)
	assert_eq(RunState.level_bonus_strength, 3)
	assert_eq(RunState.level_bonus_block, 3)
	assert_eq(RunState.player_max_hp, class_res.base_hp + 2 * 4)
	assert_eq(RunState.player_current_hp, RunState.player_max_hp)

func test_start_new_run_rehydrates_owned_and_equipped_gear_from_meta_state():
	MetaState.owned_equipment_ids = [&"rusty_shortsword", &"rusty_shortsword", &"chainmail"]
	MetaState.equipped_weapon_id = &"rusty_shortsword"
	MetaState.equipped_armor_id = &"chainmail"
	RunState.start_new_run(DwarfContent.get_class_resource())
	assert_eq(RunState.owned_equipment.size(), 3)
	assert_not_null(RunState.equipped_weapon)
	assert_eq(RunState.equipped_weapon.id, &"rusty_shortsword")
	assert_true(RunState.owned_equipment.has(RunState.equipped_weapon), "The equipped instance is one of the owned instances.")
	assert_eq(RunState.equipped_armor.id, &"chainmail")
	assert_null(RunState.equipped_trinket)

func test_start_new_run_still_resets_run_only_state():
	MetaState.level = 4
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.gold = 50
	RunState.grant_relic(DwarfRelics.get_all_relics()[0])
	RunState.add_potion(DwarfPotions.get_all_potions()[0])
	RunState.buy_card(DwarfContent.get_shop_offerings()[0], 0)
	var class_res := DwarfContent.get_class_resource()
	RunState.start_new_run(class_res)
	assert_eq(RunState.gold, 0)
	assert_eq(RunState.unlocked_relics.size(), 0)
	assert_eq(RunState.relic_bonus_strength, 0)
	assert_eq(RunState.potions.size(), 0)
	assert_eq(RunState.deck.size(), class_res.starting_deck.size())
	assert_eq(RunState.level, 4, "Persistent state is kept across runs.")

func test_enter_camp_seeds_the_character_but_starts_no_run():
	MetaState.level = 2
	MetaState.owned_equipment_ids = [&"leather_vest"]
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.gold = 30
	RunState.enter_camp(DwarfContent.get_class_resource())
	assert_false(RunState.in_run)
	assert_null(RunState.map)
	assert_null(RunState.current_node)
	assert_eq(RunState.level, 2)
	assert_eq(RunState.owned_equipment.size(), 1)
	assert_eq(RunState.gold, 0)
	assert_eq(RunState.unlocked_relics.size(), 0)
	assert_eq(RunState.potions.size(), 0)
	assert_eq(RunState.player_current_hp, RunState.player_max_hp)

func test_build_encounter_after_seeding_applies_persistent_skill_passives():
	MetaState.unlocked_skill_nodes = [&"dwarven_grit", &"thick_hide", &"reinforced_guard", &"unyielding"]
	RunState.start_new_run(DwarfContent.get_class_resource())
	var combat_node := MapNode.new(0, MapNode.NodeType.COMBAT, 0)
	var encounter := RunState.build_encounter_for_node(combat_node)
	encounter.start_player_turn()
	assert_eq(encounter.player.block, 5, "Unyielding restored from the save still gives 5 starting Block on turn 1.")

func test_grant_xp_writes_through_to_meta_state_and_saves():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.grant_xp(25)
	assert_eq(RunState.level, 2)
	assert_eq(MetaState.level, 2)
	assert_eq(MetaState.xp, 5)
	assert_eq(MetaState.skill_points, 1)
	MetaState.reset()
	assert_true(SaveManager.load_meta(), "grant_xp saved to disk.")
	assert_eq(MetaState.level, 2)
	assert_eq(MetaState.xp, 5)

func test_unlock_skill_node_writes_through_to_meta_state_and_saves():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.skill_points = 1
	var root: SkillNode = DwarfSkillTree.get_node_by_id(&"dwarven_grit")
	assert_true(RunState.unlock_skill_node(root))
	assert_eq(MetaState.unlocked_skill_nodes, [&"dwarven_grit"] as Array[StringName])
	assert_eq(MetaState.skill_points, 0)
	MetaState.reset()
	SaveManager.load_meta()
	assert_eq(MetaState.unlocked_skill_nodes, [&"dwarven_grit"] as Array[StringName])

func test_failed_unlock_does_not_touch_meta_state():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.skill_points = 0
	var root: SkillNode = DwarfSkillTree.get_node_by_id(&"dwarven_grit")
	assert_false(RunState.unlock_skill_node(root))
	assert_eq(MetaState.unlocked_skill_nodes.size(), 0)
	assert_false(SaveManager.load_meta(), "Nothing was saved.")

func test_gear_changes_inside_a_run_are_not_written_through():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var sword: EquipmentResource = DwarfEquipment.get_by_id(&"rusty_shortsword")
	RunState.grant_equipment(sword)
	RunState.equip_item(sword)
	assert_eq(MetaState.owned_equipment_ids.size(), 0)
	assert_eq(MetaState.equipped_weapon_id, &"")
	assert_false(SaveManager.load_meta(), "Nothing was saved.")

func test_gear_changes_at_camp_are_written_through_and_saved():
	MetaState.owned_equipment_ids = [&"rusty_shortsword", &"chainmail"]
	RunState.enter_camp(DwarfContent.get_class_resource())
	RunState.equip_item(RunState.owned_equipment[0])
	RunState.equip_item(RunState.owned_equipment[1])
	assert_eq(MetaState.equipped_weapon_id, &"rusty_shortsword")
	assert_eq(MetaState.equipped_armor_id, &"chainmail")
	RunState.unequip_slot(EquipmentResource.Slot.ARMOR)
	assert_eq(MetaState.equipped_armor_id, &"")
	MetaState.reset()
	assert_true(SaveManager.load_meta())
	assert_eq(MetaState.owned_equipment_ids, [&"rusty_shortsword", &"chainmail"] as Array[StringName])
	assert_eq(MetaState.equipped_weapon_id, &"rusty_shortsword")
	assert_eq(MetaState.equipped_armor_id, &"")

func test_event_xp_writes_through():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var choice := EventChoice.new()
	choice.xp_delta = 5
	RunState.apply_event_choice(choice)
	assert_eq(MetaState.xp, 5)
