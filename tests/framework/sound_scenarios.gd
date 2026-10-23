extends SceneTree
## Plays level_01 headless and checks the right sounds are triggered at the right moments.
## Usage: godot --headless --path . -s res://tests/framework/sound_scenarios.gd
## Uses Sound.history, so it works whether or not the audio files exist (headless has no audio output).

const LEVEL := "res://levels/level_01.tscn"
const LEVEL_SEED := 12345

var _failed: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var sound: Node = root.get_node("Sound")
	var level: Node = load(LEVEL).instantiate()
	(level.get_node("LevelGenerator") as LevelGenerator).level_seed = LEVEL_SEED  # same level every run
	root.add_child(level)
	var player: Player = level.get_node("Player")

	await _wait(0.5)
	_check(sound, "countdown starts with a beep", &"countdown_beep")
	_check_now(sound.call("current_music") == &"below_atmosphere", "the lower-atmosphere music plays at the start")

	Input.action_press("jump")
	await _wait(0.1)
	Input.action_release("jump")
	_check(sound, "jumping plays the jump sound", &"jump")
	await _wait(0.15)
	Input.action_press("jump")  # second press in the air
	await _wait(0.05)
	Input.action_release("jump")
	_check(sound, "jumping again in the air plays the double jump sound", &"double_jump")
	Input.action_press("dash")
	await _wait(0.05)
	Input.action_release("dash")
	_check(sound, "dashing plays the dash sound", &"dash")
	player.refill_dash()
	_check(sound, "a refill (treat) plays the treat sound", &"treat")
	await _wait(1.5)
	# Where the dog lands after the jump + double jump + dash depends on the level, so accept any landing
	# sound here; which surface gives which sound is covered by tests/test_landing_sounds.gd.
	var landing_sounds: Array = (sound.get("history") as Array).filter(
		func(name: StringName) -> bool: return String(name).begins_with("land_"))
	_check_now(not landing_sounds.is_empty(), "landing plays a landing sound (%s)" % ", ".join(landing_sounds))
	_check_now(player.is_on_floor(), "player has landed")

	await _wait(3.0)
	_check(sound, "liftoff plays the liftoff sound", &"liftoff")
	_check(sound, "the dog barks at the departing rocket", &"woof")
	_check_now(sound.call("is_looping", &"rocket_engine"), "rocket engine loop runs after liftoff")

	while not paused:
		await physics_frame
	_check(sound, "the warning sounds before losing", &"warning")
	_check(sound, "losing plays the lose jingle", &"lose")
	_check_now(not sound.call("is_looping", &"rocket_engine"), "engine loop stops when the race ends")
	_check_now(not sound.call("is_looping", &"warning_alarm"), "alarm loop stops when the race ends")
	_check_now(sound.call("current_music") == &"", "music stops when the race ends")

	# Music follows the height: a fresh level, with the dog teleported up and down the route.
	paused = false
	level.free()
	level = load(LEVEL).instantiate()
	var generator: LevelGenerator = level.get_node("LevelGenerator")
	generator.level_seed = LEVEL_SEED
	root.add_child(level)
	player = level.get_node("Player")
	var route: Array[Vector2] = generator.main_path
	await _wait(0.1)
	player.global_position = _route_point(route, generator.level_height, 0.75)
	await _wait(0.2)
	_check_now(sound.call("current_music") == &"above_atmosphere", "reaching space switches to the space music")
	player.global_position = _route_point(route, generator.level_height, 0.59)
	await _wait(0.2)
	_check_now(sound.call("current_music") == &"above_atmosphere", "dropping just below the boundary keeps the space music")
	player.global_position = _route_point(route, generator.level_height, 0.3)
	await _wait(0.2)
	_check_now(sound.call("current_music") == &"below_atmosphere", "falling well back down returns to the lower music")

	print("\n%d sound checks failed" % _failed)
	paused = false
	level.free()
	sound.call("release_all")
	for i: int in 3:
		await process_frame
	quit(1 if _failed > 0 else 0)


## A spot on the route platform closest to `fraction` of the climb (feet just above its surface).
func _route_point(route: Array[Vector2], height: float, fraction: float) -> Vector2:
	var best: Vector2 = route[0]
	for point: Vector2 in route:
		if absf(-point.y / height - fraction) < absf(-best.y / height - fraction):
			best = point
	return best + Vector2(0, -1)


func _wait(seconds: float) -> void:
	var time: float = 0.0
	while time < seconds and not paused:
		await physics_frame
		time += 1.0 / Engine.physics_ticks_per_second


func _check(sound: Node, title: String, expected: StringName) -> void:
	_check_now((sound.get("history") as Array).has(expected), title)


func _check_now(ok: bool, title: String) -> void:
	if not ok:
		_failed += 1
	print("%s %s" % ["PASS" if ok else "FAIL", title])
