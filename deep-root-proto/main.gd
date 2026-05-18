# ═══════════════════════════════════════════════════════════════
# main.gd — DEEP ROOT proto v3 (refactored)
# Thin orchestration: input handling, delegates to autoloads.
# GridLayer handles rendering, UILayer handles HUD.
# ═══════════════════════════════════════════════════════════════
extends Node2D

var mouse_pos: Vector2 = Vector2.ZERO
var hover_cell: Vector2i = Vector2i(-1, -1)


func _ready() -> void:
	GameManager.new_game()
	AIManager.setup_rivals()


func _process(delta: float) -> void:
	var gm: GameManager = GameManager
	var am: AIManager = AIManager

	# GP accrual
	gm.player_gp += gm.player_gp_rate * delta

	# Growth progress
	gm.player_growth_progress += gm.player_gp_rate * delta
	if gm.player_growth_progress >= gm.GROWTH_COST:
		gm.player_growth_progress -= gm.GROWTH_COST
		gm.update_growth_candidates()
		if not gm.growth_candidates.is_empty():
			gm.try_grow()

	# Rival AI ticks
	for i: int in range(3):
		am.rival_timers[i] -= delta
		if am.rival_timers[i] <= 0.0:
			am.rival_grow(i)
			am.rival_timers[i] = am.rival_intervals[i]

	# Animations
	gm.update_animations(delta)

	# Tree cooldowns + regen
	for tree: Dictionary in gm.trees:
		if tree["cooldown"] > 0:
			tree["cooldown"] -= delta
		# Regen: only tick when trades_left < max
		if tree["trades_left"] < gm.MAX_TRADES_PER_TREE:
			tree["regen_timer"] -= delta
			if tree["regen_timer"] <= 0.0:
				tree["trades_left"] += 1
				tree["regen_timer"] = gm.REGEN_INTERVAL

	# Message timer
	if gm.message_timer > 0:
		gm.message_timer -= delta

	# Mouse hover
	_update_hover()


func _input(event: InputEvent) -> void:
	var gm: GameManager = GameManager

	if event is InputEventMouseMotion:
		mouse_pos = event.position

	if event is InputEventMouseButton and event.pressed:
		var cell: Vector2i = gm.screen_to_cell(event.position)
		if cell.x >= 0 and cell.x < gm.GRID_W and cell.y >= 0 and cell.y < gm.GRID_H:
			var ct: int = gm.grid[cell.y][cell.x]
			if ct == gm.CellType.TREE:
				for ti: int in range(gm.trees.size()):
					var tp: Vector2i = gm.trees[ti]["pos"]
					if abs(cell.x - tp.x) <= 1 and abs(cell.y - tp.y) <= 1:
						gm.selected_tree_idx = ti
						gm.message_text = "Tree %d selected (%d trades left)" % [ti + 1, gm.trees[ti]["trades_left"]]
						gm.message_timer = 2.0
						break
			elif ct == gm.CellType.EMPTY:
				gm.try_player_grow_to(cell)

	if Input.is_action_just_pressed("trade_1"):
		gm.trade(0)
	if Input.is_action_just_pressed("trade_2"):
		gm.trade(1)
	if Input.is_action_just_pressed("trade_3"):
		gm.trade(2)

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
		var center: Vector2i = gm.player_center()
		gm.try_player_grow_to(center + grow_dir)

	if Input.is_action_just_pressed("reset"):
		gm.reset()
		AIManager.setup_rivals()

	if Input.is_action_just_pressed("cycle_tree"):
		if gm.trees.size() > 0:
			gm.selected_tree_idx = (gm.selected_tree_idx + 1) % gm.trees.size()
			gm.message_text = "Tree %d selected" % (gm.selected_tree_idx + 1)
			gm.message_timer = 2.0


func _update_hover() -> void:
	var gm: GameManager = GameManager
	hover_cell = gm.screen_to_cell(mouse_pos)
	if hover_cell.x < 0 or hover_cell.x >= gm.GRID_W or hover_cell.y < 0 or hover_cell.y >= gm.GRID_H:
		hover_cell = Vector2i(-1, -1)
	queue_redraw()


func _draw() -> void:
	if hover_cell.x < 0: return
	var gm: GameManager = GameManager
	var rect := Rect2(
		hover_cell.x * gm.CELL_SIZE, hover_cell.y * gm.CELL_SIZE,
		gm.CELL_SIZE, gm.CELL_SIZE
	)
	# Highlight hover cell: semi-transparent white border
	draw_rect(rect, Color.WHITE, false, 1.0)
	# Lighter fill for empty cells (clickable)
	if gm.grid[hover_cell.y][hover_cell.x] == gm.CellType.EMPTY:
		draw_rect(rect, Color(1.0, 1.0, 1.0, 0.15))
	elif gm.grid[hover_cell.y][hover_cell.x] == gm.CellType.TREE:
		draw_rect(rect, Color(0.95, 0.80, 0.25, 0.2))
