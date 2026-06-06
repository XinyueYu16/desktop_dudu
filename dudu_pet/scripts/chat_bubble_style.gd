class_name ChatBubbleStyle
extends RefCounted

# Shared chat bubble look — used by magic diary, floating bubbles, and speech bubble.


static func make_stylebox(role: String) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12 if role == "user" else 4
	sb.corner_radius_bottom_right = 4 if role == "user" else 12
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	if role == "user":
		sb.bg_color = Color(0.25, 0.45, 0.75, 0.8)
	else:
		sb.bg_color = Color(0.22, 0.22, 0.28, 0.75)
	return sb


static func font_color(role: String) -> Color:
	if role == "user":
		return Color(1, 1, 1, 1)
	return Color(0.9, 0.9, 1, 1)


static func apply_to_panel(panel: PanelContainer, label: Label, role: String) -> void:
	panel.add_theme_stylebox_override("panel", make_stylebox(role))
	label.add_theme_color_override("font_color", font_color(role))
	label.add_theme_font_size_override("font_size", 14)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
