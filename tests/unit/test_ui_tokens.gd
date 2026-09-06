extends GutTest

func test_palette_matches_the_design_sheet():
	assert_eq(UiTokens.BG.to_html(false), "14110f")
	assert_eq(UiTokens.SURFACE.to_html(false), "1f1a16")
	assert_eq(UiTokens.TEXT.to_html(false), "ece3d3")
	assert_eq(UiTokens.EMBER.to_html(false), "e8a44a")
	assert_eq(UiTokens.RUNE.to_html(false), "74b0d6")
	assert_eq(UiTokens.BLOOD.to_html(false), "c94a3b")
	assert_almost_eq(UiTokens.LINE.a, 0.26, 0.001)

func test_sizes_match_the_design_sheet():
	assert_eq(UiTokens.FONT_BODY, 15)
	assert_eq(UiTokens.FONT_H1, 40)
	assert_eq(UiTokens.HIT_TARGET, 44)
	assert_eq(UiTokens.NODE_SIZE, 56)
	assert_eq(UiTokens.SPACE_6, 32)
	assert_almost_eq(UiTokens.FLICKER_SECONDS, 3.4, 0.001)
