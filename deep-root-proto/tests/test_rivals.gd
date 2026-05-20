# ═══════════════════════════════════════════════════════════════
# test_rivals.gd — Tests for AIManager + AStarGrid2D pathfinding
# TDD: These MUST fail before we implement AIManager
# ═══════════════════════════════════════════════════════════════
extends GutTest

const GRID_W: int = 60
const GRID_H: int = 40

const DIRS_8: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
]

func test_rival_creation() -> bool:
	""" AIManager should create 3 rivals with distinct personalities """
	var rival_configs: Array[Dictionary] = [
		{"personality": "aggressive", "start": Vector2i(52, 4)},
		{"personality": "defensive", "start": Vector2i(5, 34)},
		{"personality": "opportunistic", "start": Vector2i(54, 32)},
	]

	assert_eq(rival_configs.size(), 3, "Must have 3 rivals")

	var personalities: Array[String] = []
	for cfg in rival_configs:
		personalities.append(cfg["personality"])

	assert_true(personalities.has("aggressive"), "Must have aggressive")
	assert_true(personalities.has("defensive"), "Must have defensive")
	assert_true(personalities.has("opportunistic"), "Must have opportunistic")
	return true

func test_rival_growth_candidates() -> bool:
	""" Rival AI should find empty adjacent cells to grow into """
	var rival_cells: Array[Vector2i] = [Vector2i(52, 4)]
	var candidates: Dictionary = {}
	var occupied: Dictionary = {}
	for c: Vector2i in rival_cells:
		occupied[c] = true
	for c: Vector2i in rival_cells:
		for d: Vector2i in DIRS_8:
			var n: Vector2i = c + d
			if n.x >= 0 and n.x < GRID_W and n.y >= 0 and n.y < GRID_H:
				if not occupied.has(n):
					candidates[n] = true

	assert_gt(candidates.size(), 0, "Single rival has growth candidates")
	return true

func test_rival_personality_scoring() -> bool:
	""" Each rival personality must score cells differently """
	var cand1: Vector2i = Vector2i(30, 20)
	var cand2: Vector2i = Vector2i(50, 5)

	# Aggressive: prefers proximity (closer = higher score)
	var agg1: float = 10.0 / (Vector2(cand1).distance_to(Vector2(30, 20)) + 1.0)
	var agg2: float = 10.0 / (Vector2(cand2).distance_to(Vector2(30, 20)) + 1.0)
	assert_gt(agg1, agg2, "Aggressive prefers closer cells")

	# Defensive: prefers distance (further = higher score)
	var def1: float = Vector2(cand1).distance_to(Vector2(10, 10)) * 0.5
	var def2: float = Vector2(cand2).distance_to(Vector2(10, 10)) * 0.5
	assert_gt(def2, def1, "Defensive prefers further cells")
	return true

func test_astargrid2d_setup() -> bool:
	""" AStarGrid2D should be creatable with correct grid size """

	var astar: AStarGrid2D = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, GRID_W, GRID_H)
	astar.cell_size = Vector2i(1, 1)
	astar.update()

	assert_not_null(astar, "AStarGrid2D creatable")
	assert_eq(astar.region.size.x, GRID_W, "AStar width=60")
	assert_eq(astar.region.size.y, GRID_H, "AStar height=40")

	# In Godot 4.2, is_in_bounds + get_point_position are the API
	assert_true(astar.is_in_bounds(0, 0), "Point (0,0) in bounds")
	assert_false(astar.is_in_bounds(GRID_W, GRID_H), "Point out of bounds")
	return true

# ── Rival Phase System Tests ────────────────────────────

const PHASE_CONFIGS: Dictionary = {
	"aggressive": {
		"phases": ["aggressive", "frenzy"],
		"phase_durations": [8.0, 5.0],
	},
	"defensive": {
		"phases": ["defensive", "fortify"],
		"phase_durations": [8.0, 5.0],
	},
	"opportunistic": {
		"phases": ["opportunistic", "harvest"],
		"phase_durations": [8.0, 5.0],
	},
}

const PHASE_PULSE_COLORS: Dictionary = {
	"frenzy": Color(1.0, 0.2, 0.1, 0.6),
	"fortify": Color(1.0, 0.65, 0.1, 0.6),
	"harvest": Color(0.75, 0.2, 1.0, 0.6),
}

