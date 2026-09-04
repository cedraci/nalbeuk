extends Resource
class_name PersistentStats

@export var strength: int = 0
@export var agility: int = 0
@export var intellect: int = 0
@export var vitality: int = 0
@export var luck: int = 0

func compute_max_hp(base_hp: int) -> int:
	return base_hp + vitality * 2

func compute_base_strike_bonus() -> int:
	return strength
