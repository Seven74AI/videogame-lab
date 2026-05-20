# ═══════════════════════════════════════════════════════════════
# test_end_screen.gd — Tests for end screen, game over, history
# Uses the real GameManager autoload singleton.
# ═══════════════════════════════════════════════════════════════
extends GutTest

const GRID_W: int = 60
const GRID_H: int = 40

enum CellType {
	EMPTY, WATER, MINERAL, SUGAR, TREE,
	MYCELIUM, RIVAL_RED, RIVAL_ORANGE, RIVAL_VIOLET
}

func _setup_controlled_grid(gm) -> void:
	"""Reset GM to a clean empty grid for controlled testing."""
	# Reset all state
	gm.player_cells.clear()
	gm.player_gp = 10.0
	gm.player_gp_rate = gm.BASE_GP_RATE
	gm.player_sugars = 0
	gm.player_water = 0
	gm.player_minerals = 0
	gm.player_absorbed = 0
	gm.player_growth_progress = 0.0
	gm.trees.clear()
	gm.anim_pulses.clear()
	gm.selected_tree_idx = -1
	gm.growth_candidates.clear()
	gm.game_over = false
	gm.game_over_reason = ""
	gm.history.clear()
	gm.history_timer = 0.0

	gm.grid.clear()
	gm.grid_resources.clear()
	for y: int in range(gm.GRID_H):
		var row: Array[int] = []
		var res_row: Array[float] = []
		for x: int in range(gm.GRID_W):
			row.append(CellType.EMPTY)
			res_row.append(0.0)
		gm.grid.append(row)
		gm.grid_resources.append(res_row)

func test_is_grid_full_empty_grid() -> bool:
	"""Grid with EMPTY cells should NOT be full"""
	var gm = get_node_or_null("/root/GameManager")
	if gm == null: return false
	_setup_controlled_grid(gm)
	gm.grid[10][10] = CellType.MYCELIUM
	gm.grid[20][20] = CellType.WATER

	assert_false(gm.is_grid_full(), "Grid with empty cells = not full")
	return true

func test_is_grid_full_completely_filled() -> bool:
	"""Fully filled grid should be detected as full"""
	var gm = get_node_or_null("/root/GameManager")
	if gm == null: return false
	_setup_controlled_grid(gm)
	for y: int in range(gm.GRID_H):
		for x: int in range(gm.GRID_W):
			gm.grid[y][x] = CellType.MYCELIUM

	assert_true(gm.is_grid_full(), "Completely filled grid = full")
	return true

func test_is_player_dead_with_cells_and_space() -> bool:
	"""Player with cells and growth space is NOT dead"""
	var gm = get_node_or_null("/root/GameManager")
	if gm == null: return false
	_setup_controlled_grid(gm)
	gm.player_cells.append(Vector2i(30, 20))
	gm.grid[20][30] = CellType.MYCELIUM

	assert_false(gm.is_player_dead(), "Player with growth space = alive")
	return true

func test_is_player_dead_no_cells() -> bool:
	"""Player with no cells IS dead"""
	var gm = get_node_or_null("/root/GameManager")
	if gm == null: return false
	_setup_controlled_grid(gm)
	# player_cells already empty from _setup_controlled_grid

	assert_true(gm.is_player_dead(), "No player cells = dead")
	return true

func test_is_player_dead_surrounded() -> bool:
	"""Player surrounded with no growth space IS dead"""
	var gm = get_node_or_null("/root/GameManager")
	if gm == null: return false
	_setup_controlled_grid(gm)
	var px: int = 5
	var py: int = 5
	gm.player_cells.append(Vector2i(px, py))
	gm.grid[py][px] = CellType.MYCELIUM
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if dx == 0 and dy == 0: continue
			var nx: int = px + dx
			var ny: int = py + dy
			if nx >= 0 and nx < gm.GRID_W and ny >= 0 and ny < gm.GRID_H:
				gm.grid[ny][nx] = CellType.WATER

	assert_true(gm.is_player_dead(), "Surrounded player = dead")
	return true

