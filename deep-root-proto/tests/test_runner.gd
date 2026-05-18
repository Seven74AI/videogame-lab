# ═══════════════════════════════════════════════════════════════
# test_runner.gd — Headless test runner for Godot
# Usage: godot4 --headless --path . res://tests/test.tscn
# Exit 0 = all pass, Exit 1 = failures
# ═══════════════════════════════════════════════════════════════
extends Node

var _passed: int = 0
var _failed: int = 0
var _errors: PackedStringArray = []
var _test_files: PackedStringArray = [
	"res://tests/test_grid.gd",
	"res://tests/test_rivals.gd",
	"res://tests/test_zones.gd",
	"res://tests/test_trees.gd",
	"res://tests/test_save.gd",
	"res://tests/test_input.gd",
]


func _ready() -> void:
	print("════════════════════════════════════════════════════════════")
	print("  DEEP ROOT proto v3 — Test Suite")
	print("════════════════════════════════════════════════════════════")
	print("")

	for file_path in _test_files:
		if not ResourceLoader.exists(file_path):
			print("SKIP: %s (file not found)" % file_path)
			continue
		var scr: Script = load(file_path)
		var test_node: Node = Node.new()
		test_node.set_script(scr)
		test_node.name = scr.resource_path.get_file().get_basename()
		add_child(test_node)
		_run_tests_on(test_node)

	print("")
	print("════════════════════════════════════════════════════════════")
	if _failed > 0:
		print("  FAILED: %d/%d" % [_failed, _passed + _failed])
		for err in _errors:
			printerr("  ", err)
		print("════════════════════════════════════════════════════════════")
		get_tree().quit(1)
	else:
		print("  ALL %d TESTS PASSED" % _passed)
		print("════════════════════════════════════════════════════════════")
		get_tree().quit(0)


func _run_tests_on(node: Node) -> void:
	var methods: Array[Dictionary] = node.get_script().get_script_method_list()
	for method_dict in methods:
		var name: String = method_dict["name"]
		if name.begins_with("test_"):
			print("  RUN: %s::%s" % [node.name, name])
			var result = node.call(name)
			# Tests use assert_* methods on this runner
			# If test returns false explicitly, count as fail
			if typeof(result) == TYPE_BOOL and result == false:
				if not _errors.has("  FAIL: %s::%s" % [node.name, name]):
					_failed += 1
					_errors.append("  FAIL: %s::%s" % [node.name, name])


# ── Public assertion API (called by test scripts) ─────────

func assert_eq(actual, expected, msg: String = "") -> bool:
	if actual == expected:
		_passed += 1
		return true
	_failed += 1
	var err: String = "  expected=%s got=%s" % [str(expected), str(actual)]
	if msg != "":
		err += " | " + msg
	_errors.append(err)
	printerr("  FAIL: ", err)
	return false


func assert_ne(actual, unexpected, msg: String = "") -> bool:
	if actual != unexpected:
		_passed += 1
		return true
	_failed += 1
	var err: String = "  expected != %s" % str(unexpected)
	if msg != "":
		err += " | " + msg
	_errors.append(err)
	printerr("  FAIL: ", err)
	return false


func assert_true(condition: bool, msg: String = "") -> bool:
	return assert_eq(condition, true, msg)


func assert_false(condition: bool, msg: String = "") -> bool:
	return assert_eq(condition, false, msg)


func assert_gt(actual, minimum, msg: String = "") -> bool:
	if actual > minimum:
		_passed += 1
		return true
	_failed += 1
	var err: String = "  expected > %s, got %s" % [str(minimum), str(actual)]
	if msg != "":
		err += " | " + msg
	_errors.append(err)
	printerr("  FAIL: ", err)
	return false


func assert_ge(actual, minimum, msg: String = "") -> bool:
	if actual >= minimum:
		_passed += 1
		return true
	_failed += 1
	var err: String = "  expected >= %s, got %s" % [str(minimum), str(actual)]
	if msg != "":
		err += " | " + msg
	_errors.append(err)
	printerr("  FAIL: ", err)
	return false


func assert_le(actual, maximum, msg: String = "") -> bool:
	if actual <= maximum:
		_passed += 1
		return true
	_failed += 1
	var err: String = "  expected <= %s, got %s" % [str(maximum), str(actual)]
	if msg != "":
		err += " | " + msg
	_errors.append(err)
	printerr("  FAIL: ", err)
	return false


func assert_not_null(obj, msg: String = "") -> bool:
	if obj != null:
		_passed += 1
		return true
	_failed += 1
	var err: String = "  expected not null"
	if msg != "":
		err += " | " + msg
	_errors.append(err)
	printerr("  FAIL: ", err)
	return false


func assert_null(obj, msg: String = "") -> bool:
	if obj == null:
		_passed += 1
		return true
	_failed += 1
	var err: String = "  expected null, got %s" % str(obj)
	if msg != "":
		err += " | " + msg
	_errors.append(err)
	printerr("  FAIL: ", err)
	return false
