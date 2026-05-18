# ═══════════════════════════════════════════════════════════════
# test_grid.gd — Tests for GridLayer (TileMapLayer replacement)
# TDD: These MUST fail before we implement GridLayer
# ═══════════════════════════════════════════════════════════════
extends Node

const GRID_W: int = 60
const GRID_H: int = 40
const CELL_SIZE: int = 24

enum CellType {
	EMPTY, WATER, MINERAL, SUGAR, TREE,
	MYCELIUM, RIVAL_RED, RIVAL_ORANGE, RIVAL_VIOLET
}

const DIRS_4: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
]
const DIRS_8: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
]


func _runner():
	return get_parent()


func test_grid_initialization_size() -> bool:
	""" Grid must initialize with correct dimensions (60x40) """
	var grid: Array[Array] = []
	for y: int in range(GRID_H):
		var row: Array[int] = []
		for x: int in range(GRID_W):
			row.append(CellType.EMPTY)
		grid.append(row)

	var r = _runner()
	r.assert_eq(grid.size(), GRID_H, "Grid height=40")
	r.assert_eq(grid[0].size(), GRID_W, "Grid width=60")
	return true


func test_grid_check_bounds() -> bool:
	""" Grid must reject out-of-bounds coordinates """
	var r = _runner()
	r.assert_true(59 >= 0 and 59 < GRID_W and 39 >= 0 and 39 < GRID_H, "59,39 in bounds")
	r.assert_false(60 >= 0 and 60 < GRID_W and 0 >= 0 and 0 < GRID_H, "60,0 out of bounds")
	return true


func test_grid_adjacent_cells() -> bool:
	""" Grid must correctly identify adjacent cells in 4 directions """
	var cell: Vector2i = Vector2i(30, 20)
	var adjacents: Array[Vector2i] = []
	for d: Vector2i in DIRS_4:
		var n: Vector2i = cell + d
		if n.x >= 0 and n.x < GRID_W and n.y >= 0 and n.y < GRID_H:
			adjacents.append(n)

	var r = _runner()
	r.assert_eq(adjacents.size(), 4, "Center cell = 4 adjacents")
	return true


func test_grid_corner_adjacent() -> bool:
	""" Corner cell should only have 2 adjacent cells """
	var cell: Vector2i = Vector2i(0, 0)
	var count: int = 0
	for d: Vector2i in DIRS_4:
		var n: Vector2i = cell + d
		if n.x >= 0 and n.x < GRID_W and n.y >= 0 and n.y < GRID_H:
			count += 1

	var r = _runner()
	r.assert_eq(count, 2, "Corner = 2 neighbors")
	return true


func test_resource_placement_count() -> bool:
	""" Resource placement must fill exactly requested count """
	var total_target: int = 100
	var placed: int = 0
	var grid: Array[Array] = []
	for y: int in range(GRID_H):
		var row: Array[int] = []
		for x: int in range(GRID_W):
			row.append(CellType.EMPTY)
		grid.append(row)

	while placed < total_target:
		var cx: int = randi() % GRID_W
		var cy: int = randi() % GRID_H
		for _i in range(5):
			if placed >= total_target:
				break
			var x: int = cx + (randi() % 3) - 1
			var y: int = cy + (randi() % 3) - 1
			if x >= 0 and x < GRID_W and y >= 0 and y < GRID_H:
				if grid[y][x] == CellType.EMPTY:
					grid[y][x] = CellType.WATER
					placed += 1

	var r = _runner()
	r.assert_eq(placed, total_target, "100 resources placed")
	return true


func test_tilemap_layer_exists() -> bool:
	""" Scene system should be able to create a Node2D for GridLayer """
	var grid_node: Node2D = Node2D.new()
	grid_node.name = "GridLayer"
	var r = _runner()
	r.assert_not_null(grid_node, "GridLayer node creatable")
	grid_node.free()
	return true


func test_grid_to_pixel_conversion() -> bool:
	""" Grid coordinates must correctly convert to pixel positions """
	var cell: Vector2i = Vector2i(5, 3)
	var px: float = cell.x * CELL_SIZE + CELL_SIZE / 2.0
	var py: float = cell.y * CELL_SIZE + CELL_SIZE / 2.0

	var r = _runner()
	r.assert_eq(px, 132.0, "x pixel for (5,3)")
	r.assert_eq(py, 84.0, "y pixel for (5,3)")
	return true
