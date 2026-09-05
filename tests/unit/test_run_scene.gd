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
