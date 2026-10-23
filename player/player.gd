class_name Player
extends CharacterBody2D
## Platformer player: run, jump with coyote time, jump buffering and variable jump height,
## a double jump in the air and an 8-direction dash (aimed with the movement keys) with limited charges.
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
@export var dash_speed: float = 340.0
@export var dash_time: float = 0.24
## Dashes available. They do NOT come back on landing; treats refill them (refill_dash).
@export var max_dash_charges: int = 1

## Dashes left right now.
var dash_charges: int = 1
## Air jumps left before landing again.
var air_jumps_left: int = 1
## 1.0 = facing right, -1.0 = facing left. Used when dashing with no direction held.
var facing: float = 1.0

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _was_on_floor: bool = true
var _dash_timer: float = 0.0
var _dash_direction: Vector2 = Vector2.RIGHT

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	air_jumps_left = air_jumps
	dash_charges = max_dash_charges
	# Deferred so a HUD that connects in its own _ready still gets the starting value.
	dash_charges_changed.emit.call_deferred(dash_charges)


func _physics_process(delta: float) -> void:
	var direction: float = Input.get_axis("move_left", "move_right")
	update_facing(direction)
	var jump_pressed: bool = Input.is_action_just_pressed("jump")
	update_timers(delta, is_on_floor(), jump_pressed)

	if Input.is_action_just_pressed("dash"):
		try_dash(Input.get_vector("move_left", "move_right", "move_up", "move_down"))

	if is_dashing():
		velocity = get_dash_velocity()
		advance_dash(delta)
	else:
		velocity.y = minf(velocity.y + current_gravity() * delta, max_fall_speed)
		if can_jump():
			_jump()
		elif can_double_jump(is_on_floor(), jump_pressed):
			_double_jump()
		if Input.is_action_just_released("jump") and velocity.y < 0.0:
			velocity.y *= jump_cut_multiplier
		velocity.x = next_horizontal_speed(velocity.x, direction, delta, is_on_floor())

	move_and_slide()
	if is_on_floor() and not _was_on_floor:
		landed.emit()
	_was_on_floor = is_on_floor()
	_update_animation()


## Which animation in dog_frames.tres fits the current movement.
static func animation_for(current_velocity: Vector2, on_floor: bool, dashing: bool = false) -> StringName:
	if dashing:
		return &"dash"
	if not on_floor:
		return &"jump" if current_velocity.y < 0.0 else &"fall"
	return &"run" if absf(current_velocity.x) > 10.0 else &"idle"


func get_jump_velocity() -> float:
	return -2.0 * jump_height / jump_time_to_peak


## Upward speed of the double jump: reaches double_jump_height under normal jump gravity.
func get_double_jump_velocity() -> float:
	return -sqrt(2.0 * get_jump_gravity() * double_jump_height)


## Distance one dash covers, in whichever direction it goes.
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
		air_jumps_left = air_jumps  # dash charges deliberately do NOT come back here
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	if jump_pressed:
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)


func can_jump() -> bool:
	return _coyote_timer > 0.0 and _jump_buffer_timer > 0.0


## True when a jump pressed this frame should be an air jump: airborne, coyote time over,
## and air jumps left. Uses the fresh press (not the buffer) so a jump buffered for landing
## stays a normal ground jump.
func can_double_jump(on_floor: bool, jump_pressed: bool) -> bool:
	return jump_pressed and not on_floor and _coyote_timer <= 0.0 and air_jumps_left > 0


func update_facing(direction: float) -> void:
	if direction != 0.0:
		facing = signf(direction)


func is_dashing() -> bool:
	return _dash_timer > 0.0


## Starts a dash aimed by `aim` (the movement keys/stick; y < 0 is up). Returns false if no charge is
## left or a dash is already running.
func try_dash(aim: Vector2) -> bool:
	if dash_charges <= 0 or is_dashing():
		return false
	_dash_direction = dash_direction_for(aim, facing)
	update_facing(_dash_direction.x)
	_dash_timer = dash_time
	dash_charges -= 1
	dashed.emit()
	dash_charges_changed.emit(dash_charges)
	return true


## Snaps an aim input to one of 8 directions (unit length). No aim = straight ahead the way the dog faces.
## Small stick tilts are ignored so a slightly-off stick still gives a clean straight dash.
static func dash_direction_for(aim: Vector2, facing_direction: float) -> Vector2:
	var snapped_aim := Vector2(
		signf(aim.x) if absf(aim.x) > 0.3 else 0.0,
		signf(aim.y) if absf(aim.y) > 0.3 else 0.0)
	if snapped_aim == Vector2.ZERO:
		return Vector2(facing_direction, 0.0)
	return snapped_aim.normalized()


func get_dash_direction() -> Vector2:
	return _dash_direction


## Velocity while dashing: straight along the dash direction, no gravity.
func get_dash_velocity() -> Vector2:
	return _dash_direction * dash_speed


## Counts the dash down. When it ends, speed drops to run speed along the dash direction
## (so an upward dash still carries a little upward momentum).
func advance_dash(delta: float) -> void:
	if not is_dashing():
		return
	_dash_timer = maxf(_dash_timer - delta, 0.0)
	if not is_dashing():
		velocity = _dash_direction * run_speed


func next_horizontal_speed(current: float, direction: float, delta: float, on_floor: bool) -> float:
	if direction != 0.0:
		var accel: float = ground_acceleration if on_floor else air_acceleration
		return move_toward(current, direction * run_speed, accel * delta)
	var decel: float = ground_friction if on_floor else air_acceleration
	return move_toward(current, 0.0, decel * delta)


func _update_animation() -> void:
	_sprite.flip_h = facing < 0.0  # the sprite sheet faces right
	var animation: StringName = animation_for(velocity, is_on_floor(), is_dashing())
	if _sprite.animation != animation:
		_sprite.play(animation)


func _jump() -> void:
	velocity.y = get_jump_velocity()
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	jumped.emit()


func _double_jump() -> void:
	velocity.y = get_double_jump_velocity()
	air_jumps_left -= 1
	_jump_buffer_timer = 0.0  # this press is used up; don't jump again on landing
	double_jumped.emit()
