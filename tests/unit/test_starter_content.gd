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

func test_dwarf_cards_have_descriptions():
	var class_res := DwarfContent.get_class_resource()
	for card in class_res.starting_deck:
		assert_ne(card.description, "", "Card '%s' should have a non-empty description." % card.display_name)

func test_cave_rat_moves_have_descriptions_and_display_values():
	var enemy_res := CaveRatContent.get_enemy_resource()
	for move in enemy_res.moves:
		assert_ne(move.description, "", "A Cave Rat move should have a non-empty description.")
	# Bite is a plain attack; its display_value should show the damage number.
	var bite: EnemyMove = enemy_res.moves[0]
	assert_eq(bite.display_value, 5)
