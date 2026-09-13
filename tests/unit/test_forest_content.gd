extends GutTest

func test_coypu_enemy_resource_has_expected_shape():
	var enemy_res := ForestContent.get_enemy_resource()
	assert_eq(enemy_res.display_name, "Coypu")
	assert_eq(enemy_res.max_hp, 16)
	assert_eq(enemy_res.moves.size(), 2)

func test_coypu_moves_have_descriptions_and_display_values():
	var enemy_res := ForestContent.get_enemy_resource()
	for move in enemy_res.moves:
		assert_ne(move.description, "", "A Coypu move should have a non-empty description.")
	var bite: EnemyMove = enemy_res.moves[0]
	assert_eq(bite.intent_type, EnemyMove.IntentType.ATTACK)
	assert_eq(bite.display_value, 4)
	var hiss: EnemyMove = enemy_res.moves[1]
	assert_eq(hiss.intent_type, EnemyMove.IntentType.BUFF)

func test_coypu_hiss_grants_itself_strength():
	var enemy_res := ForestContent.get_enemy_resource()
	var coypu := ActorFactory.build_enemy_actor(enemy_res)
	var hiss: EnemyMove = enemy_res.moves[1]
	var context := EffectContext.new(coypu, coypu)
	for effect in hiss.effects:
		effect.apply(context)
	assert_eq(coypu.get_status_stacks(&"strength"), 1)
