extends Control

# Bottom half-circle menu — 5 items in a relaxed arc below the cat.
# Click outside (left-click) → close. Overlay only activates after a short delay
# to avoid eating the right-click that opened the menu.

signal item_selected(action: String)

# Left → Right order
const ITEMS: Array[Dictionary] = [
	{"icon": "💬", "label": "聊天记录", "action": "chat_history"},
	{"icon": "⏰", "label": "定时提醒", "action": "reminders"},
	{"icon": "🌍", "label": "自由探索", "action": "explore"},
	{"icon": "🔮", "label": "每日运势", "action": "fortune"},
	{"icon": "⚙️", "label": "设置",     "action": "settings"},
]

const RADIUS: float = 135.0
const BUTTON_SIZE: Vector2 = Vector2(72, 72)

var _buttons: Array[Button] = []
var _open: bool = false
var _center: Vector2 = Vector2.ZERO
var _overlay: ColorRect


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_create_overlay()
	_create_buttons()


func _create_overlay():
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.01)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.size = get_viewport().get_visible_rect().size
	_overlay.position = Vector2.ZERO
	# Only close on LEFT click — never eat the right-click
	_overlay.gui_input.connect(_on_overlay_input)
	_overlay.hide()
	add_child(_overlay)


func _create_buttons():
	for item in ITEMS:
		var btn := Button.new()
		btn.text = item["icon"] + "\n" + item["label"]
		btn.flat = false
		btn.custom_minimum_size = BUTTON_SIZE
		btn.size = BUTTON_SIZE
		btn.modulate.a = 0.0
		btn.scale = Vector2(0.3, 0.3)
		btn.hide()

		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.1, 0.18, 0.85)
		sb.corner_radius_top_left = BUTTON_SIZE.x / 2
		sb.corner_radius_top_right = BUTTON_SIZE.x / 2
		sb.corner_radius_bottom_left = BUTTON_SIZE.x / 2
		sb.corner_radius_bottom_right = BUTTON_SIZE.x / 2
		sb.border_width_left = 1; sb.border_width_right = 1
		sb.border_width_top = 1; sb.border_width_bottom = 1
		sb.border_color = Color(1, 1, 1, 0.2)
		btn.add_theme_stylebox_override("normal", sb)

		var sb_h := sb.duplicate() as StyleBoxFlat
		sb_h.bg_color = Color(0.2, 0.2, 0.35, 0.9)
		sb_h.border_color = Color(1, 1, 1, 0.5)
		btn.add_theme_stylebox_override("hover", sb_h)

		btn.add_theme_font_size_override("font_size", 11)
		btn.add_theme_color_override("font_color", Color(0.9, 0.9, 1, 1))

		btn.pressed.connect(_on_button_pressed.bind(item["action"]))
		add_child(btn)
		_buttons.append(btn)


func _angle_for_index(i: int) -> float:
	# Left→Right: 3PI/4 (bottom-left) → PI/2 (center-bottom) → PI/4 (bottom-right)
	var n := ITEMS.size()
	var t := float(i) / float(n - 1)
	return lerpf(PI * 3.0 / 4.0, PI / 4.0, t)


func open(center: Vector2):
	if _open:
		return
	_open = true
	_center = center
	_overlay.size = get_viewport().get_visible_rect().size
	_overlay.show()

	for i in ITEMS.size():
		var btn := _buttons[i]
		var angle := _angle_for_index(i)
		var target_pos := center + Vector2(cos(angle), sin(angle)) * RADIUS - BUTTON_SIZE / 2

		btn.position = center - BUTTON_SIZE / 2
		btn.modulate.a = 0
		btn.scale = Vector2(0.3, 0.3)
		btn.show()

		var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(btn, "position", target_pos, 0.35).set_delay(i * 0.04)
		tw.tween_property(btn, "modulate:a", 1.0, 0.25).set_delay(i * 0.04)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.35).set_delay(i * 0.04)


func close():
	if not _open:
		return
	_open = false
	_overlay.hide()

	for i in _buttons.size():
		var btn := _buttons[i]
		var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
		tw.tween_property(btn, "position", _center - BUTTON_SIZE / 2, 0.2).set_delay(i * 0.02)
		tw.tween_property(btn, "modulate:a", 0.0, 0.15).set_delay(i * 0.02)
		tw.tween_property(btn, "scale", Vector2(0.3, 0.3), 0.2).set_delay(i * 0.02)
		tw.tween_callback(btn.hide).set_delay(0.2)


func _on_button_pressed(action: String):
	close()
	item_selected.emit(action)


func _on_overlay_input(event: InputEvent):
	# Only close on LEFT click, never the right-click that opened us
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()

func is_open() -> bool:
	return _open


func get_button_global_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for btn in _buttons:
		if btn.visible and btn.modulate.a > 0:
			rects.append(btn.get_global_rect())
	return rects
