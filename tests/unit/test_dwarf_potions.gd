extends GutTest

func test_get_all_potions_returns_two_well_formed_potions():
	var potions := DwarfPotions.get_all_potions()
	assert_eq(potions.size(), 2)
	for potion in potions:
		assert_ne(potion.display_name, "")
		assert_ne(potion.description, "")

func test_healing_draught_heals_ten():
	var potions := DwarfPotions.get_all_potions()
	var by_id: Dictionary = {}
	for potion in potions:
		by_id[potion.id] = potion
	assert_eq(by_id[&"healing_draught"].heal_amount, 10)

func test_vigor_tonic_grants_three_strength_stacks():
	var potions := DwarfPotions.get_all_potions()
	var by_id: Dictionary = {}
	for potion in potions:
		by_id[potion.id] = potion
	assert_eq(by_id[&"vigor_tonic"].strength_stacks, 3)
