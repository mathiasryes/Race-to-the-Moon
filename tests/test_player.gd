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
