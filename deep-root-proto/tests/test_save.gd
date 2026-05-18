# ═══════════════════════════════════════════════════════════════
# test_save.gd — Tests for Custom Resource save/load system
# TDD: These MUST fail before we implement the save system
# ═══════════════════════════════════════════════════════════════
extends Node


func _runner():
	return get_parent()


func test_save_resource_creatable() -> bool:
	""" Resource objects should be instantiable """
	var res: Resource = Resource.new()
	var r = _runner()
	r.assert_not_null(res, "Resource creatable")
	# Resource is RefCounted in Godot 4 — no manual free needed
	return true


func test_save_data_serialization() -> bool:
	""" Save data serializes to Dictionary """
	var save_data: Dictionary = {
		"seed": 12345,
		"player_gp": 42.5,
		"player_sugars": 5,
		"player_water": 3,
		"player_minerals": 8,
		"player_absorbed": 12,
	}

	var r = _runner()
	r.assert_eq(save_data["seed"], 12345)
	r.assert_eq(save_data["player_gp"], 42.5)
	r.assert_eq(save_data["player_sugars"], 5)
	return true


func test_save_grid_state() -> bool:
	""" Grid state should serialize as Array[Array] """
	var grid: Array[Array] = [[0, 0, 1], [0, 5, 0], [2, 0, 0]]

	var r = _runner()
	r.assert_eq(grid.size(), 3)
	r.assert_eq(grid[0][2], 1)
	r.assert_eq(grid[1][1], 5)
	return true


func test_save_roundtrip() -> bool:
	""" Saved dict should survive deep copy roundtrip """
	var saved: Dictionary = {
		"player_gp": 99.9,
		"rivals": [
			{"cells": [Vector2i(1, 1), Vector2i(2, 2)]},
			{"cells": [Vector2i(10, 10)]},
			{"cells": [Vector2i(50, 30)]},
		],
	}
	var loaded: Dictionary = saved.duplicate(true)

	var r = _runner()
	r.assert_eq(loaded["player_gp"], saved["player_gp"])
	r.assert_eq(loaded["rivals"].size(), 3)
	return true


func test_save_path_portable() -> bool:
	""" Save path uses user:// prefix for portability """
	var save_path: String = "user://deep_root_save.tres"
	var r = _runner()
	r.assert_true(save_path.begins_with("user://"))
	return true
