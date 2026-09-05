extends Control
class_name CombatScene

signal combat_dismissed(player_won: bool)

var encounter: CombatEncounter
var _last_result_player_won: bool = false

var player_panel: ActorPanel
var enemy_panel: ActorPanel
var hand_view: HandView
var intent_view: IntentView
var energy_label: Label
var end_turn_button: Button
var result_label: Label
var play_again_button: Button
var turn_ui_container: Control
var result_container: Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var root_vbox := VBoxContainer.new()
	add_child(root_vbox)
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)

	turn_ui_container = VBoxContainer.new()
	root_vbox.add_child(turn_ui_container)

	var actors_hbox := HBoxContainer.new()
	turn_ui_container.add_child(actors_hbox)
	player_panel = ActorPanel.new()
	enemy_panel = ActorPanel.new()
	actors_hbox.add_child(player_panel)
	actors_hbox.add_child(enemy_panel)

	intent_view = IntentView.new()
	turn_ui_container.add_child(intent_view)

	hand_view = HandView.new()
	hand_view.card_clicked.connect(_on_hand_card_clicked)
	turn_ui_container.add_child(hand_view)

	var bottom_hbox := HBoxContainer.new()
	turn_ui_container.add_child(bottom_hbox)
	energy_label = Label.new()
	bottom_hbox.add_child(energy_label)
	end_turn_button = Button.new()
	end_turn_button.text = "End Turn"
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	bottom_hbox.add_child(end_turn_button)

	result_container = VBoxContainer.new()
	root_vbox.add_child(result_container)
	result_container.hide()
	result_label = Label.new()
	result_container.add_child(result_label)
	play_again_button = Button.new()
	play_again_button.text = "Continue"
	play_again_button.pressed.connect(_on_play_again_pressed)
	result_container.add_child(play_again_button)

func start(p_encounter: CombatEncounter) -> void:
	encounter = p_encounter
	encounter.state_changed.connect(_refresh)
	encounter.combat_ended.connect(_on_combat_ended)
	result_container.hide()
	turn_ui_container.show()
	encounter.start_player_turn()
	_refresh()

func _refresh() -> void:
	player_panel.display(encounter.player)
	enemy_panel.display(encounter.enemy)
	hand_view.display(encounter.hand, encounter.energy)
	var intent := encounter.get_current_enemy_intent()
	if intent != null:
		intent_view.display(intent)
	energy_label.text = "Energy: %d / %d" % [encounter.energy, CombatEncounter.MAX_ENERGY]

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
