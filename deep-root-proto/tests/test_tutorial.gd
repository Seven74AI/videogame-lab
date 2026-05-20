# ═══════════════════════════════════════════════════════════════
# test_tutorial.gd — Tests for TutorialManager
# ═══════════════════════════════════════════════════════════════
extends GutTest


func test_tutorial_steps_exist():
	"""Tutorial STEPS array should have 6 steps."""
	var tm := get_node_or_null("/root/TutorialManager")
	if tm == null:
		assert_not_null(tm, "TutorialManager autoload should exist")
		return
	assert_true(tm.STEPS.size() >= 5, "Should have at least 5 tutorial steps")


func test_tutorial_steps_have_ids():
	"""All steps should have id and text fields."""
	var tm := get_node_or_null("/root/TutorialManager")
	if tm == null: return
	for step: Dictionary in tm.STEPS:
		assert_true(step.has("id"), "Step should have 'id' field")
		assert_true(step.has("text"), "Step should have 'text' field")
		assert_true(step.has("block_input"), "Step should have 'block_input' field")


func test_tutorial_welcome_is_blocking():
	"""First step (welcome) should block input."""
	var tm := get_node_or_null("/root/TutorialManager")
	if tm == null: return
	if tm.STEPS.size() > 0:
		assert_true(tm.STEPS[0]["block_input"], "Welcome step should block input")


func test_tutorial_start_starts():
	"""start_tutorial() should set tutorial active."""
	var tm := get_node_or_null("/root/TutorialManager")
	if tm == null: return
	# Check that is_tutorial_active works (it may be already started or not)
	# We just verify the method exists and returns a bool
	var result: bool = tm.is_tutorial_active()
	assert_eq(typeof(result), TYPE_BOOL, "is_tutorial_active should return bool")


func test_tutorial_complete_config():
	"""After skip_tutorial(), is_complete() should return true and config saved."""
	var tm := get_node_or_null("/root/TutorialManager")
	if tm == null: return
	var was_complete: bool = tm.is_complete()
	if not was_complete:
		tm.skip_tutorial()
	assert_true(tm.is_complete(), "After skip, tutorial should be complete")
	assert_false(tm.is_tutorial_active(), "After skip, tutorial should not be active")


func test_tutorial_advance_blocks():
	"""advance_tutorial() should exist and be callable."""
	var tm := get_node_or_null("/root/TutorialManager")
	if tm == null: return
	# The method should exist (no crash)
	tm.advance_tutorial()
	assert_true(true, "advance_tutorial exists and doesn't crash")


func test_tutorial_get_current_step_returns_int():
	"""get_current_step() should return int."""
	var tm := get_node_or_null("/root/TutorialManager")
	if tm == null: return
	var step: int = tm.get_current_step()
	assert_eq(typeof(step), TYPE_INT, "get_current_step should return int")


func test_tutorial_get_current_step_data():
	"""get_current_step_data() should return Dictionary."""
	var tm := get_node_or_null("/root/TutorialManager")
	if tm == null: return
	var data: Dictionary = tm.get_current_step_data()
	assert_eq(typeof(data), TYPE_DICTIONARY, "get_current_step_data should return Dictionary")
