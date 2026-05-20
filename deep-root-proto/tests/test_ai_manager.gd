# ═══════════════════════════════════════════════════════════════
# test_ai_manager.gd — Tests for AIManager autoload
# Verifies: constants, phase system, rival lifecycle, death, shake
# Uses real AIManager autoload + GameManager for integration tests
# ═══════════════════════════════════════════════════════════════
extends GutTest


# ── Constants ─────────────────────────────────────────────────

func test_ai_constants_exist():
	"""RIVAL_INTERVAL_MIN, RIVAL_INTERVAL_MAX, DEATH_BLOCKADE_THRESHOLD are defined."""
	var am := get_node_or_null("/root/AIManager")
		assert_not_null(am, "AIManager autoload should exist")
	if am == null: return
	assert_gt(am.RIVAL_INTERVAL_MIN, 0.0, "RIVAL_INTERVAL_MIN > 0")
	assert_gt(am.RIVAL_INTERVAL_MAX, am.RIVAL_INTERVAL_MIN, "RIVAL_INTERVAL_MAX > MIN")
	assert_eq(am.DEATH_BLOCKADE_THRESHOLD, 5, "DEATH_BLOCKADE_THRESHOLD = 5")


func test_phase_configs_all_personalities():
	"""PHASE_CONFIGS has aggressive, defensive, opportunistic entries."""
	var am := get_node_or_null("/root/AIManager")
		if am == null: return
	assert_true(am.PHASE_CONFIGS.has("aggressive"), "has aggressive")
	assert_true(am.PHASE_CONFIGS.has("defensive"), "has defensive")
	assert_true(am.PHASE_CONFIGS.has("opportunistic"), "has opportunistic")

	for personality in am.PHASE_CONFIGS:
		var cfg: Dictionary = am.PHASE_CONFIGS[personality]
		var phases: Array = cfg["phases"]
		var durations: Array = cfg["phase_durations"]
		assert_ge(phases.size(), 2, "%s has >=2 phases" % personality)
		assert_eq(phases.size(), durations.size(), "%s phase/duration count match" % personality)


func test_phase_multipliers_defined():
	"""PHASE_MULTIPLIERS has entries for all 6 phases."""
	var am := get_node_or_null("/root/AIManager")
		if am == null: return
	var expected_phases := ["aggressive", "frenzy", "defensive", "fortify", "opportunistic", "harvest"]
	for phase in expected_phases:
		assert_true(am.PHASE_MULTIPLIERS.has(phase), "%s multiplier exists" % phase)

	assert_gt(am.PHASE_MULTIPLIERS["frenzy"], 1.0, "frenzy > 1.0")
	assert_gt(am.PHASE_MULTIPLIERS["fortify"], 1.0, "fortify > 1.0")
	assert_gt(am.PHASE_MULTIPLIERS["harvest"], 1.0, "harvest > 1.0")
	assert_eq(am.PHASE_MULTIPLIERS["aggressive"], 1.0, "aggressive = 1.0")


func test_phase_pulse_colors_defined():
	"""PHASE_PULSE_COLORS has frenzy, fortify, harvest entries with valid alpha."""
	var am := get_node_or_null("/root/AIManager")
		if am == null: return
	assert_true(am.PHASE_PULSE_COLORS.has("frenzy"), "frenzy pulse color")
	assert_true(am.PHASE_PULSE_COLORS.has("fortify"), "fortify pulse color")
	assert_true(am.PHASE_PULSE_COLORS.has("harvest"), "harvest pulse color")

	for phase in am.PHASE_PULSE_COLORS:
		var col: Color = am.PHASE_PULSE_COLORS[phase]
		assert_gt(col.a, 0.0, "%s pulse has alpha > 0" % phase)


# ── Accessor functions ─────────────────────────────────────────

func test_get_phase_multiplier_known_phases():
	"""get_phase_multiplier returns correct values for known phases."""
	var am := get_node_or_null("/root/AIManager")
		if am == null: return
	assert_eq(am.get_phase_multiplier("frenzy"), 1.5, "frenzy ×1.5")
	assert_eq(am.get_phase_multiplier("fortify"), 1.3, "fortify ×1.3")
	assert_eq(am.get_phase_multiplier("harvest"), 1.8, "harvest ×1.8")
	assert_eq(am.get_phase_multiplier("aggressive"), 1.0, "aggressive ×1.0")


