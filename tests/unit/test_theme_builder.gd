extends GutTest

func test_build_is_memoised():
	assert_eq(ThemeBuilder.build(), ThemeBuilder.build())

func test_fonts_load_as_variations_of_the_bundled_files():
	var display := ThemeBuilder.display_font(800)
	var body := ThemeBuilder.body_font(400)
	assert_true(display.base_font is FontFile)
	assert_true(body.base_font is FontFile)
	var weight_tag := TextServerManager.get_primary_interface().name_to_tag("weight")
	assert_true(display.variation_opentype.has(weight_tag))
	assert_eq(int(display.variation_opentype[weight_tag]), 800)

func test_theme_defines_the_button_variations():
	var theme := ThemeBuilder.build()
	for variation in [&"Primary", &"Ghost", &"Danger", &"Card", &"NodeLocked", &"NodeVisited", &"NodeOpen", &"NodeCurrent"]:
		assert_eq(theme.get_type_variation_base(variation), &"Button", String(variation))
		assert_true(theme.has_stylebox(&"normal", variation), "%s has a normal stylebox" % variation)

func test_theme_defines_label_and_panel_variations():
	var theme := ThemeBuilder.build()
	for variation in [&"Display", &"Heading", &"Eyebrow", &"Number", &"Muted", &"Banter"]:
		assert_eq(theme.get_type_variation_base(variation), &"Label", String(variation))
		assert_true(theme.has_font_size(&"font_size", variation), String(variation))
	assert_eq(theme.get_type_variation_base(&"Chip"), &"PanelContainer")
	assert_true(theme.has_stylebox(&"panel", &"PanelContainer"))
	assert_true(theme.has_stylebox(&"fill", &"ProgressBar"))

func test_theme_defaults_use_the_body_font_and_text_colour():
	var theme := ThemeBuilder.build()
	assert_true(theme.default_font is FontVariation)
	assert_eq(theme.default_font_size, UiTokens.FONT_BODY)
	assert_eq(theme.get_color(&"font_color", &"Label"), UiTokens.TEXT)

func test_size_button_enforces_the_hit_target():
	var button := Button.new()
	add_child_autofree(button)
	ThemeBuilder.size_button(button)
	assert_eq(button.custom_minimum_size.y, UiTokens.HIT_TARGET)
	var tall_button := Button.new()
	add_child_autofree(tall_button)
	tall_button.custom_minimum_size.y = 56
	ThemeBuilder.size_button(tall_button)
	assert_eq(tall_button.custom_minimum_size.y, 56.0, "A button already taller than the hit target keeps its own size.")

func test_size_button_returns_the_button_it_was_given():
	var button := Button.new()
	add_child_autofree(button)
	assert_eq(ThemeBuilder.size_button(button), button)

func test_node_variations_carry_the_designed_glow():
	var theme := ThemeBuilder.build()
	assert_eq(theme.get_stylebox(&"normal", &"NodeCurrent").shadow_size, 26)
	assert_eq(theme.get_stylebox(&"normal", &"NodeOpen").shadow_size, 14)
	assert_eq(theme.get_stylebox(&"normal", &"NodeLocked").shadow_size, 0)
