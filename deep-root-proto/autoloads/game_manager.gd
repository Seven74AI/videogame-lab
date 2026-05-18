# ═══════════════════════════════════════════════════════════════
# GameManager — Autoload singleton
# Manages game state: grid, player, trees, growth, absorption,
# trade, animation state. Replaces the monolith main.gd state.
# ═══════════════════════════════════════════════════════════════
extends Node

# ── Constants ──────────────────────────────────────────────
enum CellType {
	EMPTY, WATER, MINERAL, SUGAR, TREE,
	MYCELIUM, RIVAL_RED, RIVAL_ORANGE, RIVAL_VIOLET
}

const GRID_W: int = 60
const GRID_H: int = 40
const CELL_SIZE: int = 24
const GROWTH_COST: float = 5.0
const BASE_GP_RATE: float = 0.3
const SUGAR_GP_BOOST: float = 0.07
const MAX_SUGAR_BOOST: float = 0.90
const RIVAL_INTERVAL_MIN: float = 6.0
const RIVAL_INTERVAL_MAX: float = 10.0
const TRADE_COOLDOWN: float = 4.0
const MAX_TRADES_PER_TREE: int = 6
const REGEN_INTERVAL: float = 60.0

const DIRS_4: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
]
const DIRS_8: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
]

const TRADE_RATES: Array[Dictionary] = [
	{"minerals": 2, "sugars": 1},
	{"minerals": 5, "sugars": 3},
	{"minerals": 10, "sugars": 7},
]

# ── Grid ───────────────────────────────────────────────────
var grid: Array[Array] = []
var grid_resources: Array[Array] = []

# ── Player ─────────────────────────────────────────────────
var player_cells: Array[Vector2i] = []
var player_gp: float = 10.0
var player_gp_rate: float = BASE_GP_RATE
var player_sugars: int = 0
var player_water: int = 0
var player_minerals: int = 0
var player_absorbed: int = 0
var player_growth_progress: float = 0.0

# ── Trees ──────────────────────────────────────────────────
var trees: Array[Dictionary] = []

# ── Animations ─────────────────────────────────────────────
var anim_pulses: Array[Dictionary] = []

# ── State ──────────────────────────────────────────────────
var seed_val: int = 0
var growth_candidates: Array[Vector2i] = []
var selected_tree_idx: int = -1
var message_text: String = ""
var message_timer: float = 0.0

# ── Signals ────────────────────────────────────────────────
signal state_changed
signal show_message(msg: String)
signal trade_completed(tree_idx: int, cost: int, gain: int)

# ═══════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════

func new_game() -> void:
	randomize()
	seed_val = randi()
	seed(seed_val)
	print("DEEP ROOT proto v3 — seed: ", seed_val)
	_init_grid()
	_place_resources()
	_place_trees()
	_place_player()
	message_text = "Seed: %d — Grow with arrow keys, trade with 1/2/3, reset: R" % seed_val
	state_changed.emit()


func _init_grid() -> void:
	grid.clear()
	grid_resources.clear()
	for y: int in range(GRID_H):
		var row: Array[int] = []
		var res_row: Array[float] = []
		for x: int in range(GRID_W):
			row.append(CellType.EMPTY)
			res_row.append(0.0)
		grid.append(row)
		grid_resources.append(res_row)


func _place_resources() -> void:
	_place_resource_clusters(CellType.WATER, 180, 8, 15)
	_place_resource_clusters(CellType.MINERAL, 100, 5, 12)
	_place_resource_clusters(CellType.SUGAR, 40, 2, 5)


func _place_resource_clusters(cell_type: CellType, total: int, cluster_min: int, cluster_max: int) -> void:
	var placed: int = 0
	while placed < total:
		var cx: int = randi() % GRID_W
		var cy: int = randi() % GRID_H
		var cluster_size: int = randi() % (cluster_max - cluster_min + 1) + cluster_min
		for _i: int in range(cluster_size):
			if placed >= total: break
			var x: int = cx + (randi() % 5) - 2
			var y: int = cy + (randi() % 5) - 2
			if x >= 0 and x < GRID_W and y >= 0 and y < GRID_H:
				if grid[y][x] == CellType.EMPTY:
					grid[y][x] = cell_type
					grid_resources[y][x] = 1.0
					placed += 1


