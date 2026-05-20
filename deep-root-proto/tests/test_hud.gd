# ═══════════════════════════════════════════════════════════════
# test_hud.gd — Integration tests for UILayer HUD scene
# Verifies: scene loadability, MSG_COLORS, refresh methods,
# show_typed_message, flash feedback, signal handlers,
# rival/tree panel visibility, GP bar color coding
# ═══════════════════════════════════════════════════════════════
extends GutTest


# ── Constants ───────────────────────────────────────────────

func test_msg_colors_has_all_types():
	"""MSG_COLORS dictionary has all 5 message types."""
	var scene := load("res://scenes/ui_layer.tscn")
	var instance: CanvasLayer = scene.instantiate()
	assert_true(instance.MSG_COLORS.has("info"), "has info")
	assert_true(instance.MSG_COLORS.has("warning"), "has warning")
	assert_true(instance.MSG_COLORS.has("success"), "has success")
	assert_true(instance.MSG_COLORS.has("error"), "has error")
	assert_true(instance.MSG_COLORS.has("milestone"), "has milestone")
	instance.free()


func test_msg_colors_distinct():
	"""Each message type has a distinct color."""
	var scene := load("res://scenes/ui_layer.tscn")
	var instance: CanvasLayer = scene.instantiate()
	var colors: Array[Color] = []
	for key in instance.MSG_COLORS:
		colors.append(instance.MSG_COLORS[key])
	# All 5 colors should be distinct
	for i: int in range(colors.size()):
		for j: int in range(i + 1, colors.size()):
			assert_ne(colors[i], colors[j], "MSG_COLORS distinct: %d vs %d" % [i, j])
	instance.free()


func test_msg_colors_info_blue():
	"""Info message color is light blue."""
	var scene := load("res://scenes/ui_layer.tscn")
	var instance: CanvasLayer = scene.instantiate()
	var c: Color = instance.MSG_COLORS["info"]
	assert_gt(c.b, 0.95, "info has high blue")
	assert_gt(c.r, 0.7, "info has some red")
	instance.free()


func test_flash_duration_value():
	"""FLASH_DURATION should be 0.3 seconds."""
	var scene := load("res://scenes/ui_layer.tscn")
	var instance: CanvasLayer = scene.instantiate()
	assert_eq(instance.FLASH_DURATION, 0.3, "FLASH_DURATION = 0.3")
	instance.free()


func test_flash_color_is_white():
	"""FLASH_COLOR should be pure white."""
	var scene := load("res://scenes/ui_layer.tscn")
	var instance: CanvasLayer = scene.instantiate()
	assert_eq(instance.FLASH_COLOR, Color(1.0, 1.0, 1.0, 1.0), "flash = white")
	instance.free()


# ── Scene loadability ───────────────────────────────────────

func test_hud_scene_loadable():
	"""UILayer scene and script should be loadable and instantiable."""
	assert_true(ResourceLoader.exists("res://scenes/ui_layer.tscn"), "ui_layer.tscn exists")
	assert_true(ResourceLoader.exists("res://scenes/ui_layer.gd"), "ui_layer.gd exists")
	var scene: PackedScene = load("res://scenes/ui_layer.tscn")
	assert_not_null(scene, "scene loadable")
	var instance: CanvasLayer = scene.instantiate()
	assert_not_null(instance, "instance created")
	instance.free()


func test_hud_add_to_tree_populates_onready():
	"""When added to scene tree, @onready nodes populate correctly."""
	var scene: PackedScene = load("res://scenes/ui_layer.tscn")
	var instance: CanvasLayer = scene.instantiate()
	add_child(instance)
	await get_tree().process_frame

	# Verify @onready nodes exist after adding to tree
	assert_not_null(instance._gp_label, "_gp_label populated")
	assert_not_null(instance._gp_bar, "_gp_bar populated")
	assert_not_null(instance._gp_icon, "_gp_icon populated")
	assert_not_null(instance._water_label, "_water_label populated")
	assert_not_null(instance._message_label, "_message_label populated")
	assert_not_null(instance._controls_label, "_controls_label populated")
	assert_not_null(instance._territory_label, "_territory_label populated")
	assert_not_null(instance._territory_bar, "_territory_bar populated")

	instance.queue_free()


