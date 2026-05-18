# ═══════════════════════════════════════════════════════════════
# main.gd — DEEP ROOT proto v3 (refactored)
# Thin orchestration: input handling, delegates to autoloads.
# GridLayer handles rendering, UILayer handles HUD.
# ═══════════════════════════════════════════════════════════════
extends Node2D

var mouse_pos: Vector2 = Vector2.ZERO
var hover_cell: Vector2i = Vector2i(-1, -1)

var _end_screen_scene: PackedScene = preload("res://scenes/end_screen.tscn")
var _end_screen_instance: CanvasLayer = null


func _ready() -> void:
	GameManager.new_game()
	AIManager.setup_rivals()
	GameManager.game_ended.connect(_on_game_ended)


func _process(delta: float) -> void:
	var gm: GameManager = GameManager
	var am: AIManager = AIManager

	# History tracking (before any game-over check, so last frame is recorded)
	gm.tick_history(delta)

	# Check game over
	gm.check_game_over()
	if gm.game_over:
		return

	# GP accrual
	gm.player_gp += gm.player_gp_rate * delta

	# Growth progress (auto-grow timer — uses base GROWTH_COST as timing)
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

	# Rival phase cycles
	am.update_rival_phases(delta)

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
	if gm.game_over:
		return

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
	# ── Zone difficulty tints: persistent overlay on all empty cells ──
	_draw_zone_tints()

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
		# ── Tooltip: zone name + GP cost ──
		var zone: String = gm.get_cell_zone(hover_cell)
		var cost: float = gm.get_growth_cost(hover_cell)
		var zone_name: String = "Center (normal)"
		match zone:
			"border": zone_name = "Border (easy)"
			"near_rival": zone_name = "Near rival (hostile)"
		var text: String = "%s  |  Cost: %.0f GP" % [zone_name, cost]

		var font_size: int = 11
		var txt_x: float = rect.position.x + 4
		var txt_y: float = rect.position.y - 2  # tooltip above cell
		if txt_y < font_size + 6:
			txt_y = rect.position.y + rect.size.y + 2  # below if near top edge

		# Tooltip background
		var font: Font = ThemeDB.fallback_font
		var txt_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var bg_rect := Rect2(txt_x - 2, txt_y - 2, txt_size.x + 8, txt_size.y + 6)
		draw_rect(bg_rect, Color(0.05, 0.05, 0.08, 0.88), true)
		draw_rect(bg_rect, Color(0.3, 0.3, 0.4, 0.7), false, 1.0)

		# Tooltip text — position so baseline is inside bg
		draw_string(font, Vector2(txt_x + 2, txt_y - 2 + font_size + 2), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	elif gm.grid[hover_cell.y][hover_cell.x] == gm.CellType.TREE:
		draw_rect(rect, Color(0.95, 0.80, 0.25, 0.2))


func _draw_zone_tints() -> void:
	"""Draw zone difficulty tints on all empty cells (persistent overlay)."""
	var gm: GameManager = GameManager
	if gm == null: return

	# Batch by zone color to minimize state changes
	var border_rects: Array[Rect2] = []
	var center_rects: Array[Rect2] = []
	var rival_rects: Array[Rect2] = []

	for y: int in range(gm.GRID_H):
		for x: int in range(gm.GRID_W):
			if gm.grid[y][x] != gm.CellType.EMPTY:
				continue
			var pos := Vector2i(x, y)
			var zone: String = gm.get_cell_zone(pos)
			var r := Rect2(x * gm.CELL_SIZE, y * gm.CELL_SIZE, gm.CELL_SIZE, gm.CELL_SIZE)
			match zone:
				"border": border_rects.append(r)
				"near_rival": rival_rects.append(r)
				_: center_rects.append(r)

	for r: Rect2 in center_rects:
		draw_rect(r, Color(1.0, 1.0, 0.0, 0.06), true)
	for r: Rect2 in border_rects:
		draw_rect(r, Color(0.0, 1.0, 0.0, 0.12), true)
	for r: Rect2 in rival_rects:
		draw_rect(r, Color(1.0, 0.15, 0.15, 0.18), true)


func _on_game_ended(_reason: String) -> void:
	if _end_screen_instance == null:
		_end_screen_instance = _end_screen_scene.instantiate()
		add_child(_end_screen_instance)
	else:
		# Re-show existing end screen on replay
		_end_screen_instance.visible = true
		# Re-trigger display update
		var gm: GameManager = GameManager
		if gm:
			_end_screen_instance._on_game_ended(gm.game_over_reason)