func test_end_game_sets_state() -> bool:
	"""end_game() should set game_over, reason, and record history"""
	var gm = get_node_or_null("/root/GameManager")
	if gm == null: return false
	_setup_controlled_grid(gm)
	gm.player_cells.append(Vector2i(30, 20))
	gm.grid[20][30] = CellType.MYCELIUM

	gm.end_game("test_reason")

	assert_true(gm.game_over, "game_over=true after end_game")
	assert_eq(gm.game_over_reason, "test_reason", "reason set correctly")
	assert_gt(gm.history.size(), 0, "History has at least final snapshot")
	return true

func test_end_game_idempotent() -> bool:
	"""Calling end_game twice should not double-record"""
	var gm = get_node_or_null("/root/GameManager")
	if gm == null: return false
	_setup_controlled_grid(gm)
	gm.player_cells.append(Vector2i(30, 20))
	gm.grid[20][30] = CellType.MYCELIUM

	gm.end_game("first")
	var hist_size: int = gm.history.size()
	gm.end_game("second")

	assert_eq(gm.history.size(), hist_size, "Second end_game does not add history")
	assert_eq(gm.game_over_reason, "first", "Reason stays as first")
	return true

func test_check_game_over_grid_full() -> bool:
	"""check_game_over() should detect full grid"""
	var gm = get_node_or_null("/root/GameManager")
	if gm == null: return false
	_setup_controlled_grid(gm)
	gm.player_cells.append(Vector2i(30, 20))
	gm.grid[20][30] = CellType.MYCELIUM
	for y: int in range(gm.GRID_H):
		for x: int in range(gm.GRID_W):
			gm.grid[y][x] = CellType.WATER
	gm.grid[20][30] = CellType.MYCELIUM

	gm.check_game_over()

	assert_true(gm.game_over, "check_game_over detects full grid")
	assert_eq(gm.game_over_reason, "grid_full", "reason=grid_full")
	return true

func test_check_game_over_player_died() -> bool:
	"""check_game_over() should detect dead player"""
	var gm = get_node_or_null("/root/GameManager")
	if gm == null: return false
	_setup_controlled_grid(gm)
	# player_cells empty = dead

	gm.check_game_over()

	assert_true(gm.game_over, "check_game_over detects dead player")
	assert_eq(gm.game_over_reason, "player_died", "reason=player_died")
	return true

func test_history_records_snapshots() -> bool:
	"""History should record snapshots with proper fields"""
	var gm = get_node_or_null("/root/GameManager")
	if gm == null: return false
	_setup_controlled_grid(gm)
	gm.player_cells.append(Vector2i(30, 20))
	gm.grid[20][30] = CellType.MYCELIUM

	gm.history.clear()
	gm._record_history_snapshot()

	assert_eq(gm.history.size(), 1, "One snapshot recorded")
	var snap: Dictionary = gm.history[0]
	assert_eq(snap["player_cells"], gm.player_cells.size(), "player_cells in snapshot")
	assert_true(snap.has("player_gp"), "player_gp in snapshot")
	assert_true(snap.has("player_absorbed"), "player_absorbed in snapshot")
	assert_true(snap.has("player_sugars"), "player_sugars in snapshot")
	assert_eq(snap["rival_cells"].size(), 3, "3 rival counts in snapshot")
	return true

func test_reset_clears_game_over() -> bool:
	"""reset() should clear game_over state and reinitialize history"""
	var gm = get_node_or_null("/root/GameManager")
	if gm == null: return false
	_setup_controlled_grid(gm)
	gm.player_cells.append(Vector2i(30, 20))
	gm.grid[20][30] = CellType.MYCELIUM

	gm.end_game("test")
	assert_true(gm.game_over, "game_over set before reset")

	gm.reset()
	assert_false(gm.game_over, "game_over=false after reset")
	assert_eq(gm.game_over_reason, "", "reason cleared after reset")
	assert_gt(gm.history.size(), 0, "History has initial snapshot after reset")
	return true