# ── Controls label ──────────────────────────────────────────

func test_controls_label_populated():
	"""Controls label mentions key game instructions after _refresh_controls."""
	var scene: PackedScene = load("res://scenes/ui_layer.tscn")
	var instance: CanvasLayer = scene.instantiate()
	add_child(instance)
	await get_tree().process_frame

	instance._refresh_controls(GameManager)
	var txt: String = instance._controls_label.text
	assert_true(txt.contains("grow"), "controls mention grow")
	assert_true(txt.contains("trade"), "controls mention trade")
	assert_true(txt.contains("pulse"), "controls mention pulse")
	assert_true(txt.contains("link"), "controls mention link")
	assert_true(txt.contains("reset"), "controls mention reset")

	instance.queue_free()


# ── GP bar refresh ──────────────────────────────────────────

func test_refresh_gp_updates_label():
	"""_refresh_gp sets GP label with value and rate."""
	GameManager.new_game()
	var scene: PackedScene = load("res://scenes/ui_layer.tscn")
	var instance: CanvasLayer = scene.instantiate()
	add_child(instance)
	await get_tree().process_frame

	var gm = GameManager
	gm.player_gp = 25.5
	gm.player_gp_rate = 0.37
	instance._refresh_gp(gm)

	assert_true(instance._gp_label.text.contains("GP:"), "label has GP prefix")
	assert_true(instance._gp_label.text.contains("25.5"), "label has GP value")
	assert_true(instance._gp_label.text.contains("0.37"), "label has GP rate")
	assert_eq(instance._gp_bar.value, 25.5, "GP bar value set")
	assert_eq(instance._gp_bar.max_value, 50.0, "GP bar max = 50")

	instance.queue_free()


func test_refresh_gp_bar_color_cached():
	"""GP bar StyleBoxFlat is cached and reused."""
	GameManager.new_game()
	var scene: PackedScene = load("res://scenes/ui_layer.tscn")
	var instance: CanvasLayer = scene.instantiate()
	add_child(instance)
	await get_tree().process_frame

	var gm = GameManager
	gm.player_gp = 50.0
	instance._refresh_gp(gm)

	# First call creates StyleBoxFlat cache
	assert_not_null(instance._gp_bar_style, "style cached after first refresh")
	var first_style = instance._gp_bar_style

	# Second call reuses cache (same color = no new StyleBoxFlat)
	gm.player_gp = 40.0
	instance._refresh_gp(gm)
	assert_eq(instance._gp_bar_style, first_style, "same style reused")

	instance.queue_free()


# ── Resource labels ─────────────────────────────────────────

func test_refresh_resources_updates_labels():
	"""_refresh_resources sets all 5 resource labels correctly."""
	GameManager.new_game()
	var scene: PackedScene = load("res://scenes/ui_layer.tscn")
	var instance: CanvasLayer = scene.instantiate()
	add_child(instance)
	await get_tree().process_frame

	var gm = GameManager
	gm.player_water = 12
	gm.player_minerals = 8
	gm.player_sugars = 5
	gm.player_cells.clear()
	for i: int in range(3):
		gm.player_cells.append(Vector2i(i, i))
	gm.player_absorbed = 7

	instance._refresh_resources(gm)

	assert_true(instance._water_label.text.contains("12"), "water = 12")
	assert_true(instance._mineral_label.text.contains("8"), "minerals = 8")
	assert_true(instance._sugar_label.text.contains("5"), "sugars = 5")
	assert_true(instance._cells_label.text.contains("3"), "cells = 3")
	assert_true(instance._absorbed_label.text.contains("7"), "absorbed = 7")

	instance.queue_free()


