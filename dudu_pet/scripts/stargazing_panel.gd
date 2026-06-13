class_name StargazingPanel
extends Control

signal refresh_requested()
signal location_save_requested(city: String, latitude: float, longitude: float)
signal close_requested

const BASE_SIZE := Vector2(420, 520)
const CHART_FILENAME := "chart_latest.png"
const CHART_PREVIEW_PX := 340.0
const LIGHTBOX_SCALE := 1.5

const _TITLE_RECT := Vector4(12, 10, 408, 44)
const _CONTENT_RECT := Vector4(12, 52, 408, 510)

@onready var panel_bg: Panel = $PanelBg
@onready var title_bar: MarginContainer = $PanelBg/TitleBar
@onready var title_label: Label = $PanelBg/TitleBar/TitleHBox/TitleLabel
@onready var close_btn: Button = $PanelBg/TitleBar/TitleHBox/CloseBtn

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _loading: bool = false
var _scroll: ScrollContainer = null
var _body: VBoxContainer = null
var _hint_lbl: Label = null
var _zoom_hint_lbl: Label = null
var _city_edit: LineEdit = null
var _lat_edit: LineEdit = null
var _lon_edit: LineEdit = null
var _time_lbl: Label = null
var _asc_lbl: Label = null
var _chart_img: TextureRect = null
var _save_loc_btn: Button = null
var _refresh_btn: Button = null
var _lightbox_layer: CanvasLayer = null
var _lightbox_root: Control = null
var _lightbox_tex: TextureRect = null


func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_STOP
	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	title_bar.gui_input.connect(_on_title_bar_input)
	close_btn.pressed.connect(_on_close_pressed)
	title_label.text = "✨ 观星台"
	_build_body()
	_build_lightbox()
	apply_ui_scale()


func apply_ui_scale() -> void:
	scale = Vector2.ONE
	var w := UiConfig.si(int(BASE_SIZE.x))
	var h := UiConfig.si(int(BASE_SIZE.y))
	custom_minimum_size = Vector2(w, h)
	size = Vector2(w, h)
	_layout_chrome()
	_apply_style()
	if _chart_img:
		var side := UiConfig.s(CHART_PREVIEW_PX)
		_chart_img.custom_minimum_size = Vector2(side, side)


func visual_size() -> Vector2:
	return size


func is_loading() -> bool:
	return _loading


func is_lightbox_open() -> bool:
	return _lightbox_layer != null and _lightbox_layer.visible


func set_loading(loading: bool) -> void:
	_loading = loading
	if _refresh_btn:
		_refresh_btn.disabled = loading
	if loading:
		_time_lbl.text = "生成中…"
		_asc_lbl.text = "请稍候"
		_set_zoom_hint_visible(false)


func show_error(message: String) -> void:
	_loading = false
	if _refresh_btn:
		_refresh_btn.disabled = false
	_time_lbl.text = "星盘生成失败"
	_asc_lbl.text = message
	if _chart_img:
		_chart_img.texture = null
	_set_zoom_hint_visible(false)


func _layout_chrome() -> void:
	_place_rect(title_bar, _TITLE_RECT)
	if _scroll:
		_place_rect(_scroll, _CONTENT_RECT)


func _place_rect(node: Control, rect: Vector4) -> void:
	node.offset_left = UiConfig.s(rect.x)
	node.offset_top = UiConfig.s(rect.y)
	node.offset_right = UiConfig.s(rect.z)
	node.offset_bottom = UiConfig.s(rect.w)


