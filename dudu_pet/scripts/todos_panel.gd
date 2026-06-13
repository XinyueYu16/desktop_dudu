class_name TodosPanel
extends Control

signal save_requested(items: Array)
signal close_requested

const BASE_SIZE := Vector2(400, 480)
const CST_OFFSET_SEC := 8 * 3600
const REMIND_PLACEHOLDER := "2026/06/13 18:00"

const _TITLE_RECT := Vector4(12, 10, 388, 44)
const _CONTENT_SCROLL_RECT := Vector4(12, 52, 388, 428)
const _FOOTER_RECT := Vector4(12, 434, 388, 470)

const _ROW_THEME := {
	"bg": Color(0.96, 0.94, 0.90, 1.0),
	"accent": Color(0.88, 0.76, 0.52, 1.0),
	"badge": Color(0.62, 0.50, 0.28, 1.0),
}

@onready var panel_bg: Panel = $PanelBg
@onready var title_bar: MarginContainer = $PanelBg/TitleBar
@onready var title_label: Label = $PanelBg/TitleBar/TitleHBox/TitleLabel
@onready var close_btn: Button = $PanelBg/TitleBar/TitleHBox/CloseBtn

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _scroll: ScrollContainer = null
var _list: VBoxContainer = null
var _footer: HBoxContainer = null
var _new_edit: LineEdit = null
var _add_btn: Button = null
var _save_btn: Button = null
var _items: Array = []
var _dirty: bool = false
var _populating: bool = false
var _remind_edits: Array = []
var _remind_badges: Array = []
var _datetime_popup: PopupPanel = null
var _picker_row_index: int = -1
var _picker_year: SpinBox = null
var _picker_month: SpinBox = null
var _picker_day: SpinBox = null
var _picker_hour: SpinBox = null
var _picker_minute: SpinBox = null


func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_STOP
	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	title_bar.gui_input.connect(_on_title_bar_input)
	close_btn.pressed.connect(func(): close_requested.emit(); hide())
	title_label.text = "📝 待办事项"
	_build_body()
	_build_datetime_popup()
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


func _content_scroll_width() -> float:
	return UiConfig.s(_CONTENT_SCROLL_RECT.z - _CONTENT_SCROLL_RECT.x)


func _sync_list_width() -> void:
	if _list:
		_list.custom_minimum_size.x = _content_scroll_width()


func _apply_style() -> void:
	var panel_sb := ACStyle.panel_card_stylebox()
	panel_sb.bg_color = Color(ACStyle.CREAM.r, ACStyle.CREAM.g, ACStyle.CREAM.b, 0.98)
	panel_bg.add_theme_stylebox_override("panel", panel_sb)
	title_label.add_theme_color_override("font_color", ACStyle.BROWN)
	title_label.add_theme_font_size_override("font_size", UiConfig.si(15))
	close_btn.flat = true
	close_btn.add_theme_stylebox_override("normal", ACStyle.icon_button_stylebox())
	close_btn.add_theme_stylebox_override("hover", ACStyle.icon_button_stylebox(true))
	close_btn.add_theme_color_override("font_color", ACStyle.BROWN_LIGHT)
	close_btn.custom_minimum_size = Vector2(UiConfig.s(28), UiConfig.s(28))
	if _save_btn:
		ACStyle.apply_footer_button_theme(_save_btn, not _dirty)
		_save_btn.text = "已保存 ✓" if not _dirty else "保存"
		_save_btn.disabled = not _dirty
	if _add_btn:
		ACStyle.apply_footer_button_theme(_add_btn, false)
	if _new_edit:
		ACStyle.apply_line_edit_theme(_new_edit)
	if _scroll:
		ACStyle.apply_scroll_container_theme(_scroll)


func _build_body() -> void:
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel_bg.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", UiConfig.si(12))
	_scroll.add_child(_list)

	_footer = HBoxContainer.new()
	_footer.alignment = BoxContainer.ALIGNMENT_END
	_footer.add_theme_constant_override("separation", UiConfig.si(8))
	panel_bg.add_child(_footer)

	_new_edit = LineEdit.new()
	_new_edit.placeholder_text = "添加待办…"
	_new_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_new_edit.text_submitted.connect(func(t: String): _on_add_text(t))
	_footer.add_child(_new_edit)

	_add_btn = Button.new()
	_add_btn.text = "+ 添加"
	_add_btn.pressed.connect(func(): _on_add_text(_new_edit.text))
	_footer.add_child(_add_btn)

	_save_btn = Button.new()
	_save_btn.text = "已保存 ✓"
	_save_btn.disabled = true
	_save_btn.pressed.connect(_flush_save)
	_footer.add_child(_save_btn)

	_layout_chrome()


