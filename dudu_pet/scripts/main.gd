extends Control

# DuDu Pet — Main controller
# Window, cat sprite, WebSocket, circular menu, chat panel, hover input.

# Nodes
@onready var cat: TextureRect = $CatTexture
@onready var cat_sprite: AnimatedSprite2D = $CatSprite
@onready var speech_bubble: PanelContainer = $SpeechBubble
@onready var bubble: Label = $SpeechBubble/BubbleLabel
@onready var circ_menu: Control = $CircularMenu
var chat_panel: ChatPanel = null
var settings_panel: SettingsPanel = null
var reminders_panel: RemindersPanel = null
var todos_panel: TodosPanel = null
var pomodoro_panel: PomodoroPanel = null
var stargazing_panel: StargazingPanel = null

# Window
var dragging: bool = false
var drag_mouse_start: Vector2i = Vector2i.ZERO
var drag_window_start: Vector2i = Vector2i.ZERO

# WebSocket
var ws: WebSocketPeer = WebSocketPeer.new()
const WS_URL: String = "ws://127.0.0.1:9876"
var _ws_retry_ts: int = 0
var _backend_pid: int = -1

# Animation
enum Anim { IDLE, TALKING, HAPPY, BITE, FAINT }
var current_anim: Anim = Anim.IDLE
var _anim_lock: bool = false
var _breathe_tween: Tween = null
var _idle_loop_gen: int = 0
const SPRITE_SHEET_DIR: String = "../assets/sprite sheet/"

# Hover input
var _hover_input: PanelContainer = null
var _hover_text: TextEdit = null
var _hovering: bool = false
var _stack_shown_at: int = 0
var _stack_tween: Tween = null
var _stack_hide_gen: int = 0
var _chat_session_active: bool = false

# Streaming state
var _streaming_bubble: bool = false
var _stream_buffer: String = ""
var _floating_assistant_added: bool = false
var _floating_bubbles: VBoxContainer = null
var _history_cache: Array = []

const MSG_BUBBLE = preload("res://scenes/message_bubble.tscn")
const ChatBubbleStyle = preload("res://scripts/chat_bubble_style.gd")
const CAT_PLACEHOLDER: Texture2D = preload("res://assets/sprites/cat.png")
const BASE_CAT_SIZE := 128.0
const BASE_SPACE_ABOVE_CAT := 380.0
const INPUT_GAP_ABOVE_CAT := 12.0
const BUBBLE_GAP_ABOVE_INPUT := 14.0
const BREATHE_PEAK_Y := 1.012
const BREATHE_PERIOD := 2.6
const IDLE_RANDOM_MIN := 90.0
const IDLE_RANDOM_MAX := 180.0
const TALKING_IDLE_SPEED_SCALE := 0.35
const STACK_SHOW_DELAY := 0.5
const STACK_MIN_VISIBLE_MS := 2000
const CHAT_REPLY_TIMEOUT := 90.0
const STARGAZING_TIMEOUT := 45.0

var _cat_base_height: float = 128.0
var _cat_center_x: float = 0.0
var _cat_bottom: float = 0.0
var _stack_layout_gen: int = 0
var _ws_was_open: bool = false
var _stargazing_pending: bool = false
var _stargazing_wait_gen: int = 0
var _settings_save_pending: bool = false
var _reminders_save_pending: bool = false
var _todos_save_pending: bool = false
var _pomodoro_focus_mode: bool = false
var _pomodoro_status_lbl: Label = null
var _pomodoro_status_task: String = ""
var _pomodoro_status_duration_mins: int = 0
var _active_reminder_id: String = ""
var _reminder_ack_row: HBoxContainer = null
var _reminder_alarm: Label = null
var _reminder_bubble_tween: Tween = null
var _chat_wait_gen: int = 0
# Match backend/settings.py DEFAULTS until settings.data arrives on connect
var _chat_toggles: Dictionary = {
	"thinking_enabled": true,
	"use_memory": true,
	"record_memory": true,
}

const _TOGGLE_SETTING_KEYS := {
	"toggle_thinking": "thinking_enabled",
	"toggle_memory": "use_memory",
	"toggle_record": "record_memory",
}


# ============================================================
# Init
# ============================================================

func _ready():
	_setup_cat_sprite()
	_setup_window()
	_style_speech_bubble()
	_create_hover_input()
	_create_floating_bubbles()
	_setup_chat_panel()
	_setup_settings_panel()
	_setup_reminders_panel()
	_setup_todos_panel()
	_setup_pomodoro_panel()
	_setup_stargazing_panel()
	_create_pomodoro_status_label()
	_apply_ui_scale_to_children()
	_apply_layer_order()
	_wire_signals()
	_play_anim(Anim.IDLE)
	_connect_ws()
	get_tree().create_timer(1.0).timeout.connect(_check_and_launch_backend)
	_start_idle_loop()
	print("DuDu Phase 2 started — window %s scale %.2f" % [UiConfig.window_size, UiConfig.scale])


func _style_speech_bubble():
	ChatBubbleStyle.apply_to_panel(speech_bubble, bubble, "assistant", true)
	bubble.custom_minimum_size = Vector2(UiConfig.s(180), 0)


func _cat_rect() -> Rect2:
	return cat.get_rect()


func _cat_center() -> Vector2:
	var r := _cat_rect()
	return r.position + r.size / 2.0


func _set_cat_breathe(sy: float) -> void:
	# Vertical only — width fixed, aspect preserved, feet pinned to bottom
	cat.scale = Vector2.ONE
	var w := _cat_base_height
	var h := _cat_base_height * sy
	cat.offset_left = _cat_center_x - w / 2.0
	cat.offset_right = _cat_center_x + w / 2.0
	cat.offset_top = _cat_bottom - h
	cat.offset_bottom = _cat_bottom


func _input_box_top() -> float:
	if _hover_input.visible and _hover_input.modulate.a > 0:
		return _hover_input.position.y
	var cat_rect := _cat_rect()
	var hh := UiConfig.s(36)
	if _hover_input:
		_hover_input.reset_size()
		hh = maxf(_hover_input.size.y, UiConfig.s(36))
	return cat_rect.position.y - hh - UiConfig.s(INPUT_GAP_ABOVE_CAT)


func _bubble_bottom_limit() -> float:
	return _input_box_top() - UiConfig.s(BUBBLE_GAP_ABOVE_INPUT)


func _apply_layer_order() -> void:
	# Back → front: cat, sprite overlay, speech, bubbles, input
	var ordered: Array[Node] = [cat, cat_sprite, speech_bubble, _floating_bubbles, _hover_input, circ_menu]
	if chat_panel:
		ordered.append(chat_panel)
	if settings_panel:
		ordered.append(settings_panel)
	if reminders_panel:
		ordered.append(reminders_panel)
	if todos_panel:
		ordered.append(todos_panel)
	if pomodoro_panel:
		ordered.append(pomodoro_panel)
	if stargazing_panel:
		ordered.append(stargazing_panel)
	for i in ordered.size():
		move_child(ordered[i], i)