func _apply_style() -> void:
	var panel_sb := ACStyle.panel_card_stylebox()
	panel_sb.bg_color = Color(ACStyle.CREAM.r, ACStyle.CREAM.g, ACStyle.CREAM.b, 0.98)
	panel_bg.add_theme_stylebox_override("panel", panel_sb)
	title_label.add_theme_color_override("font_color", ACStyle.BROWN)
	title_label.add_theme_font_size_override("font_size", UiConfig.si(15))
	close_btn.flat = true
	close_btn.add_theme_stylebox_override("normal", ACStyle.icon_button_stylebox())
	close_btn.add_theme_stylebox_override("hover", ACStyle.icon_button_stylebox(true))
	close_btn.add_theme_stylebox_override("pressed", ACStyle.icon_button_stylebox(true))
	close_btn.add_theme_color_override("font_color", ACStyle.BROWN_LIGHT)
	close_btn.custom_minimum_size = Vector2(UiConfig.s(28), UiConfig.s(28))
	for edit in [_city_edit, _lat_edit, _lon_edit]:
		if edit:
			ACStyle.apply_line_edit_theme(edit)
	for btn in [_save_loc_btn, _refresh_btn]:
		if btn:
			ACStyle.apply_footer_button_theme(btn, false)
	if _scroll:
		ACStyle.apply_scroll_container_theme(_scroll)
	if _hint_lbl:
		_hint_lbl.add_theme_color_override("font_color", ACStyle.BROWN_LIGHT)
	if _zoom_hint_lbl:
		_zoom_hint_lbl.add_theme_color_override("font_color", ACStyle.BROWN_LIGHT)
	if _time_lbl:
		_time_lbl.add_theme_color_override("font_color", ACStyle.BROWN)
	if _asc_lbl:
		_asc_lbl.add_theme_color_override("font_color", ACStyle.SAGE)


func _build_body() -> void:
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel_bg.add_child(_scroll)

	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", UiConfig.si(10))
	_scroll.add_child(_body)

	_hint_lbl = Label.new()
	_hint_lbl.text = "当前时间 + 地理位置的天象盘（Alcabitus）"
	_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_lbl.add_theme_font_size_override("font_size", UiConfig.si(11))
	_body.add_child(_hint_lbl)

	_time_lbl = Label.new()
	_time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_lbl.add_theme_font_size_override("font_size", UiConfig.si(12))
	_body.add_child(_time_lbl)

	_asc_lbl = Label.new()
	_asc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_asc_lbl.add_theme_font_size_override("font_size", UiConfig.si(13))
	_body.add_child(_asc_lbl)

	_chart_img = TextureRect.new()
	_chart_img.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_chart_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_chart_img.custom_minimum_size = Vector2(CHART_PREVIEW_PX, CHART_PREVIEW_PX)
	_chart_img.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_chart_img.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chart_img.mouse_filter = Control.MOUSE_FILTER_STOP
	_chart_img.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_chart_img.gui_input.connect(_on_chart_img_input)
	_body.add_child(_chart_img)

	_zoom_hint_lbl = Label.new()
	_zoom_hint_lbl.text = "点击星盘放大"
	_zoom_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zoom_hint_lbl.add_theme_font_size_override("font_size", UiConfig.si(10))
	_zoom_hint_lbl.hide()
	_body.add_child(_zoom_hint_lbl)

	var loc_row := HBoxContainer.new()
	loc_row.add_theme_constant_override("separation", UiConfig.si(6))
	_body.add_child(loc_row)
	_city_edit = LineEdit.new()
	_city_edit.placeholder_text = "城市"
	_city_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loc_row.add_child(_city_edit)
	_lat_edit = LineEdit.new()
	_lat_edit.placeholder_text = "纬度"
	_lat_edit.custom_minimum_size = Vector2(UiConfig.s(70), 0)
	loc_row.add_child(_lat_edit)
	_lon_edit = LineEdit.new()
	_lon_edit.placeholder_text = "经度"
	_lon_edit.custom_minimum_size = Vector2(UiConfig.s(70), 0)
	loc_row.add_child(_lon_edit)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", UiConfig.si(8))
	_body.add_child(btn_row)
	_save_loc_btn = Button.new()
	_save_loc_btn.text = "保存位置"
	_save_loc_btn.pressed.connect(_on_save_location)
	btn_row.add_child(_save_loc_btn)
	_refresh_btn = Button.new()
	_refresh_btn.text = "刷新星盘"
	_refresh_btn.pressed.connect(func(): refresh_requested.emit())
	btn_row.add_child(_refresh_btn)

	_layout_chrome()


func _build_lightbox() -> void:
	_lightbox_layer = CanvasLayer.new()
	_lightbox_layer.layer = 60
	_lightbox_layer.hide()
	add_child(_lightbox_layer)

	_lightbox_root = Control.new()
	_lightbox_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lightbox_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_lightbox_root.gui_input.connect(_on_lightbox_input)
	_lightbox_layer.add_child(_lightbox_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.08, 0.06, 0.05, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lightbox_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lightbox_root.add_child(center)

	_lightbox_tex = TextureRect.new()
	_lightbox_tex.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	_lightbox_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_lightbox_tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	center.add_child(_lightbox_tex)

	var close_hint := Label.new()
	close_hint.text = "点击任意处关闭"
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	close_hint.offset_top = -UiConfig.s(36)
	close_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.88))
	close_hint.add_theme_font_size_override("font_size", UiConfig.si(12))
	_lightbox_root.add_child(close_hint)


