extends Resource
class_name CardResource

enum CardType { STRIKE, TECHNIQUE, TRAIT }
enum TargetType { SINGLE_ENEMY, SELF }

@export var id: StringName = &""
@export var display_name: String = ""
@export var cost: int = 1
@export var card_type: CardType = CardType.STRIKE
@export var target_type: TargetType = TargetType.SINGLE_ENEMY
@export var effects: Array[CardEffect] = []
