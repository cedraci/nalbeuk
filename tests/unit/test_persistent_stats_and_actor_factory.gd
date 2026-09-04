extends GutTest

func test_compute_max_hp_adds_vitality_bonus():
	var stats := PersistentStats.new()
	stats.vitality = 5
	assert_eq(stats.compute_max_hp(30), 40)

func test_compute_base_strike_bonus_equals_strength():
	var stats := PersistentStats.new()
	stats.strength = 4
	assert_eq(stats.compute_base_strike_bonus(), 4)

func test_build_player_actor_applies_baseline_stats():
	var class_res := ClassResource.new()
	class_res.display_name = "Dwarf"
	class_res.base_hp = 30
	var stats := PersistentStats.new()
	stats.vitality = 5
	stats.strength = 4
	var actor := ActorFactory.build_player_actor(class_res, stats)
	assert_eq(actor.display_name, "Dwarf")
	assert_eq(actor.max_hp, 40)
	assert_eq(actor.current_hp, 40)
	assert_eq(actor.baseline_strike_bonus, 4)

func test_build_enemy_actor_uses_enemy_resource_fields():
	var enemy_res := EnemyResource.new()
	enemy_res.display_name = "Cave Rat"
	enemy_res.max_hp = 12
	var actor := ActorFactory.build_enemy_actor(enemy_res)
	assert_eq(actor.display_name, "Cave Rat")
	assert_eq(actor.max_hp, 12)
	assert_eq(actor.baseline_strike_bonus, 0)