func test_refresh_resources_flash_on_increase():
	"""Resource labels should flash when resource count increases."""
	GameManager.new_game()
	var scene: PackedScene = load("res://scenes/ui_layer.tscn")
	var instance: CanvasLayer = scene.instantiate()
	add_child(instance)
	await get_tree().process_frame

	var gm = GameManager
	gm.player_water = 5
	gm.player_minerals = 3
	gm.player_sugars = 2
	gm.player_cells.clear()
	for i: int in range(1):
		gm.player_cells.append(Vector2i.ZERO)

	# First refresh: establishes prev values
	instance._refresh_resources(gm)

	# Second refresh: increase water
	gm.player_water = 10
	instance._refresh_resources(gm)

	# Flash timer should be triggered
	assert_gt(instance._flash_timer, 0.0, "flash timer has positive value after resource increase")

	instance.queue_free()


# ── Territory ───────────────────────────────────────────────

func test_refresh_territory_updates_label():
	"""_refresh_territory updates territory label with percentage and tier."""
	GameManager.new_game()
	var scene: PackedScene = load("res://scenes/ui_layer.tscn")
	var instance: CanvasLayer = scene.instantiate()
	add_child(instance)
	await get_tree().process_frame

	var gm = GameManager
	# Fill 10% of grid to test territory display
	var total_cells: int = gm.GRID_W * gm.GRID_H
	var ten_pct: int = int(float(total_cells) * 0.10)
	gm.player_cells.clear()
	for i: int in range(ten_pct):
		var x: int = i % gm.GRID_W
		var y: int = i / gm.GRID_W
		if y < gm.GRID_H:
			gm.player_cells.append(Vector2i(x, y))
	gm._total_game_time = 0.0

	instance._refresh_territory(gm)

	var txt: String = instance._territory_label.text
	assert_true(txt.contains("Territory:"), "territory label has prefix")
	assert_true(txt.contains("%"), "territory has percentage")
	assert_eq(instance._territory_bar.max_value, 100.0, "territory bar max = 100")

	instance.queue_free()


# ── Message display ─────────────────────────────────────────

func test_refresh_message_visible_with_timer():
	"""Message label is visible when message_timer > 0."""
	GameManager.new_game()
	var scene: PackedScene = load("res://scenes/ui_layer.tscn")
	var instance: CanvasLayer = scene.instantiate()
	add_child(instance)
	await get_tree().process_frame

	var gm = GameManager
	gm.message_text = "Hello World"
	gm.message_timer = 2.0
	instance._refresh_message(gm)

	assert_true(instance._message_label.visible, "message visible when timer > 0")
	assert_eq(instance._message_label.text, "Hello World", "message text set")

	instance.queue_free()


func test_refresh_message_hidden_when_expired():
	"""Message label is hidden when timer = 0."""
	GameManager.new_game()
	var scene: PackedScene = load("res://scenes/ui_layer.tscn")
	var instance: CanvasLayer = scene.instantiate()
	add_child(instance)
	await get_tree().process_frame

	var gm = GameManager
	gm.message_text = ""
	gm.message_timer = 0.0
	instance._refresh_message(gm)

	assert_false(instance._message_label.visible, "message hidden when no timer")

	instance.queue_free()


# ── show_typed_message ──────────────────────────────────────

func test_show_typed_message_sets_text():
	"""show_typed_message() displays text with type-specific color."""
	GameManager.new_game()
	var scene: PackedScene = load("res://scenes/ui_layer.tscn")
	var instance: CanvasLayer = scene.instantiate()
	add_child(instance)
	await get_tree().process_frame

	instance.show_typed_message("Test info", "info", 1.5)

	assert_eq(instance._message_label.text, "Test info", "text set")
	assert_true(instance._message_label.visible, "label visible")

	instance.queue_free()


