extends "res://tests/framework/test_case.gd"

const SoundScript := preload("res://autoload/sound.gd")


func test_known_names() -> void:
	assert_true(SoundScript.is_known(&"jump"))
	assert_true(SoundScript.is_known(&"rocket_engine"))
	assert_true(SoundScript.is_known(&"race"))
	assert_false(SoundScript.is_known(&"not_a_sound"))


func test_finds_dropped_in_files() -> void:
	assert_true(SoundScript.path_for("sfx", &"jump").ends_with("assets/audio/sfx/jump.wav"),
		"jump placeholder should be found, got '%s'" % SoundScript.path_for("sfx", &"jump"))
	assert_true(SoundScript.path_for("loops", &"rocket_engine") != "")


func test_missing_files_are_skipped() -> void:
	assert_eq(SoundScript.path_for("music", &"race"), "", "no music yet, so no path")
	assert_eq(SoundScript.path_for("sfx", &"not_a_sound"), "")


func test_names_are_unique_across_lists() -> void:
	for sound: StringName in SoundScript.SFX:
		assert_false(SoundScript.LOOPS.has(sound) or SoundScript.MUSIC.has(sound), "%s is in two lists" % sound)
