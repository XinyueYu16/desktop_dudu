extends MarginContainer

# Single chat bubble — used inside the chat panel's message list.

const ChatBubbleStyle = preload("res://scripts/chat_bubble_style.gd")

@onready var label: Label = $BubblePanel/BubbleLabel
@onready var panel: PanelContainer = $BubblePanel

var _role: String = ""
var _compact: bool = false


func setup(role: String, text: String) -> void:
	_role = role
	if is_node_ready():
		_apply(text)
	else:
		ready.connect(func(): _apply(text), CONNECT_ONE_SHOT)


func append_text(text: String) -> void:
	label.text += text
	label.reset_size()
	reset_size()


func set_compact(compact: bool) -> void:
	_compact = compact
	if is_node_ready():
		_apply(label.text)


func _apply(text: String) -> void:
	label.text = text
	label.custom_minimum_size = Vector2(200, 0)
	ChatBubbleStyle.apply_to_panel(panel, label, _role)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if _compact:
		add_theme_constant_override("margin_left", 0)
		add_theme_constant_override("margin_right", 0)
	else:
		match _role:
			"user":
				add_theme_constant_override("margin_left", 40)
				add_theme_constant_override("margin_right", 8)
			"assistant":
				add_theme_constant_override("margin_left", 4)
				add_theme_constant_override("margin_right", 40)
