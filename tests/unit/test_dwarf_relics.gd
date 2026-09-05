extends GutTest

func test_get_all_relics_returns_four_well_formed_relics():
	var relics := DwarfRelics.get_all_relics()
	assert_eq(relics.size(), 4)
	for relic in relics:
		assert_ne(relic.display_name, "")
		assert_ne(relic.description, "")

func test_merchants_ledger_grants_gold_bonus():
	var relics := DwarfRelics.get_all_relics()
	var by_id: Dictionary = {}
	for relic in relics:
		by_id[relic.id] = relic
	assert_eq(by_id[&"merchants_ledger"].gold_bonus_per_reward, 5)

func test_get_random_relic_returns_one_of_the_known_relics():
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var all_relics := DwarfRelics.get_all_relics()
	var all_ids: Array[StringName] = []
	for relic in all_relics:
		all_ids.append(relic.id)
	var picked := DwarfRelics.get_random_relic(rng)
	assert_true(all_ids.has(picked.id))

func test_get_by_id_returns_the_matching_relic():
	var relic := DwarfRelics.get_by_id(&"whetstone")
	assert_not_null(relic)
	assert_eq(relic.strength_delta, 2)

func test_get_by_id_returns_null_for_unknown_id():
	assert_null(DwarfRelics.get_by_id(&"no_such_relic"))
