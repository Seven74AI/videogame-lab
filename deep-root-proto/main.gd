# ═══════════════════════════════════════════════════════════════
# main.gd — DEEP ROOT proto v3 (refactored)
# Thin orchestration: input handling, delegates to autoloads.
# GridLayer handles rendering, UILayer handles HUD.
# Juice: Camera2D screen shake + ColorRect fade transitions
# UX: Tutorial overlay + difficulty curve + milestone messages
# ═══════════════════════════════════════════════════════════════
extends Node2D

@onready var _camera: Camera2D = $Camera2D
@onready var _fade_overlay: CanvasLayer = $FadeCanvas
@onready var _fade_rect: ColorRect = $FadeCanvas/ColorRect
@onready var _tutorial_overlay: CanvasLayer = $TutorialOverlay

var mouse_pos: Vector2 = Vector2.ZERO
var hover_cell: Vector2i = Vector2i(-1, -1)

var _end_screen_scene: PackedScene = preload("res://scenes/end_screen.tscn")
var _end_screen_instance: CanvasLayer = null

# ── Difficulty milestone tracking ─────────────────────────
var _last_difficulty_tier: int = 0

# ── Screen shake state ────────────────────────────────────
var _shake_intensity: float = 0.0
var _shake_decay: float = 0.9

# ── Fade state ────────────────────────────────────────────
enum FadeState { NONE, FADING_OUT, WAITING, FADING_IN }
var _fade_state: int = FadeState.NONE
var _fade_progress: float = 0.0
const FADE_DURATION: float = 0.4
const FADE_HOLD: float = 0.3  # Time to hold at full black while reset happens
var _fade_hold_timer: float = 0.0


func _ready() -> void:
	# Connect screen shake signal
	var gm: GameManager = GameManager
	if not gm.screen_shake_requested.is_connected(_on_screen_shake_requested):
		gm.screen_shake_requested.connect(_on_screen_shake_requested)
	if not gm.reset_fade_requested.is_connected(_on_reset_fade_requested):
		gm.reset_fade_requested.connect(_on_reset_fade_requested)

	# Init fade overlay: fully transparent
	_fade_rect.modulate = Color(0, 0, 0, 0)
	_fade_overlay.visible = false

	GameManager.new_game()
	AIManager.setup_rivals()
	GameManager.game_ended.connect(_on_game_ended)

	# ── Start tutorial (TutorialManager checks if already completed) ──
	var tm := get_node_or_null("/root/TutorialManager")
	if tm:
		tm.start_tutorial()
	_last_difficulty_tier = gm.get_difficulty_tier()


func _process(delta: float) -> void:
	var gm: GameManager = GameManager
	var am: AIManager = AIManager

	# History tracking (before any game-over check, so last frame is recorded)
	gm.tick_history(delta)

	# ── Difficulty tracking ───────────────────────────────
	gm.tick_difficulty(delta)
	_check_difficulty_milestone(gm)

	# Check game over
	gm.check_game_over()
	if gm.game_over:
		return

	# ── Game logic (skip during reset fade) ────────────────
	if not gm.is_resetting:
		# GP accrual
		gm.player_gp += gm.player_gp_rate * delta

		# Growth progress (auto-grow timer — uses base GROWTH_COST as timing)
		gm.player_growth_progress += gm.player_gp_rate * delta
		if gm.player_growth_progress >= gm.GROWTH_COST:
			gm.player_growth_progress -= gm.GROWTH_COST
			gm.update_growth_candidates()
			if not gm.growth_candidates.is_empty():
				gm.try_grow()

	# Rival AI ticks — iterate backward so rival death (remove_at) doesn't invalidate indices
	for i: int in range(am.rivals.size() - 1, -1, -1):
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
			# Regen: only tick when trades_left < max AND not linked (linked trees don't regen)
			if tree["trades_left"] < gm.MAX_TRADES_PER_TREE and tree.get("linked_to", -1) < 0:
				tree["regen_timer"] -= delta
				if tree["regen_timer"] <= 0.0:
					tree["trades_left"] += 1
					tree["regen_timer"] = gm.REGEN_INTERVAL

		# Message timer
		if gm.message_timer > 0:
			gm.message_timer -= delta

	# ── Screen shake ───────────────────────────────────────
	_update_screen_shake(delta)

	# ── Fade transition ────────────────────────────────────
	_update_fade(delta)

	# ── Mouse hover ────────────────────────────────────────
	_update_hover()