func _setup_chat_panel():
	var scene = load("res://scenes/chat_panel.tscn")
	chat_panel = scene.instantiate()
	add_child(chat_panel)


func _setup_settings_panel():
	var scene = load("res://scenes/settings_panel.tscn")
	settings_panel = scene.instantiate()
	add_child(settings_panel)
	settings_panel.setting_changed.connect(func(key: String, value):
		if key == "ui.scale_multiplier":
			UiConfig.set_user_multiplier(float(value))
			UiConfig.persist_multiplier()
			_refresh_ui_scale()
	)
	settings_panel.save_requested.connect(_on_settings_save)
	settings_panel.clear_history_requested.connect(_on_clear_chat_history)
	settings_panel.close_requested.connect(func(): settings_panel.hide())


func _setup_reminders_panel():
	var scene: PackedScene = load("res://scenes/reminders_panel.tscn") as PackedScene
	if scene == null:
		push_error("DuDu: failed to load reminders_panel.tscn")
		return
	var panel = scene.instantiate()
	if panel == null or not panel.has_method("open"):
		push_error("DuDu: RemindersPanel script failed to load — check Output for parser errors")
		if panel:
			panel.queue_free()
		return
	reminders_panel = panel as RemindersPanel
	add_child(reminders_panel)
	reminders_panel.save_requested.connect(_on_reminders_save)
	reminders_panel.close_requested.connect(func():
		if reminders_panel:
			reminders_panel.hide()
	)
	_create_reminder_ack_ui()


func _create_pomodoro_status_label() -> void:
	_pomodoro_status_lbl = Label.new()
	_pomodoro_status_lbl.hide()
	_pomodoro_status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pomodoro_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pomodoro_status_lbl.add_theme_font_size_override("font_size", UiConfig.si(12))
	_pomodoro_status_lbl.add_theme_color_override("font_color", ACStyle.BROWN)
	add_child(_pomodoro_status_lbl)


func _setup_todos_panel() -> void:
	var scene: PackedScene = load("res://scenes/todos_panel.tscn") as PackedScene
	if scene == null:
		push_error("DuDu: failed to load todos_panel.tscn")
		return
	var panel = scene.instantiate()
	if panel == null or not panel.has_method("open"):
		push_error("DuDu: TodosPanel failed to load")
		if panel:
			panel.queue_free()
		return
	todos_panel = panel as TodosPanel
	add_child(todos_panel)
	todos_panel.save_requested.connect(_on_todos_save)
	todos_panel.close_requested.connect(func():
		if todos_panel:
			todos_panel.hide()
	)


func _setup_pomodoro_panel() -> void:
	var scene: PackedScene = load("res://scenes/pomodoro_panel.tscn") as PackedScene
	if scene == null:
		push_error("DuDu: failed to load pomodoro_panel.tscn")
		return
	var panel = scene.instantiate()
	if panel == null or not panel.has_method("open"):
		push_error("DuDu: PomodoroPanel failed to load")
		if panel:
			panel.queue_free()
		return
	pomodoro_panel = panel as PomodoroPanel
	add_child(pomodoro_panel)
	pomodoro_panel.start_requested.connect(_on_pomodoro_start)
	pomodoro_panel.pause_requested.connect(func(): _send_ws({"type": "pomodoro.pause"}))
	pomodoro_panel.resume_requested.connect(func(): _send_ws({"type": "pomodoro.resume"}))
	pomodoro_panel.abort_requested.connect(func(): _send_ws({"type": "pomodoro.abort"}))
	pomodoro_panel.close_requested.connect(func():
		if pomodoro_panel:
			pomodoro_panel.hide()
	)


func _setup_stargazing_panel() -> void:
	var scene: PackedScene = load("res://scenes/stargazing_panel.tscn") as PackedScene
	if scene == null:
		push_error("DuDu: failed to load stargazing_panel.tscn")
		return
	var panel = scene.instantiate()
	if panel == null or not panel.has_method("open"):
		push_error("DuDu: StargazingPanel failed to load")
		if panel:
			panel.queue_free()
		return
	stargazing_panel = panel as StargazingPanel
	add_child(stargazing_panel)
	stargazing_panel.refresh_requested.connect(_on_stargazing_refresh)
	stargazing_panel.location_save_requested.connect(_on_stargazing_location_save)
	stargazing_panel.close_requested.connect(func():
		if stargazing_panel:
			stargazing_panel.close_panel()
	)


func _create_reminder_ack_ui():
	_reminder_alarm = Label.new()
	_reminder_alarm.text = "⏰"
	_reminder_alarm.hide()
	_reminder_alarm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reminder_alarm.add_theme_font_size_override("font_size", UiConfig.si(18))
	add_child(_reminder_alarm)

	_reminder_ack_row = HBoxContainer.new()
	_reminder_ack_row.hide()
	_reminder_ack_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var ack_btn := Button.new()
	ack_btn.text = "知道了"
	ack_btn.pressed.connect(_on_reminder_ack)
	ACStyle.apply_footer_button_theme(ack_btn, false)
	_reminder_ack_row.add_child(ack_btn)
	add_child(_reminder_ack_row)


func _on_settings_save(pending: Dictionary) -> void:
	if pending.is_empty():
		return
	if ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		settings_panel.mark_save_failed()
		return
	_settings_save_pending = true
	_send_ws({"type": "settings.set_bulk", "updates": pending})


func _apply_ui_scale_to_children() -> void:
	_refresh_ui_scale()


func _refresh_ui_scale() -> void:
	_layout_cat_in_window()
	_style_speech_bubble()
	if _hover_input:
		_hover_input.add_theme_stylebox_override("panel", ChatBubbleStyle.make_input_stylebox(true))
		_hover_text.custom_minimum_size = Vector2(ChatBubbleStyle.content_min_width(), 0)
		_hover_text.add_theme_font_size_override("font_size", UiConfig.si(14))
	if _floating_bubbles:
		_floating_bubbles.add_theme_constant_override("separation", UiConfig.si(6))
	if chat_panel:
		chat_panel.apply_ui_scale()
	if settings_panel:
		settings_panel.apply_ui_scale()
	if reminders_panel:
		reminders_panel.apply_ui_scale()
	if todos_panel:
		todos_panel.apply_ui_scale()
	if pomodoro_panel:
		pomodoro_panel.apply_ui_scale()
	if stargazing_panel:
		stargazing_panel.apply_ui_scale()
	if circ_menu:
		circ_menu.apply_ui_scale()
	_schedule_stack_layout()


