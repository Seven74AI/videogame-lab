# ═══════════════════════════════════════════════════════════════
# test_ui.gd — Tests for UILayer HUD helper functions
# Validates: resource bars, formatting, tooltip data, visual states
# ═══════════════════════════════════════════════════════════════
extends Node

func _runner():
	return get_parent()


# ── Bar progress ratio ────────────────────────────────────

func test_bar_ratio_full() -> bool:
	""" Bar ratio returns 1.0 when current equals max """
	var r = _runner()
	r.assert_eq(_calc_bar_ratio(100.0, 100.0), 1.0, "full bar ratio")
	return true


func test_bar_ratio_empty() -> bool:
	""" Bar ratio returns 0.0 when current is 0 """
	var r = _runner()
	r.assert_eq(_calc_bar_ratio(0.0, 100.0), 0.0, "empty bar ratio")
	return true


func test_bar_ratio_half() -> bool:
	""" Bar ratio returns 0.5 for half """
	var r = _runner()
	r.assert_eq(_calc_bar_ratio(50.0, 100.0), 0.5, "half bar ratio")
	return true


func test_bar_ratio_clamped_zero() -> bool:
	""" Bar ratio clamps negative values to 0 """
	var r = _runner()
	r.assert_eq(_calc_bar_ratio(-10.0, 100.0), 0.0, "negative clamps to 0")
	return true


func test_bar_ratio_clamped_max() -> bool:
	""" Bar ratio clamps values exceeding max to 1 """
	var r = _runner()
	r.assert_eq(_calc_bar_ratio(150.0, 100.0), 1.0, "overflow clamps to 1")
	return true


func test_bar_ratio_zero_max() -> bool:
	""" Bar ratio returns 0 when max is 0 (avoid division by zero) """
	var r = _runner()
	r.assert_eq(_calc_bar_ratio(0.0, 0.0), 0.0, "zero max returns 0")
	return true


# ── GP rate formatting ─────────────────────────────────────

func test_fmt_gp_rate_positive() -> bool:
	""" GP rate formats with two decimals """
	var r = _runner()
	r.assert_eq(_fmt_gp_rate(0.37), "+0.37/s", "positive rate")
	return true


func test_fmt_gp_rate_high() -> bool:
	""" GP rate formats high value correctly """
	var r = _runner()
	r.assert_eq(_fmt_gp_rate(1.2), "+1.20/s", "high rate")
	return true


func test_fmt_gp_rate_zero() -> bool:
	""" GP rate formats zero """
	var r = _runner()
	r.assert_eq(_fmt_gp_rate(0.0), "+0.00/s", "zero rate")
	return true


# ── Resource count formatting ─────────────────────────────

func test_fmt_resource_count() -> bool:
	""" Resource count formats as 'current/max' """
	var r = _runner()
	r.assert_eq(_fmt_resource_count(5, 10), "5/10", "half count")
	return true


func test_fmt_resource_count_zero() -> bool:
	""" Resource count with zero current """
	var r = _runner()
	r.assert_eq(_fmt_resource_count(0, 10), "0/10", "zero count")
	return true


func test_fmt_resource_count_full() -> bool:
	""" Resource count at max """
	var r = _runner()
	r.assert_eq(_fmt_resource_count(10, 10), "10/10", "full count")
	return true


# ── Rival icon / name / color ─────────────────────────────

func test_rival_display_name_aggressive() -> bool:
	""" Aggressive rival display name is 'Red' """
	var r = _runner()
	r.assert_eq(_rival_display_name("aggressive"), "Red", "aggressive -> Red")
	return true


func test_rival_display_name_defensive() -> bool:
	""" Defensive rival display name is 'Orange' """
	var r = _runner()
	r.assert_eq(_rival_display_name("defensive"), "Orange", "defensive -> Orange")
	return true


func test_rival_display_name_opportunistic() -> bool:
	""" Opportunistic rival display name is 'Violet' """
	var r = _runner()
	r.assert_eq(_rival_display_name("opportunistic"), "Violet", "opportunistic -> Violet")
	return true


