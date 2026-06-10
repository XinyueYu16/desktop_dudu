class_name SettingsPanel
extends Control

# Tabbed settings panel — 动森风格.
# All config exposed: General, Chat, Pomodoro, Reminders.
# Changes sent to backend immediately via signal.

signal setting_changed(key: String, value: Variant)
signal save_requested(pending: Dictionary)
signal close_requested
signal clear_history_requested

const BASE_SIZE := Vector2(400, 540)
const TAB_NAMES := ["🖼 通用", "💬 对话", "🍅 番茄", "🔔 提醒"]
const TAB_HINTS := [
	"调整界面大小，让嘟嘟刚好待在桌面上",
	"配置 DeepSeek API、V4 模型与喵设提示词",
	"专注与休息的节奏",
	"定时温柔提醒，记得喝水和活动",
]
const TAB_KEYS := ["ui", "chat", "pomodoro", "reminders"]

# Design rects — title + fixed tabs + scroll content + footer
const _TITLE_RECT := Vector4(12, 10, 388, 44)
const _TAB_ROW_RECT := Vector4(12, 50, 388, 84)
const _DIVIDER_RECT := Vector4(16, 88, 384, 89)
const _CONTENT_SCROLL_RECT := Vector4(12, 94, 388, 488)
const _FOOTER_RECT := Vector4(12, 492, 388, 528)

const _SETTING_DEFAULTS := {
	"ui.scale_multiplier": 1.0,
	"chat.temperature": 0.8,
}

@onready var panel_bg: Panel = $PanelBg
@onready var title_bar: MarginContainer = $PanelBg/TitleBar
@onready var title_label: Label = $PanelBg/TitleBar/TitleHBox/TitleLabel
@onready var close_btn: Button = $PanelBg/TitleBar/TitleHBox/CloseBtn

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _active_tab: int = 0
var _tab_btns: Array[Button] = []
var _tab_row: HBoxContainer = null
var _main_scroll: ScrollContainer = null
var _tab_divider: Panel = null
var _content_parent: VBoxContainer = null
var _footer: HBoxContainer = null
var _save_btn: Button = null
var _clear_confirm: ConfirmationDialog = null
var _tab_controls: Array = [{}, {}, {}, {}]  # {key: control_node}
var _pending_settings: Dictionary = {}

# ── Model / duration option maps ──
const CHAT_MODEL_IDS := ["deepseek-v4-flash", "deepseek-v4-pro"]
const CHAT_MODEL_LABELS := ["V4 Flash · 快速", "V4 Pro · 旗舰"]
const LEGACY_CHAT_MODELS := {
	"deepseek-chat": "deepseek-v4-flash",
	"deepseek-reasoner": "deepseek-v4-pro",
}
const DURATIONS_WORK := [15, 20, 25, 30, 45, 60]
const DURATIONS_BREAK := [5, 10, 15, 20]
const INTERVALS := [2, 3, 4, 5]
const REMINDER_INTERVALS := [15, 30, 45, 60, 90, 120]


func _ready():
	hide()
	mouse_filter = Control.MOUSE_FILTER_STOP
	apply_ui_scale()
	_build_tab_row()
	_build_main_scroll()
	_build_content()
	_build_footer()
	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	title_bar.gui_input.connect(_on_title_bar_input)
	close_btn.pressed.connect(func(): close_requested.emit(); hide())
	_switch_tab(0)
	_apply_control_styles()
	call_deferred("_sync_content_layout")


func apply_ui_scale() -> void:
	scale = Vector2.ONE
	var w := UiConfig.si(int(BASE_SIZE.x))
	var h := UiConfig.si(int(BASE_SIZE.y))
	custom_minimum_size = Vector2(w, h)
	size = Vector2(w, h)
	_layout_chrome()
	_apply_style()
	_refresh_tab_chrome()
	_refresh_scaled_content()
	_apply_control_styles()
	_apply_scroll_theme()
	_sync_content_layout()
	call_deferred("_sync_content_layout")


func _layout_chrome() -> void:
	_place_rect(title_bar, _TITLE_RECT)
	if _tab_row:
		_place_rect(_tab_row, _TAB_ROW_RECT)
		_tab_row.add_theme_constant_override("separation", UiConfig.si(6))
	if _tab_divider:
		_place_rect(_tab_divider, _DIVIDER_RECT)
	if _main_scroll:
		_place_rect(_main_scroll, _CONTENT_SCROLL_RECT)
	if _footer:
		_place_rect(_footer, _FOOTER_RECT)


