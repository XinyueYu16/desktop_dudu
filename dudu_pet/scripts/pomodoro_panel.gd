class_name PomodoroPanel
extends Control

signal start_requested(task: String, duration_minutes: int)
signal pause_requested()
signal resume_requested()
signal abort_requested()
signal close_requested

const BASE_SIZE := Vector2(400, 480)
const DURATIONS := [15, 20, 25, 30, 45, 60]

const _TITLE_RECT := Vector4(12, 10, 388, 44)
const _CONTENT_RECT := Vector4(12, 52, 388, 430)
const _FOOTER_RECT := Vector4(12, 436, 388, 470)

@onready var panel_bg: Panel = $PanelBg
@onready var title_bar: MarginContainer = $PanelBg/TitleBar
@onready var title_label: Label = $PanelBg/TitleBar/TitleHBox/TitleLabel
@onready var close_btn: Button = $PanelBg/TitleBar/TitleHBox/CloseBtn

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _body: VBoxContainer = null
var _task_edit: LineEdit = null
var _duration_opt: OptionButton = null
var _timer_lbl: Label = null
var _state_lbl: Label = null
var _start_btn: Button = null
var _pause_btn: Button = null
var _abort_btn: Button = null
var _inventory_grid: GridContainer = null
var _state: String = "idle"
var _inventory: Array = []


func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_STOP
	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	title_bar.gui_input.connect(_on_title_bar_input)
	close_btn.pressed.connect(func(): close_requested.emit(); hide())
	title_label.text = "🍅 番茄钟"
	_build_body()
	apply_ui_scale()


func apply_ui_scale() -> void:
	scale = Vector2.ONE
	var w := UiConfig.si(int(BASE_SIZE.x))
	var h := UiConfig.si(int(BASE_SIZE.y))
	custom_minimum_size = Vector2(w, h)
	size = Vector2(w, h)
	_layout_chrome()
	_apply_style()


func visual_size() -> Vector2:
	return size


func _layout_chrome() -> void:
	_place_rect(title_bar, _TITLE_RECT)
	if _body:
		_place_rect(_body.get_parent() as Control, _CONTENT_RECT)


func _place_rect(node: Control, rect: Vector4) -> void:
	node.offset_left = UiConfig.s(rect.x)
	node.offset_top = UiConfig.s(rect.y)
	node.offset_right = UiConfig.s(rect.z)
	node.offset_bottom = UiConfig.s(rect.w)


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
	if _task_edit:
		ACStyle.apply_line_edit_theme(_task_edit)
	if _duration_opt:
		ACStyle.apply_option_button_theme(_duration_opt)
	for btn in [_start_btn, _pause_btn, _abort_btn]:
		if btn:
			ACStyle.apply_footer_button_theme(btn, false)


