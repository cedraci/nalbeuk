extends GutTest

func test_ready_starts_a_run_and_shows_the_map():
	var scene := RunScene.new()
	add_child_autofree(scene)
	assert_eq(scene.map_view.get_parent(), scene)

func test_selecting_a_combat_node_shows_combat_scene():
	var scene := RunScene.new()
	add_child_autofree(scene)
	var combat_node := MapNode.new(9999, MapNode.NodeType.COMBAT, 0)
	scene.map_view.node_selected.emit(combat_node)
	assert_eq(scene.combat_scene.get_parent(), scene)

func test_selecting_an_elite_node_builds_the_elite_encounter():
	var scene := RunScene.new()
	add_child_autofree(scene)
	var elite_node := MapNode.new(9999, MapNode.NodeType.ELITE, 0)
	scene.map_view.node_selected.emit(elite_node)
	assert_eq(scene.combat_scene.encounter.enemy.display_name, "Alpha Cave Rat")

func test_selecting_an_event_node_shows_event_scene():
	var scene := RunScene.new()
	add_child_autofree(scene)
	var event_node := MapNode.new(9999, MapNode.NodeType.EVENT, 0)
	scene.map_view.node_selected.emit(event_node)
	assert_eq(scene.event_scene.get_parent(), scene)

func test_selecting_a_rest_node_shows_rest_scene():
	var scene := RunScene.new()
	add_child_autofree(scene)
	var rest_node := MapNode.new(9999, MapNode.NodeType.REST, 0)
	scene.map_view.node_selected.emit(rest_node)
	assert_eq(scene.rest_scene.get_parent(), scene)

func test_selecting_a_shop_node_shows_shop_scene():
	var scene := RunScene.new()
	add_child_autofree(scene)
	var shop_node := MapNode.new(9999, MapNode.NodeType.SHOP, 0)
	scene.map_view.node_selected.emit(shop_node)
	assert_eq(scene.shop_scene.get_parent(), scene)

func test_completing_a_rest_node_marks_it_visited_and_returns_to_map():
	var scene := RunScene.new()
	add_child_autofree(scene)
	var rest_node := MapNode.new(9999, MapNode.NodeType.REST, 0)
	scene.map_view.node_selected.emit(rest_node)
	scene.rest_scene.heal_button.pressed.emit()
	assert_true(rest_node.visited)
	assert_eq(RunState.current_node, rest_node)
	assert_eq(scene.map_view.get_parent(), scene)
	assert_null(scene.rest_scene.get_parent())

func test_winning_a_combat_node_grants_gold_and_returns_to_map():
	var scene := RunScene.new()
	add_child_autofree(scene)
	var combat_node := MapNode.new(9999, MapNode.NodeType.COMBAT, 0)
	scene.map_view.node_selected.emit(combat_node)
	scene.combat_scene.combat_dismissed.emit(true)
	assert_eq(RunState.gold, RunState.COMBAT_GOLD_REWARD)
	assert_true(combat_node.visited)
	assert_eq(RunState.current_node, combat_node)
	assert_eq(scene.map_view.get_parent(), scene)

func test_losing_a_combat_node_shows_game_over():
	var scene := RunScene.new()
	add_child_autofree(scene)
	var combat_node := MapNode.new(9999, MapNode.NodeType.COMBAT, 0)
	scene.map_view.node_selected.emit(combat_node)
	scene.combat_scene.combat_dismissed.emit(false)
	assert_eq(scene.game_over_scene.get_parent(), scene)

func test_losing_a_combat_node_reports_the_floor_it_was_lost_on():
	var scene := RunScene.new()
	add_child_autofree(scene)
	var combat_node := MapNode.new(9999, MapNode.NodeType.COMBAT, 2)
	scene.map_view.node_selected.emit(combat_node)
	scene.combat_scene.combat_dismissed.emit(false)
	assert_eq(RunState.current_floor, 2)

func test_winning_the_boss_node_shows_victory():
	var scene := RunScene.new()
	add_child_autofree(scene)
	var boss_node := MapNode.new(9999, MapNode.NodeType.BOSS, 0)
	scene.map_view.node_selected.emit(boss_node)
	scene.combat_scene.combat_dismissed.emit(true)
	assert_eq(scene.victory_scene.get_parent(), scene)

