class_name ChatPanel
extends Control

# Chat history panel — "🌙 魔法日记"
# Floating dialog, positioned near the cat.

signal message_sent(text: String)
signal close_requested

const BASE_SIZE := Vector2(340, 420)
const MSG_BUBBLE = preload("res://scenes/message_bubble.tscn")

# Design-time chrome rects (left, top, right, bottom) before UiConfig.scale
const _TITLE_RECT := Vector4(12, 10, 328, 40)
const _SCROLL_RECT := Vector4(4, 46, 336, 368)
const _INPUT_RECT := Vector4(8, 374, 332, 416)

@onready var panel_bg: Panel = $PanelBg
@onready var message_list: VBoxContainer = $PanelBg/MessageScroll/MessageList
@onready var message_scroll: ScrollContainer = $PanelBg/MessageScroll
@onready var input_container: MarginContainer = $PanelBg/InputContainer
@onready var input_field: TextEdit = $PanelBg/InputContainer/InputHBox/InputField
@onready var send_btn: Button = $PanelBg/InputContainer/InputHBox/SendBtn
@onready var close_btn: Button = $PanelBg/TitleBar/TitleHBox/CloseBtn
@onready var title_bar: MarginContainer = $PanelBg/TitleBar
@onready var title_label: Label = $PanelBg/TitleBar/TitleHBox/TitleLabel

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO


func _ready():
	hide()
	mouse_filter = Control.MOUSE_FILTER_STOP
	apply_ui_scale()
	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	title_bar.gui_input.connect(_on_title_bar_input)
	input_field.text_changed.connect(_on_input_changed)
	send_btn.pressed.connect(_send_message)
	close_btn.pressed.connect(func(): close_requested.emit(); hide())


func is_dragging_title() -> bool:
	return _dragging


func visual_size() -> Vector2:
	return size


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


func apply_ui_scale() -> void:
	scale = Vector2.ONE
	var w := UiConfig.si(int(BASE_SIZE.x))
	var h := UiConfig.si(int(BASE_SIZE.y))
	custom_minimum_size = Vector2(w, h)
	size = Vector2(w, h)
	_layout_chrome()
	_apply_style()


func _layout_chrome() -> void:
	_place_rect(title_bar, _TITLE_RECT)
	_place_rect(message_scroll, _SCROLL_RECT)
	_place_rect(input_container, _INPUT_RECT)
	message_list.add_theme_constant_override("separation", UiConfig.si(8))


func _place_rect(node: Control, rect: Vector4) -> void:
	node.offset_left = UiConfig.s(rect.x)
	node.offset_top = UiConfig.s(rect.y)
	node.offset_right = UiConfig.s(rect.z)
	node.offset_bottom = UiConfig.s(rect.w)


