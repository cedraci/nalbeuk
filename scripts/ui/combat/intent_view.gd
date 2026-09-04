extends HBoxContainer
class_name IntentView

var label: Label

func _ready() -> void:
	label = Label.new()
	add_child(label)

func display(move: EnemyMove) -> void:
	var intent_name: String = EnemyMove.IntentType.keys()[move.intent_type]
	if move.display_value > 0:
		label.text = "%s %d" % [intent_name, move.display_value]
	else:
		label.text = intent_name
	label.tooltip_text = move.description