func test_end_screen_scene_loadable() -> bool:
	"""End screen scene should be loadable with all required nodes"""
	assert_true(ResourceLoader.exists("res://scenes/end_screen.tscn"), "end_screen.tscn exists")
	assert_true(ResourceLoader.exists("res://scenes/end_screen.gd"), "end_screen.gd exists")
	if ResourceLoader.exists("res://scenes/end_screen.tscn"):
		var scene: PackedScene = load("res://scenes/end_screen.tscn")
		assert_not_null(scene, "end_screen.tscn loadable")
		var instance: CanvasLayer = scene.instantiate()
		assert_not_null(instance, "end_screen instance created")
		# Verify all required child nodes exist
		assert_not_null(instance.get_node_or_null("BG"), "BG node exists")
		assert_not_null(instance.get_node_or_null("Panel"), "Panel node exists")
		assert_not_null(instance.get_node_or_null("Panel/Margin/VBox/Title"), "Title exists")
		assert_not_null(instance.get_node_or_null("Panel/Margin/VBox/Reason"), "Reason exists")
		assert_not_null(instance.get_node_or_null("Panel/Margin/VBox/SummarySection/SummaryText"), "SummaryText exists")
		assert_not_null(instance.get_node_or_null("Panel/Margin/VBox/ChartsRow/ResourceChart"), "ResourceChart exists")
		assert_not_null(instance.get_node_or_null("Panel/Margin/VBox/ChartsRow/ProgressChart"), "ProgressChart exists")
		assert_not_null(instance.get_node_or_null("Panel/Margin/VBox/RivalsSection/RivalsGrid"), "RivalsGrid exists")
		assert_not_null(instance.get_node_or_null("Panel/Margin/VBox/ReplayBtn"), "ReplayBtn exists")
		instance.queue_free()
	return true

func test_build_run_summary_generates_text() -> bool:
	"""Run summary should generate non-empty text with stats"""
	var gm = get_node_or_null("/root/GameManager")
	if gm == null: return false
	_setup_controlled_grid(gm)
	gm.player_cells.append(Vector2i(30, 20))
	gm.player_cells.append(Vector2i(30, 21))
	gm.grid[20][30] = CellType.MYCELIUM
	gm.grid[21][30] = CellType.MYCELIUM
	gm.player_absorbed = 5
	gm.player_sugars = 3
	gm.player_minerals = 2
	gm.player_water = 4
	gm.player_gp = 25.0
	gm.seed_val = 42

	# Instantiate end screen and call summary builder
	var scene: PackedScene = load("res://scenes/end_screen.tscn")
	var instance: CanvasLayer = scene.instantiate()
	add_child(instance)
	var summary: String = instance._build_run_summary(gm)

	assert_true(summary.length() > 0, "Summary is not empty")
	assert_true("2" in summary, "Summary mentions cell count")  # 2 cells
	assert_true("5" in summary, "Summary mentions absorbed count")
	instance.queue_free()
	return true

func test_run_summary_includes_performance_tier() -> bool:
	"""Run summary should include a performance tier"""
	var gm = get_node_or_null("/root/GameManager")
	if gm == null: return false
	_setup_controlled_grid(gm)
	# Place 200 cells to get "legendary" tier
	for i: int in range(200):
		gm.player_cells.append(Vector2i(i % gm.GRID_W, i / gm.GRID_W))
	gm.player_absorbed = 40
	gm.player_sugars = 10
	gm.player_gp = 50.0
	gm.seed_val = 99

	var scene: PackedScene = load("res://scenes/end_screen.tscn")
	var instance: CanvasLayer = scene.instantiate()
	add_child(instance)
	var summary: String = instance._build_run_summary(gm)

	assert_true("LEGENDARY" in summary, "200 cells = legendary tier, found LEGENDARY in summary")
	assert_true("TROPHY" in summary, "Legendary tier has trophy icon")
	instance.queue_free()
	return true

func test_end_screen_visible_on_game_over() -> bool:
	"""End screen should become visible when game ends — test via tree-attached instance"""
	var gm = get_node_or_null("/root/GameManager")
	if gm == null: return false
	_setup_controlled_grid(gm)
	gm.player_cells.append(Vector2i(30, 20))
	gm.grid[20][30] = CellType.MYCELIUM

	var scene: PackedScene = load("res://scenes/end_screen.tscn")
	var instance: CanvasLayer = scene.instantiate()
	instance.visible = false

	# Add to tree so /root autoload lookups work
	add_child(instance)

	# Simulate game end
	gm.game_over = false  # Reset so end_game doesn't bail
	gm.end_game("test_reason")

	assert_true(instance.visible, "End screen visible after game over")
	instance.queue_free()
	return true
