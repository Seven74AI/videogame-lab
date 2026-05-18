extends Node2D

# ═══════════════════════════════════════════════════════════════
# DEEP ROOT — Proto v2
# Mycelium core loop: expand, absorb, trade, compete
# ═══════════════════════════════════════════════════════════════

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

# Colors — ugly and minimal as required
const COLOR_EMPTY: Color     = Color(0.10, 0.10, 0.13)
const COLOR_WATER: Color     = Color(0.18, 0.38, 0.85)
const COLOR_MINERAL: Color   = Color(0.65, 0.55, 0.25)
const COLOR_SUGAR: Color     = Color(0.95, 0.80, 0.25)
const COLOR_TREE: Color      = Color(0.15, 0.50, 0.15)
const COLOR_MYCELIUM: Color  = Color(0.25, 0.75, 0.35)
const COLOR_RIVAL_RED: Color = Color(0.88, 0.18, 0.18)
const COLOR_RIVAL_ORANGE: Color = Color(0.92, 0.55, 0.08)
const COLOR_RIVAL_VIOLET: Color = Color(0.65, 0.18, 0.85)
const COLOR_CONNECTION: Color = Color(0.20, 0.60, 0.30, 0.4)
const COLOR_GRID_LINE: Color = Color(0.18, 0.18, 0.22)
const COLOR_HOVER: Color     = Color(1.0, 1.0, 1.0, 0.15)
const COLOR_GROW_HIGHLIGHT: Color = Color(0.3, 1.0, 0.3, 0.25)
const COLOR_UI_BG: Color     = Color(0.0, 0.0, 0.0, 0.7)
const COLOR_UI_TEXT: Color   = Color(0.9, 0.9, 0.9)

# ── Grid ───────────────────────────────────────────────────
var grid: Array[Array] = []          # [y][x] = CellType
var grid_resources: Array[Array] = [] # [y][x] = float (amount for minerals/water)

# ── Player ─────────────────────────────────────────────────
var player_cells: Array[Vector2i] = []
var player_gp: float = 10.0
var player_gp_rate: float = BASE_GP_RATE
var player_sugars: int = 0
var player_water: int = 0
var player_minerals: int = 0
var player_absorbed: int = 0
var player_growth_progress: float = 0.0

# ── Rivals (3) ─────────────────────────────────────────────
var rivals: Array[Dictionary] = []
var rival_timers: Array[float] = [0.0, 0.0, 0.0]
var rival_intervals: Array[float] = []

# ── Trees (3) ──────────────────────────────────────────────
var trees: Array[Dictionary] = []

# ── Animations ─────────────────────────────────────────────
var anim_pulses: Array[Dictionary] = []      # {pos, type, t, color}
var anim_absorbs: Array[Dictionary] = []     # {pos, t}
var anim_connections: Array[PackedVector2Array] = []

# ── Input / UI ─────────────────────────────────────────────
var mouse_pos: Vector2 = Vector2.ZERO
var hover_cell: Vector2i = Vector2i(-1, -1)
var selected_tree_idx: int = -1
var growth_candidates: Array[Vector2i] = []
var message_text: String = ""
var message_timer: float = 0.0
var seed_val: int = 0


# ═══════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	randomize()
	seed_val = randi()
	seed(seed_val)
	print("DEEP ROOT proto v2 — seed: ", seed_val)
	_init_grid()
	_place_resources()
	_place_trees()
	_place_player()
	_place_rivals()
	_setup_rival_timers()
	message_text = "Seed: %d — Grow with arrow keys, trade with 1/2/3, reset: R" % seed_val


