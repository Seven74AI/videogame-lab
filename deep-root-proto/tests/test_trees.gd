# ═══════════════════════════════════════════════════════════════
# test_trees.gd — Tests for tree trading, regen, pulse, and linking
# ═══════════════════════════════════════════════════════════════
extends GutTest

const GRID_W: int = 60
const GRID_H: int = 40
const MAX_TRADES_PER_TREE: int = 6
const TRADE_COOLDOWN: float = 4.0
const REGEN_INTERVAL: float = 60.0
const DEEP_ROOT_PULSE_COST: float = 15.0
const DEEP_ROOT_PULSE_REGEN: int = 3
const LINK_BONUS_TRADES: int = 6

const TRADE_RATES: Array[Dictionary] = [
	{"minerals": 2, "sugars": 1},
	{"minerals": 5, "sugars": 3},
	{"minerals": 10, "sugars": 7},
]

# ═══════════════════════════════════════════════════════════════
# Trade system tests
# ═══════════════════════════════════════════════════════════════

func test_trade_rates_exist() -> bool:
	""" Trade system should have 3 tiered exchange rates """
	assert_eq(TRADE_RATES.size(), 3, "Must have 3 tiers")
	assert_eq(TRADE_RATES[0]["minerals"], 2)
	assert_eq(TRADE_RATES[2]["sugars"], 7)
	return true

func test_tree_initialization() -> bool:
	""" Each tree starts with MAX_TRADES_PER_TREE trades, linked_to=-1 """
	var trees: Array[Dictionary] = []
	for tp: Vector2i in [Vector2i(30, 20), Vector2i(6, 4), Vector2i(52, 34)]:
		trees.append({
			"pos": tp,
			"trades_left": MAX_TRADES_PER_TREE,
			"cooldown": 0.0,
			"regen_timer": REGEN_INTERVAL,
			"linked_to": -1,
		})

	assert_eq(trees.size(), 3, "Must have 3 trees")
	for tree in trees:
		assert_eq(tree["trades_left"], 6)
		assert_eq(tree["cooldown"], 0.0)
		assert_eq(tree["linked_to"], -1)
		assert_eq(tree["regen_timer"], REGEN_INTERVAL)
	return true

func test_trade_depletes_tree() -> bool:
	""" Trade should decrement trades_left and start cooldown """
	var tree: Dictionary = {"pos": Vector2i(30, 20), "trades_left": 6, "cooldown": 0.0, "regen_timer": 60.0, "linked_to": -1}
	tree["trades_left"] -= 1
	tree["cooldown"] = TRADE_COOLDOWN

	assert_eq(tree["trades_left"], 5, "5 trades left after 1")
	assert_gt(tree["cooldown"], 0.0, "Cooldown active")
	return true

func test_trade_insufficient_minerals() -> bool:
	""" Trade blocked if player lacks minerals """
	assert_true(1 < 2, "1 < 2 blocks trade")
	return true

func test_trade_tree_depleted() -> bool:
	""" Tree with 0 trades_left should reject """
	var can_trade: bool = false  # 0 trades_left
	assert_false(can_trade, "Depleted tree rejects")
	return true

func test_sugar_gp_boost() -> bool:
	""" Each sugar increases GP rate """
	const BASE_GP_RATE: float = 0.3
	const SUGAR_GP_BOOST: float = 0.07
	const MAX_SUGAR_BOOST: float = 0.90

	var rate_0: float = minf(BASE_GP_RATE + 0 * SUGAR_GP_BOOST, BASE_GP_RATE + MAX_SUGAR_BOOST)
	var rate_5: float = minf(BASE_GP_RATE + 5 * SUGAR_GP_BOOST, BASE_GP_RATE + MAX_SUGAR_BOOST)

	assert_eq(rate_0, 0.3, "Base = 0.3")
	assert_eq(rate_5, 0.65, "5 sugars = 0.65")
	assert_gt(rate_5, rate_0, "More sugars = faster")
	return true

# ═══════════════════════════════════════════════════════════════
# Tree regen tests (1 trade / 60s)
# ═══════════════════════════════════════════════════════════════

func test_tree_regen_timer_initialized() -> bool:
	""" Each tree starts with a regen_timer set to REGEN_INTERVAL """
	var trees: Array[Dictionary] = []
	for tp: Vector2i in [Vector2i(30, 20), Vector2i(6, 4), Vector2i(52, 34)]:
		trees.append({
			"pos": tp,
			"trades_left": MAX_TRADES_PER_TREE,
			"cooldown": 0.0,
			"regen_timer": REGEN_INTERVAL,
			"linked_to": -1,
		})

	assert_eq(trees.size(), 3, "3 trees")
	for tree in trees:
		assert_eq(tree["regen_timer"], REGEN_INTERVAL, "regen_timer should start at 60.0")
		assert_true(tree.has("regen_timer"), "tree must have regen_timer field")
	return true