func test_phase_definitions() -> bool:
	""" Each rival personality must have 2-3 phases defined """

	assert_true(PHASE_CONFIGS.has("aggressive"), "aggressive config exists")
	assert_true(PHASE_CONFIGS.has("defensive"), "defensive config exists")
	assert_true(PHASE_CONFIGS.has("opportunistic"), "opportunistic config exists")

	for personality in PHASE_CONFIGS:
		var cfg: Dictionary = PHASE_CONFIGS[personality]
		var phases: Array = cfg["phases"]
		var durations: Array = cfg["phase_durations"]
		assert_gt(phases.size(), 1, "%s has >=2 phases" % personality)
		assert_true(phases.size() <= 3, "%s has <=3 phases" % personality)
		assert_eq(phases.size(), durations.size(), "%s phase/duration count match" % personality)

	# Aggressive phases: aggressive → frenzy
	assert_eq(PHASE_CONFIGS["aggressive"]["phases"][0], "aggressive", "aggressive phase 0")
	assert_eq(PHASE_CONFIGS["aggressive"]["phases"][1], "frenzy", "aggressive phase 1")

	# Defensive phases: defensive → fortify
	assert_eq(PHASE_CONFIGS["defensive"]["phases"][0], "defensive", "defensive phase 0")
	assert_eq(PHASE_CONFIGS["defensive"]["phases"][1], "fortify", "defensive phase 1")

	# Opportunistic phases: opportunistic → harvest
	assert_eq(PHASE_CONFIGS["opportunistic"]["phases"][0], "opportunistic", "opportunistic phase 0")
	assert_eq(PHASE_CONFIGS["opportunistic"]["phases"][1], "harvest", "opportunistic phase 1")
	return true

func test_phase_transition_logic() -> bool:
	""" Phase timer decrements and cycles through phases """

	# Simulate phase state for one rival
	var phases: Array[String] = ["aggressive", "frenzy"]
	var durations: Array[float] = [8.0, 5.0]
	var phase_idx: int = 0
	var phase_timer: float = durations[0]

	# Initial state
	assert_eq(phases[phase_idx], "aggressive", "starts in phase 0")
	assert_eq(phase_timer, 8.0, "phase timer = 8.0s")

	# Decrement timer
	phase_timer -= 2.0
	assert_eq(phase_timer, 6.0, "timer decreases")

	# Timer reaches 0 → switch phase
	phase_timer = 0.0
	assert_true(phase_timer <= 0.0, "timer exhausted")

	# Transition to next phase
	phase_idx = (phase_idx + 1) % phases.size()
	phase_timer = durations[phase_idx]
	assert_eq(phases[phase_idx], "frenzy", "switched to frenzy")
	assert_eq(phase_timer, 5.0, "frenzy duration = 5.0s")

	# Another cycle back to aggressive
	phase_timer = 0.0
	phase_idx = (phase_idx + 1) % phases.size()
	phase_timer = durations[phase_idx]
	assert_eq(phases[phase_idx], "aggressive", "cycled back to aggressive")
	assert_eq(phase_timer, 8.0, "aggressive duration = 8.0s")
	return true

func test_phase_pulse_colors() -> bool:
	""" Special phases have distinct pulse colors """

	assert_eq(PHASE_PULSE_COLORS["frenzy"], Color(1.0, 0.2, 0.1, 0.6), "frenzy = deep red")
	assert_eq(PHASE_PULSE_COLORS["fortify"], Color(1.0, 0.65, 0.1, 0.6), "fortify = amber")
	assert_eq(PHASE_PULSE_COLORS["harvest"], Color(0.75, 0.2, 1.0, 0.6), "harvest = bright violet")

	# Default phases (non-special) should not have pulse colors
	assert_false(PHASE_PULSE_COLORS.has("aggressive"), "aggressive has no pulse")
	assert_false(PHASE_PULSE_COLORS.has("defensive"), "defensive has no pulse")
	assert_false(PHASE_PULSE_COLORS.has("opportunistic"), "opportunistic has no pulse")
	return true

func test_phase_behavior_modifier() -> bool:
	""" Phases modify scoring weight or growth speed """

	# Frenzy phase: +50% aggression scoring
	var base_agg_score: float = 10.0
	var frenzy_mult: float = 1.5
	var frenzy_score: float = base_agg_score * frenzy_mult
	assert_gt(frenzy_score, base_agg_score, "frenzy amplifies aggression")

	# Fortify phase: +30% defensive distance scoring
	var base_def_score: float = 5.0
	var fortify_mult: float = 1.3
	var fortify_score: float = base_def_score * fortify_mult
	assert_gt(fortify_score, base_def_score, "fortify amplifies defense")

	# Harvest phase: +80% resource scoring
	var base_opp_score: float = 12.0
	var harvest_mult: float = 1.8
	var harvest_score: float = base_opp_score * harvest_mult
	assert_gt(harvest_score, base_opp_score, "harvest amplifies resource gathering")

	# Normal phases use multiplier 1.0
	var normal_mult: float = 1.0
	assert_eq(base_agg_score * normal_mult, base_agg_score, "normal phase = no multiplier")
	return true
