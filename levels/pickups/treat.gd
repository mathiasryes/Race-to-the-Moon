class_name Treat
extends Area2D
## Dog treat pickup: refills the player's dash when touched, then pops and disappears.
## The node's origin is the centre of the treat. Only the sprite bobs; the collision area stays put.

signal collected

## How far the treat bobs up and down, in pixels.
@export var bob_height: float = 2.0
## Bobs per second.
@export var bob_speed: float = 0.8
## Length of the pop/fade when collected, in seconds.
@export var pop_time: float = 0.2

var is_collected: bool = false
var _bob_time: float = 0.0

@onready var _sprite: AnimatedSprite2D = get_node_or_null(^"AnimatedSprite2D") as AnimatedSprite2D
@onready var _shape: CollisionShape2D = get_node_or_null(^"CollisionShape2D") as CollisionShape2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_bob_time = fposmod(global_position.x * 0.013, 1.0)  # treats next to each other don't bob in sync
	if _sprite:
		_sprite.play(&"shine")
		_sprite.frame = int(_bob_time * 4.0) % _sprite.sprite_frames.get_frame_count(&"shine")


func _process(delta: float) -> void:
	if is_collected or _sprite == null:
		return
	_bob_time += delta * bob_speed
	_sprite.position.y = bob_offset(_bob_time, bob_height)


## Vertical sprite offset for a bob phase (1.0 = one full bob). Whole pixels to keep the pixel art crisp.
static func bob_offset(phase: float, height: float) -> float:
	return roundf(sin(phase * TAU) * height)


func _on_body_entered(body: Node2D) -> void:
	if is_collected or not (body is Player):
		return
	is_collected = true
	# Physics state can't change inside a physics callback, so switch the collision off deferred.
	set_deferred(&"monitoring", false)
	if _shape:
		_shape.set_deferred(&"disabled", true)
	(body as Player).refill_dash()
	collected.emit()
	_pop()


func _pop() -> void:
	if not is_inside_tree() or _sprite == null:
		queue_free()
		return
	_sprite.position.y = 0.0
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(_sprite, ^"scale", Vector2(1.8, 1.8), pop_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, ^"position:y", -6.0, pop_time)
	tween.tween_property(_sprite, ^"modulate:a", 0.0, pop_time).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
