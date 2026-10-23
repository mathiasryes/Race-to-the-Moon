extends "res://tests/framework/test_case.gd"

const SoundScript := preload("res://autoload/sound.gd")


func test_known_names() -> void:
	assert_true(SoundScript.is_known(&"jump"))
	assert_true(SoundScript.is_known(&"rocket_engine"))
	assert_true(SoundScript.is_known(&"below_atmosphere"))
	assert_false(SoundScript.is_known(&"not_a_sound"))


func test_finds_dropped_in_files() -> void:
	assert_true(SoundScript.path_for("sfx", &"jump").ends_with("assets/audio/sfx/jump.wav"),
		"jump placeholder should be found, got '%s'" % SoundScript.path_for("sfx", &"jump"))
	assert_true(SoundScript.path_for("loops", &"rocket_engine") != "")


func test_missing_files_are_skipped() -> void:
	assert_eq(SoundScript.path_for("music", &"not_a_track"), "", "unknown track, so no path")
	assert_eq(SoundScript.path_for("sfx", &"not_a_sound"), "")


func test_names_are_unique_across_lists() -> void:
	for sound: StringName in SoundScript.SFX:
		assert_false(SoundScript.LOOPS.has(sound) or SoundScript.MUSIC.has(sound), "%s is in two lists" % sound)


func test_dash_and_treat_sounds_are_known() -> void:
	for sound: StringName in [&"dash", &"double_jump", &"treat"]:
		assert_true(SoundScript.SFX.has(sound), "%s should be a one-shot effect" % sound)


func test_dash_and_treat_placeholders_exist() -> void:
	for sound: StringName in [&"dash", &"double_jump", &"treat"]:
		assert_true(SoundScript.path_for("sfx", sound).ends_with("assets/audio/sfx/%s.wav" % sound),
			"%s placeholder should be found, got '%s'" % [sound, SoundScript.path_for("sfx", sound)])