extends GutTest

func _make_actor(hp: int) -> CombatActor:
	return CombatActor.new("Test", hp)

func _make_strike(amount: int) -> CardResource:
	var card := CardResource.new()
	card.display_name = "Strike"
	card.cost = 1
	card.description = "Deal damage."
	var effect := DamageEffect.new()
	effect.amount = amount
	card.effects = [effect]
	return card

func _make_attack_move(amount: int) -> EnemyMove:
	var move := EnemyMove.new()
	move.intent_type = EnemyMove.IntentType.ATTACK
	move.display_value = amount
	move.description = "It attacks."
	var effect := DamageEffect.new()
	effect.amount = amount
	move.effects = [effect]
	return move

func test_start_shows_turn_ui_and_hides_result():
	var scene := CombatScene.new()
	add_child_autofree(scene)
	var player := _make_actor(20)
	var enemy := _make_actor(20)
	var deck: Array[CardResource] = [_make_strike(3)]
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(3)])
	scene.start(encounter)
	assert_true(scene.turn_ui_container.visible)
	assert_false(scene.result_container.visible)
	assert_eq(scene.player_panel.hp_label.text, "HP: 20 / 20")

func test_playing_a_card_updates_the_view():
	var scene := CombatScene.new()
	add_child_autofree(scene)
	var player := _make_actor(20)
	var enemy := _make_actor(20)
	var deck: Array[CardResource] = [_make_strike(3)]
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(3)])
	scene.start(encounter)
	var card := encounter.hand[0]
	scene.hand_view.card_clicked.emit(card)
	assert_eq(scene.enemy_panel.hp_label.text, "HP: 17 / 20")

func test_combat_ended_shows_result_overlay_with_win_message():
	var scene := CombatScene.new()
	add_child_autofree(scene)
	var player := _make_actor(20)
	var enemy := _make_actor(3)
	var deck: Array[CardResource] = [_make_strike(3)]
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(3)])
	scene.start(encounter)
	scene.hand_view.card_clicked.emit(encounter.hand[0])
	assert_false(scene.turn_ui_container.visible)
	assert_true(scene.result_container.visible)
	assert_eq(scene.result_label.text, "You Won")

func test_play_again_button_emits_combat_dismissed_with_player_won():
	var scene := CombatScene.new()
	add_child_autofree(scene)
	var player := _make_actor(3)
	var enemy := _make_actor(20)
	var deck: Array[CardResource] = [_make_strike(3)]
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(5)])
	scene.start(encounter)
	scene.end_turn_button.pressed.emit()
	watch_signals(scene)
	scene.play_again_button.pressed.emit()
	assert_signal_emitted_with_parameters(scene, "combat_dismissed", [false])

func test_end_turn_button_starts_new_player_turn_when_combat_continues():
	var scene := CombatScene.new()
	add_child_autofree(scene)
	var player := _make_actor(20)
	var enemy := _make_actor(20)
	var deck: Array[CardResource] = [_make_strike(3)]
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(3)])
	scene.start(encounter)
	scene.end_turn_button.pressed.emit()
	assert_eq(scene.energy_label.text, "Energy: 3 / 3")
	assert_eq(scene.player_panel.hp_label.text, "HP: 17 / 20")

func test_end_turn_button_shows_result_overlay_with_loss_message():
	var scene := CombatScene.new()
	add_child_autofree(scene)
	var player := _make_actor(3)
	var enemy := _make_actor(20)
	var deck: Array[CardResource] = [_make_strike(3)]
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(5)])
	scene.start(encounter)
	scene.end_turn_button.pressed.emit()
	assert_eq(scene.result_label.text, "You Lost")
	assert_true(scene.result_container.visible)
	assert_false(scene.turn_ui_container.visible)
