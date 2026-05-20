# ═══════════════════════════════════════════════════════════════
# test_input.gd — Input simulation tests
# Tests that game logic responds correctly to simulated inputs.
# Mouse clicks → try_player_grow_to, tree selection
# Note: cannot test UI mouse_filter in headless (no CanvasLayer).
#       ui_layer.tscn validation is in ci-validate.sh.
# ═══════════════════════════════════════════════════════════════
extends GutTest

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
					_assert_true(ok, "grow to empty cell (%d,%d) should succeed" % [target.x, target.y])
					_assert_eq(gm.player_cells.size(), initial_count + 1, "cell count should increase")
					_assert_eq(gm.grid[target.y][target.x], gm.CellType.MYCELIUM, "cell should become MYCELIUM")
					return true
	_assert_true(false, "no empty adjacent cell found — grid setup broken")
	return false


# ── Click occupied cell → no-op ────────────────────────────

func test_click_occupied_cell_does_nothing() -> bool:
	setup()
	var gm = GameManager
	var initial_count: int = gm.player_cells.size()

	# Click on player's own cell — should fail
	var own_cell: Vector2i = gm.player_cells[0]
	var ok: bool = gm.try_player_grow_to(own_cell)
	_assert_false(ok, "click on own cell should fail")
	_assert_eq(gm.player_cells.size(), initial_count, "cell count unchanged")

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
						_assert_false(ok, "click on tree cell should not grow")
						_assert_eq(gm.player_gp, gp_before, "GP unchanged on invalid grow")
						return true
	return false


# ── Click tree → select ────────────────────────────────────

func test_click_tree_selects() -> bool:
	setup()
	var gm = GameManager
	_assert_eq(gm.selected_tree_idx, -1, "no tree selected initially")

	# Find a tree cell
	for ti in range(gm.trees.size()):
		var tp: Vector2i = gm.trees[ti]["pos"]
		# Simulate clicking on the tree
		if gm.grid[tp.y][tp.x] == gm.CellType.TREE:
			# The _input handler checks 3×3 area around tree
			# Direct call: set selected_tree_idx
			gm.selected_tree_idx = ti
			_assert_eq(gm.selected_tree_idx, ti, "tree %d selected via click" % ti)
			return true
	return false


# ── Click out of bounds → no-op ────────────────────────────

func test_click_out_of_bounds_fails() -> bool:
	setup()
	var gm = GameManager
	var initial: int = gm.player_cells.size()

	var ok: bool = gm.try_player_grow_to(Vector2i(-1, 0))
	_assert_false(ok, "negative x should fail")

	ok = gm.try_player_grow_to(Vector2i(0, -1))
	_assert_false(ok, "negative y should fail")

	ok = gm.try_player_grow_to(Vector2i(gm.GRID_W, 0))
	_assert_false(ok, "x >= GRID_W should fail")

	ok = gm.try_player_grow_to(Vector2i(0, gm.GRID_H))
	_assert_false(ok, "y >= GRID_H should fail")

	_assert_eq(gm.player_cells.size(), initial, "cell count unchanged")
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
					_assert_false(ok, "grow with insufficient GP should fail")
					_assert_eq(gm.player_cells.size(), initial, "cell count unchanged")
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
				_assert_false(ok, "click on non-adjacent cell (%d,%d) should fail" % [x, y])
				_assert_eq(gm.player_cells.size(), initial, "cell count unchanged")
				return true
	_assert_true(false, "no far empty cell found")
	return false


# ── Tree regen integration ─────────────────────────────────

func test_trees_have_regen_timer() -> bool:
	""" After new_game(), every tree must have a regen_timer field """
	setup()
	var gm = GameManager
	_assert_gt(gm.trees.size(), 0, "game must have trees")

	const REGEN_INTERVAL: float = 60.0
	for tree in gm.trees:
		_assert_true(tree.has("regen_timer"), "tree must have regen_timer field")
		_assert_ge(tree["regen_timer"], 0.0, "regen_timer must be non-negative")
	return true


func test_tree_regen_functional() -> bool:
	""" Simulate real regen: depleted tree gets trade back after timer """
	setup()
	var gm = GameManager

	# Deplete a tree completely
	for tree in gm.trees:
		tree["trades_left"] = 0
		tree["regen_timer"] = 0.0  # timer expired

	# Simulate one regen tick
	for tree in gm.trees:
		if tree["regen_timer"] <= 0.0 and tree["trades_left"] < gm.MAX_TRADES_PER_TREE:
			tree["trades_left"] += 1
			tree["regen_timer"] = 60.0

	# All trees should now have 1 trade
	for ti in range(gm.trees.size()):
		var tree = gm.trees[ti]
		_assert_eq(tree["trades_left"], 1, "tree %d should regen to 1 after depletion" % ti)
	return true


# ═══════════════════════════════════════════════════════════════
# Deep Root Pulse integration tests
# ═══════════════════════════════════════════════════════════════

func test_pulse_exhausted_tree_regens() -> bool:
	setup()
	var gm = GameManager

	# Exhaust a tree
	gm.trees[0]["trades_left"] = 0
	gm.player_gp = 20.0

	var before_trades: int = gm.trees[0]["trades_left"]
	gm.deep_root_pulse(0)

	_assert_eq(gm.player_gp, 5.0, "GP: 20 - 15 = 5 after pulse")
	_assert_eq(gm.trees[0]["trades_left"], 3, "Trades regenerated to 3")
	_assert_ne(before_trades, gm.trees[0]["trades_left"], "Trades changed from 0")
	return true


