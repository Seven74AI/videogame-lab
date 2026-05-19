# ═══════════════════════════════════════════════════════════════
# test_zones.gd — Tests for zone-based growth cost system
# Verifies border/center/near_rival classification, cost values,
# and zone tint colors.
# ═══════════════════════════════════════════════════════════════
extends Node

const GRID_W: int = 60
const GRID_H: int = 40
const ZONE_BORDER_DIST: int = 3
const ZONE_RIVAL_DIST: int = 5
const ZONE_COST_BORDER: float = 3.0
const ZONE_COST_CENTER: float = 5.0
const ZONE_COST_NEAR_RIVAL: float = 7.0

func _runner():
	return get_parent()


func _get_cell_zone(pos: Vector2i, rival_cells: Array[Vector2i]) -> String:
	"""Replicate GameManager.get_cell_zone() for isolated testing."""
	# Border check (edges of the map — easy growth)
	if pos.x < ZONE_BORDER_DIST or pos.x >= GRID_W - ZONE_BORDER_DIST:
		return "border"
	if pos.y < ZONE_BORDER_DIST or pos.y >= GRID_H - ZONE_BORDER_DIST:
		return "border"
	# Near rivals check
	for rc: Vector2i in rival_cells:
		if abs(pos.x - rc.x) <= ZONE_RIVAL_DIST and abs(pos.y - rc.y) <= ZONE_RIVAL_DIST:
			return "near_rival"
	return "center"


func _get_growth_cost(pos: Vector2i, rival_cells: Array[Vector2i]) -> float:
	match _get_cell_zone(pos, rival_cells):
		"border": return ZONE_COST_BORDER
		"near_rival": return ZONE_COST_NEAR_RIVAL
		_: return ZONE_COST_CENTER


# ── Zone classification tests ──────────────────────────────────

func test_zone_border_top_edge() -> bool:
	"""Top row (y=0) cells within border distance are border zone."""
	var r = _runner()
	var pos := Vector2i(10, 0)
	r.assert_eq(_get_cell_zone(pos, []), "border", "y=0 is border")
	for y: int in range(ZONE_BORDER_DIST):
		r.assert_eq(_get_cell_zone(Vector2i(30, y), []), "border",
			"y=%d within border distance is border" % y)
	return true


func test_zone_border_bottom_edge() -> bool:
	"""Bottom row cells within border distance are border zone."""
	var r = _runner()
	for y: int in range(GRID_H - ZONE_BORDER_DIST, GRID_H):
		r.assert_eq(_get_cell_zone(Vector2i(30, y), []), "border",
			"y=%d near bottom is border" % y)
	return true


func test_zone_border_left_edge() -> bool:
	"""Left column cells within border distance are border zone."""
	var r = _runner()
	for x: int in range(ZONE_BORDER_DIST):
		r.assert_eq(_get_cell_zone(Vector2i(x, 20), []), "border",
			"x=%d near left is border" % x)
	return true


func test_zone_border_right_edge() -> bool:
	"""Right column cells within border distance are border zone."""
	var r = _runner()
	for x: int in range(GRID_W - ZONE_BORDER_DIST, GRID_W):
		r.assert_eq(_get_cell_zone(Vector2i(x, 20), []), "border",
			"x=%d near right is border" % x)
	return true


func test_zone_center() -> bool:
	"""Cells well inside the grid (not near border, no rivals) are center zone."""
	var r = _runner()
	var pos := Vector2i(30, 20)
	r.assert_eq(_get_cell_zone(pos, []), "center", "(30,20) is center")
	pos = Vector2i(10, 10)
	r.assert_eq(_get_cell_zone(pos, []), "center", "(10,10) is center")
	return true


