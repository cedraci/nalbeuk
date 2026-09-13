extends Control
class_name CombatScene

# The Torchlit battlefield: player foreground bottom-left, enemy back-right
# with its intent floating over its head, energy + draw pile by the player,
# discard + End turn by the hand's other side. See
# docs/design/look-and-feel/Combat.dc.html for the reference mockup.

signal combat_dismissed(player_won: bool)

var encounter: CombatEncounter
var _last_result_player_won: bool = false

var player_panel: ActorPanel
var enemy_panel: ActorPanel
var player_art: ArtPlaceholder
var enemy_art: ArtPlaceholder
var intent_view: IntentView
var hand_view: HandView
var energy_value_label: Label
var draw_count_label: Label
var discard_count_label: Label
var relic_row: HBoxContainer
var end_turn_button: Button
var potion_container: VBoxContainer
var result_label: Label
var play_again_button: Button
var turn_ui_container: Control
var result_container: Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	turn_ui_container = Control.new()
	turn_ui_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(turn_ui_container)

	_build_backdrop(turn_ui_container)
	_build_top_bar(turn_ui_container)
	_build_enemy_stage(turn_ui_container)
	_build_player_stage(turn_ui_container)
	_build_hand(turn_ui_container)
	_build_bottom_left_cluster(turn_ui_container)
	_build_bottom_right_cluster(turn_ui_container)

	result_container = VBoxContainer.new()
	add_child(result_container)
	result_container.hide()
	result_label = Label.new()
	result_label.theme_type_variation = &"Display"
	result_container.add_child(result_label)
	play_again_button = Button.new()
	play_again_button.theme_type_variation = &"Primary"
	play_again_button.text = "Continue"
	ThemeBuilder.size_button(play_again_button)
	play_again_button.pressed.connect(_on_play_again_pressed)
	result_container.add_child(play_again_button)

func _build_backdrop(parent: Control) -> void:
	var background := ArtPlaceholder.new()
	background.setup(&"combat_backdrop", "combat backdrop — a low vaulted chamber, one torch bracket each side, rubble", Vector2(1440, 560))
	background.position = Vector2(0, 0)
	background.size = Vector2(1440, 560)
	parent.add_child(background)

	var glow_left := TorchGlow.new()
	glow_left.set_radius(260)
	glow_left.position = Vector2(-80, -160)
	parent.add_child(glow_left)

	var glow_right := TorchGlow.new()
	glow_right.set_radius(260)
	glow_right.position = Vector2(980, -160)
	parent.add_child(glow_right)

func _build_top_bar(parent: Control) -> void:
	var eyebrow := Label.new()
	eyebrow.theme_type_variation = &"Eyebrow"
	eyebrow.text = "Floor %d · Combat" % (RunState.current_floor + 1)
	eyebrow.position = Vector2(40, 22)
	parent.add_child(eyebrow)

	relic_row = HBoxContainer.new()
	relic_row.add_theme_constant_override(&"separation", UiTokens.SPACE_2)
	relic_row.position = Vector2(240, 18)
	parent.add_child(relic_row)

func _build_enemy_stage(parent: Control) -> void:
	intent_view = IntentView.new()
	intent_view.position = Vector2(1087, 96)
	parent.add_child(intent_view)

	enemy_art = ArtPlaceholder.new()
	enemy_art.setup(&"enemy_default", "the enemy, lit from below, ready to lunge", Vector2(288, 266))
	enemy_art.position = Vector2(966, 150)
	enemy_art.size = Vector2(288, 266)
	parent.add_child(enemy_art)

	enemy_panel = ActorPanel.new()
	enemy_panel.custom_minimum_size = Vector2(308, 0)
	enemy_panel.position = Vector2(956, 428)
	parent.add_child(enemy_panel)

func _build_player_stage(parent: Control) -> void:
	player_art = ArtPlaceholder.new()
	player_art.setup(&"player_default", "the party's fighter, torch in one hand, weapon in the other", Vector2(320, 296))
	player_art.position = Vector2(110, 206)
	player_art.size = Vector2(320, 296)
	parent.add_child(player_art)

	player_panel = ActorPanel.new()
	player_panel.custom_minimum_size = Vector2(344, 0)
	player_panel.position = Vector2(98, 514)
	parent.add_child(player_panel)

func _build_hand(parent: Control) -> void:
	hand_view = HandView.new()
	hand_view.position = Vector2(260, 610)
	hand_view.size = Vector2(920, 260)
	hand_view.card_clicked.connect(_on_hand_card_clicked)
	parent.add_child(hand_view)

