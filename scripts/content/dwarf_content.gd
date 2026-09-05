extends RefCounted
class_name DwarfContent

static func get_class_resource() -> ClassResource:
	var class_res := ClassResource.new()
	class_res.id = &"dwarf"
	class_res.display_name = "Dwarf"
	class_res.base_hp = 30
	var deck: Array[CardResource] = []
	for i in range(4):
		deck.append(_make_strike_card())
	deck.append(_make_guard_card())
	class_res.starting_deck = deck
	return class_res

static func get_upgraded_card(card_id: StringName) -> CardResource:
	match card_id:
		&"dwarf_strike":
			return _make_strike_plus_card()
		&"dwarf_guard":
			return _make_guard_plus_card()
		_:
			return null

static func _make_strike_card() -> CardResource:
	var card := CardResource.new()
	card.id = &"dwarf_strike"
	card.display_name = "Strike"
	card.cost = 1
	card.card_type = CardResource.CardType.STRIKE
	card.target_type = CardResource.TargetType.SINGLE_ENEMY
	var effect := DamageEffect.new()
	effect.amount = 6
	card.effects = [effect]
	card.description = "Deal 6 damage."
	return card

static func _make_guard_card() -> CardResource:
	var card := CardResource.new()
	card.id = &"dwarf_guard"
	card.display_name = "Guard"
	card.cost = 1
	card.card_type = CardResource.CardType.TECHNIQUE
	card.target_type = CardResource.TargetType.SELF
	var effect := BlockEffect.new()
	effect.amount = 5
	card.effects = [effect]
	card.description = "Gain 5 Block."
	return card

static func _make_strike_plus_card() -> CardResource:
	var card := CardResource.new()
	card.id = &"dwarf_strike_plus"
	card.display_name = "Strike+"
	card.cost = 1
	card.card_type = CardResource.CardType.STRIKE
	card.target_type = CardResource.TargetType.SINGLE_ENEMY
	var effect := DamageEffect.new()
	effect.amount = 9
	card.effects = [effect]
	card.description = "Deal 9 damage."
	return card

static func _make_guard_plus_card() -> CardResource:
	var card := CardResource.new()
	card.id = &"dwarf_guard_plus"
	card.display_name = "Guard+"
	card.cost = 1
	card.card_type = CardResource.CardType.TECHNIQUE
	card.target_type = CardResource.TargetType.SELF
	var effect := BlockEffect.new()
	effect.amount = 8
	card.effects = [effect]
	card.description = "Gain 8 Block."
	return card
