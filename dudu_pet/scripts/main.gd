extends Control

# DuDu Pet — Main controller
# Window, cat sprite, WebSocket, circular menu, chat panel, hover input.

# Nodes
@onready var cat: TextureRect = $CatTexture
@onready var speech_bubble: PanelContainer = $SpeechBubble
@onready var bubble: Label = $SpeechBubble/BubbleLabel
@onready var circ_menu: Control = $CircularMenu
var chat_panel: ChatPanel = null

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
enum Anim { IDLE, TALKING, PETTED }
var current_anim: Anim = Anim.IDLE
var _anim_lock: bool = false
var _breathe_tween: Tween = null

# Hover input
var _hover_input: PanelContainer = null
var _hover_text: TextEdit = null
var _hover_tween: Tween = null
var _hovering: bool = false
var _hover_shown_at: int = 0

# Streaming state
var _streaming_bubble: bool = false
var _stream_buffer: String = ""
var _floating_assistant_added: bool = false
var _floating_bubbles: VBoxContainer = null
var _history_cache: Array = []

const MSG_BUBBLE = preload("res://scenes/message_bubble.tscn")
const ChatBubbleStyle = preload("res://scripts/chat_bubble_style.gd")
const BASE_CAT_SIZE := 128.0
const BASE_SPACE_ABOVE_CAT := 380.0
const INPUT_GAP_ABOVE_CAT := 12.0
const BUBBLE_GAP_ABOVE_INPUT := 14.0
const BREATHE_PEAK_Y := 1.012
const BREATHE_PERIOD := 2.6

var _cat_base_height: float = 128.0
var _cat_center_x: float = 0.0
var _cat_bottom: float = 0.0
var _stack_layout_gen: int = 0


# ============================================================
# Init
# ============================================================

func _ready():
	_setup_window()
	_load_cat_texture()
	_style_speech_bubble()
	_create_hover_input()
	_create_floating_bubbles()
	_setup_chat_panel()
	_apply_ui_scale_to_children()
	_apply_layer_order()
	_wire_signals()
	_play_anim(Anim.IDLE)
	_connect_ws()
	get_tree().create_timer(1.0).timeout.connect(_check_and_launch_backend)
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
	# Back → front: cat, speech, bubbles, input (input must stay above bubbles)
	var ordered: Array[Node] = [cat, speech_bubble, _floating_bubbles, _hover_input, circ_menu]
	if chat_panel:
		ordered.append(chat_panel)
	for i in ordered.size():
		move_child(ordered[i], i)


func _setup_chat_panel():
	var scene = load("res://scenes/chat_panel.tscn")
	chat_panel = scene.instantiate()
	add_child(chat_panel)


func _apply_ui_scale_to_children() -> void:
	chat_panel.apply_ui_scale()
	circ_menu.apply_ui_scale()
	_schedule_stack_layout()


func _setup_window():
	var screen_idx := DisplayServer.window_get_current_screen()
	var screen_size := DisplayServer.screen_get_size(screen_idx)
	var screen_pos := DisplayServer.screen_get_position(screen_idx)
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


func _load_cat_texture():
	var img_path = ProjectSettings.globalize_path("res://").path_join("../assets/占位.png")
	var img = Image.load_from_file(img_path)
	if img:
		cat.texture = ImageTexture.create_from_image(img)
	else:
		_make_placeholder_cat()


func _make_placeholder_cat():
	var size := 128; var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var cx := size / 2; var cy := size / 2; var r := 56
	for x in size:
		for y in size:
			var dx = x - cx; var dy = y - cy
			if dx * dx + dy * dy <= r * r:
				img.set_pixel(x, y, Color(0.35, 0.52, 0.71, 1))
				if abs(x - (cx - 18)) <= 6 and abs(y - (cy - 10)) <= 5:
					img.set_pixel(x, y, Color(0.1, 0.1, 0.15, 1))
				if abs(x - (cx + 18)) <= 6 and abs(y - (cy - 10)) <= 5:
					img.set_pixel(x, y, Color(0.1, 0.1, 0.15, 1))
				var mx = x - cx; var my = y - (cy + 8)
				if abs(mx) <= 8 and abs(my - (-abs(mx * 0.6))) <= 1.5:
					img.set_pixel(x, y, Color(0.1, 0.1, 0.15, 1))
	cat.texture = ImageTexture.create_from_image(img)


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
	_hover_input.mouse_exited.connect(_on_cat_mouse_exit)



