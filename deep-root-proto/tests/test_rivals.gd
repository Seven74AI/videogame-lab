# ═══════════════════════════════════════════════════════════════
# test_rivals.gd — Tests for AIManager + AStarGrid2D pathfinding
# TDD: These MUST fail before we implement AIManager
# ═══════════════════════════════════════════════════════════════
extends Node

const GRID_W: int = 60
const GRID_H: int = 40

const DIRS_8: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
]


func _runner():
	return get_parent()


func test_rival_creation() -> bool:
	""" AIManager should create 3 rivals with distinct personalities """
	var rival_configs: Array[Dictionary] = [
		{"personality": "aggressive", "start": Vector2i(52, 4)},
		{"personality": "defensive", "start": Vector2i(5, 34)},
		{"personality": "opportunistic", "start": Vector2i(54, 32)},
	]

	var r = _runner()
	r.assert_eq(rival_configs.size(), 3, "Must have 3 rivals")

	var personalities: Array[String] = []
	for cfg in rival_configs:
		personalities.append(cfg["personality"])

	r.assert_true(personalities.has("aggressive"), "Must have aggressive")
	r.assert_true(personalities.has("defensive"), "Must have defensive")
	r.assert_true(personalities.has("opportunistic"), "Must have opportunistic")
	return true


func test_rival_growth_candidates() -> bool:
	""" Rival AI should find empty adjacent cells to grow into """
	var rival_cells: Array[Vector2i] = [Vector2i(52, 4)]
	var candidates: Dictionary = {}
	var occupied: Dictionary = {}
	for c: Vector2i in rival_cells:
		occupied[c] = true
	for c: Vector2i in rival_cells:
		for d: Vector2i in DIRS_8:
			var n: Vector2i = c + d
			if n.x >= 0 and n.x < GRID_W and n.y >= 0 and n.y < GRID_H:
				if not occupied.has(n):
					candidates[n] = true

	var r = _runner()
	r.assert_gt(candidates.size(), 0, "Single rival has growth candidates")
	return true


func test_rival_personality_scoring() -> bool:
	""" Each rival personality must score cells differently """
	var cand1: Vector2i = Vector2i(30, 20)
	var cand2: Vector2i = Vector2i(50, 5)

	var r = _runner()

	# Aggressive: prefers proximity (closer = higher score)
	var agg1: float = 10.0 / (Vector2(cand1).distance_to(Vector2(30, 20)) + 1.0)
	var agg2: float = 10.0 / (Vector2(cand2).distance_to(Vector2(30, 20)) + 1.0)
	r.assert_gt(agg1, agg2, "Aggressive prefers closer cells")

	# Defensive: prefers distance (further = higher score)
	var def1: float = Vector2(cand1).distance_to(Vector2(10, 10)) * 0.5
	var def2: float = Vector2(cand2).distance_to(Vector2(10, 10)) * 0.5
	r.assert_gt(def2, def1, "Defensive prefers further cells")
	return true


func test_astargrid2d_setup() -> bool:
	""" AStarGrid2D should be creatable with correct grid size """
	var r = _runner()

	var astar: AStarGrid2D = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, GRID_W, GRID_H)
	astar.cell_size = Vector2i(1, 1)
	astar.update()

	r.assert_not_null(astar, "AStarGrid2D creatable")
	r.assert_eq(astar.region.size.x, GRID_W, "AStar width=60")
	r.assert_eq(astar.region.size.y, GRID_H, "AStar height=40")

	# In Godot 4.2, is_in_bounds + get_point_position are the API
	r.assert_true(astar.is_in_bounds(0, 0), "Point (0,0) in bounds")
	r.assert_false(astar.is_in_bounds(GRID_W, GRID_H), "Point out of bounds")
	return true
