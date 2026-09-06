extends Control
class_name EventScene

signal node_completed

var description_label: Label
var choices_container: VBoxContainer
var outcome_label: Label
var continue_button: Button

# The picked choice, applied only when Continue is pressed. Applying it
# earlier would write XP through to MetaState while the run snapshot still
# has the event node unvisited: quitting on the outcome panel would keep
# the XP and replay the event.
var _pending_choice: EventChoice = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root_vbox := VBoxContainer.new()
	add_child(root_vbox)

	description_label = Label.new()
	root_vbox.add_child(description_label)

	choices_container = VBoxContainer.new()
	root_vbox.add_child(choices_container)

	outcome_label = Label.new()
	root_vbox.add_child(outcome_label)
	outcome_label.hide()

	continue_button = Button.new()
	continue_button.text = "Continue"
	continue_button.pressed.connect(_on_continue_pressed)
	root_vbox.add_child(continue_button)
	continue_button.hide()

func display(event: EventResource) -> void:
	_pending_choice = null
	description_label.text = event.description
	for child in choices_container.get_children():
		choices_container.remove_child(child)
		child.queue_free()
	for choice in event.choices:
		var button := Button.new()
		button.text = choice.label
		button.pressed.connect(_on_choice_button_pressed.bind(choice))
		choices_container.add_child(button)
	choices_container.show()
	outcome_label.hide()
	continue_button.hide()

func _on_choice_button_pressed(choice: EventChoice) -> void:
	_pending_choice = choice
	choices_container.hide()
	outcome_label.text = choice.outcome_text
	outcome_label.show()
	continue_button.show()

func _on_continue_pressed() -> void:
	# Apply and checkpoint in one burst: node_completed drives
	# RunState.mark_node_visited_and_advance(), which captures the snapshot.
	if _pending_choice != null:
		RunState.apply_event_choice(_pending_choice)
		_pending_choice = null
	node_completed.emit()
