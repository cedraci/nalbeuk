extends GutTest

func test_dwarf_defeats_cave_rat_with_repeated_strikes():
	var class_res := DwarfContent.get_class_resource()
	var stats := PersistentStats.new()
	stats.strength = 2
	stats.vitality = 3
	var player := ActorFactory.build_player_actor(class_res, stats)
	var enemy_res := CaveRatContent.get_enemy_resource()
	var enemy := ActorFactory.build_enemy_actor(enemy_res)
	var encounter := CombatEncounter.new(player, class_res.starting_deck, enemy, enemy_res.moves)

	var safety_turns := 0
	while not encounter.is_over and safety_turns < 20:
		encounter.start_player_turn()
		for card in encounter.hand.duplicate():
			if encounter.can_play_card(card):
				encounter.play_card(card)
			if encounter.is_over:
				break
		if not encounter.is_over:
			encounter.end_player_turn()
		safety_turns += 1

	assert_true(encounter.is_over)
	assert_true(encounter.player_won)
	assert_true(safety_turns < 20)
	assert_true(player.current_hp > 0)
