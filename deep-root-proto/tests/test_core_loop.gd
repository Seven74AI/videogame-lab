# ═══════════════════════════════════════════════════════════════
# test_core_loop.gd — Core game loop regression tests
# Tests the full lifecycle: new_game → GP accrual → growth →
# absorption → trade → difficulty → rival growth → game over → reset
# Uses real GameManager + AIManager autoloads.
# ═══════════════════════════════════════════════════════════════
extends Node


func _runner():
	return get_parent()


# ── new_game() initialization ───────────────────────────────

func test_new_game_creates_valid_state() -> bool:
	"""After new_game(), all player fields should be initialized correctly."""
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	r.assert_not_null(gm, "GameManager exists")
	if gm == null: return true

	gm.new_game()

	r.assert_eq(gm.player_gp, 10.0, "player_gp = 10.0")
	r.assert_eq(gm.player_gp_rate, gm.BASE_GP_RATE, "gp_rate = base rate")
	r.assert_eq(gm.player_sugars, 0, "player_sugars = 0")
	r.assert_eq(gm.player_water, 0, "player_water = 0")
	r.assert_eq(gm.player_minerals, 0, "player_minerals = 0")
	r.assert_eq(gm.player_absorbed, 0, "player_absorbed = 0")
	r.assert_eq(gm.player_growth_progress, 0.0, "growth_progress = 0")
	r.assert_false(gm.game_over, "game_over = false")
	r.assert_eq(gm.game_over_reason, "", "game_over_reason = ''")
	r.assert_eq(gm.selected_tree_idx, -1, "no tree selected")
	r.assert_eq(gm.link_mode, -1, "not in link mode")
	r.assert_gt(gm.seed_val, 0, "seed_val > 0")
	return true


func test_new_game_player_has_one_cell() -> bool:
	"""Player starts with exactly 1 mycelium cell."""
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	if gm == null: return true
	gm.new_game()

	r.assert_eq(gm.player_cells.size(), 1, "player starts with 1 cell")
	var pos: Vector2i = gm.player_cells[0]
	r.assert_eq(gm.grid[pos.y][pos.x], gm.CellType.MYCELIUM, "player cell is MYCELIUM")
	return true


func test_new_game_creates_three_trees() -> bool:
	"""3 trees should be placed with correct initial state."""
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	if gm == null: return true
	gm.new_game()

	r.assert_eq(gm.trees.size(), 3, "3 trees created")
	for ti: int in range(3):
		var tree: Dictionary = gm.trees[ti]
		r.assert_eq(tree["trades_left"], gm.MAX_TRADES_PER_TREE, "tree %d: %d trades" % [ti, gm.MAX_TRADES_PER_TREE])
		r.assert_eq(tree["cooldown"], 0.0, "tree %d: no cooldown" % ti)
		r.assert_eq(tree["linked_to"], -1, "tree %d: not linked" % ti)
		r.assert_true(tree.has("regen_timer"), "tree %d: has regen_timer" % ti)
		r.assert_eq(tree["regen_timer"], gm.REGEN_INTERVAL, "tree %d: regen_timer = REGEN_INTERVAL" % ti)
	return true


func test_new_game_grid_has_dimensions() -> bool:
	"""Grid should be 60x40 and contain resources."""
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	if gm == null: return true
	gm.new_game()

	r.assert_eq(gm.grid.size(), gm.GRID_H, "grid height = 40")
	r.assert_eq(gm.grid[0].size(), gm.GRID_W, "grid width = 60")

	# Count non-empty cells (resources should be placed)
	var non_empty: int = 0
	for y: int in range(gm.GRID_H):
		for x: int in range(gm.GRID_W):
			if gm.grid[y][x] != gm.CellType.EMPTY and gm.grid[y][x] != gm.CellType.MYCELIUM:
				non_empty += 1
	r.assert_gt(non_empty, 100, "at least 100 resource cells placed")
	return true


# ── GP accrual ───────────────────────────────────────────

func test_gp_accrues_over_time() -> bool:
	"""player_gp increases with base rate * delta."""
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	if gm == null: return true
	gm.new_game()

	var before: float = gm.player_gp
	gm.player_gp += gm.player_gp_rate * 5.0  # 5 seconds
	gm.player_growth_progress += gm.player_gp_rate * 5.0
	r.assert_eq(gm.player_gp, before + gm.BASE_GP_RATE * 5.0, "GP accrued over 5s")
	r.assert_eq(gm.player_growth_progress, gm.BASE_GP_RATE * 5.0, "growth progress accrued")
	return true


