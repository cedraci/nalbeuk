extends RunStateTest

func _map_signature(graph: MapGraph) -> Array:
	var out: Array = []
	for floor_nodes in graph.floors:
		for node in floor_nodes:
			out.append("%d:%d:%d:%s:%s" % [node.id, node.node_type, node.floor, str(node.connections), str(node.visited)])
	return out

func _deck_ids() -> Array:
	var out: Array = []
	for card in RunState.deck:
		out.append(card.id)
	return out

func _start_and_mutate_a_run() -> MapNode:
	MetaState.unlocked_skill_nodes = [&"dwarven_grit"]
	RunState.start_new_run(DwarfContent.get_class_resource())
	var second_floor_node: MapNode = RunState.map.floors[1][0]
	RunState.mark_node_visited_and_advance(second_floor_node)
	RunState.gold = 40
	RunState.buy_card(DwarfContent.get_shop_offerings()[1], 15)
	RunState.upgrade_card(&"dwarf_strike")
	RunState.grant_relic(DwarfRelics.get_by_id(&"iron_ration"))
	RunState.grant_relic(DwarfRelics.get_by_id(&"whetstone"))
	RunState.add_potion(DwarfPotions.get_by_id(&"vigor_tonic"))
	RunState.grant_equipment(DwarfEquipment.get_by_id(&"chainmail"))
	RunState.equip_item(RunState.owned_equipment[0])
	RunState.player_current_hp = 9
	return second_floor_node

func test_capture_then_restore_reproduces_the_run():
	var saved_node := _start_and_mutate_a_run()
	var expected_map := _map_signature(RunState.map)
	var expected_deck := _deck_ids()
	var expected_max_hp: int = RunState.player_max_hp
	var data := RunSnapshot.capture()
	var expected_next_random: int = RunState.rng.randi()
	RunState.enter_camp(DwarfContent.get_class_resource())
	assert_null(RunState.map, "enter_camp wiped the run before restore.")
	assert_true(RunSnapshot.restore(data))
	assert_eq(_map_signature(RunState.map), expected_map)
	assert_eq(RunState.current_node.id, saved_node.id)
	assert_eq(RunState.current_floor, 1)
	assert_eq(_deck_ids(), expected_deck)
	assert_eq(RunState.player_max_hp, expected_max_hp, "Relic vitality is already baked into the saved max HP.")
	assert_eq(RunState.player_current_hp, 9)
	assert_eq(RunState.gold, 25)
	assert_eq(RunState.unlocked_relics, [&"iron_ration", &"whetstone"] as Array[StringName])
	assert_eq(RunState.relic_bonus_strength, 2)
	assert_eq(RunState.relic_bonus_block, 0)
	assert_eq(RunState.relic_gold_bonus, 0)
	assert_eq(RunState.potions.size(), 1)
	assert_eq(RunState.potions[0].id, &"vigor_tonic")
	assert_eq(RunState.owned_equipment.size(), 1)
	assert_eq(RunState.equipped_armor.id, &"chainmail")
	assert_null(RunState.equipped_weapon)
	assert_eq(RunState.rng.randi(), expected_next_random, "The random sequence continues where it left off.")

func test_snapshot_survives_json():
	_start_and_mutate_a_run()
	var expected_map := _map_signature(RunState.map)
	var data := RunSnapshot.capture()
	var expected_next_random: int = RunState.rng.randi()
	var parsed: Variant = JSON.parse_string(JSON.stringify(data))
	RunState.enter_camp(DwarfContent.get_class_resource())
	assert_true(RunSnapshot.restore(parsed))
	assert_eq(_map_signature(RunState.map), expected_map)
	assert_eq(RunState.rng.randi(), expected_next_random)

func test_capture_outside_a_run_returns_an_empty_dictionary():
	RunState.enter_camp(DwarfContent.get_class_resource())
	assert_eq(RunSnapshot.capture(), {})

func test_restore_rejects_a_missing_map_or_unknown_node_without_touching_state():
	RunState.enter_camp(DwarfContent.get_class_resource())
	RunState.gold = 7
	assert_false(RunSnapshot.restore({"gold": 99}))
	assert_false(RunSnapshot.restore({"gold": 99, "map": {"floors": []}}))
	RunState.start_new_run(DwarfContent.get_class_resource())
	var data := RunSnapshot.capture()
	data["current_node_id"] = 9999
	data["gold"] = 99
	RunState.enter_camp(DwarfContent.get_class_resource())
	RunState.gold = 7
	assert_false(RunSnapshot.restore(data))
	assert_null(RunState.map)
	assert_eq(RunState.gold, 7)

func test_restore_skips_unknown_ids_and_falls_back_to_the_starting_deck():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var data := RunSnapshot.capture()
	data["deck"] = ["no_such_card"]
	data["relic_ids"] = ["no_such_relic", "whetstone"]
	data["potion_ids"] = ["no_such_potion", "healing_draught", "vigor_tonic", "healing_draught"]
	data["owned_equipment_ids"] = ["no_such_item"]
	data["equipped_weapon_id"] = "no_such_item"
	var class_res := DwarfContent.get_class_resource()
	RunState.enter_camp(class_res)
	assert_true(RunSnapshot.restore(data))
	assert_eq(RunState.deck.size(), class_res.starting_deck.size(), "An empty deck falls back to the starting deck.")
	assert_eq(RunState.unlocked_relics, [&"whetstone"] as Array[StringName])
	assert_eq(RunState.potions.size(), RunState.MAX_POTIONS, "Potions are capped at MAX_POTIONS.")
	assert_eq(RunState.owned_equipment.size(), 0)
	assert_null(RunState.equipped_weapon)

func test_run_outcome_abandoned_defaults_to_false():
	var outcome := RunOutcome.new()
	assert_false(outcome.abandoned)
