class_name SettingsPanel
extends Control

# Tabbed settings panel — 动森风格.
# All config exposed: General, Chat, Pomodoro, Reminders.
# Changes sent to backend immediately via signal.

signal setting_changed(key: String, value: Variant)
signal close_requested

const BASE_SIZE := Vector2(380, 440)
const TAB_NAMES := ["通用", "对话", "番茄", "提醒"]
const TAB_KEYS := ["ui", "chat", "pomodoro", "reminders"]

# Design rects
const _TITLE_RECT := Vector4(12, 10, 368, 40)
const _TAB_ROW_RECT := Vector4(8, 44, 372, 76)
const _CONTENT_RECT := Vector4(12, 82, 368, 420)

@onready var panel_bg: Panel = $PanelBg
@onready var title_bar: MarginContainer = $PanelBg/TitleBar
@onready var title_label: Label = $PanelBg/TitleBar/TitleHBox/TitleLabel
@onready var close_btn: Button = $PanelBg/TitleBar/TitleHBox/CloseBtn

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _active_tab: int = 0
var _tab_btns: Array[Button] = []
var _content_parent: Control = null
var _tab_controls: Array = [{}, {}, {}, {}]  # {key: control_node}
var _pending_settings: Dictionary = {}

# ── Model / duration option maps ──
const MODELS := ["deepseek-chat", "deepseek-reasoner"]
const DURATIONS_WORK := [15, 20, 25, 30, 45, 60]
const DURATIONS_BREAK := [5, 10, 15, 20]
const INTERVALS := [2, 3, 4, 5]
const REMINDER_INTERVALS := [15, 30, 45, 60, 90, 120]


func _ready():
	hide()
	mouse_filter = Control.MOUSE_FILTER_STOP
	apply_ui_scale()
	_build_tab_row()
	_build_content()
	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	title_bar.gui_input.connect(_on_title_bar_input)
	close_btn.pressed.connect(func(): close_requested.emit(); hide())
	_switch_tab(0)


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
	# Tab row and content parent are created programmatically below the chrome


func _place_rect(node: Control, rect: Vector4) -> void:
	node.offset_left = UiConfig.s(rect.x)
	node.offset_top = UiConfig.s(rect.y)
	node.offset_right = UiConfig.s(rect.z)
	node.offset_bottom = UiConfig.s(rect.w)


func _apply_style():
	panel_bg.add_theme_stylebox_override("panel", ACStyle.panel_card_stylebox())
	title_label.add_theme_color_override("font_color", ACStyle.BROWN)
	title_label.add_theme_font_size_override("font_size", UiConfig.si(15))
	close_btn.add_theme_color_override("font_color", ACStyle.BROWN_LIGHT)
	close_btn.add_theme_font_size_override("font_size", UiConfig.si(16))
	close_btn.custom_minimum_size = Vector2(UiConfig.s(28), UiConfig.s(28))


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


func is_dragging_title() -> bool:
	return _dragging


func visual_size() -> Vector2:
	return size


# ── Open / position ──

func open(near_position: Vector2):
	var view_size := get_viewport().get_visible_rect().size
	var vs := visual_size()
	position.x = near_position.x + UiConfig.s(100)
	position.y = near_position.y - vs.y / 2.0
	if position.x + vs.x > view_size.x:
		position.x = near_position.x - vs.x - UiConfig.s(20)
	position.y = clampf(position.y, 0, view_size.y - vs.y)
	show()


# ── Tab row ──

func _build_tab_row():
	var tab_cont := HBoxContainer.new()
	tab_cont.name = "TabRow"
	tab_cont.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_cont.add_theme_constant_override("separation", UiConfig.si(4))
	panel_bg.add_child(tab_cont)
	_place_rect(tab_cont, _TAB_ROW_RECT)

	var tab_group := ButtonGroup.new()
	tab_group.allow_unpress = false
	for i in TAB_NAMES.size():
		var btn := Button.new()
		btn.text = TAB_NAMES[i]
		btn.flat = true
		btn.toggle_mode = true
		btn.button_group = tab_group
		btn.custom_minimum_size = Vector2(UiConfig.s(66), UiConfig.s(28))
		btn.add_theme_font_size_override("font_size", UiConfig.si(13))
		btn.pressed.connect(_on_tab_pressed.bind(i))
		tab_cont.add_child(btn)
		_tab_btns.append(btn)
		_style_tab_btn(btn, false)


