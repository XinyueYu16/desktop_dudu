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
# 主操作绿 — 保存/添加等（#6fba2c，animal-island success 绿）
const AC_GREEN := Color(0.435, 0.729, 0.173, 1.0)        # #6fba2c
const AC_GREEN_HOVER := Color(0.494, 0.800, 0.220, 1.0)  # #7ecc38 hover
const AC_GREEN_DARK := Color(0.353, 0.620, 0.118, 1.0)   # #5a9e1e 描边
const DANGER_CORAL := Color(0.90, 0.55, 0.50, 1.0)

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
	var focus_sb := sb.duplicate()
	focus_sb.border_color = SAGE
	focus_sb.set_border_width_all(UiConfig.si(2))
	edit.add_theme_stylebox_override("focus", focus_sb)
	edit.add_theme_color_override("font_color", BROWN)
	edit.add_theme_color_override("font_placeholder_color", BROWN_LIGHT)
	edit.add_theme_color_override("caret_color", BROWN)
	edit.add_theme_color_override("selection_color", Color(SAGE.r, SAGE.g, SAGE.b, 0.35))
	edit.add_theme_font_size_override("font_size", UiConfig.si(13))
	edit.custom_minimum_size.y = UiConfig.s(30)
	edit.caret_blink = true


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


# 与 reminders_panel 卡片一致：accent α0.18, size 3, offset (0,2)
static func apply_soft_elevation_shadow(sb: StyleBoxFlat, tint: Color) -> void:
	sb.shadow_color = Color(tint.r, tint.g, tint.b, 0.18)
	sb.shadow_size = UiConfig.si(3)
	sb.shadow_offset = Vector2(0, UiConfig.s(2))


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
		sb.bg_color = AC_GREEN_HOVER if hovered else AC_GREEN
		sb.border_color = AC_GREEN_DARK
		apply_soft_elevation_shadow(sb, AC_GREEN)
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
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.content_margin_left = UiConfig.si(10)
	sb.content_margin_right = UiConfig.si(10)
	sb.content_margin_top = UiConfig.si(5)
	sb.content_margin_bottom = UiConfig.si(5)
	apply_soft_elevation_shadow(sb, AC_GREEN if not saved else AC_GREEN_DARK)
	if saved:
		sb.bg_color = Color(AC_GREEN.r, AC_GREEN.g, AC_GREEN.b, 0.48 if hovered else 0.34)
		sb.border_color = Color(AC_GREEN_DARK.r, AC_GREEN_DARK.g, AC_GREEN_DARK.b, 0.60)
	else:
		sb.bg_color = AC_GREEN_HOVER if hovered else AC_GREEN
		sb.border_color = AC_GREEN_DARK
	return sb


static func apply_footer_button_theme(btn: Button, saved: bool = false) -> void:
	btn.flat = false
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("normal", save_button_stylebox(saved))
	btn.add_theme_stylebox_override("hover", save_button_stylebox(saved, true))
	btn.add_theme_stylebox_override("pressed", save_button_stylebox(saved, true))
	btn.add_theme_stylebox_override("disabled", save_button_stylebox(saved))
	btn.add_theme_stylebox_override("focus", save_button_stylebox(saved))
	btn.add_theme_font_size_override("font_size", UiConfig.si(13))
	btn.custom_minimum_size = Vector2(UiConfig.s(88), UiConfig.s(32))
	var font := BROWN_LIGHT if saved else BROWN
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		btn.add_theme_color_override(key, font)


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
	sb.content_margin_left = UiConfig.si(10)
	sb.content_margin_right = UiConfig.si(10)
	sb.content_margin_top = UiConfig.si(5)
	sb.content_margin_bottom = UiConfig.si(5)
	var red := DANGER_CORAL
	var red_hi := Color(0.96, 0.62, 0.56, 1.0)
	sb.bg_color = red_hi if hovered else red
	sb.border_color = Color(0.72, 0.32, 0.28, 0.90)
	apply_soft_elevation_shadow(sb, red)
	return sb


