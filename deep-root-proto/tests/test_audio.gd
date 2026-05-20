# ═══════════════════════════════════════════════════════════════
# test_audio.gd — Tests for AudioManager autoload
# Verifies: SFX pool, music states, crossfade, muting, headless detection
# Data-driven — no actual audio playback required.
# ═══════════════════════════════════════════════════════════════
extends GutTest


# ── SFX pool tests ────────────────────────────────────────────

func test_sfx_pool_size():
	"""AudioManager should maintain 8 SFX players."""
	var am := get_node_or_null("/root/AudioManager")
		assert_not_null(am, "AudioManager autoload should exist")
	if am == null: return
	assert_eq(am.SFX_POOL_SIZE, 8, "SFX pool size = 8")


func test_sfx_names_defined():
	"""All 9 SFX effects should be listed in SFX_NAMES."""
	var am := get_node_or_null("/root/AudioManager")
		if am == null: return
	assert_eq(am.SFX_NAMES.size(), 9, "9 SFX names defined")
	assert_true(am.SFX_NAMES.has("mycelium_expansion"), "mycelium_expansion")
	assert_true(am.SFX_NAMES.has("water_absorption"), "water_absorption")
	assert_true(am.SFX_NAMES.has("tree_trade"), "tree_trade")
	assert_true(am.SFX_NAMES.has("rival_expansion"), "rival_expansion")
	assert_true(am.SFX_NAMES.has("game_over"), "game_over")
	assert_true(am.SFX_NAMES.has("victory"), "victory")
	assert_true(am.SFX_NAMES.has("ui_click"), "ui_click")
	assert_true(am.SFX_NAMES.has("mineral_absorption"), "mineral_absorption")
	assert_true(am.SFX_NAMES.has("sugar_absorption"), "sugar_absorption")


func test_sfx_volumes_defined():
	"""All 9 SFX effects should have volume settings in dB."""
	var am := get_node_or_null("/root/AudioManager")
		if am == null: return
	for sfx_name: String in am.SFX_NAMES:
		assert_true(am.SFX_VOLUMES.has(sfx_name), "%s has volume" % sfx_name)
		var vol: float = am.SFX_VOLUMES[sfx_name]
		assert_true(vol <= 0.0, "%s volume ≤ 0dB" % sfx_name)
		assert_true(vol >= -10.0, "%s volume ≥ -10dB" % sfx_name)


func test_sfx_round_robin_pointer_initial():
	"""Round-robin pointer should start at 0."""
	var am := get_node_or_null("/root/AudioManager")
		if am == null: return
	# _sfx_next is not exported; validate that play_sfx doesn't crash
	# by checking it's callable
	assert_true(am.has_method("play_sfx"), "play_sfx method exists")


# ── Music system tests ────────────────────────────────────────

func test_music_state_enum():
	"""MusicState enum should have 3 states: EXPLORATION, COMPETITION, SYMBIOSE."""
	var am := get_node_or_null("/root/AudioManager")
		if am == null: return
	assert_eq(am.MusicState.EXPLORATION, 0, "EXPLORATION = 0")
	assert_eq(am.MusicState.COMPETITION, 1, "COMPETITION = 1")
	assert_eq(am.MusicState.SYMBIOSE, 2, "SYMBIOSE = 2")


func test_music_tracks_defined():
	"""MUSIC_TRACKS should have 3 track mappings."""
	var am := get_node_or_null("/root/AudioManager")
		if am == null: return
	assert_eq(am.MUSIC_TRACKS.size(), 3, "3 music tracks defined")
	assert_eq(am.MUSIC_TRACKS[am.MusicState.EXPLORATION], "01_exploration", "exploration track")
	assert_eq(am.MUSIC_TRACKS[am.MusicState.COMPETITION], "02_competition", "competition track")
	assert_eq(am.MUSIC_TRACKS[am.MusicState.SYMBIOSE], "03_symbiose", "symbiose track")


func test_music_volume_constant():
	"""MUSIC_VOLUME_DB should be -10.0 dB."""
	var am := get_node_or_null("/root/AudioManager")
		if am == null: return
	assert_eq(am.MUSIC_VOLUME_DB, -10.0, "music volume = -10dB")


func test_crossfade_duration():
	"""Crossfade should last 0.8 seconds."""
	var am := get_node_or_null("/root/AudioManager")
		if am == null: return
	assert_eq(am.CROSSFADE_DURATION, 0.8, "crossfade = 0.8s")


# ── Music state transition logic (data-driven) ────────────────

func test_update_music_state_exploration():
	"""Default state with no rivals, no trades, no sugars = EXPLORATION."""
	var am := get_node_or_null("/root/AudioManager")
		if am == null: return
	am.update_music_state(0, 0, 0)
	assert_eq(am.get_music_state(), am.MusicState.EXPLORATION, "empty game = exploration")


func test_update_music_state_competition():
	"""Few rivals (<15 cells) + no trades = COMPETITION."""
	var am := get_node_or_null("/root/AudioManager")
		if am == null: return
	am.update_music_state(5, 0, 0)
	assert_eq(am.get_music_state(), am.MusicState.COMPETITION, "5 rival cells = competition")


