extends RunStateTest

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
	assert_eq(scene.player_panel.hp_bar.value_label.text, "20 / 20")

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
	assert_eq(scene.enemy_panel.hp_bar.value_label.text, "17 / 20")

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
	assert_eq(scene.energy_value_label.text, "3/3")
	assert_eq(scene.player_panel.hp_bar.value_label.text, "17 / 20")

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

func test_relic_row_shows_one_chip_per_unlocked_relic():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.unlocked_relics = [&"whetstone", &"reinforced_buckle"]
	var scene := CombatScene.new()
	add_child_autofree(scene)
	var player := _make_actor(20)
	var enemy := _make_actor(20)
	var deck: Array[CardResource] = [_make_strike(3)]
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(3)])
	scene.start(encounter)
	assert_eq(scene.relic_row.get_child_count(), 2)
	assert_eq(scene.relic_row.get_child(0).label.text, "Whetstone")

func test_pile_counts_reflect_draw_and_discard():
	var scene := CombatScene.new()
	add_child_autofree(scene)
	var player := _make_actor(20)
	var enemy := _make_actor(20)
	var deck: Array[CardResource] = [_make_strike(3), _make_strike(3), _make_strike(3)]
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(3)])
	scene.start(encounter)
	assert_eq(scene.draw_count_label.text, "0")
	assert_eq(scene.discard_count_label.text, "0")
	scene.hand_view.card_clicked.emit(encounter.hand[0])
	assert_eq(scene.discard_count_label.text, "1")

func test_potion_row_hidden_when_no_potions():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var scene := CombatScene.new()
	add_child_autofree(scene)
	var player := _make_actor(20)
	var enemy := _make_actor(20)
	var deck: Array[CardResource] = [_make_strike(3)]
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(3)])
	scene.start(encounter)
	assert_false(scene.potion_container.visible)

func test_potion_row_shows_one_button_per_potion():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var potions := DwarfPotions.get_all_potions()
	RunState.add_potion(potions[0])
	RunState.add_potion(potions[1])
	var scene := CombatScene.new()
	add_child_autofree(scene)
	var player := _make_actor(20)
	var enemy := _make_actor(20)
	var deck: Array[CardResource] = [_make_strike(3)]
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(3)])
	scene.start(encounter)
	assert_true(scene.potion_container.visible)
	assert_eq(scene.potion_container.get_child_count(), 2)

func test_clicking_a_potion_button_applies_it_without_ending_the_turn():
	RunState.start_new_run(DwarfContent.get_class_resource())
	var potions := DwarfPotions.get_all_potions()
	RunState.add_potion(potions[0])
	var scene := CombatScene.new()
	add_child_autofree(scene)
	var player := _make_actor(20)
	player.take_damage(15)
	var enemy := _make_actor(20)
	var deck: Array[CardResource] = [_make_strike(3)]
	var encounter := CombatEncounter.new(player, deck, enemy, [_make_attack_move(3)])
	scene.start(encounter)
	var energy_before: int = encounter.energy
	var potion_button: Button = scene.potion_container.get_child(0)
	potion_button.pressed.emit()
	assert_eq(encounter.player.current_hp, 15, "Healing Draught heals 10, from 5 up to 15.")
	assert_eq(encounter.energy, energy_before, "Using a potion should not spend Energy.")
	assert_true(scene.turn_ui_container.visible, "Using a potion should not end the turn.")
	assert_eq(scene.potion_container.get_child_count(), 0, "The consumed potion should no longer appear.")
