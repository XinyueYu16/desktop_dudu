extends MarginContainer

# Single chat bubble — used inside the chat panel's message list.

const ChatBubbleStyle = preload("res://scripts/chat_bubble_style.gd")

@onready var time_label: Label = $ContentVBox/TimeLabel
@onready var label: Label = $ContentVBox/BubblePanel/BubbleLabel
@onready var panel: PanelContainer = $ContentVBox/BubblePanel

var _role: String = ""
var _compact: bool = false
var _timestamp: String = ""


func setup(role: String, text: String, timestamp: String = "") -> void:
	_role = role
	_timestamp = timestamp
	if is_node_ready():
		_apply(text, timestamp)
	else:
		ready.connect(func(): _apply(text, timestamp), CONNECT_ONE_SHOT)


func append_text(text: String) -> void:
	label.text += text
	label.reset_size()
	reset_size()


func set_compact(compact: bool) -> void:
	_compact = compact
	if is_node_ready():
		_apply(label.text, _timestamp)


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


func _apply(text: String, timestamp: String = "") -> void:
	label.text = text
	label.custom_minimum_size = Vector2(_dim(200), 0)
	ChatBubbleStyle.apply_to_panel(panel, label, _role, true)
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
