class_name RemindersPanel
extends Control

signal save_requested(items: Array)
signal close_requested

const BASE_SIZE := Vector2(400, 440)
const MAX_ITEMS := 5
const REMINDER_INTERVALS := [15, 30, 45, 50, 60, 90, 120]
const CST_OFFSET_SEC := 8 * 3600

const _TITLE_RECT := Vector4(12, 10, 388, 44)
const _CONTENT_SCROLL_RECT := Vector4(12, 52, 388, 388)
const _FOOTER_RECT := Vector4(12, 394, 388, 430)

const _ROW_THEMES := {
	"water": {
		"bg": Color(0.82, 0.92, 0.98, 1.0),
		"accent": Color(0.45, 0.72, 0.90, 1.0),
		"badge": Color(0.35, 0.58, 0.78, 1.0),
	},
	"stretch": {
		"bg": Color(0.84, 0.96, 0.88, 1.0),
		"accent": Color(0.48, 0.72, 0.55, 1.0),
		"badge": Color(0.32, 0.55, 0.42, 1.0),
	},
}

const _FALLBACK_THEMES: Array = [
	{
		"bg": Color(0.98, 0.90, 0.82, 1.0),
		"accent": Color(0.90, 0.68, 0.48, 1.0),
		"badge": Color(0.72, 0.48, 0.32, 1.0),
	},
	{
		"bg": Color(0.94, 0.88, 0.98, 1.0),
		"accent": Color(0.72, 0.58, 0.88, 1.0),
		"badge": Color(0.52, 0.38, 0.68, 1.0),
	},
	{
		"bg": Color(0.98, 0.94, 0.84, 1.0),
		"accent": Color(0.88, 0.76, 0.52, 1.0),
		"badge": Color(0.62, 0.50, 0.28, 1.0),
	},
]

@onready var panel_bg: Panel = $PanelBg
@onready var title_bar: MarginContainer = $PanelBg/TitleBar
@onready var title_label: Label = $PanelBg/TitleBar/TitleHBox/TitleLabel
@onready var close_btn: Button = $PanelBg/TitleBar/TitleHBox/CloseBtn

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _scroll: ScrollContainer = null
var _list: VBoxContainer = null
var _footer: HBoxContainer = null
var _save_btn: Button = null
var _add_btn: Button = null
var _hint_panel: PanelContainer = null
var _items: Array = []
var _dirty: bool = false
var _populating: bool = false
var _row_controls: Array = []
var _next_labels: Array = []


func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_STOP
	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	title_bar.gui_input.connect(_on_title_bar_input)
	close_btn.pressed.connect(func(): close_requested.emit(); hide())
	_build_body()
	apply_ui_scale()


func apply_ui_scale() -> void:
	scale = Vector2.ONE
	var w := UiConfig.si(int(BASE_SIZE.x))
	var h := UiConfig.si(int(BASE_SIZE.y))
	custom_minimum_size = Vector2(w, h)
	size = Vector2(w, h)
	_layout_chrome()
	_apply_style()
	_sync_list_width()


func visual_size() -> Vector2:
	return size


func _layout_chrome() -> void:
	_place_rect(title_bar, _TITLE_RECT)
	if _scroll:
		_place_rect(_scroll, _CONTENT_SCROLL_RECT)
	if _footer:
		_place_rect(_footer, _FOOTER_RECT)


func _place_rect(node: Control, rect: Vector4) -> void:
	node.offset_left = UiConfig.s(rect.x)
	node.offset_top = UiConfig.s(rect.y)
	node.offset_right = UiConfig.s(rect.z)
	node.offset_bottom = UiConfig.s(rect.w)


func _sync_list_width() -> void:
	if _list:
		_list.custom_minimum_size.x = _content_scroll_width()


func _content_scroll_width() -> float:
	return UiConfig.s(_CONTENT_SCROLL_RECT.z - _CONTENT_SCROLL_RECT.x)


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
	close_btn.add_theme_font_size_override("font_size", UiConfig.si(16))
	close_btn.custom_minimum_size = Vector2(UiConfig.s(28), UiConfig.s(28))
	if _hint_panel:
		_style_hint_panel()
	if _save_btn:
		_style_save_button(not _dirty)
	if _add_btn:
		_style_add_button()
	if _scroll:
		ACStyle.apply_scroll_container_theme(_scroll)


func _style_hint_panel() -> void:
	var sb := StyleBoxFlat.new()
	var r := UiConfig.si(10)
	sb.bg_color = Color(ACStyle.HOVER.r, ACStyle.HOVER.g, ACStyle.HOVER.b, 0.55)
	sb.corner_radius_top_left = r
	sb.corner_radius_top_right = r
	sb.corner_radius_bottom_left = r
	sb.corner_radius_bottom_right = r
	sb.content_margin_left = UiConfig.si(10)
	sb.content_margin_right = UiConfig.si(10)
	sb.content_margin_top = UiConfig.si(6)
	sb.content_margin_bottom = UiConfig.si(6)
	_hint_panel.add_theme_stylebox_override("panel", sb)