func _build_datetime_popup() -> void:
	_datetime_popup = PopupPanel.new()
	_datetime_popup.hide()
	add_child(_datetime_popup)

	var wrap := PanelContainer.new()
	var popup_sb := ACStyle.panel_card_stylebox()
	popup_sb.content_margin_left = UiConfig.si(14)
	popup_sb.content_margin_right = UiConfig.si(14)
	popup_sb.content_margin_top = UiConfig.si(12)
	popup_sb.content_margin_bottom = UiConfig.si(12)
	wrap.add_theme_stylebox_override("panel", popup_sb)
	_datetime_popup.add_child(wrap)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", UiConfig.si(8))
	wrap.add_child(body)

	var title := Label.new()
	title.text = "选择提醒时间"
	title.add_theme_color_override("font_color", ACStyle.BROWN)
	title.add_theme_font_size_override("font_size", UiConfig.si(13))
	body.add_child(title)

	var date_row := HBoxContainer.new()
	date_row.add_theme_constant_override("separation", UiConfig.si(4))
	body.add_child(date_row)
	_picker_year = _add_picker_spin(date_row, 2020, 2035, 2026, "年")
	_picker_month = _add_picker_spin(date_row, 1, 12, 6, "月")
	_picker_day = _add_picker_spin(date_row, 1, 31, 13, "日")

	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", UiConfig.si(4))
	body.add_child(time_row)
	_picker_hour = _add_picker_spin(time_row, 0, 23, 18, "时")
	_picker_minute = _add_picker_spin(time_row, 0, 59, 0, "分")

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", UiConfig.si(8))
	body.add_child(btn_row)

	var clear_btn := Button.new()
	clear_btn.text = "清除"
	ACStyle.apply_footer_button_theme(clear_btn, false)
	clear_btn.pressed.connect(_on_picker_clear)
	btn_row.add_child(clear_btn)

	var ok_btn := Button.new()
	ok_btn.text = "确定"
	ACStyle.apply_footer_button_theme(ok_btn, false)
	ok_btn.pressed.connect(_on_picker_confirm)
	btn_row.add_child(ok_btn)


func _add_picker_spin(row: HBoxContainer, min_v: int, max_v: int, default_v: int, suffix: String) -> SpinBox:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", UiConfig.si(2))
	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.value = default_v
	spin.custom_minimum_size = Vector2(UiConfig.s(56), UiConfig.s(30))
	ACStyle.apply_spinbox_theme(spin)
	var lbl := Label.new()
	lbl.text = suffix
	lbl.add_theme_color_override("font_color", ACStyle.BROWN_LIGHT)
	lbl.add_theme_font_size_override("font_size", UiConfig.si(12))
	box.add_child(spin)
	box.add_child(lbl)
	row.add_child(box)
	return spin


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


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible():
		if _datetime_popup:
			_datetime_popup.hide()


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


func _card_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var r := UiConfig.si(12)
	var theme := _ROW_THEME
	sb.bg_color = theme["bg"]
	sb.border_color = theme["accent"]
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(r)
	sb.content_margin_left = UiConfig.si(10)
	sb.content_margin_right = UiConfig.si(10)
	sb.content_margin_top = UiConfig.si(8)
	sb.content_margin_bottom = UiConfig.si(8)
	ACStyle.apply_soft_elevation_shadow(sb, theme["accent"])
	return sb


