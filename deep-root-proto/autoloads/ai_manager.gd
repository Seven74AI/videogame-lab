# ═══════════════════════════════════════════════════════════════
# AIManager — Autoload singleton
# Manages 3 rival AIs with AStarGrid2D pathfinding
# ═══════════════════════════════════════════════════════════════
extends Node

const RIVAL_INTERVAL_MIN: float = 6.0
const RIVAL_INTERVAL_MAX: float = 10.0

# ── Rivals ─────────────────────────────────────────────────
var rivals: Array[Dictionary] = []
var rival_timers: Array[float] = [0.0, 0.0, 0.0]
var rival_intervals: Array[float] = []

# ── Pathfinding ────────────────────────────────────────────
var _astar: AStarGrid2D


func setup_rivals() -> void:
	rivals.clear()
	rival_intervals.clear()

	var gm = get_node_or_null("/root/GameManager")
	if gm == null: return

	var rival_configs: Array[Dictionary] = [
		{
			"personality": "aggressive",
			"color": Color(0.88, 0.18, 0.18),
			"cell_type": gm.CellType.RIVAL_RED,
			"start": Vector2i(gm.GRID_W - 8, 4),
		},
		{
			"personality": "defensive",
			"color": Color(0.92, 0.55, 0.08),
			"cell_type": gm.CellType.RIVAL_ORANGE,
			"start": Vector2i(5, gm.GRID_H - 6),
		},
		{
			"personality": "opportunistic",
			"color": Color(0.65, 0.18, 0.85),
			"cell_type": gm.CellType.RIVAL_VIOLET,
			"start": Vector2i(gm.GRID_W - 6, gm.GRID_H - 8),
		},
	]

	for cfg: Dictionary in rival_configs:
		var cells: Array[Vector2i] = [cfg["start"]]
		gm.grid[cfg["start"].y][cfg["start"].x] = cfg["cell_type"]
		rivals.append({
			"personality": cfg["personality"],
			"color": cfg["color"],
			"cell_type": cfg["cell_type"],
			"cells": cells,
			"gp": 10.0,
			"absorbed": 0,
		})

	for _i: int in range(3):
		rival_intervals.append(randf_range(RIVAL_INTERVAL_MIN, RIVAL_INTERVAL_MAX))
		rival_timers[_i] = rival_intervals[_i]

	_setup_astar()


func _setup_astar() -> void:
	_astar = AStarGrid2D.new()
	var gm = get_node_or_null("/root/GameManager")
	if gm == null: return
	# Godot 4.2: region is the canonical API but can fail to
	# initialize the internal grid for set_point_solid before update().
	# size is deprecated but ensures the grid is sized before update().
	_astar.region = Rect2i(0, 0, gm.GRID_W, gm.GRID_H)
	_astar.size = Vector2i(gm.GRID_W, gm.GRID_H)
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.update()
	_update_astar_solid()


func _update_astar_solid() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm == null or _astar == null: return
	for y: int in range(gm.GRID_H):
		for x: int in range(gm.GRID_W):
			var ct: int = gm.grid[y][x]
			var solid: bool = (ct != gm.CellType.EMPTY and ct != gm.CellType.TREE)
			_astar.set_point_solid(Vector2i(x, y), solid)


func rival_grow(rival_idx: int) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm == null: return
	var rival: Dictionary = rivals[rival_idx]
	var personality: String = rival["personality"]
	var cells: Array[Vector2i] = rival["cells"]
	var cell_type: int = rival["cell_type"]

	# Find candidates
	var candidates: Dictionary = {}
	var occupied: Dictionary = {}
	for c: Vector2i in cells: occupied[c] = true
	for c: Vector2i in cells:
		for d: Vector2i in gm.DIRS_8:
			var n: Vector2i = c + d
			if n.x >= 0 and n.x < gm.GRID_W and n.y >= 0 and n.y < gm.GRID_H:
				if not occupied.has(n) and gm.grid[n.y][n.x] == gm.CellType.EMPTY:
					candidates[n] = true

	if candidates.is_empty(): return

	# Score
	var best_score: float = -999.0
	var best_cell: Vector2i = candidates.keys()[0]

	for cand: Vector2i in candidates:
		var score: float = randf() * 2.0
		var grid_val: float = gm.grid_resources[cand.y][cand.x]

		match personality:
			"aggressive":
				for pc: Vector2i in gm.player_cells:
					score += 10.0 / (Vector2(cand).distance_to(Vector2(pc)) + 1.0)
				for tree: Dictionary in gm.trees:
					score += 8.0 / (Vector2(cand).distance_to(Vector2(tree["pos"])) + 1.0)
				score += grid_val * 5.0
			"defensive":
				var min_player_dist: float = 999.0
				for pc: Vector2i in gm.player_cells:
					min_player_dist = minf(min_player_dist, Vector2(cand).distance_to(Vector2(pc)))
				score += min_player_dist * 0.5
				var center: Vector2i = cells[0]
				score += Vector2(cand).distance_to(Vector2(center)) * 0.3
				score += grid_val * 3.0
			"opportunistic":
				score += grid_val * 12.0
				for dy: int in range(-3, 4):
					for dx: int in range(-3, 4):
						var sx: int = cand.x + dx
						var sy: int = cand.y + dy
						if sx >= 0 and sx < gm.GRID_W and sy >= 0 and sy < gm.GRID_H:
							if gm.grid_resources[sy][sx] > 0:
								score += 2.0 / (abs(dx) + abs(dy) + 1.0)

		if score > best_score:
			best_score = score
			best_cell = cand

	# Grow
	gm.grid[best_cell.y][best_cell.x] = cell_type
	cells.append(best_cell)
	rival["absorbed"] += 1

	gm._add_pulse(best_cell, rival["color"], "grow")

	if gm.grid_resources[best_cell.y][best_cell.x] > 0:
		gm.grid_resources[best_cell.y][best_cell.x] = 0.0
		gm.grid[best_cell.y][best_cell.x] = cell_type
		rival["gp"] += 3.0
		gm._add_pulse(best_cell, Color(1.0, 0.9, 0.2), "absorb")

	rival_intervals[rival_idx] = randf_range(RIVAL_INTERVAL_MIN, RIVAL_INTERVAL_MAX)
