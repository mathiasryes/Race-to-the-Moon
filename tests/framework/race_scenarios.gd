extends SceneTree
## Plays level_01 headless with scripted "players" to check the race is winnable but not too easy.
## Usage: godot --headless --path . -s res://tests/framework/race_scenarios.gd
## The climbers jump straight onto each platform after a fixed delay, so this tests the race pacing, not the jumping.

const LEVEL := "res://levels/level_01.tscn"
const MAX_SECONDS := 60.0

var _failed: int = 0


func _initialize() -> void:
	_run_all.call_deferred()


func _run_all() -> void:
	await _scenario("standing still loses", -1.0, RaceDirector.State.LOST)
	await _scenario("climbing 1 platform/second wins", 1.0, RaceDirector.State.WON)
	await _scenario("climbing 1 platform per 2.5 seconds loses", 2.5, RaceDirector.State.LOST)
	print("\n%d race scenarios failed" % _failed)
	quit(1 if _failed > 0 else 0)


## seconds_per_platform < 0 means the player never moves.
func _scenario(title: String, seconds_per_platform: float, expected: RaceDirector.State) -> void:
	var level: Node = load(LEVEL).instantiate()
	root.add_child(level)
	var player: Node2D = level.get_node("Player")
	var director: RaceDirector = level.get_node("RaceDirector")
	var platforms: Array[Node] = level.get_node("Platforms").get_children()
	platforms.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.position.y > b.position.y)

	var time: float = 0.0
	var next_platform: int = 0
	var step: float = 1.0 / Engine.physics_ticks_per_second
	while not paused and time < MAX_SECONDS:
		await physics_frame
		time += step
		if seconds_per_platform > 0.0 and next_platform < platforms.size() \
				and time >= (next_platform + 1) * seconds_per_platform:
			player.global_position = (platforms[next_platform] as Node2D).global_position + Vector2(0, -1)
			next_platform += 1

	var ok: bool = director.state == expected
	if not ok:
		_failed += 1
	print("%s %s: ended %s after %.1fs (reached platform %d/%d)" % [
		"PASS" if ok else "FAIL", title, RaceDirector.State.keys()[director.state], time,
		next_platform, platforms.size()])
	paused = false
	level.queue_free()
	await process_frame
