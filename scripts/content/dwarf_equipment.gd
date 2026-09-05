extends RefCounted
class_name DwarfEquipment

static func get_all_equipment() -> Array[EquipmentResource]:
	var rusty_shortsword := EquipmentResource.new()
	rusty_shortsword.id = &"rusty_shortsword"
	rusty_shortsword.display_name = "Rusty Shortsword"
	rusty_shortsword.slot = EquipmentResource.Slot.WEAPON
	rusty_shortsword.description = "+2 Strength."
	rusty_shortsword.strength_delta = 2

	var dwarven_warhammer := EquipmentResource.new()
	dwarven_warhammer.id = &"dwarven_warhammer"
	dwarven_warhammer.display_name = "Dwarven Warhammer"
	dwarven_warhammer.slot = EquipmentResource.Slot.WEAPON
	dwarven_warhammer.description = "+4 Strength."
	dwarven_warhammer.strength_delta = 4

	var leather_vest := EquipmentResource.new()
	leather_vest.id = &"leather_vest"
	leather_vest.display_name = "Leather Vest"
	leather_vest.slot = EquipmentResource.Slot.ARMOR
	leather_vest.description = "+2 Block."
	leather_vest.block_delta = 2

	var chainmail := EquipmentResource.new()
	chainmail.id = &"chainmail"
	chainmail.display_name = "Chainmail"
	chainmail.slot = EquipmentResource.Slot.ARMOR
	chainmail.description = "+4 Block."
	chainmail.block_delta = 4

	var lucky_charm := EquipmentResource.new()
	lucky_charm.id = &"lucky_charm"
	lucky_charm.display_name = "Lucky Charm"
	lucky_charm.slot = EquipmentResource.Slot.TRINKET
	lucky_charm.description = "Start every fight with 2 bonus Strength stacks."
	lucky_charm.passive_id = &"bonus_strength_stack"

	var guardian_amulet := EquipmentResource.new()
	guardian_amulet.id = &"guardian_amulet"
	guardian_amulet.display_name = "Guardian Amulet"
	guardian_amulet.slot = EquipmentResource.Slot.TRINKET
	guardian_amulet.description = "Start every fight with 5 Block."
	guardian_amulet.passive_id = &"bonus_starting_block"

	return [rusty_shortsword, dwarven_warhammer, leather_vest, chainmail, lucky_charm, guardian_amulet]

static func get_random_equipment(rng: RandomNumberGenerator) -> EquipmentResource:
	var items := get_all_equipment()
	return items[rng.randi_range(0, items.size() - 1)]

static func get_by_id(item_id: StringName) -> EquipmentResource:
	for item in get_all_equipment():
		if item.id == item_id:
			return item
	return null