func _process(delta: float) -> void:
	# GP accrual
	player_gp += player_gp_rate * delta

	# Growth
	player_growth_progress += player_gp_rate * delta
	if player_growth_progress >= GROWTH_COST:
		player_growth_progress -= GROWTH_COST
		if not growth_candidates.is_empty():
			_try_grow()

	# Rival AI ticks
	for i: int in range(3):
		rival_timers[i] -= delta
		if rival_timers[i] <= 0.0:
			_rival_grow(i)
			rival_timers[i] = rival_intervals[i]

	# Animations
	_update_animations(delta)

	# Tree cooldowns
	for tree: Dictionary in trees:
		if tree["cooldown"] > 0:
			tree["cooldown"] -= delta

	# Message timer
	if message_timer > 0:
		message_timer -= delta

	# Mouse hover
	_update_hover()

	# Growth candidates (adjacent to player, not occupied)
	_update_growth_candidates()

	queue_redraw()


# ═══════════════════════════════════════════════════════════════
# INIT
# ═══════════════════════════════════════════════════════════════

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
	# Water: ~180 cells (common)
	_place_resource_clusters(CellType.WATER, 180, 8, 15)
	# Minerals: ~100 cells (medium)
	_place_resource_clusters(CellType.MINERAL, 100, 5, 12)
	# Sugars: ~40 cells (rare, scattered)
	_place_resource_clusters(CellType.SUGAR, 40, 2, 5)


func _place_resource_clusters(cell_type: CellType, total: int, cluster_min: int, cluster_max: int) -> void:
	var placed: int = 0
	while placed < total:
		var cx: int = randi() % GRID_W
		var cy: int = randi() % GRID_H
		var cluster_size: int = randi() % (cluster_max - cluster_min + 1) + cluster_min
		for _i: int in range(cluster_size):
			if placed >= total:
				break
			var x: int = cx + (randi() % 5) - 2
			var y: int = cy + (randi() % 5) - 2
			if x >= 0 and x < GRID_W and y >= 0 and y < GRID_H:
				if grid[y][x] == CellType.EMPTY:
					grid[y][x] = cell_type
					grid_resources[y][x] = 1.0
					placed += 1


func _place_trees() -> void:
	trees.clear()
	# 3 tree positions — center + 2 peripheral
	var tree_positions: Array[Vector2i] = [
		Vector2i(GRID_W / 2, GRID_H / 2),      # center
		Vector2i(6, 4),                           # top-left peripheral
		Vector2i(GRID_W - 8, GRID_H - 6),        # bottom-right peripheral
	]
	for tp: Vector2i in tree_positions:
		# Place 2×2 tree blocks, protect 3×3 zone
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var tx: int = tp.x + dx
				var ty: int = tp.y + dy
				if tx >= 0 and tx < GRID_W and ty >= 0 and ty < GRID_H:
					if abs(dx) <= 1 and abs(dy) <= 1:
						grid[ty][tx] = CellType.TREE
		trees.append({
			"pos": tp,
			"trades_left": MAX_TRADES_PER_TREE,
			"cooldown": 0.0,
		})


func _place_player() -> void:
	player_cells.clear()
	# Start near center, offset from center tree
	var sx: int = (GRID_W / 2) - 5
	var sy: int = (GRID_H / 2) + 3
	player_cells.append(Vector2i(sx, sy))
	grid[sy][sx] = CellType.MYCELIUM


func _place_rivals() -> void:
	rivals.clear()
	var rival_configs: Array[Dictionary] = [
		{
			"personality": "aggressive",
			"color": COLOR_RIVAL_RED,
			"cell_type": CellType.RIVAL_RED,
			"start": Vector2i(GRID_W - 8, 4),
		},
		{
			"personality": "defensive",
			"color": COLOR_RIVAL_ORANGE,
			"cell_type": CellType.RIVAL_ORANGE,
			"start": Vector2i(5, GRID_H - 6),
		},
		{
			"personality": "opportunistic",
			"color": COLOR_RIVAL_VIOLET,
			"cell_type": CellType.RIVAL_VIOLET,
			"start": Vector2i(GRID_W - 6, GRID_H - 8),
		},
	]
	for cfg: Dictionary in rival_configs:
		var cells: Array[Vector2i] = [cfg["start"]]
		grid[cfg["start"].y][cfg["start"].x] = cfg["cell_type"]
		rivals.append({
			"personality": cfg["personality"],
			"color": cfg["color"],
			"cell_type": cfg["cell_type"],
			"cells": cells,
			"gp": 10.0,
			"gp_rate": BASE_GP_RATE,
			"sugars": 0,
			"absorbed": 0,
			"growth_progress": 0.0,
		})


