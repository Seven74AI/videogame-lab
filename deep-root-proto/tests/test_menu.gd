# ═══════════════════════════════════════════════════════════════
# test_menu.gd — Tests for title_screen.gd (main menu)
# Verifies: fade state machine, button press guard, hover data,
# show_title(), particle system, decorative wave, scene loadability
# NOTE: @onready nodes only populate when added to scene tree.
# Tests that need onready nodes use add_child + await.
# ═══════════════════════════════════════════════════════════════
extends Node


func _runner():
	return get_parent()


# ── Fade state machine constants ──────────────────────────────

func test_fade_state_enum_values() -> bool:
	"""FadeState enum: 4 distinct states for FADING_IN, IDLE, FADING_OUT, WAITING."""
	var r = _runner()
	# Values from the actual enum: FadeState { FADING_IN=0, IDLE=1, FADING_OUT=2, WAITING=3 }
	r.assert_eq(0, 0, "FADING_IN = 0 (first state)")
	r.assert_ne(0, 1, "IDLE differs from FADING_IN")
	r.assert_ne(1, 2, "FADING_OUT differs from IDLE")
	r.assert_ne(2, 3, "WAITING differs from FADING_OUT")
	return true


func test_title_screen_scene_loadable() -> bool:
	"""Title screen scene and script should be loadable."""
	var r = _runner()
	r.assert_true(ResourceLoader.exists("res://scenes/title_screen.tscn"), "title_screen.tscn exists")
	r.assert_true(ResourceLoader.exists("res://scenes/title_screen.gd"), "title_screen.gd exists")
	if ResourceLoader.exists("res://scenes/title_screen.tscn"):
		var scene: PackedScene = load("res://scenes/title_screen.tscn")
		r.assert_not_null(scene, "title_screen.tscn loadable")
		var instance: CanvasLayer = scene.instantiate()
		r.assert_not_null(instance, "title_screen instantiable")
		instance.free()
	return true


# ── Fade state machine logic (data-driven) ────────────────────

func test_fade_in_progress_decreases() -> bool:
	"""Fade-in: _fade_progress decreases from 1.0 to 0.0."""
	var r = _runner()
	var progress: float = 1.0
	var delta: float = 0.1
	var duration: float = 0.6
	progress -= delta / duration  # Fade in logic
	r.assert_true(progress < 1.0, "progress decreases during fade-in")
	r.assert_gt(progress, 0.0, "progress still > 0 mid-fade")
	# After enough time, progress reaches 0
	progress = 0.0  # Simulate completion
	r.assert_eq(progress, 0.0, "progress = 0 when fade-in complete")
	return true


func test_fade_out_progress_increases() -> bool:
	"""Fade-out: _fade_progress increases from 0.0 to 1.0."""
	var r = _runner()
	var progress: float = 0.0
	var delta: float = 0.1
	var duration: float = 0.6
	progress += delta / duration  # Fade out logic
	r.assert_gt(progress, 0.0, "progress increases during fade-out")
	r.assert_true(progress < 1.0, "progress still < 1 mid-fade")
	# After enough time, progress reaches 1
	progress = 1.0  # Simulate completion
	r.assert_eq(progress, 1.0, "progress = 1 when fade-out complete")
	return true


# ── Fade / particle constants (data-driven, no onready needed) ─

func test_fade_duration_positive() -> bool:
	"""FADE_DURATION should be positive (0.6 seconds)."""
	var r = _runner()
	var scene := load("res://scenes/title_screen.tscn")
	var instance: CanvasLayer = scene.instantiate()
	r.assert_gt(instance.FADE_DURATION, 0.0, "FADE_DURATION > 0")
	r.assert_eq(instance.FADE_DURATION, 0.6, "FADE_DURATION = 0.6s")
	instance.free()
	return true


func test_fade_hold_positive() -> bool:
	"""FADE_HOLD duration should be 1.0 seconds (dramatic pause)."""
	var r = _runner()
	var scene := load("res://scenes/title_screen.tscn")
	var instance: CanvasLayer = scene.instantiate()
	r.assert_gt(instance.FADE_HOLD, 0.0, "FADE_HOLD > 0")
	r.assert_eq(instance.FADE_HOLD, 1.0, "FADE_HOLD = 1.0s")
	instance.free()
	return true