func _build_body() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel_bg.add_child(scroll)

	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", UiConfig.si(12))
	scroll.add_child(_body)

	var hint := Label.new()
	hint.text = "专注时嘟嘟会缩到角落，完成可能带回小物件~"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", ACStyle.BROWN_LIGHT)
	hint.add_theme_font_size_override("font_size", UiConfig.si(12))
	_body.add_child(hint)

	var task_row := HBoxContainer.new()
	task_row.add_theme_constant_override("separation", UiConfig.si(8))
	var task_lbl := Label.new()
	task_lbl.text = "专注任务"
	task_lbl.add_theme_color_override("font_color", ACStyle.BROWN)
	_body.add_child(task_row)
	task_row.add_child(task_lbl)
	_task_edit = LineEdit.new()
	_task_edit.placeholder_text = "写代码、看书…"
	_task_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	task_row.add_child(_task_edit)

	var dur_row := HBoxContainer.new()
	dur_row.add_theme_constant_override("separation", UiConfig.si(8))
	var dur_lbl := Label.new()
	dur_lbl.text = "时长"
	dur_lbl.add_theme_color_override("font_color", ACStyle.BROWN)
	_body.add_child(dur_row)
	dur_row.add_child(dur_lbl)
	_duration_opt = OptionButton.new()
	for m in DURATIONS:
		_duration_opt.add_item("%d 分钟" % m)
	_duration_opt.select(DURATIONS.find(25))
	dur_row.add_child(_duration_opt)

	_timer_lbl = Label.new()
	_timer_lbl.text = "25:00"
	_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_lbl.add_theme_font_size_override("font_size", UiConfig.si(28))
	_timer_lbl.add_theme_color_override("font_color", ACStyle.BROWN)
	_body.add_child(_timer_lbl)

	_state_lbl = Label.new()
	_state_lbl.text = "准备开始"
	_state_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_state_lbl.add_theme_color_override("font_color", ACStyle.BROWN_LIGHT)
	_state_lbl.add_theme_font_size_override("font_size", UiConfig.si(13))
	_body.add_child(_state_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", UiConfig.si(8))
	_body.add_child(btn_row)

	_start_btn = Button.new()
	_start_btn.text = "开始探索"
	_start_btn.pressed.connect(_on_start)
	btn_row.add_child(_start_btn)

	_pause_btn = Button.new()
	_pause_btn.text = "暂停"
	_pause_btn.hide()
	_pause_btn.pressed.connect(_on_pause_toggle)
	btn_row.add_child(_pause_btn)

	_abort_btn = Button.new()
	_abort_btn.text = "中止"
	_abort_btn.hide()
	_abort_btn.pressed.connect(func(): abort_requested.emit())
	btn_row.add_child(_abort_btn)

	var inv_title := Label.new()
	inv_title.text = "🎒 背包"
	inv_title.add_theme_color_override("font_color", ACStyle.BROWN)
	inv_title.add_theme_font_size_override("font_size", UiConfig.si(14))
	_body.add_child(inv_title)

	_inventory_grid = GridContainer.new()
	_inventory_grid.columns = 4
	_inventory_grid.add_theme_constant_override("h_separation", UiConfig.si(6))
	_inventory_grid.add_theme_constant_override("v_separation", UiConfig.si(6))
	_body.add_child(_inventory_grid)

	_layout_chrome()


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


func set_inventory(items: Array) -> void:
	_inventory = items.duplicate(true)
	_rebuild_inventory()


func update_state(state: Dictionary) -> void:
	_state = str(state.get("state", "idle"))
	var remaining := int(state.get("remaining_sec", 0))
	var total := int(state.get("total", 0))
	if total <= 0 and _duration_opt:
		total = DURATIONS[_duration_opt.selected] * 60
	_timer_lbl.text = _format_time(remaining if _state == "focusing" else total)
	var paused := bool(state.get("paused", false))
	match _state:
		"idle":
			_state_lbl.text = "准备开始"
			_start_btn.show()
			_start_btn.text = "开始探索"
			_pause_btn.hide()
			_abort_btn.hide()
			_task_edit.editable = true
			_duration_opt.disabled = false
		"focusing":
			_state_lbl.text = "嘟嘟在角落蹲守…" if not paused else "已暂停"
			_start_btn.hide()
			_pause_btn.show()
			_abort_btn.show()
			_pause_btn.text = "继续" if paused else "暂停"
			_task_edit.editable = false
			_duration_opt.disabled = true


func update_tick(payload: Dictionary) -> void:
	var remaining := int(payload.get("remaining", 0))
	_timer_lbl.text = _format_time(remaining)
	var paused := str(payload.get("phase", "")) == "paused"
	_state_lbl.text = "已暂停" if paused else "专注中…"


func _format_time(sec: int) -> String:
	sec = maxi(0, sec)
	return "%02d:%02d" % [sec / 60, sec % 60]


func _rebuild_inventory() -> void:
	for c in _inventory_grid.get_children():
		c.queue_free()
	if _inventory.is_empty():
		var empty := Label.new()
		empty.text = "还没有战利品，完成番茄钟试试~"
		empty.add_theme_color_override("font_color", ACStyle.BROWN_LIGHT)
		empty.add_theme_font_size_override("font_size", UiConfig.si(12))
		_inventory_grid.add_child(empty)
		return
	for item in _inventory:
		var cell := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.5)
		sb.set_corner_radius_all(UiConfig.si(8))
		sb.content_margin_left = UiConfig.si(6)
		sb.content_margin_right = UiConfig.si(6)
		sb.content_margin_top = UiConfig.si(4)
		sb.content_margin_bottom = UiConfig.si(4)
		cell.add_theme_stylebox_override("panel", sb)
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_child(v)
		var emoji := Label.new()
		emoji.text = str(item.get("emoji", "📦"))
		emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emoji.add_theme_font_size_override("font_size", UiConfig.si(20))
		v.add_child(emoji)
		var name_lbl := Label.new()
		name_lbl.text = str(item.get("name", ""))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", UiConfig.si(10))
		name_lbl.add_theme_color_override("font_color", ACStyle.BROWN)
		v.add_child(name_lbl)
		var cnt := Label.new()
		cnt.text = "×%d" % int(item.get("count", 1))
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cnt.add_theme_font_size_override("font_size", UiConfig.si(9))
		cnt.add_theme_color_override("font_color", ACStyle.BROWN_LIGHT)
		v.add_child(cnt)
		_inventory_grid.add_child(cell)


func _on_start() -> void:
	var task := _task_edit.text.strip_edges()
	if task.is_empty():
		task = "专注"
	var mins: int = DURATIONS[_duration_opt.selected]
	start_requested.emit(task, mins)


func _on_pause_toggle() -> void:
	if _pause_btn.text == "暂停":
		pause_requested.emit()
	else:
		resume_requested.emit()


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