func test_rival_icon_color_aggressive() -> bool:
	""" Aggressive rival icon color is red """
	var r = _runner()
	r.assert_eq(_rival_icon_color("aggressive"), Color(0.88, 0.18, 0.18), "aggressive color")
	return true


func test_rival_icon_color_defensive() -> bool:
	""" Defensive rival icon color is orange """
	var r = _runner()
	r.assert_eq(_rival_icon_color("defensive"), Color(0.92, 0.55, 0.08), "defensive color")
	return true


func test_rival_icon_color_opportunistic() -> bool:
	""" Opportunistic rival icon color is violet """
	var r = _runner()
	r.assert_eq(_rival_icon_color("opportunistic"), Color(0.65, 0.18, 0.85), "opportunistic color")
	return true


# ── Resource icon colors ──────────────────────────────────

func test_resource_icon_color_water() -> bool:
	""" Water icon is blue """
	var r = _runner()
	r.assert_eq(_resource_icon_color("water"), Color(0.18, 0.38, 0.85), "water blue")
	return true


func test_resource_icon_color_minerals() -> bool:
	""" Minerals icon is brown/gold """
	var r = _runner()
	r.assert_eq(_resource_icon_color("minerals"), Color(0.65, 0.55, 0.25), "minerals brown")
	return true


func test_resource_icon_color_sugars() -> bool:
	""" Sugars icon is gold """
	var r = _runner()
	r.assert_eq(_resource_icon_color("sugars"), Color(0.95, 0.80, 0.25), "sugars gold")
	return true


func test_resource_icon_color_gp() -> bool:
	""" GP icon is green """
	var r = _runner()
	r.assert_eq(_resource_icon_color("gp"), Color(0.25, 0.75, 0.35), "gp green")
	return true


func test_resource_icon_color_cells() -> bool:
	""" Cells icon is teal """
	var r = _runner()
	r.assert_eq(_resource_icon_color("cells"), Color(0.3, 0.7, 0.7), "cells teal")
	return true


# ── Tree status determination ─────────────────────────────

func test_tree_status_available() -> bool:
	""" Tree with trades and no cooldown returns 'available' """
	var tree: Dictionary = {"trades_left": 3, "cooldown": 0.0, "linked_to": -1}
	var r = _runner()
	r.assert_eq(_tree_status(tree, 6), "available", "available tree")
	return true


func test_tree_status_cooldown() -> bool:
	""" Tree with cooldown returns 'cooldown' """
	var tree: Dictionary = {"trades_left": 2, "cooldown": 1.5, "linked_to": -1}
	var r = _runner()
	r.assert_eq(_tree_status(tree, 6), "cooldown", "cooldown tree")
	return true


func test_tree_status_depleted() -> bool:
	""" Tree with no trades returns 'depleted' """
	var tree: Dictionary = {"trades_left": 0, "cooldown": 0.0, "linked_to": -1}
	var r = _runner()
	r.assert_eq(_tree_status(tree, 6), "depleted", "depleted tree")
	return true


func test_tree_status_linked() -> bool:
	""" Tree with link returns 'linked' """
	var tree: Dictionary = {"trades_left": 3, "cooldown": 0.0, "linked_to": 1}
	var r = _runner()
	r.assert_eq(_tree_status(tree, 6), "linked", "linked tree")
	return true


func test_tree_status_linked_depleted() -> bool:
	""" Linked tree with no trades still shows 'linked' """
	var tree: Dictionary = {"trades_left": 0, "cooldown": 0.0, "linked_to": 0}
	var r = _runner()
	r.assert_eq(_tree_status(tree, 6), "linked", "linked depleted tree")
	return true


# ── Tree status color ─────────────────────────────────────

func test_tree_status_color_available() -> bool:
	""" Available tree color is green """
	var r = _runner()
	r.assert_eq(_tree_status_color("available"), Color(0.3, 0.8, 0.3), "available green")
	return true


