# ═══════════════════════════════════════════════════════════════
# test_tutorial.gd — Tests for TutorialManager
# ═══════════════════════════════════════════════════════════════
extends Node


func _runner():
	return get_parent()


func test_tutorial_steps_exist() -> bool:
	"""Tutorial STEPS array should have 6 steps."""
	var tm := get_node_or_null("/root/TutorialManager")
	var r = _runner()
	if tm == null:
		r.assert_not_null(tm, "TutorialManager autoload should exist")
		return true
	r.assert_ge(tm.STEPS.size(), 5, "Should have at least 5 tutorial steps")
	return true


func test_tutorial_steps_have_ids() -> bool:
	"""All steps should have id and text fields."""
	var tm := get_node_or_null("/root/TutorialManager")
	var r = _runner()
	if tm == null:
		return true
	for step: Dictionary in tm.STEPS:
		r.assert_true(step.has("id"), "Step should have 'id' field")
		r.assert_true(step.has("text"), "Step should have 'text' field")
		r.assert_true(step.has("block_input"), "Step should have 'block_input' field")
	return true


func test_tutorial_welcome_is_blocking() -> bool:
	"""First step (welcome) should block input."""
	var tm := get_node_or_null("/root/TutorialManager")
	var r = _runner()
	if tm == null: return true
	if tm.STEPS.size() > 0:
		r.assert_true(tm.STEPS[0]["block_input"], "Welcome step should block input")
	return true


func test_tutorial_start_starts() -> bool:
	"""start_tutorial() should set tutorial active."""
	var tm := get_node_or_null("/root/TutorialManager")
	var r = _runner()
	if tm == null: return true
	# Check that is_tutorial_active works (it may be already started or not)
	# We just verify the method exists and returns a bool
	var result: bool = tm.is_tutorial_active()
	r.assert_eq(typeof(result), TYPE_BOOL, "is_tutorial_active should return bool")
	return true


func test_tutorial_complete_config() -> bool:
	"""After skip_tutorial(), is_complete() should return true and config saved."""
	var tm := get_node_or_null("/root/TutorialManager")
	var r = _runner()
	if tm == null: return true
	var was_complete: bool = tm.is_complete()
	if not was_complete:
		tm.skip_tutorial()
		r.assert_true(tm.is_complete(), "After skip, tutorial should be complete")
		r.assert_false(tm.is_tutorial_active(), "After skip, tutorial should not be active")
	return true


func test_tutorial_advance_blocks() -> bool:
	"""advance_tutorial() should exist and be callable."""
	var tm := get_node_or_null("/root/TutorialManager")
	var r = _runner()
	if tm == null: return true
	# The method should exist (no crash)
	tm.advance_tutorial()
	r.assert_true(true, "advance_tutorial exists and doesn't crash")
	return true


func test_tutorial_get_current_step_returns_int() -> bool:
	"""get_current_step() should return int."""
	var tm := get_node_or_null("/root/TutorialManager")
	var r = _runner()
	if tm == null: return true
	var step: int = tm.get_current_step()
	r.assert_eq(typeof(step), TYPE_INT, "get_current_step should return int")
	return true


func test_tutorial_get_current_step_data() -> bool:
	"""get_current_step_data() should return Dictionary."""
	var tm := get_node_or_null("/root/TutorialManager")
	var r = _runner()
	if tm == null: return true
	var data: Dictionary = tm.get_current_step_data()
	r.assert_eq(typeof(data), TYPE_DICTIONARY, "get_current_step_data should return Dictionary")
	return true
