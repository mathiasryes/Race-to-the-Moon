extends SceneTree
## Saves screenshots of level_01 at several heights to builds/screenshots/ (git-ignored).
## Needs a real window, so don't pass --headless:
##   godot --path . -s res://tests/framework/capture_screenshots.gd

const HEIGHTS: Array[float] = [0.0, -192.0, -384.0]


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var level: Node = load("res://levels/level_01.tscn").instantiate()
	root.add_child(level)
	var player: Node2D = level.get_node("Player")
	var camera: Camera2D = player.get_node("Camera2D")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/screenshots"))
	for y: float in HEIGHTS:
		player.global_position = Vector2(40.0, y)
		camera.reset_smoothing()
		for i: int in 30:
			await process_frame
		var image: Image = root.get_texture().get_image()
		image.save_png("res://builds/screenshots/level_01_%d.png" % int(-y))
	quit()
