extends Control

# 嘟嘟快捷菜单 — 动森风格侧边卡片
# Replaces the old half-circle fan menu with a clean vertical card.
# Card appears to the right of the cat (or left if no space), never above.

signal item_selected(action: String)
signal toggle_changed(action: String, enabled: bool)

const ACTION_ITEMS: Array[Dictionary] = [
	{"icon": "💬", "label": "聊天记录", "action": "chat_history"},
	{"icon": "⏰", "label": "定时提醒", "action": "reminders"},
	{"icon": "🌍", "label": "自由探索", "action": "explore"},
	{"icon": "🔮", "label": "每日运势", "action": "fortune"},
	{"icon": "⚙️", "label": "设置",     "action": "settings"},
	{"icon": "🚪", "label": "退出",     "action": "quit"},
]

const TOGGLE_ITEMS: Array[Dictionary] = [
	{"icon": "💭", "label": "思考", "action": "toggle_thinking"},
	{"icon": "🧩", "label": "记忆", "action": "toggle_memory"},
	{"icon": "📝", "label": "记入", "action": "toggle_record"},
]

const ITEM_HEIGHT := 36.0
const ITEM_WIDTH := 130.0
const CARD_PADDING := 10.0
const GAP_FROM_CAT := 18.0

var _open: bool = false
var _card: PanelContainer = null
var _items_vbox: VBoxContainer = null
var _buttons: Array[Button] = []
var _toggle_buttons: Dictionary = {}
var _toggle_states: Dictionary = {
	"toggle_thinking": true,
	"toggle_memory": true,
	"toggle_record": true,
}
var _overlay: ColorRect = null
var _anim_tween: Tween = null
var _card_size: Vector2 = Vector2.ZERO


func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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

	_add_action_item(ACTION_ITEMS[0])
	_add_separator()
	for item in TOGGLE_ITEMS:
		_add_toggle_item(item)
	_add_separator()
	for i in range(1, ACTION_ITEMS.size()):
		_add_action_item(ACTION_ITEMS[i])

	add_child(_card)
	_card.hide()
	_card.modulate.a = 0.0
	call_deferred("_cache_card_size")


func _add_separator() -> void:
	var sep := Panel.new()
	sep.custom_minimum_size = Vector2(0, UiConfig.s(1))
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sep.add_theme_stylebox_override("panel", ACStyle.divider_stylebox())
	_items_vbox.add_child(sep)


func _add_action_item(item: Dictionary) -> void:
	var btn := _make_menu_button(item, false)
	btn.pressed.connect(_on_action_pressed.bind(item["action"]))
	_items_vbox.add_child(btn)
	_buttons.append(btn)


func _add_toggle_item(item: Dictionary) -> void:
	var action: String = item["action"]
	var btn := _make_menu_button(item, true)
	btn.toggle_mode = false
	btn.focus_mode = Control.FOCUS_NONE
	var on := bool(_toggle_states.get(action, true))
	btn.pressed.connect(_on_toggle_clicked.bind(action, item))
	_toggle_buttons[action] = btn
	_items_vbox.add_child(btn)
	_buttons.append(btn)
	_style_toggle_button(btn, item, on)


func _make_menu_button(item: Dictionary, _is_toggle: bool) -> Button:
	var btn := Button.new()
	btn.flat = true
	btn.custom_minimum_size = Vector2(ITEM_WIDTH, ITEM_HEIGHT)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", ACStyle.BROWN)
	btn.add_theme_stylebox_override("normal", ACStyle.menu_item_stylebox(false))
	btn.add_theme_stylebox_override("hover", ACStyle.menu_item_stylebox(true))
	btn.text = "  %s  %s" % [item["icon"], item["label"]]
	return btn


func _style_toggle_button(btn: Button, item: Dictionary, on: bool) -> void:
	btn.flat = false
	btn.clip_contents = false
	btn.text = "  %s  %s" % [item["icon"], item["label"]]
	var normal := ACStyle.menu_toggle_stylebox(on, false)
	var hover := ACStyle.menu_toggle_stylebox(on, true)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", normal)
	btn.add_theme_stylebox_override("disabled", normal)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		btn.add_theme_color_override(key, ACStyle.BROWN)


