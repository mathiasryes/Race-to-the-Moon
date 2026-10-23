extends RefCounted
## Base class for tests. Test files live in tests/ as test_*.gd, extend this file,
## and define methods named test_*. See tests/framework/run_tests.gd.

var failures: PackedStringArray = []


func assert_true(condition: bool, message: String = "expected true") -> void:
	if not condition:
		failures.append(message)


func assert_false(condition: bool, message: String = "expected false") -> void:
	assert_true(not condition, message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		failures.append("expected %s, got %s. %s" % [expected, actual, message])


func assert_almost_eq(actual: float, expected: float, tolerance: float = 0.001, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		failures.append("expected %s (±%s), got %s. %s" % [expected, tolerance, actual, message])
