extends "res://tests/framework/test_case.gd"

const PlayerScript := preload("res://player/player.gd")
const PlatformScript := preload("res://levels/blocks/platform.gd")
const BackgroundScript := preload("res://levels/background/altitude_background.gd")


func test_player_animation_on_ground() -> void:
	assert_eq(PlayerScript.animation_for(Vector2.ZERO, true), &"idle")
	assert_eq(PlayerScript.animation_for(Vector2(120, 0), true), &"run")
	assert_eq(PlayerScript.animation_for(Vector2(-120, 0), true), &"run")


func test_player_animation_in_air() -> void:
	assert_eq(PlayerScript.animation_for(Vector2(0, -200), false), &"jump")
	assert_eq(PlayerScript.animation_for(Vector2(0, 150), false), &"fall")


func test_platform_tile_columns() -> void:
	assert_eq(PlatformScript.tile_column(0, 1), 3, "single tile")
	assert_eq(PlatformScript.tile_column(0, 4), 0, "left cap")
	assert_eq(PlatformScript.tile_column(1, 4), 1, "middle")
	assert_eq(PlatformScript.tile_column(2, 4), 1, "middle")
	assert_eq(PlatformScript.tile_column(3, 4), 2, "right cap")


func test_background_progress_is_clamped() -> void:
	assert_almost_eq(BackgroundScript.altitude_progress(-50.0, 1000.0), 0.0)
	assert_almost_eq(BackgroundScript.altitude_progress(500.0, 1000.0), 0.5)
	assert_almost_eq(BackgroundScript.altitude_progress(5000.0, 1000.0), 1.0)


func test_all_art_files_load() -> void:
	for path: String in [
		"res://assets/art/player/dog.png", "res://assets/art/rocket/rocket.png", "res://assets/art/rocket/flame.png",
		"res://assets/art/tiles/platforms.png", "res://assets/art/backgrounds/sky_gradient.png",
		"res://assets/art/props/moon.png", "res://player/dog_frames.tres",
	]:
		assert_true(load(path) != null, "could not load " + path)