func _apply_style():
	# 动森风格面板 — 奶油底 + 木纹边框
	panel_bg.add_theme_stylebox_override("panel", ACStyle.panel_card_stylebox())

	# 输入框 — 温暖的浅色背景
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color(0.980, 0.965, 0.933, 1.0)
	var icr := UiConfig.si(10)
	# 滚动区域 — 透明，让奶油底色透出
	message_scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	isb.corner_radius_top_left = icr
	isb.corner_radius_top_right = icr
	isb.corner_radius_bottom_left = icr
	isb.corner_radius_bottom_right = icr
	isb.border_width_left = 1
	isb.border_width_right = 1
	isb.border_width_top = 1
	isb.border_width_bottom = 1
	isb.border_color = Color(ACStyle.TAN.r, ACStyle.TAN.g, ACStyle.TAN.b, 0.5)
	input_field.add_theme_stylebox_override("normal", isb)
	input_field.add_theme_stylebox_override("focus", isb)
	input_field.add_theme_color_override("font_color", ACStyle.BROWN)
	input_field.add_theme_color_override("font_placeholder_color", ACStyle.BROWN_LIGHT)
	input_field.add_theme_font_size_override("font_size", UiConfig.si(14))
	input_field.placeholder_text = "说点什么..."
	input_field.custom_minimum_size.y = UiConfig.s(36)

	# 发送按钮 — 鼠尾草绿
	send_btn.flat = true
	var btn_sb := StyleBoxFlat.new()
	btn_sb.bg_color = ACStyle.SAGE
	btn_sb.corner_radius_top_left = UiConfig.si(8)
	btn_sb.corner_radius_top_right = UiConfig.si(8)
	btn_sb.corner_radius_bottom_left = UiConfig.si(8)
	btn_sb.corner_radius_bottom_right = UiConfig.si(8)
	send_btn.add_theme_stylebox_override("normal", btn_sb)
	var btn_hover := btn_sb.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(ACStyle.SAGE.r, ACStyle.SAGE.g, ACStyle.SAGE.b, 0.8)
	send_btn.add_theme_stylebox_override("hover", btn_hover)
	send_btn.add_theme_font_size_override("font_size", UiConfig.si(13))
	send_btn.add_theme_color_override("font_color", Color.WHITE)
	send_btn.custom_minimum_size = Vector2(UiConfig.s(52), UiConfig.s(36))

	# 标题
	title_label.add_theme_color_override("font_color", ACStyle.BROWN)
	title_label.add_theme_font_size_override("font_size", UiConfig.si(15))
	close_btn.add_theme_color_override("font_color", ACStyle.BROWN_LIGHT)
	close_btn.add_theme_font_size_override("font_size", UiConfig.si(16))
	close_btn.custom_minimum_size = Vector2(UiConfig.s(28), UiConfig.s(28))


func open(near_position: Vector2):
	var view_size := get_viewport().get_visible_rect().size
	var vs := visual_size()
	position.x = near_position.x + UiConfig.s(100)
	position.y = near_position.y - vs.y / 2.0
	if position.x + vs.x > view_size.x:
		position.x = near_position.x - vs.x - UiConfig.s(20)
	position.y = clampf(position.y, 0, view_size.y - vs.y)
	show()
	input_field.grab_focus()


func add_message(role: String, text: String, timestamp: String = ""):
	var bubble := MSG_BUBBLE.instantiate()
	message_list.add_child(bubble)
	bubble.setup(role, text, timestamp if not timestamp.is_empty() else _now_timestamp())
	_scroll_to_bottom.call_deferred()


func add_messages(messages: Array):
	for m in messages:
		var role: String = m.get("role", "assistant")
		var content: String = m.get("content", "")
		if content.is_empty():
			continue
		var bubble := MSG_BUBBLE.instantiate()
		message_list.add_child(bubble)
		bubble.setup(role, content, m.get("timestamp", ""))
	_scroll_to_bottom.call_deferred()


func _now_timestamp() -> String:
	return Time.get_datetime_string_from_system(false, true)


func clear_messages():
	for c in message_list.get_children():
		message_list.remove_child(c)
		c.queue_free()


func _scroll_to_bottom():
	await get_tree().process_frame
	message_list.reset_size()
	var bar := message_scroll.get_v_scroll_bar()
	message_scroll.scroll_vertical = bar.max_value


func append_last(text: String):
	var n := message_list.get_child_count()
	if n > 0:
		var last := message_list.get_child(n - 1)
		if last.has_method("append_text"):
			last.append_text(text)
	_scroll_to_bottom.call_deferred()


func add_date_divider(date_str: String):
	var lbl := Label.new()
	lbl.text = "── " + date_str + " ──"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", ACStyle.BROWN_LIGHT)
	lbl.add_theme_font_size_override("font_size", UiConfig.si(12))
	message_list.add_child(lbl)


func _send_message():
	var text := input_field.text.strip_edges()
	if text.is_empty():
		return
	input_field.text = ""
	add_message("user", text)
	message_sent.emit(text)


func _on_input_changed():
	send_btn.disabled = input_field.text.strip_edges().is_empty()
