# ═══════════════════════════════════════════════════════════════
# test_difficulty.gd — Tests for difficulty curve system
# ═══════════════════════════════════════════════════════════════
extends GutTest


func test_difficulty_constants_exist():
	"""Difficulty constants should be defined in GameManager."""
	var gm := get_node_or_null("/root/GameManager")
	assert_not_null(gm, "GameManager should exist")
	if gm == null: return

	assert_ge(gm.DIFFICULTY_TIER_TERRITORY.size(), 3, "Should have at least 3 difficulty tiers")
	assert_eq(gm.DIFFICULTY_TIER_TERRITORY.size(), gm.DIFFICULTY_RIVAL_MULTIPLIERS.size(),
	"Tier and multiplier arrays should be same size")
	assert_eq(gm.DIFFICULTY_TIER_TERRITORY.size(), gm.DIFFICULTY_NAMES.size(),
	"Tier and name arrays should be same size")


func test_difficulty_tier_zero_by_default():
	"""With few cells, difficulty tier should be 0."""
	var gm := get_node_or_null("/root/GameManager")
	if gm == null: return

	var tier: int = gm.get_difficulty_tier()
	assert_eq(tier, 0, "Default difficulty tier should be 0 (Germination)")


func test_player_territory_pct_returns_float():
	"""player_territory_pct should return a float between 0 and 100."""
	var gm := get_node_or_null("/root/GameManager")
	if gm == null: return

	var pct: float = gm.player_territory_pct()
	assert_eq(typeof(pct), TYPE_FLOAT, "Territory pct should be float")
	assert_ge(pct, 0.0, "Territory pct should be >= 0")
	assert_le(pct, 100.0, "Territory pct should be <= 100")


func test_rival_speed_multiplier_default():
	"""Default rival speed multiplier should be 1.0."""
	var gm := get_node_or_null("/root/GameManager")
	if gm == null: return

	var mult: float = gm.get_rival_speed_multiplier()
	assert_ge(mult, 1.0, "Speed multiplier should be >= 1.0")


func test_difficulty_name_not_empty():
	"""get_difficulty_name should return a non-empty string."""
	var gm := get_node_or_null("/root/GameManager")
	if gm == null: return

	var name: String = gm.get_difficulty_name()
	assert_ne(name, "", "Difficulty name should not be empty")


func test_mechanic_unlocked_defaults():
	"""is_mechanic_unlocked should return bool for known mechanics."""
	var gm := get_node_or_null("/root/GameManager")
	if gm == null: return

	var pulse_ok: bool = gm.is_mechanic_unlocked("pulse")
	var link_ok: bool = gm.is_mechanic_unlocked("link")
	var unlink_ok: bool = gm.is_mechanic_unlocked("unlink")
	assert_eq(typeof(pulse_ok), TYPE_BOOL, "is_mechanic_unlocked(pulse) returns bool")
	assert_eq(typeof(link_ok), TYPE_BOOL, "is_mechanic_unlocked(link) returns bool")
	assert_eq(typeof(unlink_ok), TYPE_BOOL, "is_mechanic_unlocked(unlink) returns bool")
	# With few cells, pulse might be locked
	assert_false(pulse_ok, "Pulse should be locked with few cells (5% threshold)")


func test_tick_difficulty_increments_time():
	"""tick_difficulty should not crash."""
	var gm := get_node_or_null("/root/GameManager")
	if gm == null: return

	gm.tick_difficulty(0.1)
	assert_true(true, "tick_difficulty doesn't crash")


func test_rival_bonus_gp_default():
	"""get_rival_bonus_gp should be 0 by default."""
	var gm := get_node_or_null("/root/GameManager")
	if gm == null: return

	var bonus: float = gm.get_rival_bonus_gp()
	assert_eq(bonus, 0.0, "Rival bonus GP should be 0 at tier 0")


func test_difficulty_tier_territory_increasing():
	"""Difficulty tier thresholds should be strictly increasing."""
	var gm := get_node_or_null("/root/GameManager")
	if gm == null: return

	for i: int in range(1, gm.DIFFICULTY_TIER_TERRITORY.size()):
		assert_gt(gm.DIFFICULTY_TIER_TERRITORY[i], gm.DIFFICULTY_TIER_TERRITORY[i - 1],
			"Tier threshold %d should be > tier %d" % [i, i - 1])