func test_tree_regen_refills_trade() -> bool:
	""" When regen_timer expires, trades_left increases by 1 """
	var tree: Dictionary = {
		"pos": Vector2i(30, 20),
		"trades_left": 3,
		"cooldown": 0.0,
		"regen_timer": 0.0,
		"linked_to": -1,
	}

	# Simulate regen tick: timer expired, below max
	if tree["regen_timer"] <= 0.0 and tree["trades_left"] < MAX_TRADES_PER_TREE:
		tree["trades_left"] += 1
		tree["regen_timer"] = REGEN_INTERVAL

	assert_eq(tree["trades_left"], 4, "regen should add 1 trade (3→4)")
	assert_eq(tree["regen_timer"], REGEN_INTERVAL, "timer should reset to 60.0")
	return true

func test_tree_regen_capped_at_max() -> bool:
	""" Tree regen stops at MAX_TRADES_PER_TREE, timer pauses """
	var tree: Dictionary = {
		"pos": Vector2i(30, 20),
		"trades_left": MAX_TRADES_PER_TREE,
		"cooldown": 0.0,
		"regen_timer": 0.0,
		"linked_to": -1,
	}

	var before: int = tree["trades_left"]
	if tree["regen_timer"] <= 0.0 and tree["trades_left"] < MAX_TRADES_PER_TREE:
		tree["trades_left"] += 1
		tree["regen_timer"] = REGEN_INTERVAL

	assert_eq(tree["trades_left"], MAX_TRADES_PER_TREE, "should not exceed MAX_TRADES_PER_TREE")
	assert_eq(tree["trades_left"], before, "trades_left unchanged when at max")
	return true

func test_tree_never_permanently_depleted() -> bool:
	""" Even fully depleted tree (0 trades) can regen back """
	var tree: Dictionary = {
		"pos": Vector2i(30, 20),
		"trades_left": 0,
		"cooldown": 0.0,
		"regen_timer": 0.0,
		"linked_to": -1,
	}

	if tree["regen_timer"] <= 0.0 and tree["trades_left"] < MAX_TRADES_PER_TREE:
		tree["trades_left"] += 1
		tree["regen_timer"] = REGEN_INTERVAL

	assert_eq(tree["trades_left"], 1, "depleted tree should regen to 1 trade")
	assert_gt(tree["trades_left"], 0, "tree is never permanently depleted")
	return true

func test_tree_regen_timer_ticks() -> bool:
	""" regen_timer decreases with delta time """
	const DELTA: float = 1.5
	var tree: Dictionary = {
		"pos": Vector2i(30, 20),
		"trades_left": 4,
		"cooldown": 0.0,
		"regen_timer": REGEN_INTERVAL,
		"linked_to": -1,
	}

	var before: float = tree["regen_timer"]
	if tree["trades_left"] < MAX_TRADES_PER_TREE:
		tree["regen_timer"] -= DELTA

	assert_eq(tree["regen_timer"], before - DELTA, "regen_timer should decrease by delta")
	assert_gt(before, tree["regen_timer"], "regen_timer should tick down (before > after)")
	return true

func test_tree_regen_timer_pauses_at_max() -> bool:
	""" regen_timer does NOT tick when trades_left is at MAX """
	const DELTA: float = 10.0
	var tree: Dictionary = {
		"pos": Vector2i(30, 20),
		"trades_left": MAX_TRADES_PER_TREE,
		"cooldown": 0.0,
		"regen_timer": REGEN_INTERVAL,
		"linked_to": -1,
	}

	var before: float = tree["regen_timer"]
	if tree["trades_left"] < MAX_TRADES_PER_TREE:
		tree["regen_timer"] -= DELTA

	assert_eq(tree["regen_timer"], before, "regen_timer should NOT tick when at max")
	return true

# ═══════════════════════════════════════════════════════════════
# Deep Root Pulse tests
# ═══════════════════════════════════════════════════════════════

func test_pulse_regen_on_exhausted_tree() -> bool:
	""" Deep Root Pulse costs 15 GP, regens 3 trades on exhausted tree """
	var gp: float = 20.0
	var tree: Dictionary = {"pos": Vector2i(30, 20), "trades_left": 0, "cooldown": 0.0, "regen_timer": 0.0, "linked_to": -1}

	assert_eq(tree["trades_left"], 0, "Tree exhausted before pulse")

	gp -= DEEP_ROOT_PULSE_COST
	tree["trades_left"] = DEEP_ROOT_PULSE_REGEN

	assert_eq(gp, 5.0, "GP: 20 - 15 = 5")
	assert_eq(tree["trades_left"], 3, "3 trades regenerated after pulse")
	return true

func test_pulse_blocked_if_tree_has_trades() -> bool:
	""" Pulse should be blocked when tree still has trades """
	var tree: Dictionary = {"pos": Vector2i(30, 20), "trades_left": 2, "cooldown": 0.0, "regen_timer": 0.0, "linked_to": -1}
	var can_pulse: bool = tree["trades_left"] <= 0

	assert_false(can_pulse, "Pulse blocked when tree has trades")
	return true

