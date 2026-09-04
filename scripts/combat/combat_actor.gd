class_name CombatActor
extends RefCounted

signal died

var display_name: String
var max_hp: int
var current_hp: int
var block: int = 0
var baseline_strike_bonus: int = 0
var status_stacks: Dictionary = {}

func _init(p_display_name: String, p_max_hp: int, p_baseline_strike_bonus: int = 0) -> void:
	display_name = p_display_name
	max_hp = p_max_hp
	current_hp = p_max_hp
	baseline_strike_bonus = p_baseline_strike_bonus

func take_damage(amount: int) -> void:
	var incoming: int = max(amount, 0) as int
	var absorbed: int = min(block, incoming) as int
	block -= absorbed
	var remaining: int = incoming - absorbed
	current_hp = max(current_hp - remaining, 0) as int
	if current_hp == 0:
		died.emit()

func add_block(amount: int) -> void:
	block += amount

func clear_block() -> void:
	block = 0

func get_status_stacks(status_id: StringName) -> int:
	return status_stacks.get(status_id, 0)

func add_status(status_id: StringName, stacks: int) -> void:
	status_stacks[status_id] = get_status_stacks(status_id) + stacks