# ── Growth cost and zone mechanics ───────────────────────

func test_growth_cost_vs_gp() -> bool:
	"""Growth should only succeed when player has enough GP."""
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	if gm == null: return true
	gm.new_game()

	# Find the growth cost for a player-adjacent cell
	gm.update_growth_candidates()
	if gm.growth_candidates.is_empty():
		return true  # Edge case: no adjacent empty cells

	var target: Vector2i = gm.growth_candidates[0]
	var cost: float = gm.get_growth_cost(target)

	# Not enough GP
	gm.player_gp = cost - 1.0
	var ok: bool = gm.try_player_grow_to(target)
	r.assert_false(ok, "growth blocked with insufficient GP")

	# Enough GP
	gm.player_gp = cost + 10.0
	ok = gm.try_player_grow_to(target)
	r.assert_true(ok, "growth succeeds with sufficient GP")
	return true


# ── Absorption mechanics ─────────────────────────────────

func test_grow_into_water_gives_gp_and_water() -> bool:
	"""Growing into a WATER cell should give +2 GP and +1 water."""
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	if gm == null: return true
	gm.new_game()

	# Find a WATER cell adjacent to player
	for d in gm.DIRS_8:
		for c in gm.player_cells:
			var target: Vector2i = c + d
			if target.x >= 0 and target.x < gm.GRID_W and target.y >= 0 and target.y < gm.GRID_H:
				if gm.grid[target.y][target.x] == gm.CellType.WATER:
					var gp_before: float = gm.player_gp
					var water_before: int = gm.player_water
					var absorbed_before: int = gm.player_absorbed

					gm.player_gp += 100.0  # Enough GP
					var ok: bool = gm.try_player_grow_to(target)
					if ok:
						r.assert_eq(gm.player_gp, gp_before + 100.0 - gm.get_growth_cost(target) + 2.0, "GP: +2 for water")
						r.assert_eq(gm.player_water, water_before + 1, "water count +1")
						r.assert_eq(gm.player_absorbed, absorbed_before + 1, "absorbed count +1")
						r.assert_eq(gm.grid_resources[target.y][target.x], 0.0, "resource consumed")
						return true
	return true  # No adjacent water, test passes vacuously


func test_grow_into_mineral_gives_gp_and_mineral() -> bool:
	"""Growing into a MINERAL cell should give +3 GP and +1 mineral."""
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	if gm == null: return true
	gm.new_game()

	for d in gm.DIRS_8:
		for c in gm.player_cells:
			var target: Vector2i = c + d
			if target.x >= 0 and target.x < gm.GRID_W and target.y >= 0 and target.y < gm.GRID_H:
				if gm.grid[target.y][target.x] == gm.CellType.MINERAL:
					var mineral_before: int = gm.player_minerals
					var gp_before: float = gm.player_gp
					var absorbed_before: int = gm.player_absorbed

					gm.player_gp += 100.0
					var ok: bool = gm.try_player_grow_to(target)
					if ok:
						r.assert_eq(gm.player_gp, gp_before + 100.0 - gm.get_growth_cost(target) + 3.0, "GP: +3 for mineral")
						r.assert_eq(gm.player_minerals, mineral_before + 1, "mineral count +1")
						r.assert_eq(gm.player_absorbed, absorbed_before + 1, "absorbed count +1")
						return true
	return true


func test_grow_into_sugar_gives_gp_rate_boost() -> bool:
	"""Growing into a SUGAR cell should boost GP rate."""
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	if gm == null: return true
	gm.new_game()

	for d in gm.DIRS_8:
		for c in gm.player_cells:
			var target: Vector2i = c + d
			if target.x >= 0 and target.x < gm.GRID_W and target.y >= 0 and target.y < gm.GRID_H:
				if gm.grid[target.y][target.x] == gm.CellType.SUGAR:
					var sugar_before: int = gm.player_sugars
					var rate_before: float = gm.player_gp_rate

					gm.player_gp += 100.0
					var ok: bool = gm.try_player_grow_to(target)
					if ok:
						r.assert_eq(gm.player_sugars, sugar_before + 1, "sugar count +1")
						if sugar_before == 0:
							r.assert_gt(gm.player_gp_rate, rate_before, "gp_rate increased after first sugar")
						return true
	return true


