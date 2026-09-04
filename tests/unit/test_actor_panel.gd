extends GutTest

func test_display_shows_name_hp_and_block():
	var panel := ActorPanel.new()
	add_child_autofree(panel)
	var actor := CombatActor.new("Dwarf", 30)
	actor.block = 5
	actor.take_damage(4)
	panel.display(actor)
	assert_eq(panel.name_label.text, "Dwarf")
	assert_eq(panel.hp_label.text, "HP: 30 / 30")
	assert_eq(panel.block_label.text, "Block: 1")
