extends GutTest

func test_get_upgraded_card_returns_a_stronger_strike():
	var upgraded := DwarfContent.get_upgraded_card(&"dwarf_strike")
	assert_eq(upgraded.display_name, "Strike+")
	assert_eq(upgraded.effects[0].amount, 9)

func test_get_upgraded_card_returns_a_stronger_guard():
	var upgraded := DwarfContent.get_upgraded_card(&"dwarf_guard")
	assert_eq(upgraded.display_name, "Guard+")
	assert_eq(upgraded.effects[0].amount, 8)

func test_get_upgraded_card_returns_null_for_an_unknown_id():
	var upgraded := DwarfContent.get_upgraded_card(&"not_a_real_card")
	assert_null(upgraded)