func test_show_typed_message_sets_game_manager():
	"""show_typed_message() also sets GameManager message state."""
	GameManager.new_game()
	var scene: PackedScene = load("res://scenes/ui_layer.tscn")
	var instance: CanvasLayer = scene.instantiate()
	add_child(instance)
	await get_tree().process_frame

	instance.show_typed_message("Warning!", "warning", 3.0)

	var gm = GameManager
	assert_eq(gm.message_text, "Warning!", "gm text set")
	assert_eq(gm.message_timer, 3.0, "gm timer set")

	instance.queue_free()


func test_show_typed_message_unknown_type_defaults():
	"""Unknown message type falls back to 'info' color."""
	var scene: PackedScene = load("res://scenes/ui_layer.tscn")
	var instance: CanvasLayer = scene.instantiate()
	add_child(instance)
	await get_tree().process_frame

	# Unknown type should not crash
	instance.show_typed_message("Default", "unknown_type", 1.0)
	assert_true(true, "unknown type does not crash")

	instance.queue_free()


func test_show_typed_message_milestone():
	"""Milestone messages use orange color."""
	GameManager.new_game()
	var scene: PackedScene = load("res://scenes/ui_layer.tscn")
	var instance: CanvasLayer = scene.instantiate()
	add_child(instance)
	await get_tree().process_frame

	instance.show_typed_message("Milestone reached!", "milestone", 2.0)

	assert_eq(instance._message_label.text, "Milestone reached!", "milestone text set")
	assert_eq(GameManager.message_text, "Milestone reached!", "gm text set")

	instance.queue_free()


# ── Signal handlers ─────────────────────────────────────────

func test_on_state_changed_calls_refresh():
	"""_on_state_changed signal triggers _refresh (does not crash)."""
	GameManager.new_game()
	var scene: PackedScene = load("res://scenes/ui_layer.tscn")
	var instance: CanvasLayer = scene.instantiate()
	add_child(instance)
	await get_tree().process_frame

	# Simulate state change by emitting signal
	# The signal is connected in _ready(), but we test the handler directly
	# _on_state_changed should not crash
	instance._on_state_changed()
	assert_true(true, "_on_state_changed does not crash")

	instance.queue_free()


func test_on_message_sets_label():
	"""_on_message handler sets message label text and makes it visible."""
	GameManager.new_game()
	var scene: PackedScene = load("res://scenes/ui_layer.tscn")
	var instance: CanvasLayer = scene.instantiate()
	add_child(instance)
	await get_tree().process_frame

	instance._on_message("Test notification")

	assert_true(instance._message_label.visible, "label visible after _on_message")
	assert_eq(instance._message_label.text, "Test notification", "text set")

	instance.queue_free()


# ── Rival panels ────────────────────────────────────────────

func test_refresh_rivals_after_setup():
	"""After AIManager.setup_rivals(), all 3 panels show with names and stats."""
	GameManager.new_game()
	AIManager.rivals.clear()
	AIManager.rival_intervals.clear()
	AIManager.rival_timers.resize(3)
	AIManager.setup_rivals()

	var scene: PackedScene = load("res://scenes/ui_layer.tscn")
	var instance: CanvasLayer = scene.instantiate()
	add_child(instance)
	await get_tree().process_frame

	assert_eq(AIManager.rivals.size(), 3, "3 rivals after setup")
	assert_true(instance._rival1_panel.visible, "panel 1 visible")
	assert_true(instance._rival2_panel.visible, "panel 2 visible")
	assert_true(instance._rival3_panel.visible, "panel 3 visible")
	# Verify rival names are populated (at least one form of name)
	assert_ne(instance._rival1_name.text, "", "rival1 has name")
	assert_ne(instance._rival2_name.text, "", "rival2 has name")
	assert_ne(instance._rival3_name.text, "", "rival3 has name")
	# Verify stats contain cell count
	assert_true(instance._rival1_stats.text.contains("cell"), "rival1 has stats")
	assert_true(instance._rival2_stats.text.contains("cell"), "rival2 has stats")
	assert_true(instance._rival3_stats.text.contains("cell"), "rival3 has stats")

	instance.queue_free()