func test_tree_status_color_cooldown() -> bool:
	""" Cooldown tree color is orange """
	var r = _runner()
	r.assert_eq(_tree_status_color("cooldown"), Color(0.9, 0.6, 0.2), "cooldown orange")
	return true


func test_tree_status_color_depleted() -> bool:
	""" Depleted tree color is red """
	var r = _runner()
	r.assert_eq(_tree_status_color("depleted"), Color(0.9, 0.2, 0.2), "depleted red")
	return true


func test_tree_status_color_linked() -> bool:
	""" Linked tree color is purple """
	var r = _runner()
	r.assert_eq(_tree_status_color("linked"), Color(0.6, 0.4, 0.95), "linked purple")
	return true


# ── GP bar color based on value ───────────────────────────

func test_gp_bar_color_high() -> bool:
	""" High GP (>30) returns green """
	var r = _runner()
	r.assert_eq(_gp_bar_color(50.0), Color(0.25, 0.75, 0.35), "high GP green")
	return true


func test_gp_bar_color_medium() -> bool:
	""" Medium GP (10-30) returns yellow-green """
	var r = _runner()
	r.assert_eq(_gp_bar_color(20.0), Color(0.5, 0.8, 0.25), "medium GP yellow-green")
	return true


func test_gp_bar_color_low() -> bool:
	""" Low GP (<10) returns orange-red """
	var r = _runner()
	r.assert_eq(_gp_bar_color(5.0), Color(0.9, 0.4, 0.15), "low GP orange-red")
	return true


func test_gp_bar_color_critical() -> bool:
	""" Critical GP (<5) returns red """
	var r = _runner()
	r.assert_eq(_gp_bar_color(2.0), Color(0.9, 0.15, 0.15), "critical GP red")
	return true


# ── Helper functions (duplicated here for test isolation) ──

static func _calc_bar_ratio(current: float, max_val: float) -> float:
	if max_val <= 0.0: return 0.0
	return clampf(current / max_val, 0.0, 1.0)


static func _fmt_gp_rate(rate: float) -> String:
	return "+%.2f/s" % rate


static func _fmt_resource_count(current: int, max_count: int) -> String:
	return "%d/%d" % [current, max_count]


static func _rival_display_name(personality: String) -> String:
	match personality:
		"aggressive": return "Red"
		"defensive": return "Orange"
		"opportunistic": return "Violet"
		_: return personality


static func _rival_icon_color(personality: String) -> Color:
	match personality:
		"aggressive": return Color(0.88, 0.18, 0.18)
		"defensive": return Color(0.92, 0.55, 0.08)
		"opportunistic": return Color(0.65, 0.18, 0.85)
		_: return Color.GRAY


static func _resource_icon_color(type: String) -> Color:
	match type:
		"water": return Color(0.18, 0.38, 0.85)
		"minerals": return Color(0.65, 0.55, 0.25)
		"sugars": return Color(0.95, 0.80, 0.25)
		"gp": return Color(0.25, 0.75, 0.35)
		"cells": return Color(0.3, 0.7, 0.7)
		_: return Color.GRAY


static func _tree_status(tree: Dictionary, max_trades: int) -> String:
	if tree.get("linked_to", -1) >= 0:
		return "linked"
	if tree.get("trades_left", 0) <= 0:
		return "depleted"
	if tree.get("cooldown", 0.0) > 0.0:
		return "cooldown"
	return "available"


static func _tree_status_color(status: String) -> Color:
	match status:
		"available": return Color(0.3, 0.8, 0.3)
		"cooldown": return Color(0.9, 0.6, 0.2)
		"depleted": return Color(0.9, 0.2, 0.2)
		"linked": return Color(0.6, 0.4, 0.95)
		_: return Color.GRAY


static func _gp_bar_color(gp: float) -> Color:
	if gp >= 30.0:
		return Color(0.25, 0.75, 0.35)
	elif gp >= 10.0:
		return Color(0.5, 0.8, 0.25)
	elif gp >= 5.0:
		return Color(0.9, 0.4, 0.15)
	else:
		return Color(0.9, 0.15, 0.15)
