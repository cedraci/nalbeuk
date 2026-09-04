extends GutTest

func _make_actor(hp: int) -> CombatActor:
	return CombatActor.new("Test", hp)

func _make_strike(amount: int) -> CardResource:
	var card := CardResource.new()
	card.display_name = "Strike"
	card.cost = 1
	var effect := DamageEffect.new()
	effect.amount = amount
	card.effects = [effect]
	return card

func _make_guard(amount: int) -> CardResource:
	var card := CardResource.new()
	card.display_name = "Guard"
	card.cost = 1
	card.target_type = CardResource.TargetType.SELF
	var effect := BlockEffect.new()
	effect.amount = amount
	card.effects = [effect]
	return card

func _make_attack_move(amount: int) -> EnemyMove:
	var move := EnemyMove.new()
	move.intent_type = EnemyMove.IntentType.ATTACK
	var effect := DamageEffect.new()
	effect.amount = amount
	move.effects = [effect]
	return move

func test_start_player_turn_draws_up_to_hand_size():
	var player := _make_actor(20)
	var enemy := _make_actor(20)
	var deck: Array[CardResource] = []
	for i in range(8):
		deck.append(_make_strike(3))
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(3)])
	encounter.start_player_turn()
	assert_eq(encounter.hand.size(), 5)
	assert_eq(encounter.energy, 3)

func test_play_card_spends_energy_and_moves_card_to_discard():
	var player := _make_actor(20)
	var enemy := _make_actor(20)
	var deck: Array[CardResource] = [_make_strike(3)]
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(3)])
	encounter.start_player_turn()
	var card = encounter.hand[0]
	encounter.play_card(card)
	assert_eq(encounter.energy, 2)
	assert_false(encounter.hand.has(card))
	assert_true(encounter.discard_pile.has(card))
	assert_eq(enemy.current_hp, 17)

func test_self_targeted_card_applies_effect_to_player_not_enemy():
	var player := _make_actor(20)
	var enemy := _make_actor(20)
	var deck: Array[CardResource] = [_make_guard(5)]
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(3)])
	encounter.start_player_turn()
	encounter.play_card(encounter.hand[0])
	assert_eq(player.block, 5)
	assert_eq(enemy.block, 0)

func test_cannot_play_card_without_enough_energy():
	var player := _make_actor(20)
	var enemy := _make_actor(20)
	var expensive_card := _make_strike(3)
	expensive_card.cost = 99
	var encounter := CombatEncounter.new(player, [expensive_card], enemy, [_make_attack_move(3)])
	encounter.start_player_turn()
	assert_false(encounter.can_play_card(expensive_card))

func test_end_player_turn_discards_hand_and_runs_enemy_attack():
	var player := _make_actor(20)
	var enemy := _make_actor(20)
	var deck: Array[CardResource] = []
	for i in range(5):
		deck.append(_make_strike(3))
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(4)])
	encounter.start_player_turn()
	encounter.end_player_turn()
	assert_eq(encounter.hand.size(), 0)
	assert_eq(player.current_hp, 16)

func test_reshuffles_discard_into_draw_pile_when_empty():
	var player := _make_actor(20)
	var enemy := _make_actor(20)
	var deck: Array[CardResource] = []
	for i in range(5):
		deck.append(_make_strike(1))
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(1)])
	encounter.start_player_turn()
	encounter.end_player_turn()
	encounter.start_player_turn()
	assert_eq(encounter.hand.size(), 5)
	assert_eq(encounter.draw_pile.size() + encounter.hand.size() + encounter.discard_pile.size(), 5)

func test_combat_ends_when_enemy_hp_reaches_zero():
	var player := _make_actor(20)
	var enemy := _make_actor(5)
	var deck: Array[CardResource] = [_make_strike(10)]
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(1)])
	encounter.start_player_turn()
	encounter.play_card(encounter.hand[0])
	assert_true(encounter.is_over)
	assert_true(encounter.player_won)

func test_combat_ends_when_player_hp_reaches_zero():
	var player := _make_actor(3)
	var enemy := _make_actor(20)
	var deck: Array[CardResource] = []
	for i in range(5):
		deck.append(_make_strike(0))
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(10)])
	encounter.start_player_turn()
	encounter.end_player_turn()
	assert_true(encounter.is_over)
	assert_false(encounter.player_won)

func test_get_current_enemy_intent_cycles_through_moves():
	var player := _make_actor(20)
	var enemy := _make_actor(20)
	var deck: Array[CardResource] = []
	for i in range(5):
		deck.append(_make_strike(0))
	var move_a := _make_attack_move(3)
	var move_b := _make_attack_move(5)
	var encounter := CombatEncounter.new(player, deck, enemy, [move_a, move_b])
	assert_eq(encounter.get_current_enemy_intent(), move_a)
	encounter.start_player_turn()
	encounter.end_player_turn()
	assert_eq(encounter.get_current_enemy_intent(), move_b)