func _place_rect(node: Control, rect: Vector4) -> void:
	node.offset_left = UiConfig.s(rect.x)
	node.offset_top = UiConfig.s(rect.y)
	node.offset_right = UiConfig.s(rect.z)
	node.offset_bottom = UiConfig.s(rect.w)


func _apply_style():
	var panel_sb := ACStyle.panel_card_stylebox()
	panel_sb.bg_color = Color(ACStyle.CREAM.r, ACStyle.CREAM.g, ACStyle.CREAM.b, 0.98)
	panel_bg.add_theme_stylebox_override("panel", panel_sb)
	title_label.text = "⚙ 嘟嘟设置"
	title_label.add_theme_color_override("font_color", ACStyle.BROWN)
	title_label.add_theme_font_size_override("font_size", UiConfig.si(15))
	close_btn.flat = true
	close_btn.add_theme_stylebox_override("normal", ACStyle.icon_button_stylebox())
	close_btn.add_theme_stylebox_override("hover", ACStyle.icon_button_stylebox(true))
	close_btn.add_theme_stylebox_override("pressed", ACStyle.icon_button_stylebox(true))
	close_btn.add_theme_color_override("font_color", ACStyle.BROWN_LIGHT)
	close_btn.add_theme_font_size_override("font_size", UiConfig.si(16))
	close_btn.custom_minimum_size = Vector2(UiConfig.s(28), UiConfig.s(28))
	if _tab_divider:
		_tab_divider.add_theme_stylebox_override("panel", ACStyle.divider_stylebox())
	for i in _tab_btns.size():
		_style_tab_btn(_tab_btns[i], i == _active_tab)
	if _save_btn:
		var saved_look := _save_btn.disabled and _pending_settings.is_empty()
		_style_save_button(saved_look)


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
	call_deferred("_sync_content_layout")


func _build_footer() -> void:
	_footer = HBoxContainer.new()
	_footer.name = "Footer"
	_footer.alignment = BoxContainer.ALIGNMENT_END
	panel_bg.add_child(_footer)
	_place_rect(_footer, _FOOTER_RECT)

	_save_btn = Button.new()
	_save_btn.text = "已保存 ✓"
	_save_btn.disabled = true
	_save_btn.pressed.connect(_flush_pending)
	_footer.add_child(_save_btn)
	_style_save_button(true)


func _style_save_button(saved: bool) -> void:
	if not _save_btn:
		return
	_save_btn.flat = true
	_save_btn.add_theme_stylebox_override("normal", ACStyle.save_button_stylebox(saved))
	_save_btn.add_theme_stylebox_override("hover", ACStyle.save_button_stylebox(saved, true))
	_save_btn.add_theme_stylebox_override("pressed", ACStyle.save_button_stylebox(saved, true))
	_save_btn.add_theme_stylebox_override("disabled", ACStyle.save_button_stylebox(saved))
	_save_btn.add_theme_font_size_override("font_size", UiConfig.si(13))
	_save_btn.custom_minimum_size = Vector2(UiConfig.s(88), UiConfig.s(32))
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		_save_btn.add_theme_color_override(key, ACStyle.BROWN)


func _mark_dirty() -> void:
	if not _save_btn:
		return
	_save_btn.text = "保存"
	_save_btn.disabled = false
	_style_save_button(false)


func mark_saved() -> void:
	_pending_settings.clear()
	if not _save_btn:
		return
	_save_btn.text = "已保存 ✓"
	_save_btn.disabled = true
	_style_save_button(true)


func mark_save_failed() -> void:
	if not _save_btn:
		return
	if _pending_settings.is_empty():
		mark_saved()
	else:
		_save_btn.text = "保存"
		_save_btn.disabled = false
		_style_save_button(false)


func _flush_pending() -> void:
	_flush_prompt_edits()
	if _pending_settings.is_empty():
		mark_saved()
		return
	_save_btn.text = "保存中..."
	_save_btn.disabled = true
	save_requested.emit(_pending_settings.duplicate())


# ── Tab row ──

