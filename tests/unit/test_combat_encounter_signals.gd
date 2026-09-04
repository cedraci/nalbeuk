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

func _make_attack_move(amount: int) -> EnemyMove:
	var move := EnemyMove.new()
	move.intent_type = EnemyMove.IntentType.ATTACK
	var effect := DamageEffect.new()
	effect.amount = amount
	move.effects = [effect]
	return move

func test_play_card_emits_state_changed():
	var player := _make_actor(20)
	var enemy := _make_actor(20)
	var deck: Array[CardResource] = [_make_strike(3)]
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(3)])
	watch_signals(encounter)
	encounter.start_player_turn()
	encounter.play_card(encounter.hand[0])
	assert_signal_emit_count(encounter, "state_changed", 1)

func test_end_player_turn_emits_state_changed_exactly_once():
	var player := _make_actor(20)
	var enemy := _make_actor(20)
	var deck: Array[CardResource] = [_make_strike(3)]
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(3)])
	encounter.start_player_turn()
	watch_signals(encounter)
	encounter.end_player_turn()
	assert_signal_emit_count(encounter, "state_changed", 1)

func test_combat_ended_emits_once_with_player_won_true():
	var player := _make_actor(20)
	var enemy := _make_actor(3)
	var deck: Array[CardResource] = [_make_strike(3)]
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(3)])
	watch_signals(encounter)
	encounter.start_player_turn()
	encounter.play_card(encounter.hand[0])
	assert_signal_emitted_with_parameters(encounter, "combat_ended", [true])
	assert_signal_emit_count(encounter, "combat_ended", 1)

func test_combat_ended_emits_once_with_player_won_false():
	var player := _make_actor(3)
	var enemy := _make_actor(20)
	var deck: Array[CardResource] = [_make_strike(0)]
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(5)])
	watch_signals(encounter)
	encounter.start_player_turn()
	encounter.end_player_turn()
	assert_signal_emitted_with_parameters(encounter, "combat_ended", [false])
	assert_signal_emit_count(encounter, "combat_ended", 1)

func test_combat_ended_never_fires_twice_across_multiple_calls():
	var player := _make_actor(20)
	var enemy := _make_actor(3)
	var deck: Array[CardResource] = [_make_strike(3)]
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(3)])
	watch_signals(encounter)
	encounter.start_player_turn()
	encounter.play_card(encounter.hand[0])
	assert_signal_emit_count(encounter, "combat_ended", 1)
	# Combat is already over. end_player_turn() has no is_over guard of
	# its own and always calls _check_combat_over() internally, so this
	# redundant call is exactly what would double-fire combat_ended if
	# _check_combat_over()'s own re-entry guard were missing or broken.
	encounter.end_player_turn()
	assert_signal_emit_count(encounter, "combat_ended", 1)
