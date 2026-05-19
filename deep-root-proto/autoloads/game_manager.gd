# ═══════════════════════════════════════════════════════════════
# GameManager — Autoload singleton
# Manages game state: grid, player, trees, growth, absorption,
# trade, animation state. Replaces the monolith main.gd state.
# Juice: death_anims for rival death particles, screen_shake_requested signal
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
const DEEP_ROOT_PULSE_COST: float = 15.0
const DEEP_ROOT_PULSE_REGEN: int = 3
const LINK_BONUS_TRADES: int = 6  # 2× base trades when linked

# ── Zone difficulty ────────────────────────────────────────
const ZONE_COST_BORDER: float = 3.0
const ZONE_COST_CENTER: float = 5.0
const ZONE_COST_NEAR_RIVAL: float = 7.0
const ZONE_BORDER_DIST: int = 3
const ZONE_RIVAL_DIST: int = 5

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
var death_anims: Array[Dictionary] = []

# ── State ──────────────────────────────────────────────────
var seed_val: int = 0
var growth_candidates: Array[Vector2i] = []
var selected_tree_idx: int = -1
var link_mode: int = -1  # -1 = no link in progress, N = tree idx waiting for link partner
var message_text: String = ""
var message_timer: float = 0.0
var is_resetting: bool = false

# ── History tracking ───────────────────────────────────────
const HISTORY_INTERVAL: float = 2.0  # snapshot every 2 seconds
var history_timer: float = 0.0
var history: Array[Dictionary] = []  # [{t: float, player_cells: int, rivals: [int, int, int]}]

# ── Game Over ──────────────────────────────────────────────
var game_over: bool = false
var game_over_reason: String = ""

# ── Signals ────────────────────────────────────────────────
signal state_changed
signal show_message(msg: String)
signal trade_completed(tree_idx: int, cost: int, gain: int)
signal game_ended(reason: String)
signal screen_shake_requested(intensity: float)
signal reset_fade_requested

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
	game_over = false
	game_over_reason = ""
	history.clear()
	history_timer = HISTORY_INTERVAL
	_record_history_snapshot()
	message_text = "Seed: %d — Grow with arrow keys, trade with 1/2/3, reset: R" % seed_val
	is_resetting = false
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
			"linked_to": -1,
		})


func _place_player() -> void:
	player_cells.clear()
	var sx: int = (GRID_W / 2) - 5
	var sy: int = (GRID_H / 2) + 3
	player_cells.append(Vector2i(sx, sy))
	grid[sy][sx] = CellType.MYCELIUM

# ═══════════════════════════════════════════════════════════════
# ZONE DETECTION
# ═══════════════════════════════════════════════════════════════

func get_cell_zone(pos: Vector2i) -> String:
	"""Return zone classification: border, near_rival, or center."""
	# Border check (edges of the map — easy growth)
	if pos.x < ZONE_BORDER_DIST or pos.x >= GRID_W - ZONE_BORDER_DIST:
		return "border"
	if pos.y < ZONE_BORDER_DIST or pos.y >= GRID_H - ZONE_BORDER_DIST:
		return "border"
	# Near rivals check (highest priority — hostile growth)
	var am = get_node_or_null("/root/AIManager")
	if am:
		for rival: Dictionary in am.rivals:
			for rc: Vector2i in rival["cells"]:
				if abs(pos.x - rc.x) <= ZONE_RIVAL_DIST and abs(pos.y - rc.y) <= ZONE_RIVAL_DIST:
					return "near_rival"
	return "center"


func get_growth_cost(pos: Vector2i) -> float:
	match get_cell_zone(pos):
		"border": return ZONE_COST_BORDER
		"near_rival": return ZONE_COST_NEAR_RIVAL
		_: return ZONE_COST_CENTER


func get_zone_tint(pos: Vector2i) -> Color:
	"""Return a subtle tint color for zone visualization."""
	match get_cell_zone(pos):
		"border": return Color(0.0, 1.0, 0.0, 0.12)      # Green = easy
		"near_rival": return Color(1.0, 0.15, 0.15, 0.18)  # Red = hostile
		_: return Color(1.0, 1.0, 0.0, 0.06)              # Yellow = normal