func _setup_rival_timers() -> void:
	rival_intervals.clear()
	for _i: int in range(3):
		rival_intervals.append(randf_range(RIVAL_INTERVAL_MIN, RIVAL_INTERVAL_MAX))
		rival_timers[_i] = rival_intervals[_i]


# ═══════════════════════════════════════════════════════════════
# PLAYER GROWTH
# ═══════════════════════════════════════════════════════════════

func _update_growth_candidates() -> void:
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


func _try_grow() -> void:
	if growth_candidates.is_empty():
		return
	var chosen: Vector2i = growth_candidates[randi() % growth_candidates.size()]
	grid[chosen.y][chosen.x] = CellType.MYCELIUM
	player_cells.append(chosen)
	anim_pulses.append({
		"pos": chosen,
		"t": 0.0,
		"color": COLOR_MYCELIUM,
		"type": "grow",
	})
	# Absorb if resource present
	var cell_val: float = grid_resources[chosen.y][chosen.x]
	if cell_val > 0:
		_absorb_resource(chosen, true)


func _try_player_grow_to(target: Vector2i) -> bool:
	if target.x < 0 or target.x >= GRID_W or target.y < 0 or target.y >= GRID_H:
		return false
	if grid[target.y][target.x] != CellType.EMPTY:
		return false
	# Check adjacency
	var adjacent: bool = false
	for c: Vector2i in player_cells:
		var diff: Vector2i = target - c
		if abs(diff.x) <= 1 and abs(diff.y) <= 1 and diff != Vector2i.ZERO:
			adjacent = true
			break
	if not adjacent:
		return false
	if player_gp < GROWTH_COST:
		return false
	player_gp -= GROWTH_COST
	grid[target.y][target.x] = CellType.MYCELIUM
	player_cells.append(target)
	anim_pulses.append({
		"pos": target,
		"t": 0.0,
		"color": COLOR_MYCELIUM,
		"type": "grow",
	})
	if grid_resources[target.y][target.x] > 0:
		_absorb_resource(target, true)
	return true


# ═══════════════════════════════════════════════════════════════
# ABSORPTION
# ═══════════════════════════════════════════════════════════════

func _absorb_resource(cell: Vector2i, is_player: bool) -> void:
	var cell_type: int = grid[cell.y][cell.x]
	var amount: float = grid_resources[cell.y][cell.x]
	if amount <= 0:
		return
	grid_resources[cell.y][cell.x] = 0.0
	grid[cell.y][cell.x] = CellType.EMPTY

	anim_pulses.append({
		"pos": cell,
		"t": 0.0,
		"color": Color(1.0, 0.9, 0.2),
		"type": "absorb",
	})

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
	else:
		# Rival absorption — handled by the rival that grew here; simplified
		# Rivals get flat GP boost
		pass


func _cell_type_name(ct: int) -> String:
	match ct:
		CellType.WATER: return "Water"
		CellType.MINERAL: return "Mineral"
		CellType.SUGAR: return "Sugar"
	return "?"


# ═══════════════════════════════════════════════════════════════
# RIVAL AI
# ═══════════════════════════════════════════════════════════════