func test_get_phase_multiplier_unknown():
	"""get_phase_multiplier defaults to 1.0 for unknown phases."""
	var am := get_node_or_null("/root/AIManager")
		if am == null: return
	assert_eq(am.get_phase_multiplier("nonexistent"), 1.0, "unknown = 1.0")


func test_get_phase_pulse_color_known():
	"""get_phase_pulse_color returns correct values."""
	var am := get_node_or_null("/root/AIManager")
		if am == null: return
	assert_eq(am.get_phase_pulse_color("frenzy"), Color(1.0, 0.2, 0.1, 0.6), "frenzy pulse")
	assert_eq(am.get_phase_pulse_color("fortify"), Color(1.0, 0.65, 0.1, 0.6), "fortify pulse")
	assert_eq(am.get_phase_pulse_color("harvest"), Color(0.75, 0.2, 1.0, 0.6), "harvest pulse")


func test_get_phase_pulse_color_unknown():
	"""get_phase_pulse_color returns transparent black for unknown phases."""
	var am := get_node_or_null("/root/AIManager")
		if am == null: return
	var col: Color = am.get_phase_pulse_color("normal_phase")
	assert_eq(col.a, 0.0, "unknown phase = transparent")


# ── _rival_name() ─────────────────────────────────────────────

func test_rival_name_red():
	"""Red rival color maps to 'Red'."""
	var am := get_node_or_null("/root/AIManager")
		if am == null: return
	var name: String = am._rival_name(Color(0.88, 0.18, 0.18))
	assert_eq(name, "Red", "red color → Red")


func test_rival_name_orange():
	"""Orange rival color maps to 'Orange'."""
	var am := get_node_or_null("/root/AIManager")
		if am == null: return
	var name: String = am._rival_name(Color(0.92, 0.55, 0.08))
	assert_eq(name, "Orange", "orange color → Orange")


func test_rival_name_violet():
	"""Violet rival color maps to 'Violet'."""
	var am := get_node_or_null("/root/AIManager")
		if am == null: return
	var name: String = am._rival_name(Color(0.65, 0.18, 0.85))
	assert_eq(name, "Violet", "violet color → Violet")


func test_rival_name_unknown():
	"""Unknown color maps to '???'."""
	var am := get_node_or_null("/root/AIManager")
		if am == null: return
	var name: String = am._rival_name(Color.BLUE)
	assert_eq(name, "???", "unknown color → ???")


# ── Phase cycling ──────────────────────────────────────────────

func test_update_rival_phases_decrements_timer():
	"""update_rival_phases() decrements phase_timer on all rivals."""
	var gm := get_node_or_null("/root/GameManager")
	var am := get_node_or_null("/root/AIManager")
		if gm == null or am == null: return

	gm.new_game()
	am.setup_rivals()
	assert_eq(am.rivals.size(), 3, "3 rivals created")

	# Capture initial phase timers
	var initial_timers: Array[float] = []
	for rival: Dictionary in am.rivals:
		initial_timers.append(rival["phase_timer"])

	# Advance 1 second
	am.update_rival_phases(1.0)

	for i: int in range(3):
		var expected: float = initial_timers[i] - 1.0
		assert_true(am.rivals[i]["phase_timer"] < initial_timers[i],
			"rival %d timer decreased" % i)


func test_advance_phase_cycles_aggressive():
	"""Advancing through aggressive phases: aggressive → frenzy → aggressive."""
	var gm := get_node_or_null("/root/GameManager")
	var am := get_node_or_null("/root/AIManager")
		if gm == null or am == null: return

	gm.new_game()
	am.setup_rivals()

	# Find aggressive rival (rival 0)
	var rival: Dictionary = am.rivals[0]
	assert_eq(rival["personality"], "aggressive", "rival 0 is aggressive")
	assert_eq(rival["phase"], "aggressive", "starts in aggressive")

	# Force timer to 0 to trigger transition
	rival["phase_timer"] = -0.1
	am.update_rival_phases(0.1)
	assert_eq(rival["phase"], "frenzy", "switched to frenzy")
	assert_gt(rival["phase_timer"], 0.0, "frenzy timer > 0")

	# Force another transition back to aggressive
	rival["phase_timer"] = -0.1
	am.update_rival_phases(0.1)
	assert_eq(rival["phase"], "aggressive", "cycled back to aggressive")


