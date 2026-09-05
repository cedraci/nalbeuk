extends Resource
class_name EquipmentResource

enum Slot { WEAPON, ARMOR, TRINKET }

@export var id: StringName
@export var display_name: String = ""
@export var slot: Slot
@export var description: String = ""
@export var strength_delta: int = 0
@export var block_delta: int = 0
@export var passive_id: StringName = &""
