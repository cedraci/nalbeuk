extends GutTest

func test_reset_restores_a_level_one_dwarf_with_nothing():
	MetaState.level = 4
	MetaState.xp = 9
	MetaState.skill_points = 2
	MetaState.unlocked_skill_nodes = [&"dwarven_grit"]
	MetaState.owned_equipment_ids = [&"chainmail"]
	MetaState.equipped_armor_id = &"chainmail"
	MetaState.reset()
	assert_eq(MetaState.class_id, &"dwarf")
	assert_eq(MetaState.level, 1)
	assert_eq(MetaState.xp, 0)
	assert_eq(MetaState.skill_points, 0)
	assert_eq(MetaState.unlocked_skill_nodes.size(), 0)
	assert_eq(MetaState.owned_equipment_ids.size(), 0)
	assert_eq(MetaState.equipped_weapon_id, &"")
	assert_eq(MetaState.equipped_armor_id, &"")
	assert_eq(MetaState.equipped_trinket_id, &"")

func test_to_dict_from_dict_round_trips_every_field():
	MetaState.reset()
	MetaState.level = 3
	MetaState.xp = 12
	MetaState.skill_points = 1
	MetaState.unlocked_skill_nodes = [&"dwarven_grit", &"sharpened_pick"]
	MetaState.owned_equipment_ids = [&"rusty_shortsword", &"rusty_shortsword", &"leather_vest"]
	MetaState.equipped_weapon_id = &"rusty_shortsword"
	MetaState.equipped_armor_id = &"leather_vest"
	var data := MetaState.to_dict()
	MetaState.reset()
	MetaState.from_dict(data)
	assert_eq(MetaState.level, 3)
	assert_eq(MetaState.xp, 12)
	assert_eq(MetaState.skill_points, 1)
	assert_eq(MetaState.unlocked_skill_nodes, [&"dwarven_grit", &"sharpened_pick"] as Array[StringName])
	assert_eq(MetaState.owned_equipment_ids, [&"rusty_shortsword", &"rusty_shortsword", &"leather_vest"] as Array[StringName])
	assert_eq(MetaState.equipped_weapon_id, &"rusty_shortsword")
	assert_eq(MetaState.equipped_armor_id, &"leather_vest")
	assert_eq(MetaState.equipped_trinket_id, &"")

func test_to_dict_uses_plain_strings_and_ints_so_json_can_carry_it():
	MetaState.reset()
	MetaState.unlocked_skill_nodes = [&"dwarven_grit"]
	MetaState.owned_equipment_ids = [&"chainmail"]
	MetaState.equipped_armor_id = &"chainmail"
	var data := MetaState.to_dict()
	var text := JSON.stringify(data)
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary)
	MetaState.reset()
	MetaState.from_dict(parsed)
	assert_eq(MetaState.unlocked_skill_nodes, [&"dwarven_grit"] as Array[StringName])
	assert_eq(MetaState.equipped_armor_id, &"chainmail")

func test_from_dict_skips_unknown_ids():
	MetaState.reset()
	MetaState.from_dict({
		"level": 2, "xp": 0, "skill_points": 0,
		"unlocked_skill_nodes": ["dwarven_grit", "no_such_node"],
		"owned_equipment_ids": ["no_such_item", "leather_vest"],
	})
	assert_eq(MetaState.unlocked_skill_nodes, [&"dwarven_grit"] as Array[StringName])
	assert_eq(MetaState.owned_equipment_ids, [&"leather_vest"] as Array[StringName])

func test_from_dict_clears_an_equipped_slot_whose_item_is_not_owned():
	MetaState.reset()
	MetaState.from_dict({
		"owned_equipment_ids": ["leather_vest"],
		"equipped_weapon_id": "rusty_shortsword",
		"equipped_armor_id": "leather_vest",
	})
	assert_eq(MetaState.equipped_weapon_id, &"")
	assert_eq(MetaState.equipped_armor_id, &"leather_vest")

func test_from_dict_defaults_missing_fields_and_floors_bad_numbers():
	MetaState.reset()
	MetaState.from_dict({"level": 0, "xp": -5})
	assert_eq(MetaState.level, 1)
	assert_eq(MetaState.xp, 0)
	assert_eq(MetaState.skill_points, 0)
	assert_eq(MetaState.class_id, &"dwarf")
