extends RefCounted
class_name ActorFactory

static func build_player_actor(class_resource: ClassResource, stats: PersistentStats) -> CombatActor:
	var max_hp := stats.compute_max_hp(class_resource.base_hp)
	return CombatActor.new(class_resource.display_name, max_hp, stats.compute_base_strike_bonus())

static func build_enemy_actor(enemy_resource: EnemyResource) -> CombatActor:
	return CombatActor.new(enemy_resource.display_name, enemy_resource.max_hp)
