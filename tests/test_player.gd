extends "res://tests/framework/test_case.gd"

const PlayerScript := preload("res://player/player.gd")


func _make_player() -> Player:
	return PlayerScript.new()


func test_full_jump_reaches_configured_height() -> void:
	var player: Player = _make_player()
	var v: float = player.get_jump_velocity()
	var peak: float = (v * v) / (2.0 * player.get_jump_gravity())
	assert_almost_eq(peak, player.jump_height, 0.01)
	player.free()


func test_falling_is_faster_than_rising() -> void:
	var player: Player = _make_player()
	assert_true(player.get_fall_gravity() > player.get_jump_gravity())
	player.free()


func test_coyote_time_allows_late_jump() -> void:
	var player: Player = _make_player()
	player.update_timers(0.016, true, false)  # standing on ground
	player.update_timers(player.coyote_time * 0.5, false, true)  # walked off, then pressed jump
	assert_true(player.can_jump(), "jump should work shortly after leaving a ledge")
	player.free()


func test_coyote_time_expires() -> void:
	var player: Player = _make_player()
	player.update_timers(0.016, true, false)
	player.update_timers(player.coyote_time + 0.05, false, false)
	player.update_timers(0.016, false, true)
	assert_false(player.can_jump(), "jump should not work long after leaving a ledge")
	player.free()


func test_jump_buffer_triggers_on_landing() -> void:
	var player: Player = _make_player()
	player.update_timers(0.016, false, true)  # pressed jump in the air
	player.update_timers(player.jump_buffer_time * 0.5, true, false)  # landed soon after
	assert_true(player.can_jump(), "buffered jump should fire on landing")
	player.free()


func test_horizontal_speed_caps_at_run_speed() -> void:
	var player: Player = _make_player()
	var speed: float = 0.0
	for i: int in 120:
		speed = player.next_horizontal_speed(speed, 1.0, 0.016, true)
	assert_almost_eq(speed, player.run_speed)
	player.free()


# --- Double jump ---

func _airborne_after_coyote(player: Player) -> void:
	player.update_timers(0.016, true, false)  # on the ground: refills air jumps
	player.update_timers(player.coyote_time + 0.05, false, false)  # left the ground, coyote over


func test_double_jump_allowed_once_in_the_air() -> void:
	var player: Player = _make_player()
	_airborne_after_coyote(player)
	player.update_timers(0.016, false, true)
	assert_false(player.can_jump(), "a normal jump should not be possible here")
	assert_true(player.can_double_jump(false, true), "first air jump should be allowed")
	player.air_jumps_left -= 1  # what _double_jump() does
	assert_false(player.can_double_jump(false, true), "only one air jump by default")
	player.free()


func test_double_jump_resets_on_landing() -> void:
	var player: Player = _make_player()
	_airborne_after_coyote(player)
	player.air_jumps_left = 0
	player.update_timers(0.016, true, false)  # landed
	assert_eq(player.air_jumps_left, player.air_jumps)
	player.update_timers(player.coyote_time + 0.05, false, false)
	assert_true(player.can_double_jump(false, true))
	player.free()


func test_double_jump_not_used_on_ground_or_in_coyote_time() -> void:
	var player: Player = _make_player()
	player.update_timers(0.016, true, true)
	assert_false(player.can_double_jump(true, true), "on the ground a jump is a normal jump")
	player.update_timers(0.016, true, false)
	player.update_timers(player.coyote_time * 0.5, false, true)  # walked off, still in coyote time
	assert_true(player.can_jump())
	assert_false(player.can_double_jump(false, true), "coyote jump is a normal jump")
	player.free()


func test_double_jump_needs_a_fresh_press() -> void:
	var player: Player = _make_player()
	_airborne_after_coyote(player)
	player.update_timers(0.016, false, true)  # pressed: buffered
	player.update_timers(0.016, false, false)  # next frame, press only remembered in the buffer
	assert_false(player.can_double_jump(false, false), "a buffered press must not trigger an air jump")
	player.free()


func test_double_jump_reaches_configured_height() -> void:
	var player: Player = _make_player()
	var v: float = player.get_double_jump_velocity()
	assert_true(v < 0.0, "double jump goes up")
	var peak: float = (v * v) / (2.0 * player.get_jump_gravity())
	assert_almost_eq(peak, player.double_jump_height, 0.01)
	player.free()


# --- Dash ---

func test_dash_consumes_a_charge_and_is_refused_at_zero() -> void:
	var player: Player = _make_player()
	player.dash_charges = 1
	var events: Array[int] = []
	player.dashed.connect(func() -> void: events.append(-1))
	player.dash_charges_changed.connect(func(charges: int) -> void: events.append(charges))
	assert_true(player.try_dash(Vector2.RIGHT))
	assert_eq(player.dash_charges, 0)
	assert_true(player.is_dashing())
	assert_eq(events, [-1, 0] as Array[int])
	player.advance_dash(player.dash_time + 0.01)
	assert_false(player.is_dashing())
	assert_false(player.try_dash(Vector2.RIGHT), "no charges left")
	assert_eq(player.dash_charges, 0)
	player.free()


