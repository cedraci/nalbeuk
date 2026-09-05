extends Control
class_name GameOverScene

signal new_run_requested

var result_label: Label
var new_run_button: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var vbox := VBoxContainer.new()
	add_child(vbox)

	result_label = Label.new()
	result_label.text = "You died on floor %d." % RunState.current_floor
	vbox.add_child(result_label)

	new_run_button = Button.new()
	new_run_button.text = "New Run"
	new_run_button.pressed.connect(_on_new_run_pressed)
	vbox.add_child(new_run_button)

func _on_new_run_pressed() -> void:
	new_run_requested.emit()