func _setup_window():
	var screen_idx := DisplayServer.window_get_current_screen()
	var screen_size := DisplayServer.screen_get_size(screen_idx)
	var screen_pos := DisplayServer.screen_get_position(screen_idx)
	UiConfig.bootstrap_multiplier()
	UiConfig.init_from_screen(screen_size)
	get_window().size = UiConfig.window_size
	get_window().position = screen_pos + (screen_size - UiConfig.window_size) / 2

	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0; offset_top = 0; offset_right = 0; offset_bottom = 0
	clip_contents = false
	_layout_cat_in_window()

	get_viewport().transparent_bg = true
	get_tree().root.set_transparent_background(true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	if not DisplayServer.is_window_transparency_available():
		_show_bubble("透明窗口不支持...")


func _layout_cat_in_window():
	var w := float(UiConfig.window_size.x)
	_cat_base_height = UiConfig.s(BASE_CAT_SIZE)
	_cat_center_x = w / 2.0
	cat.offset_left = _cat_center_x - _cat_base_height / 2.0
	cat.offset_right = _cat_center_x + _cat_base_height / 2.0
	cat.offset_top = UiConfig.s(BASE_SPACE_ABOVE_CAT)
	cat.offset_bottom = cat.offset_top + _cat_base_height
	_cat_bottom = cat.offset_bottom
	cat.scale = Vector2.ONE
	cat.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if cat_sprite.visible:
		_sync_sprite_for_anim(cat_sprite.animation)


# ============================================================
# Cat sprite setup
# ============================================================

func _setup_cat_sprite():
	var sf := SpriteFrames.new()
	_add_sheet_frames(sf, "idle", "trans-Dudu-idle-4x4.png", 4, 4, 8.0, true)
	# Sheet is 5×5 cells (128px); filename 4x5 is misleading.
	_add_sheet_frames(sf, "walk", "trans-Dudu-walk-4x5.png", 5, 5, 10.0, true)
	_add_sheet_frames(sf, "happy", "trans-Dudu-happy-4x5.png", 4, 5, 10.0, false)
	_add_sheet_frames(sf, "bite", "trans-Dudu-bite-4x4.png", 4, 4, 12.0, false)
	_add_sheet_frames(sf, "faint", "trans-Dudu-瘫倒-nobg-4x4.png", 4, 4, 6.0, false)
	cat_sprite.sprite_frames = sf
	cat_sprite.hide()
	cat_sprite.centered = true


func _add_sheet_frames(sf: SpriteFrames, anim_name: String, filename: String, cols: int, rows: int, fps: float, loop: bool):
	var root = ProjectSettings.globalize_path("res://")
	var path = root.path_join(SPRITE_SHEET_DIR).path_join(filename)
	var img = Image.load_from_file(path)
	if img == null:
		print("WARNING: Missing sprite sheet ", path)
		return
	var tex = ImageTexture.create_from_image(img)
	var fw: int = img.get_width() / cols
	var fh: int = img.get_height() / rows
	sf.add_animation(anim_name)
	sf.set_animation_speed(anim_name, fps)
	sf.set_animation_loop(anim_name, loop)
	for row in range(rows):
		for col in range(cols):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(col * fw, row * fh, fw, fh)
			at.filter_clip = true
			sf.add_frame(anim_name, at)
	print("Loaded %s: %d frames from %s" % [anim_name, rows * cols, filename])


func _create_hover_input():
	_hover_input = PanelContainer.new()
	_hover_input.hide()
	_hover_input.modulate.a = 0
	_hover_input.mouse_filter = Control.MOUSE_FILTER_STOP
	_hover_input.add_theme_stylebox_override("panel", ChatBubbleStyle.make_input_stylebox(true))

	_hover_text = TextEdit.new()
	_hover_text.custom_minimum_size = Vector2(ChatBubbleStyle.content_min_width(), 0)
	_hover_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_hover_text.add_theme_font_size_override("font_size", UiConfig.si(14))
	_hover_text.add_theme_color_override("font_color", ACStyle.LIGHT_TEXT)
	_hover_text.add_theme_color_override("font_placeholder_color", Color(ACStyle.TAN.r, ACStyle.TAN.g, ACStyle.TAN.b, 0.5))
	_hover_text.add_theme_stylebox_override("normal", _transparent_stylebox())
	_hover_text.add_theme_stylebox_override("focus", _transparent_stylebox())
	_hover_text.placeholder_text = "说点什么..."
	_hover_text.scroll_fit_content_height = true
	_hover_text.gui_input.connect(_on_hover_text_input)

	_hover_input.add_child(_hover_text)
	add_child(_hover_input)
	_hover_input.mouse_entered.connect(func(): _hovering = true)
	_hover_input.mouse_exited.connect(_on_stack_mouse_exit)


func _create_floating_bubbles():
	_floating_bubbles = VBoxContainer.new()
	_floating_bubbles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floating_bubbles.alignment = BoxContainer.ALIGNMENT_CENTER
	_floating_bubbles.add_theme_constant_override("separation", UiConfig.si(6))
	_floating_bubbles.hide()
	_floating_bubbles.modulate.a = 0
	_floating_bubbles.mouse_entered.connect(func(): _hovering = true)
	_floating_bubbles.mouse_exited.connect(_on_stack_mouse_exit)
	add_child(_floating_bubbles)
func _transparent_stylebox() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()


func _wire_signals():
	circ_menu.item_selected.connect(_on_menu_action)
	circ_menu.toggle_changed.connect(_on_menu_toggle)
	chat_panel.message_sent.connect(_on_chat_send)
	chat_panel.message_delete_requested.connect(_on_message_delete)
	chat_panel.close_requested.connect(func(): chat_panel.hide())
	cat.mouse_entered.connect(_on_cat_mouse_enter)
	cat.mouse_exited.connect(_on_cat_mouse_exit)


# ============================================================
# Hover input
# ============================================================

func _on_cat_mouse_enter():
	_hovering = true
	_stack_hide_gen += 1
	_cancel_stack_tween()
	_stack_tween = create_tween()
	_stack_tween.tween_interval(STACK_SHOW_DELAY)
	_stack_tween.tween_callback(_show_hover_stack)


func _on_cat_mouse_exit():
	_hovering = false
	_schedule_stack_hide()


func _on_stack_mouse_exit():
	_hovering = false
	_schedule_stack_hide()


func _pointer_in_stack() -> bool:
	if _hovering:
		return true
	if cat.get_global_rect().has_point(get_global_mouse_position()):
		return true
	var mp := get_global_mouse_position()
	if _hover_input.visible and _hover_input.modulate.a > 0.01:
		if _hover_input.get_global_rect().has_point(mp):
			return true
	if _floating_bubbles.visible and _floating_bubbles.modulate.a > 0.01:
		if _floating_bubbles.get_global_rect().has_point(mp):
			return true
	return false


func _schedule_stack_hide() -> void:
	_stack_hide_gen += 1
	var gen := _stack_hide_gen
	var elapsed := Time.get_ticks_msec() - _stack_shown_at
	var grace := 0.3 if elapsed >= STACK_MIN_VISIBLE_MS else (STACK_MIN_VISIBLE_MS - elapsed) / 1000.0 + 0.3
	await get_tree().create_timer(grace).timeout
	if gen != _stack_hide_gen:
		return
	if _chat_session_active:
		return
	if _pointer_in_stack():
		return
	_hide_hover_stack()


func _cancel_stack_tween() -> void:
	if _stack_tween and _stack_tween.is_valid():
		_stack_tween.kill()
	_stack_tween = null


func _show_hover_stack():
	if not _hovering and not _chat_session_active:
		return
	_stack_shown_at = Time.get_ticks_msec()
	_position_hover_input()
	_schedule_stack_layout()
	_cancel_stack_tween()
	var tw := create_tween().set_parallel(true)
	if _hovering:
		_hover_input.show()
		_hover_input.modulate.a = 0.0
		tw.tween_property(_hover_input, "modulate:a", 1.0, 0.2)
	if _floating_bubbles.get_child_count() > 0:
		_floating_bubbles.show()
		if _floating_bubbles.modulate.a < 0.99:
			tw.tween_property(_floating_bubbles, "modulate:a", 1.0, 0.2).from(0.0)
	_sync_bubbles_mouse_filter()


func _hide_hover_stack():
	_cancel_stack_tween()
	var tw := create_tween().set_parallel(true)
	if _hover_input.visible:
		tw.tween_property(_hover_input, "modulate:a", 0.0, 0.15)
	if _floating_bubbles.visible:
		tw.tween_property(_floating_bubbles, "modulate:a", 0.0, 0.15)
	tw.chain().tween_callback(_on_stack_hidden)


func _hide_input_only():
	_cancel_stack_tween()
	var tw := create_tween()
	tw.tween_property(_hover_input, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func():
		_hover_input.hide()
		_hover_input.modulate.a = 0.0
		_schedule_stack_layout()
	)


func _on_stack_hidden():
	_hover_input.hide()
	_hover_input.modulate.a = 0.0
	_floating_bubbles.hide()
	_floating_bubbles.modulate.a = 0.0
	_sync_bubbles_mouse_filter()
	_schedule_stack_layout()


func _sync_bubbles_mouse_filter() -> void:
	var interactive := _floating_bubbles.get_child_count() > 0 and _floating_bubbles.visible
	_floating_bubbles.mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE


func _ensure_bubbles_visible() -> void:
	if _floating_bubbles.get_child_count() == 0:
		return
	if not _floating_bubbles.visible or _floating_bubbles.modulate.a < 0.99:
		_floating_bubbles.show()
		_floating_bubbles.modulate.a = 1.0
		_sync_bubbles_mouse_filter()
		_schedule_stack_layout()


func _position_hover_input():
	var min_w := ChatBubbleStyle.outer_min_width()
	_hover_input.custom_minimum_size = Vector2(min_w, 0)
	_hover_input.reset_size()
	var cx := _cat_center().x
	var hw := maxf(_hover_input.size.x, min_w)
	var hh := maxf(_hover_input.size.y, UiConfig.s(36))
	var cat_rect := _cat_rect()
	_hover_input.position = Vector2(cx - hw / 2.0, cat_rect.position.y - hh - UiConfig.s(INPUT_GAP_ABOVE_CAT))


func _schedule_stack_layout() -> void:
	_stack_layout_gen += 1
	var gen := _stack_layout_gen
	call_deferred("_run_stack_layout", gen)


func _run_stack_layout(gen: int) -> void:
	if gen != _stack_layout_gen:
		return
	_position_hover_input()
	for c in _floating_bubbles.get_children():
		c.reset_size()
	_floating_bubbles.reset_size()
	call_deferred("_finish_stack_layout", gen)


func _finish_stack_layout(gen: int) -> void:
	if gen != _stack_layout_gen:
		return
	_position_floating_bubbles()
	if speech_bubble.visible:
		_position_bubble()


func _on_hover_text_input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.shift_pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			var text = _hover_text.text.strip_edges()
			if not text.is_empty():
				_send_chat(text)
				_hover_text.text = ""
				_hide_input_only()
			get_viewport().set_input_as_handled()


# ============================================================
# Circular menu
# ============================================================

func _on_menu_toggle(action: String, enabled: bool) -> void:
	var field: String = _TOGGLE_SETTING_KEYS.get(action, "")
	if field.is_empty():
		return
	_chat_toggles[field] = enabled
	match action:
		"toggle_thinking":
			_send_ws({"type": "settings.set", "key": "chat.thinking_enabled", "value": enabled})
		"toggle_memory":
			_send_ws({"type": "settings.set", "key": "chat.use_memory", "value": enabled})
		"toggle_record":
			_send_ws({"type": "settings.set", "key": "chat.record_memory", "value": enabled})


func _on_menu_action(action: String):
	match action:
		"chat_history":
			_open_chat_history()
		"reminders":
			_open_reminders()
		"todos":
			_open_todos()
		"explore":
			_open_pomodoro()
		"stargazing":
			_open_stargazing()
		"fortune":
			_send_chat("今日运势", false, "fortune")
		"settings":
			_open_settings()
		"quit":
			_shutdown()


func _open_circular_menu() -> void:
	if circ_menu.is_open():
		circ_menu.close()
		return
	_sync_circ_menu_toggles()
	circ_menu.open(_cat_center())


# ============================================================
# Chat
# ============================================================

func _send_chat(text: String, panel_user_added: bool = false, mode: String = ""):
	if not panel_user_added:
		chat_panel.add_message("user", text, _now_timestamp())
	var payload := {"type": "user.chat", "text": text}
	if not mode.is_empty():
		payload["mode"] = mode
	payload["thinking"] = bool(_chat_toggles["thinking_enabled"])
	payload["use_memory"] = bool(_chat_toggles["use_memory"])
	payload["record_memory"] = bool(_chat_toggles["record_memory"])
	_send_ws(payload)
	_play_anim(Anim.TALKING)
	_streaming_bubble = true
	_stream_buffer = ""
	speech_bubble.hide()
	_chat_session_active = true
	_hide_input_only()
	# Only the current turn — never replay history or prior session bubbles
	_clear_floating_bubbles()
	_ensure_bubbles_visible()
	_add_floating_bubble("user", text)
	_floating_assistant_added = false
	_start_chat_reply_timeout()


func _start_chat_reply_timeout() -> void:
	_chat_wait_gen += 1
	var gen := _chat_wait_gen
	await get_tree().create_timer(CHAT_REPLY_TIMEOUT).timeout
	if gen != _chat_wait_gen or not _chat_session_active:
		return
	_on_chat_reply_failed("等太久啦…检查一下网络或 API 设置喵")


func _cancel_chat_reply_timeout() -> void:
	_chat_wait_gen += 1


func _on_chat_reply_failed(message: String) -> void:
	_cancel_chat_reply_timeout()
	_stream_buffer = ""
	_streaming_bubble = false
	_chat_session_active = false
	_ensure_bubbles_visible()
	if not _floating_assistant_added:
		_add_floating_bubble("assistant", message)
		_floating_assistant_added = true
	else:
		_append_floating_bubble(message)
	_stack_shown_at = Time.get_ticks_msec()
	_schedule_stack_layout()
	_play_anim(Anim.IDLE)


func _on_chat_send(text: String):
	_send_chat(text, true)


func _on_clear_chat_history() -> void:
	_send_ws({"type": "history.clear"})
	_history_cache.clear()
	chat_panel.clear_messages()
	_clear_floating_bubbles()


func _on_message_delete(timestamp: String) -> void:
	if timestamp.is_empty():
		return
	_send_ws({"type": "history.delete", "timestamp": timestamp})
	_remove_history_entry(timestamp)
	chat_panel.remove_message_by_timestamp(timestamp)


func _remove_history_entry(timestamp: String) -> void:
	for i in range(_history_cache.size() - 1, -1, -1):
		if _history_cache[i].get("timestamp", "") == timestamp:
			_history_cache.remove_at(i)
			return


func _open_chat_history():
	chat_panel.open(_cat_center())
	if not _history_cache.is_empty():
		chat_panel.clear_messages()
		chat_panel.add_messages(_history_cache)
	_send_ws({"type": "history.request"})



func _open_reminders():
	if reminders_panel == null:
		push_error("DuDu: reminders panel unavailable")
		return
	if settings_panel and settings_panel.visible:
		settings_panel.hide()
	if chat_panel and chat_panel.visible:
		chat_panel.hide()
	reminders_panel.open(_cat_center())
	_send_ws({"type": "reminders.get"})


func _on_reminders_save(items: Array) -> void:
	if reminders_panel == null:
		return
	if ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		reminders_panel.mark_save_failed()
		return
	_reminders_save_pending = true
	_send_ws({"type": "reminders.set", "items": items})


func _open_todos() -> void:
	if todos_panel == null:
		return
	if chat_panel.visible:
		chat_panel.hide()
	if settings_panel and settings_panel.visible:
		settings_panel.hide()
	if reminders_panel and reminders_panel.visible:
		reminders_panel.hide()
	todos_panel.open(_cat_center())
	_send_ws({"type": "todos.get"})


func _on_todos_save(items: Array) -> void:
	if todos_panel == null:
		return
	if ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		todos_panel.mark_save_failed()
		return
	_todos_save_pending = true
	_send_ws({"type": "todos.set", "items": items})


func _open_pomodoro() -> void:
	if pomodoro_panel == null:
		return
	if chat_panel.visible:
		chat_panel.hide()
	pomodoro_panel.open(_cat_center())
	_send_ws({"type": "inventory.get"})
	_send_ws({"type": "pomodoro.get"})


func _on_pomodoro_start(task: String, duration_minutes: int) -> void:
	_pomodoro_status_task = task if not task.is_empty() else "专注"
	_pomodoro_status_duration_mins = maxi(1, duration_minutes)
	_send_ws({
		"type": "pomodoro.start",
		"task": task,
		"duration_minutes": duration_minutes,
	})


func _open_stargazing() -> void:
	if stargazing_panel == null:
		return
	if chat_panel.visible:
		chat_panel.hide()
	stargazing_panel.open(_cat_center())
	_send_ws({"type": "settings.get"})


func _on_stargazing_refresh() -> void:
	if stargazing_panel == null:
		return
	stargazing_panel.set_loading(true)
	_stargazing_pending = true
	_stargazing_wait_gen += 1
	var gen := _stargazing_wait_gen
	get_tree().create_timer(STARGAZING_TIMEOUT).timeout.connect(func():
		if gen == _stargazing_wait_gen and _stargazing_pending and stargazing_panel:
			stargazing_panel.show_error("请求超时，请确认 backend 已启动")
			_stargazing_pending = false
	, CONNECT_ONE_SHOT)
	if ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		stargazing_panel.show_error("后端未连接，正在启动…")
		_check_and_launch_backend()
		return
	_send_ws({"type": "stargazing.get"})


func _on_stargazing_location_save(city: String, latitude: float, longitude: float) -> void:
	_send_ws({
		"type": "settings.set_bulk",
		"updates": {
			"stargazing.city": city,
			"stargazing.latitude": latitude,
			"stargazing.longitude": longitude,
		},
	})
	get_tree().create_timer(0.3).timeout.connect(_on_stargazing_refresh)


func _on_reminder_ack() -> void:
	if _active_reminder_id.is_empty():
		return
	_send_ws({"type": "reminders.ack", "id": _active_reminder_id})
	_clear_reminder_ui()


func _clear_reminder_ui() -> void:
	_active_reminder_id = ""
	if _reminder_bubble_tween and _reminder_bubble_tween.is_valid():
		_reminder_bubble_tween.kill()
		_reminder_bubble_tween = null
	_reminder_ack_row.hide()
	_reminder_alarm.hide()
	speech_bubble.hide()


func _show_reminder_trigger(payload: Dictionary) -> void:
	_active_reminder_id = str(payload.get("id", ""))
	var text: String = str(payload.get("bubble_text", "嘟嘟提醒你一下喵~"))
	_show_bubble_persistent(text)
	_reminder_alarm.show()
	_reminder_ack_row.show()
	_handle_action(str(payload.get("animation", "happy")))
	call_deferred("_layout_reminder_overlay")


func _position_reminder_alarm() -> void:
	var cat_rect := _cat_rect()
	_reminder_alarm.position = Vector2(
		cat_rect.position.x + UiConfig.s(4),
		cat_rect.position.y - UiConfig.s(8)
	)


func _position_reminder_ack() -> void:
	_reminder_ack_row.reset_size()
	speech_bubble.reset_size()
	var cx := _cat_center().x
	var bw := maxf(_reminder_ack_row.size.x, UiConfig.s(80))
	var bubble_bottom := speech_bubble.position.y + speech_bubble.size.y
	_reminder_ack_row.position = Vector2(
		cx - bw / 2.0,
		bubble_bottom + UiConfig.s(4)
	)


func _layout_reminder_overlay() -> void:
	_position_bubble()
	_position_reminder_alarm()
	_position_reminder_ack()


func _show_bubble_persistent(text: String) -> void:
	if _reminder_bubble_tween and _reminder_bubble_tween.is_valid():
		_reminder_bubble_tween.kill()
		_reminder_bubble_tween = null
	bubble.text = text
	speech_bubble.show()
	_schedule_stack_layout()
	_position_bubble()
func _open_settings():
	settings_panel.open(_cat_center())
	_send_ws({"type": "settings.get"})


func _apply_chat_toggles(settings: Dictionary) -> void:
	var chat: Variant = settings.get("chat", {})
	if not chat is Dictionary:
		return
	_chat_toggles["thinking_enabled"] = bool(chat.get("thinking_enabled", true))
	_chat_toggles["use_memory"] = bool(chat.get("use_memory", true))
	_chat_toggles["record_memory"] = bool(chat.get("record_memory", true))
	_sync_circ_menu_toggles()


func _sync_circ_menu_toggles() -> void:
	circ_menu.set_toggle("toggle_thinking", bool(_chat_toggles["thinking_enabled"]))
	circ_menu.set_toggle("toggle_memory", bool(_chat_toggles["use_memory"]))
	circ_menu.set_toggle("toggle_record", bool(_chat_toggles["record_memory"]))


# ============================================================
# WebSocket
# ============================================================

func _connect_ws():
	if ws.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		return
	ws.connect_to_url(WS_URL)


func _process(_delta):
	ws.poll()
	var ws_open := ws.get_ready_state() == WebSocketPeer.STATE_OPEN
	if ws_open and not _ws_was_open and _stargazing_pending:
		_send_ws({"type": "stargazing.get"})
	_ws_was_open = ws_open
	_handle_ws_messages()
	_update_passthrough()
	if ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		_reconnect()


func _handle_ws_messages():
	while ws.get_available_packet_count() > 0:
		var pkt = ws.get_packet()
		var raw = pkt.get_string_from_utf8()
		var msg = JSON.parse_string(raw)
		if msg == null:
			continue

		match msg.get("type", ""):
			"pet.action":
				var pl = msg["payload"]
				_show_bubble(pl.get("bubble_text", "喵~"))
				_handle_action(pl.get("animation", "idle"))

			"assistant.chunk":
				var delta = msg["payload"].get("delta", "")
				_stream_buffer += delta
				if chat_panel.visible:
					if _streaming_bubble:
						chat_panel.add_message("assistant", delta, _now_timestamp())
						_streaming_bubble = false
					else:
						chat_panel.append_last(delta)

				_ensure_bubbles_visible()
				if not _floating_assistant_added:
					_add_floating_bubble("assistant", delta)
					_floating_assistant_added = true
				else:
					_append_floating_bubble(delta)
			"assistant.done":
				_cancel_chat_reply_timeout()
				var full = msg["payload"].get("full_text", _stream_buffer)
				if full.is_empty():
					full = "唔...嘟嘟一时说不出话，再试一次喵~"
				if _stream_buffer.is_empty() and not full.is_empty():
					_ensure_bubbles_visible()
					_add_floating_bubble("assistant", full)
				if chat_panel.visible and _stream_buffer != "":
					pass
				_stream_buffer = ""
				_streaming_bubble = false
				_floating_assistant_added = false
				_chat_session_active = false
				_stack_shown_at = Time.get_ticks_msec()
				_schedule_stack_layout()
				if not _pointer_in_stack():
					_schedule_stack_hide()
				_play_anim(Anim.IDLE)

			"window.hide":
				get_window().mode = Window.MODE_MINIMIZED
				_send_ws({"type": "window.hidden"})

			"window.restore":
				get_window().mode = Window.MODE_WINDOWED
				_send_ws({"type": "window.shown"})

			"app.quit":
				_shutdown()

			"pong":
				pass

			"history.data":
				_load_history_into_panel(msg["payload"]["messages"])

			"history.cleared":
				_history_cache.clear()
				if chat_panel.visible:
					chat_panel.clear_messages()
				_clear_floating_bubbles()

			"history.deleted":
				var ts: String = msg["payload"].get("timestamp", "")
				if bool(msg["payload"].get("ok", false)) and not ts.is_empty():
					_remove_history_entry(ts)
					chat_panel.remove_message_by_timestamp(ts)

			"settings.data":
				var prev_scale := UiConfig.user_multiplier
				if settings_panel:
					settings_panel.populate(msg["payload"])
				if stargazing_panel:
					stargazing_panel.populate_location(msg["payload"])
				if not is_equal_approx(prev_scale, UiConfig.user_multiplier):
					_refresh_ui_scale()
				UiConfig.persist_multiplier()

				if not circ_menu.is_open():
					_apply_chat_toggles(msg["payload"])

			"settings.updated":
				# Toggle state is optimistic-local; echo would race and break menu styling.
				if _settings_save_pending:
					_settings_save_pending = false
					if settings_panel:
						settings_panel.mark_saved()

			"reminders.data":
				if reminders_panel:
					var items = msg["payload"].get("items", [])
					reminders_panel.populate(items)
				if _reminders_save_pending:
					_reminders_save_pending = false
					if reminders_panel:
						reminders_panel.mark_saved()

			"reminder.trigger":
				_show_reminder_trigger(msg["payload"])

			"reminders.acked":
				if str(msg["payload"].get("id", "")) == _active_reminder_id:
					_clear_reminder_ui()

			"daily_stats.yesterday":
				pass

			"todos.data":
				if todos_panel:
					todos_panel.populate(msg["payload"].get("items", []))
				if _todos_save_pending:
					_todos_save_pending = false
					if todos_panel:
						todos_panel.mark_saved()

			"todo.remind":
				var todo_text := str(msg["payload"].get("text", ""))
				if not todo_text.is_empty():
					_show_bubble("⏰ 待办：%s" % todo_text)
				_chat_session_active = true
				_streaming_bubble = true
				_stream_buffer = ""
				_clear_floating_bubbles()
				_ensure_bubbles_visible()
				_play_anim(Anim.TALKING)
				_start_chat_reply_timeout()

			"inventory.data", "inventory.updated":
				if pomodoro_panel:
					pomodoro_panel.set_inventory(msg["payload"].get("items", []))

			"pomodoro.state":
				if pomodoro_panel:
					pomodoro_panel.update_state(msg["payload"])
				var st := str(msg["payload"].get("state", "idle"))
				if st == "focusing":
					_pomodoro_status_task = str(msg["payload"].get("task", _pomodoro_status_task))
					if _pomodoro_status_duration_mins <= 0:
						var total_sec := int(msg["payload"].get("duration_sec", 0))
						if total_sec > 0:
							_pomodoro_status_duration_mins = maxi(1, total_sec / 60)
					_enter_pomodoro_focus()
					_update_pomodoro_status_label()
				elif _pomodoro_focus_mode:
					_exit_pomodoro_focus()

			"pomodoro.tick":
				if pomodoro_panel:
					pomodoro_panel.update_tick(msg["payload"])

			"pomodoro.phase_change":
				var pl = msg["payload"]
				var bubble_txt := str(pl.get("bubble_text", ""))
				if not bubble_txt.is_empty():
					_show_bubble(bubble_txt)
				var phase := str(pl.get("phase", ""))
				if phase == "focusing":
					_pomodoro_status_task = str(pl.get("task", _pomodoro_status_task))
					_enter_pomodoro_focus()
					_update_pomodoro_status_label()
				elif phase in ["complete", "aborted", "idle"]:
					_exit_pomodoro_focus()

			"pomodoro.complete":
				var item: Variant = msg["payload"].get("item")
				if item is Dictionary and not item.is_empty():
					var item_name := str(item.get("name", "小物件"))
					var emoji := str(item.get("emoji", "📦"))
					_show_bubble("带回了 %s%s！" % [emoji, item_name])

			"stargazing.chart":
				_stargazing_pending = false
				_stargazing_wait_gen += 1
				if stargazing_panel:
					stargazing_panel.show_chart(msg["payload"])

			_:
				print("Unhandled: ", msg["type"])


func _handle_action(action: String):
	match action:
		"idle": _play_anim(Anim.IDLE)
		"talking": _play_anim(Anim.TALKING)
		"happy", "petted", "lick_mouth": _play_anim(Anim.HAPPY)
		"wiggle_butt": _play_anim(Anim.HAPPY)
		"bite": _play_anim(Anim.BITE)
		"faint": _play_anim(Anim.FAINT)
		_: pass


func _reconnect():
	var t = Time.get_ticks_msec()
	if _ws_retry_ts < t:
		_ws_retry_ts = t + 3000
		ws = WebSocketPeer.new()
		_connect_ws()
		print("WS reconnect...")



func _update_passthrough():
	var rects: Array[Rect2] = []
	rects.append(cat.get_global_rect())
	if _pomodoro_status_lbl and _pomodoro_status_lbl.visible:
		rects.append(_pomodoro_status_lbl.get_global_rect())
	if speech_bubble.visible:
		rects.append(speech_bubble.get_global_rect())
	if _reminder_ack_row and _reminder_ack_row.visible:
		rects.append(_reminder_ack_row.get_global_rect())
	if _hover_input.visible and _hover_input.modulate.a > 0:
		rects.append(_hover_input.get_global_rect())
	if _floating_bubbles.visible and _floating_bubbles.get_child_count() > 0:
		rects.append(_floating_bubbles.get_global_rect())
	if chat_panel.visible:
		rects.append(chat_panel.get_global_rect())
	if settings_panel and settings_panel.visible:
		rects.append(settings_panel.get_global_rect())
	if reminders_panel and reminders_panel.visible:
		rects.append(reminders_panel.get_global_rect())
	if todos_panel and todos_panel.visible:
		rects.append(todos_panel.get_global_rect())
	if pomodoro_panel and pomodoro_panel.visible:
		rects.append(pomodoro_panel.get_global_rect())
	if stargazing_panel and stargazing_panel.visible:
		rects.append(stargazing_panel.get_global_rect())
	if stargazing_panel and stargazing_panel.is_lightbox_open():
		rects.append(get_viewport().get_visible_rect())
	if circ_menu.is_open():
		for r in circ_menu.get_passthrough_rects():
			rects.append(r)
		_update_passthrough_polygon(rects)
		return
	if rects.is_empty():
		return
	_update_passthrough_polygon(rects)


func _update_passthrough_polygon(rects: Array[Rect2]) -> void:
	var merged := rects[0]
	for i in range(1, rects.size()):
		merged = merged.merge(rects[i])
	var poly := PackedVector2Array()
	poly.append(merged.position)
	poly.append(Vector2(merged.end.x, merged.position.y))
	poly.append(merged.end)
	poly.append(Vector2(merged.position.x, merged.end.y))
	poly.append(merged.position)
	get_window().mouse_passthrough_polygon = poly

func _position_floating_bubbles():
	var limit_y := _bubble_bottom_limit()
	var bh := _floating_bubbles.size.y
	var bw := _floating_bubbles.size.x
	var cx := _cat_center().x
	if bh <= 0:
		_floating_bubbles.position = Vector2(cx - bw / 2.0, limit_y)
		return
	_floating_bubbles.position = Vector2(cx - bw / 2.0, limit_y - bh)
func _add_floating_bubble(role: String, text: String):
	var bubble := MSG_BUBBLE.instantiate()
	bubble.set_compact(true)
	_floating_bubbles.add_child(bubble)
	bubble.setup(role, text)
	while _floating_bubbles.get_child_count() > 6:
		var first := _floating_bubbles.get_child(0)
		_floating_bubbles.remove_child(first)
		first.queue_free()
	_schedule_stack_layout()


func _append_floating_bubble(delta: String):
	var last_idx := _floating_bubbles.get_child_count() - 1
	if last_idx < 0:
		return
	var last_bubble = _floating_bubbles.get_child(last_idx)
	if last_bubble.has_method("append_text"):
		last_bubble.append_text(delta)
	_schedule_stack_layout()

func _clear_floating_bubbles():
	for c in _floating_bubbles.get_children():
		_floating_bubbles.remove_child(c)
		c.queue_free()
func _send_ws(dict: Dictionary):
	if not dict.has("id"):
		dict["id"] = _uid()
	if not dict.has("timestamp"):
		dict["timestamp"] = Time.get_unix_time_from_system()
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify(dict))


