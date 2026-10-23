extends "res://tests/framework/test_case.gd"

const SoundScript := preload("res://autoload/sound.gd")


func test_rocket_is_quieter_than_other_sounds() -> void:
	assert_true(SoundScript.volume_for(&"rocket_engine") < 0.0, "engine loop turned down")
	assert_true(SoundScript.volume_for(&"liftoff") < 0.0, "liftoff turned down")
	assert_almost_eq(SoundScript.volume_for(&"jump"), 0.0, 0.001, "other sounds play as recorded")


func test_volume_table_only_uses_known_names() -> void:
	for sound: StringName in SoundScript.VOLUME_DB:
		assert_true(SoundScript.is_known(sound), "%s in VOLUME_DB isn't a known sound" % sound)


func test_music_bus_is_not_turned_down() -> void:
	var layout: AudioBusLayout = load("res://default_bus_layout.tres")
	assert_true(layout != null, "bus layout loads")
	var bus: int = AudioServer.get_bus_index(&"Music")
	assert_true(bus >= 0, "Music bus exists")
	assert_true(AudioServer.get_bus_volume_db(bus) >= 0.0, "music plays at full volume")


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