func _time_badge_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var theme := _ROW_THEME
	var r := UiConfig.si(8)
	sb.bg_color = Color(theme["badge"].r, theme["badge"].g, theme["badge"].b, 0.16)
	sb.border_color = Color(theme["badge"].r, theme["badge"].g, theme["badge"].b, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(r)
	sb.content_margin_left = UiConfig.si(8)
	sb.content_margin_right = UiConfig.si(8)
	sb.content_margin_top = UiConfig.si(3)
	sb.content_margin_bottom = UiConfig.si(3)
	return sb


func _rebuild_rows() -> void:
	for c in _list.get_children():
		c.queue_free()
	_remind_edits.clear()
	_remind_badges.clear()
	for i in range(_items.size()):
		_list.add_child(_build_row(i))
	if _items.is_empty():
		var empty := Label.new()
		empty.text = "还没有待办，在下面输入添加吧~"
		empty.add_theme_color_override("font_color", ACStyle.BROWN_LIGHT)
		empty.add_theme_font_size_override("font_size", UiConfig.si(13))
		_list.add_child(empty)
	call_deferred("_sync_list_width")


func _build_row(index: int) -> PanelContainer:
	var item: Dictionary = _items[index]
	var done := bool(item.get("done", false))
	var theme := _ROW_THEME

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _card_stylebox())
	card.modulate = Color(1, 1, 1, 0.55 if done else 1.0)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", UiConfig.si(8))
	card.add_child(body)

	# 第一行：勾选 + 待办内容 + 删除
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", UiConfig.si(8))

	var cb := CheckBox.new()
	cb.set_pressed_no_signal(done)
	ACStyle.apply_checkbox_theme(cb, "完成")
	if done:
		cb.add_theme_color_override("font_color", ACStyle.BROWN_LIGHT)
	cb.toggled.connect(func(on: bool): _on_row_changed(index, "done", on))
	row1.add_child(cb)

	var text_edit := LineEdit.new()
	text_edit.text = str(item.get("text", ""))
	text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_edit.custom_minimum_size = Vector2(UiConfig.s(120), 0)
	ACStyle.apply_line_edit_theme(text_edit)
	text_edit.text_changed.connect(func(t: String): _on_row_changed(index, "text", t))
	row1.add_child(text_edit)

	var del_btn := Button.new()
	del_btn.text = "删除"
	ACStyle.apply_danger_button_theme(del_btn, 52.0)
	del_btn.pressed.connect(func(): _on_delete_row(index))
	row1.add_child(del_btn)
	body.add_child(row1)

	# 第二行：提醒时间（真实日期时间）
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", UiConfig.si(6))

	var remind_lbl := Label.new()
	remind_lbl.text = "提醒"
	remind_lbl.add_theme_color_override("font_color", theme["badge"])
	remind_lbl.add_theme_font_size_override("font_size", UiConfig.si(13))
	row2.add_child(remind_lbl)

	var remind_edit := LineEdit.new()
	remind_edit.placeholder_text = REMIND_PLACEHOLDER
	remind_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	remind_edit.text = _remind_display_text(item)
	remind_edit.editable = not done
	ACStyle.apply_line_edit_theme(remind_edit)
	remind_edit.text_changed.connect(func(t: String): _on_remind_draft_changed(index, t))
	remind_edit.focus_exited.connect(func(): _on_remind_commit(index))
	remind_edit.text_submitted.connect(func(_t: String): _on_remind_commit(index))
	row2.add_child(remind_edit)
	_remind_edits.append(remind_edit)

	var pick_btn := Button.new()
	pick_btn.text = "📅"
	pick_btn.tooltip_text = "选择日期和时间"
	pick_btn.disabled = done
	pick_btn.custom_minimum_size = Vector2(UiConfig.s(36), UiConfig.s(30))
	ACStyle.apply_footer_button_theme(pick_btn, false)
	pick_btn.pressed.connect(func(): _open_remind_picker(index, pick_btn))
	row2.add_child(pick_btn)

	var tz_hint := Label.new()
	tz_hint.text = "东八区"
	tz_hint.add_theme_color_override("font_color", Color(theme["badge"].r, theme["badge"].g, theme["badge"].b, 0.65))
	tz_hint.add_theme_font_size_override("font_size", UiConfig.si(11))
	row2.add_child(tz_hint)

	var badge_wrap := PanelContainer.new()
	badge_wrap.add_theme_stylebox_override("panel", _time_badge_stylebox())
	var badge_lbl := Label.new()
	badge_lbl.add_theme_color_override("font_color", theme["badge"])
	badge_lbl.add_theme_font_size_override("font_size", UiConfig.si(12))
	badge_lbl.text = _format_remind_summary(item)
	badge_wrap.add_child(badge_lbl)
	row2.add_child(badge_wrap)
	_remind_badges.append(badge_lbl)
	body.add_child(row2)

	return card


func _remind_display_text(item: Dictionary) -> String:
	if bool(item.get("done", false)):
		return ""
	var stored := str(item.get("remind_at_text", ""))
	if not stored.is_empty():
		return stored
	var raw = item.get("remind_at")
	if raw == null:
		return ""
	return _unix_to_cst_display(int(float(raw)))