func _load_history_into_panel(messages: Array):
	# History is for 魔法日记 only — floating bubbles stay session-turn scoped
	_history_cache = messages.duplicate(true)
	if chat_panel.visible:
		chat_panel.clear_messages()
		if not _history_cache.is_empty():
			chat_panel.add_messages(_history_cache)


# ============================================================
# Backend process
# ============================================================

func _check_and_launch_backend():
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		return

	print("WS not connected — launching backend...")
	var project_dir := ProjectSettings.globalize_path("res://")
	var backend_dir := project_dir.path_join("../backend")
	var python_exe := backend_dir.path_join("venv/Scripts/python.exe")
	var server_py := backend_dir.path_join("server.py")

	if not FileAccess.file_exists(python_exe):
		print("Backend python not found, start it manually: ", python_exe)
		return

	var args := PackedStringArray([server_py])
	_backend_pid = OS.create_process(python_exe, args)
	if _backend_pid > 0:
		print("Backend launched (PID ", _backend_pid, ")")
		get_tree().create_timer(0.5).timeout.connect(_connect_ws)
	else:
		print("WARNING: Failed to launch backend, start it manually")


func _shutdown():
	if _backend_pid > 0:
		OS.kill(_backend_pid)
	get_tree().quit()


# ============================================================
# Animation
# ============================================================