func _refresh_toggle_button(action: String) -> void:
	if not _toggle_buttons.has(action):
		return
	var btn: Button = _toggle_buttons[action]
	_style_toggle_button(btn, _item_for_action(action), bool(_toggle_states.get(action, true)))


func _kill_anim() -> void:
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = null


func _cache_card_size() -> void:
	call_deferred("_finish_cache_card_size")


func _finish_cache_card_size() -> void:
	if not _card or _open:
		return
	var keep_visible := _open
	var keep_alpha := _card.modulate.a
	_card.show()
	_card.modulate.a = 1.0
	_items_vbox.reset_size()
	_card.reset_size()
	var measured := _card.get_combined_minimum_size()
	if measured.y > 1.0:
		_card_size = measured
	elif _card.size.y > 1.0:
		_card_size = _card.size
	if not keep_visible:
		_card.hide()
		_card.modulate.a = keep_alpha


func _item_for_action(action: String) -> Dictionary:
	for item in TOGGLE_ITEMS:
		if item["action"] == action:
			return item
	return {}


func _on_action_pressed(action: String) -> void:
	close()
	item_selected.emit(action)


func _on_toggle_clicked(action: String, item: Dictionary) -> void:
	var on := not bool(_toggle_states.get(action, false))
	_toggle_states[action] = on
	_style_toggle_button(_toggle_buttons[action], item, on)
	toggle_changed.emit(action, on)


func set_toggle(action: String, on: bool) -> void:
	_toggle_states[action] = on
	if not _toggle_buttons.has(action):
		return
	var btn: Button = _toggle_buttons[action]
	_style_toggle_button(btn, _item_for_action(action), on)


func is_toggle_on(action: String) -> bool:
	return bool(_toggle_states.get(action, true))


func apply_ui_scale() -> void:
	_card.custom_minimum_size = Vector2(
		UiConfig.s(ITEM_WIDTH + CARD_PADDING * 2 + 4), 0
	)
	for btn in _buttons:
		btn.custom_minimum_size = Vector2(UiConfig.s(ITEM_WIDTH), UiConfig.s(ITEM_HEIGHT))
		btn.add_theme_font_size_override("font_size", UiConfig.si(13))
	for action in _toggle_buttons:
		var btn: Button = _toggle_buttons[action]
		_style_toggle_button(btn, _item_for_action(action), bool(_toggle_states.get(action, true)))
	if not _open:
		_cache_card_size()


func open(center: Vector2) -> void:
	if _open:
		return
	_kill_anim()
	_open = true

	var vp := get_viewport().get_visible_rect()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.size = vp.size
	_overlay.position = Vector2.ZERO
	_overlay.show()
	_overlay.move_to_front()
	_card.move_to_front()

	if _card_size.y <= 1.0:
		_finish_cache_card_size()

	var card_w := maxf(_card_size.x, UiConfig.s(ITEM_WIDTH + CARD_PADDING * 2 + 4))
	var card_h := maxf(_card_size.y, 1.0)

	var view_w := float(get_viewport().get_visible_rect().size.x)
	var view_h := float(get_viewport().get_visible_rect().size.y)

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

	_anim_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_anim_tween.set_parallel(true)
	_anim_tween.tween_property(_card, "position:x", pos_x, 0.22)
	_anim_tween.tween_property(_card, "modulate:a", 1.0, 0.18)


func close() -> void:
	if not _open:
		return
	_kill_anim()
	_open = false
	_overlay.hide()

	var dir := 10.0 if _card.position.x > get_viewport().get_visible_rect().size.x / 2.0 else -10.0
	_anim_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_anim_tween.set_parallel(true)
	_anim_tween.tween_property(_card, "position:x", _card.position.x + dir, 0.15)
	_anim_tween.tween_property(_card, "modulate:a", 0.0, 0.12)
	_anim_tween.chain().tween_callback(func():
		_card.hide()
		_card.modulate.a = 0.0
	)


func _on_overlay_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()


func is_open() -> bool:
	return _open


func get_passthrough_rects() -> Array[Rect2]:
	if not _open:
		return []
	# Overlay covers the viewport — must be in passthrough or clicks fall through glass.
	return [get_viewport().get_visible_rect()]
