class_name AltitudeBackground
extends Node2D
## Screen-space background that follows the camera's height: Earth sky at the ground, deep space at the top.
## Place it inside a CanvasLayer with a negative layer so it draws behind the level.

const SKY: Texture2D = preload("res://assets/art/backgrounds/sky_gradient.png")
const STARS_FAR: Texture2D = preload("res://assets/art/backgrounds/stars_far.png")
const STARS_NEAR: Texture2D = preload("res://assets/art/backgrounds/stars_near.png")
const SKYLINE: Texture2D = preload("res://assets/art/backgrounds/earth_skyline.png")
const HORIZON: Texture2D = preload("res://assets/art/backgrounds/earth_horizon.png")

## World y of the ground at the start of the climb.
@export var ground_y: float = 0.0
## Pixels the player climbs before the sky is fully space. Real levels: a few thousand.
@export var climb_height: float = 3000.0

var _camera_y: float = NAN


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


func _process(_delta: float) -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null:
		return
	var y: float = camera.get_screen_center_position().y
	if y != _camera_y:
		_camera_y = y
		queue_redraw()


## 0 at the ground, 1 once `climb_height` pixels above it. `altitude` = height of the screen's bottom edge.
static func altitude_progress(altitude: float, height: float) -> float:
	return clampf(altitude / height, 0.0, 1.0)


func _draw() -> void:
	if is_nan(_camera_y):
		return
	var view: Vector2 = get_viewport_rect().size
	var altitude: float = ground_y - (_camera_y + view.y * 0.5)
	var progress: float = altitude_progress(altitude, climb_height)

	var sky_offset: float = roundf(lerpf(SKY.get_height() - view.y, 0.0, progress))
	draw_texture_rect_region(SKY, Rect2(Vector2.ZERO, view), Rect2(0.0, sky_offset, view.x, view.y))

	var star_alpha: float = smoothstep(0.35, 0.7, progress)
	if star_alpha > 0.0:
		_draw_tiled(STARS_FAR, altitude * 0.05, view, Color(1, 1, 1, star_alpha))
		_draw_tiled(STARS_NEAR, altitude * 0.12, view, Color(1, 1, 1, star_alpha))

	# The curved Earth rises into view as we leave the atmosphere, then sinks away below us.
	var horizon_rise: float = smoothstep(0.45, 0.7, progress) * 110.0 - smoothstep(0.85, 1.0, progress) * 70.0
	if horizon_rise > 0.0:
		draw_texture(HORIZON, Vector2(0.0, roundf(view.y - horizon_rise)))

	# Hills and trees at the launch site scroll away at half speed.
	var skyline_y: float = roundf(view.y - SKYLINE.get_height() + 40.0 + altitude * 0.5)
	if skyline_y < view.y:
		draw_texture(SKYLINE, Vector2(0.0, skyline_y))


func _draw_tiled(texture: Texture2D, offset_y: float, view: Vector2, color: Color) -> void:
	var y: float = roundf(fposmod(offset_y, texture.get_height()))
	draw_texture_rect_region(texture, Rect2(Vector2.ZERO, view), Rect2(0.0, -y, view.x, view.y), color)
