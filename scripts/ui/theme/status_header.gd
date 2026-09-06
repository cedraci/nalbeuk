extends HBoxContainer
class_name StatusHeader

# Level, XP bar, skill points, gold and HP — the strip at the top of the
# Map and inside Camp's status panel. Reads RunState on refresh().

var level_label: Label
var xp_bar: StatBar
var skill_points_chip: StatChip
var gold_chip: StatChip
var hp_chip: StatChip

func _init() -> void:
	add_theme_constant_override(&"separation", UiTokens.SPACE_5)
	alignment = BoxContainer.ALIGNMENT_BEGIN
	level_label = Label.new()
	level_label.theme_type_variation = &"Number"
	add_child(level_label)
	xp_bar = StatBar.new()
	xp_bar.custom_minimum_size = Vector2(180, 0)
	xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	xp_bar.setup("XP", UiTokens.EMBER)
	add_child(xp_bar)
	skill_points_chip = StatChip.new()
	skill_points_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(skill_points_chip)
	gold_chip = StatChip.new()
	gold_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(gold_chip)
	hp_chip = StatChip.new()
	hp_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(hp_chip)

func refresh() -> void:
	var at_max: bool = RunState.level >= RunState.MAX_LEVEL
	level_label.text = "LEVEL %d · MAX" % RunState.level if at_max else "LEVEL %d" % RunState.level
	xp_bar.visible = not at_max
	if not at_max:
		xp_bar.set_values(RunState.xp, RunState.XP_THRESHOLDS[RunState.level - 1])
	var points: int = RunState.skill_points
	skill_points_chip.setup(&"tree", "%d skill point%s" % [points, "" if points == 1 else "s"], UiTokens.EMBER)
	skill_points_chip.visible = points > 0
	gold_chip.setup(&"coin", "%d gold" % RunState.gold, UiTokens.EMBER)
	hp_chip.setup(&"heart", "%d / %d" % [RunState.player_current_hp, RunState.player_max_hp], UiTokens.BLOOD)

func set_gold_visible(visible_now: bool) -> void:
	gold_chip.visible = visible_now

func set_hp_visible(visible_now: bool) -> void:
	hp_chip.visible = visible_now
