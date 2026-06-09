class_name UiConfig
extends RefCounted

# Global UI scale — wire settings panel to user_multiplier later.

const DESIGN_SIZE := Vector2(1200, 820)
const SCREEN_MARGIN := Vector2i(32, 32)

static var scale: float = 1.0
static var user_multiplier: float = 1.0
static var window_size: Vector2i = Vector2i(1200, 820)


static func init_from_screen(screen_size: Vector2i) -> void:
	window_size = Vector2i(
		maxi(800, screen_size.x - SCREEN_MARGIN.x * 2),
		maxi(600, screen_size.y - SCREEN_MARGIN.y * 2)
	)
	var fit := minf(
		window_size.x / DESIGN_SIZE.x,
		window_size.y / DESIGN_SIZE.y
	)
	scale = fit * user_multiplier


static func set_user_multiplier(value: float) -> void:
	user_multiplier = clampf(value, 0.85, 1.5)


static func s(value: float) -> float:
	return value * scale


static func si(value: int) -> int:
	return int(round(value * scale))
