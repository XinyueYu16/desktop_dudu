extends MarginContainer

# Single chat bubble — used inside the chat panel's message list.

const ChatBubbleStyle = preload("res://scripts/chat_bubble_style.gd")
const ChatMarkdown = preload("res://scripts/chat_markdown.gd")

signal delete_requested(timestamp: String)

@onready var time_label: Label = $ContentVBox/TimeLabel
@onready var label: RichTextLabel = $ContentVBox/BubblePanel/BubbleLabel
@onready var panel: PanelContainer = $ContentVBox/BubblePanel

var _role: String = ""
var _compact: bool = false
var _timestamp: String = ""
var _raw_text: String = ""
var _context_menu: PopupMenu = null


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	panel.gui_input.connect(_on_gui_input)
	label.gui_input.connect(_on_gui_input)
	label.context_menu_enabled = false
	_setup_context_menu()


func get_timestamp() -> String:
	return _timestamp


func get_plain_text() -> String:
	return _raw_text


func setup(role: String, text: String, timestamp: String = "") -> void:
	_role = role
	_timestamp = timestamp
	_raw_text = text
	if is_node_ready():
		_apply(text, timestamp)
	else:
		ready.connect(func(): _apply(text, timestamp), CONNECT_ONE_SHOT)


func append_text(text: String) -> void:
	_raw_text += text
	_set_label_text(_raw_text)
	label.reset_size()
	reset_size()


func set_compact(compact: bool) -> void:
	_compact = compact
	if is_node_ready():
		_set_label_text(_raw_text)


func _dim(v: float) -> float:
	return UiConfig.s(v)


func _dimi(v: int) -> int:
	return UiConfig.si(v)


func _format_timestamp(ts: String) -> String:
	if ts.is_empty() or ts.length() < 16 or ts[4] != "-" or ts[10] != " ":
		return ""
	var hm := ts.substr(11, 5)
	var year := int(ts.substr(0, 4))
	var month := int(ts.substr(5, 2))
	var day := int(ts.substr(8, 2))

	var now := Time.get_datetime_dict_from_system(false)
	var today := "%04d-%02d-%02d" % [now.year, now.month, now.day]
	var msg_day := "%04d-%02d-%02d" % [year, month, day]

	if msg_day == today:
		return hm

	var yesterday_unix := Time.get_unix_time_from_datetime_dict(now) - 86400
	var yd := Time.get_datetime_dict_from_unix_time(int(yesterday_unix))
	var yesterday := "%04d-%02d-%02d" % [yd.year, yd.month, yd.day]
	if msg_day == yesterday:
		return "昨天 %s" % hm

	return "%d月%d日 %s" % [month, day, hm]


func _set_label_text(text: String) -> void:
	if _compact:
		label.bbcode_enabled = false
		label.text = text
	else:
		label.bbcode_enabled = true
		label.text = ChatMarkdown.to_bbcode(text, _role)


func _apply(text: String, timestamp: String = "") -> void:
	_raw_text = text
	_set_label_text(text)
	label.custom_minimum_size = Vector2(_dim(200), 0)
	ChatBubbleStyle.apply_to_rich_label(panel, label, _role, true)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if _compact:
		time_label.hide()
		add_theme_constant_override("margin_left", 0)
		add_theme_constant_override("margin_right", 0)
	else:
		var display_ts := _format_timestamp(timestamp)
		if display_ts.is_empty():
			time_label.hide()
		else:
			time_label.show()
			time_label.text = display_ts
			time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if _role == "user" else HORIZONTAL_ALIGNMENT_LEFT
			time_label.add_theme_color_override("font_color", ACStyle.BROWN_LIGHT)
			time_label.add_theme_font_size_override("font_size", _dimi(11))
		match _role:
			"user":
				add_theme_constant_override("margin_left", _dimi(40))
				add_theme_constant_override("margin_right", _dimi(8))
			"assistant":
				add_theme_constant_override("margin_left", _dimi(4))
				add_theme_constant_override("margin_right", _dimi(40))


func _setup_context_menu() -> void:
	if _compact:
		return
	_context_menu = PopupMenu.new()
	_context_menu.add_item("全选", 0)
	_context_menu.add_item("复制", 1)
	_context_menu.add_separator()
	_context_menu.add_item("删除", 2)
	_context_menu.id_pressed.connect(_on_context_menu_id)
	_context_menu.popup_window = true
	add_child(_context_menu)


func _on_gui_input(event: InputEvent) -> void:
	if _compact or _context_menu == null:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var mouse := get_global_mouse_position()
			_context_menu.popup(Rect2i(mouse, Vector2i.ZERO))
			get_viewport().set_input_as_handled()


func _on_context_menu_id(id: int) -> void:
	match id:
		0:
			label.select_all()
		1:
			var selected := label.get_selected_text()
			if selected.is_empty():
				DisplayServer.clipboard_set(_raw_text)
			else:
				DisplayServer.clipboard_set(selected)
		2:
			if not _timestamp.is_empty():
				delete_requested.emit(_timestamp)