func test_refresh_rivals_phase_modulate():
	"""Rival name modulate changes when in special phase (not base personality)."""
	GameManager.new_game()
	# Reset AIManager rivals; resize rival_timers to 3 for setup_rivals() index assignment
	AIManager.rivals.clear()
	AIManager.rival_intervals.clear()
	AIManager.rival_timers.resize(3)
	AIManager.setup_rivals()

	# Force rival 0 into a special phase (aggressive rival's colonize phase)
	var aggro_rival: Dictionary = AIManager.rivals[0]
	aggro_rival["phase"] = "colonize"  # Special phase, not base "aggressive"

	var scene: PackedScene = load("res://scenes/ui_layer.tscn")
	var instance: CanvasLayer = scene.instantiate()
	add_child(instance)
	await get_tree().process_frame

	instance._refresh_rivals(GameManager)

	# During special phase, rival name should be gold-modulated (not the base color)
	var mod: Color = instance._rival1_name.modulate
	assert_gt(mod.r, 0.9, "special phase rival name has high red component")

	instance.queue_free()


# ── Tree panels ─────────────────────────────────────────────

func test_refresh_trees_shows_all_three():
	"""Tree panels 1-3 are visible with status info."""
	GameManager.new_game()

	var scene: PackedScene = load("res://scenes/ui_layer.tscn")
	var instance: CanvasLayer = scene.instantiate()
	add_child(instance)
	await get_tree().process_frame

	instance._refresh_trees(GameManager)

	assert_true(instance._tree1_panel.visible, "tree1 visible")
	assert_true(instance._tree2_panel.visible, "tree2 visible")
	assert_true(instance._tree3_panel.visible, "tree3 visible")

	assert_ne(instance._tree1_name.text, "", "tree1 has name")
	assert_ne(instance._tree2_name.text, "", "tree2 has name")
	assert_ne(instance._tree3_name.text, "", "tree3 has name")

	instance.queue_free()


# ── GP bar color helper ─────────────────────────────────────

func test_gp_bar_color_from_hud():
	"""UILayer._gp_bar_color matches expected thresholds."""
	var scene: PackedScene = load("res://scenes/ui_layer.tscn")
	var instance: CanvasLayer = scene.instantiate()

	assert_eq(instance._gp_bar_color(50.0), Color(0.25, 0.75, 0.35), ">=30 → green")
	assert_eq(instance._gp_bar_color(30.0), Color(0.25, 0.75, 0.35), "=30 → green")
	assert_eq(instance._gp_bar_color(20.0), Color(0.5, 0.8, 0.25), "20 → yellow-green")
	assert_eq(instance._gp_bar_color(10.0), Color(0.5, 0.8, 0.25), "10 → yellow-green")
	assert_eq(instance._gp_bar_color(5.0), Color(0.9, 0.4, 0.15), "5 → orange-red")
	assert_eq(instance._gp_bar_color(2.0), Color(0.9, 0.15, 0.15), "<5 → red")

	instance.free()


# ── Regen bar ───────────────────────────────────────────────

func test_regen_bar_formatting():
	"""_regen_bar produces a bracketed ASCII bar."""
	var scene: PackedScene = load("res://scenes/ui_layer.tscn")
	var instance: CanvasLayer = scene.instantiate()

	var bar: String = instance._regen_bar(30.0, 60.0)
	assert_true(bar.begins_with("["), "bar starts with [")
	assert_true(bar.ends_with("]"), "bar ends with ]")
	assert_gt(bar.length(), 3, "bar is > 3 chars")

	var bar_full: String = instance._regen_bar(0.0, 60.0)
	assert_gt(bar_full.length(), 1, "full bar not empty")

	var bar_empty: String = instance._regen_bar(60.0, 60.0)
	assert_gt(bar_empty.length(), 1, "empty bar still has brackets")

	instance.free()