func _rival_grow(rival_idx: int) -> void:
	var rival: Dictionary = rivals[rival_idx]
	var personality: String = rival["personality"]
	var cells: Array[Vector2i] = rival["cells"]
	var cell_type: int = rival["cell_type"]

	# Find all adjacent empty cells
	var candidates: Dictionary = {}  # Vector2i -> bool
	var occupied: Dictionary = {}
	for c: Vector2i in cells:
		occupied[c] = true
	for c: Vector2i in cells:
		for d: Vector2i in DIRS_8:
			var n: Vector2i = c + d
			if n.x >= 0 and n.x < GRID_W and n.y >= 0 and n.y < GRID_H:
				if not occupied.has(n) and grid[n.y][n.x] == CellType.EMPTY:
					candidates[n] = true

	if candidates.is_empty():
		return

	# Score each candidate based on personality
	var best_score: float = -999.0
	var best_cell: Vector2i = candidates.keys()[0]

	for cand: Vector2i in candidates:
		var score: float = randf() * 2.0  # base noise
		var grid_val: float = grid_resources[cand.y][cand.x]

		match personality:
			"aggressive":
				# Prefer cells near player mycelium or trees
				for pc: Vector2i in player_cells:
					var dist: float = Vector2(cand).distance_to(Vector2(pc))
					score += 10.0 / (dist + 1.0)
				for tree: Dictionary in trees:
					var tp: Vector2i = tree["pos"]
					var dist: float = Vector2(cand).distance_to(Vector2(tp))
					score += 8.0 / (dist + 1.0)
				score += grid_val * 5.0
			"defensive":
				# Maximize territory: prefer cells far from player and other rivals
				var min_player_dist: float = 999.0
				for pc: Vector2i in player_cells:
					min_player_dist = minf(min_player_dist, Vector2(cand).distance_to(Vector2(pc)))
				score += min_player_dist * 0.5
				# Prefer spreading out from own center
				var center: Vector2i = cells[0]
				score += Vector2(cand).distance_to(Vector2(center)) * 0.3
				score += grid_val * 3.0
			"opportunistic":
				# Heavy sugar preference
				score += grid_val * 12.0
				# Also drawn to nearby resources
				for dy: int in range(-3, 4):
					for dx: int in range(-3, 4):
						var sx: int = cand.x + dx
						var sy: int = cand.y + dy
						if sx >= 0 and sx < GRID_W and sy >= 0 and sy < GRID_H:
							if grid_resources[sy][sx] > 0:
								score += 2.0 / (abs(dx) + abs(dy) + 1.0)

		if score > best_score:
			best_score = score
			best_cell = cand

	# Grow
	grid[best_cell.y][best_cell.x] = cell_type
	cells.append(best_cell)
	rival["absorbed"] += 1

	anim_pulses.append({
		"pos": best_cell,
		"t": 0.0,
		"color": rival["color"],
		"type": "grow",
	})

	# Absorb resource if present
	if grid_resources[best_cell.y][best_cell.x] > 0:
		grid_resources[best_cell.y][best_cell.x] = 0.0
		grid[best_cell.y][best_cell.x] = cell_type
		rival["gp"] += 3.0
		anim_pulses.append({
			"pos": best_cell,
			"t": 0.0,
			"color": Color(1.0, 0.9, 0.2),
			"type": "absorb",
		})

	# Randomize next interval
	rival_intervals[rival_idx] = randf_range(RIVAL_INTERVAL_MIN, RIVAL_INTERVAL_MAX)


# ═══════════════════════════════════════════════════════════════
# TREE TRADE
# ═══════════════════════════════════════════════════════════════

func _trade(rate_idx: int) -> void:
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

	anim_pulses.append({
		"pos": tree["pos"],
		"t": 0.0,
		"color": COLOR_SUGAR,
		"type": "trade",
	})


func _find_trade_tree() -> Dictionary:
	# Priority: selected tree if in range, then nearest tree in range
	var in_range: Array[Dictionary] = []
	for tree: Dictionary in trees:
		var tp: Vector2i = tree["pos"]
		# Check if any player cell is adjacent to tree's 3×3 zone
		for pc: Vector2i in player_cells:
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					var tx: int = tp.x + dx
					var ty: int = tp.y + dy
					if tx >= 0 and tx < GRID_W and ty >= 0 and ty < GRID_H:
						if Vector2(pc).distance_to(Vector2(tx, ty)) <= 1.5:
							in_range.append(tree)
							break
				if in_range.has(tree):
					break
			if in_range.has(tree):
				break

	if in_range.is_empty():
		return {}

	# Prefer selected tree if it's in range
	if selected_tree_idx >= 0 and selected_tree_idx < trees.size():
		if in_range.has(trees[selected_tree_idx]):
			return trees[selected_tree_idx]

	# Nearest tree
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