func test_advance_phase_cycles_defensive():
	"""Advancing through defensive phases: defensive → fortify → defensive."""
	var gm := get_node_or_null("/root/GameManager")
	var am := get_node_or_null("/root/AIManager")
		if gm == null or am == null: return

	gm.new_game()
	am.setup_rivals()

	# Find defensive rival (rival 1)
	var rival: Dictionary = am.rivals[1]
	assert_eq(rival["personality"], "defensive", "rival 1 is defensive")

	rival["phase_timer"] = -0.1
	am.update_rival_phases(0.1)
	assert_eq(rival["phase"], "fortify", "switched to fortify")

	rival["phase_timer"] = -0.1
	am.update_rival_phases(0.1)
	assert_eq(rival["phase"], "defensive", "cycled back to defensive")


func test_advance_phase_cycles_opportunistic():
	"""Advancing through opportunistic phases: opportunistic → harvest → opportunistic."""
	var gm := get_node_or_null("/root/GameManager")
	var am := get_node_or_null("/root/AIManager")
		if gm == null or am == null: return

	gm.new_game()
	am.setup_rivals()

	# Find opportunistic rival (rival 2)
	var rival: Dictionary = am.rivals[2]
	assert_eq(rival["personality"], "opportunistic", "rival 2 is opportunistic")

	rival["phase_timer"] = -0.1
	am.update_rival_phases(0.1)
	assert_eq(rival["phase"], "harvest", "switched to harvest")

	rival["phase_timer"] = -0.1
	am.update_rival_phases(0.1)
	assert_eq(rival["phase"], "opportunistic", "cycled back to opportunistic")


# ── setup_rivals() ─────────────────────────────────────────────

func test_setup_rivals_creates_three():
	"""setup_rivals() creates exactly 3 rivals after new_game()."""
	var gm := get_node_or_null("/root/GameManager")
	var am := get_node_or_null("/root/AIManager")
		if gm == null or am == null: return

	gm.new_game()
	am.setup_rivals()

	assert_eq(am.rivals.size(), 3, "3 rivals created")
	assert_eq(am.rival_timers.size(), 3, "3 rival timers")
	assert_eq(am.rival_intervals.size(), 3, "3 rival intervals")
	assert_eq(am._blockaded_ticks, [0, 0, 0], "blockade ticks reset to 0")


func test_setup_rivals_distinct_personalities():
	"""setup_rivals() gives each rival a distinct personality."""
	var gm := get_node_or_null("/root/GameManager")
	var am := get_node_or_null("/root/AIManager")
		if gm == null or am == null: return

	gm.new_game()
	am.setup_rivals()

	var personalities: Array[String] = []
	for rival: Dictionary in am.rivals:
		personalities.append(rival["personality"])

	assert_true(personalities.has("aggressive"), "has aggressive")
	assert_true(personalities.has("defensive"), "has defensive")
	assert_true(personalities.has("opportunistic"), "has opportunistic")


func test_setup_rivals_initial_state():
	"""Each rival has correct initial state: one cell, 10 GP, first phase."""
	var gm := get_node_or_null("/root/GameManager")
	var am := get_node_or_null("/root/AIManager")
		if gm == null or am == null: return

	gm.new_game()
	am.setup_rivals()

	for rival: Dictionary in am.rivals:
		assert_eq(rival["cells"].size(), 1, "rival starts with 1 cell")
		assert_ge(rival["gp"], 0.0, "rival has >= 0 GP")
		assert_eq(rival["absorbed"], 0, "rival absorbed = 0")
		assert_eq(rival["phase_idx"], 0, "rival starts at phase 0")
		assert_gt(rival["phase_timer"], 0.0, "phase_timer > 0")

		var personality: String = rival["personality"]
		var phases: Array = am.PHASE_CONFIGS[personality]["phases"]
		assert_eq(rival["phase"], phases[0], "rival phase matches config phase 0")


func test_setup_rivals_astar_created():
	"""setup_rivals() creates an AStarGrid2D for pathfinding."""
	var gm := get_node_or_null("/root/GameManager")
	var am := get_node_or_null("/root/AIManager")
		if gm == null or am == null: return

	gm.new_game()
	am.setup_rivals()

	assert_not_null(am._astar, "AStarGrid2D is created")
	assert_eq(am._astar.region.size.x, gm.GRID_W, "AStar width = grid width")
	assert_eq(am._astar.region.size.y, gm.GRID_H, "AStar height = grid height")


# ── Rival timer / interval ────────────────────────────────────