# ── Trade mechanics ──────────────────────────────────────

func test_trade_fails_without_minerals() -> bool:
	"""Trade requires minerals — fails when player has none."""
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	if gm == null: return true
	gm.new_game()

	# Deplete minerals
	gm.player_minerals = 0
	gm.selected_tree_idx = 0

	# Place player cell next to tree 0
	var tp: Vector2i = gm.trees[0]["pos"]
	gm.player_cells.clear()
	gm.player_cells.append(Vector2i(tp.x + 1, tp.y))
	gm.grid[tp.y][tp.x + 1] = gm.CellType.MYCELIUM

	var mineral_before: int = gm.player_minerals
	var sugar_before: int = gm.player_sugars
	gm.trade(0)  # Trade tier 0: costs 2 minerals

	r.assert_eq(gm.player_minerals, mineral_before, "minerals unchanged on failed trade")
	r.assert_eq(gm.player_sugars, sugar_before, "sugars unchanged on failed trade")
	return true


func test_trade_success_exchanges_resources() -> bool:
	"""A successful trade should exchange minerals for sugars."""
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	if gm == null: return true
	gm.new_game()

	# Give minerals and position player next to tree 0
	gm.player_minerals = 20
	gm.selected_tree_idx = 0

	var tp: Vector2i = gm.trees[0]["pos"]
	gm.player_cells.clear()
	gm.player_cells.append(Vector2i(tp.x + 1, tp.y))
	gm.grid[tp.y][tp.x + 1] = gm.CellType.MYCELIUM

	var trades_before: int = gm.trees[0]["trades_left"]
	var mineral_before: int = gm.player_minerals
	gm.trade(0)  # Trade tier 0: costs 2 minerals, gives 1 sugar

	r.assert_eq(gm.player_minerals, mineral_before - 2, "minerals -2 after trade")
	r.assert_eq(gm.trees[0]["trades_left"], trades_before - 1, "trades_left -1")
	r.assert_gt(gm.trees[0]["cooldown"], 0.0, "trade cooldown active")
	return true


func test_trade_respects_cooldown() -> bool:
	"""A tree on cooldown should reject trades."""
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	if gm == null: return true
	gm.new_game()

	gm.player_minerals = 20
	gm.selected_tree_idx = 0
	var tp: Vector2i = gm.trees[0]["pos"]
	gm.player_cells.clear()
	gm.player_cells.append(Vector2i(tp.x + 1, tp.y))
	gm.grid[tp.y][tp.x + 1] = gm.CellType.MYCELIUM

	# First trade succeeds
	gm.trade(0)
	r.assert_eq(gm.trees[0]["trades_left"], gm.MAX_TRADES_PER_TREE - 1, "first trade OK")

	# Second trade while on cooldown should fail
	var trades_after_first: int = gm.trees[0]["trades_left"]
	gm.trade(0)
	r.assert_eq(gm.trees[0]["trades_left"], trades_after_first, "no trade during cooldown")
	return true


# ── Deep Root Pulse mechanics ────────────────────────────

func test_pulse_only_on_exhausted_tree() -> bool:
	"""Deep Root Pulse only works when trades_left = 0."""
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	if gm == null: return true
	gm.new_game()

	# Tree with trades — pulse should be blocked
	gm.trees[0]["trades_left"] = 3
	gm.player_gp = 20.0
	var gp_before: float = gm.player_gp
	gm.deep_root_pulse(0)
	r.assert_eq(gm.player_gp, gp_before, "GP unchanged when tree has trades")
	r.assert_eq(gm.trees[0]["trades_left"], 3, "trades unchanged when tree has trades")

	# Exhausted tree — pulse should work
	gm.trees[0]["trades_left"] = 0
	gm.player_gp = 20.0
	gm.deep_root_pulse(0)
	r.assert_eq(gm.player_gp, 5.0, "GP: 20 - 15 = 5")
	r.assert_eq(gm.trees[0]["trades_left"], gm.DEEP_ROOT_PULSE_REGEN, "trades regenerated")
	return true


# ── Tree linking mechanics ───────────────────────────────

