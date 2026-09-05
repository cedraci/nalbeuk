extends RunStateTest

func _boot_into_run() -> RunScene:
	var scene := RunScene.new()
	add_child_autofree(scene)
	scene.camp_scene.start_run_button.pressed.emit()
	return scene

func test_ready_shows_camp_not_the_map():
	var scene := RunScene.new()
	add_child_autofree(scene)
	assert_eq(scene.camp_scene.get_parent(), scene)
	assert_false(scene.map_view.visible)
	assert_false(RunState.in_run)

func test_selecting_a_combat_node_shows_combat_scene():
	var scene := _boot_into_run()
	var combat_node := MapNode.new(9999, MapNode.NodeType.COMBAT, 0)
	scene.map_view.node_selected.emit(combat_node)
	assert_eq(scene.combat_scene.get_parent(), scene)

func test_selecting_an_elite_node_builds_the_elite_encounter():
	var scene := _boot_into_run()
	var elite_node := MapNode.new(9999, MapNode.NodeType.ELITE, 0)
	scene.map_view.node_selected.emit(elite_node)
	assert_eq(scene.combat_scene.encounter.enemy.display_name, "Alpha Cave Rat")

func test_selecting_an_event_node_shows_event_scene():
	var scene := _boot_into_run()
	var event_node := MapNode.new(9999, MapNode.NodeType.EVENT, 0)
	scene.map_view.node_selected.emit(event_node)
	assert_eq(scene.event_scene.get_parent(), scene)

func test_selecting_a_rest_node_shows_rest_scene():
	var scene := _boot_into_run()
	var rest_node := MapNode.new(9999, MapNode.NodeType.REST, 0)
	scene.map_view.node_selected.emit(rest_node)
	assert_eq(scene.rest_scene.get_parent(), scene)

func test_selecting_a_shop_node_shows_shop_scene():
	var scene := _boot_into_run()
	var shop_node := MapNode.new(9999, MapNode.NodeType.SHOP, 0)
	scene.map_view.node_selected.emit(shop_node)
	assert_eq(scene.shop_scene.get_parent(), scene)

func test_completing_a_rest_node_marks_it_visited_and_returns_to_map():
	var scene := _boot_into_run()
	var rest_node := MapNode.new(9999, MapNode.NodeType.REST, 0)
	scene.map_view.node_selected.emit(rest_node)
	scene.rest_scene.heal_button.pressed.emit()
	assert_true(rest_node.visited)
	assert_eq(RunState.current_node, rest_node)
	assert_eq(scene.map_view.get_parent(), scene)
	assert_null(scene.rest_scene.get_parent())

func test_winning_a_combat_node_grants_gold_and_returns_to_map():
	var scene := _boot_into_run()
	var combat_node := MapNode.new(9999, MapNode.NodeType.COMBAT, 0)
	scene.map_view.node_selected.emit(combat_node)
	scene.combat_scene.combat_dismissed.emit(true)
	assert_eq(RunState.gold, RunState.COMBAT_GOLD_REWARD)
	assert_true(combat_node.visited)
	assert_eq(RunState.current_node, combat_node)
	assert_eq(scene.map_view.get_parent(), scene)

func test_losing_a_combat_node_shows_game_over():
	var scene := _boot_into_run()
	var combat_node := MapNode.new(9999, MapNode.NodeType.COMBAT, 0)
	scene.map_view.node_selected.emit(combat_node)
	scene.combat_scene.combat_dismissed.emit(false)
	assert_eq(scene.game_over_scene.get_parent(), scene)

func test_losing_a_combat_node_reports_the_floor_it_was_lost_on():
	var scene := _boot_into_run()
	var combat_node := MapNode.new(9999, MapNode.NodeType.COMBAT, 2)
	scene.map_view.node_selected.emit(combat_node)
	scene.combat_scene.combat_dismissed.emit(false)
	assert_eq(RunState.current_floor, 2)

func test_winning_the_boss_node_shows_victory():
	var scene := _boot_into_run()
	var boss_node := MapNode.new(9999, MapNode.NodeType.BOSS, 0)
	scene.map_view.node_selected.emit(boss_node)
	scene.combat_scene.combat_dismissed.emit(true)
	assert_eq(scene.victory_scene.get_parent(), scene)

