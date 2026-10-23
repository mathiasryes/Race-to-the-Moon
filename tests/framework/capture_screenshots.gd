extends SceneTree
## Saves screenshots of level_01 to builds/screenshots/ (git-ignored): the level at several heights,
## then a race where the player stands still (liftoff, warning, lost screen).
## Needs a real window, so don't pass --headless:
##   godot --path . -s res://tests/framework/capture_screenshots.gd

const LEVEL := "res://levels/level_01.tscn"
const LEVEL_SEED := 7
## Poses the player on the generated route at these fractions of the climb.
const CLIMB_FRACTIONS: Array[float] = [0.0, 0.2, 0.45, 0.7, 1.0]
## Seconds into an idle race at which to take a shot.
const RACE_SHOTS: Array[float] = [1.0, 4.0, 9.5]


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/screenshots"))
	# Keep Godot from importing the screenshots as game assets.
	FileAccess.open("res://builds/.gdignore", FileAccess.WRITE)

	var level: Node = load(LEVEL).instantiate()
	var generator: LevelGenerator = level.get_node("LevelGenerator")
	generator.level_seed = LEVEL_SEED
	# No race while posing: otherwise touching the goal ends the race and pauses the game.
	level.get_node("RaceDirector").free()
	level.get_node("RaceHud").free()
	root.add_child(level)
	var player: Node2D = level.get_node("Player")
	var camera: Camera2D = player.get_node("Camera2D")
	var route: Array[Vector2] = generator.main_path
	for fraction: float in CLIMB_FRACTIONS:
		var spot: Vector2 = Vector2.ZERO
		if fraction > 0.0:
			spot = route[mini(roundi(fraction * (route.size() - 1)), route.size() - 1)]
		player.global_position = spot + Vector2(0, -1)
		camera.reset_smoothing()
		for i: int in 30:
			await process_frame
		_save("climb_%d" % roundi(fraction * 100))
	level.free()

	level = load(LEVEL).instantiate()
	(level.get_node("LevelGenerator") as LevelGenerator).level_seed = LEVEL_SEED
	root.add_child(level)
	var time: float = 0.0
	for shot: float in RACE_SHOTS:
		while time < shot:
			await physics_frame
			time += 1.0 / Engine.physics_ticks_per_second
		await process_frame
		_save("race_%.1fs" % shot)
	while not paused:
		await physics_frame
	for i: int in 3:
		await process_frame
	_save("race_end")
	quit()


func _save(name: String) -> void:
	root.get_texture().get_image().save_png("res://builds/screenshots/%s.png" % name)
