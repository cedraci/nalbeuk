extends GutTest

func test_get_all_equipment_returns_six_well_formed_items():
	var items := DwarfEquipment.get_all_equipment()
	assert_eq(items.size(), 6)
	for item in items:
		assert_ne(item.display_name, "")
		assert_ne(item.description, "")

func test_get_all_equipment_has_two_items_per_slot():
	var items := DwarfEquipment.get_all_equipment()
	var counts: Dictionary = {}
	for item in items:
		counts[item.slot] = counts.get(item.slot, 0) + 1
	assert_eq(counts[EquipmentResource.Slot.WEAPON], 2)
	assert_eq(counts[EquipmentResource.Slot.ARMOR], 2)
	assert_eq(counts[EquipmentResource.Slot.TRINKET], 2)

func test_trinket_items_carry_the_two_shared_passive_ids():
	var items := DwarfEquipment.get_all_equipment()
	var by_id: Dictionary = {}
	for item in items:
		by_id[item.id] = item
	assert_eq(by_id[&"lucky_charm"].passive_id, &"bonus_strength_stack")
	assert_eq(by_id[&"guardian_amulet"].passive_id, &"bonus_starting_block")

func test_get_random_equipment_returns_one_of_the_known_items():
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var all_items := DwarfEquipment.get_all_equipment()
	var all_ids: Array[StringName] = []
	for item in all_items:
		all_ids.append(item.id)
	var picked := DwarfEquipment.get_random_equipment(rng)
	assert_true(all_ids.has(picked.id))

func test_get_by_id_returns_a_fresh_instance_of_the_known_item():
	var first := DwarfEquipment.get_by_id(&"chainmail")
	var second := DwarfEquipment.get_by_id(&"chainmail")
	assert_not_null(first)
	assert_eq(first.display_name, "Chainmail")
	assert_eq(first.slot, EquipmentResource.Slot.ARMOR)
	assert_ne(first, second, "Each call returns its own instance so two owned copies are distinct.")

func test_get_by_id_returns_null_for_unknown_id():
	assert_null(DwarfEquipment.get_by_id(&"no_such_item"))
