extends RefCounted
class_name UiTokens

# The Torchlit design system as typed constants — the single source for
# colours, type sizes, spacing, radii and motion. Mirrors
# docs/design/look-and-feel/Tokens.dc.html.

const BG := Color("#14110f")
const SURFACE := Color("#1f1a16")
const SURFACE_2 := Color("#2a231d")
const TEXT := Color("#ece3d3")
const MUTED := Color("#8f857a")
const DIM := Color("#7a7166")
const EMBER := Color("#e8a44a")
const EMBER_LIGHT := Color("#f3c274")
const EMBER_DEEP := Color("#c9542b")
const RUNE := Color("#74b0d6")
const MOSS := Color("#8fae5c")
const BLOOD := Color("#c94a3b")
const LINE := Color(0.91, 0.64, 0.29, 0.26)
const LINE_SOFT := Color(1.0, 1.0, 1.0, 0.07)

const FONT_EYEBROW := 12
const FONT_BODY := 15
const FONT_BANTER := 16
const FONT_H2 := 20
const FONT_NUMBER := 24
const FONT_H1 := 40

const SPACE_1 := 4
const SPACE_2 := 8
const SPACE_3 := 12
const SPACE_4 := 16
const SPACE_5 := 24
const SPACE_6 := 32

const RADIUS_BUTTON := 4
const RADIUS_PANEL := 6
const RADIUS_CARD := 8

const HIT_TARGET := 44
const NODE_SIZE := 56
const NODE_SIZE_BOSS := 72

const FLICKER_SECONDS := 3.4
const PULSE_SECONDS := 2.2
const HOVER_SECONDS := 0.18

static func ember(alpha: float) -> Color:
	return Color(EMBER.r, EMBER.g, EMBER.b, alpha)
