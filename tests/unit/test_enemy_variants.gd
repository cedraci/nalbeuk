extends GutTest

func test_elite_enemy_is_stronger_than_base():
	var base := CaveRatContent.get_enemy_resource()
	var elite := CaveRatContent.get_elite_enemy_resource()
	assert_true(elite.max_hp > base.max_hp)
	assert_ne(elite.display_name, base.display_name)

func test_boss_enemy_is_stronger_than_elite():
	var elite := CaveRatContent.get_elite_enemy_resource()
	var boss := CaveRatContent.get_boss_enemy_resource()
	assert_true(boss.max_hp > elite.max_hp)
	assert_ne(boss.display_name, elite.display_name)

func test_elite_and_boss_moves_have_descriptions():
	var enemies: Array[EnemyResource] = [CaveRatContent.get_elite_enemy_resource(), CaveRatContent.get_boss_enemy_resource()]
	for enemy_res in enemies:
		for move in enemy_res.moves:
			assert_ne(move.description, "")