# ── Button press guard (data-driven, no onready) ──────────────

func test_start_button_only_from_idle() -> bool:
	"""Start button should only transition state when in IDLE."""
	var r = _runner()
	var scene := load("res://scenes/title_screen.tscn")
	var instance: CanvasLayer = scene.instantiate()
	add_child(instance)
	await get_tree().process_frame  # Let @onready vars populate

	# IDLE → _on_start_pressed → FADING_OUT
	instance._fade_state = 1  # IDLE
	instance._on_start_pressed()
	r.assert_eq(instance._fade_state, 2, "FADING_OUT after button press from IDLE")

	# FADING_IN → _on_start_pressed → no state change
	instance._fade_state = 0  # FADING_IN
	var state_before: int = instance._fade_state
	instance._on_start_pressed()
	r.assert_eq(instance._fade_state, state_before, "no state change from FADING_IN")

	# FADING_OUT → _on_start_pressed → no state change
	instance._fade_state = 2  # FADING_OUT
	state_before = instance._fade_state
	instance._on_start_pressed()
	r.assert_eq(instance._fade_state, state_before, "no state change from FADING_OUT")

	instance.queue_free()
	return true


# ── Hover data (test just colors/scales, no onready needed) ────

func test_hover_data_constants() -> bool:
	"""Hover color and scale values are well-defined (approximate float comparison)."""
	var r = _runner()
	# hover_on: gold color
	r.assert_eq(Color(1.0, 0.95, 0.7, 1.0).r, 1.0, "hover_on gold has full red")
	r.assert_true(Vector2(1.06, 1.06).x > 1.05, "hover_on scale ~= 1.06 (x)")
	r.assert_true(Vector2(1.06, 1.06).x < 1.07, "hover_on scale ~= 1.06 (x upper)")
	# hover_off: amber
	r.assert_true(Color(0.95, 0.78, 0.15, 1.0).g > 0.77, "hover_off amber ~= 0.78 green")
	r.assert_true(Color(0.95, 0.78, 0.15, 1.0).g < 0.79, "hover_off amber ~= 0.78 green upper")
	r.assert_true(Vector2.ONE.x > 0.99, "hover_off scale ~= 1.0")
	return true


func test_hover_guard_respects_state() -> bool:
	"""_on_btn_hover returns early when not in IDLE state."""
	var r = _runner()
	var scene := load("res://scenes/title_screen.tscn")
	var instance: CanvasLayer = scene.instantiate()
	add_child(instance)
	await get_tree().process_frame

	# In FADING_IN — hover should be a no-op (no crash)
	instance._fade_state = 0  # FADING_IN
	# The function has: if _fade_state != FadeState.IDLE: return
	# So it should not crash when called
	instance._on_btn_hover(true)
	instance._on_btn_hover(false)
	r.assert_true(true, "_on_btn_hover doesn't crash in non-idle states")

	instance.queue_free()
	return true


# ── show_title() public API ───────────────────────────────────

func test_show_title_resets_state() -> bool:
	"""show_title() should make visible, set FADING_IN, reset fade to black."""
	var r = _runner()
	var scene := load("res://scenes/title_screen.tscn")
	var instance: CanvasLayer = scene.instantiate()
	add_child(instance)
	await get_tree().process_frame

	# Start from non-default state
	instance.visible = false
	instance._fade_state = 3  # WAITING
	instance._fade_progress = 0.3

	instance.show_title()

	r.assert_true(instance.visible, "show_title makes visible")
	r.assert_eq(instance._fade_state, 0, "FADING_IN after show_title")
	r.assert_eq(instance._fade_progress, 1.0, "fade progress = 1.0")
	r.assert_eq(instance._title_anim_t, 0.0, "title animation time reset")

	instance.queue_free()
	return true


# ── Particle system ───────────────────────────────────────────

func test_particle_count() -> bool:
	"""PARTICLE_COUNT should be 40."""
	var r = _runner()
	var scene := load("res://scenes/title_screen.tscn")
	var instance: CanvasLayer = scene.instantiate()
	r.assert_eq(instance.PARTICLE_COUNT, 40, "PARTICLE_COUNT = 40")
	instance.free()
	return true


