extends Control
class_name CombatDemo

var combat_scene: CombatScene

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_start_new_fight()

func _start_new_fight() -> void:
	if combat_scene != null:
		remove_child(combat_scene)
		combat_scene.queue_free()

	var class_res := DwarfContent.get_class_resource()
	var stats := PersistentStats.new()
	var player := ActorFactory.build_player_actor(class_res, stats)

	var enemy_res := CaveRatContent.get_enemy_resource()
	var enemy := ActorFactory.build_enemy_actor(enemy_res)

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var encounter := CombatEncounter.new(player, class_res.starting_deck, enemy, enemy_res.moves, rng)

	combat_scene = CombatScene.new()
	combat_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(combat_scene)
	combat_scene.play_again_requested.connect(_start_new_fight)
	combat_scene.start(encounter)