func test_dash_uses_held_or_facing_direction() -> void:
	var player: Player = _make_player()
	player.dash_charges = 2
	player.update_facing(-1.0)
	assert_true(player.try_dash(Vector2.ZERO))
	assert_almost_eq(player.get_dash_velocity().x, -player.dash_speed)
	assert_almost_eq(player.get_dash_velocity().y, 0.0)
	player.advance_dash(player.dash_time + 0.01)
	assert_almost_eq(player.velocity.x, -player.run_speed, 0.001, "keeps run speed after the dash")
	assert_true(player.try_dash(Vector2.RIGHT))
	assert_almost_eq(player.get_dash_velocity().x, player.dash_speed)
	assert_almost_eq(player.facing, 1.0)
	player.free()


func test_dash_aims_in_eight_directions() -> void:
	var diagonal: float = sqrt(0.5)
	assert_eq(PlayerScript.dash_direction_for(Vector2(0, -1), 1.0), Vector2.UP, "W = up")
	assert_eq(PlayerScript.dash_direction_for(Vector2(0, 1), 1.0), Vector2.DOWN, "S = down")
	assert_eq(PlayerScript.dash_direction_for(Vector2(-1, 0), 1.0), Vector2.LEFT, "A = left")
	var up_right: Vector2 = PlayerScript.dash_direction_for(Vector2(0.7071, -0.7071), -1.0)
	assert_almost_eq(up_right.x, diagonal, 0.001, "W+D = up-right")
	assert_almost_eq(up_right.y, -diagonal, 0.001, "W+D = up-right")
	var up_left: Vector2 = PlayerScript.dash_direction_for(Vector2(-0.7071, -0.7071), 1.0)
	assert_almost_eq(up_left.x, -diagonal, 0.001, "W+A = up-left")
	assert_almost_eq(up_left.y, -diagonal, 0.001, "W+A = up-left")
	assert_eq(PlayerScript.dash_direction_for(Vector2.ZERO, -1.0), Vector2.LEFT, "no aim = facing direction")
	assert_eq(PlayerScript.dash_direction_for(Vector2(0.95, -0.2), 1.0), Vector2.RIGHT, "small stick tilt ignored")


func test_diagonal_dash_covers_the_same_distance() -> void:
	var player: Player = _make_player()
	player.dash_charges = 1
	assert_true(player.try_dash(Vector2(1, -1)))
	assert_almost_eq(player.get_dash_velocity().length(), player.dash_speed, 0.01)
	assert_true(player.get_dash_velocity().y < 0.0, "goes up")
	player.free()


func test_upward_dash_keeps_some_rise_and_facing() -> void:
	var player: Player = _make_player()
	player.dash_charges = 1
	player.update_facing(-1.0)
	assert_true(player.try_dash(Vector2.UP))
	assert_almost_eq(player.get_dash_velocity().x, 0.0)
	assert_almost_eq(player.get_dash_velocity().y, -player.dash_speed)
	assert_almost_eq(player.facing, -1.0, 0.001, "dashing straight up doesn't turn the dog around")
	player.advance_dash(player.dash_time + 0.01)
	assert_almost_eq(player.velocity.y, -player.run_speed, 0.001, "still moving up a little after the dash")
	player.free()


func test_dash_does_not_recharge_on_landing() -> void:
	var player: Player = _make_player()
	player.dash_charges = 1
	player.try_dash(Vector2.RIGHT)
	player.advance_dash(player.dash_time + 0.01)
	player.update_timers(0.016, true, false)  # landed
	assert_eq(player.dash_charges, 0)
	player.free()


func test_refill_dash_restores_max_and_emits() -> void:
	var player: Player = _make_player()
	player.max_dash_charges = 2
	player.dash_charges = 0
	var got: Array[int] = []
	var refilled: Array[bool] = []
	player.dash_charges_changed.connect(func(charges: int) -> void: got.append(charges))
	player.dash_refilled.connect(func() -> void: refilled.append(true))
	player.refill_dash()
	assert_eq(player.dash_charges, 2)
	assert_eq(got, [2] as Array[int])
	assert_eq(refilled.size(), 1)
	player.free()


func test_dash_distance_matches_speed_and_time() -> void:
	var player: Player = _make_player()
	assert_almost_eq(player.get_dash_distance(), player.dash_speed * player.dash_time)
	# Simulate at 60 fps: distance covered while dashing is close to the configured distance.
	player.dash_charges = 1
	player.try_dash(Vector2.RIGHT)
	var travelled: float = 0.0
	var step: float = 1.0 / 60.0
	while player.is_dashing():
		travelled += player.get_dash_velocity().x * step
		player.advance_dash(step)
	assert_almost_eq(travelled, player.get_dash_distance(), player.dash_speed * step)
	player.free()


func test_animation_for_picks_dash() -> void:
	assert_eq(PlayerScript.animation_for(Vector2(320, 0), true, true), &"dash")
	assert_eq(PlayerScript.animation_for(Vector2(-320, 0), false, true), &"dash")
	assert_eq(PlayerScript.animation_for(Vector2(0, -200), false, false), &"jump")


func test_dash_animation_exists() -> void:
	var frames: SpriteFrames = load("res://player/dog_frames.tres")
	assert_true(frames.has_animation(&"dash"))
	assert_true(frames.has_animation(&"jump"))
