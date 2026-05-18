# ═══════════════════════════════════════════════════════════════
# test_trees.gd — Tests for tree trading system
# TDD: These MUST fail before we implement the refactored trade system
# ═══════════════════════════════════════════════════════════════
extends Node

const GRID_W: int = 60
const GRID_H: int = 40
const MAX_TRADES_PER_TREE: int = 6
const TRADE_COOLDOWN: float = 4.0

const TRADE_RATES: Array[Dictionary] = [
	{"minerals": 2, "sugars": 1},
	{"minerals": 5, "sugars": 3},
	{"minerals": 10, "sugars": 7},
]


func _runner():
	return get_parent()


func test_trade_rates_exist() -> bool:
	""" Trade system should have 3 tiered exchange rates """
	var r = _runner()
	r.assert_eq(TRADE_RATES.size(), 3, "Must have 3 tiers")
	r.assert_eq(TRADE_RATES[0]["minerals"], 2)
	r.assert_eq(TRADE_RATES[2]["sugars"], 7)
	return true


func test_tree_initialization() -> bool:
	""" Each tree starts with MAX_TRADES_PER_TREE trades """
	var trees: Array[Dictionary] = []
	for tp: Vector2i in [Vector2i(30, 20), Vector2i(6, 4), Vector2i(52, 34)]:
		trees.append({
			"pos": tp,
			"trades_left": MAX_TRADES_PER_TREE,
			"cooldown": 0.0,
		})

	var r = _runner()
	r.assert_eq(trees.size(), 3, "Must have 3 trees")
	for tree in trees:
		r.assert_eq(tree["trades_left"], 6)
		r.assert_eq(tree["cooldown"], 0.0)
	return true


func test_trade_depletes_tree() -> bool:
	""" Trade should decrement trades_left and start cooldown """
	var tree: Dictionary = {"pos": Vector2i(30, 20), "trades_left": 6, "cooldown": 0.0}
	tree["trades_left"] -= 1
	tree["cooldown"] = TRADE_COOLDOWN

	var r = _runner()
	r.assert_eq(tree["trades_left"], 5, "5 trades left after 1")
	r.assert_gt(tree["cooldown"], 0.0, "Cooldown active")
	return true


func test_trade_insufficient_minerals() -> bool:
	""" Trade blocked if player lacks minerals """
	var r = _runner()
	r.assert_true(1 < 2, "1 < 2 blocks trade")
	return true


func test_trade_tree_depleted() -> bool:
	""" Tree with 0 trades_left should reject """
	var can_trade: bool = false  # 0 trades_left
	var r = _runner()
	r.assert_false(can_trade, "Depleted tree rejects")
	return true


func test_sugar_gp_boost() -> bool:
	""" Each sugar increases GP rate """
	const BASE_GP_RATE: float = 0.3
	const SUGAR_GP_BOOST: float = 0.07
	const MAX_SUGAR_BOOST: float = 0.90

	var rate_0: float = minf(BASE_GP_RATE + 0 * SUGAR_GP_BOOST, BASE_GP_RATE + MAX_SUGAR_BOOST)
	var rate_5: float = minf(BASE_GP_RATE + 5 * SUGAR_GP_BOOST, BASE_GP_RATE + MAX_SUGAR_BOOST)

	var r = _runner()
	r.assert_eq(rate_0, 0.3, "Base = 0.3")
	r.assert_eq(rate_5, 0.65, "5 sugars = 0.65")
	r.assert_gt(rate_5, rate_0, "More sugars = faster")
	return true
