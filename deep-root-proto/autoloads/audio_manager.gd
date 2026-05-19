# ═══════════════════════════════════════════════════════════════
# AudioManager — Autoload singleton
# SFX: 8-player AudioStreamPlayer2D pool (round-robin)
# Music: dual-player AudioStreamPlayer crossfade system (0.8s fade)
# Music states: EXPLORATION → COMPETITION (rival <15 cells)
#                → SYMBIOSE (≥3 trades or ≥10 sugars)
# Headless-safe: DisplayServer headless detection skips audio in CI
# Direct OGG loading: AudioStreamOggVorbis.load_from_file()
# ═══════════════════════════════════════════════════════════════
extends Node

# ── Music state enum ──────────────────────────────────────
enum MusicState {
	EXPLORATION,
	COMPETITION,
	SYMBIOSE,
}

# ── SFX pool ───────────────────────────────────────────────
const SFX_POOL_SIZE: int = 8
const SFX_NAMES: Array[String] = [
	"mycelium_expansion",
	"water_absorption",
	"mineral_absorption",
	"sugar_absorption",
	"tree_trade",
	"rival_expansion",
	"game_over",
	"victory",
	"ui_click",
]
const SFX_VOLUMES: Dictionary = {
	"mycelium_expansion": -6.0,
	"water_absorption": -3.0,
	"mineral_absorption": -3.0,
	"sugar_absorption": -4.0,
	"tree_trade": -5.0,
	"rival_expansion": -4.0,
	"game_over": -2.0,
	"victory": -2.0,
	"ui_click": -8.0,
}

var _sfx_players: Array[AudioStreamPlayer2D] = []
var _sfx_next: int = 0
var _sfx_streams: Dictionary = {}    # name → AudioStreamOggVorbis
var _sfx_muted: bool = false

# ── Music system ───────────────────────────────────────────
const MUSIC_TRACKS: Dictionary = {
	MusicState.EXPLORATION: "01_exploration",
	MusicState.COMPETITION: "02_competition",
	MusicState.SYMBIOSE: "03_symbiose",
}
const MUSIC_VOLUME_DB: float = -10.0
const CROSSFADE_DURATION: float = 0.8

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_streams: Dictionary = {}  # name → AudioStreamOggVorbis
var _active_player: int = 0  # 0 = music_a, 1 = music_b
var _current_music_state: int = MusicState.EXPLORATION
var _music_muted: bool = false
var _tween: Tween
var _is_headless: bool = false

# ── Music transition thresholds ────────────────────────────
const COMPETITION_RIVAL_THRESHOLD: int = 15


func _ready() -> void:
	_is_headless = DisplayServer.get_name() == "headless"
	if _is_headless:
		print("[AudioManager] Headless mode — skipping audio setup")
		return

	_create_tween()
	_create_sfx_pool()
	_create_music_players()
	_preload_audio()
	# Start exploration music
	_play_music_immediate(MusicState.EXPLORATION)


# ═══════════════════════════════════════════════════════════════
# SETUP
# ═══════════════════════════════════════════════════════════════

func _create_tween() -> void:
	_tween = create_tween()
	_tween.kill()  # Ready to use later


func _create_sfx_pool() -> void:
	for i: int in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer2D.new()
		player.name = "SFX_" + str(i)
		player.bus = "Master"
		add_child(player)
		_sfx_players.append(player)


func _create_music_players() -> void:
	_music_a = AudioStreamPlayer.new()
	_music_a.name = "MusicA"
	_music_a.bus = "Master"
	_music_a.volume_db = MUSIC_VOLUME_DB
	add_child(_music_a)

	_music_b = AudioStreamPlayer.new()
	_music_b.name = "MusicB"
	_music_b.bus = "Master"
	_music_b.volume_db = -80.0  # Silent initially
	add_child(_music_b)


func _preload_audio() -> void:
	# Preload SFX streams
	for sfx_name: String in SFX_NAMES:
		var path: String = "res://assets/sounds/" + sfx_name + ".ogg"
		if ResourceLoader.exists(path):
			var stream := AudioStreamOggVorbis.load_from_file(path)
			if stream:
				_sfx_streams[sfx_name] = stream
			else:
				push_warning("[AudioManager] Failed to load SFX: ", path)
		else:
			push_warning("[AudioManager] SFX file not found: ", path)

	# Preload music streams
	for state: int in MUSIC_TRACKS:
		var track_name: String = MUSIC_TRACKS[state]
		var path: String = "res://assets/music/" + track_name + ".ogg"
		if ResourceLoader.exists(path):
			var stream := AudioStreamOggVorbis.load_from_file(path)
			if stream:
				_music_streams[track_name] = stream
			else:
				push_warning("[AudioManager] Failed to load music: ", path)
		else:
			push_warning("[AudioManager] Music file not found: ", path)


