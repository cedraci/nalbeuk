extends Control
class_name GameOverScene

signal camp_requested

# Set by RunScene before add_child; null is treated as an empty outcome.
var outcome: RunOutcome = null

var result_label: Label
var outcome_label: Label
var camp_button: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var vbox := VBoxContainer.new()
	add_child(vbox)

	result_label = Label.new()
	result_label.text = "You died on floor %d." % RunState.current_floor
	vbox.add_child(result_label)

	var gear_lost: int = outcome.gear_lost if outcome != null else 0
	var xp_lost: int = outcome.xp_lost if outcome != null else 0
	outcome_label = Label.new()
	outcome_label.text = "Lost %d piece(s) of gear and %d XP. Skills are safe." % [gear_lost, xp_lost]
	vbox.add_child(outcome_label)

	camp_button = Button.new()
	camp_button.text = "Return to Camp"
	camp_button.pressed.connect(_on_camp_pressed)
	vbox.add_child(camp_button)

func _on_camp_pressed() -> void:
	camp_requested.emit()