func _create_floating_bubbles():
	_floating_bubbles = VBoxContainer.new()
	_floating_bubbles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floating_bubbles.alignment = BoxContainer.ALIGNMENT_CENTER
	_floating_bubbles.add_theme_constant_override("separation", UiConfig.si(6))
	_floating_bubbles.hide()
	_floating_bubbles.modulate.a = 0
	add_child(_floating_bubbles)
func _transparent_stylebox() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()


func _wire_signals():
	circ_menu.item_selected.connect(_on_menu_action)
	chat_panel.message_sent.connect(_on_chat_send)
	chat_panel.close_requested.connect(func(): chat_panel.hide())
	cat.mouse_entered.connect(_on_cat_mouse_enter)
	cat.mouse_exited.connect(_on_cat_mouse_exit)


# ============================================================
# Hover input
# ============================================================

func _on_cat_mouse_enter():
	_hovering = true
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	# Wait 1 second before showing
	_hover_tween = create_tween()
	_hover_tween.tween_interval(0.5)
	_hover_tween.tween_callback(_show_hover_input)


func _on_cat_mouse_exit():
	_hovering = false
	# Minimum 2s display; then hide after mouse leaves both cat and input
	var elapsed := Time.get_ticks_msec() - _hover_shown_at
	var grace := 0.3 if elapsed >= 2000 else (2000 - elapsed) / 1000.0 + 0.3
	await get_tree().create_timer(grace).timeout
	if not _hovering and not _hover_input.get_global_rect().has_point(get_global_mouse_position()):
		_hide_hover_input()


func _show_hover_input():
	_hover_shown_at = Time.get_ticks_msec()
	if not _hovering:
		return
	_position_hover_input()
	_hover_input.modulate.a = 0
	_hover_input.show()
	if _floating_bubbles.get_child_count() > 0:
		_floating_bubbles.show()
		_floating_bubbles.modulate.a = 1
	_schedule_stack_layout()
	var tw = create_tween()
	tw.tween_property(_hover_input, "modulate:a", 1.0, 0.2)
func _hide_hover_input():
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(_hover_input, "modulate:a", 0.0, 0.15)
	_hover_tween.tween_callback(func():
		_hover_input.hide()
		if _floating_bubbles.get_child_count() > 0 or speech_bubble.visible:
			_schedule_stack_layout()
	)


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
				_hide_hover_input()
			get_viewport().set_input_as_handled()


# ============================================================
# Circular menu
# ============================================================

func _on_menu_action(action: String):
		match action:
			"chat_history":
				_open_chat_history()
			"reminders":
				_show_bubble("定时提醒功能即将上线~")
			"explore":
				_send_chat("嘟嘟想做点什么")
			"fortune":
				_send_chat("今日运势")
			"settings":
				_show_bubble("设置功能即将上线~")


func _open_circular_menu():
	circ_menu.open(_cat_center())


# ============================================================
# Chat
# ============================================================

func _send_chat(text: String, panel_user_added: bool = false):
	if not panel_user_added:
		chat_panel.add_message("user", text, _now_timestamp())
	_send_ws({
		"type": "user.chat",
		"text": text,
	})
	_play_anim(Anim.TALKING)
	_streaming_bubble = true
	_stream_buffer = ""
	speech_bubble.hide()
	# Only the current turn — never replay history or prior session bubbles
	_clear_floating_bubbles()
	_show_floating_bubbles()
	_add_floating_bubble("user", text)
	_floating_assistant_added = false


func _on_chat_send(text: String):
	_send_chat(text, true)


func _open_chat_history():
	chat_panel.open(_cat_center())
	if not _history_cache.is_empty():
		chat_panel.clear_messages()
		chat_panel.add_messages(_history_cache)
	_send_ws({"type": "history.request"})


