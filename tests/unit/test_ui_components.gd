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

func test_art_placeholder_applies_the_torchlit_shader_when_requested():
	var art := ArtPlaceholder.new()
	add_child_autofree(art)
	art.setup(&"_test_fixture", "a fixture creature", Vector2(40, 40), true)
	assert_true(art.texture_rect.material is ShaderMaterial)

func test_art_placeholder_skips_the_shader_by_default():
	var art := ArtPlaceholder.new()
	add_child_autofree(art)
	art.setup(&"_test_fixture", "a fixture creature", Vector2(40, 40))
	assert_null(art.texture_rect.material)

func test_art_accent_dot_ignores_the_mouse_and_pulses():
	var dot := ArtAccentDot.new(UiTokens.RUNE, 6.0)
	add_child_autofree(dot)
	assert_eq(dot.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(dot.custom_minimum_size, Vector2(12, 12))
	assert_true(dot.is_pulsing())

func test_art_placeholder_adds_a_glow_dot_per_accent_marker():
	var art := ArtPlaceholder.new()
	add_child_autofree(art)
	var markers: Array[Vector2] = [Vector2(0.5, 0.5), Vector2(0.25, 0.75)]
	art.setup(&"_test_fixture", "a fixture creature", Vector2(40, 40), false, markers)
	assert_eq(art.get_child_count(), 2, "texture_rect plus the accent overlay")
	assert_not_null(art.accents_overlay)
	assert_eq(art.accents_overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(art.accents_overlay.get_child_count(), 2, "one accent dot per marker")
	assert_true(art.accents_overlay.get_child(0) is ArtAccentDot)

func test_art_placeholder_dot_positions_survive_the_layout_pass():
	# PanelContainer sorts its children via fit_child_in_rect(), which would
	# flatten a dot parented straight to it. Await a real frame so the sort
	# actually runs before asserting — a synchronous assert here passes even
	# when the layout destroys the position afterwards.
	var art := ArtPlaceholder.new()
	add_child_autofree(art)
	var markers: Array[Vector2] = [Vector2(0.5, 0.5)]
	art.setup(&"_test_fixture", "a fixture creature", Vector2(40, 40), false, markers)
	var dot: ArtAccentDot = art.accents_overlay.get_child(0)
	var expected_position: Vector2 = Vector2(20, 20) - dot.custom_minimum_size / 2.0
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(dot.position, expected_position, "the dot keeps its hand-placed position")
	assert_eq(dot.size, dot.custom_minimum_size, "the dot is not stretched to fill the panel")
	assert_eq(art.accents_overlay.size, art.size, "the overlay covers the whole art area")
	assert_eq(art.accents_overlay.position, Vector2.ZERO, "the overlay sits at the art's origin")

func test_art_placeholder_adds_no_dots_without_markers():
	var art := ArtPlaceholder.new()
	add_child_autofree(art)
	art.setup(&"_test_fixture", "a fixture creature", Vector2(40, 40))
	assert_eq(art.get_child_count(), 1, "just the texture_rect")
	assert_null(art.accents_overlay, "no overlay when there are no markers")
