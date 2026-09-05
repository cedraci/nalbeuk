extends GutTest

func test_get_card_by_id_returns_each_known_card():
	assert_eq(DwarfContent.get_card_by_id(&"dwarf_strike").display_name, "Strike")
	assert_eq(DwarfContent.get_card_by_id(&"dwarf_guard").display_name, "Guard")
	assert_eq(DwarfContent.get_card_by_id(&"dwarf_strike_plus").display_name, "Strike+")
	assert_eq(DwarfContent.get_card_by_id(&"dwarf_guard_plus").display_name, "Guard+")

func test_get_card_by_id_returns_fresh_instances():
	var first := DwarfContent.get_card_by_id(&"dwarf_strike")
	var second := DwarfContent.get_card_by_id(&"dwarf_strike")
	assert_ne(first, second)

func test_get_card_by_id_returns_null_for_unknown_id():
	assert_null(DwarfContent.get_card_by_id(&"no_such_card"))