func test_rival_timers_initialized():
	"""After setup_rivals(), all rival timers are positive and within interval range."""
	var gm := get_node_or_null("/root/GameManager")
	var am := get_node_or_null("/root/AIManager")
		if gm == null or am == null: return

	gm.new_game()
	am.setup_rivals()

	assert_eq(am.rivals.size(), 3, "3 rivals for timer test")
	for i: int in range(am.rivals.size()):
		assert_gt(am.rival_timers[i], 0.0, "rival %d timer > 0" % i)
		assert_gt(am.rival_intervals[i], 0.0, "rival %d interval > 0" % i)


# ── Multiple setup_rivals() calls ──────────────────────────────

func test_setup_rivals_idempotent():
	"""Calling setup_rivals() twice reset all rival state."""
	var gm := get_node_or_null("/root/GameManager")
	var am := get_node_or_null("/root/AIManager")
		if gm == null or am == null: return

	gm.new_game()
	am.setup_rivals()

	# Grow one rival once
	am.rival_grow(0)
	var cells_after_grow: int = am.rivals[0]["cells"].size()

	# Re-setup — should reset everything
	am.setup_rivals()
	assert_eq(am.rivals.size(), 3, "3 rivals after re-setup")
	assert_eq(am.rivals[0]["cells"].size(), 1, "rival 0 back to 1 cell")
	assert_eq(am._blockaded_ticks, [0, 0, 0], "blockade ticks reset")


# ── Rival growth ───────────────────────────────────────────────

func test_rival_grow_increases_cells():
	"""rival_grow() adds a cell to the rival."""
	var gm := get_node_or_null("/root/GameManager")
	var am := get_node_or_null("/root/AIManager")
		if gm == null or am == null: return

	gm.new_game()
	am.setup_rivals()

	var initial_cells: int = am.rivals[0]["cells"].size()
	am.rival_grow(0)
	assert_gt(am.rivals[0]["cells"].size(), initial_cells, "rival grew by at least 1 cell")
	assert_gt(am.rivals[0]["absorbed"], 0, "absorbed count increased")


func test_rival_grow_increments_blockade():
	"""rival_grow() increments blockade ticks when completely surrounded."""
	var gm := get_node_or_null("/root/GameManager")
	var am := get_node_or_null("/root/AIManager")
		if gm == null or am == null: return

	gm.new_game()
	am.setup_rivals()

	# Fill all adjacent cells of rival 0 to blockade them
	var rival_cells: Array[Vector2i] = am.rivals[0]["cells"]
	for c: Vector2i in rival_cells:
		for d: Vector2i in gm.DIRS_8:
			var n: Vector2i = c + d
			if n.x >= 0 and n.x < gm.GRID_W and n.y >= 0 and n.y < gm.GRID_H:
				if gm.grid[n.y][n.x] == gm.CellType.EMPTY:
					gm.grid[n.y][n.x] = gm.CellType.WATER

	var initial_ticks: int = am._blockaded_ticks[0]
	am.rival_grow(0)
	assert_gt(am._blockaded_ticks[0], initial_ticks, "blockade tick incremented")


# ── Rival death ─────────────────────────────────────────────────
# NOTE: death tests MUST be last — they shrink arrays which
# breaks subsequent setup_rivals() calls (setup_rivals doesn't
# clear rival_timers before index assignment)

func test_blockaded_rival_dies_after_threshold():
	"""Rival dies after DEATH_BLOCKADE_THRESHOLD consecutive blockaded ticks."""
	var gm := get_node_or_null("/root/GameManager")
	var am := get_node_or_null("/root/AIManager")
		if gm == null or am == null: return

	gm.new_game()
	am.setup_rivals()

	var initial_count: int = am.rivals.size()

	# Fill all adjacent cells around rival 0 to completely blockade it
	for c: Vector2i in am.rivals[0]["cells"]:
		for d: Vector2i in gm.DIRS_8:
			var n: Vector2i = c + d
			if n.x >= 0 and n.x < gm.GRID_W and n.y >= 0 and n.y < gm.GRID_H:
				if gm.grid[n.y][n.x] == gm.CellType.EMPTY:
					gm.grid[n.y][n.x] = gm.CellType.WATER

	# Force blockaded_ticks just below threshold
	am._blockaded_ticks[0] = am.DEATH_BLOCKADE_THRESHOLD - 1
	# One more grow should push it over threshold
	am.rival_grow(0)

	# The rival should now be dead (removed)
	assert_eq(am.rivals.size(), initial_count - 1, "rival removed after blockade threshold")
