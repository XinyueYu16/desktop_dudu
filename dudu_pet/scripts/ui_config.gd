class_name UiConfig
extends RefCounted

# Global UI scale — wire settings panel to user_multiplier later.

const DESIGN_SIZE := Vector2(1200, 820)
const SCREEN_MARGIN := Vector2i(32, 32)

static var scale: float = 1.0
static var user_multiplier: float = 1.0
static var window_size: Vector2i = Vector2i(1200, 820)
static var _base_fit: float = 1.0

const UI_SCALE_CACHE := "user://dudu_ui_scale.txt"


static func bootstrap_multiplier() -> void:
	if _load_multiplier_from_cache():
		return
	var backend_json := ProjectSettings.globalize_path("res://").path_join(
		"../backend/data/settings.json"
	)
	_load_multiplier_from_settings_json(backend_json)


static func persist_multiplier() -> void:
	var f := FileAccess.open(UI_SCALE_CACHE, FileAccess.WRITE)
	if f:
		f.store_string(str(user_multiplier))


static func _load_multiplier_from_cache() -> bool:
	if not FileAccess.file_exists(UI_SCALE_CACHE):
		return false
	var text := FileAccess.get_file_as_string(UI_SCALE_CACHE).strip_edges()
	if text.is_empty():
		return false
	set_user_multiplier(float(text))
	return true


static func _load_multiplier_from_settings_json(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return
	var ui: Variant = parsed.get("ui", {})
	if ui is Dictionary and ui.has("scale_multiplier"):
		set_user_multiplier(float(ui["scale_multiplier"]))


static func init_from_screen(screen_size: Vector2i) -> void:
	window_size = Vector2i(
		maxi(800, screen_size.x - SCREEN_MARGIN.x * 2),
		maxi(600, screen_size.y - SCREEN_MARGIN.y * 2)
	)
	_base_fit = minf(
		window_size.x / DESIGN_SIZE.x,
		window_size.y / DESIGN_SIZE.y
	)
	scale = _base_fit * user_multiplier


static func set_user_multiplier(value: float) -> void:
	user_multiplier = clampf(value, 0.85, 1.5)
	scale = _base_fit * user_multiplier


static func s(value: float) -> float:
	return value * scale


static func si(value: int) -> int:
	return int(round(value * scale))
