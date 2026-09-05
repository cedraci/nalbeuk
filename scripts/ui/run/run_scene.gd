extends Control
class_name RunScene

var map_view: MapView
var combat_scene: CombatScene
var rest_scene: RestScene
var event_scene: EventScene
var shop_scene: ShopScene
var victory_scene: VictoryScene
var game_over_scene: GameOverScene
var skill_tree_scene: SkillTreeScene
var inventory_scene: InventoryScene
var camp_scene: CampScene

var _current_child: Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	map_view = MapView.new()
	map_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_view.node_selected.connect(_on_map_node_selected)
	map_view.skill_tree_requested.connect(_on_skill_tree_requested)
	map_view.inventory_requested.connect(_on_inventory_requested)
	add_child(map_view)
	SaveManager.load_game()
	RunState.enter_camp(DwarfContent.get_class_resource())
	_show_camp()

func _swap_to(node: Control) -> void:
	if _current_child != null and _current_child != map_view and _current_child.get_parent() == self:
		# queue_free(), not free(): this can run from inside the
		# outgoing scene's own signal-dispatch call stack (e.g. a
		# button's "pressed" handler chain), so freeing immediately
		# would destroy a node still executing its own dispatch —
		# the same bug class HandView and CombatDemo were fixed for
		# in Plan 2A.
		remove_child(_current_child)
		_current_child.queue_free()
	map_view.visible = (node == map_view)
	_current_child = node
	if node != map_view:
		add_child(node)

func _show_map() -> void:
	map_view.display(RunState.map, RunState.current_node)
	_swap_to(map_view)

func _show_camp() -> void:
	camp_scene = CampScene.new()
	camp_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	camp_scene.skill_tree_requested.connect(_on_skill_tree_requested)
	camp_scene.inventory_requested.connect(_on_inventory_requested)
	camp_scene.run_requested.connect(_on_run_requested)
	camp_scene.continue_requested.connect(_on_continue_requested)
	camp_scene.abandon_requested.connect(_on_abandon_requested)
	_swap_to(camp_scene)

# Where "Back" goes: the map during a run, Camp between runs.
func _show_home() -> void:
	if RunState.in_run:
		_show_map()
	else:
		_show_camp()

func _on_run_requested() -> void:
	RunState.start_new_run(DwarfContent.get_class_resource())
	_show_map()

func _on_continue_requested() -> void:
	if RunState.resume_run(DwarfContent.get_class_resource()):
		_show_map()
		return
	# A snapshot that cannot be restored is discarded with no penalty.
	SaveManager.run_snapshot = null
	SaveManager.save_game()
	_show_camp()

func _on_abandon_requested() -> void:
	var outcome := RunState.abandon_saved_run()
	if outcome.abandoned:
		_show_game_over(outcome)
	else:
		_show_camp()

func _on_skill_tree_requested() -> void:
	skill_tree_scene = SkillTreeScene.new()
	skill_tree_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	skill_tree_scene.back_requested.connect(_on_skill_tree_back_requested)
	_swap_to(skill_tree_scene)

func _on_skill_tree_back_requested() -> void:
	_show_home()

func _on_inventory_requested() -> void:
	inventory_scene = InventoryScene.new()
	inventory_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	inventory_scene.back_requested.connect(_on_inventory_back_requested)
	_swap_to(inventory_scene)

func _on_inventory_back_requested() -> void:
	_show_home()

func _on_map_node_selected(node: MapNode) -> void:
	match node.node_type:
		MapNode.NodeType.COMBAT, MapNode.NodeType.ELITE, MapNode.NodeType.BOSS:
			_start_combat(node)
		MapNode.NodeType.EVENT:
			_start_event(node)
		MapNode.NodeType.REST:
			_start_rest(node)
		MapNode.NodeType.SHOP:
			_start_shop(node)
		MapNode.NodeType.TREASURE:
			_start_treasure(node)

func _start_combat(node: MapNode) -> void:
	var encounter := RunState.build_encounter_for_node(node)
	combat_scene = CombatScene.new()
	combat_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	combat_scene.combat_dismissed.connect(_on_combat_dismissed.bind(node))
	_swap_to(combat_scene)
	combat_scene.start(encounter)

func _on_combat_dismissed(player_won: bool, node: MapNode) -> void:
	if player_won:
		var gold_reward: int = _gold_reward_for(node.node_type)
		var xp_reward: int = _xp_reward_for(node.node_type)
		RunState.apply_combat_reward(gold_reward, combat_scene.encounter.player.current_hp)
		RunState.grant_xp(xp_reward)
		if node.node_type == MapNode.NodeType.ELITE:
			RunState.grant_equipment(DwarfEquipment.get_random_equipment(RunState.rng))
		elif node.node_type == MapNode.NodeType.BOSS:
			RunState.grant_relic(DwarfRelics.get_random_relic(RunState.rng))
		RunState.mark_node_visited_and_advance(node)
		if node.node_type == MapNode.NodeType.BOSS:
			_show_victory(RunState.finish_run(true))
		else:
			_show_map()
	else:
		RunState.current_floor = node.floor
		_show_game_over(RunState.finish_run(false))

func _gold_reward_for(node_type: MapNode.NodeType) -> int:
	match node_type:
		MapNode.NodeType.ELITE:
			return RunState.ELITE_GOLD_REWARD
		MapNode.NodeType.BOSS:
			return RunState.BOSS_GOLD_REWARD
		_:
			return RunState.COMBAT_GOLD_REWARD

func _xp_reward_for(node_type: MapNode.NodeType) -> int:
	match node_type:
		MapNode.NodeType.ELITE:
			return RunState.ELITE_XP_REWARD
		MapNode.NodeType.BOSS:
			return RunState.BOSS_XP_REWARD
		_:
			return RunState.COMBAT_XP_REWARD

func _start_event(node: MapNode) -> void:
	event_scene = EventScene.new()
	event_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	event_scene.node_completed.connect(_on_node_completed.bind(node))
	_swap_to(event_scene)
	event_scene.display(EventsContent.get_random_event(RunState.rng))

func _start_rest(node: MapNode) -> void:
	rest_scene = RestScene.new()
	rest_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	rest_scene.node_completed.connect(_on_node_completed.bind(node))
	_swap_to(rest_scene)

func _start_shop(node: MapNode) -> void:
	shop_scene = ShopScene.new()
	shop_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	shop_scene.node_completed.connect(_on_node_completed.bind(node))
	_swap_to(shop_scene)

func _start_treasure(node: MapNode) -> void:
	RunState.grant_relic(DwarfRelics.get_random_relic(RunState.rng))
	RunState.mark_node_visited_and_advance(node)
	_show_map()

func _on_node_completed(node: MapNode) -> void:
	RunState.mark_node_visited_and_advance(node)
	_show_map()

func _show_victory(outcome: RunOutcome) -> void:
	victory_scene = VictoryScene.new()
	victory_scene.outcome = outcome
	victory_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	victory_scene.camp_requested.connect(_show_camp)
	_swap_to(victory_scene)

func _show_game_over(outcome: RunOutcome) -> void:
	game_over_scene = GameOverScene.new()
	game_over_scene.outcome = outcome
	game_over_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_over_scene.camp_requested.connect(_show_camp)
	_swap_to(game_over_scene)