# ═══════════════════════════════════════════════════════════════
# DIFFICULTY CURVE — Progressive challenge scaling
# ═══════════════════════════════════════════════════════════════

const DIFFICULTY_TIER_TERRITORY: Array[float] = [0.0, 5.0, 15.0, 30.0, 50.0, 70.0]
const DIFFICULTY_RIVAL_MULTIPLIERS: Array[float] = [1.0, 1.15, 1.35, 1.6, 1.9, 2.5]
const DIFFICULTY_RIVAL_BONUS_GP: Array[float] = [0.0, 0.5, 1.0, 1.5, 2.0, 3.0]
const DIFFICULTY_NAMES: Array[String] = [
	"Germination", "Spreading", "Colonizing", "Dominating", "Overgrowth", "Conqueror"
]
var _total_game_time: float = 0.0


func player_territory_pct() -> float:
	"""Player territory as percentage of total grid cells."""
	var total: int = GRID_W * GRID_H
	return float(player_cells.size()) / float(total) * 100.0


func get_difficulty_tier() -> int:
	"""Return difficulty tier based on player territory percentage."""
	var pct: float = player_territory_pct()
	var tier: int = 0
	for i: int in range(DIFFICULTY_TIER_TERRITORY.size()):
		if pct >= DIFFICULTY_TIER_TERRITORY[i]:
			tier = i
	return tier


func get_difficulty_name() -> String:
	return DIFFICULTY_NAMES[get_difficulty_tier()]


func get_rival_speed_multiplier() -> float:
	"""Scale rival growth speed based on difficulty tier."""
	var tier: int = get_difficulty_tier()
	if tier < DIFFICULTY_RIVAL_MULTIPLIERS.size():
		return DIFFICULTY_RIVAL_MULTIPLIERS[tier]
	return 1.0


func get_rival_bonus_gp() -> float:
	"""Extra GP per tick for rivals as difficulty increases."""
	var tier: int = get_difficulty_tier()
	if tier < DIFFICULTY_RIVAL_BONUS_GP.size():
		return DIFFICULTY_RIVAL_BONUS_GP[tier]
	return 0.0


func is_mechanic_unlocked(mechanic: String) -> bool:
	"""Check if an advanced mechanic is unlocked based on progress.
	Mechanics: pulse, link, unlink."""
	var tm := get_node_or_null("/root/TutorialManager")
	if tm and tm.is_tutorial_active():
		# During tutorial, only unlock mechanics after "trade" step
		# "advanced" step is index 5
		if tm.get_current_step() < 4:
			return false

	# Unlock based on territory %
	match mechanic:
		"pulse":
			# Unlock when player has >10% territory (Spread tier+)
			return player_territory_pct() >= 5.0
		"link":
			# Unlock when player has >15% territory (Colonizing tier+)
			return player_territory_pct() >= 10.0
		"unlink":
			# Same as link
			return player_territory_pct() >= 10.0
	return true


func tick_difficulty(delta: float) -> void:
	"""Track total game time for progressive scaling."""
	_total_game_time += delta

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
	var cost: float = get_growth_cost(chosen)
	if player_gp < cost: return
	player_gp -= cost
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
	var cost: float = get_growth_cost(target)
	if player_gp < cost: return false
	player_gp -= cost
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

	# GPU particle burst: add multiple small pulses for juice
	_add_pulse(cell, Color(1.0, 0.9, 0.2), "absorb")
	_add_pulse(cell, Color(1.0, 0.7, 0.1), "absorb")  # extra warm particle
	_add_pulse(cell, Color(1.0, 1.0, 0.5), "absorb")  # bright spark

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
		message_text = "Tree depleted! All trades used."
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
# DEEP ROOT PULSE — Regenerate trades on exhausted tree
# ═══════════════════════════════════════════════════════════════

func deep_root_pulse(tree_idx: int) -> void:
	if tree_idx < 0 or tree_idx >= trees.size():
		return
	var tree: Dictionary = trees[tree_idx]
	if tree["trades_left"] > 0:
		message_text = "Tree still has trades! Pulse only works on exhausted trees."
		message_timer = 2.0
		return
	if player_gp < DEEP_ROOT_PULSE_COST:
		message_text = "Need %.0f GP for Deep Root Pulse (have %.1f)" % [DEEP_ROOT_PULSE_COST, player_gp]
		message_timer = 2.0
		return
	player_gp -= DEEP_ROOT_PULSE_COST
	tree["trades_left"] = DEEP_ROOT_PULSE_REGEN
	_add_pulse(tree["pos"], Color(0.4, 0.9, 0.6), "pulse")
	message_text = "Deep Root Pulse! Tree %d regenerated to %d trades." % [tree_idx + 1, DEEP_ROOT_PULSE_REGEN]
	message_timer = 2.0
	state_changed.emit()

