# ═══════════════════════════════════════════════════════════════
# TutorialManager — Autoload singleton
# Step-by-step onboarding system. Data-driven: steps defined as
# an array of {"id": String, "text": String, "block_input": bool}.
# Persists tutorial completion to user://tutorial_config.cfg.
# Signal tutorial_step_changed(step_idx: int) for overlay.
# ═══════════════════════════════════════════════════════════════
extends Node

# ── Tutorial steps ──────────────────────────────────────────
const STEPS: Array[Dictionary] = [
	{
		"id": "welcome",
		"text": "Welcome to DEEP ROOT!\nYou are a mycelium network growing across the forest floor.\nClick anywhere or press → to continue.",
		"block_input": true,
		"duration": 0.0,
	},
	{
		"id": "grow",
		"text": "Use ARROW KEYS or CLICK adjacent empty cells to GROW your mycelium.\nGrowth costs GP (shown top-left).\nTry growing now!",
		"block_input": false,
		"duration": 0.0,
	},
	{
		"id": "resources",
		"text": "Growth absorbs resources:\n  BLUE = Water (+2 GP)\n  BROWN = Minerals (+3 GP)\n  GOLD = Sugars (+1 GP, +growth rate)\nAbsorb a resource to continue.",
		"block_input": false,
		"duration": 0.0,
	},
	{
		"id": "trade",
		"text": "Trees (green cells) trade minerals → sugars.\nApproach a tree, then press 1 / 2 / 3 to trade.\nSugars boost your GP rate!\nClick a tree to select it, then trade.",
		"block_input": false,
		"duration": 0.0,
	},
	{
		"id": "rivals",
		"text": "Three rival fungi compete for territory:\n  RED — aggressive, targets you\n  ORANGE — defensive, expands territory\n  VIOLET — opportunistic, hunts sugars\nWatch the rival stats (top-left panel).",
		"block_input": false,
		"duration": 0.0,
	},
	{
		"id": "advanced",
		"text": "Advanced mechanics:\n  G = Deep Root Pulse (15 GP, regen trades)\n  L = Link two exhausted trees (double trades)\n  U = Unlink trees\n  R = Reset game\n  Esc = Cancel link mode\nGood luck!",
		"block_input": false,
		"duration": 0.0,
	},
]

# ── State ──────────────────────────────────────────────────
var _tutorial_active: bool = false
var _tutorial_complete: bool = false
var _current_step: int = -1
var _step_timer: float = 0.0  # For auto-advance steps

# ── Completion conditions ──────────────────────────────────
# Track gameplay conditions for auto-advancing steps
var _absorbed_at_step_start: int = 0
var _cells_at_step_start: int = 0
var _sugars_at_step_start: int = 0
var _trade_count_at_step_start: int = 0

# ── Signals ────────────────────────────────────────────────
signal tutorial_started
signal tutorial_step_changed(step_idx: int, step_data: Dictionary)
signal tutorial_completed

# ═══════════════════════════════════════════════════════════════
# API
# ═══════════════════════════════════════════════════════════════

func is_tutorial_active() -> bool:
	return _tutorial_active and not _tutorial_complete

func is_input_blocked() -> bool:
	if not _tutorial_active or _tutorial_complete:
		return false
	if _current_step < 0 or _current_step >= STEPS.size():
		return false
	return STEPS[_current_step]["block_input"]

func get_current_step() -> int:
	return _current_step

func get_current_step_data() -> Dictionary:
	if _current_step >= 0 and _current_step < STEPS.size():
		return STEPS[_current_step]
	return {}

func is_complete() -> bool:
	return _tutorial_complete

# ═══════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	_load_config()

func start_tutorial() -> void:
	if _tutorial_complete:
		return
	if _tutorial_active:
		return
	_tutorial_active = true
	_current_step = -1
	_advance_step()
	tutorial_started.emit()

func skip_tutorial() -> void:
	_tutorial_active = false
	_tutorial_complete = true
	_current_step = -1
	_save_config()
	tutorial_completed.emit()

func advance_tutorial() -> void:
	"""Called by main.gd when the player presses a key/click during tutorial."""
	if not _tutorial_active or _tutorial_complete:
		return
	if _current_step < 0:
		return
	var step: Dictionary = STEPS[_current_step]
	if step["block_input"]:
		# Blocking steps advance on any input
		_advance_step()
	# Non-blocking steps auto-advance via _check_conditions

func _process(delta: float) -> void:
	if not _tutorial_active or _tutorial_complete:
		return
	if _current_step < 0 or _current_step >= STEPS.size():
		return

	# Check auto-advance conditions for non-blocking steps
	var step: Dictionary = STEPS[_current_step]
	if not step["block_input"]:
		_check_step_conditions(_current_step)

func _advance_step() -> void:
	_current_step += 1
	if _current_step >= STEPS.size():
		_complete_tutorial()
		return

	var gm := get_node_or_null("/root/GameManager")
	# Snapshot current game state for condition tracking
	if gm:
		_absorbed_at_step_start = gm.player_absorbed
		_cells_at_step_start = gm.player_cells.size()
		_sugars_at_step_start = gm.player_sugars
		_trade_count_at_step_start = _count_trades_used(gm)

	tutorial_step_changed.emit(_current_step, STEPS[_current_step])

# ═══════════════════════════════════════════════════════════════
# CONDITION CHECKING
# ═══════════════════════════════════════════════════════════════

func _check_step_conditions(step_idx: int) -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm == null:
		return

	var step_id: String = STEPS[step_idx]["id"]

	match step_id:
		"grow":
			# Player grew at least 3 new cells
			if gm.player_cells.size() - _cells_at_step_start >= 3:
				_advance_step()

		"resources":
			# Player absorbed at least 1 resource
			if gm.player_absorbed > _absorbed_at_step_start:
				_advance_step()

		"trade":
			# Player completed at least 1 trade (sugars increased)
			if gm.player_sugars > _sugars_at_step_start:
				_advance_step()

		"rivals":
			# Auto-advance after 8 seconds or when player has >30 cells
			if gm.player_cells.size() >= 30:
				_advance_step()

		"advanced":
			# Auto-advance after 12 seconds (informational)
			# We don't auto-advance; player presses any key
			pass

func _count_trades_used(gm) -> int:
	var used: int = 0
	for tree: Dictionary in gm.trees:
		used += gm.MAX_TRADES_PER_TREE - tree["trades_left"]
	return used

func _complete_tutorial() -> void:
	_tutorial_active = false
	_tutorial_complete = true
	_save_config()
	tutorial_completed.emit()

# ═══════════════════════════════════════════════════════════════
# PERSISTENCE
# ═══════════════════════════════════════════════════════════════

func _save_config() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("tutorial", "complete", true)
	var err := cfg.save("user://tutorial_config.cfg")
	if err != OK:
		printerr("TutorialManager: failed to save config, err=%d" % err)

func _load_config() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load("user://tutorial_config.cfg")
	if err == OK:
		_tutorial_complete = cfg.get_value("tutorial", "complete", false)
		if _tutorial_complete:
			print("TutorialManager: tutorial already completed, skipping.")