func _update_animations(delta: float) -> void:
	# Pulses
	var i: int = 0
	while i < anim_pulses.size():
		var a: Dictionary = anim_pulses[i]
		a["t"] += delta * 3.0
		if a["t"] >= 1.0:
			anim_pulses.remove_at(i)
		else:
			i += 1

	# Absorbs
	i = 0
	while i < anim_absorbs.size():
		var a: Dictionary = anim_absorbs[i]
		a["t"] += delta * 2.0
		if a["t"] >= 1.0:
			anim_absorbs.remove_at(i)
		else:
			i += 1


# ═══════════════════════════════════════════════════════════════
# INPUT
# ═══════════════════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_pos = event.position

	if event is InputEventMouseButton and event.pressed:
		var cell: Vector2i = _screen_to_cell(event.position)
		if cell.x >= 0 and cell.x < GRID_W and cell.y >= 0 and cell.y < GRID_H:
			var ct: int = grid[cell.y][cell.x]
			if ct == CellType.TREE:
				for ti: int in range(trees.size()):
					var tp: Vector2i = trees[ti]["pos"]
					if abs(cell.x - tp.x) <= 1 and abs(cell.y - tp.y) <= 1:
						selected_tree_idx = ti
						message_text = "Tree %d selected (%d trades left)" % [ti + 1, trees[ti]["trades_left"]]
						message_timer = 2.0
						break
			elif ct == CellType.EMPTY:
				_try_player_grow_to(cell)

	# Trade actions via InputMap (rebindable in Project Settings)
	if Input.is_action_just_pressed("trade_1"):
		_trade(0)
	if Input.is_action_just_pressed("trade_2"):
		_trade(1)
	if Input.is_action_just_pressed("trade_3"):
		_trade(2)

	# Arrow-key growth via InputMap
	var grow_dir: Vector2i = Vector2i.ZERO
	if Input.is_action_just_pressed("grow_right"):
		grow_dir = Vector2i(1, 0)
	elif Input.is_action_just_pressed("grow_left"):
		grow_dir = Vector2i(-1, 0)
	elif Input.is_action_just_pressed("grow_down"):
		grow_dir = Vector2i(0, 1)
	elif Input.is_action_just_pressed("grow_up"):
		grow_dir = Vector2i(0, -1)
	if grow_dir != Vector2i.ZERO:
		var center: Vector2i = _player_center()
		_try_player_grow_to(center + grow_dir)

	if Input.is_action_just_pressed("reset"):
		_reset()

	if Input.is_action_just_pressed("cycle_tree"):
		if trees.size() > 0:
			selected_tree_idx = (selected_tree_idx + 1) % trees.size()
			message_text = "Tree %d selected" % (selected_tree_idx + 1)
			message_timer = 2.0


func _screen_to_cell(screen_pos: Vector2) -> Vector2i:
	return Vector2i(int(screen_pos.x / CELL_SIZE), int(screen_pos.y / CELL_SIZE))


func _player_center() -> Vector2i:
	if player_cells.is_empty():
		return Vector2i(GRID_W / 2, GRID_H / 2)
	var sx: int = 0
	var sy: int = 0
	for c: Vector2i in player_cells:
		sx += c.x
		sy += c.y
	return Vector2i(sx / player_cells.size(), sy / player_cells.size())


func _update_hover() -> void:
	hover_cell = _screen_to_cell(mouse_pos)
	if hover_cell.x < 0 or hover_cell.x >= GRID_W or hover_cell.y < 0 or hover_cell.y >= GRID_H:
		hover_cell = Vector2i(-1, -1)


# ═══════════════════════════════════════════════════════════════
# RESET
# ═══════════════════════════════════════════════════════════════

