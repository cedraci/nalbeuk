extends RefCounted
class_name DwarfRelics

static func get_all_relics() -> Array[RelicResource]:
	var iron_ration := RelicResource.new()
	iron_ration.id = &"iron_ration"
	iron_ration.display_name = "Iron Ration"
	iron_ration.description = "+3 Vitality (permanent max HP increase)."
	iron_ration.vitality_delta = 3

	var whetstone := RelicResource.new()
	whetstone.id = &"whetstone"
	whetstone.display_name = "Whetstone"
	whetstone.description = "+2 Strength."
	whetstone.strength_delta = 2

	var reinforced_buckle := RelicResource.new()
	reinforced_buckle.id = &"reinforced_buckle"
	reinforced_buckle.display_name = "Reinforced Buckle"
	reinforced_buckle.description = "+2 Block."
	reinforced_buckle.block_delta = 2

	var merchants_ledger := RelicResource.new()
	merchants_ledger.id = &"merchants_ledger"
	merchants_ledger.display_name = "Merchant's Ledger"
	merchants_ledger.description = "+5 gold on every combat reward."
	merchants_ledger.gold_bonus_per_reward = 5

	return [iron_ration, whetstone, reinforced_buckle, merchants_ledger]

static func get_random_relic(rng: RandomNumberGenerator) -> RelicResource:
	var relics := get_all_relics()
	return relics[rng.randi_range(0, relics.size() - 1)]

static func get_by_id(relic_id: StringName) -> RelicResource:
	for relic in get_all_relics():
		if relic.id == relic_id:
			return relic
	return null
