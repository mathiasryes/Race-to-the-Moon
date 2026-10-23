extends SceneTree
## Minimal headless test runner: runs every test_* method in res://tests/test_*.gd.
## Usage: godot --headless --path . -s res://tests/framework/run_tests.gd
## Exits with code 1 if any test fails, so CI can catch it.

const TESTS_DIR := "res://tests"


func _initialize() -> void:
	var total: int = 0
	var failed: int = 0

	for file: String in DirAccess.get_files_at(TESTS_DIR):
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		var script: GDScript = load(TESTS_DIR.path_join(file))
		if script == null:
			printerr("FAIL %s: could not load script" % file)
			failed += 1
			continue

		for method: Dictionary in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			total += 1
			var suite: RefCounted = script.new()
			suite.call(method_name)
			var failures: PackedStringArray = suite.get("failures")
			if failures.is_empty():
				print("PASS %s :: %s" % [file, method_name])
			else:
				failed += 1
				for failure: String in failures:
					printerr("FAIL %s :: %s - %s" % [file, method_name, failure])

	print("\n%d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 else 0)