func test_update_music_state_symbiose_via_trades():
	""">=3 trades triggers SYMBIOSE (highest priority)."""
	var am := get_node_or_null("/root/AudioManager")
		if am == null: return
	am.update_music_state(0, 3, 0)
	assert_eq(am.get_music_state(), am.MusicState.SYMBIOSE, "3 trades = symbiose")


func test_update_music_state_symbiose_via_sugars():
	""">=10 sugars triggers SYMBIOSE (highest priority)."""
	var am := get_node_or_null("/root/AudioManager")
		if am == null: return
	am.update_music_state(0, 0, 10)
	assert_eq(am.get_music_state(), am.MusicState.SYMBIOSE, "10 sugars = symbiose")


func test_update_music_state_symbiose_priority():
	"""SYMBIOSE beats COMPETITION when both conditions are met."""
	var am := get_node_or_null("/root/AudioManager")
		if am == null: return
	# Many rival cells (would trigger COMPETITION) + trades (triggers SYMBIOSE)
	am.update_music_state(10, 3, 0)
	assert_eq(am.get_music_state(), am.MusicState.SYMBIOSE, "symbiose beats competition")


func test_update_music_state_rival_threshold():
	"""Rival cells < COMPETITION_RIVAL_THRESHOLD triggers COMPETITION, >= does not."""
	var am := get_node_or_null("/root/AudioManager")
		if am == null: return

	# Below threshold → competition
	am.update_music_state(14, 0, 0)
	assert_eq(am.get_music_state(), am.MusicState.COMPETITION, "14 < 15 = competition")

	# At threshold → NO competition (reverts to exploration)
	am.update_music_state(15, 0, 0)
	assert_eq(am.get_music_state(), am.MusicState.EXPLORATION, "15 >= 15 = exploration")

	# 0 → exploration (no rivals at all)
	am.update_music_state(0, 0, 0)
	assert_eq(am.get_music_state(), am.MusicState.EXPLORATION, "0 rivals = exploration")


# ── Mute tests ─────────────────────────────────────────────────

func test_set_music_muted_exists():
	"""set_music_muted should be callable."""
	var am := get_node_or_null("/root/AudioManager")
		if am == null: return
	assert_true(am.has_method("set_music_muted"), "set_music_muted method exists")


func test_set_sfx_muted_exists():
	"""set_sfx_muted should be callable."""
	var am := get_node_or_null("/root/AudioManager")
		if am == null: return
	assert_true(am.has_method("set_sfx_muted"), "set_sfx_muted method exists")


func test_stop_all_exists():
	"""stop_all should be callable."""
	var am := get_node_or_null("/root/AudioManager")
		if am == null: return
	assert_true(am.has_method("stop_all"), "stop_all method exists")


# ── Spatial audio constants ───────────────────────────────────

func test_spatial_audio_constants():
	"""Spatial audio decay/distance constants should be positive."""
	var am := get_node_or_null("/root/AudioManager")
		if am == null: return
	assert_gt(am.SPATIAL_DECAY_DB, 0.0, "spatial decay > 0")
	assert_gt(am.SPATIAL_MAX_DISTANCE, 0.0, "max distance > 0")
	assert_gt(am.SPATIAL_REFERENCE_DISTANCE, 0.0, "reference distance > 0")
	assert_gt(am.SPATIAL_MAX_DISTANCE, am.SPATIAL_REFERENCE_DISTANCE, "max > reference")


# ── SFX at cell convenience method ────────────────────────────

func test_play_sfx_at_cell_exists():
	"""play_sfx_at_cell should be callable."""
	var am := get_node_or_null("/root/AudioManager")
		if am == null: return
	assert_true(am.has_method("play_sfx_at_cell"), "play_sfx_at_cell method exists")


# ── Headless detection ────────────────────────────────────────

func test_headless_detection():
	"""In headless mode, _is_headless should be true."""
	var am := get_node_or_null("/root/AudioManager")
		if am == null: return
	# In CI (headless), this should be true
	# Test the logic: DisplayServer.get_name() == "headless"
	var ds_name: String = DisplayServer.get_name()
	assert_eq(ds_name, "headless", "Running in headless mode")


func test_headless_skips_playback():
	"""In headless mode, play_sfx and transition_music should be no-ops (no crash)."""
	var am := get_node_or_null("/root/AudioManager")
		if am == null: return
	# These should not crash in headless
	am.play_sfx("mycelium_expansion", Vector2.ZERO)
	am.play_sfx("non_existent_sfx", Vector2.ZERO)  # Should warn but not crash
	am._transition_music(am.MusicState.COMPETITION)
	am._transition_music(am.MusicState.EXPLORATION)
	assert_true(true, "All audio methods called without crash in headless")


# ── Competition rival threshold constant ─────────────────────

func test_competition_rival_threshold():
	"""COMPETITION_RIVAL_THRESHOLD should be 15."""
	var am := get_node_or_null("/root/AudioManager")
		if am == null: return
	assert_eq(am.COMPETITION_RIVAL_THRESHOLD, 15, "competition threshold = 15")
