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


static func menu_toggle_stylebox(on: bool, hovered: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	if on:
		sb.bg_color = Color(SAGE.r, SAGE.g, SAGE.b, 0.88 if hovered else 0.62)
	else:
		sb.bg_color = HOVER if hovered else Color.TRANSPARENT
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


# ── Settings panel widgets ──

static func inset_panel_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var r := UiConfig.si(12)
	sb.bg_color = Color(0.935, 0.912, 0.862, 1.0)
	sb.corner_radius_top_left = r
	sb.corner_radius_top_right = r
	sb.corner_radius_bottom_left = r
	sb.corner_radius_bottom_right = r
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(TAN.r, TAN.g, TAN.b, 0.72)
	sb.content_margin_left = UiConfig.si(12)
	sb.content_margin_right = UiConfig.si(12)
	sb.content_margin_top = UiConfig.si(10)
	sb.content_margin_bottom = UiConfig.si(10)
	return sb


static func settings_row_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var r := UiConfig.si(10)
	sb.bg_color = Color(0.995, 0.988, 0.968, 1.0)
	sb.corner_radius_top_left = r
	sb.corner_radius_top_right = r
	sb.corner_radius_bottom_left = r
	sb.corner_radius_bottom_right = r
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(TAN.r, TAN.g, TAN.b, 0.48)
	sb.content_margin_left = UiConfig.si(10)
	sb.content_margin_right = UiConfig.si(10)
	sb.content_margin_top = UiConfig.si(8)
	sb.content_margin_bottom = UiConfig.si(8)
	return sb


static func tab_stylebox(active: bool, hovered: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var r := UiConfig.si(10)
	sb.corner_radius_top_left = r
	sb.corner_radius_top_right = r
	sb.corner_radius_bottom_left = r
	sb.corner_radius_bottom_right = r
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	if active:
		sb.bg_color = Color(SAGE.r, SAGE.g, SAGE.b, 0.22)
		sb.border_color = Color(SAGE.r, SAGE.g, SAGE.b, 0.72)
	elif hovered:
		sb.bg_color = HOVER
		sb.border_color = Color(TAN.r, TAN.g, TAN.b, 0.35)
	else:
		sb.bg_color = Color(1.0, 0.995, 0.978, 0.55)
		sb.border_color = Color(TAN.r, TAN.g, TAN.b, 0.28)
	return sb


static func field_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var r := UiConfig.si(8)
	sb.bg_color = Color(1.0, 0.998, 0.992, 1.0)
	sb.corner_radius_top_left = r
	sb.corner_radius_top_right = r
	sb.corner_radius_bottom_left = r
	sb.corner_radius_bottom_right = r
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(TAN.r, TAN.g, TAN.b, 0.62)
	sb.content_margin_left = UiConfig.si(8)
	sb.content_margin_right = UiConfig.si(8)
	sb.content_margin_top = UiConfig.si(4)
	sb.content_margin_bottom = UiConfig.si(4)
	return sb


static func icon_button_stylebox(hovered: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var r := UiConfig.si(8)
	sb.corner_radius_top_left = r
	sb.corner_radius_top_right = r
	sb.corner_radius_bottom_left = r
	sb.corner_radius_bottom_right = r
	sb.bg_color = HOVER if hovered else Color.TRANSPARENT
	return sb


static func divider_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(TAN.r, TAN.g, TAN.b, 0.35)
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	return sb


static func apply_vscroll_theme(bar: ScrollBar) -> void:
	var r := UiConfig.si(4)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(TAN.r, TAN.g, TAN.b, 0.28)
	track.corner_radius_top_left = r
	track.corner_radius_top_right = r
	track.corner_radius_bottom_left = r
	track.corner_radius_bottom_right = r
	track.content_margin_left = UiConfig.si(2)
	track.content_margin_right = UiConfig.si(2)

	var grabber := StyleBoxFlat.new()
	grabber.bg_color = BROWN
	grabber.corner_radius_top_left = r
	grabber.corner_radius_top_right = r
	grabber.corner_radius_bottom_left = r
	grabber.corner_radius_bottom_right = r

	var grabber_hi := grabber.duplicate() as StyleBoxFlat
	grabber_hi.bg_color = BROWN_LIGHT

	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)
	bar.add_theme_stylebox_override("grabber", grabber)
	bar.add_theme_stylebox_override("grabber_highlight", grabber_hi)
	bar.custom_minimum_size.x = UiConfig.s(8)


static func apply_scroll_container_theme(scroll: ScrollContainer) -> void:
	scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var bar := scroll.get_v_scroll_bar()
	if bar:
		apply_vscroll_theme(bar)


static func apply_slider_theme(slider: HSlider) -> void:
	slider.add_theme_constant_override("center_grabber", 1)
	var cr := UiConfig.si(4)
	var edge := UiConfig.si(6)
	var vpad := UiConfig.si(7)

	var track := StyleBoxFlat.new()
	track.bg_color = Color(TAN.r, TAN.g, TAN.b, 0.42)
	track.corner_radius_top_left = cr
	track.corner_radius_top_right = cr
	track.corner_radius_bottom_left = cr
	track.corner_radius_bottom_right = cr
	track.content_margin_left = edge
	track.content_margin_right = edge
	track.content_margin_top = vpad
	track.content_margin_bottom = vpad

	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = Color(SAGE.r, SAGE.g, SAGE.b, 0.78)

	var grabber := StyleBoxFlat.new()
	var gr := UiConfig.si(6)
	grabber.bg_color = SAGE
	grabber.corner_radius_top_left = gr
	grabber.corner_radius_top_right = gr
	grabber.corner_radius_bottom_left = gr
	grabber.corner_radius_bottom_right = gr
	grabber.set_content_margin_all(UiConfig.si(5))

	var grabber_hi := grabber.duplicate() as StyleBoxFlat
	grabber_hi.bg_color = PEACH

	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	slider.add_theme_stylebox_override("grabber", grabber)
	slider.add_theme_stylebox_override("grabber_highlight", grabber_hi)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var track_h := UiConfig.s(28)
	slider.custom_minimum_size = Vector2(0, track_h)
	if slider.get_parent() is Control:
		var host := slider.get_parent() as Control
		host.custom_minimum_size.y = track_h
		host.custom_minimum_size.x = 0


static func apply_option_button_theme(opt: OptionButton) -> void:
	var sb := field_stylebox()
	opt.add_theme_stylebox_override("normal", sb)
	opt.add_theme_stylebox_override("hover", sb.duplicate())
	opt.add_theme_stylebox_override("focus", sb.duplicate())
	opt.add_theme_stylebox_override("pressed", sb.duplicate())
	opt.add_theme_color_override("font_color", BROWN)
	opt.add_theme_font_size_override("font_size", UiConfig.si(13))
	opt.custom_minimum_size.y = UiConfig.s(30)


static func apply_line_edit_theme(edit: LineEdit) -> void:
	var sb := field_stylebox()
	edit.add_theme_stylebox_override("normal", sb)
	edit.add_theme_stylebox_override("focus", sb.duplicate())
	edit.add_theme_color_override("font_color", BROWN)
	edit.add_theme_color_override("font_placeholder_color", BROWN_LIGHT)
	edit.add_theme_font_size_override("font_size", UiConfig.si(13))
	edit.custom_minimum_size.y = UiConfig.s(30)


static func apply_text_edit_theme(edit: TextEdit) -> void:
	var sb := field_stylebox()
	sb.content_margin_left = UiConfig.si(10)
	sb.content_margin_right = UiConfig.si(10)
	sb.content_margin_top = UiConfig.si(8)
	sb.content_margin_bottom = UiConfig.si(8)
	edit.add_theme_stylebox_override("normal", sb)
	edit.add_theme_stylebox_override("focus", sb.duplicate())
	edit.add_theme_color_override("font_color", BROWN)
	edit.add_theme_color_override("font_placeholder_color", BROWN_LIGHT)
	edit.add_theme_font_size_override("font_size", UiConfig.si(12))
	var bar := edit.get_v_scroll_bar()
	if bar:
		apply_vscroll_theme(bar)


static func chat_send_button_stylebox(enabled: bool, hovered: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var r := UiConfig.si(8)
	sb.corner_radius_top_left = r
	sb.corner_radius_top_right = r
	sb.corner_radius_bottom_left = r
	sb.corner_radius_bottom_right = r
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	if enabled:
		sb.bg_color = Color(SAGE.r, SAGE.g, SAGE.b, 0.92 if hovered else 0.82)
		sb.border_color = Color(SAGE.r, SAGE.g, SAGE.b, 0.95)
	else:
		sb.bg_color = Color(TAN.r, TAN.g, TAN.b, 0.22 if hovered else 0.14)
		sb.border_color = Color(TAN.r, TAN.g, TAN.b, 0.38)
	return sb


static func save_button_stylebox(saved: bool, hovered: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var r := UiConfig.si(8)
	sb.corner_radius_top_left = r
	sb.corner_radius_top_right = r
	sb.corner_radius_bottom_left = r
	sb.corner_radius_bottom_right = r
	if saved:
		sb.bg_color = HOVER if hovered else Color(TAN.r, TAN.g, TAN.b, 0.28)
	else:
		sb.bg_color = Color(SAGE.r, SAGE.g, SAGE.b, 0.92 if hovered else 0.78)
	return sb


static func danger_button_stylebox(hovered: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var r := UiConfig.si(8)
	sb.corner_radius_top_left = r
	sb.corner_radius_top_right = r
	sb.corner_radius_bottom_left = r
	sb.corner_radius_bottom_right = r
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	var red := Color(0.82, 0.32, 0.28, 1.0)
	var red_hi := Color(0.90, 0.40, 0.34, 1.0)
	sb.bg_color = red_hi if hovered else red
	sb.border_color = Color(0.68, 0.22, 0.20, 0.85)
	return sb


static func apply_checkbox_theme(cb: CheckBox) -> void:
	cb.add_theme_color_override("font_color", BROWN)
	cb.add_theme_color_override("font_hover_color", BROWN)
	cb.add_theme_color_override("font_pressed_color", BROWN)
	cb.add_theme_font_size_override("font_size", UiConfig.si(13))
	cb.text = "开启"