func _play_anim(anim: Anim):
	match anim:
		Anim.IDLE:
			_cancel_one_shot()
			current_anim = Anim.IDLE
			_show_idle_placeholder()
			_start_breathing()
		Anim.TALKING:
			_cancel_one_shot()
			current_anim = Anim.TALKING
			if _breathe_tween and _breathe_tween.is_valid():
				_breathe_tween.kill()
			_show_sprite_anim("idle", TALKING_IDLE_SPEED_SCALE)
		Anim.HAPPY:
			if _anim_lock: return
			_start_one_shot("happy", Anim.HAPPY)
		Anim.BITE:
			if _anim_lock: return
			_start_one_shot("bite", Anim.BITE)
		Anim.FAINT:
			if _anim_lock: return
			_start_one_shot("faint", Anim.FAINT)


func _show_idle_placeholder() -> void:
	cat_sprite.hide()
	cat.texture = CAT_PLACEHOLDER
	cat.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func _show_sprite_anim(anim_name: String, speed_scale: float = 1.0) -> void:
	cat.texture = null
	cat_sprite.show()
	cat_sprite.speed_scale = speed_scale
	_sync_sprite_for_anim(anim_name)
	cat_sprite.play(anim_name)


func _cancel_one_shot():
	_anim_lock = false