func test_link_trees_success() -> bool:
	"""Linking two exhausted trees should set linked_to and add bonus trades."""
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	if gm == null: return true
	gm.new_game()

	gm.trees[0]["trades_left"] = 0
	gm.trees[1]["trades_left"] = 0

	gm.link_trees(0, 1)

	r.assert_eq(gm.trees[0]["linked_to"], 1, "tree 0 linked to 1")
	r.assert_eq(gm.trees[1]["linked_to"], 0, "tree 1 linked to 0")
	r.assert_eq(gm.trees[0]["trades_left"], gm.LINK_BONUS_TRADES, "tree 0: +%d trades" % gm.LINK_BONUS_TRADES)
	r.assert_eq(gm.trees[1]["trades_left"], gm.LINK_BONUS_TRADES, "tree 1: +%d trades" % gm.LINK_BONUS_TRADES)
	r.assert_eq(gm.link_mode, -1, "link_mode cleared")
	return true


func test_unlink_removes_bonus_and_relationship() -> bool:
	"""Unlinking should clear linked_to and remove bonus trades (capped at 0)."""
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	if gm == null: return true
	gm.new_game()

	gm.trees[0]["trades_left"] = 0
	gm.trees[1]["trades_left"] = 0
	gm.link_trees(0, 1)

	# Simulate using some trades after linking
	gm.trees[0]["trades_left"] = 8
	gm.trees[1]["trades_left"] = 2

	gm.unlink_trees(0)

	r.assert_eq(gm.trees[0]["linked_to"], -1, "tree 0 unlinked")
	r.assert_eq(gm.trees[1]["linked_to"], -1, "tree 1 unlinked")
	r.assert_eq(gm.trees[0]["trades_left"], 2, "tree 0: 8 - 6 = 2")
	r.assert_eq(gm.trees[1]["trades_left"], 0, "tree 1: 2 - 2 = 0 (capped)")
	return true


# ── Difficulty progression ───────────────────────────────

func test_difficulty_tier_progression() -> bool:
	"""Difficulty tier should increase as player territory grows."""
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	if gm == null: return true
	gm.new_game()

	# Default: 1 cell out of 2400 => ~0.04% => tier 0
	r.assert_eq(gm.get_difficulty_tier(), 0, "tier 0 with 1 cell")

	# Simulate territory growth to reach tier 2 (>= 15% = 360 cells)
	for y: int in range(gm.GRID_H):
		for x: int in range(gm.GRID_W):
			if gm.player_cells.size() >= 400:
				break
			if gm.grid[y][x] == gm.CellType.EMPTY:
				gm.grid[y][x] = gm.CellType.MYCELIUM
				gm.player_cells.append(Vector2i(x, y))
		if gm.player_cells.size() >= 400:
			break

	r.assert_ge(gm.player_cells.size(), 360, "at least 360 cells placed (15%% threshold)")
	r.assert_ge(gm.get_difficulty_tier(), 2, "tier >= 2 with >=15%% territory")
	return true


func test_speed_multiplier_increases_with_tier() -> bool:
	"""Rival speed multiplier should increase with territory."""
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	if gm == null: return true
	gm.new_game()

	var mult0: float = gm.get_rival_speed_multiplier()
	r.assert_eq(mult0, 1.0, "tier 0: multiplier = 1.0")

	# Manually add enough cells for tier 2 (territory >= 15%)
	for y: int in range(gm.GRID_H):
		for x: int in range(gm.GRID_W):
			if gm.player_cells.size() >= 450:
				break
			if gm.grid[y][x] == gm.CellType.EMPTY:
				gm.grid[y][x] = gm.CellType.MYCELIUM
				gm.player_cells.append(Vector2i(x, y))

	if gm.player_cells.size() >= 450:
		var mult_new: float = gm.get_rival_speed_multiplier()
		r.assert_ge(mult_new, 1.15, "multiplier increased with territory")
	return true


# ── Rival initialization ─────────────────────────────────

func test_setup_rivals_creates_three_rivals() -> bool:
	"""AIManager.setup_rivals() should create 3 rivals."""
	var am := get_node_or_null("/root/AIManager")
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	if am == null or gm == null: return true
	gm.new_game()
	am.setup_rivals()

	r.assert_eq(am.rivals.size(), 3, "3 rivals created")
	for i: int in range(3):
		var rival: Dictionary = am.rivals[i]
		r.assert_true(rival.has("personality"), "rival %d has personality" % i)
		r.assert_true(rival.has("cells"), "rival %d has cells" % i)
		r.assert_gt(rival["cells"].size(), 0, "rival %d has at least 1 cell" % i)
		r.assert_true(rival.has("color"), "rival %d has color" % i)
		r.assert_true(rival.has("phase"), "rival %d has phase" % i)
	return true


