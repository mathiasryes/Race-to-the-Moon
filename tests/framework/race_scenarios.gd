extends SceneTree
## Plays level_01 headless with scripted "players" to check the race is winnable but not too easy.
## Usage: godot --headless --path . -s res://tests/framework/race_scenarios.gd
## Climbers hop up the generated route at a fixed average climb speed (a multiple of the rocket's
## cruise speed), so this tests the race pacing, not the jumping. Jump reach is covered by test_level_generator.gd.

const LEVEL := "res://levels/level_01.tscn"
const LEVEL_SEED := 12345
const MAX_SECONDS := 240.0

var _failed: int = 0


func _initialize() -> void:
	_run_all.call_deferred()


func _run_all() -> void:
	await _scenario("standing still loses", 0.0, RaceDirector.State.LOST)
	await _scenario("climbing at 1.5x rocket speed wins", 1.5, RaceDirector.State.WON)
	await _scenario("climbing at 0.6x rocket speed loses", 0.6, RaceDirector.State.LOST)
	print("\n%d race scenarios failed" % _failed)
	quit(1 if _failed > 0 else 0)


func _scenario(title: String, speed_factor: float, expected: RaceDirector.State) -> void:
	var level: Node = load(LEVEL).instantiate()
	var generator: LevelGenerator = level.get_node("LevelGenerator")
	generator.level_seed = LEVEL_SEED
	root.add_child(level)
	var player: Node2D = level.get_node("Player")
	var director: RaceDirector = level.get_node("RaceDirector")
	var route: Array[Vector2] = generator.main_path
	var climb_speed: float = speed_factor * director.cruise_speed

	var time: float = 0.0
	var next_step: int = 0
	var step: float = 1.0 / Engine.physics_ticks_per_second
	while not paused and time < MAX_SECONDS:
		await physics_frame
		time += step
		while next_step < route.size() and -route[next_step].y <= climb_speed * time:
			player.global_position = route[next_step] + Vector2(0, -1)
			next_step += 1

	var ok: bool = director.state == expected
	if not ok:
		_failed += 1
	print("%s %s: ended %s after %.1fs at height %.0f of %.0f" % [
		"PASS" if ok else "FAIL", title, RaceDirector.State.keys()[director.state], time,
		-player.global_position.y, generator.level_height])
	paused = false
	level.queue_free()
	await process_frame
