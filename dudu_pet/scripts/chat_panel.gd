class_name ChatPanel
extends Control

# Chat history panel — "🌙 魔法日记"
# Floating dialog, positioned near the cat.

signal message_sent(text: String)
signal close_requested

@onready var message_list: VBoxContainer = $PanelBg/MessageScroll/MessageList
@onready var message_scroll: ScrollContainer = $PanelBg/MessageScroll
@onready var input_field: TextEdit = $PanelBg/InputContainer/InputHBox/InputField
@onready var send_btn: Button = $PanelBg/InputContainer/InputHBox/SendBtn
@onready var close_btn: Button = $PanelBg/TitleBar/TitleHBox/CloseBtn
@onready var title_bar: MarginContainer = $PanelBg/TitleBar

const MSG_BUBBLE = preload("res://scenes/message_bubble.tscn")

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO


func _ready():
    hide()
    mouse_filter = Control.MOUSE_FILTER_STOP
    _apply_style()
    title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
    title_bar.gui_input.connect(_on_title_bar_input)
    input_field.text_changed.connect(_on_input_changed)
    send_btn.pressed.connect(_send_message)
    close_btn.pressed.connect(func(): close_requested.emit(); hide())


func is_dragging_title() -> bool:
    return _dragging


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


func _apply_style():
    # PanelBg dark rounded background
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.12, 0.12, 0.18, 0.95)
    sb.corner_radius_top_left = 16; sb.corner_radius_top_right = 16
    sb.corner_radius_bottom_left = 16; sb.corner_radius_bottom_right = 16
    sb.border_width_left = 1; sb.border_width_right = 1
    sb.border_width_top = 1; sb.border_width_bottom = 1
    sb.border_color = Color(1, 1, 1, 0.1)
    var panel_bg: Panel = $PanelBg
    panel_bg.add_theme_stylebox_override("panel", sb)

    # Input field style
    var isb := StyleBoxFlat.new()
    isb.bg_color = Color(0.18, 0.18, 0.24, 1)
    isb.corner_radius_top_left = 8; isb.corner_radius_top_right = 8
    isb.corner_radius_bottom_left = 8; isb.corner_radius_bottom_right = 8
    input_field.add_theme_stylebox_override("normal", isb)
    input_field.add_theme_stylebox_override("focus", isb)
    input_field.add_theme_color_override("font_color", Color(1, 1, 1, 1))
    input_field.add_theme_font_size_override("font_size", 14)
    input_field.placeholder_text = "说点什么..."

    # Send button style
    send_btn.add_theme_font_size_override("font_size", 13)


func open(near_position: Vector2):
    var view_size := get_viewport().get_visible_rect().size
    position.x = near_position.x + 100
    position.y = near_position.y - size.y / 2.0
    if position.x + size.x > view_size.x:
        position.x = near_position.x - size.x - 20
    position.y = clampf(position.y, 0, view_size.y - size.y)
    show()
    input_field.grab_focus()


func add_message(role: String, text: String):
    var bubble := MSG_BUBBLE.instantiate()
    message_list.add_child(bubble)
    bubble.setup(role, text)
    _scroll_to_bottom.call_deferred()


func add_messages(messages: Array):
    for m in messages:
        var role: String = m.get("role", "assistant")
        var content: String = m.get("content", "")
        if content.is_empty():
            continue
        var bubble := MSG_BUBBLE.instantiate()
        message_list.add_child(bubble)
        bubble.setup(role, content)
    _scroll_to_bottom.call_deferred()

func clear_messages():
    for c in message_list.get_children():
        message_list.remove_child(c)
        c.queue_free()

func _scroll_to_bottom():
    await get_tree().process_frame
    message_list.reset_size()
    var bar := message_scroll.get_v_scroll_bar()
    message_scroll.scroll_vertical = bar.max_value


func append_last(text: String):
    var n := message_list.get_child_count()
    if n > 0:
        var last := message_list.get_child(n - 1)
        if last.has_method("append_text"):
            last.append_text(text)
    _scroll_to_bottom.call_deferred()


func add_date_divider(date_str: String):
    var lbl := Label.new()
    lbl.text = "── " + date_str + " ──"
    lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 1))
    lbl.add_theme_font_size_override("font_size", 12)
    message_list.add_child(lbl)


func _send_message():
    var text := input_field.text.strip_edges()
    if text.is_empty():
        return
    input_field.text = ""
    add_message("user", text)
    message_sent.emit(text)


func _on_input_changed():
    send_btn.disabled = input_field.text.strip_edges().is_empty()
