extends Resource
class_name EnemyMove

enum IntentType { ATTACK, DEFEND, BUFF, DEBUFF, SPECIAL }

@export var intent_type: IntentType = IntentType.ATTACK
@export var effects: Array[CardEffect] = []
@export var description: String = ""
@export var display_value: int = 0