func _start_one_shot(anim_name: String, anim_enum: Anim):
	_anim_lock = true
	current_anim = anim_enum
	if _breathe_tween and _breathe_tween.is_valid():
		_breathe_tween.kill()
	_set_cat_breathe(1.0)
	_show_sprite_anim(anim_name)
	var frame_count: int = cat_sprite.sprite_frames.get_frame_count(anim_name)
	var fps: float = cat_sprite.sprite_frames.get_animation_speed(anim_name)
	var duration := frame_count / fps
	await get_tree().create_timer(duration).timeout
	if current_anim == anim_enum:
		_anim_lock = false
		_play_anim(Anim.IDLE)


func _start_breathing(peak_y: float = BREATHE_PEAK_Y, period: float = BREATHE_PERIOD):
	_set_cat_breathe(1.0)
	if _breathe_tween and _breathe_tween.is_valid():
		_breathe_tween.kill()
	_breathe_tween = create_tween().set_loops()
	_breathe_tween.tween_method(_set_cat_breathe, 1.0, peak_y, period).set_ease(Tween.EASE_IN_OUT)
	_breathe_tween.tween_method(_set_cat_breathe, peak_y, 1.0, period).set_ease(Tween.EASE_IN_OUT)


func _sync_sprite_for_anim(anim_name: String) -> void:
	var rect := _cat_rect()
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var sf := cat_sprite.sprite_frames
	if sf == null or not sf.has_animation(anim_name):
		return
	var frame_tex: Texture2D = sf.get_frame_texture(anim_name, 0)
	if frame_tex == null:
		return
	var frame_size := frame_tex.get_size()
	if frame_size.x <= 0 or frame_size.y <= 0:
		return
	var target_scale := minf(rect.size.x / frame_size.x, rect.size.y / frame_size.y)
	cat_sprite.scale = Vector2(target_scale, target_scale)
	var scaled_h := frame_size.y * target_scale
	var cx := rect.position.x + rect.size.x * 0.5
	var foot_y := rect.position.y + rect.size.y
	cat_sprite.position = Vector2(cx, foot_y - scaled_h * 0.5)