func test_return_to_camp_from_game_over_shows_camp_with_the_run_over():
	var scene := _boot_into_run()
	var combat_node := MapNode.new(9999, MapNode.NodeType.COMBAT, 0)
	scene.map_view.node_selected.emit(combat_node)
	scene.combat_scene.combat_dismissed.emit(false)
	scene.game_over_scene.camp_button.pressed.emit()
	assert_eq(scene.camp_scene.get_parent(), scene)
	assert_false(scene.map_view.visible)
	assert_false(RunState.in_run)

func test_pressing_skill_tree_button_shows_skill_tree_scene():
	var scene := _boot_into_run()
	scene.map_view.skill_tree_requested.emit()
	assert_eq(scene.skill_tree_scene.get_parent(), scene)

func test_skill_tree_back_returns_to_map_without_advancing_position():
	var scene := _boot_into_run()
	var starting_node := RunState.current_node
	scene.map_view.skill_tree_requested.emit()
	scene.skill_tree_scene.back_requested.emit()
	assert_eq(scene.map_view.get_parent(), scene)
	assert_eq(RunState.current_node, starting_node)

func test_winning_a_combat_node_grants_xp():
	var scene := _boot_into_run()
	var combat_node := MapNode.new(9999, MapNode.NodeType.COMBAT, 0)
	scene.map_view.node_selected.emit(combat_node)
	scene.combat_scene.combat_dismissed.emit(true)
	assert_eq(RunState.xp, RunState.COMBAT_XP_REWARD)

func test_winning_an_elite_node_grants_enough_xp_to_level_up():
	var scene := _boot_into_run()
	var elite_node := MapNode.new(9999, MapNode.NodeType.ELITE, 0)
	scene.map_view.node_selected.emit(elite_node)
	scene.combat_scene.combat_dismissed.emit(true)
	assert_eq(RunState.level, 2)
	assert_eq(RunState.skill_points, 1)

func test_selecting_a_treasure_node_grants_a_relic_and_returns_to_map():
	var scene := _boot_into_run()
	var treasure_node := MapNode.new(9999, MapNode.NodeType.TREASURE, 0)
	var relics_before: int = RunState.unlocked_relics.size()
	scene.map_view.node_selected.emit(treasure_node)
	assert_eq(RunState.unlocked_relics.size(), relics_before + 1)
	assert_true(treasure_node.visited)
	assert_eq(RunState.current_node, treasure_node)
	assert_eq(scene.map_view.get_parent(), scene)

func test_winning_an_elite_node_grants_equipment():
	var scene := _boot_into_run()
	var elite_node := MapNode.new(9999, MapNode.NodeType.ELITE, 0)
	var owned_before: int = RunState.owned_equipment.size()
	scene.map_view.node_selected.emit(elite_node)
	scene.combat_scene.combat_dismissed.emit(true)
	assert_eq(RunState.owned_equipment.size(), owned_before + 1)

func test_winning_the_boss_node_grants_a_relic():
	var scene := _boot_into_run()
	var boss_node := MapNode.new(9999, MapNode.NodeType.BOSS, 0)
	var relics_before: int = RunState.unlocked_relics.size()
	scene.map_view.node_selected.emit(boss_node)
	scene.combat_scene.combat_dismissed.emit(true)
	assert_eq(RunState.unlocked_relics.size(), relics_before + 1)

func test_winning_a_plain_combat_node_grants_neither_equipment_nor_relics():
	var scene := _boot_into_run()
	var combat_node := MapNode.new(9999, MapNode.NodeType.COMBAT, 0)
	var owned_before: int = RunState.owned_equipment.size()
	var relics_before: int = RunState.unlocked_relics.size()
	scene.map_view.node_selected.emit(combat_node)
	scene.combat_scene.combat_dismissed.emit(true)
	assert_eq(RunState.owned_equipment.size(), owned_before)
	assert_eq(RunState.unlocked_relics.size(), relics_before)

func test_pressing_inventory_button_shows_inventory_scene():
	var scene := _boot_into_run()
	scene.map_view.inventory_requested.emit()
	assert_eq(scene.inventory_scene.get_parent(), scene)

func test_inventory_back_returns_to_map_without_advancing_position():
	var scene := _boot_into_run()
	var starting_node := RunState.current_node
	scene.map_view.inventory_requested.emit()
	scene.inventory_scene.back_requested.emit()
	assert_eq(scene.map_view.get_parent(), scene)
	assert_eq(RunState.current_node, starting_node)

