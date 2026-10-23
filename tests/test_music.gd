extends "res://tests/framework/test_case.gd"

const RaceSoundsScript := preload("res://audio/race_sounds.gd")
const SoundScript := preload("res://autoload/sound.gd")

const SPACE := 0.6
const MARGIN := 0.03


func test_lower_music_below_the_atmosphere() -> void:
	assert_eq(RaceSoundsScript.music_for(0.0, &"", SPACE, MARGIN), &"below_atmosphere")
	assert_eq(RaceSoundsScript.music_for(0.59, &"below_atmosphere", SPACE, MARGIN), &"below_atmosphere")


func test_space_music_from_the_switch_point() -> void:
	assert_eq(RaceSoundsScript.music_for(0.6, &"below_atmosphere", SPACE, MARGIN), &"above_atmosphere")
	assert_eq(RaceSoundsScript.music_for(1.0, &"above_atmosphere", SPACE, MARGIN), &"above_atmosphere")


func test_no_flip_flopping_around_the_boundary() -> void:
	assert_eq(RaceSoundsScript.music_for(0.58, &"above_atmosphere", SPACE, MARGIN), &"above_atmosphere",
		"just below the boundary after reaching space: keep the space music")
	assert_eq(RaceSoundsScript.music_for(0.56, &"above_atmosphere", SPACE, MARGIN), &"below_atmosphere",
		"clearly back down: switch back")


func test_both_tracks_are_known_and_have_files() -> void:
	for track: StringName in [&"below_atmosphere", &"above_atmosphere"]:
		assert_true(SoundScript.MUSIC.has(track), "%s missing from Sound.MUSIC" % track)
		assert_true(SoundScript.path_for("music", track).ends_with(".mp3"), "%s should be the delivered mp3" % track)