func _build_tab_row():
	_tab_row = HBoxContainer.new()
	_tab_row.name = "TabRow"
	_tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_tab_row.add_theme_constant_override("separation", UiConfig.si(6))
	panel_bg.add_child(_tab_row)
	_place_rect(_tab_row, _TAB_ROW_RECT)

	_tab_divider = Panel.new()
	_tab_divider.name = "TabDivider"
	_tab_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_bg.add_child(_tab_divider)
	_place_rect(_tab_divider, _DIVIDER_RECT)

	for i in TAB_NAMES.size():
		var btn := Button.new()
		btn.text = TAB_NAMES[i]
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(UiConfig.s(72), UiConfig.s(30))
		btn.add_theme_font_size_override("font_size", UiConfig.si(12))
		btn.pressed.connect(_on_tab_pressed.bind(i))
		_tab_row.add_child(btn)
		_tab_btns.append(btn)
		_style_tab_btn(btn, i == 0)


func _style_tab_btn(btn: Button, active: bool) -> void:
	var sb := ACStyle.tab_stylebox(active)
	var sb_hover := ACStyle.tab_stylebox(active, true)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_hover)
	btn.add_theme_stylebox_override("focus", sb)
	btn.add_theme_stylebox_override("disabled", sb)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		btn.add_theme_color_override(key, ACStyle.BROWN)


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


# ── Scrollable tab content (tabs stay fixed above) ──

func _apply_scroll_theme() -> void:
	if _main_scroll:
		ACStyle.apply_scroll_container_theme(_main_scroll)


func _build_main_scroll() -> void:
	_main_scroll = ScrollContainer.new()
	_main_scroll.name = "ContentScroll"
	_main_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_main_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_main_scroll.follow_focus = true
	_main_scroll.resized.connect(_sync_content_layout)
	panel_bg.add_child(_main_scroll)
	_place_rect(_main_scroll, _CONTENT_SCROLL_RECT)
	call_deferred("_apply_scroll_theme")

	_content_parent = VBoxContainer.new()
	_content_parent.name = "TabContent"
	_content_parent.mouse_filter = Control.MOUSE_FILTER_PASS
	_content_parent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_scroll.add_child(_content_parent)


func _build_content():

	for tab_idx in TAB_NAMES.size():
		var container := VBoxContainer.new()
		container.name = "Tab%d" % tab_idx
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.add_theme_constant_override("separation", UiConfig.si(10))
		container.visible = false
		_content_parent.add_child(container)
		_section_header(container, TAB_HINTS[tab_idx])

		match tab_idx:
			0: _build_general_tab(container, tab_idx)
			1: _build_chat_tab(container, tab_idx)
			2: _build_pomodoro_tab(container, tab_idx)
			3: _build_reminders_tab(container, tab_idx)

	call_deferred("_sync_content_layout")


func _content_scroll_width() -> float:
	return UiConfig.s(_CONTENT_SCROLL_RECT.z - _CONTENT_SCROLL_RECT.x)


func _content_child_width() -> float:
	var pad := UiConfig.s(4.0)
	return maxf(0.0, _content_scroll_width() - pad)


func _sync_content_layout() -> void:
	if not _main_scroll or not _content_parent:
		return
	var inner_w := _content_child_width()
	_content_parent.custom_minimum_size.x = inner_w
	for child in _content_parent.get_children():
		if child is Control:
			(child as Control).custom_minimum_size.x = inner_w


func _section_header(parent: VBoxContainer, hint: String) -> void:
	var sub := Label.new()
	sub.text = hint
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.add_theme_color_override("font_color", ACStyle.BROWN)
	sub.add_theme_font_size_override("font_size", UiConfig.si(12))
	sub.custom_minimum_size = Vector2(0, UiConfig.s(30))
	parent.add_child(sub)


func _row(parent: Control, label_text: String) -> HBoxContainer:
	var card := PanelContainer.new()
	card.clip_contents = true
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", ACStyle.settings_row_stylebox())
	parent.add_child(card)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiConfig.si(8))
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_color_override("font_color", ACStyle.BROWN)
	lbl.add_theme_font_size_override("font_size", UiConfig.si(14))
	lbl.custom_minimum_size = Vector2(UiConfig.s(76), 0)
	lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)
	return row


func _refresh_tab_chrome() -> void:
	for i in _tab_btns.size():
		var btn := _tab_btns[i]
		btn.custom_minimum_size = Vector2(UiConfig.s(72), UiConfig.s(30))
		btn.add_theme_font_size_override("font_size", UiConfig.si(12))
		_style_tab_btn(btn, i == _active_tab)


func _refresh_scaled_content() -> void:
	if not _content_parent:
		return
	for tab in _content_parent.get_children():
		if tab is VBoxContainer:
			_refresh_tab_container(tab as VBoxContainer)