func _style_tab_btn(btn: Button, active: bool):
	var sb := StyleBoxFlat.new()
	sb.bg_color = ACStyle.SAGE if active else Color.TRANSPARENT
	sb.corner_radius_top_left = UiConfig.si(10)
	sb.corner_radius_top_right = UiConfig.si(10)
	sb.corner_radius_bottom_left = UiConfig.si(10)
	sb.corner_radius_bottom_right = UiConfig.si(10)
	btn.add_theme_stylebox_override("normal", sb)
	var hover_sb := StyleBoxFlat.new()
	hover_sb.bg_color = ACStyle.HOVER if not active else ACStyle.SAGE
	hover_sb.corner_radius_top_left = UiConfig.si(10)
	hover_sb.corner_radius_top_right = UiConfig.si(10)
	hover_sb.corner_radius_bottom_left = UiConfig.si(10)
	hover_sb.corner_radius_bottom_right = UiConfig.si(10)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_color_override("font_color", Color.WHITE if active else ACStyle.BROWN)


func _on_tab_pressed(idx: int):
	_switch_tab(idx)


func _switch_tab(idx: int):
	_active_tab = idx
	for i in _tab_btns.size():
		_style_tab_btn(_tab_btns[i], i == idx)
	for i in _tab_controls.size():
		var ctrl = _content_parent.get_child(i) if i < _content_parent.get_child_count() else null
		if ctrl:
			ctrl.visible = (i == idx)


# ── Content area ──

func _build_content():
	_content_parent = Control.new()
	_content_parent.name = "TabContent"
	_content_parent.mouse_filter = Control.MOUSE_FILTER_PASS
	panel_bg.add_child(_content_parent)
	_place_rect(_content_parent, _CONTENT_RECT)

	for tab_idx in TAB_NAMES.size():
		var container := VBoxContainer.new()
		container.name = "Tab%d" % tab_idx
		container.add_theme_constant_override("separation", UiConfig.si(14))
		container.visible = false
		_content_parent.add_child(container)

		match tab_idx:
			0: _build_general_tab(container, tab_idx)
			1: _build_chat_tab(container, tab_idx)
			2: _build_pomodoro_tab(container, tab_idx)
			3: _build_reminders_tab(container, tab_idx)


func _row(parent: Control, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiConfig.si(10))
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_color_override("font_color", ACStyle.BROWN)
	lbl.add_theme_font_size_override("font_size", UiConfig.si(13))
	lbl.custom_minimum_size = Vector2(UiConfig.s(72), 0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)
	parent.add_child(row)
	return row


# ── Tab 0: 通用 ──

func _build_general_tab(container: VBoxContainer, tab_idx: int):
	var row := _row(container, "UI缩放")
	var slider := HSlider.new()
	slider.min_value = 0.85
	slider.max_value = 1.5
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(UiConfig.s(160), 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v: float): _on_setting("ui.scale_multiplier", snappedf(v, 0.05)))
	row.add_child(slider)
	_tab_controls[tab_idx]["ui.scale_multiplier"] = slider

	var val_lbl := Label.new()
	val_lbl.name = "ScaleVal"
	val_lbl.add_theme_color_override("font_color", ACStyle.BROWN_LIGHT)
	val_lbl.add_theme_font_size_override("font_size", UiConfig.si(12))
	val_lbl.custom_minimum_size = Vector2(UiConfig.s(36), 0)
	row.add_child(val_lbl)
	slider.value_changed.connect(func(v: float): val_lbl.text = "%.2fx" % snappedf(v, 0.05))


# ── Tab 1: 对话 ──

func _build_chat_tab(container: VBoxContainer, tab_idx: int):
	# Model
	var row1 := _row(container, "模型")
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(UiConfig.s(160), 0)
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for m in MODELS:
		opt.add_item(m)
	opt.item_selected.connect(func(idx: int): _on_setting("chat.model", MODELS[idx]))
	row1.add_child(opt)
	_tab_controls[tab_idx]["chat.model"] = opt

	# Temperature
	var row2 := _row(container, "温度")
	var slider := HSlider.new()
	slider.min_value = 0.1
	slider.max_value = 1.5
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(UiConfig.s(160), 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v: float): _on_setting("chat.temperature", snappedf(v, 0.05)))
	row2.add_child(slider)
	_tab_controls[tab_idx]["chat.temperature"] = slider

	var val_lbl := Label.new()
	val_lbl.name = "TempVal"
	val_lbl.add_theme_color_override("font_color", ACStyle.BROWN_LIGHT)
	val_lbl.add_theme_font_size_override("font_size", UiConfig.si(12))
	val_lbl.custom_minimum_size = Vector2(UiConfig.s(36), 0)
	row2.add_child(val_lbl)
	slider.value_changed.connect(func(v: float): val_lbl.text = "%.2f" % snappedf(v, 0.05))


# ── Tab 2: 番茄钟 ──