# ═══════════════════════════════════════════════════════════════
# TREE LINKING — Connect 2 trees via mycelium to double trades
# ═══════════════════════════════════════════════════════════════

func enter_link_mode(tree_idx: int) -> void:
	if tree_idx < 0 or tree_idx >= trees.size():
		return
	var tree: Dictionary = trees[tree_idx]
	if tree["trades_left"] > 0:
		message_text = "Tree still has trades! Link only available when exhausted."
		message_timer = 2.0
		return
	if tree["linked_to"] >= 0:
		message_text = "Tree %d already linked to Tree %d. Press U to unlink." % [tree_idx + 1, tree["linked_to"] + 1]
		message_timer = 2.0
		return
	link_mode = tree_idx
	message_text = "Link mode: select another tree to link with Tree %d (press L again or Esc to cancel)" % (tree_idx + 1)
	message_timer = 3.0
	state_changed.emit()


func link_trees(tree_a_idx: int, tree_b_idx: int) -> void:
	if tree_a_idx == tree_b_idx:
		message_text = "Cannot link a tree to itself!"
		message_timer = 2.0
		link_mode = -1
		return
	if tree_a_idx < 0 or tree_a_idx >= trees.size() or tree_b_idx < 0 or tree_b_idx >= trees.size():
		link_mode = -1
		return
	var tree_a: Dictionary = trees[tree_a_idx]
	var tree_b: Dictionary = trees[tree_b_idx]

	if tree_a["linked_to"] >= 0:
		message_text = "Tree %d is already linked to Tree %d. Unlink first." % [tree_a_idx + 1, tree_a["linked_to"] + 1]
		message_timer = 2.0
		link_mode = -1
		return
	if tree_b["linked_to"] >= 0:
		message_text = "Tree %d is already linked to Tree %d. Unlink first." % [tree_b_idx + 1, tree_b["linked_to"] + 1]
		message_timer = 2.0
		link_mode = -1
		return

	# Form the link
	tree_a["linked_to"] = tree_b_idx
	tree_b["linked_to"] = tree_a_idx
	tree_a["trades_left"] += LINK_BONUS_TRADES
	tree_b["trades_left"] += LINK_BONUS_TRADES

	_add_pulse(tree_a["pos"], Color(0.6, 0.4, 0.95), "link")
	_add_pulse(tree_b["pos"], Color(0.6, 0.4, 0.95), "link")
	message_text = "Trees %d and %d linked via mycelium! +%d trades each." % [tree_a_idx + 1, tree_b_idx + 1, LINK_BONUS_TRADES]
	message_timer = 2.0
	link_mode = -1
	state_changed.emit()


func unlink_trees(tree_idx: int) -> void:
	if tree_idx < 0 or tree_idx >= trees.size():
		return
	var tree: Dictionary = trees[tree_idx]
	var partner_idx: int = tree["linked_to"]
	if partner_idx < 0:
		message_text = "Tree %d is not linked." % (tree_idx + 1)
		message_timer = 2.0
		return
	var partner: Dictionary = trees[partner_idx]

	# Remove bonus trades (cap at 0, don't go negative if already used)
	var remove_a: int = min(tree["trades_left"], LINK_BONUS_TRADES)
	var remove_b: int = min(partner["trades_left"], LINK_BONUS_TRADES)
	tree["trades_left"] -= remove_a
	partner["trades_left"] -= remove_b
	tree["linked_to"] = -1
	partner["linked_to"] = -1

	message_text = "Unlinked Trees %d and %d." % [tree_idx + 1, partner_idx + 1]
	message_timer = 2.0
	state_changed.emit()


func cancel_link_mode() -> void:
	if link_mode >= 0:
		message_text = "Link cancelled."
		message_timer = 1.5
		link_mode = -1
		state_changed.emit()

