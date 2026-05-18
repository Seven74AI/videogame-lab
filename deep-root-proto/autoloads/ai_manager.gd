# ═══════════════════════════════════════════════════════════════
# AIManager — Autoload singleton
# Manages 3 rival AIs with AStarGrid2D pathfinding
# Phase system: rivals cycle between 2-3 personality phases
# ═══════════════════════════════════════════════════════════════
extends Node

const RIVAL_INTERVAL_MIN: float = 6.0
const RIVAL_INTERVAL_MAX: float = 10.0

# ── Phase Configuration ───────────────────────────────────
const PHASE_CONFIGS: Dictionary = {
	"aggressive": {
		"phases": ["aggressive", "frenzy"],
		"phase_durations": [8.0, 5.0],
	},
	"defensive": {
		"phases": ["defensive", "fortify"],
		"phase_durations": [8.0, 5.0],
	},
	"opportunistic": {
		"phases": ["opportunistic", "harvest"],
		"phase_durations": [8.0, 5.0],
	},
}

const PHASE_MULTIPLIERS: Dictionary = {
	"aggressive": 1.0,
	"frenzy": 1.5,
	"defensive": 1.0,
	"fortify": 1.3,
	"opportunistic": 1.0,
	"harvest": 1.8,
}

const PHASE_PULSE_COLORS: Dictionary = {
	"frenzy": Color(1.0, 0.2, 0.1, 0.6),
	"fortify": Color(1.0, 0.65, 0.1, 0.6),
	"harvest": Color(0.75, 0.2, 1.0, 0.6),
}

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

		var personality: String = cfg["personality"]
		var phase_cfg: Dictionary = PHASE_CONFIGS.get(personality, {})
		var phase_names: Array = phase_cfg.get("phases", [personality])
		var phase_durations: Array = phase_cfg.get("phase_durations", [8.0])

		rivals.append({
			"personality": personality,
			"color": cfg["color"],
			"cell_type": cfg["cell_type"],
			"cells": cells,
			"gp": 10.0,
			"absorbed": 0,
			"phase": phase_names[0],
			"phase_idx": 0,
			"phase_timer": phase_durations[0],
		})

	for _i: int in range(3):
		rival_intervals.append(randf_range(RIVAL_INTERVAL_MIN, RIVAL_INTERVAL_MAX))
		rival_timers[_i] = rival_intervals[_i]

	_setup_astar()


func _setup_astar() -> void:
	_astar = AStarGrid2D.new()
	var gm = get_node_or_null("/root/GameManager")
	if gm == null: return
	# Godot 4.2+: region is the canonical API for AStarGrid2D size.
	# size property is deprecated — removed in 4.2.2+.
	_astar.region = Rect2i(0, 0, gm.GRID_W, gm.GRID_H)
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


# ═══════════════════════════════════════════════════════════════
# PHASE SYSTEM
# ═══════════════════════════════════════════════════════════════

func update_rival_phases(delta: float) -> void:
	for i: int in range(rivals.size()):
		var rival: Dictionary = rivals[i]
		rival["phase_timer"] -= delta
		if rival["phase_timer"] <= 0.0:
			_advance_phase(rival)


func _advance_phase(rival: Dictionary) -> void:
	var personality: String = rival["personality"]
	var phase_cfg: Dictionary = PHASE_CONFIGS.get(personality, {})
	var phase_names: Array = phase_cfg.get("phases", [personality])

	if phase_names.is_empty():
		return

	var new_idx: int = (rival["phase_idx"] + 1) % phase_names.size()
	var new_phase: String = phase_names[new_idx]
	var durations: Array = phase_cfg.get("phase_durations", [8.0])
	var new_duration: float = durations[new_idx] if new_idx < durations.size() else 8.0

	rival["phase_idx"] = new_idx
	rival["phase"] = new_phase
	rival["phase_timer"] = new_duration

	# Emit phase pulse on all rival cells on transition
	var gm = get_node_or_null("/root/GameManager")
	if gm == null: return

	var pulse_color: Color = get_phase_pulse_color(new_phase)
	if pulse_color.a > 0:
		for cell: Vector2i in rival["cells"]:
			gm._add_pulse(cell, pulse_color, "phase")


func get_phase_multiplier(phase: String) -> float:
	return PHASE_MULTIPLIERS.get(phase, 1.0)


func get_phase_pulse_color(phase: String) -> Color:
	return PHASE_PULSE_COLORS.get(phase, Color(0, 0, 0, 0))


# ═══════════════════════════════════════════════════════════════
# RIVAL GROWTH
# ═══════════════════════════════════════════════════════════════

func rival_grow(rival_idx: int) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm == null: return
	var rival: Dictionary = rivals[rival_idx]
	var personality: String = rival["personality"]
	var phase: String = rival["phase"]
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
	var phase_mult: float = get_phase_multiplier(phase)

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
				# Frenzy phase: amplify aggression scoring
				score *= phase_mult
			"defensive":
				var min_player_dist: float = 999.0
				for pc: Vector2i in gm.player_cells:
					min_player_dist = minf(min_player_dist, Vector2(cand).distance_to(Vector2(pc)))
				score += min_player_dist * 0.5
				var center: Vector2i = cells[0]
				score += Vector2(cand).distance_to(Vector2(center)) * 0.3
				score += grid_val * 3.0
				# Fortify phase: amplify defensive distance scoring
				score *= phase_mult
			"opportunistic":
				score += grid_val * 12.0
				for dy: int in range(-3, 4):
					for dx: int in range(-3, 4):
						var sx: int = cand.x + dx
						var sy: int = cand.y + dy
						if sx >= 0 and sx < gm.GRID_W and sy >= 0 and sy < gm.GRID_H:
							if gm.grid_resources[sy][sx] > 0:
								score += 2.0 / (abs(dx) + abs(dy) + 1.0)
				# Harvest phase: amplify resource scoring
				score *= phase_mult

		if score > best_score:
			best_score = score
			best_cell = cand

	# Grow
	gm.grid[best_cell.y][best_cell.x] = cell_type
	cells.append(best_cell)
	rival["absorbed"] += 1

	# Use phase pulse color if in special phase, else default
	var grow_color: Color = get_phase_pulse_color(phase)
	if grow_color.a <= 0:
		grow_color = rival["color"]
	gm._add_pulse(best_cell, grow_color, "grow")

	if gm.grid_resources[best_cell.y][best_cell.x] > 0:
		gm.grid_resources[best_cell.y][best_cell.x] = 0.0
		gm.grid[best_cell.y][best_cell.x] = cell_type
		rival["gp"] += 3.0
		gm._add_pulse(best_cell, Color(1.0, 0.9, 0.2), "absorb")

	rival_intervals[rival_idx] = randf_range(RIVAL_INTERVAL_MIN, RIVAL_INTERVAL_MAX)