func test_start_run_from_camp_shows_the_map_with_a_run_in_progress():
	var scene := _boot_into_run()
	assert_true(scene.map_view.visible)
	assert_true(RunState.in_run)
	assert_not_null(RunState.map)
	assert_eq(RunState.current_floor, 0)

func test_ready_loads_the_saved_character():
	MetaState.level = 3
	MetaState.unlocked_skill_nodes = [&"dwarven_grit"]
	SaveManager.save_meta()
	MetaState.reset()
	var scene := RunScene.new()
	add_child_autofree(scene)
	assert_eq(RunState.level, 3)
	assert_true(scene.camp_scene.status_label.text.begins_with("Lv 3"))

func test_losing_a_run_applies_the_death_penalty_and_shows_it():
	var scene := _boot_into_run()
	RunState.grant_equipment(DwarfEquipment.get_by_id(&"chainmail"))
	RunState.xp = 10
	var combat_node := MapNode.new(9999, MapNode.NodeType.COMBAT, 1)
	scene.map_view.node_selected.emit(combat_node)
	scene.combat_scene.combat_dismissed.emit(false)
	assert_eq(RunState.owned_equipment.size(), 0)
	assert_eq(RunState.xp, 5)
	assert_eq(MetaState.xp, 5)
	assert_false(RunState.in_run)
	assert_eq(scene.game_over_scene.outcome_label.text, "Lost 1 piece(s) of gear and 5 XP. Skills are safe.")

func test_winning_the_boss_commits_gear_and_returns_to_camp():
	var scene := _boot_into_run()
	RunState.grant_equipment(DwarfEquipment.get_by_id(&"chainmail"))
	var boss_node := MapNode.new(9999, MapNode.NodeType.BOSS, 0)
	scene.map_view.node_selected.emit(boss_node)
	scene.combat_scene.combat_dismissed.emit(true)
	assert_true(MetaState.owned_equipment_ids.has(&"chainmail"))
	assert_false(RunState.in_run)
	scene.victory_scene.camp_button.pressed.emit()
	assert_eq(scene.camp_scene.get_parent(), scene)

func test_skill_unlocked_mid_run_is_in_meta_state_immediately():
	var scene := _boot_into_run()
	RunState.skill_points = 1
	scene.map_view.skill_tree_requested.emit()
	scene.skill_tree_scene.node_buttons[&"dwarven_grit"].pressed.emit()
	assert_true(MetaState.unlocked_skill_nodes.has(&"dwarven_grit"))

func test_skill_tree_opened_from_camp_returns_to_camp():
	var scene := RunScene.new()
	add_child_autofree(scene)
	scene.camp_scene.skill_tree_requested.emit()
	assert_eq(scene.skill_tree_scene.get_parent(), scene)
	scene.skill_tree_scene.back_requested.emit()
	assert_eq(scene.camp_scene.get_parent(), scene)
	assert_false(RunState.in_run)

func test_inventory_opened_from_camp_returns_to_camp():
	var scene := RunScene.new()
	add_child_autofree(scene)
	scene.camp_scene.inventory_requested.emit()
	assert_eq(scene.inventory_scene.get_parent(), scene)
	scene.inventory_scene.back_requested.emit()
	assert_eq(scene.camp_scene.get_parent(), scene)

func test_gear_equipped_at_camp_is_saved_and_carried_into_the_run():
	MetaState.owned_equipment_ids = [&"dwarven_warhammer"]
	SaveManager.save_meta()
	var scene := RunScene.new()
	add_child_autofree(scene)
	scene.camp_scene.inventory_requested.emit()
	var options: VBoxContainer = scene.inventory_scene.slot_options_containers[EquipmentResource.Slot.WEAPON]
	options.get_child(0).pressed.emit()
	assert_eq(MetaState.equipped_weapon_id, &"dwarven_warhammer")
	scene.inventory_scene.back_requested.emit()
	scene.camp_scene.start_run_button.pressed.emit()
	assert_eq(RunState.equipped_weapon.id, &"dwarven_warhammer")
	var combat_node := MapNode.new(9999, MapNode.NodeType.COMBAT, 0)
	scene.map_view.node_selected.emit(combat_node)
	assert_eq(scene.combat_scene.encounter.player.baseline_strike_bonus, 4)