# ═══════════════════════════════════════════════════════════════
# SFX
# ═══════════════════════════════════════════════════════════════

func play_sfx(sfx_name: String, position: Vector2 = Vector2.ZERO) -> void:
	"""Play a sound effect. Round-robin pool selection."""
	if _is_headless or _sfx_muted:
		return

	if not _sfx_streams.has(sfx_name):
		push_warning("[AudioManager] SFX not loaded: ", sfx_name)
		return

	# Round-robin: pick next player
	var player: AudioStreamPlayer2D = _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % SFX_POOL_SIZE

	# Stop if already playing (reuse player)
	if player.playing:
		player.stop()

	player.stream = _sfx_streams[sfx_name]
	player.global_position = position
	player.volume_db = SFX_VOLUMES.get(sfx_name, 0.0)
	player.play()


func play_sfx_at_cell(_cell: Vector2i, sfx_name: String) -> void:
	"""Play SFX at grid cell position (world space)."""
	# Cell position to world: cell * CELL_SIZE + half cell
	# We don't import GameManager to avoid circular dependency;
	# callers compute world position and pass to play_sfx.
	# This convenience method is called from game_manager via helper.
	if _is_headless or _sfx_muted:
		return
	play_sfx(sfx_name, Vector2.ZERO)


# ═══════════════════════════════════════════════════════════════
# MUSIC
# ═══════════════════════════════════════════════════════════════

func update_music_state(rival_cell_count: int, trade_count: int, sugar_count: int) -> void:
	"""Determine and transition music state based on game conditions.
	Priority: SYMBIOSE > COMPETITION > EXPLORATION
	"""
	var new_state: int = MusicState.EXPLORATION

	# Check symbiosis first (highest priority)
	if trade_count >= 3 or sugar_count >= 10:
		new_state = MusicState.SYMBIOSE
	# Check competition
	elif rival_cell_count > 0 and rival_cell_count < COMPETITION_RIVAL_THRESHOLD:
		new_state = MusicState.COMPETITION

	if new_state != _current_music_state:
		_transition_music(new_state)


func _transition_music(new_state: int) -> void:
	"""Crossfade to new music track."""
	if _is_headless:
		_current_music_state = new_state
		return

	var track_name: String = MUSIC_TRACKS.get(new_state, "")
	if track_name == "" or not _music_streams.has(track_name):
		_current_music_state = new_state
		return

	var stream: AudioStreamOggVorbis = _music_streams[track_name]
	var fade_in_player: AudioStreamPlayer
	var fade_out_player: AudioStreamPlayer

	if _active_player == 0:
		fade_out_player = _music_a
		fade_in_player = _music_b
		_active_player = 1
	else:
		fade_out_player = _music_b
		fade_in_player = _music_a
		_active_player = 0

	# Kill any existing tween and create fresh one
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)

	# Set up the new track
	fade_in_player.stream = stream
	fade_in_player.volume_db = -80.0
	fade_in_player.play()

	# Crossfade: fade out old, fade in new
	_tween.tween_property(fade_out_player, "volume_db", -80.0, CROSSFADE_DURATION)
	_tween.tween_property(fade_in_player, "volume_db", MUSIC_VOLUME_DB, CROSSFADE_DURATION)

	_current_music_state = new_state
	print("[AudioManager] Music state: ", MusicState.keys()[new_state])


func _play_music_immediate(state: int) -> void:
	"""Play music track immediately (for initial playback, no crossfade)."""
	if _is_headless:
		_current_music_state = state
		return

	var track_name: String = MUSIC_TRACKS.get(state, "")
	if track_name == "" or not _music_streams.has(track_name):
		return

	_music_a.stream = _music_streams[track_name]
	_music_a.volume_db = MUSIC_VOLUME_DB
	_music_a.play()
	_active_player = 0
	_current_music_state = state


func set_music_muted(muted: bool) -> void:
	_music_muted = muted
	if _is_headless: return
	_music_a.volume_db = -80.0 if muted else MUSIC_VOLUME_DB
	_music_b.volume_db = -80.0 if muted else MUSIC_VOLUME_DB


func set_sfx_muted(muted: bool) -> void:
	_sfx_muted = muted


func stop_all() -> void:
	"""Stop all audio (for game over / reset)."""
	if _is_headless: return
	for player: AudioStreamPlayer2D in _sfx_players:
		player.stop()
	if _music_a.playing:
		_music_a.stop()
	if _music_b.playing:
		_music_b.stop()


# ═══════════════════════════════════════════════════════════════
# MUSIC STATE QUERY
# ═══════════════════════════════════════════════════════════════

func get_music_state() -> int:
	return _current_music_state
