class_name Player
extends CharacterBody2D
## Platformer player: run, jump with coyote time, jump buffering and variable jump height.
## Jump is tuned by height and timing (pixels / seconds) instead of raw gravity values.

signal jumped
signal landed
signal double_jumped
signal dashed
## A treat (or anything else) refilled the dash.
signal dash_refilled
signal dash_charges_changed(charges: int)

@export_group("Run")
@export var run_speed: float = 115.0
@export var ground_acceleration: float = 1000.0
@export var ground_friction: float = 1200.0
@export var air_acceleration: float = 700.0

@export_group("Jump")
## Peak height of a full jump, in pixels. The level generator spaces platforms from this.
@export var jump_height: float = 88.0
@export var jump_time_to_peak: float = 0.45
@export var jump_time_to_fall: float = 0.36
## Fraction of upward speed kept when jump is released early.
@export var jump_cut_multiplier: float = 0.45
## Seconds after leaving a ledge during which a jump still works.
@export var coyote_time: float = 0.1
## Seconds a jump press is remembered before landing.
@export var jump_buffer_time: float = 0.12
@export var max_fall_speed: float = 420.0

@export_group("Double jump")
## Extra jumps allowed in the air before landing again.
@export var air_jumps: int = 1
## Height of the extra jump in the air, in pixels (added on top of wherever the first jump got to).
@export var double_jump_height: float = 56.0

@export_group("Dash")
@export var dash_speed: float = 320.0
@export var dash_time: float = 0.16
## Dashes available. They do NOT come back on landing; treats refill them (refill_dash).
@export var max_dash_charges: int = 1

## Dashes left right now.
var dash_charges: int = 1

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _was_on_floor: bool = true

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _physics_process(delta: float) -> void:
	var direction: float = Input.get_axis("move_left", "move_right")
	update_timers(delta, is_on_floor(), Input.is_action_just_pressed("jump"))

	velocity.y = minf(velocity.y + current_gravity() * delta, max_fall_speed)
	if can_jump():
		_jump()
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier

	velocity.x = next_horizontal_speed(velocity.x, direction, delta, is_on_floor())
	move_and_slide()
	if is_on_floor() and not _was_on_floor:
		landed.emit()
	_was_on_floor = is_on_floor()
	_update_animation(direction)


## Which animation in dog_frames.tres fits the current movement.
static func animation_for(current_velocity: Vector2, on_floor: bool) -> StringName:
	if not on_floor:
		return &"jump" if current_velocity.y < 0.0 else &"fall"
	return &"run" if absf(current_velocity.x) > 10.0 else &"idle"


func get_jump_velocity() -> float:
	return -2.0 * jump_height / jump_time_to_peak


## Upward speed of the double jump: reaches double_jump_height under normal jump gravity.
func get_double_jump_velocity() -> float:
	return -sqrt(2.0 * get_jump_gravity() * double_jump_height)


## Horizontal distance one dash covers.
func get_dash_distance() -> float:
	return dash_speed * dash_time


## Gives back all dashes (called by treats).
func refill_dash() -> void:
	dash_charges = max_dash_charges
	dash_charges_changed.emit(dash_charges)
	dash_refilled.emit()


func get_jump_gravity() -> float:
	return 2.0 * jump_height / (jump_time_to_peak * jump_time_to_peak)


func get_fall_gravity() -> float:
	return 2.0 * jump_height / (jump_time_to_fall * jump_time_to_fall)


func current_gravity() -> float:
	return get_jump_gravity() if velocity.y < 0.0 else get_fall_gravity()


func update_timers(delta: float, on_floor: bool, jump_pressed: bool) -> void:
	if on_floor:
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	if jump_pressed:
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)


func can_jump() -> bool:
	return _coyote_timer > 0.0 and _jump_buffer_timer > 0.0


func next_horizontal_speed(current: float, direction: float, delta: float, on_floor: bool) -> float:
	if direction != 0.0:
		var accel: float = ground_acceleration if on_floor else air_acceleration
		return move_toward(current, direction * run_speed, accel * delta)
	var decel: float = ground_friction if on_floor else air_acceleration
	return move_toward(current, 0.0, decel * delta)


func _update_animation(direction: float) -> void:
	if direction != 0.0:
		_sprite.flip_h = direction < 0.0  # the sprite sheet faces right
	var animation: StringName = animation_for(velocity, is_on_floor())
	if _sprite.animation != animation:
		_sprite.play(animation)


func _jump() -> void:
	velocity.y = get_jump_velocity()
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	jumped.emit()
