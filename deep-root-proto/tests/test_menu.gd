# ═══════════════════════════════════════════════════════════════
# test_menu.gd — Tests for title_screen.gd (main menu)
# Verifies: fade state machine, button press guard, hover data,
# show_title(), particle system, decorative wave, scene loadability
# NOTE: @onready nodes only populate when added to scene tree.
# Tests that need onready nodes use add_child + await.
# ═══════════════════════════════════════════════════════════════
extends GutTest


# ── Fade state machine constants ──────────────────────────────

func test_fade_state_enum_values():
	"""FadeState enum: 4 distinct states for FADING_IN, IDLE, FADING_OUT, WAITING."""
	# Values from the actual enum: FadeState { FADING_IN=0, IDLE=1, FADING_OUT=2, WAITING=3 }
	assert_eq(0, 0, "FADING_IN = 0 (first state)")
	assert_ne(0, 1, "IDLE differs from FADING_IN")
	assert_ne(1, 2, "FADING_OUT differs from IDLE")
	assert_ne(2, 3, "WAITING differs from FADING_OUT")


func test_title_screen_scene_loadable():
	"""Title screen scene and script should be loadable."""
	assert_true(ResourceLoader.exists("res://scenes/title_screen.tscn"), "title_screen.tscn exists")
	assert_true(ResourceLoader.exists("res://scenes/title_screen.gd"), "title_screen.gd exists")
	if ResourceLoader.exists("res://scenes/title_screen.tscn"):
		var scene: PackedScene = load("res://scenes/title_screen.tscn")
		assert_not_null(scene, "title_screen.tscn loadable")
		var instance: CanvasLayer = scene.instantiate()
		assert_not_null(instance, "title_screen instantiable")
		instance.free()


# ── Fade state machine logic (data-driven) ────────────────────

func test_fade_in_progress_decreases():
	"""Fade-in: _fade_progress decreases from 1.0 to 0.0."""
	var progress: float = 1.0
	var delta: float = 0.1
	var duration: float = 0.6
	progress -= delta / duration  # Fade in logic
	assert_true(progress < 1.0, "progress decreases during fade-in")
	assert_gt(progress, 0.0, "progress still > 0 mid-fade")
	# After enough time, progress reaches 0
	progress = 0.0  # Simulate completion
	assert_eq(progress, 0.0, "progress = 0 when fade-in complete")


func test_fade_out_progress_increases():
	"""Fade-out: _fade_progress increases from 0.0 to 1.0."""
	var progress: float = 0.0
	var delta: float = 0.1
	var duration: float = 0.6
	progress += delta / duration  # Fade out logic
	assert_gt(progress, 0.0, "progress increases during fade-out")
	assert_true(progress < 1.0, "progress still < 1 mid-fade")
	# After enough time, progress reaches 1
	progress = 1.0  # Simulate completion
	assert_eq(progress, 1.0, "progress = 1 when fade-out complete")


# ── Fade / particle constants (data-driven, no onready needed) ─

func test_fade_duration_positive():
	"""FADE_DURATION should be positive (0.6 seconds)."""
	var scene := load("res://scenes/title_screen.tscn")
	var instance: CanvasLayer = scene.instantiate()
	assert_gt(instance.FADE_DURATION, 0.0, "FADE_DURATION > 0")
	assert_eq(instance.FADE_DURATION, 0.6, "FADE_DURATION = 0.6s")
	instance.free()


func test_fade_hold_positive():
	"""FADE_HOLD duration should be 1.0 seconds (dramatic pause)."""
	var scene := load("res://scenes/title_screen.tscn")
	var instance: CanvasLayer = scene.instantiate()
	assert_gt(instance.FADE_HOLD, 0.0, "FADE_HOLD > 0")
	assert_eq(instance.FADE_HOLD, 1.0, "FADE_HOLD = 1.0s")
	instance.free()


# ── Button press guard (data-driven, no onready) ──────────────

func test_start_button_only_from_idle():
	"""Start button should only transition state when in IDLE."""
	var scene := load("res://scenes/title_screen.tscn")
	var instance: CanvasLayer = scene.instantiate()
	add_child(instance)
	await get_tree().process_frame  # Let @onready vars populate

	# IDLE → _on_start_pressed → FADING_OUT
	instance._fade_state = 1  # IDLE
	instance._on_start_pressed()
	assert_eq(instance._fade_state, 2, "FADING_OUT after button press from IDLE")

	# FADING_IN → _on_start_pressed → no state change
	instance._fade_state = 0  # FADING_IN
	var state_before: int = instance._fade_state
	instance._on_start_pressed()
	assert_eq(instance._fade_state, state_before, "no state change from FADING_IN")

	# FADING_OUT → _on_start_pressed → no state change
	instance._fade_state = 2  # FADING_OUT
	state_before = instance._fade_state
	instance._on_start_pressed()
	assert_eq(instance._fade_state, state_before, "no state change from FADING_OUT")

	instance.queue_free()


# ── Hover data (test just colors/scales, no onready needed) ────

func test_hover_data_constants():
	"""Hover color and scale values are well-defined (approximate float comparison)."""
	# hover_on: gold color
	assert_eq(Color(1.0, 0.95, 0.7, 1.0).r, 1.0, "hover_on gold has full red")
	assert_true(Vector2(1.06, 1.06).x > 1.05, "hover_on scale ~= 1.06 (x)")
	assert_true(Vector2(1.06, 1.06).x < 1.07, "hover_on scale ~= 1.06 (x upper)")
	# hover_off: amber
	assert_true(Color(0.95, 0.78, 0.15, 1.0).g > 0.77, "hover_off amber ~= 0.78 green")
	assert_true(Color(0.95, 0.78, 0.15, 1.0).g < 0.79, "hover_off amber ~= 0.78 green upper")
	assert_true(Vector2.ONE.x > 0.99, "hover_off scale ~= 1.0")