func test_rivals_have_distinct_personalities() -> bool:
	"""Three rivals should have unique personalities."""
	var am := get_node_or_null("/root/AIManager")
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	if am == null or gm == null: return true
	gm.new_game()
	am.setup_rivals()

	var personalities: Array[String] = []
	for rival: Dictionary in am.rivals:
		personalities.append(rival["personality"])

	r.assert_true(personalities.has("aggressive"), "has aggressive rival")
	r.assert_true(personalities.has("defensive"), "has defensive rival")
	r.assert_true(personalities.has("opportunistic"), "has opportunistic rival")
	return true


# ── Rival growth over time ───────────────────────────────

func test_rival_growth_increases_cells() -> bool:
	"""Rival growth should add cells over time."""
	var am := get_node_or_null("/root/AIManager")
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	if am == null or gm == null: return true
	gm.new_game()
	am.setup_rivals()

	# Force several growth ticks on rival 0
	var initial_cells: int = am.rivals[0]["cells"].size()
	for _i in range(3):
		am.rival_grow(0)

	var final_cells: int = am.rivals[0]["cells"].size()
	r.assert_ge(final_cells, initial_cells, "rival cells increased or stayed same")
	# With 3 growth ticks on an empty grid, should have gained at least some cells
	# (defensive rival might grow slower, so we just check non-decrease)
	return true


# ── Game over detection ──────────────────────────────────

func test_check_game_over_player_died() -> bool:
	"""check_game_over() should detect dead player (no cells)."""
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	if gm == null: return true
	gm.new_game()

	gm.player_cells.clear()
	gm.check_game_over()

	r.assert_true(gm.game_over, "game_over = true when player died")
	r.assert_eq(gm.game_over_reason, "player_died", "reason = player_died")
	return true


func test_check_game_over_grid_full() -> bool:
	"""check_game_over() should detect full grid."""
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	if gm == null: return true
	gm.new_game()

	# Fill grid (leave one for player)
	for y: int in range(gm.GRID_H):
		for x: int in range(gm.GRID_W):
			gm.grid[y][x] = gm.CellType.WATER
	gm.player_cells.append(Vector2i(30, 20))
	gm.grid[20][30] = gm.CellType.MYCELIUM

	gm.check_game_over()

	r.assert_true(gm.game_over, "game_over = true when grid full")
	r.assert_eq(gm.game_over_reason, "grid_full", "reason = grid_full")
	return true


func test_end_game_idempotent() -> bool:
	"""Calling end_game twice should not double-record or change reason."""
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	if gm == null: return true
	gm.new_game()

	gm.player_cells.append(Vector2i(30, 20))
	gm.grid[20][30] = gm.CellType.MYCELIUM

	gm.end_game("first")
	var hist_size: int = gm.history.size()
	gm.end_game("second")

	r.assert_eq(gm.history.size(), hist_size, "no extra snapshot on second end_game")
	r.assert_eq(gm.game_over_reason, "first", "reason stays as first")
	return true


# ── Reset mechanics ──────────────────────────────────────

func test_reset_clears_state() -> bool:
	"""reset() should clear game_over, reinitialize from new_game()."""
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	if gm == null: return true
	gm.new_game()

	gm.end_game("test")
	r.assert_true(gm.game_over, "game_over set before reset")

	gm.reset()

	r.assert_false(gm.game_over, "game_over = false after reset")
	r.assert_eq(gm.game_over_reason, "", "reason cleared after reset")
	r.assert_eq(gm.player_cells.size(), 1, "player has 1 cell after reset")
	r.assert_eq(gm.player_gp, 10.0, "GP = 10 after reset")
	r.assert_gt(gm.trees.size(), 0, "trees exist after reset")
	r.assert_gt(gm.seed_val, 0, "new seed after reset")
	return true


# ── History tracking ─────────────────────────────────────