# ═══════════════════════════════════════════════════════════════
# ANIMATIONS
# ═══════════════════════════════════════════════════════════════

func _add_pulse(pos: Vector2i, color: Color, type: String) -> void:
	anim_pulses.append({"pos": pos, "t": 0.0, "color": color, "type": type})


func update_animations(delta: float) -> void:
	# Update cell pulses
	var i: int = 0
	while i < anim_pulses.size():
		var a: Dictionary = anim_pulses[i]
		a["t"] += delta * 3.0
		if a["t"] >= 1.0:
			anim_pulses.remove_at(i)
		else:
			i += 1

	# Update death animations
	var j: int = 0
	while j < death_anims.size():
		var da: Dictionary = death_anims[j]
		da["t"] += delta * 2.0
		if da["t"] >= 1.0:
			death_anims.remove_at(j)
		else:
			j += 1


func _add_death_pulse(pos: Vector2i, color: Color) -> void:
	death_anims.append({"pos": pos, "t": 0.0, "color": color})


func request_screen_shake(intensity: float = 0.3) -> void:
	screen_shake_requested.emit(intensity)

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


# ═══════════════════════════════════════════════════════════════
# RESET (with death animation for rivals)
# ═══════════════════════════════════════════════════════════════

func reset_with_animations() -> void:
	"""Phase 1: Spawn death particles on rival cells, request fade out."""
	# Capture rival cells BEFORE clearing
	var am = get_node_or_null("/root/AIManager")
	if am != null:
		for rival: Dictionary in am.rivals:
			var rival_color: Color = rival["color"]
			for cell: Vector2i in rival["cells"]:
				_add_death_pulse(cell, rival_color)
				# Extra white flash for pop
				_add_death_pulse(cell, Color(1.0, 1.0, 1.0))

	is_resetting = true
	reset_fade_requested.emit()


func reset() -> void:
	"""Called after fade-out completes to actually clear state."""
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
	death_anims.clear()
	selected_tree_idx = -1
	link_mode = -1
	growth_candidates.clear()
	game_over = false
	game_over_reason = ""
	history.clear()
	history_timer = 0.0
	is_resetting = false
	state_changed.emit()
	new_game()

# ═══════════════════════════════════════════════════════════════
# GAME OVER DETECTION
# ═══════════════════════════════════════════════════════════════

func is_grid_full() -> bool:
	for y: int in range(GRID_H):
		for x: int in range(GRID_W):
			if grid[y][x] == CellType.EMPTY:
				return false
	return true

func is_player_dead() -> bool:
	return player_cells.is_empty() or not _has_growth_space()

func _has_growth_space() -> bool:
	update_growth_candidates()
	return not growth_candidates.is_empty()

func end_game(reason: String) -> void:
	if game_over: return
	game_over = true
	game_over_reason = reason
	# Take one final snapshot
	_record_history_snapshot()
	print("GAME OVER: ", reason)
	game_ended.emit(reason)

func check_game_over() -> void:
	if game_over: return
	if is_grid_full():
		end_game("grid_full")
	elif is_player_dead():
		end_game("player_died")

# ═══════════════════════════════════════════════════════════════
# HISTORY TRACKING
# ═══════════════════════════════════════════════════════════════

func tick_history(delta: float) -> void:
	if game_over: return
	history_timer -= delta
	if history_timer <= 0.0:
		history_timer = HISTORY_INTERVAL
		_record_history_snapshot()

func _record_history_snapshot() -> void:
	var am = get_node_or_null("/root/AIManager")
	var rival_counts: Array[int] = [0, 0, 0]
	var rival_absorbed: Array[int] = [0, 0, 0]
	if am:
		for i: int in range(min(am.rivals.size(), 3)):
			rival_counts[i] = am.rivals[i]["cells"].size()
			rival_absorbed[i] = am.rivals[i]["absorbed"]
	history.append({
		"t": Time.get_ticks_msec() / 1000.0 if Engine.get_process_frames() > 0 else 0.0,
		"player_cells": player_cells.size(),
		"player_gp": player_gp,
		"player_absorbed": player_absorbed,
		"player_sugars": player_sugars,
		"rival_cells": rival_counts,
		"rival_absorbed": rival_absorbed,
	})