static func apply_danger_button_theme(btn: Button, min_width: float = 160.0) -> void:
	btn.flat = false
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("normal", danger_button_stylebox(false))
	btn.add_theme_stylebox_override("hover", danger_button_stylebox(true))
	btn.add_theme_stylebox_override("pressed", danger_button_stylebox(true))
	btn.add_theme_stylebox_override("disabled", danger_button_stylebox(false))
	btn.add_theme_stylebox_override("focus", danger_button_stylebox(false))
	btn.add_theme_font_size_override("font_size", UiConfig.si(13))
	btn.custom_minimum_size = Vector2(UiConfig.s(min_width), UiConfig.s(32))
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		btn.add_theme_color_override(key, BROWN)


static func badge_stylebox(tint: Color = BROWN) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var r := UiConfig.si(8)
	sb.bg_color = Color(tint.r, tint.g, tint.b, 0.16)
	sb.border_color = Color(tint.r, tint.g, tint.b, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(r)
	sb.content_margin_left = UiConfig.si(8)
	sb.content_margin_right = UiConfig.si(8)
	sb.content_margin_top = UiConfig.si(3)
	sb.content_margin_bottom = UiConfig.si(3)
	return sb


static func spinbox_updown_stylebox(hovered: bool = false, pressed: bool = false) -> StyleBoxFlat:
	var sb := badge_stylebox(BROWN).duplicate() as StyleBoxFlat
	sb.set_corner_radius_all(UiConfig.si(6))
	sb.content_margin_left = UiConfig.si(2)
	sb.content_margin_right = UiConfig.si(2)
	sb.content_margin_top = UiConfig.si(2)
	sb.content_margin_bottom = UiConfig.si(2)
	if pressed:
		sb.bg_color = Color(BROWN.r, BROWN.g, BROWN.b, 0.28)
	elif hovered:
		sb.bg_color = Color(BROWN.r, BROWN.g, BROWN.b, 0.22)
	return sb


static func apply_spinbox_theme(spin: SpinBox) -> void:
	var field := field_stylebox()
	spin.add_theme_stylebox_override("updown", spinbox_updown_stylebox())
	spin.add_theme_stylebox_override("updown_hover", spinbox_updown_stylebox(true))
	spin.add_theme_stylebox_override("updown_pressed", spinbox_updown_stylebox(false, true))
	spin.add_theme_color_override("font_color", BROWN)
	spin.add_theme_color_override("font_hover_color", BROWN)
	spin.add_theme_color_override("font_pressed_color", BROWN)
	spin.add_theme_color_override("icon_normal_color", BROWN)
	spin.add_theme_color_override("icon_hover_color", BROWN)
	spin.add_theme_color_override("icon_pressed_color", BROWN)
	spin.add_theme_font_size_override("font_size", UiConfig.si(12))
	spin.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var edit := spin.get_line_edit()
	if edit:
		edit.add_theme_stylebox_override("normal", field)
		edit.add_theme_stylebox_override("focus", field.duplicate())
		edit.add_theme_color_override("font_color", BROWN)
		edit.add_theme_font_size_override("font_size", UiConfig.si(12))
		edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		edit.add_theme_constant_override("minimum_character_width", 3)


static func _checkbox_icon(checked: bool, disabled: bool = false) -> ImageTexture:
	var sz := maxi(UiConfig.si(20), 14)
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var pad := UiConfig.si(2)
	var rect := Rect2i(pad, pad, sz - pad * 2, sz - pad * 2)
	var radius := UiConfig.si(4)
	var alpha := 0.42 if disabled else 1.0
	var fill := Color(SAGE.r, SAGE.g, SAGE.b, 0.88 * alpha) if checked else Color(1.0, 0.998, 0.992, alpha)
	var border := Color(SAGE.r * 0.72, SAGE.g * 0.72, SAGE.b * 0.72, alpha) if checked else Color(TAN.r, TAN.g, TAN.b, alpha)
	_paint_round_rect(img, rect, radius, fill, border, 1)
	if checked:
		var mark := Color(BROWN.r, BROWN.g, BROWN.b, alpha)
		_paint_check_mark(img, mark, sz)
	return ImageTexture.create_from_image(img)


static func _paint_round_rect(img: Image, rect: Rect2i, radius: int, fill: Color, border: Color, border_w: int) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if not _inside_round_rect(x, y, rect, radius):
				continue
			var on_border := (
				x < rect.position.x + border_w
				or x >= rect.position.x + rect.size.x - border_w
				or y < rect.position.y + border_w
				or y >= rect.position.y + rect.size.y - border_w
			)
			img.set_pixel(x, y, border if on_border else fill)


static func _inside_round_rect(x: int, y: int, rect: Rect2i, radius: int) -> bool:
	if x < rect.position.x or y < rect.position.y:
		return false
	if x >= rect.position.x + rect.size.x or y >= rect.position.y + rect.size.y:
		return false
	var rx := rect.position.x
	var ry := rect.position.y
	var rw := rect.size.x
	var rh := rect.size.y
	var r := mini(radius, mini(rw, rh) / 2)
	if x < rx + r and y < ry + r:
		return Vector2(x - (rx + r), y - (ry + r)).length_squared() <= r * r
	if x >= rx + rw - r and y < ry + r:
		return Vector2(x - (rx + rw - r - 1), y - (ry + r)).length_squared() <= r * r
	if x < rx + r and y >= ry + rh - r:
		return Vector2(x - (rx + r), y - (ry + rh - r - 1)).length_squared() <= r * r
	if x >= rx + rw - r and y >= ry + rh - r:
		return Vector2(x - (rx + rw - r - 1), y - (ry + rh - r - 1)).length_squared() <= r * r
	return true


static func _paint_check_mark(img: Image, color: Color, sz: int) -> void:
	var x0 := int(sz * 0.24)
	var y0 := int(sz * 0.52)
	var x1 := int(sz * 0.42)
	var y1 := int(sz * 0.68)
	var x2 := int(sz * 0.76)
	var y2 := int(sz * 0.30)
	_draw_thick_line(img, Vector2i(x0, y0), Vector2i(x1, y1), color, 2)
	_draw_thick_line(img, Vector2i(x1, y1), Vector2i(x2, y2), color, 2)


static func _draw_thick_line(img: Image, from: Vector2i, to: Vector2i, color: Color, thickness: int) -> void:
	var delta := to - from
	var steps := maxi(absi(delta.x), absi(delta.y))
	if steps == 0:
		img.set_pixel(from.x, from.y, color)
		return
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var px := int(roundi(lerpf(float(from.x), float(to.x), t)))
		var py := int(roundi(lerpf(float(from.y), float(to.y), t)))
		for ox in range(-thickness, thickness + 1):
			for oy in range(-thickness, thickness + 1):
				var sx := px + ox
				var sy := py + oy
				if sx >= 0 and sy >= 0 and sx < img.get_width() and sy < img.get_height():
					img.set_pixel(sx, sy, color)


static func apply_checkbox_theme(cb: CheckBox, label: String = "开启") -> void:
	cb.add_theme_color_override("font_color", BROWN)
	cb.add_theme_color_override("font_hover_color", BROWN)
	cb.add_theme_color_override("font_pressed_color", BROWN)
	cb.add_theme_color_override("font_disabled_color", BROWN_LIGHT)
	cb.add_theme_font_size_override("font_size", UiConfig.si(13))
	cb.add_theme_constant_override("h_separation", UiConfig.si(6))
	cb.add_theme_icon_override("checked", _checkbox_icon(true))
	cb.add_theme_icon_override("unchecked", _checkbox_icon(false))
	cb.add_theme_icon_override("checked_disabled", _checkbox_icon(true, true))
	cb.add_theme_icon_override("unchecked_disabled", _checkbox_icon(false, true))
	cb.text = label
	if label == "完成":
		cb.tooltip_text = "勾选表示此项已完成"