func _build_body() -> void:
	_scroll = ScrollContainer.new()
	_scroll.name = "ContentScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.follow_focus = true
	panel_bg.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", UiConfig.si(12))
	_scroll.add_child(_list)

	_hint_panel = PanelContainer.new()
	var hint_lbl := Label.new()
	hint_lbl.text = "到点会弹气泡，记得点「知道了」"
	hint_lbl.add_theme_color_override("font_color", ACStyle.BROWN_LIGHT)
	hint_lbl.add_theme_font_size_override("font_size", UiConfig.si(12))
	_hint_panel.add_child(hint_lbl)
	_list.add_child(_hint_panel)

	_footer = HBoxContainer.new()
	_footer.name = "Footer"
	_footer.alignment = BoxContainer.ALIGNMENT_END
	_footer.add_theme_constant_override("separation", UiConfig.si(8))
	panel_bg.add_child(_footer)

	_add_btn = Button.new()
	_add_btn.text = "+ 添加"
	_add_btn.pressed.connect(_on_add_pressed)
	_footer.add_child(_add_btn)

	_save_btn = Button.new()
	_save_btn.text = "已保存 ✓"
	_save_btn.disabled = true
	_save_btn.pressed.connect(_flush_save)
	_footer.add_child(_save_btn)

	_style_add_button()
	_style_save_button(true)
	_layout_chrome()


func _style_save_button(saved: bool) -> void:
	if not _save_btn:
		return
	ACStyle.apply_footer_button_theme(_save_btn, saved)
	_save_btn.text = "已保存 ✓" if saved else "保存"
	_save_btn.disabled = saved


func _style_add_button() -> void:
	if not _add_btn:
		return
	var at_limit := _items.size() >= MAX_ITEMS
	ACStyle.apply_footer_button_theme(_add_btn, at_limit)
	_add_btn.disabled = at_limit


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
	call_deferred("_layout_chrome")


func is_dragging_title() -> bool:
	return _dragging


func populate(items: Array) -> void:
	_populating = true
	_items = items.duplicate(true)
	_dirty = false
	_rebuild_rows()
	_populating = false
	mark_saved()


func mark_saved() -> void:
	_dirty = false
	_apply_style()


func mark_save_failed() -> void:
	_dirty = true
	_apply_style()


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


func _rebuild_rows() -> void:
	for c in _list.get_children():
		if c == _hint_panel:
			continue
		c.queue_free()
	_row_controls.clear()
	_next_labels.clear()
	for i in range(_items.size()):
		_list.add_child(_build_row(i))
	_style_add_button()
	call_deferred("_sync_list_width")


func _row_theme(item: Dictionary, index: int) -> Dictionary:
	var rid := str(item.get("id", ""))
	if _ROW_THEMES.has(rid):
		return _ROW_THEMES[rid]
	return _FALLBACK_THEMES[index % _FALLBACK_THEMES.size()]


func _card_stylebox(theme: Dictionary) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var r := UiConfig.si(12)
	sb.bg_color = theme["bg"]
	sb.border_color = theme["accent"]
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = r
	sb.corner_radius_top_right = r
	sb.corner_radius_bottom_left = r
	sb.corner_radius_bottom_right = r
	sb.content_margin_left = UiConfig.si(10)
	sb.content_margin_right = UiConfig.si(10)
	sb.content_margin_top = UiConfig.si(8)
	sb.content_margin_bottom = UiConfig.si(8)
	ACStyle.apply_soft_elevation_shadow(sb, theme["accent"])
	return sb


func _time_badge_stylebox(theme: Dictionary) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var r := UiConfig.si(8)
	sb.bg_color = Color(theme["badge"].r, theme["badge"].g, theme["badge"].b, 0.16)
	sb.border_color = Color(theme["badge"].r, theme["badge"].g, theme["badge"].b, 0.35)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = r
	sb.corner_radius_top_right = r
	sb.corner_radius_bottom_left = r
	sb.corner_radius_bottom_right = r
	sb.content_margin_left = UiConfig.si(8)
	sb.content_margin_right = UiConfig.si(8)
	sb.content_margin_top = UiConfig.si(3)
	sb.content_margin_bottom = UiConfig.si(3)
	return sb


