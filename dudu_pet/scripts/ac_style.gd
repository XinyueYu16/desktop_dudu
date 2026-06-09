class_name ACStyle
extends RefCounted

# 动森风格 (Animal Crossing) 色板和样式工厂
# Used by: side menu card, chat panel, speech bubble, hover input.

# ── Color palette ──
const CREAM := Color(0.925, 0.906, 0.859, 1.0)
const CREAM_BG := Color(0.925, 0.906, 0.859, 0.94)
const TAN := Color(0.690, 0.612, 0.502, 1.0)
const BROWN := Color(0.353, 0.282, 0.220, 1.0)
const BROWN_LIGHT := Color(0.580, 0.510, 0.420, 1.0)
const HOVER := Color(0.878, 0.847, 0.780, 1.0)
const SAGE := Color(0.482, 0.659, 0.557, 1.0)
const PEACH := Color(0.910, 0.659, 0.486, 1.0)

# Dark-warm variants for floating bubbles (unobtrusive on dark desktop)
const DARK_WARM := Color(0.275, 0.251, 0.220, 0.85)
const DARK_SAGE := Color(0.255, 0.333, 0.310, 0.85)
const LIGHT_TEXT := Color(0.961, 0.941, 0.890, 1.0)


static func card_stylebox(radius: float = 14.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CREAM_BG
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = TAN
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func menu_item_stylebox(hover: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = HOVER if hover else Color.TRANSPARENT
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	return sb


static func bubble_stylebox(role: String) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var r := 14.0
	var r_asym := 6.0
	sb.corner_radius_top_left = r
	sb.corner_radius_top_right = r
	sb.corner_radius_bottom_left = r if role == "user" else r_asym
	sb.corner_radius_bottom_right = r_asym if role == "user" else r
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	if role == "user":
		sb.bg_color = Color(SAGE.r, SAGE.g, SAGE.b, 0.82)
	else:
		sb.bg_color = DARK_WARM
	return sb


static func panel_card_stylebox(radius: float = 16.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CREAM_BG
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = TAN
	return sb
