extends PanelContainer
class_name ActorPanel

# A combat stage pill: name + HP bar on top, Block and active statuses
# (Strength, Weak, ...) as chips below. Statuses not in STATUS_ORDER are
# not shown yet — add them there when a new one gets a card.

const STATUS_ORDER: Array[StringName] = [&"strength", &"weak"]
const STATUS_META := {
	&"strength": {"icon": &"bolt", "label": "Strength", "tint": UiTokens.EMBER},
	&"weak": {"icon": &"weak", "label": "Weak", "tint": UiTokens.BLOOD},
}

var hp_bar: StatBar
var block_chip: StatChip
var buff_row: HBoxContainer

func _init() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", UiTokens.SPACE_2)
	add_child(vbox)

	hp_bar = StatBar.new()
	hp_bar.caption_label.theme_type_variation = &"Heading"
	vbox.add_child(hp_bar)

	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override(&"separation", UiTokens.SPACE_2)
	vbox.add_child(stats_row)

	block_chip = StatChip.new()
	stats_row.add_child(block_chip)

	buff_row = HBoxContainer.new()
	buff_row.add_theme_constant_override(&"separation", UiTokens.SPACE_2)
	stats_row.add_child(buff_row)

func display(actor: CombatActor, hp_fill: Color = UiTokens.MOSS) -> void:
	hp_bar.setup(actor.display_name, hp_fill)
	hp_bar.set_values(actor.current_hp, actor.max_hp)

	block_chip.setup(&"shield", "Block %d" % actor.block, UiTokens.RUNE)
	block_chip.visible = actor.block > 0

	for child in buff_row.get_children():
		buff_row.remove_child(child)
		child.queue_free()
	for status_id in STATUS_ORDER:
		var stacks: int = actor.get_status_stacks(status_id)
		if stacks <= 0:
			continue
		var meta: Dictionary = STATUS_META[status_id]
		var chip := StatChip.new()
		chip.setup(meta["icon"], "%s %d" % [meta["label"], stacks], meta["tint"])
		buff_row.add_child(chip)