func _place_trees() -> void:
	trees.clear()
	var tree_positions: Array[Vector2i] = [
		Vector2i(GRID_W / 2, GRID_H / 2),
		Vector2i(6, 4),
		Vector2i(GRID_W - 8, GRID_H - 6),
	]
	for tp: Vector2i in tree_positions:
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var tx: int = tp.x + dx
				var ty: int = tp.y + dy
				if tx >= 0 and tx < GRID_W and ty >= 0 and ty < GRID_H:
					grid[ty][tx] = CellType.TREE
		trees.append({
			"pos": tp,
			"trades_left": MAX_TRADES_PER_TREE,
			"cooldown": 0.0,
			"regen_timer": REGEN_INTERVAL,
		})


func _place_player() -> void:
	player_cells.clear()
	var sx: int = (GRID_W / 2) - 5
	var sy: int = (GRID_H / 2) + 3
	player_cells.append(Vector2i(sx, sy))
	grid[sy][sx] = CellType.MYCELIUM

# ═══════════════════════════════════════════════════════════════
# GROWTH
# ═══════════════════════════════════════════════════════════════

func update_growth_candidates() -> void:
	growth_candidates.clear()
	var occupied: Dictionary = {}
	for c: Vector2i in player_cells:
		occupied[c] = true
	for c: Vector2i in player_cells:
		for d: Vector2i in DIRS_8:
			var n: Vector2i = c + d
			if n.x >= 0 and n.x < GRID_W and n.y >= 0 and n.y < GRID_H:
				if not occupied.has(n) and grid[n.y][n.x] == CellType.EMPTY:
					growth_candidates.append(n)
					occupied[n] = true


func try_grow() -> void:
	if growth_candidates.is_empty():
		return
	var chosen: Vector2i = growth_candidates[randi() % growth_candidates.size()]
	_set_cell(chosen, CellType.MYCELIUM)
	player_cells.append(chosen)
	_add_pulse(chosen, Color(0.25, 0.75, 0.35), "grow")
	if grid_resources[chosen.y][chosen.x] > 0:
		_absorb_resource(chosen, true)


func try_player_grow_to(target: Vector2i) -> bool:
	if target.x < 0 or target.x >= GRID_W or target.y < 0 or target.y >= GRID_H:
		return false
	if grid[target.y][target.x] != CellType.EMPTY:
		return false
	var adjacent: bool = false
	for c: Vector2i in player_cells:
		var diff: Vector2i = target - c
		if abs(diff.x) <= 1 and abs(diff.y) <= 1 and diff != Vector2i.ZERO:
			adjacent = true
			break
	if not adjacent: return false
	if player_gp < GROWTH_COST: return false
	player_gp -= GROWTH_COST
	_set_cell(target, CellType.MYCELIUM)
	player_cells.append(target)
	_add_pulse(target, Color(0.25, 0.75, 0.35), "grow")
	if grid_resources[target.y][target.x] > 0:
		_absorb_resource(target, true)
	return true

# ═══════════════════════════════════════════════════════════════
# ABSORPTION
# ═══════════════════════════════════════════════════════════════

func _absorb_resource(cell: Vector2i, is_player: bool) -> void:
	var cell_type: int = grid[cell.y][cell.x]
	var amount: float = grid_resources[cell.y][cell.x]
	if amount <= 0: return
	grid_resources[cell.y][cell.x] = 0.0
	grid[cell.y][cell.x] = CellType.EMPTY

	_add_pulse(cell, Color(1.0, 0.9, 0.2), "absorb")

	if is_player:
		player_absorbed += 1
		match cell_type:
			CellType.WATER:
				player_water += 1
				player_gp += 2.0
			CellType.MINERAL:
				player_minerals += 1
				player_gp += 3.0
			CellType.SUGAR:
				player_sugars += 1
				player_gp += 1.0
				player_gp_rate = minf(BASE_GP_RATE + player_sugars * SUGAR_GP_BOOST, BASE_GP_RATE + MAX_SUGAR_BOOST)
		message_text = "Absorbed %s (%d total)" % [_cell_type_name(cell_type), player_absorbed]
		message_timer = 2.0
		state_changed.emit()

# ═══════════════════════════════════════════════════════════════
# TRADE
# ═══════════════════════════════════════════════════════════════

