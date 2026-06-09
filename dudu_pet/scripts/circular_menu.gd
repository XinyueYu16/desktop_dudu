extends Control

# 嘟嘟快捷菜单 — 动森风格侧边卡片
# Replaces the old half-circle fan menu with a clean vertical card.
# Card appears to the right of the cat (or left if no space), never above.

signal item_selected(action: String)

const ITEMS: Array[Dictionary] = [
	{"icon": "💬", "label": "聊天记录", "action": "chat_history"},
	{"icon": "⏰", "label": "定时提醒", "action": "reminders"},
	{"icon": "🌍", "label": "自由探索", "action": "explore"},
	{"icon": "🔮", "label": "每日运势", "action": "fortune"},
	{"icon": "⚙️", "label": "设置",     "action": "settings"},
]

const ITEM_HEIGHT := 36.0
const ITEM_WIDTH := 130.0
const CARD_PADDING := 10.0
const GAP_FROM_CAT := 18.0

var _open: bool = false
var _card: PanelContainer = null
var _items_vbox: VBoxContainer = null
var _buttons: Array[Button] = []
var _overlay: ColorRect = null


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_create_overlay()
	_create_card()


func _create_overlay():
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.01)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.size = get_viewport().get_visible_rect().size
	_overlay.position = Vector2.ZERO
	_overlay.gui_input.connect(_on_overlay_input)
	_overlay.hide()
	add_child(_overlay)


func _create_card():
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.add_theme_stylebox_override("panel", ACStyle.card_stylebox(12.0))

	_items_vbox = VBoxContainer.new()
	_items_vbox.add_theme_constant_override("separation", 2)
	_card.add_child(_items_vbox)

	for item in ITEMS:
		var btn := Button.new()
		btn.flat = true
		btn.custom_minimum_size = Vector2(ITEM_WIDTH, ITEM_HEIGHT)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.text = "  %s  %s" % [item["icon"], item["label"]]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", ACStyle.BROWN)
		btn.add_theme_stylebox_override("normal", ACStyle.menu_item_stylebox(false))
		btn.add_theme_stylebox_override("hover", ACStyle.menu_item_stylebox(true))
		btn.pressed.connect(_on_button_pressed.bind(item["action"]))
		_items_vbox.add_child(btn)
		_buttons.append(btn)

	add_child(_card)
	_card.hide()
	_card.modulate.a = 0.0


func apply_ui_scale() -> void:
	var s := UiConfig.scale
	_card.custom_minimum_size = Vector2(
		UiConfig.s(ITEM_WIDTH + CARD_PADDING * 2 + 4), 0
	)
	for btn in _buttons:
		btn.custom_minimum_size = Vector2(UiConfig.s(ITEM_WIDTH), UiConfig.s(ITEM_HEIGHT))
		btn.add_theme_font_size_override("font_size", UiConfig.si(13))


func open(center: Vector2):
	if _open:
		return
	_open = true

	_overlay.size = get_viewport().get_visible_rect().size
	_overlay.show()

	_card.reset_size()
	var card_size := _card.size
	var card_w := maxf(card_size.x, UiConfig.s(ITEM_WIDTH + CARD_PADDING * 2 + 4))
	var card_h := maxf(card_size.y, 1.0)

	var view_w := float(get_viewport().get_visible_rect().size.x)
	var view_h := float(get_viewport().get_visible_rect().size.y)

	# Prefer right side, fallback to left
	var pos_x: float
	var slide_dir: float
	if center.x + 64 + GAP_FROM_CAT + card_w <= view_w:
		pos_x = center.x + 64 + UiConfig.s(GAP_FROM_CAT)
		slide_dir = -10.0
	else:
		pos_x = center.x - 64 - UiConfig.s(GAP_FROM_CAT) - card_w
		slide_dir = 10.0

	var pos_y := center.y - card_h / 2.0
	pos_y = clampf(pos_y, UiConfig.s(8), view_h - card_h - UiConfig.s(8))

	_card.position = Vector2(pos_x + slide_dir, pos_y)
	_card.modulate.a = 0.0
	_card.show()

	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.set_parallel(true)
	tw.tween_property(_card, "position:x", pos_x, 0.22)
	tw.tween_property(_card, "modulate:a", 1.0, 0.18)


func close():
	if not _open:
		return
	_open = false
	_overlay.hide()

	var tw := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.set_parallel(true)
	# Slide back toward cat + fade
	var dir := 10.0 if _card.position.x > get_viewport().get_visible_rect().size.x / 2.0 else -10.0
	tw.tween_property(_card, "position:x", _card.position.x + dir, 0.15)
	tw.tween_property(_card, "modulate:a", 0.0, 0.12)
	tw.tween_callback(_card.hide).set_delay(0.15)


func _on_button_pressed(action: String):
	close()
	item_selected.emit(action)


func _on_overlay_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()


func is_open() -> bool:
	return _open


func get_button_global_rects() -> Array[Rect2]:
	if not _open or not _card.visible:
		return []
	return [_card.get_global_rect()]