func test_new_run_requested_from_game_over_starts_a_fresh_run_and_shows_map():
	var scene := RunScene.new()
	add_child_autofree(scene)
	var combat_node := MapNode.new(9999, MapNode.NodeType.COMBAT, 0)
	scene.map_view.node_selected.emit(combat_node)
	scene.combat_scene.combat_dismissed.emit(false)
	scene.game_over_scene.new_run_button.pressed.emit()
	assert_eq(scene.map_view.get_parent(), scene)
	assert_eq(RunState.current_floor, 0)

func test_pressing_skill_tree_button_shows_skill_tree_scene():
	var scene := RunScene.new()
	add_child_autofree(scene)
	scene.map_view.skill_tree_requested.emit()
	assert_eq(scene.skill_tree_scene.get_parent(), scene)

func test_skill_tree_back_returns_to_map_without_advancing_position():
	var scene := RunScene.new()
	add_child_autofree(scene)
	var starting_node := RunState.current_node
	scene.map_view.skill_tree_requested.emit()
	scene.skill_tree_scene.back_requested.emit()
	assert_eq(scene.map_view.get_parent(), scene)
	assert_eq(RunState.current_node, starting_node)

func test_winning_a_combat_node_grants_xp():
	var scene := RunScene.new()
	add_child_autofree(scene)
	var combat_node := MapNode.new(9999, MapNode.NodeType.COMBAT, 0)
	scene.map_view.node_selected.emit(combat_node)
	scene.combat_scene.combat_dismissed.emit(true)
	assert_eq(RunState.xp, RunState.COMBAT_XP_REWARD)

func test_winning_an_elite_node_grants_enough_xp_to_level_up():
	var scene := RunScene.new()
	add_child_autofree(scene)
	var elite_node := MapNode.new(9999, MapNode.NodeType.ELITE, 0)
	scene.map_view.node_selected.emit(elite_node)
	scene.combat_scene.combat_dismissed.emit(true)
	assert_eq(RunState.level, 2)
	assert_eq(RunState.skill_points, 1)

func test_selecting_a_treasure_node_grants_a_relic_and_returns_to_map():
	var scene := RunScene.new()
	add_child_autofree(scene)
	var treasure_node := MapNode.new(9999, MapNode.NodeType.TREASURE, 0)
	var relics_before: int = RunState.unlocked_relics.size()
	scene.map_view.node_selected.emit(treasure_node)
	assert_eq(RunState.unlocked_relics.size(), relics_before + 1)
	assert_true(treasure_node.visited)
	assert_eq(RunState.current_node, treasure_node)
	assert_eq(scene.map_view.get_parent(), scene)

func test_winning_an_elite_node_grants_equipment():
	var scene := RunScene.new()
	add_child_autofree(scene)
	var elite_node := MapNode.new(9999, MapNode.NodeType.ELITE, 0)
	var owned_before: int = RunState.owned_equipment.size()
	scene.map_view.node_selected.emit(elite_node)
	scene.combat_scene.combat_dismissed.emit(true)
	assert_eq(RunState.owned_equipment.size(), owned_before + 1)

func test_winning_the_boss_node_grants_a_relic():
	var scene := RunScene.new()
	add_child_autofree(scene)
	var boss_node := MapNode.new(9999, MapNode.NodeType.BOSS, 0)
	var relics_before: int = RunState.unlocked_relics.size()
	scene.map_view.node_selected.emit(boss_node)
	scene.combat_scene.combat_dismissed.emit(true)
	assert_eq(RunState.unlocked_relics.size(), relics_before + 1)

func test_winning_a_plain_combat_node_grants_neither_equipment_nor_relics():
	var scene := RunScene.new()
	add_child_autofree(scene)
	var combat_node := MapNode.new(9999, MapNode.NodeType.COMBAT, 0)
	var owned_before: int = RunState.owned_equipment.size()
	var relics_before: int = RunState.unlocked_relics.size()
	scene.map_view.node_selected.emit(combat_node)
	scene.combat_scene.combat_dismissed.emit(true)
	assert_eq(RunState.owned_equipment.size(), owned_before)
	assert_eq(RunState.unlocked_relics.size(), relics_before)

func test_pressing_inventory_button_shows_inventory_scene():
	var scene := RunScene.new()
	add_child_autofree(scene)
	scene.map_view.inventory_requested.emit()
	assert_eq(scene.inventory_scene.get_parent(), scene)

func test_inventory_back_returns_to_map_without_advancing_position():
	var scene := RunScene.new()
	add_child_autofree(scene)
	var starting_node := RunState.current_node
	scene.map_view.inventory_requested.emit()
	scene.inventory_scene.back_requested.emit()
	assert_eq(scene.map_view.get_parent(), scene)
	assert_eq(RunState.current_node, starting_node)
