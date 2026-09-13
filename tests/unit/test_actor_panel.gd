extends GutTest

func test_display_shows_name_hp_and_block():
	var panel := ActorPanel.new()
	add_child_autofree(panel)
	var actor := CombatActor.new("Dwarf", 30)
	actor.block = 5
	actor.take_damage(4)
	panel.display(actor)
	assert_eq(panel.hp_bar.caption_label.text, "Dwarf")
	assert_eq(panel.hp_bar.value_label.text, "30 / 30")
	assert_true(panel.block_chip.visible)
	assert_eq(panel.block_chip.label.text, "Block 1")

func test_block_chip_hidden_when_no_block():
	var panel := ActorPanel.new()
	add_child_autofree(panel)
	var actor := CombatActor.new("Dwarf", 30)
	panel.display(actor)
	assert_false(panel.block_chip.visible)

func test_buff_row_shows_a_chip_per_active_status_in_a_fixed_order():
	var panel := ActorPanel.new()
	add_child_autofree(panel)
	var actor := CombatActor.new("Dwarf", 30)
	actor.add_status(&"weak", 1)
	actor.add_status(&"strength", 2)
	panel.display(actor)
	assert_eq(panel.buff_row.get_child_count(), 2, "Strength then Weak, in that order, regardless of the order they were applied.")
	assert_eq(panel.buff_row.get_child(0).label.text, "Strength 2")
	assert_eq(panel.buff_row.get_child(1).label.text, "Weak 1")

func test_buff_row_empty_when_no_statuses():
	var panel := ActorPanel.new()
	add_child_autofree(panel)
	var actor := CombatActor.new("Dwarf", 30)
	panel.display(actor)
	assert_eq(panel.buff_row.get_child_count(), 0)

func test_display_called_twice_leaves_only_current_statuses():
	var panel := ActorPanel.new()
	add_child_autofree(panel)
	var actor := CombatActor.new("Dwarf", 30)
	actor.add_status(&"strength", 2)
	panel.display(actor)
	actor.status_stacks.clear()
	panel.display(actor)
	assert_eq(panel.buff_row.get_child_count(), 0)
