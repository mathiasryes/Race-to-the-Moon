class_name RaceDirector
extends Node
## Runs the race against the rocket: countdown, liftoff, then the rocket climbs at its own pace.
## The rocket lives in the world, so it drifts up or down the screen depending on how fast the player climbs.
## Lose when the rocket's nozzle leaves the top of the screen; win when the player reaches the goal.

signal countdown_changed(seconds_left: int)
signal lifted_off
## 0 = safe, 1 = the rocket is about to leave the screen.
signal danger_changed(amount: float)
signal race_lost
signal race_won

enum State { COUNTDOWN, RACING, LOST, WON }

@export var rocket: Rocket
## Area2D the player must reach to win (usually at the moon).
@export var goal: Area2D

@export_group("Tuning")
## Seconds before liftoff. The player can already climb: it's a head start.
@export var countdown_time: float = 3.0
## Rocket climb speed after it has finished accelerating, in px/s.
@export var cruise_speed: float = 55.0
## Seconds the rocket takes to reach cruise speed after liftoff.
@export var acceleration_time: float = 3.0
## Warning starts when the nozzle is this many px below the top of the screen.
@export var danger_zone: float = 100.0

var state: State = State.COUNTDOWN

var _time: float = 0.0
var _launch_y: float = 0.0
var _last_count: int = -1
var _last_danger: float = -1.0


func _ready() -> void:
	_launch_y = rocket.position.y
	if goal:
		goal.body_entered.connect(_on_goal_body_entered)


func _physics_process(delta: float) -> void:
	match state:
		State.COUNTDOWN:
			_time += delta
			var seconds_left: int = ceili(countdown_time - _time)
			if seconds_left != _last_count:
				_last_count = seconds_left
				countdown_changed.emit(seconds_left)
			if _time >= countdown_time:
				_time = 0.0
				state = State.RACING
				rocket.engine_on = true
				lifted_off.emit()
		State.RACING:
			_time += delta
			rocket.position.y = _launch_y - rocket_height_at(_time, cruise_speed, acceleration_time)
			var view_top: float = _view_top()
			var danger: float = danger_amount(rocket.global_position.y, view_top, danger_zone)
			if not is_equal_approx(danger, _last_danger):
				_last_danger = danger
				danger_changed.emit(danger)
			if rocket_has_escaped(rocket.global_position.y, view_top):
				_end(State.LOST)


## Height the rocket has climbed `time` seconds after liftoff (linear speed-up, then constant speed).
static func rocket_height_at(time: float, cruise: float, accel_time: float) -> float:
	if time <= 0.0:
		return 0.0
	if accel_time <= 0.0:
		return cruise * time
	if time < accel_time:
		return 0.5 * cruise / accel_time * time * time
	return 0.5 * cruise * accel_time + cruise * (time - accel_time)


## True once the rocket's nozzle (its lowest point) is above the top edge of the screen.
static func rocket_has_escaped(nozzle_y: float, view_top: float) -> bool:
	return nozzle_y < view_top


static func danger_amount(nozzle_y: float, view_top: float, zone: float) -> float:
	return clampf(1.0 - (nozzle_y - view_top) / zone, 0.0, 1.0)


func _view_top() -> float:
	var camera: Camera2D = get_viewport().get_camera_2d()
	var half_height: float = get_viewport().get_visible_rect().size.y * 0.5
	if camera == null:
		return -half_height
	return camera.get_screen_center_position().y - half_height / camera.zoom.y


func _on_goal_body_entered(body: Node2D) -> void:
	if body is Player and (state == State.COUNTDOWN or state == State.RACING):
		_end(State.WON)


func _end(result: State) -> void:
	state = result
	if result == State.WON:
		race_won.emit()
	else:
		race_lost.emit()
	get_tree().paused = true