func _build_bottom_left_cluster(parent: Control) -> void:
	var cluster := VBoxContainer.new()
	cluster.alignment = BoxContainer.ALIGNMENT_CENTER
	cluster.add_theme_constant_override(&"separation", UiTokens.SPACE_4)
	cluster.position = Vector2(56, 654)
	parent.add_child(cluster)

	var energy_orb := PanelContainer.new()
	energy_orb.custom_minimum_size = Vector2(66, 66)
	var orb_box := StyleBoxFlat.new()
	orb_box.bg_color = UiTokens.EMBER
	orb_box.border_color = UiTokens.EMBER_LIGHT
	orb_box.set_border_width_all(2)
	orb_box.set_corner_radius_all(999)
	orb_box.shadow_size = 18
	orb_box.shadow_color = UiTokens.ember(0.5)
	energy_orb.add_theme_stylebox_override(&"panel", orb_box)
	cluster.add_child(energy_orb)
	energy_value_label = Label.new()
	energy_value_label.theme_type_variation = &"Number"
	energy_value_label.add_theme_color_override(&"font_color", UiTokens.BG)
	energy_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energy_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	energy_orb.add_child(energy_value_label)

	var draw_label := Label.new()
	draw_label.theme_type_variation = &"Eyebrow"
	draw_label.text = "DRAW"
	draw_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cluster.add_child(draw_label)

	var draw_chip := StatChip.new()
	draw_count_label = draw_chip.label
	draw_chip.setup(&"cards", "0", UiTokens.MUTED)
	cluster.add_child(draw_chip)

func _build_bottom_right_cluster(parent: Control) -> void:
	var cluster := VBoxContainer.new()
	cluster.alignment = BoxContainer.ALIGNMENT_CENTER
	cluster.add_theme_constant_override(&"separation", UiTokens.SPACE_3)
	cluster.position = Vector2(1160, 640)
	parent.add_child(cluster)

	potion_container = VBoxContainer.new()
	potion_container.add_theme_constant_override(&"separation", UiTokens.SPACE_2)
	cluster.add_child(potion_container)

	end_turn_button = Button.new()
	end_turn_button.theme_type_variation = &"Primary"
	end_turn_button.text = "End turn"
	end_turn_button.custom_minimum_size.x = 200
	ThemeBuilder.size_button(end_turn_button)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	cluster.add_child(end_turn_button)

	var discard_label := Label.new()
	discard_label.theme_type_variation = &"Eyebrow"
	discard_label.text = "DISCARD"
	discard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cluster.add_child(discard_label)

	var discard_chip := StatChip.new()
	discard_count_label = discard_chip.label
	discard_chip.setup(&"cards", "0", UiTokens.MUTED)
	cluster.add_child(discard_chip)

func start(p_encounter: CombatEncounter) -> void:
	encounter = p_encounter
	encounter.state_changed.connect(_refresh)
	encounter.combat_ended.connect(_on_combat_ended)
	result_container.hide()
	turn_ui_container.show()
	encounter.start_player_turn()
	_refresh()

func _refresh() -> void:
	player_panel.display(encounter.player, UiTokens.MOSS)
	enemy_panel.display(encounter.enemy, UiTokens.BLOOD)
	player_panel.size = player_panel.get_combined_minimum_size()
	enemy_panel.size = enemy_panel.get_combined_minimum_size()
	hand_view.display(encounter.hand, encounter.energy)
	var intent := encounter.get_current_enemy_intent()
	if intent != null:
		intent_view.display(intent)
	energy_value_label.text = "%d/%d" % [encounter.energy, CombatEncounter.MAX_ENERGY]
	draw_count_label.text = str(encounter.draw_pile.size())
	discard_count_label.text = str(encounter.discard_pile.size())
	_refresh_relics()
	_refresh_potions()

func _refresh_relics() -> void:
	for child in relic_row.get_children():
		relic_row.remove_child(child)
		child.queue_free()
	for relic_id in RunState.unlocked_relics:
		var relic: RelicResource = DwarfRelics.get_by_id(relic_id)
		if relic == null:
			continue
		var chip := StatChip.new()
		chip.setup(&"gem", relic.display_name, UiTokens.EMBER)
		relic_row.add_child(chip)

func _refresh_potions() -> void:
	for child in potion_container.get_children():
		potion_container.remove_child(child)
		child.queue_free()
	potion_container.visible = not RunState.potions.is_empty()
	for i in range(RunState.potions.size()):
		var potion: PotionResource = RunState.potions[i]
		var button := Button.new()
		button.theme_type_variation = &"Ghost"
		button.text = "%s: %s" % [potion.display_name, potion.description]
		button.pressed.connect(_on_potion_button_pressed.bind(i))
		potion_container.add_child(button)

func _on_potion_button_pressed(index: int) -> void:
	var potion: PotionResource = RunState.consume_potion(index)
	potion.apply(encounter.player)
	_refresh()

func _on_hand_card_clicked(card: CardResource) -> void:
	if encounter.can_play_card(card):
		encounter.play_card(card)

func _on_end_turn_pressed() -> void:
	encounter.end_player_turn()
	if not encounter.is_over:
		encounter.start_player_turn()
		_refresh()

func _on_combat_ended(player_won: bool) -> void:
	turn_ui_container.hide()
	result_container.show()
	result_label.text = "You Won" if player_won else "You Lost"
	_last_result_player_won = player_won

func _on_play_again_pressed() -> void:
	combat_dismissed.emit(_last_result_player_won)