func _local_tz_bias_sec() -> int:
	var tz: Dictionary = Time.get_time_zone_from_system()
	return -int(tz.get("bias", 0)) * 60


func _unix_from_cst_datetime(year: int, month: int, day: int, hour: int, minute: int) -> int:
	var dict := {
		"year": year, "month": month, "day": day,
		"hour": hour, "minute": minute, "second": 0,
	}
	var as_local := int(Time.get_unix_time_from_datetime_dict(dict))
	return as_local + _local_tz_bias_sec() - CST_OFFSET_SEC


func _unix_to_cst_display(unix_ts: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(unix_ts + CST_OFFSET_SEC - _local_tz_bias_sec())
	return "%04d/%02d/%02d %02d:%02d" % [
		int(d.get("year", 2000)), int(d.get("month", 1)), int(d.get("day", 1)),
		int(d.get("hour", 0)), int(d.get("minute", 0)),
	]


func _unix_to_display(unix_ts: int) -> String:
	return _unix_to_cst_display(unix_ts)


func _parse_remind_datetime(text: String) -> Variant:
	var t := text.strip_edges()
	if t.is_empty():
		return {"remind_at": null, "remind_at_text": ""}
	var parts := t.split(" ", false)
	if parts.size() != 2:
		return null
	var date_str := parts[0]
	var date_parts: PackedStringArray
	if date_str.contains("/"):
		date_parts = date_str.split("/", false)
	elif date_str.contains("-"):
		date_parts = date_str.split("-", false)
	else:
		return null
	var time_parts := parts[1].split(":", false)
	if date_parts.size() != 3 or time_parts.size() != 2:
		return null
	if not date_parts[0].is_valid_int() or not date_parts[1].is_valid_int() or not date_parts[2].is_valid_int():
		return null
	if not time_parts[0].is_valid_int() or not time_parts[1].is_valid_int():
		return null
	var y_raw := int(date_parts[0])
	var year := y_raw if y_raw >= 100 else 2000 + y_raw
	var month := int(date_parts[1])
	var day := int(date_parts[2])
	var hour := int(time_parts[0])
	var minute := int(time_parts[1])
	if month < 1 or month > 12 or day < 1 or day > 31:
		return null
	if hour < 0 or hour > 23 or minute < 0 or minute > 59:
		return null
	var unix_local := _unix_from_cst_datetime(year, month, day, hour, minute)
	var normalized := "%04d/%02d/%02d %02d:%02d" % [year, month, day, hour, minute]
	return {"remind_at": float(unix_local), "remind_at_text": normalized}


func _format_remind_summary(item: Dictionary, draft: String = "") -> String:
	if bool(item.get("done", false)):
		return "已完成"
	var draft_text := draft.strip_edges()
	if not draft_text.is_empty():
		var parsed = _parse_remind_datetime(draft_text)
		if parsed == null:
			return "格式错误"
	var raw = item.get("remind_at")
	if raw == null:
		if not draft_text.is_empty():
			return "待确认"
		return "无提醒"
	var ts := int(float(raw))
	var now := int(Time.get_unix_time_from_system())
	if ts <= now:
		return "已到期"
	return "待提醒"


func _update_remind_badge(index: int, draft: String = "") -> void:
	if index < 0 or index >= _remind_badges.size() or index >= _items.size():
		return
	var badge: Label = _remind_badges[index]
	if badge:
		badge.text = _format_remind_summary(_items[index], draft)


func _on_remind_draft_changed(index: int, text: String) -> void:
	if _populating:
		return
	if index < 0 or index >= _items.size():
		return
	_items[index]["remind_at_text"] = text
	_mark_dirty()
	_update_remind_badge(index, text)


func _open_remind_picker(index: int, _anchor: Control) -> void:
	if index < 0 or index >= _items.size() or _datetime_popup == null:
		return
	_picker_row_index = index
	var edit: LineEdit = null
	if index < _remind_edits.size():
		edit = _remind_edits[index]
	var seed := edit.text if edit else str(_items[index].get("remind_at_text", ""))
	_seed_picker(seed)
	_popup_datetime_centered()


func _popup_datetime_centered() -> void:
	if _datetime_popup == null:
		return
	var wrap := _datetime_popup.get_child(0) as Control
	var pop_size := wrap.get_combined_minimum_size() if wrap else Vector2(UiConfig.s(300), UiConfig.s(150))
	_datetime_popup.size = Vector2i(int(pop_size.x), int(pop_size.y))
	var area := panel_bg.get_rect()
	var pos := area.position + (area.size - pop_size) * 0.5
	_datetime_popup.position = Vector2i(int(pos.x), int(pos.y))
	_datetime_popup.popup()


func _seed_picker(text: String) -> void:
	var parsed = _parse_remind_datetime(text)
	var remind_at = parsed.get("remind_at") if parsed != null else null
	if remind_at != null:
		var adj := int(float(remind_at)) + CST_OFFSET_SEC - _local_tz_bias_sec()
		_set_picker_from_datetime_dict(Time.get_datetime_dict_from_unix_time(adj))
		return
	var now_adj := int(Time.get_unix_time_from_system()) + CST_OFFSET_SEC - _local_tz_bias_sec()
	_set_picker_from_datetime_dict(Time.get_datetime_dict_from_unix_time(now_adj))


func _set_picker_from_datetime_dict(d: Dictionary) -> void:
	_picker_year.value = int(d.get("year", 2026))
	_picker_month.value = int(d.get("month", 1))
	_picker_day.value = int(d.get("day", 1))
	_picker_hour.value = int(d.get("hour", 0))
	_picker_minute.value = int(d.get("minute", 0))


func _format_picker_datetime() -> String:
	return "%04d/%02d/%02d %02d:%02d" % [
		int(_picker_year.value), int(_picker_month.value), int(_picker_day.value),
		int(_picker_hour.value), int(_picker_minute.value),
	]


func _on_picker_confirm() -> void:
	var idx := _picker_row_index
	_picker_row_index = -1
	if idx < 0:
		return
	var text := _format_picker_datetime()
	if idx < _remind_edits.size():
		_remind_edits[idx].text = text
	_on_remind_commit(idx)
	if _datetime_popup:
		_datetime_popup.hide()


func _on_picker_clear() -> void:
	var idx := _picker_row_index
	_picker_row_index = -1
	if idx < 0:
		return
	if idx < _remind_edits.size():
		_remind_edits[idx].text = ""
	_on_remind_commit(idx)
	if _datetime_popup:
		_datetime_popup.hide()


func _on_remind_commit(index: int) -> void:
	if _populating:
		return
	if index < 0 or index >= _items.size():
		return
	var edit: LineEdit = null
	if index < _remind_edits.size():
		edit = _remind_edits[index]
	var text := edit.text if edit else str(_items[index].get("remind_at_text", ""))
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		_items[index]["remind_at"] = null
		_items[index]["remind_at_text"] = ""
		if edit:
			edit.text = ""
		_mark_dirty()
		_update_remind_badge(index)
		return
	var parsed = _parse_remind_datetime(trimmed)
	if parsed == null:
		_items[index]["remind_at_text"] = trimmed
		_mark_dirty()
		_update_remind_badge(index, trimmed)
		return
	_items[index]["remind_at"] = parsed["remind_at"]
	_items[index]["remind_at_text"] = parsed["remind_at_text"]
	if edit:
		edit.text = parsed["remind_at_text"]
	_mark_dirty()
	_update_remind_badge(index)


func _on_row_changed(index: int, field: String, value: Variant) -> void:
	if _populating:
		return
	if index < 0 or index >= _items.size():
		return
	_items[index][field] = value
	if field == "done" and bool(value):
		_items[index]["remind_at"] = null
		_items[index]["remind_at_text"] = ""
	_mark_dirty()
	if field == "done":
		_rebuild_rows()


func _on_delete_row(index: int) -> void:
	if index < 0 or index >= _items.size():
		return
	_items.remove_at(index)
	_mark_dirty()
	_rebuild_rows()


func _on_add_text(text: String) -> void:
	var t := text.strip_edges()
	if t.is_empty():
		return
	_items.append({
		"id": "todo_%d" % Time.get_ticks_msec(),
		"text": t,
		"done": false,
		"remind_at": null,
		"remind_at_text": "",
		"created_at": Time.get_datetime_string_from_system(false, true),
	})
	_new_edit.text = ""
	_mark_dirty()
	_rebuild_rows()


func _mark_dirty() -> void:
	_dirty = true
	_apply_style()


func _flush_save() -> void:
	for i in range(_items.size()):
		_on_remind_commit(i)
	save_requested.emit(_items.duplicate(true))