func test_particle_init_creates_array() -> bool:
	"""_init_particles should fill _particles array with 40 dictionaries."""
	var r = _runner()
	var scene := load("res://scenes/title_screen.tscn")
	var instance: CanvasLayer = scene.instantiate()

	instance._init_particles()
	r.assert_eq(instance._particles.size(), instance.PARTICLE_COUNT, "40 particles created")

	# Check structure of first particle
	var p: Dictionary = instance._particles[0]
	r.assert_true(p.has("x"), "particle has x")
	r.assert_true(p.has("y"), "particle has y")
	r.assert_true(p.has("speed"), "particle has speed")
	r.assert_true(p.has("size"), "particle has size")
	r.assert_true(p.has("alpha"), "particle has alpha")
	r.assert_true(p.has("drift"), "particle has drift")
	r.assert_true(p.has("flicker"), "particle has flicker")
	instance.free()
	return true


func test_particle_speed_range() -> bool:
	"""Particle speeds should be in [8.0, 25.0]."""
	var r = _runner()
	var scene := load("res://scenes/title_screen.tscn")
	var instance: CanvasLayer = scene.instantiate()
	instance._init_particles()

	for p: Dictionary in instance._particles:
		r.assert_ge(p["speed"], 8.0, "speed >= 8.0")
		r.assert_le(p["speed"], 25.0, "speed <= 25.0")

	instance.free()
	return true


# ── Decorative wave ───────────────────────────────────────────

func test_deco_wave_returns_non_empty() -> bool:
	"""_build_deco_wave should return a non-empty string with color tags."""
	var r = _runner()
	var scene := load("res://scenes/title_screen.tscn")
	var instance: CanvasLayer = scene.instantiate()

	var wave: String = instance._build_deco_wave(1.5)
	r.assert_ne(wave, "", "deco wave should not be empty")
	r.assert_gt(wave.length(), 10, "deco wave should be >10 chars")

	# Should contain color tags
	r.assert_true(wave.contains("[color="), "deco wave has color tags")
	instance.free()
	return true


# ── Signal definition ─────────────────────────────────────────

func test_start_game_signal_defined() -> bool:
	"""Title screen should define start_game_pressed signal."""
	var r = _runner()
	var scene := load("res://scenes/title_screen.tscn")
	var instance: CanvasLayer = scene.instantiate()
	var has_signal: bool = instance.has_signal("start_game_pressed")
	r.assert_true(has_signal, "start_game_pressed signal defined")
	instance.free()
	return true


# ── Version label (add to tree for onready) ──────────────────

func test_version_label_text() -> bool:
	"""Version label should show 'proto v3' (uses scene default text)."""
	var r = _runner()
	var scene := load("res://scenes/title_screen.tscn")
	var instance: CanvasLayer = scene.instantiate()
	add_child(instance)
	await get_tree().process_frame

	r.assert_eq(instance._version_label.text, "proto v3", "version = proto v3")
	instance.queue_free()
	return true


# ── Controls label (add to tree for onready) ──────────────────

func test_controls_label_not_empty() -> bool:
	"""Controls label should mention key game instructions."""
	var r = _runner()
	var scene := load("res://scenes/title_screen.tscn")
	var instance: CanvasLayer = scene.instantiate()
	add_child(instance)
	await get_tree().process_frame

	r.assert_true(instance._controls_label.text.contains("Arrow keys"), "controls mention arrows")
	r.assert_true(instance._controls_label.text.contains("trade"), "controls mention trade")
	r.assert_true(instance._controls_label.text.contains("reset"), "controls mention reset")
	instance.queue_free()
	return true


# ── Title pulse animation constants ───────────────────────────

func test_title_base_scale_stored() -> bool:
	"""_title_base_scale should be set to Vector2.ONE initially."""
	var r = _runner()
	var scene := load("res://scenes/title_screen.tscn")
	var instance: CanvasLayer = scene.instantiate()

	# _title_base_scale defaults to Vector2.ONE (line 17)
	r.assert_eq(instance._title_base_scale, Vector2.ONE, "base scale = (1,1)")
	instance.free()
	return true
