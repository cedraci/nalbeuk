extends PanelContainer
class_name ActorPanel

var name_label: Label
var hp_label: Label
var block_label: Label

func _ready() -> void:
	var vbox := VBoxContainer.new()
	add_child(vbox)
	name_label = Label.new()
	hp_label = Label.new()
	block_label = Label.new()
	vbox.add_child(name_label)
	vbox.add_child(hp_label)
	vbox.add_child(block_label)

func display(actor: CombatActor) -> void:
	name_label.text = actor.display_name
	hp_label.text = "HP: %d / %d" % [actor.current_hp, actor.max_hp]
	block_label.text = "Block: %d" % actor.block
