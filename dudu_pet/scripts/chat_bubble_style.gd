class_name ChatBubbleStyle
extends RefCounted

# Chat bubble look — 动森 warm palette.
# Used by: floating bubbles, magic diary, and speech bubble.


static func _dim(v: float, scaled: bool) -> float:
	return UiConfig.s(v) if scaled else v


static func _dimi(v: int, scaled: bool) -> int:
	return UiConfig.si(v) if scaled else v


static func make_stylebox(role: String, scaled: bool = false) -> StyleBoxFlat:
	return ACStyle.bubble_stylebox(role)


static func font_color(_role: String) -> Color:
	return ACStyle.LIGHT_TEXT


static func apply_to_panel(panel: PanelContainer, label: Label, role: String, scaled: bool = true) -> void:
	panel.add_theme_stylebox_override("panel", make_stylebox(role, scaled))
	label.add_theme_color_override("font_color", font_color(role))
	label.add_theme_font_size_override("font_size", _dimi(14, scaled))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


static func make_input_stylebox(scaled: bool = true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var r := _dimi(12, scaled)
	var r_asym := _dimi(4, scaled)
	sb.corner_radius_top_left = r
	sb.corner_radius_top_right = r
	sb.corner_radius_bottom_left = r
	sb.corner_radius_bottom_right = r_asym
	sb.content_margin_left = _dimi(12, scaled)
	sb.content_margin_right = _dimi(12, scaled)
	sb.content_margin_top = _dimi(8, scaled)
	sb.content_margin_bottom = _dimi(8, scaled)
	sb.bg_color = Color(0.275, 0.251, 0.220, 0.88)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(ACStyle.TAN.r, ACStyle.TAN.g, ACStyle.TAN.b, 0.35)
	return sb


static func content_min_width(scaled: bool = true) -> float:
	return _dim(200, scaled)


static func outer_min_width(scaled: bool = true) -> float:
	return content_min_width(scaled) + float(_dimi(24, scaled))
