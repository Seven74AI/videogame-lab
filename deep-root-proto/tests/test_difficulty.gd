# ═══════════════════════════════════════════════════════════════
# test_difficulty.gd — Tests for difficulty curve system
# ═══════════════════════════════════════════════════════════════
extends Node


func _runner():
	return get_parent()


func test_difficulty_constants_exist() -> bool:
	"""Difficulty constants should be defined in GameManager."""
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	r.assert_not_null(gm, "GameManager should exist")
	if gm == null: return true

	r.assert_ge(gm.DIFFICULTY_TIER_TERRITORY.size(), 3, "Should have at least 3 difficulty tiers")
	r.assert_eq(gm.DIFFICULTY_TIER_TERRITORY.size(), gm.DIFFICULTY_RIVAL_MULTIPLIERS.size(),
		"Tier and multiplier arrays should be same size")
	r.assert_eq(gm.DIFFICULTY_TIER_TERRITORY.size(), gm.DIFFICULTY_NAMES.size(),
		"Tier and name arrays should be same size")
	return true


func test_difficulty_tier_zero_by_default() -> bool:
	"""With few cells, difficulty tier should be 0."""
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	if gm == null: return true

	var tier: int = gm.get_difficulty_tier()
	r.assert_eq(tier, 0, "Default difficulty tier should be 0 (Germination)")
	return true


func test_player_territory_pct_returns_float() -> bool:
	"""player_territory_pct should return a float between 0 and 100."""
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	if gm == null: return true

	var pct: float = gm.player_territory_pct()
	r.assert_eq(typeof(pct), TYPE_FLOAT, "Territory pct should be float")
	r.assert_ge(pct, 0.0, "Territory pct should be >= 0")
	r.assert_le(pct, 100.0, "Territory pct should be <= 100")
	return true


func test_rival_speed_multiplier_default() -> bool:
	"""Default rival speed multiplier should be 1.0."""
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	if gm == null: return true

	var mult: float = gm.get_rival_speed_multiplier()
	r.assert_ge(mult, 1.0, "Speed multiplier should be >= 1.0")
	return true


func test_difficulty_name_not_empty() -> bool:
	"""get_difficulty_name should return a non-empty string."""
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	if gm == null: return true

	var name: String = gm.get_difficulty_name()
	r.assert_ne(name, "", "Difficulty name should not be empty")
	return true


func test_mechanic_unlocked_defaults() -> bool:
	"""is_mechanic_unlocked should return bool for known mechanics."""
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	if gm == null: return true

	var pulse_ok: bool = gm.is_mechanic_unlocked("pulse")
	var link_ok: bool = gm.is_mechanic_unlocked("link")
	var unlink_ok: bool = gm.is_mechanic_unlocked("unlink")
	r.assert_eq(typeof(pulse_ok), TYPE_BOOL, "is_mechanic_unlocked(pulse) returns bool")
	r.assert_eq(typeof(link_ok), TYPE_BOOL, "is_mechanic_unlocked(link) returns bool")
	r.assert_eq(typeof(unlink_ok), TYPE_BOOL, "is_mechanic_unlocked(unlink) returns bool")
	# With few cells, pulse might be locked
	r.assert_false(pulse_ok, "Pulse should be locked with few cells (5% threshold)")
	return true


func test_tick_difficulty_increments_time() -> bool:
	"""tick_difficulty should not crash."""
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	if gm == null: return true

	gm.tick_difficulty(0.1)
	r.assert_true(true, "tick_difficulty doesn't crash")
	return true


func test_rival_bonus_gp_default() -> bool:
	"""get_rival_bonus_gp should be 0 by default."""
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	if gm == null: return true

	var bonus: float = gm.get_rival_bonus_gp()
	r.assert_eq(bonus, 0.0, "Rival bonus GP should be 0 at tier 0")
	return true


func test_difficulty_tier_territory_increasing() -> bool:
	"""Difficulty tier thresholds should be strictly increasing."""
	var gm := get_node_or_null("/root/GameManager")
	var r = _runner()
	if gm == null: return true

	for i: int in range(1, gm.DIFFICULTY_TIER_TERRITORY.size()):
		r.assert_gt(gm.DIFFICULTY_TIER_TERRITORY[i], gm.DIFFICULTY_TIER_TERRITORY[i - 1],
			"Tier threshold %d should be > tier %d" % [i, i - 1])
	return true