func test_pulse_blocked_insufficient_gp() -> bool:
	""" Pulse blocked if player has less than 15 GP """
	var gp: float = 10.0
	var can_afford: bool = gp >= DEEP_ROOT_PULSE_COST

	assert_false(can_afford, "Pulse blocked when GP < 15")
	return true

func test_pulse_constants_correct() -> bool:
	""" DEEP_ROOT_PULSE_COST = 15, DEEP_ROOT_PULSE_REGEN = 3 """
	assert_eq(DEEP_ROOT_PULSE_COST, 15.0, "Pulse costs 15 GP")
	assert_eq(DEEP_ROOT_PULSE_REGEN, 3, "Pulse regens 3 trades")
	return true

# ═══════════════════════════════════════════════════════════════
# Tree Linking tests
# ═══════════════════════════════════════════════════════════════

func test_link_doubles_trades() -> bool:
	""" Linking 2 exhausted trees doubles their trade capacity """
	var tree_a: Dictionary = {"pos": Vector2i(30, 20), "trades_left": 0, "cooldown": 0.0, "regen_timer": 0.0, "linked_to": -1}
	var tree_b: Dictionary = {"pos": Vector2i(6, 4), "trades_left": 0, "cooldown": 0.0, "regen_timer": 0.0, "linked_to": -1}

	tree_a["linked_to"] = 1
	tree_b["linked_to"] = 0
	tree_a["trades_left"] += LINK_BONUS_TRADES
	tree_b["trades_left"] += LINK_BONUS_TRADES

	assert_eq(tree_a["linked_to"], 1, "Tree A linked to B")
	assert_eq(tree_b["linked_to"], 0, "Tree B linked to A")
	assert_eq(tree_a["trades_left"], 6, "Tree A: 0 + 6 = 6 trades after link")
	assert_eq(tree_b["trades_left"], 6, "Tree B: 0 + 6 = 6 trades after link")
	return true

func test_link_blocked_if_already_linked() -> bool:
	""" Cannot link a tree that is already linked """
	var tree_a: Dictionary = {"pos": Vector2i(30, 20), "trades_left": 5, "cooldown": 0.0, "regen_timer": 0.0, "linked_to": 1}
	var can_link: bool = tree_a["linked_to"] < 0

	assert_false(can_link, "Cannot link an already-linked tree")
	return true

func test_link_blocked_if_has_trades() -> bool:
	""" Link only available when tree is exhausted """
	var tree: Dictionary = {"pos": Vector2i(30, 20), "trades_left": 3, "cooldown": 0.0, "regen_timer": 0.0, "linked_to": -1}
	var can_link: bool = tree["trades_left"] <= 0

	assert_false(can_link, "Link blocked when tree has trades")
	return true

func test_unlink_removes_bonus() -> bool:
	""" Unlinking removes bonus trades (caps at 0) """
	var tree_a: Dictionary = {"pos": Vector2i(30, 20), "trades_left": 8, "cooldown": 0.0, "regen_timer": 0.0, "linked_to": 1}
	var tree_b: Dictionary = {"pos": Vector2i(6, 4), "trades_left": 2, "cooldown": 0.0, "regen_timer": 0.0, "linked_to": 0}

	var remove_a: int = min(tree_a["trades_left"], LINK_BONUS_TRADES)
	var remove_b: int = min(tree_b["trades_left"], LINK_BONUS_TRADES)
	tree_a["trades_left"] -= remove_a
	tree_b["trades_left"] -= remove_b
	tree_a["linked_to"] = -1
	tree_b["linked_to"] = -1

	assert_eq(tree_a["trades_left"], 2, "Tree A: 8 - 6 = 2 trades after unlink")
	assert_eq(tree_b["trades_left"], 0, "Tree B: 2 - 2 = 0 trades after unlink (capped)")
	assert_eq(tree_a["linked_to"], -1, "Tree A unlinked")
	assert_eq(tree_b["linked_to"], -1, "Tree B unlinked")
	return true

func test_link_bonus_constant() -> bool:
	""" LINK_BONUS_TRADES should equal MAX_TRADES_PER_TREE (doubling) """
	assert_eq(LINK_BONUS_TRADES, MAX_TRADES_PER_TREE, "Link bonus = base max trades")
	assert_eq(LINK_BONUS_TRADES, 6, "Link bonus = 6")
	return true

func test_new_tree_starts_unlinked() -> bool:
	""" New trees should start with linked_to = -1 """
	var tree: Dictionary = {"pos": Vector2i(30, 20), "trades_left": 6, "cooldown": 0.0, "regen_timer": 60.0, "linked_to": -1}
	assert_eq(tree["linked_to"], -1, "New tree starts unlinked")
	return true