func _build_row(index: int) -> PanelContainer:
	var item: Dictionary = _items[index]
	var theme := _row_theme(item, index)
	var enabled := bool(item.get("enabled", true))

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _card_stylebox(theme))
	card.modulate = Color(1, 1, 1, 1.0 if enabled else 0.55)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", UiConfig.si(8))
	card.add_child(body)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiConfig.si(8))

	var cb := CheckBox.new()
	cb.set_pressed_no_signal(enabled)
	ACStyle.apply_checkbox_theme(cb)
	cb.text = ""
	cb.toggled.connect(func(on: bool): _on_row_changed(index, "enabled", on))
	row.add_child(cb)

	var label_edit := LineEdit.new()
	label_edit.text = str(item.get("label", "提醒"))
	label_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_edit.custom_minimum_size = Vector2(UiConfig.s(80), 0)
	ACStyle.apply_line_edit_theme(label_edit)
	label_edit.text_changed.connect(func(t: String): _on_row_changed(index, "label", t))
	row.add_child(label_edit)

	var every_lbl := Label.new()
	every_lbl.text = "每"
	every_lbl.add_theme_color_override("font_color", theme["badge"])
	every_lbl.add_theme_font_size_override("font_size", UiConfig.si(13))
	row.add_child(every_lbl)

	var interval_opt := OptionButton.new()
	interval_opt.custom_minimum_size = Vector2(UiConfig.s(88), 0)
	for v in REMINDER_INTERVALS:
		interval_opt.add_item("%d分钟" % v)
	var interval := int(item.get("interval_minutes", 60))
	var idx := REMINDER_INTERVALS.find(interval)
	if idx < 0:
		idx = REMINDER_INTERVALS.find(60)
	ACStyle.apply_option_button_theme(interval_opt)
	interval_opt.select(max(idx, 0))
	interval_opt.item_selected.connect(func(sel: int):
		_on_row_changed(index, "interval_minutes", REMINDER_INTERVALS[sel])
	)
	row.add_child(interval_opt)

	var del_btn := Button.new()
	del_btn.text = "删除"
	ACStyle.apply_danger_button_theme(del_btn, 52.0)
	del_btn.pressed.connect(func(): _on_delete_row(index))
	row.add_child(del_btn)
	body.add_child(row)

	var meta_row := HBoxContainer.new()
	meta_row.add_theme_constant_override("separation", UiConfig.si(6))

	var meta_hint := Label.new()
	meta_hint.text = "东八区"
	meta_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_hint.add_theme_color_override("font_color", Color(theme["badge"].r, theme["badge"].g, theme["badge"].b, 0.65))
	meta_hint.add_theme_font_size_override("font_size", UiConfig.si(11))
	meta_row.add_child(meta_hint)

	var time_wrap := PanelContainer.new()
	time_wrap.add_theme_stylebox_override("panel", _time_badge_stylebox(theme))
	var next_lbl := Label.new()
	next_lbl.add_theme_color_override("font_color", theme["badge"])
	next_lbl.add_theme_font_size_override("font_size", UiConfig.si(12))
	next_lbl.text = _format_next_at(item)
	time_wrap.add_child(next_lbl)
	meta_row.add_child(time_wrap)
	body.add_child(meta_row)

	_row_controls.append({
		"enabled": cb,
		"label": label_edit,
		"interval": interval_opt,
		"delete": del_btn,
		"card": card,
	})
	_next_labels.append(next_lbl)
	return card


func _format_cst_clock(unix_ts: int) -> String:
	# Fixed UTC+8 — Godot 4.6 API has no use_utc flag on this helper.
	var sod := (unix_ts + CST_OFFSET_SEC) % 86400
	if sod < 0:
		sod += 86400
	var h := sod / 3600
	var m := (sod % 3600) / 60
	return "%02d:%02d" % [h, m]


func _format_next_at(item: Dictionary) -> String:
	if not bool(item.get("enabled", true)):
		return "已关闭"
	if _dirty:
		var mins := int(item.get("interval_minutes", 60))
		var preview_ts := int(Time.get_unix_time_from_system()) + mins * 60
		return "约 %s" % _format_cst_clock(preview_ts)
	var raw = item.get("next_at")
	if raw == null:
		return "保存后生效"
	var ts := int(float(raw))
	if ts <= 0:
		return "保存后生效"
	return _format_cst_clock(ts)


func _refresh_next_labels() -> void:
	for i in range(min(_items.size(), _next_labels.size())):
		_next_labels[i].text = _format_next_at(_items[i])
	for i in range(min(_items.size(), _row_controls.size())):
		var enabled := bool(_items[i].get("enabled", true))
		var row_ctrl: Dictionary = _row_controls[i]
		var card = row_ctrl.get("card") as PanelContainer
		if card:
			card.modulate = Color(1, 1, 1, 1.0 if enabled else 0.55)


func _on_row_changed(index: int, field: String, value: Variant) -> void:
	if _populating:
		return
	if index < 0 or index >= _items.size():
		return
	_items[index][field] = value
	if field == "enabled" or field == "interval_minutes":
		_refresh_next_labels()
	_mark_dirty()


func _on_delete_row(index: int) -> void:
	if index < 0 or index >= _items.size():
		return
	_items.remove_at(index)
	_mark_dirty()
	_rebuild_rows()


func _on_add_pressed() -> void:
	if _items.size() >= MAX_ITEMS:
		return
	_items.append({
		"id": "reminder_%d" % Time.get_ticks_msec(),
		"label": "新提醒",
		"interval_minutes": 60,
		"enabled": true,
		"animation": "happy",
		"bubble_text": "嘟嘟提醒你一下喵~",
	})
	_mark_dirty()
	_rebuild_rows()


func _mark_dirty() -> void:
	_dirty = true
	_apply_style()


func _flush_save() -> void:
	save_requested.emit(_items.duplicate(true))