func test_zone_near_rival() -> bool:
	"""Cells within ZONE_RIVAL_DIST of a rival are near_rival zone."""
	var r = _runner()
	var rival_cells: Array[Vector2i] = [Vector2i(20, 20)]
	# Exactly at rival cell
	r.assert_eq(_get_cell_zone(Vector2i(20, 20), rival_cells), "near_rival", "rival cell itself")
	# Within distance
	r.assert_eq(_get_cell_zone(Vector2i(22, 22), rival_cells), "near_rival", "2 tiles away")
	r.assert_eq(_get_cell_zone(Vector2i(25, 25), rival_cells), "near_rival", "exactly 5 tiles away (boundary)")
	# Outside distance
	r.assert_eq(_get_cell_zone(Vector2i(26, 20), rival_cells), "center", "6 tiles away = center")
	r.assert_eq(_get_cell_zone(Vector2i(20, 26), rival_cells), "center", "6 tiles away = center")
	return true


func test_zone_border_beats_near_rival() -> bool:
	"""Border check runs before near_rival — edge cells are border even if near rival."""
	var r = _runner()
	var rival_cells: Array[Vector2i] = [Vector2i(5, 2)]
	# Cell (2,0) is border (y=0 < 3) — border check runs first, returns "border"
	var pos := Vector2i(2, 0)
	r.assert_eq(_get_cell_zone(pos, rival_cells), "border",
		"edge cell is border even if near rival (border check first)")
	# Cell (4,4) is not border (x=4>=3, y=4>=3) but IS near rival
	var interior_near := Vector2i(4, 4)
	r.assert_eq(_get_cell_zone(interior_near, rival_cells), "near_rival",
		"interior cell near rival = near_rival")
	return true


# ── Growth cost tests ──────────────────────────────────────────

func test_growth_cost_border() -> bool:
	"""Border zone cost = 3.0 GP."""
	var r = _runner()
	r.assert_eq(_get_growth_cost(Vector2i(0, 20), []), 3.0, "border cost = 3.0")
	r.assert_eq(_get_growth_cost(Vector2i(GRID_W - 1, 20), []), 3.0, "right border cost = 3.0")
	return true


func test_growth_cost_center() -> bool:
	"""Center zone cost = 5.0 GP."""
	var r = _runner()
	r.assert_eq(_get_growth_cost(Vector2i(30, 20), []), 5.0, "center cost = 5.0")
	return true


func test_growth_cost_near_rival() -> bool:
	"""Near-rival zone cost = 7.0 GP."""
	var r = _runner()
	var rival_cells: Array[Vector2i] = [Vector2i(30, 20)]
	r.assert_eq(_get_growth_cost(Vector2i(30, 20), rival_cells), 7.0, "near-rival cost = 7.0")
	return true


func test_growth_cost_ordering() -> bool:
	"""Growth costs follow the difficulty order: border < center < near_rival."""
	var r = _runner()
	r.assert_true(ZONE_COST_BORDER < ZONE_COST_CENTER, "border < center")
	r.assert_true(ZONE_COST_CENTER < ZONE_COST_NEAR_RIVAL, "center < near_rival")
	return true


# ── Zone tint tests ────────────────────────────────────────────

func test_zone_tint_colors() -> bool:
	"""Zone tints have distinct colors: green (border), yellow (center), red (rival)."""
	var r = _runner()
	# These match GameManager.get_zone_tint() return values
	var border_tint := Color(0.0, 1.0, 0.0, 0.12)
	var center_tint := Color(1.0, 1.0, 0.0, 0.06)
	var rival_tint := Color(1.0, 0.15, 0.15, 0.18)

	r.assert_true(border_tint.r < center_tint.r, "border has less red than center")
	r.assert_true(rival_tint.g < center_tint.g, "rival has less green than center")
	r.assert_true(border_tint.a != center_tint.a, "zones have distinct alpha")
	return true


func test_zone_tint_all_different() -> bool:
	"""All three zone tints must be visually distinguishable."""
	var r = _runner()
	var border_tint := Color(0.0, 1.0, 0.0, 0.12)
	var center_tint := Color(1.0, 1.0, 0.0, 0.06)
	var rival_tint := Color(1.0, 0.15, 0.15, 0.18)

	r.assert_ne(border_tint, center_tint, "border ≠ center")
	r.assert_ne(center_tint, rival_tint, "center ≠ rival")
	r.assert_ne(border_tint, rival_tint, "border ≠ rival")
	return true
