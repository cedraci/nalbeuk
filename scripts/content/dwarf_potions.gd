extends RefCounted
class_name DwarfPotions

static func get_all_potions() -> Array[PotionResource]:
	var healing_draught := PotionResource.new()
	healing_draught.id = &"healing_draught"
	healing_draught.display_name = "Healing Draught"
	healing_draught.description = "Heal 10 HP."
	healing_draught.heal_amount = 10

	var vigor_tonic := PotionResource.new()
	vigor_tonic.id = &"vigor_tonic"
	vigor_tonic.display_name = "Vigor Tonic"
	vigor_tonic.description = "Gain 3 Strength stacks for this fight."
	vigor_tonic.strength_stacks = 3

	return [healing_draught, vigor_tonic]

static func get_by_id(potion_id: StringName) -> PotionResource:
	for potion in get_all_potions():
		if potion.id == potion_id:
			return potion
	return null