func _reset() -> void:
	player_cells.clear()
	player_gp = 10.0
	player_gp_rate = BASE_GP_RATE
	player_sugars = 0
	player_water = 0
	player_minerals = 0
	player_absorbed = 0
	player_growth_progress = 0.0
	rivals.clear()
	rival_timers = [0.0, 0.0, 0.0]
	trees.clear()
	anim_pulses.clear()
	anim_absorbs.clear()
	selected_tree_idx = -1
	growth_candidates.clear()

	randomize()
	seed_val = randi()
	seed(seed_val)
	print("DEEP ROOT proto v2 — seed: ", seed_val)
	_init_grid()
	_place_resources()
	_place_trees()
	_place_player()
	_place_rivals()
	_setup_rival_timers()
	message_text = "Seed: %d — Grow with arrow keys, trade with 1/2/3, reset: R" % seed_val


# ═══════════════════════════════════════════════════════════════
# RENDER
# ═══════════════════════════════════════════════════════════════

func _draw() -> void:
	_draw_grid()
	_draw_resources()
	_draw_player()
	_draw_rivals()
	_draw_trees()
	_draw_animations()
	_draw_ui()
	if hover_cell.x >= 0:
		_draw_hover()
	_draw_growth_highlight()


func _draw_grid() -> void:
	# Background
	draw_rect(Rect2(0, 0, GRID_W * CELL_SIZE, GRID_H * CELL_SIZE), COLOR_EMPTY)

	# Grid lines
	for x: int in range(GRID_W + 1):
		var px: int = x * CELL_SIZE
		draw_line(Vector2(px, 0), Vector2(px, GRID_H * CELL_SIZE), COLOR_GRID_LINE, 1)
	for y: int in range(GRID_H + 1):
		var py: int = y * CELL_SIZE
		draw_line(Vector2(0, py), Vector2(GRID_W * CELL_SIZE, py), COLOR_GRID_LINE, 1)


func _draw_resources() -> void:
	for y: int in range(GRID_H):
		for x: int in range(GRID_W):
			var ct: int = grid[y][x]
			var color: Color
			var size_ratio: float = 0.35
			match ct:
				CellType.WATER:
					color = COLOR_WATER
					size_ratio = 0.4
				CellType.MINERAL:
					color = COLOR_MINERAL
					size_ratio = 0.35
				CellType.SUGAR:
					color = COLOR_SUGAR
					size_ratio = 0.3
				_:
					continue
			var cx: float = x * CELL_SIZE + CELL_SIZE / 2.0
			var cy: float = y * CELL_SIZE + CELL_SIZE / 2.0
			var r: float = CELL_SIZE * size_ratio
			draw_circle(Vector2(cx, cy), r, color)


func _draw_player() -> void:
	# Connections (8-dir)
	_draw_connections(player_cells, COLOR_MYCELIUM)

	for c: Vector2i in player_cells:
		var cx: float = c.x * CELL_SIZE + CELL_SIZE / 2.0
		var cy: float = c.y * CELL_SIZE + CELL_SIZE / 2.0
		var r: float = CELL_SIZE * 0.42
		draw_circle(Vector2(cx, cy), r, COLOR_MYCELIUM)
		draw_arc(Vector2(cx, cy), r, 0, TAU, 32, Color(0.2, 0.6, 0.3), 1.5)


func _draw_rivals() -> void:
	for rival: Dictionary in rivals:
		var color: Color = rival["color"]
		var cells: Array[Vector2i] = rival["cells"]
		# Connections
		_draw_connections(cells, color)
		for c: Vector2i in cells:
			var cx: float = c.x * CELL_SIZE + CELL_SIZE / 2.0
			var cy: float = c.y * CELL_SIZE + CELL_SIZE / 2.0
			var r: float = CELL_SIZE * 0.38
			draw_circle(Vector2(cx, cy), r, color)
			draw_arc(Vector2(cx, cy), r, 0, TAU, 32, color.darkened(0.3), 1.5)