# ============================================================
# Random idle animations
# ============================================================

func _start_idle_loop():
	_idle_loop_gen += 1
	var gen := _idle_loop_gen
	while gen == _idle_loop_gen:
		var delay := randf_range(IDLE_RANDOM_MIN, IDLE_RANDOM_MAX)
		await get_tree().create_timer(delay).timeout
		if gen != _idle_loop_gen:
			return
		if current_anim == Anim.IDLE and not _anim_lock and not _chat_session_active:
			_trigger_random_idle()


func _trigger_random_idle():
	var r := randf()
	if r < 0.4:
		_play_anim(Anim.HAPPY)
	elif r < 0.7:
		_play_anim(Anim.BITE)
	else:
		_play_anim(Anim.FAINT)


# ============================================================
# Bubble
# ============================================================

func _show_bubble(text: String):
	bubble.text = text
	speech_bubble.show()
	_schedule_stack_layout()
	var t = create_tween()
	t.tween_interval(5.0)
	t.tween_callback(func(): speech_bubble.hide())


func _enter_pomodoro_focus() -> void:
	if _pomodoro_focus_mode:
		return
	_pomodoro_focus_mode = true
	var w := float(UiConfig.window_size.x)
	var h := float(UiConfig.window_size.y)
	var mini := UiConfig.s(48)
	cat.scale = Vector2(0.4, 0.4)
	cat.offset_left = w - mini - UiConfig.s(8)
	cat.offset_right = w - UiConfig.s(8)
	cat.offset_bottom = h - UiConfig.s(8)
	cat.offset_top = cat.offset_bottom - mini
	if cat_sprite.visible:
		_sync_sprite_for_anim(cat_sprite.animation)
	_position_pomodoro_status_label()


