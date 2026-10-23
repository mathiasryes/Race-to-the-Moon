extends "res://tests/framework/test_case.gd"

const RaceSoundsScript := preload("res://audio/race_sounds.gd")
const PlayerScript := preload("res://player/player.gd")
const SoundScript := preload("res://autoload/sound.gd")

const HEAVY := 160.0


func test_each_surface_has_its_landing_sound() -> void:
	assert_eq(RaceSoundsScript.landing_sound(Platform.Zone.GRASS, 40.0, HEAVY), &"land_grass")
	assert_eq(RaceSoundsScript.landing_sound(Platform.Zone.LAUNCHPAD, 40.0, HEAVY), &"land_metal")
	assert_eq(RaceSoundsScript.landing_sound(Platform.Zone.GIRDER, 40.0, HEAVY), &"land_metal")
	assert_eq(RaceSoundsScript.landing_sound(Platform.Zone.SOLAR, 40.0, HEAVY), &"land_metal")
	assert_eq(RaceSoundsScript.landing_sound(Platform.Zone.CLOUD, 40.0, HEAVY), &"land_cloud")
	assert_eq(RaceSoundsScript.landing_sound(Platform.Zone.ASTEROID, 40.0, HEAVY), &"land_rock")
	assert_eq(RaceSoundsScript.landing_sound(Platform.Zone.MOON, 40.0, HEAVY), &"land_rock")


func test_unknown_surface_falls_back_to_grass() -> void:
	assert_eq(RaceSoundsScript.landing_sound(-1, 40.0, HEAVY), &"land_grass")


func test_long_falls_land_heavy_on_any_surface() -> void:
	assert_eq(RaceSoundsScript.landing_sound(Platform.Zone.CLOUD, 300.0, HEAVY), &"land_heavy")
	assert_eq(RaceSoundsScript.landing_sound(Platform.Zone.GRASS, HEAVY + 1.0, HEAVY), &"land_heavy")
	assert_eq(RaceSoundsScript.landing_sound(Platform.Zone.GRASS, HEAVY, HEAVY), &"land_grass", "exactly the limit is normal")


func test_a_full_double_jump_is_not_a_heavy_landing() -> void:
	var player: Player = PlayerScript.new()
	assert_true(player.jump_height + player.double_jump_height < HEAVY,
		"jumping and double jumping back down to the same platform shouldn't sound heavy")
	player.free()


func test_fall_height_is_measured_from_the_top_of_the_jump() -> void:
	assert_almost_eq(PlayerScript.fall_height(-200.0, -40.0), 160.0)
	assert_almost_eq(PlayerScript.fall_height(-40.0, -100.0), 0.0, 0.001, "landing higher than the top is not a fall")


func test_every_landing_sound_is_a_known_name_with_a_file() -> void:
	for sound: StringName in [&"land_grass", &"land_metal", &"land_cloud", &"land_rock", &"land_heavy", &"woof"]:
		assert_true(SoundScript.SFX.has(sound), "%s missing from Sound.SFX" % sound)
		assert_true(SoundScript.path_for("sfx", sound) != "", "%s has no audio file" % sound)
