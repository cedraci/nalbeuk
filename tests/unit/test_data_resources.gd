extends GutTest

func test_card_resource_holds_configured_fields():
	var card := CardResource.new()
	card.id = &"test_card"
	card.display_name = "Test Card"
	card.cost = 2
	card.card_type = CardResource.CardType.TECHNIQUE
	card.target_type = CardResource.TargetType.SELF
	var effect := BlockEffect.new()
	effect.amount = 5
	card.effects = [effect]
	assert_eq(card.cost, 2)
	assert_eq(card.card_type, CardResource.CardType.TECHNIQUE)
	assert_eq(card.effects.size(), 1)

func test_enemy_move_holds_intent_and_effects():
	var move := EnemyMove.new()
	move.intent_type = EnemyMove.IntentType.ATTACK
	var effect := DamageEffect.new()
	effect.amount = 5
	move.effects = [effect]
	assert_eq(move.intent_type, EnemyMove.IntentType.ATTACK)
	assert_eq(move.effects.size(), 1)

func test_enemy_resource_holds_moves():
	var enemy := EnemyResource.new()
	enemy.id = &"test_enemy"
	enemy.display_name = "Test Enemy"
	enemy.max_hp = 15
	var move := EnemyMove.new()
	enemy.moves = [move]
	assert_eq(enemy.max_hp, 15)
	assert_eq(enemy.moves.size(), 1)

func test_class_resource_holds_starting_deck():
	var class_res := ClassResource.new()
	class_res.id = &"test_class"
	class_res.display_name = "Test Class"
	class_res.base_hp = 20
	var card := CardResource.new()
	class_res.starting_deck = [card]
	assert_eq(class_res.base_hp, 20)
	assert_eq(class_res.starting_deck.size(), 1)