func _refresh_tab_container(tab: VBoxContainer) -> void:
	tab.add_theme_constant_override("separation", UiConfig.si(10))
	for child in tab.get_children():
		if child is Label:
			var hint := child as Label
			hint.add_theme_font_size_override("font_size", UiConfig.si(12))
			hint.custom_minimum_size = Vector2(0, UiConfig.s(30))
		elif child is PanelContainer:
			_refresh_setting_row(child as PanelContainer)


func _refresh_setting_row(card: PanelContainer) -> void:
	card.add_theme_stylebox_override("panel", ACStyle.settings_row_stylebox())
	if card.get_child_count() == 0:
		return
	var inner := card.get_child(0)
	if inner is HBoxContainer:
		var row := inner as HBoxContainer
		row.add_theme_constant_override("separation", UiConfig.si(8))
		for c in row.get_children():
			if c is Label:
				var lbl := c as Label
				var is_value := lbl.name.contains("Scale") or lbl.name.contains("Temp")
				lbl.add_theme_font_size_override("font_size", UiConfig.si(13 if is_value else 14))
				lbl.custom_minimum_size = Vector2(UiConfig.s(48 if is_value else 76), 0)
			elif c is Control and c.get_child_count() > 0 and c.get_child(0) is HSlider:
				var host := c as Control
				host.custom_minimum_size = Vector2(0, UiConfig.s(28))
				ACStyle.apply_slider_theme(c.get_child(0) as HSlider)
			elif c is LineEdit:
				ACStyle.apply_line_edit_theme(c as LineEdit)
	elif inner is VBoxContainer:
		var box := inner as VBoxContainer
		box.add_theme_constant_override("separation", UiConfig.si(6))
		for c in box.get_children():
			if c is Label:
				(c as Label).add_theme_font_size_override("font_size", UiConfig.si(13))
			elif c is TextEdit:
				var te := c as TextEdit
				var mh: float = te.get_meta("prompt_min_h", 72.0)
				te.custom_minimum_size = Vector2(0, UiConfig.s(mh))
				ACStyle.apply_text_edit_theme(te)


func _value_label(parent: HBoxContainer) -> Label:
	var val_lbl := Label.new()
	val_lbl.add_theme_color_override("font_color", ACStyle.SAGE)
	val_lbl.add_theme_font_size_override("font_size", UiConfig.si(13))
	val_lbl.custom_minimum_size = Vector2(UiConfig.s(48), 0)
	val_lbl.size_flags_horizontal = Control.SIZE_SHRINK_END
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(val_lbl)
	return val_lbl


func _add_slider_to_row(row: HBoxContainer) -> HSlider:
	var host := Control.new()
	host.clip_contents = true
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.size_flags_stretch_ratio = 1.0
	host.custom_minimum_size.y = UiConfig.s(30)
	row.add_child(host)
	var slider := HSlider.new()
	slider.set_anchors_preset(Control.PRESET_FULL_RECT)
	slider.offset_left = 0
	slider.offset_right = 0
	slider.offset_top = 0
	slider.offset_bottom = 0
	host.add_child(slider)
	return slider


func _apply_control_styles() -> void:
	for tab_idx in _tab_controls.size():
		var ctrls: Dictionary = _tab_controls[tab_idx]
		for key in ctrls:
			var node = ctrls[key]
			if node is HSlider:
				ACStyle.apply_slider_theme(node)
			elif node is OptionButton:
				ACStyle.apply_option_button_theme(node)
			elif node is LineEdit:
				ACStyle.apply_line_edit_theme(node)
			elif node is TextEdit:
				ACStyle.apply_text_edit_theme(node)
			elif node is CheckBox:
				ACStyle.apply_checkbox_theme(node)


# ── Tab 0: 通用 ──

func _build_general_tab(container: VBoxContainer, tab_idx: int):
	var row := _row(container, "UI缩放")
	var slider := _add_slider_to_row(row)
	slider.min_value = 0.85
	slider.max_value = 1.5
	slider.step = 0.05
	slider.value = _SETTING_DEFAULTS["ui.scale_multiplier"]
	slider.value_changed.connect(func(v: float): _stage_setting("ui.scale_multiplier", snappedf(v, 0.05)))
	_tab_controls[tab_idx]["ui.scale_multiplier"] = slider

	var val_lbl := _value_label(row)
	val_lbl.name = "ScaleVal"
	val_lbl.text = "%.2fx" % slider.value
	slider.value_changed.connect(func(v: float): val_lbl.text = "%.2fx" % snappedf(v, 0.05))