func trade(rate_idx: int) -> void:
	var tree: Dictionary = _find_trade_tree()
	if tree.is_empty():
		message_text = "No tree in range! Grow toward a tree."
		message_timer = 2.0
		return
	if tree["trades_left"] <= 0:
		message_text = "Tree depleted! All 6 trades used."
		message_timer = 2.0
		return
	if tree["cooldown"] > 0:
		message_text = "Tree cooling down... %.1fs" % tree["cooldown"]
		message_timer = 2.0
		return

	var rate: Dictionary = TRADE_RATES[rate_idx]
	var cost: int = rate["minerals"]
	var gain: int = rate["sugars"]

	if player_minerals < cost:
		message_text = "Need %d minerals (have %d)" % [cost, player_minerals]
		message_timer = 2.0
		return

	player_minerals -= cost
	player_sugars += gain
	player_gp_rate = minf(BASE_GP_RATE + player_sugars * SUGAR_GP_BOOST, BASE_GP_RATE + MAX_SUGAR_BOOST)
	tree["trades_left"] -= 1
	tree["cooldown"] = TRADE_COOLDOWN
	selected_tree_idx = trees.find(tree)

	message_text = "Trade OK: %d→%d sugars (%d trades left)" % [cost, gain, tree["trades_left"]]
	message_timer = 2.0
	trade_completed.emit(selected_tree_idx, cost, gain)

	_add_pulse(tree["pos"], Color(0.95, 0.80, 0.25), "trade")
	state_changed.emit()


func _find_trade_tree() -> Dictionary:
	var in_range: Array[Dictionary] = []
	for tree: Dictionary in trees:
		var tp: Vector2i = tree["pos"]
		for pc: Vector2i in player_cells:
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					var tx: int = tp.x + dx
					var ty: int = tp.y + dy
					if tx >= 0 and tx < GRID_W and ty >= 0 and ty < GRID_H:
						if Vector2(pc).distance_to(Vector2(tx, ty)) <= 1.5:
							in_range.append(tree)
							break
				if in_range.has(tree): break
			if in_range.has(tree): break

	if in_range.is_empty(): return {}
	if selected_tree_idx >= 0 and selected_tree_idx < trees.size():
		if in_range.has(trees[selected_tree_idx]):
			return trees[selected_tree_idx]

	var nearest: Dictionary = in_range[0]
	var nearest_dist: float = 999.0
	for tree: Dictionary in in_range:
		var tp: Vector2i = tree["pos"]
		for pc: Vector2i in player_cells:
			var d: float = Vector2(pc).distance_to(Vector2(tp))
			if d < nearest_dist:
				nearest_dist = d
				nearest = tree
	return nearest

# ═══════════════════════════════════════════════════════════════
# ANIMATIONS
# ═══════════════════════════════════════════════════════════════

func _add_pulse(pos: Vector2i, color: Color, type: String) -> void:
	anim_pulses.append({"pos": pos, "t": 0.0, "color": color, "type": type})


func update_animations(delta: float) -> void:
	var i: int = 0
	while i < anim_pulses.size():
		var a: Dictionary = anim_pulses[i]
		a["t"] += delta * 3.0
		if a["t"] >= 1.0:
			anim_pulses.remove_at(i)
		else:
			i += 1

# ═══════════════════════════════════════════════════════════════
# UTILITY
# ═══════════════════════════════════════════════════════════════

func _set_cell(cell: Vector2i, ct: CellType) -> void:
	grid[cell.y][cell.x] = ct


func get_cell(pos: Vector2i) -> int:
	if pos.x < 0 or pos.x >= GRID_W or pos.y < 0 or pos.y >= GRID_H:
		return -1
	return grid[pos.y][pos.x]


func screen_to_cell(screen_pos: Vector2) -> Vector2i:
	return Vector2i(int(screen_pos.x / CELL_SIZE), int(screen_pos.y / CELL_SIZE))


func player_center() -> Vector2i:
	if player_cells.is_empty():
		return Vector2i(GRID_W / 2, GRID_H / 2)
	var sx: int = 0; var sy: int = 0
	for c: Vector2i in player_cells:
		sx += c.x; sy += c.y
	return Vector2i(sx / player_cells.size(), sy / player_cells.size())


func _cell_type_name(ct: int) -> String:
	match ct:
		CellType.WATER: return "Water"
		CellType.MINERAL: return "Mineral"
		CellType.SUGAR: return "Sugar"
	return "?"


func reset() -> void:
	player_cells.clear()
	player_gp = 10.0
	player_gp_rate = BASE_GP_RATE
	player_sugars = 0
	player_water = 0
	player_minerals = 0
	player_absorbed = 0
	player_growth_progress = 0.0
	trees.clear()
	anim_pulses.clear()
	selected_tree_idx = -1
	growth_candidates.clear()
	state_changed.emit()
	new_game()
