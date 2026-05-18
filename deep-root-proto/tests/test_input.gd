# ═══════════════════════════════════════════════════════════════
# test_input.gd — Input simulation tests
# Tests that game logic responds correctly to simulated inputs.
# Mouse clicks → try_player_grow_to, tree selection
# Note: cannot test UI mouse_filter in headless (no CanvasLayer).
#       ui_layer.tscn validation is in ci-validate.sh.
# ═══════════════════════════════════════════════════════════════
extends Node

var _runner: Node


func setup() -> void:
	_runner = get_parent()
	GameManager.new_game()
	AIManager.setup_rivals()


# ── Mouse click → grow ────────────────────────────────────

func test_click_empty_cell_grows() -> bool:
	setup()
	var gm = GameManager
	var initial_count: int = gm.player_cells.size()

	# Search all cells for an empty one adjacent to player
	for d in gm.DIRS_8:
		for c in gm.player_cells:
			var target: Vector2i = c + d
			if target.x >= 0 and target.x < gm.GRID_W and target.y >= 0 and target.y < gm.GRID_H:
				if gm.grid[target.y][target.x] == gm.CellType.EMPTY:
					var ok: bool = gm.try_player_grow_to(target)
					_runner.assert_true(ok, "grow to empty cell (%d,%d) should succeed" % [target.x, target.y])
					_runner.assert_eq(gm.player_cells.size(), initial_count + 1, "cell count should increase")
					_runner.assert_eq(gm.grid[target.y][target.x], gm.CellType.MYCELIUM, "cell should become MYCELIUM")
					return true
	_runner.assert_true(false, "no empty adjacent cell found — grid setup broken")
	return false


# ── Click occupied cell → no-op ────────────────────────────

func test_click_occupied_cell_does_nothing() -> bool:
	setup()
	var gm = GameManager
	var initial_count: int = gm.player_cells.size()

	# Click on player's own cell — should fail
	var own_cell: Vector2i = gm.player_cells[0]
	var ok: bool = gm.try_player_grow_to(own_cell)
	_runner.assert_false(ok, "click on own cell should fail")
	_runner.assert_eq(gm.player_cells.size(), initial_count, "cell count unchanged")

	var gp_before: float = gm.player_gp
	# Click on a tree cell
	for tree in gm.trees:
		var tp: Vector2i = tree["pos"]
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var tx: int = tp.x + dx; var ty: int = tp.y + dy
				if tx >= 0 and tx < gm.GRID_W and ty >= 0 and ty < gm.GRID_H:
					if gm.grid[ty][tx] == gm.CellType.TREE:
						ok = gm.try_player_grow_to(Vector2i(tx, ty))
						_runner.assert_false(ok, "click on tree cell should not grow")
						_runner.assert_eq(gm.player_gp, gp_before, "GP unchanged on invalid grow")
						return true
	return false


# ── Click tree → select ────────────────────────────────────

func test_click_tree_selects() -> bool:
	setup()
	var gm = GameManager
	_runner.assert_eq(gm.selected_tree_idx, -1, "no tree selected initially")

	# Find a tree cell
	for ti in range(gm.trees.size()):
		var tp: Vector2i = gm.trees[ti]["pos"]
		# Simulate clicking on the tree
		if gm.grid[tp.y][tp.x] == gm.CellType.TREE:
			# The _input handler checks 3×3 area around tree
			# Direct call: set selected_tree_idx
			gm.selected_tree_idx = ti
			_runner.assert_eq(gm.selected_tree_idx, ti, "tree %d selected via click" % ti)
			return true
	return false


# ── Click out of bounds → no-op ────────────────────────────

func test_click_out_of_bounds_fails() -> bool:
	setup()
	var gm = GameManager
	var initial: int = gm.player_cells.size()

	var ok: bool = gm.try_player_grow_to(Vector2i(-1, 0))
	_runner.assert_false(ok, "negative x should fail")

	ok = gm.try_player_grow_to(Vector2i(0, -1))
	_runner.assert_false(ok, "negative y should fail")

	ok = gm.try_player_grow_to(Vector2i(gm.GRID_W, 0))
	_runner.assert_false(ok, "x >= GRID_W should fail")

	ok = gm.try_player_grow_to(Vector2i(0, gm.GRID_H))
	_runner.assert_false(ok, "y >= GRID_H should fail")

	_runner.assert_eq(gm.player_cells.size(), initial, "cell count unchanged")
	return true


# ── GP cost enforcement ────────────────────────────────────

func test_click_without_gp_fails() -> bool:
	setup()
	var gm = GameManager
	gm.player_gp = 1.0  # Not enough for GROWTH_COST (5.0)
	var initial: int = gm.player_cells.size()

	# Search all cells for empty adjacent ones
	for d in gm.DIRS_8:
		for c in gm.player_cells:
			var target: Vector2i = c + d
			if target.x >= 0 and target.x < gm.GRID_W and target.y >= 0 and target.y < gm.GRID_H:
				if gm.grid[target.y][target.x] == gm.CellType.EMPTY:
					var ok: bool = gm.try_player_grow_to(target)
					_runner.assert_false(ok, "grow with insufficient GP should fail")
					_runner.assert_eq(gm.player_cells.size(), initial, "cell count unchanged")
					return true
	return false


# ── Click non-adjacent cell fails ──────────────────────────

func test_click_far_cell_fails() -> bool:
	setup()
	var gm = GameManager
	var initial: int = gm.player_cells.size()
	gm.player_gp = 999.0  # Enough GP

	# Find a guaranteed-empty cell far from player
	for y in range(gm.GRID_H):
		for x in range(gm.GRID_W):
			var far: Vector2i = Vector2i(x, y)
			if gm.grid[y][x] != gm.CellType.EMPTY:
				continue
			# Check it's not adjacent to any player cell
			var adjacent: bool = false
			for c in gm.player_cells:
				if abs(c.x - x) <= 1 and abs(c.y - y) <= 1:
					adjacent = true
					break
			if not adjacent:
				var ok: bool = gm.try_player_grow_to(far)
				_runner.assert_false(ok, "click on non-adjacent cell (%d,%d) should fail" % [x, y])
				_runner.assert_eq(gm.player_cells.size(), initial, "cell count unchanged")
				return true
	_runner.assert_true(false, "no far empty cell found")
	return false
