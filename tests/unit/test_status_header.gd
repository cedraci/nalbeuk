extends RunStateTest

func test_refresh_shows_level_xp_and_skill_points():
	MetaState.level = 3
	MetaState.xp = 12
	MetaState.skill_points = 2
	RunState.enter_camp(DwarfContent.get_class_resource())
	var header := StatusHeader.new()
	add_child_autofree(header)
	header.refresh()
	assert_eq(header.level_label.text, "LEVEL 3")
	assert_true(header.xp_bar.visible)
	assert_eq(header.xp_bar.value_label.text, "12 / 40")
	assert_true(header.skill_points_chip.visible)
	assert_eq(header.skill_points_chip.label.text, "2 skill points")

func test_refresh_at_max_level_hides_the_xp_bar():
	MetaState.level = RunState.MAX_LEVEL
	RunState.enter_camp(DwarfContent.get_class_resource())
	var header := StatusHeader.new()
	add_child_autofree(header)
	header.refresh()
	assert_eq(header.level_label.text, "LEVEL 7 · MAX")
	assert_false(header.xp_bar.visible)

func test_refresh_hides_the_skill_chip_at_zero_and_singularises_one():
	RunState.enter_camp(DwarfContent.get_class_resource())
	var header := StatusHeader.new()
	add_child_autofree(header)
	header.refresh()
	assert_false(header.skill_points_chip.visible)
	RunState.skill_points = 1
	header.refresh()
	assert_eq(header.skill_points_chip.label.text, "1 skill point")

func test_gold_and_hp_chips_reflect_run_state_and_can_be_hidden():
	RunState.start_new_run(DwarfContent.get_class_resource())
	RunState.gold = 25
	RunState.player_current_hp = 21
	var header := StatusHeader.new()
	add_child_autofree(header)
	header.refresh()
	assert_eq(header.gold_chip.label.text, "25 gold")
	assert_eq(header.hp_chip.label.text, "21 / %d" % RunState.player_max_hp)
	header.set_gold_visible(false)
	header.set_hp_visible(false)
	assert_false(header.gold_chip.visible)
	assert_false(header.hp_chip.visible)