func _input(event: InputEvent) -> void:
	var gm: GameManager = GameManager
	if gm.game_over:
		return

	# ── Tutorial: route input to TutorialManager ───────────
	var tm := get_node_or_null("/root/TutorialManager")
	if tm and tm.is_tutorial_active():
		if event is InputEventKey and event.pressed:
			tm.advance_tutorial()
		elif event is InputEventMouseButton and event.pressed:
			tm.advance_tutorial()
		if tm.is_input_blocked():
			return  # Don't process game input during blocking tutorial steps

	# Block input during fade/reset
	if _fade_state != FadeState.NONE or gm.is_resetting:
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
						if gm.link_mode >= 0:
							# In link mode — clicking a tree attempts to link
							gm.link_trees(gm.link_mode, ti)
						else:
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

	# ── Deep Root Pulse ──────────────────────────────────
	if Input.is_action_just_pressed("pulse_tree"):
		if not gm.is_mechanic_unlocked("pulse"):
			gm.message_text = "Deep Root Pulse not yet available. Expand further!"
			gm.message_timer = 2.0
		elif gm.link_mode >= 0:
			gm.cancel_link_mode()
		elif gm.selected_tree_idx >= 0:
			gm.deep_root_pulse(gm.selected_tree_idx)
		else:
			gm.message_text = "No tree selected! Click a tree first."
			gm.message_timer = 2.0

	# ── Tree Linking ─────────────────────────────────────
	if Input.is_action_just_pressed("link_tree"):
		if not gm.is_mechanic_unlocked("link"):
			gm.message_text = "Tree Linking not yet available. Expand further!"
			gm.message_timer = 2.0
		elif gm.link_mode >= 0:
			# Already in link mode — pressing L again cancels
			gm.cancel_link_mode()
		elif gm.selected_tree_idx >= 0:
			gm.enter_link_mode(gm.selected_tree_idx)
		else:
			gm.message_text = "No tree selected! Click a tree first."
			gm.message_timer = 2.0

	# ── Tree Unlinking ───────────────────────────────────
	if Input.is_action_just_pressed("unlink_tree"):
		if not gm.is_mechanic_unlocked("unlink"):
			gm.message_text = "Tree Unlinking not yet available. Expand further!"
			gm.message_timer = 2.0
		elif gm.link_mode >= 0:
			gm.cancel_link_mode()
		elif gm.selected_tree_idx >= 0:
			gm.unlink_trees(gm.selected_tree_idx)
		else:
			gm.message_text = "No tree selected! Click a tree first."
			gm.message_timer = 2.0

	# ── Cancel link mode (Esc) ───────────────────────────
	if Input.is_action_just_pressed("ui_cancel"):
		if gm.link_mode >= 0:
			gm.cancel_link_mode()
			get_viewport().set_input_as_handled()

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
		# Start fade-out → death animation → reset → fade-in
		gm.reset_with_animations()

	if Input.is_action_just_pressed("cycle_tree"):
		if gm.trees.size() > 0:
			gm.selected_tree_idx = (gm.selected_tree_idx + 1) % gm.trees.size()
			gm.message_text = "Tree %d selected" % (gm.selected_tree_idx + 1)
			gm.message_timer = 2.0


# ═══════════════════════════════════════════════════════════════
# SCREEN SHAKE
# ═══════════════════════════════════════════════════════════════

func _on_screen_shake_requested(intensity: float) -> void:
	# Only apply if intensity is higher than current
	_shake_intensity = maxf(_shake_intensity, intensity)


func _update_screen_shake(delta: float) -> void:
	if _shake_intensity > 0.001:
		var offset_x: float = randf_range(-_shake_intensity, _shake_intensity) * 4.0
		var offset_y: float = randf_range(-_shake_intensity, _shake_intensity) * 4.0
		_camera.offset = Vector2(offset_x, offset_y)
		_shake_intensity *= _shake_decay
	else:
		_shake_intensity = 0.0
		_camera.offset = Vector2.ZERO


# ═══════════════════════════════════════════════════════════════
# FADE TRANSITION
# ═══════════════════════════════════════════════════════════════

func _on_reset_fade_requested() -> void:
	_fade_state = FadeState.FADING_OUT
	_fade_progress = 0.0
	_fade_hold_timer = 0.0
	_fade_overlay.visible = true
	_fade_rect.modulate = Color(0, 0, 0, 0)


func _update_fade(delta: float) -> void:
	match _fade_state:
		FadeState.FADING_OUT:
			_fade_progress += delta / FADE_DURATION
			if _fade_progress >= 1.0:
				_fade_progress = 1.0
				_fade_rect.modulate = Color(0, 0, 0, 1.0)
				_fade_state = FadeState.WAITING
				_fade_hold_timer = 0.0
				# Execute the actual reset now (screen is black)
				GameManager.reset()
				AIManager.setup_rivals()
			else:
				_fade_rect.modulate = Color(0, 0, 0, _fade_progress)

		FadeState.WAITING:
			_fade_hold_timer += delta
			if _fade_hold_timer >= FADE_HOLD:
				_fade_state = FadeState.FADING_IN
				_fade_progress = 1.0

		FadeState.FADING_IN:
			_fade_progress -= delta / FADE_DURATION
			if _fade_progress <= 0.0:
				_fade_progress = 0.0
				_fade_rect.modulate = Color(0, 0, 0, 0)
				_fade_overlay.visible = false
				_fade_state = FadeState.NONE
			else:
				_fade_rect.modulate = Color(0, 0, 0, _fade_progress)


# ═══════════════════════════════════════════════════════════════
# HOVER
# ═══════════════════════════════════════════════════════════════

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


# ═══════════════════════════════════════════════════════════════
# DIFFICULTY MILESTONE DETECTION
# ═══════════════════════════════════════════════════════════════

func _check_difficulty_milestone(gm) -> void:
	"""Show a milestone message when difficulty tier increases."""
	var current_tier: int = gm.get_difficulty_tier()
	if current_tier > _last_difficulty_tier:
		var name: String = gm.get_difficulty_name()
		var tier_msgs: Array[String] = [
			"",  # Tier 0 = no message
			"[Milestone] Your mycelium is spreading! Rivals accelerate.",
			"[Milestone] Colonizing the forest! Rivals grow faster.",
			"[Milestone] Dominating territory! Rivals are relentless.",
			"[Milestone] Overgrowth! The forest trembles.",
			"[Milestone] Conqueror! Can you take the entire grid?",
		]
		var msg: String = tier_msgs[current_tier] if current_tier < tier_msgs.size() else "New difficulty tier: %s!" % name
		gm.message_text = msg
		gm.message_timer = 3.0

		# Also trigger a subtle screen shake for milestone feel
		gm.request_screen_shake(0.15)
		_last_difficulty_tier = current_tier
