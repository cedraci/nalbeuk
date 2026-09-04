extends GutTest

# Fixed seed chosen so this fight deterministically resolves in exactly 2
# player turns (verified empirically): turn 1 leaves the Cave Rat at non-zero
# HP, so its Screech (weak-applying) move is queued, and turn 2 finishes it
# off. This makes the fight's outcome depend on more than "any 3 strikes in a
# row," and lets us pin exact intermediate/final numbers below.
const FIGHT_SEED := 2

func _run_fight(strength: int, vitality: int) -> Dictionary:
	var class_res := DwarfContent.get_class_resource()
	var stats := PersistentStats.new()
	stats.strength = strength
	stats.vitality = vitality
	var player := ActorFactory.build_player_actor(class_res, stats)
	var enemy_res := CaveRatContent.get_enemy_resource()
	var enemy := ActorFactory.build_enemy_actor(enemy_res)
	var rng := RandomNumberGenerator.new()
	rng.seed = FIGHT_SEED
	var encounter := CombatEncounter.new(player, class_res.starting_deck, enemy, enemy_res.moves, rng)

	var enemy_hp_after_first_turn := -1
	var safety_turns := 0
	while not encounter.is_over and safety_turns < 20:
		encounter.start_player_turn()
		for card in encounter.hand.duplicate():
			if encounter.can_play_card(card):
				encounter.play_card(card)
			if encounter.is_over:
				break
		if safety_turns == 0:
			enemy_hp_after_first_turn = enemy.current_hp
		if not encounter.is_over:
			encounter.end_player_turn()
		safety_turns += 1

	return {
		"encounter": encounter,
		"player": player,
		"enemy": enemy,
		"turns": safety_turns,
		"enemy_hp_after_first_turn": enemy_hp_after_first_turn,
	}

func test_dwarf_defeats_cave_rat_with_repeated_strikes():
	var result := _run_fight(2, 3)
	var encounter: CombatEncounter = result.encounter
	var player: CombatActor = result.player
	var enemy: CombatActor = result.enemy

	assert_true(encounter.is_over)
	assert_true(encounter.player_won)
	assert_true(result.turns < 20)
	assert_eq(result.turns, 2, "This seeded fight is expected to resolve in exactly 2 player turns.")
	assert_true(enemy.current_hp <= 0, "Cave Rat should be at or below 0 HP once the fight is over.")
	assert_eq(player.current_hp, 36,
		"36 == base_hp(30) + vitality(3) * 2: proves the vitality bonus actually raised max HP.")
	assert_eq(result.enemy_hp_after_first_turn, 2,
		"With strength=2, two Strike hits (6+2 damage each) should leave the Cave Rat at exactly 2 HP after turn 1.")

	# Persistent stats must actually matter for the outcome, not just be present
	# on the actor. Re-run the identically-seeded fight with strength/vitality
	# zeroed: if the stat wiring were ever broken (e.g. baseline_strike_bonus or
	# compute_max_hp stopped being applied), these comparisons would start
	# failing instead of silently passing.
	var zeroed := _run_fight(0, 0)
	assert_lt(result.enemy_hp_after_first_turn, zeroed.enemy_hp_after_first_turn,
		"Strength bonus should make turn 1 deal more damage than with strength zeroed.")
	assert_gt(player.current_hp, zeroed.player.current_hp,
		"Vitality bonus should give the player more HP than with vitality zeroed.")
