extends GutTest

func test_dwarf_class_resource_has_expected_shape():
	var class_res := DwarfContent.get_class_resource()
	assert_eq(class_res.display_name, "Dwarf")
	assert_eq(class_res.base_hp, 30)
	assert_eq(class_res.starting_deck.size(), 5)

func test_dwarf_deck_includes_strike_and_guard():
	var class_res := DwarfContent.get_class_resource()
	var names := []
	for card in class_res.starting_deck:
		names.append(card.display_name)
	assert_true(names.count("Strike") >= 3)
	assert_true(names.count("Guard") >= 1)

func test_cave_rat_enemy_resource_has_expected_shape():
	var enemy_res := CaveRatContent.get_enemy_resource()
	assert_eq(enemy_res.display_name, "Cave Rat")
	assert_eq(enemy_res.max_hp, 18)
	assert_eq(enemy_res.moves.size(), 2)