# ── Tab 1: 对话 ──

func _build_chat_tab(container: VBoxContainer, tab_idx: int):
	_add_line_edit_row(
		container, tab_idx, "API 地址", "chat.api_base",
		false, "https://api.deepseek.com"
	)

	var row1 := _row(container, "模型")
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for label in CHAT_MODEL_LABELS:
		opt.add_item(label)
	opt.item_selected.connect(func(idx: int): _stage_setting("chat.model", CHAT_MODEL_IDS[idx]))
	row1.add_child(opt)
	_tab_controls[tab_idx]["chat.model"] = opt

	_add_line_edit_row(
		container, tab_idx, "API Key", "chat.api_key",
		true, "sk-..."
	)

	var row2 := _row(container, "温度")
	var slider := _add_slider_to_row(row2)
	slider.min_value = 0.1
	slider.max_value = 1.5
	slider.step = 0.05
	slider.value = _SETTING_DEFAULTS["chat.temperature"]
	slider.value_changed.connect(func(v: float): _stage_setting("chat.temperature", snappedf(v, 0.05)))
	_tab_controls[tab_idx]["chat.temperature"] = slider

	var val_lbl := _value_label(row2)
	val_lbl.name = "TempVal"
	val_lbl.text = "%.2f" % slider.value
	slider.value_changed.connect(func(v: float): val_lbl.text = "%.2f" % snappedf(v, 0.05))

	_add_prompt_section(container, tab_idx, "喵设提示词", "prompts.system", 200)
	_add_prompt_section(container, tab_idx, "工具纪律（可选）", "prompts.tools_discipline", 64)
	_add_prompt_section(container, tab_idx, "运势模式追加", "prompts.fortune_append", 64)
	_add_prompt_section(container, tab_idx, "探索模式追加", "prompts.explore_append", 64)
	_add_clear_history_button(container)


func _add_clear_history_button(parent: VBoxContainer) -> void:
	if _clear_confirm == null:
		_clear_confirm = ConfirmationDialog.new()
		_clear_confirm.title = "清空聊天记录"
		_clear_confirm.dialog_text = "确定要清空所有聊天记录吗？\n此操作不可恢复。"
		_clear_confirm.ok_button_text = "清空"
		_clear_confirm.cancel_button_text = "取消"
		_clear_confirm.confirmed.connect(func(): clear_history_requested.emit())
		add_child(_clear_confirm)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, UiConfig.s(8))
	parent.add_child(spacer)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)

	var btn := Button.new()
	btn.text = "清空聊天记录"
	btn.focus_mode = Control.FOCUS_NONE
	btn.flat = false
	btn.custom_minimum_size = Vector2(UiConfig.s(160), UiConfig.s(36))
	btn.add_theme_font_size_override("font_size", UiConfig.si(13))
	btn.add_theme_stylebox_override("normal", ACStyle.danger_button_stylebox(false))
	btn.add_theme_stylebox_override("hover", ACStyle.danger_button_stylebox(true))
	btn.add_theme_stylebox_override("pressed", ACStyle.danger_button_stylebox(true))
	btn.add_theme_stylebox_override("focus", ACStyle.danger_button_stylebox(false))
	btn.add_theme_stylebox_override("disabled", ACStyle.danger_button_stylebox(false))
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		btn.add_theme_color_override(key, Color.WHITE)
	btn.pressed.connect(func(): _clear_confirm.popup_centered())
	row.add_child(btn)


func _add_prompt_section(
	parent: VBoxContainer,
	tab_idx: int,
	title: String,
	key: String,
	min_height: float
) -> TextEdit:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", ACStyle.settings_row_stylebox())
	parent.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UiConfig.si(6))
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(box)

	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_color_override("font_color", ACStyle.BROWN)
	lbl.add_theme_font_size_override("font_size", UiConfig.si(13))
	box.add_child(lbl)

	var edit := TextEdit.new()
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.scroll_fit_content_height = false
	edit.custom_minimum_size = Vector2(0, UiConfig.s(min_height))
	edit.set_meta("prompt_min_h", min_height)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(func(): _mark_dirty())
	edit.focus_exited.connect(func(): _commit_text_edit(key, edit))
	box.add_child(edit)
	_tab_controls[tab_idx][key] = edit
	return edit


func _commit_text_edit(key: String, edit: TextEdit) -> void:
	_stage_setting(key, edit.text)


