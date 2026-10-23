@tool
class_name Platform
extends StaticBody2D
## Platform drawn from tiles/platforms.png. Pick the zone style and width in the Inspector.
## The node's origin is the centre of the walkable top surface.

enum Zone { GRASS, LAUNCHPAD, CLOUD, GIRDER, SOLAR, ASTEROID, MOON }

const TILE_SIZE: int = 16
const ATLAS: Texture2D = preload("res://assets/art/tiles/platforms.png")

## Visual style; each zone is one row in the tile atlas.
@export var zone: Zone = Zone.GRASS:
	set(value):
		zone = value
		queue_redraw()

@export_range(1, 64) var width_tiles: int = 4:
	set(value):
		width_tiles = value
		_update_collision()
		queue_redraw()

## One-way platforms can be jumped through from below.
@export var one_way: bool = true:
	set(value):
		one_way = value
		_update_collision()


func _ready() -> void:
	_update_collision()


func _draw() -> void:
	var left: float = -width_tiles * TILE_SIZE / 2.0
	for i: int in width_tiles:
		var source := Rect2(tile_column(i, width_tiles) * TILE_SIZE, int(zone) * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		var target := Rect2(left + i * TILE_SIZE, -1.0, TILE_SIZE, TILE_SIZE)
		draw_texture_rect_region(ATLAS, target, source)


## Atlas column for tile `index` of a platform `count` tiles wide: 0 left cap, 1 middle, 2 right cap, 3 single.
static func tile_column(index: int, count: int) -> int:
	if count == 1:
		return 3
	if index == 0:
		return 0
	if index == count - 1:
		return 2
	return 1


func _update_collision() -> void:
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width_tiles * TILE_SIZE - 2, 8)
	collision.shape = shape
	collision.position = Vector2(0, 4)
	collision.one_way_collision = one_way