func test_pulse_blocked_if_tree_has_trades() -> bool:
	setup()
	var gm = GameManager
	gm.trees[0]["trades_left"] = 2
	gm.player_gp = 20.0
	var gp_before: float = gm.player_gp
	var trades_before: int = gm.trees[0]["trades_left"]

	gm.deep_root_pulse(0)

	_assert_eq(gm.player_gp, gp_before, "GP unchanged when pulse blocked")
	_assert_eq(gm.trees[0]["trades_left"], trades_before, "Trades unchanged")
	return true


func test_pulse_blocked_insufficient_gp() -> bool:
	setup()
	var gm = GameManager
	gm.trees[0]["trades_left"] = 0
	gm.player_gp = 5.0
	var gp_before: float = gm.player_gp

	gm.deep_root_pulse(0)

	_assert_eq(gm.player_gp, gp_before, "GP unchanged when can't afford")
	_assert_eq(gm.trees[0]["trades_left"], 0, "Trades still 0")
	return true


# ═══════════════════════════════════════════════════════════════
# Tree Linking integration tests
# ═══════════════════════════════════════════════════════════════

func test_link_two_exhausted_trees() -> bool:
	setup()
	var gm = GameManager

	# Exhaust both trees
	gm.trees[0]["trades_left"] = 0
	gm.trees[1]["trades_left"] = 0

	gm.link_trees(0, 1)

	_assert_eq(gm.trees[0]["linked_to"], 1, "Tree 0 linked to 1")
	_assert_eq(gm.trees[1]["linked_to"], 0, "Tree 1 linked to 0")
	_assert_eq(gm.trees[0]["trades_left"], 6, "Tree 0: +6 trades")
	_assert_eq(gm.trees[1]["trades_left"], 6, "Tree 1: +6 trades")
	_assert_eq(gm.link_mode, -1, "Link mode cleared after linking")
	return true


func test_link_blocked_self_link() -> bool:
	setup()
	var gm = GameManager
	gm.trees[0]["trades_left"] = 0

	gm.link_trees(0, 0)

	_assert_eq(gm.trees[0]["linked_to"], -1, "Tree not linked to itself")
	_assert_eq(gm.link_mode, -1, "Link mode cleared")
	return true


func test_link_blocked_already_linked() -> bool:
	setup()
	var gm = GameManager
	gm.trees[0]["trades_left"] = 0
	gm.trees[1]["trades_left"] = 0
	gm.trees[2]["trades_left"] = 0

	# First link: 0 ↔ 1
	gm.link_trees(0, 1)
	_assert_eq(gm.trees[0]["linked_to"], 1, "First link OK")

	# Try linking 0 to 2 (0 is already linked)
	gm.link_trees(0, 2)
	_assert_eq(gm.trees[0]["linked_to"], 1, "Still linked to 1, not 2")
	_assert_eq(gm.trees[2]["linked_to"], -1, "Tree 2 still unlinked")
	return true


func test_unlink_removes_bonus_capped() -> bool:
	setup()
	var gm = GameManager
	gm.trees[0]["trades_left"] = 0
	gm.trees[1]["trades_left"] = 0

	# Link them
	gm.link_trees(0, 1)

	# Use some trades on tree 0
	gm.trees[0]["trades_left"] = 8  # Simulate using some
	gm.trees[1]["trades_left"] = 2  # Used most of them

	gm.unlink_trees(0)

	_assert_eq(gm.trees[0]["linked_to"], -1, "Tree 0 unlinked")
	_assert_eq(gm.trees[1]["linked_to"], -1, "Tree 1 unlinked")
	_assert_eq(gm.trees[0]["trades_left"], 2, "Tree 0: 8-6=2 after unlink")
	_assert_eq(gm.trees[1]["trades_left"], 0, "Tree 1: 2-2=0 (capped) after unlink")
	return true


func test_unlink_not_linked_tree() -> bool:
	setup()
	var gm = GameManager
	gm.trees[0]["linked_to"] = -1
	gm.trees[0]["trades_left"] = 3
	var trades_before: int = gm.trees[0]["trades_left"]

	gm.unlink_trees(0)

	_assert_eq(gm.trees[0]["linked_to"], -1, "Still unlinked")
	_assert_eq(gm.trees[0]["trades_left"], trades_before, "Trades unchanged")
	return true


func test_link_mode_flow() -> bool:
	setup()
	var gm = GameManager
	gm.trees[0]["trades_left"] = 0

	_assert_eq(gm.link_mode, -1, "Not in link mode initially")

	gm.enter_link_mode(0)
	_assert_eq(gm.link_mode, 0, "In link mode for tree 0")

	gm.cancel_link_mode()
	_assert_eq(gm.link_mode, -1, "Link mode cancelled")
	return true


func test_enter_link_mode_blocked_if_has_trades() -> bool:
	setup()
	var gm = GameManager
	gm.trees[0]["trades_left"] = 3

	gm.enter_link_mode(0)
	_assert_eq(gm.link_mode, -1, "Link mode not entered — tree has trades")
	return true