func _exit_pomodoro_focus() -> void:
	if not _pomodoro_focus_mode:
		return
	_pomodoro_focus_mode = false
	_pomodoro_status_task = ""
	_pomodoro_status_duration_mins = 0
	if _pomodoro_status_lbl:
		_pomodoro_status_lbl.hide()
	_layout_cat_in_window()


func _update_pomodoro_status_label() -> void:
	if not _pomodoro_status_lbl or not _pomodoro_focus_mode:
		return
	if _pomodoro_status_duration_mins <= 0:
		_pomodoro_status_lbl.hide()
		return
	var task := _pomodoro_status_task if not _pomodoro_status_task.is_empty() else "专注"
	_pomodoro_status_lbl.text = "【%s - %dmin】" % [task, _pomodoro_status_duration_mins]
	_pomodoro_status_lbl.show()
	_position_pomodoro_status_label()


func _position_pomodoro_status_label() -> void:
	if not _pomodoro_status_lbl or not _pomodoro_status_lbl.visible:
		return
	_pomodoro_status_lbl.reset_size()
	var rect := _cat_rect()
	var cx := _cat_center().x
	var bw := _pomodoro_status_lbl.size.x
	_pomodoro_status_lbl.position = Vector2(
		cx - bw / 2.0,
		rect.position.y + rect.size.y + UiConfig.s(4)
	)


func _position_bubble():
	bubble.reset_size()
	speech_bubble.reset_size()
	var cx := _cat_center().x
	var bw := speech_bubble.size.x
	var bh := speech_bubble.size.y
	speech_bubble.position = Vector2(cx - bw / 2.0, _bubble_bottom_limit() - bh)
	if _reminder_ack_row and _reminder_ack_row.visible:
		_position_reminder_ack()
	if _reminder_alarm and _reminder_alarm.visible:
		_position_reminder_alarm()
	if _pomodoro_status_lbl and _pomodoro_status_lbl.visible:
		_position_pomodoro_status_label()


func _now_timestamp() -> String:
	return Time.get_datetime_string_from_system(false, true)
func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var mp := get_global_mouse_position()
				var on_panel: bool = (chat_panel.visible and chat_panel.is_dragging_title()) or (settings_panel.visible and settings_panel.is_dragging_title()) or (reminders_panel != null and reminders_panel.visible and reminders_panel.is_dragging_title()) or (todos_panel != null and todos_panel.visible and todos_panel.is_dragging_title()) or (pomodoro_panel != null and pomodoro_panel.visible and pomodoro_panel.is_dragging_title()) or (stargazing_panel != null and stargazing_panel.visible and stargazing_panel.is_dragging_title()) or (stargazing_panel != null and stargazing_panel.is_lightbox_open())
				if not on_panel and cat.get_global_rect().has_point(mp):
					dragging = true
					drag_mouse_start = DisplayServer.mouse_get_position()
					drag_window_start = get_window().position
			else:
				dragging = false
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and cat.get_global_rect().has_point(get_global_mouse_position()):
			_open_circular_menu()

	if event is InputEventMouseMotion and dragging:
		var delta = DisplayServer.mouse_get_position() - drag_mouse_start
		get_window().position = drag_window_start + delta


func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_shutdown()


func _uid() -> String:
	return str(randi())