func _show_floating_bubbles():
	_floating_bubbles.show()
	_floating_bubbles.modulate.a = 1.0
	_schedule_stack_layout()


# ============================================================
# WebSocket
# ============================================================

func _connect_ws():
	ws.connect_to_url(WS_URL)


func _process(_delta):
	ws.poll()
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
				# Floating message bubbles only (same style as 魔法日记)
				# Update chat panel
				if chat_panel.visible:
					if _streaming_bubble:
						chat_panel.add_message("assistant", delta, _now_timestamp())
						_streaming_bubble = false
					else:
						chat_panel.append_last(delta)

				_show_floating_bubbles()
				if not _floating_assistant_added:
					_add_floating_bubble("assistant", delta)
					_floating_assistant_added = true
				else:
					_append_floating_bubble(delta)
			"assistant.done":
				var full = msg["payload"].get("full_text", _stream_buffer)
				if chat_panel.visible and _stream_buffer != "":
					pass  # already appended via chunks
				_stream_buffer = ""
				_streaming_bubble = false
				_floating_assistant_added = false
				_schedule_stack_layout()
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

			_:
				print("Unhandled: ", msg["type"])


func _handle_action(action: String):
	match action:
		"petted": _play_anim(Anim.PETTED)
		"talking": _play_anim(Anim.TALKING)
		_: pass


func _reconnect():
	var t = Time.get_ticks_msec()
	if _ws_retry_ts < t:
		_ws_retry_ts = t + 3000
		ws = WebSocketPeer.new()
		ws.connect_to_url(WS_URL)
		print("WS reconnect...")



func _update_passthrough():
	var rects: Array[Rect2] = []
	rects.append(cat.get_global_rect())
	if speech_bubble.visible:
		rects.append(speech_bubble.get_global_rect())
	if _hover_input.visible and _hover_input.modulate.a > 0:
		rects.append(_hover_input.get_global_rect())
	if _floating_bubbles.visible and _floating_bubbles.get_child_count() > 0:
		rects.append(_floating_bubbles.get_global_rect())
	if chat_panel.visible:
		rects.append(chat_panel.get_global_rect())
	if circ_menu.is_open():
		for r in circ_menu.get_button_global_rects():
			rects.append(r)
	if rects.is_empty():
		return
	# Merge all rects into one bounding box
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
	if _anim_lock and anim != current_anim:
		return
	if _breathe_tween and _breathe_tween.is_valid():
		_breathe_tween.kill()
	current_anim = anim

	match anim:
		Anim.IDLE:
			_start_breathing()
		Anim.TALKING:
			_start_breathing(BREATHE_PEAK_Y + 0.004, 1.2)
		Anim.PETTED:
			_anim_lock = true
			var tw = create_tween()
			tw.tween_method(_set_cat_breathe, 1.0, 0.97, 0.1)
			tw.tween_method(_set_cat_breathe, 0.97, BREATHE_PEAK_Y + 0.01, 0.12)
			tw.tween_method(_set_cat_breathe, BREATHE_PEAK_Y + 0.01, 1.0, 0.15)
			tw.tween_callback(func(): _anim_lock = false; _play_anim(Anim.IDLE))


func _start_breathing(peak_y: float = BREATHE_PEAK_Y, period: float = BREATHE_PERIOD):
	_set_cat_breathe(1.0)
	_breathe_tween = create_tween().set_loops()
	_breathe_tween.tween_method(_set_cat_breathe, 1.0, peak_y, period).set_ease(Tween.EASE_IN_OUT)
	_breathe_tween.tween_method(_set_cat_breathe, peak_y, 1.0, period).set_ease(Tween.EASE_IN_OUT)


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

func _position_bubble():
	bubble.reset_size()
	speech_bubble.reset_size()
	var cx := _cat_center().x
	var bw := speech_bubble.size.x
	var bh := speech_bubble.size.y
	speech_bubble.position = Vector2(cx - bw / 2.0, _bubble_bottom_limit() - bh)


func _now_timestamp() -> String:
	return Time.get_datetime_string_from_system(false, true)
func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var mp := get_global_mouse_position()
				var on_panel: bool = chat_panel.visible and chat_panel.is_dragging_title()
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