func open(near_position: Vector2) -> void:
	apply_ui_scale()
	var view_size := get_viewport().get_visible_rect().size
	var vs := visual_size()
	position.x = near_position.x + UiConfig.s(100)
	position.y = near_position.y - vs.y / 2.0
	if position.x + vs.x > view_size.x:
		position.x = near_position.x - vs.x - UiConfig.s(20)
	position.y = clampf(position.y, 0, view_size.y - vs.y)
	show()
	refresh_requested.emit()


func close_panel() -> void:
	_close_chart_lightbox()
	hide()


func _on_close_pressed() -> void:
	close_requested.emit()
	close_panel()


func is_dragging_title() -> bool:
	return _dragging


func populate_location(settings: Dictionary) -> void:
	var sg: Variant = settings.get("stargazing", {})
	if not sg is Dictionary:
		return
	_city_edit.text = str(sg.get("city", "上海"))
	_lat_edit.text = str(sg.get("latitude", 31.2304))
	_lon_edit.text = str(sg.get("longitude", 121.4737))


func show_chart(payload: Dictionary) -> void:
	_loading = false
	if _refresh_btn:
		_refresh_btn.disabled = false

	if payload.has("error"):
		show_error(str(payload.get("error", "未知错误")))
		return

	var city := str(payload.get("city", ""))
	var at := str(payload.get("observed_at", ""))
	_time_lbl.text = "%s · %s" % [city, at] if not city.is_empty() else at

	var asc: Variant = payload.get("ascendant", {})
	if asc is Dictionary:
		_asc_lbl.text = "上升 %s %.1f°" % [str(asc.get("sign_zh", "")), float(asc.get("degree", 0))]
	else:
		_asc_lbl.text = ""

	var filename := str(payload.get("image_file", CHART_FILENAME))
	var path := _chart_file_path(filename)
	if not FileAccess.file_exists(path):
		show_error("找不到星盘图片：%s" % filename)
		return

	var img := Image.new()
	if img.load(path) != OK:
		show_error("星盘图片加载失败")
		return
	_chart_img.texture = ImageTexture.create_from_image(img)
	_set_zoom_hint_visible(true)


func _set_zoom_hint_visible(visible: bool) -> void:
	if _zoom_hint_lbl:
		_zoom_hint_lbl.visible = visible


func _chart_file_path(filename: String) -> String:
	var project_dir := ProjectSettings.globalize_path("res://")
	return project_dir.path_join("../backend/data").path_join(filename)


func _on_chart_img_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _chart_img.texture != null:
			_open_chart_lightbox()
			get_viewport().set_input_as_handled()


func _open_chart_lightbox() -> void:
	if _chart_img.texture == null or _lightbox_layer == null:
		return
	_lightbox_tex.texture = _chart_img.texture
	var side := UiConfig.s(CHART_PREVIEW_PX) * LIGHTBOX_SCALE
	_lightbox_tex.custom_minimum_size = Vector2(side, side)
	_lightbox_layer.show()


func _close_chart_lightbox() -> void:
	if _lightbox_layer:
		_lightbox_layer.hide()


func _on_lightbox_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_chart_lightbox()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close_chart_lightbox()
		get_viewport().set_input_as_handled()


func _on_save_location() -> void:
	var lat := float(_lat_edit.text) if _lat_edit.text.is_valid_float() else 31.2304
	var lon := float(_lon_edit.text) if _lon_edit.text.is_valid_float() else 121.4737
	location_save_requested.emit(_city_edit.text.strip_edges(), lat, lon)


func _on_title_bar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if close_btn.get_global_rect().has_point(event.global_position):
				return
			_dragging = true
			_drag_offset = get_global_mouse_position() - global_position
			get_viewport().set_input_as_handled()
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		global_position = get_global_mouse_position() - _drag_offset
		get_viewport().set_input_as_handled()
