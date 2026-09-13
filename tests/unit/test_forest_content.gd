extends GutTest

func test_forest_wolf_enemy_resource_has_expected_shape():
	var enemy_res := ForestContent.get_enemy_resource()
	assert_eq(enemy_res.display_name, "Forest Wolf")
	assert_eq(enemy_res.max_hp, 16)
	assert_eq(enemy_res.moves.size(), 2)

func test_forest_wolf_moves_have_descriptions_and_display_values():
	var enemy_res := ForestContent.get_enemy_resource()
	for move in enemy_res.moves:
		assert_ne(move.description, "", "A Forest Wolf move should have a non-empty description.")
	var bite: EnemyMove = enemy_res.moves[0]
	assert_eq(bite.intent_type, EnemyMove.IntentType.ATTACK)
	assert_eq(bite.display_value, 4)
	var howl: EnemyMove = enemy_res.moves[1]
	assert_eq(howl.intent_type, EnemyMove.IntentType.BUFF)

func test_forest_wolf_howl_grants_itself_strength():
	var enemy_res := ForestContent.get_enemy_resource()
	var wolf := ActorFactory.build_enemy_actor(enemy_res)
	var howl: EnemyMove = enemy_res.moves[1]
	var context := EffectContext.new(wolf, wolf)
	for effect in howl.effects:
		effect.apply(context)
	assert_eq(wolf.get_status_stacks(&"strength"), 1)