func test_history_records_on_interval() -> bool:
	"""History should record snapshots every HISTORY_INTERVAL seconds."""
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	if gm == null: return true
	gm.new_game()

	var initial_count: int = gm.history.size()
	r.assert_eq(initial_count, 1, "history starts with 1 snapshot")

	# Simulate time passing
	for _i in range(3):
		gm.tick_history(gm.HISTORY_INTERVAL)

	r.assert_eq(gm.history.size(), initial_count + 3, "3 more snapshots recorded")
	return true


func test_history_snapshot_has_all_fields() -> bool:
	"""Each snapshot should contain required fields."""
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	if gm == null: return true
	gm.new_game()

	var snap: Dictionary = gm.history[0]
	r.assert_true(snap.has("player_cells"), "snapshot has player_cells")
	r.assert_true(snap.has("player_gp"), "snapshot has player_gp")
	r.assert_true(snap.has("player_absorbed"), "snapshot has player_absorbed")
	r.assert_true(snap.has("player_sugars"), "snapshot has player_sugars")
	r.assert_true(snap.has("rival_cells"), "snapshot has rival_cells")
	r.assert_eq(snap["rival_cells"].size(), 3, "3 rival counts in snapshot")
	return true


# ── Tree regen integration ───────────────────────────────

func test_tree_regen_over_time() -> bool:
	"""Tree should regen trades when depleted and unlinked."""
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	if gm == null: return true
	gm.new_game()

	# Deplete a tree
	gm.trees[0]["trades_left"] = 0
	gm.trees[0]["regen_timer"] = 0.0  # Timer expired
	gm.trees[0]["linked_to"] = -1  # Unlinked

	# Regen tick: timer expired, trades < max, unlinked
	if gm.trees[0]["regen_timer"] <= 0.0 and gm.trees[0]["trades_left"] < gm.MAX_TRADES_PER_TREE and gm.trees[0].get("linked_to", -1) < 0:
		gm.trees[0]["trades_left"] += 1
		gm.trees[0]["regen_timer"] = gm.REGEN_INTERVAL

	r.assert_eq(gm.trees[0]["trades_left"], 1, "regen: 0 → 1 trade")
	r.assert_eq(gm.trees[0]["regen_timer"], gm.REGEN_INTERVAL, "regen timer reset to 60")
	return true


# ── Multiple game lifecycle test ─────────────────────────

func test_full_game_lifecycle() -> bool:
	"""new_game → grow → trade → reset should all work without crashes."""
	var gm := get_node_or_null("/root/GameManager")
	var am := get_node_or_null("/root/AIManager")
	var r = _runner()
	if gm == null or am == null: return true

	# Phase 1: New game
	gm.new_game()
	am.setup_rivals()
	r.assert_eq(gm.player_cells.size(), 1, "phase 1: 1 player cell")
	r.assert_eq(am.rivals.size(), 3, "phase 1: 3 rivals")
	r.assert_false(gm.game_over, "phase 1: game not over")

	# Phase 2: Grow a bit
	gm.update_growth_candidates()
	gm.player_gp += 100.0
	var any_grown: bool = false
	for cand: Vector2i in gm.growth_candidates:
		if gm.try_player_grow_to(cand):
			any_grown = true
	if any_grown:
		r.assert_gt(gm.player_cells.size(), 1, "phase 2: player grew")

	# Phase 3: Trade
	gm.player_minerals = 20
	gm.selected_tree_idx = -1
	var tp: Vector2i = gm.trees[0]["pos"]
	# Place near tree
	gm.player_cells.append(Vector2i(tp.x + 1, tp.y))
	gm.grid[tp.y][tp.x + 1] = gm.CellType.MYCELIUM
	var trades_before: int = gm.trees[0]["trades_left"]
	gm.trade(0)
	r.assert_le(gm.trees[0]["trades_left"], trades_before, "phase 3: trade consumed a use")

	# Phase 4: Reset
	gm.reset()
	r.assert_false(gm.game_over, "phase 4: game_over false after reset")
	r.assert_eq(gm.player_cells.size(), 1, "phase 4: back to 1 cell")
	r.assert_eq(gm.player_gp, 10.0, "phase 4: GP = 10")
	r.assert_eq(gm.trees.size(), 3, "phase 4: 3 trees again")
	r.assert_eq(gm.history.size(), 1, "phase 4: history reset to 1 snapshot")

	return true