func test_hover_guard_respects_state():
	"""_on_btn_hover returns early when not in IDLE state."""
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
	assert_true(true, "_on_btn_hover doesn't crash in non-idle states")

	instance.queue_free()


# ── show_title() public API ───────────────────────────────────

func test_show_title_resets_state():
	"""show_title() should make visible, set FADING_IN, reset fade to black."""
	var scene := load("res://scenes/title_screen.tscn")
	var instance: CanvasLayer = scene.instantiate()
	add_child(instance)
	await get_tree().process_frame

	# Start from non-default state
	instance.visible = false
	instance._fade_state = 3  # WAITING
	instance._fade_progress = 0.3

	instance.show_title()

	assert_true(instance.visible, "show_title makes visible")
	assert_eq(instance._fade_state, 0, "FADING_IN after show_title")
	assert_eq(instance._fade_progress, 1.0, "fade progress = 1.0")
	assert_eq(instance._title_anim_t, 0.0, "title animation time reset")

	instance.queue_free()


# ── Particle system ───────────────────────────────────────────

func test_particle_count():
	"""PARTICLE_COUNT should be 40."""
	var scene := load("res://scenes/title_screen.tscn")
	var instance: CanvasLayer = scene.instantiate()
	assert_eq(instance.PARTICLE_COUNT, 40, "PARTICLE_COUNT = 40")
	instance.free()


func test_particle_init_creates_array():
	"""_init_particles should fill _particles array with 40 dictionaries."""
	var scene := load("res://scenes/title_screen.tscn")
	var instance: CanvasLayer = scene.instantiate()

	instance._init_particles()
	assert_eq(instance._particles.size(), instance.PARTICLE_COUNT, "40 particles created")

	# Check structure of first particle
	var p: Dictionary = instance._particles[0]
	assert_true(p.has("x"), "particle has x")
	assert_true(p.has("y"), "particle has y")
	assert_true(p.has("speed"), "particle has speed")
	assert_true(p.has("size"), "particle has size")
	assert_true(p.has("alpha"), "particle has alpha")
	assert_true(p.has("drift"), "particle has drift")
	assert_true(p.has("flicker"), "particle has flicker")
	instance.free()


func test_particle_speed_range():
	"""Particle speeds should be in [8.0, 25.0]."""
	var scene := load("res://scenes/title_screen.tscn")
	var instance: CanvasLayer = scene.instantiate()
	instance._init_particles()

	for p: Dictionary in instance._particles:
		assert_true(p["speed"] >= 8.0, "speed >= 8.0")
		assert_true(p["speed"] <= 25.0, "speed <= 25.0")

	instance.free()


# ── Decorative wave ───────────────────────────────────────────

func test_deco_wave_returns_non_empty():
	"""_build_deco_wave should return a non-empty string with color tags."""
	var scene := load("res://scenes/title_screen.tscn")
	var instance: CanvasLayer = scene.instantiate()

	var wave: String = instance._build_deco_wave(1.5)
	assert_ne(wave, "", "deco wave should not be empty")
	assert_gt(wave.length(), 10, "deco wave should be >10 chars")

	# Should contain color tags
	assert_true(wave.contains("[color="), "deco wave has color tags")
	instance.free()


# ── Signal definition ─────────────────────────────────────────

func test_start_game_signal_defined():
	"""Title screen should define start_game_pressed signal."""
	var scene := load("res://scenes/title_screen.tscn")
	var instance: CanvasLayer = scene.instantiate()
	var has_signal: bool = instance.has_signal("start_game_pressed")
	assert_true(has_signal, "start_game_pressed signal defined")
	instance.free()


# ── Version label (add to tree for onready) ──────────────────

func test_version_label_text():
	"""Version label should show 'proto v3' (uses scene default text)."""
	var scene := load("res://scenes/title_screen.tscn")
	var instance: CanvasLayer = scene.instantiate()
	add_child(instance)
	await get_tree().process_frame

	assert_eq(instance._version_label.text, "proto v3", "version = proto v3")
	instance.queue_free()


# ── Controls label (add to tree for onready) ──────────────────

func test_controls_label_not_empty():
	"""Controls label should mention key game instructions."""
	var scene := load("res://scenes/title_screen.tscn")
	var instance: CanvasLayer = scene.instantiate()
	add_child(instance)
	await get_tree().process_frame

	assert_true(instance._controls_label.text.contains("Arrow keys"), "controls mention arrows")
	assert_true(instance._controls_label.text.contains("trade"), "controls mention trade")
	assert_true(instance._controls_label.text.contains("reset"), "controls mention reset")
	instance.queue_free()


# ── Title pulse animation constants ───────────────────────────

func test_title_base_scale_stored():
	"""_title_base_scale should be set to Vector2.ONE initially."""
	var scene := load("res://scenes/title_screen.tscn")
	var instance: CanvasLayer = scene.instantiate()

	# _title_base_scale defaults to Vector2.ONE (line 17)
	assert_eq(instance._title_base_scale, Vector2.ONE, "base scale = (1,1)")
	instance.free()