func _draw_trees() -> void:
	for ti: int in range(trees.size()):
		var tree: Dictionary = trees[ti]
		var tp: Vector2i = tree["pos"]
		var is_selected: bool = (ti == selected_tree_idx)

		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var tx: int = tp.x + dx
				var ty: int = tp.y + dy
				if tx >= 0 and tx < GRID_W and ty >= 0 and ty < GRID_H:
					var cx: float = tx * CELL_SIZE + CELL_SIZE / 2.0
					var cy: float = ty * CELL_SIZE + CELL_SIZE / 2.0
					var r: float = CELL_SIZE * 0.45
					var tree_color: Color = COLOR_TREE
					if is_selected:
						tree_color = COLOR_TREE.lightened(0.3)
					draw_circle(Vector2(cx, cy), r, tree_color)
					draw_arc(Vector2(cx, cy), r, 0, TAU, 32, Color(0.1, 0.35, 0.1), 2.0)

		# Tree label
		var label_x: float = (tp.x + 1) * CELL_SIZE
		var label_y: float = (tp.y - 0.5) * CELL_SIZE
		draw_string(ThemeDB.fallback_font, Vector2(label_x, label_y),
			"T%d [%d]" % [ti + 1, tree["trades_left"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_UI_TEXT)


func _draw_connections(cells: Array[Vector2i], color: Color) -> void:
	var drawn: Dictionary = {}
	for c: Vector2i in cells:
		for d: Vector2i in DIRS_8:
			var n: Vector2i = c + d
			if n.x >= 0 and n.x < GRID_W and n.y >= 0 and n.y < GRID_H:
				var key: String = "%d,%d-%d,%d" % [min(c.x, n.x), min(c.y, n.y), max(c.x, n.x), max(c.y, n.y)]
				if not drawn.has(key):
					drawn[key] = true
					if cells.has(n):
						var ax: float = c.x * CELL_SIZE + CELL_SIZE / 2.0
						var ay: float = c.y * CELL_SIZE + CELL_SIZE / 2.0
						var bx: float = n.x * CELL_SIZE + CELL_SIZE / 2.0
						var by: float = n.y * CELL_SIZE + CELL_SIZE / 2.0
						draw_line(Vector2(ax, ay), Vector2(bx, by), color, 2.0)


func _draw_animations() -> void:
	for a: Dictionary in anim_pulses:
		var pos: Vector2i = a["pos"]
		var t: float = a["t"]
		var color: Color = a["color"]
		var anim_type: String = a.get("type", "grow")
		var cx: float = pos.x * CELL_SIZE + CELL_SIZE / 2.0
		var cy: float = pos.y * CELL_SIZE + CELL_SIZE / 2.0

		match anim_type:
			"grow":
				var r: float = CELL_SIZE * (0.1 + t * 1.2)
				var alpha: float = 1.0 - t
				draw_arc(Vector2(cx, cy), r, 0, TAU, 32, Color(color, alpha * 0.4), 2.0)
			"absorb":
				var r: float = CELL_SIZE * (0.2 + t * 0.6)
				var alpha: float = 1.0 - t
				draw_circle(Vector2(cx, cy), r, Color(color, alpha * 0.6))
			"trade":
				var r: float = CELL_SIZE * (0.3 + t * 1.5)
				var alpha: float = 1.0 - t
				draw_arc(Vector2(cx, cy), r, 0, TAU, 32, Color(color, alpha * 0.5), 2.5)


func _draw_hover() -> void:
	var x: float = hover_cell.x * CELL_SIZE
	var y: float = hover_cell.y * CELL_SIZE
	draw_rect(Rect2(x, y, CELL_SIZE, CELL_SIZE), COLOR_HOVER)
	draw_rect(Rect2(x, y, CELL_SIZE, CELL_SIZE), Color(1, 1, 1, 0.3), false, 1)

	# Tooltip
	var ct: int = grid[hover_cell.y][hover_cell.x]
	var tip: String = ""
	match ct:
		CellType.EMPTY: tip = "Empty soil"
		CellType.WATER: tip = "Water"
		CellType.MINERAL: tip = "Minerals"
		CellType.SUGAR: tip = "Sugar"
		CellType.TREE: tip = "Tree"
		CellType.MYCELIUM: tip = "Your mycelium"
		CellType.RIVAL_RED: tip = "Red rival (aggressive)"
		CellType.RIVAL_ORANGE: tip = "Orange rival (defensive)"
		CellType.RIVAL_VIOLET: tip = "Violet rival (opportunistic)"

	if tip != "":
		var tip_x: float = x + CELL_SIZE + 4
		var tip_y: float = y - 4
		draw_string(ThemeDB.fallback_font, Vector2(tip_x, tip_y), tip,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_UI_TEXT)


func _draw_growth_highlight() -> void:
	for c: Vector2i in growth_candidates:
		var x: float = c.x * CELL_SIZE + 2
		var y: float = c.y * CELL_SIZE + 2
		draw_rect(Rect2(x, y, CELL_SIZE - 4, CELL_SIZE - 4), COLOR_GROW_HIGHLIGHT)


func _draw_ui() -> void:
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 11
	var line_h: int = 14
	var ui_x: int = 4
	var ui_y: int = 4
	var bg_w: int = 200
	var bg_h: int = 220

	# Background
	draw_rect(Rect2(ui_x, ui_y, bg_w, bg_h), COLOR_UI_BG)

	var y_off: float = ui_y + 2

	# Title
	draw_string(font, Vector2(ui_x + 4, y_off + 10), "DEEP ROOT proto v2",
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLOR_SUGAR)
	y_off += line_h + 2

	# Stats
	var lines: Array[String] = [
		"Seed: %d" % seed_val,
		"GP: %.1f (%.2f/s)" % [player_gp, player_gp_rate],
		"Water: %d  Minerals: %d  Sugars: %d" % [player_water, player_minerals, player_sugars],
		"Cells: %d  Absorbed: %d" % [player_cells.size(), player_absorbed],
		"",
		"── Rivals ──",
	]

	for rival: Dictionary in rivals:
		var name: String = ""
		match rival["personality"]:
			"aggressive": name = "Red"
			"defensive": name = "Orange"
			"opportunistic": name = "Violet"
		lines.append("  %s: %d cells, %d absorbed" % [name, rival["cells"].size(), rival["absorbed"]])

	lines.append("")
	lines.append("── Trees ──")

	for ti: int in range(trees.size()):
		var tree: Dictionary = trees[ti]
		var marker: String = ">" if ti == selected_tree_idx else " "
		lines.append("  %sT%d: %d trades left%s" % [
			marker, ti + 1, tree["trades_left"],
			" (CD %.1fs)" % tree["cooldown"] if tree["cooldown"] > 0 else "",
		])

	for line: String in lines:
		draw_string(font, Vector2(ui_x + 4, y_off + 10), line,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLOR_UI_TEXT)
		y_off += line_h

	# Territory percentage
	var total_cells: int = GRID_W * GRID_H
	var pct: float = float(player_cells.size()) / float(total_cells) * 100.0
	var terr_str: String = "Territory: %.1f%%" % pct
	draw_string(font, Vector2(ui_x + 4, y_off + 14), terr_str,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLOR_UI_TEXT)
	y_off += line_h

	# Message
	if message_timer > 0 and message_text != "":
		draw_string(font, Vector2(ui_x + 4, y_off + 18), message_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLOR_SUGAR)

	# Controls hint — bottom right
	var ctrl_lines: Array[String] = [
		"Arrows: grow  |  1/2/3: trade  |  Tab: cycle tree",
		"Click: grow to cell  |  Click tree: select  |  R: reset",
	]
	var ctrl_y: float = GRID_H * CELL_SIZE - len(ctrl_lines) * line_h - 6
	draw_rect(Rect2(0, ctrl_y - 2, GRID_W * CELL_SIZE, len(ctrl_lines) * line_h + 4), COLOR_UI_BG)
	for cl: String in ctrl_lines:
		draw_string(font, Vector2(6, ctrl_y + 10), cl,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLOR_UI_TEXT)
		ctrl_y += line_h
