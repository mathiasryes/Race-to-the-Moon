extends "res://tests/framework/test_case.gd"

const Director := preload("res://levels/race/race_director.gd")


func test_rocket_stays_on_pad_before_liftoff() -> void:
	assert_almost_eq(Director.rocket_height_at(0.0, 55.0, 3.0), 0.0)
	assert_almost_eq(Director.rocket_height_at(-1.0, 55.0, 3.0), 0.0)


func test_rocket_speeds_up_then_cruises() -> void:
	# Halfway through accelerating it has covered a quarter of the acceleration distance.
	var accel_distance: float = 0.5 * 55.0 * 3.0
	assert_almost_eq(Director.rocket_height_at(1.5, 55.0, 3.0), accel_distance * 0.25)
	assert_almost_eq(Director.rocket_height_at(3.0, 55.0, 3.0), accel_distance)
	# After that, exactly cruise speed.
	var after: float = Director.rocket_height_at(5.0, 55.0, 3.0) - Director.rocket_height_at(4.0, 55.0, 3.0)
	assert_almost_eq(after, 55.0)


func test_rocket_height_without_acceleration() -> void:
	assert_almost_eq(Director.rocket_height_at(2.0, 50.0, 0.0), 100.0)


func test_escape_only_when_nozzle_above_screen() -> void:
	assert_false(Director.rocket_has_escaped(-300.0, -345.0), "nozzle still on screen")
	assert_false(Director.rocket_has_escaped(-345.0, -345.0), "nozzle exactly at the top edge")
	assert_true(Director.rocket_has_escaped(-346.0, -345.0), "nozzle above the top edge")


func test_danger_grows_near_the_top() -> void:
	assert_almost_eq(Director.danger_amount(-100.0, -345.0, 100.0), 0.0, 0.001, "far below the top")
	assert_almost_eq(Director.danger_amount(-295.0, -345.0, 100.0), 0.5, 0.001, "halfway into the zone")
	assert_almost_eq(Director.danger_amount(-345.0, -345.0, 100.0), 1.0, 0.001, "at the edge")
	assert_almost_eq(Director.danger_amount(-400.0, -345.0, 100.0), 1.0, 0.001, "clamped")
