extends GutTest

func test_stat_chip_shows_icon_text_and_tint():
	var chip := StatChip.new()
	add_child_autofree(chip)
	chip.setup(&"heart", "21 / 36", UiTokens.BLOOD)
	assert_not_null(chip.icon_rect.texture)
	assert_eq(chip.label.text, "21 / 36")
	assert_eq(chip.icon_rect.modulate, UiTokens.BLOOD)
	assert_eq(chip.theme_type_variation, &"Chip")
	chip.set_text("5 / 36")
	assert_eq(chip.label.text, "5 / 36")

func test_stat_bar_shows_caption_and_ratio():
	var bar := StatBar.new()
	add_child_autofree(bar)
	bar.setup("XP", UiTokens.EMBER)
	bar.set_values(7, 30)
	assert_eq(bar.caption_label.text, "XP")
	assert_eq(bar.value_label.text, "7 / 30")
	assert_eq(bar.bar.max_value, 30.0)
	assert_eq(bar.bar.value, 7.0)
	assert_false(bar.bar.show_percentage)

func test_stat_bar_tolerates_a_zero_maximum():
	var bar := StatBar.new()
	add_child_autofree(bar)
	bar.setup("XP", UiTokens.EMBER)
	bar.set_values(0, 0)
	assert_eq(bar.value_label.text, "0 / 0")
	assert_true(bar.bar.max_value > 0.0, "ProgressBar needs max > min; the bar clamps to 1.")

func test_torch_glow_ignores_the_mouse_and_flickers():
	var glow := TorchGlow.new()
	glow.set_radius(120.0)
	add_child_autofree(glow)
	assert_eq(glow.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(glow.custom_minimum_size, Vector2(240, 240))
	assert_true(glow.is_flickering())

func test_art_placeholder_shows_the_brief_when_no_image_exists():
	var art := ArtPlaceholder.new()
	add_child_autofree(art)
	art.setup(&"no_such_art", "the party, torchlit", Vector2(400, 300))
	assert_false(art.has_art)
	assert_null(art.texture_rect)
	assert_eq(art.label.text, "[art: the party, torchlit]")
	assert_eq(art.custom_minimum_size, Vector2(400, 300))

func test_art_placeholder_can_be_set_up_twice():
	var art := ArtPlaceholder.new()
	add_child_autofree(art)
	art.setup(&"a", "first", Vector2(10, 10))
	art.setup(&"b", "second", Vector2(20, 20))
	assert_eq(art.label.text, "[art: second]")
	assert_eq(art.get_child_count(), 1, "setup() replaces its previous content.")

func test_art_placeholder_resolves_an_svg_before_a_png():
	var art := ArtPlaceholder.new()
	add_child_autofree(art)
	art.setup(&"_test_fixture", "a fixture creature", Vector2(40, 40))
	assert_true(art.has_art)
	assert_not_null(art.texture_rect)
	assert_null(art.label)