func _build_pomodoro_tab(container: VBoxContainer, tab_idx: int):
	var specs := [
		["工作时间", "pomodoro.work_minutes", DURATIONS_WORK],
		["休息时间", "pomodoro.break_minutes", DURATIONS_BREAK],
		["长休息", "pomodoro.long_break_minutes", DURATIONS_BREAK],
		["长休间隔", "pomodoro.long_break_interval", INTERVALS],
	]
	for spec in specs:
		var label: String = spec[0]
		var key: String = spec[1]
		var options: Array = spec[2]
		var row := _row(container, label)
		var opt := OptionButton.new()
		opt.custom_minimum_size = Vector2(UiConfig.s(120), 0)
		for v in options:
			var suffix := "分钟" if "minutes" in key else "个番茄后"
			opt.add_item("%d%s" % [v, suffix])
		opt.item_selected.connect(func(idx: int, _o=options, _k=key): _on_setting(_k, _o[idx]))
		row.add_child(opt)
		_tab_controls[tab_idx][key] = opt


# ── Tab 3: 提醒 ──

func _build_reminders_tab(container: VBoxContainer, tab_idx: int):
	var specs := [
		["喝水提醒", "reminders.water_enabled", "reminders.water_interval_minutes"],
		["提肛提醒", "reminders.stretch_enabled", "reminders.stretch_interval_minutes"],
	]
	for spec in specs:
		var label: String = spec[0]
		var enable_key: String = spec[1]
		var interval_key: String = spec[2]
		var row := _row(container, label)

		var cb := CheckBox.new()
		cb.add_theme_font_size_override("font_size", UiConfig.si(13))
		row.add_child(cb)
		cb.toggled.connect(func(on: bool, _k=enable_key): _on_setting(_k, on))
		_tab_controls[tab_idx][enable_key] = cb

		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(UiConfig.s(8), 0)
		row.add_child(spacer)

		var int_lbl := Label.new()
		int_lbl.text = "每"
		int_lbl.add_theme_color_override("font_color", ACStyle.BROWN_LIGHT)
		int_lbl.add_theme_font_size_override("font_size", UiConfig.si(13))
		row.add_child(int_lbl)

		var opt := OptionButton.new()
		opt.custom_minimum_size = Vector2(UiConfig.s(84), 0)
		for v in REMINDER_INTERVALS:
			opt.add_item("%d分钟" % v)
		opt.item_selected.connect(func(idx: int, _o=REMINDER_INTERVALS, _k=interval_key): _on_setting(_k, _o[idx]))
		row.add_child(opt)
		_tab_controls[tab_idx][interval_key] = opt

# ── Settings sync ──

func _on_setting(key: String, value: Variant):
	# Debounce: send immediately, backend persists
	setting_changed.emit(key, value)


func populate(settings: Dictionary):
	"""Apply settings dict to all controls without emitting changes."""
	for tab_idx in _tab_controls.size():
		var ctrls: Dictionary = _tab_controls[tab_idx]
		for key in ctrls:
			var val = _get_nested(settings, key)
			if val == null:
				continue
			var node = ctrls[key]
			if node is HSlider:
				node.set_value_no_signal(float(val))
				# Update value label if present
				_update_slider_label(node, float(val))
			elif node is OptionButton:
				var idx := _option_index(key, val)
				if idx >= 0:
					node.select(idx)
			elif node is CheckBox:
				node.set_pressed_no_signal(bool(val))

	# UI scale also updates UiConfig
	var ui_scale: Variant = _get_nested(settings, "ui.scale_multiplier")
	if ui_scale != null:
		UiConfig.set_user_multiplier(float(ui_scale))


func _update_slider_label(slider: HSlider, val: float):
	var parent := slider.get_parent()
	if parent:
		for c in parent.get_children():
			if c is Label and (c.name.contains("Scale") or c.name.contains("Temp")):
				c.text = "%.2fx" % val if "Scale" in c.name else "%.2f" % val


func _option_index(key: String, val) -> int:
	match key:
		"chat.model": return MODELS.find(val)
		"pomodoro.work_minutes": return DURATIONS_WORK.find(int(val))
		"pomodoro.break_minutes": return DURATIONS_BREAK.find(int(val))
		"pomodoro.long_break_minutes": return DURATIONS_BREAK.find(int(val))
		"pomodoro.long_break_interval": return INTERVALS.find(int(val))
		"reminders.water_interval_minutes": return REMINDER_INTERVALS.find(int(val))
		"reminders.stretch_interval_minutes": return REMINDER_INTERVALS.find(int(val))
	return -1


func _get_nested(d: Dictionary, key: String) -> Variant:
	var parts := key.split(".")
	var node = d
	for p in parts:
		if node is Dictionary and p in node:
			node = node[p]
		else:
			return null
	return node