func _flush_prompt_edits() -> void:
	for tab_idx in _tab_controls.size():
		var ctrls: Dictionary = _tab_controls[tab_idx]
		for key in ctrls:
			if not str(key).begins_with("prompts."):
				continue
			var node = ctrls[key]
			if node is TextEdit:
				_stage_setting(key, (node as TextEdit).text)


func _add_line_edit_row(
	parent: VBoxContainer,
	tab_idx: int,
	label: String,
	key: String,
	secret: bool,
	placeholder: String
) -> LineEdit:
	var row := _row(parent, label)
	var edit := LineEdit.new()
	edit.secret = secret
	edit.placeholder_text = placeholder
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.focus_exited.connect(func(): _commit_line_edit(key, edit))
	edit.text_submitted.connect(func(_t): _commit_line_edit(key, edit))
	row.add_child(edit)
	_tab_controls[tab_idx][key] = edit
	return edit


func _commit_line_edit(key: String, edit: LineEdit) -> void:
	_stage_setting(key, edit.text.strip_edges())


func _normalize_chat_model(model_id: String) -> String:
	if LEGACY_CHAT_MODELS.has(model_id):
		return LEGACY_CHAT_MODELS[model_id]
	return model_id


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
		opt.item_selected.connect(func(idx: int, _o=options, _k=key): _stage_setting(_k, _o[idx]))
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
		row.add_child(cb)
		cb.toggled.connect(func(on: bool, _k=enable_key): _stage_setting(_k, on))
		_tab_controls[tab_idx][enable_key] = cb

		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(UiConfig.s(8), 0)
		row.add_child(spacer)

		var int_lbl := Label.new()
		int_lbl.text = "每"
		int_lbl.add_theme_color_override("font_color", ACStyle.BROWN_LIGHT)
		int_lbl.add_theme_font_size_override("font_size", UiConfig.si(14))
		row.add_child(int_lbl)

		var opt := OptionButton.new()
		opt.custom_minimum_size = Vector2(UiConfig.s(84), 0)
		for v in REMINDER_INTERVALS:
			opt.add_item("%d分钟" % v)
		opt.item_selected.connect(func(idx: int, _o=REMINDER_INTERVALS, _k=interval_key): _stage_setting(_k, _o[idx]))
		row.add_child(opt)
		_tab_controls[tab_idx][interval_key] = opt

# ── Settings sync ──

func _stage_setting(key: String, value: Variant) -> void:
	_pending_settings[key] = value
	_mark_dirty()
	if key == "ui.scale_multiplier":
		setting_changed.emit(key, value)


func populate(settings: Dictionary):
	"""Apply settings dict to all controls without emitting changes."""
	for tab_idx in _tab_controls.size():
		var ctrls: Dictionary = _tab_controls[tab_idx]
		for key in ctrls:
			var val: Variant = _get_nested(settings, key)
			if val == null and _SETTING_DEFAULTS.has(key):
				val = _SETTING_DEFAULTS[key]
			if val == null:
				continue
			var node = ctrls[key]
			if node is HSlider:
				node.set_value_no_signal(float(val))
				_update_slider_label(node, float(val))
			elif node is OptionButton:
				var idx := _option_index(key, val)
				if idx >= 0:
					node.select(idx)
			elif node is LineEdit:
				node.text = str(val)
			elif node is TextEdit:
				node.text = str(val)
			elif node is CheckBox:
				node.set_pressed_no_signal(bool(val))

	var ui_scale: Variant = _get_nested(settings, "ui.scale_multiplier")
	if ui_scale != null:
		var f := float(ui_scale)
		if not is_equal_approx(f, UiConfig.user_multiplier):
			UiConfig.set_user_multiplier(f)
	mark_saved()


func _update_slider_label(slider: HSlider, val: float) -> void:
	var row := _slider_row(slider)
	if row == null:
		return
	for c in row.get_children():
		if c is Label and (c.name.contains("Scale") or c.name.contains("Temp")):
			c.text = "%.2fx" % val if "Scale" in c.name else "%.2f" % val


func _slider_row(slider: HSlider) -> HBoxContainer:
	var host := slider.get_parent()
	if host == null:
		return null
	var row := host.get_parent()
	if row is HBoxContainer:
		return row as HBoxContainer
	return null


func _option_index(key: String, val) -> int:
	match key:
		"chat.model": return CHAT_MODEL_IDS.find(_normalize_chat_model(str(val)))
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
