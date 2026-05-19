# ═══════════════════════════════════════════════════════════════
# title_screen.gd — DEEP ROOT Title Screen
# Polished main menu with animated title, smooth fade transitions.
# CanvasLayer that sits on top of a dark ambient background.
# ═══════════════════════════════════════════════════════════════
extends CanvasLayer

# ── Fade state machine ───────────────────────────────────
enum FadeState { FADING_IN, IDLE, FADING_OUT, WAITING }
var _fade_state: int = FadeState.FADING_IN
var _fade_progress: float = 0.0
const FADE_DURATION: float = 0.6
const FADE_HOLD: float = 1.0  # Hold at black before fading in (dramatic pause)

# ── Title animation ──────────────────────────────────────
var _title_anim_t: float = 0.0
var _title_base_scale: Vector2 = Vector2.ONE

# ── Background particles ─────────────────────────────────
const PARTICLE_COUNT: int = 40
var _particles: Array[Dictionary] = []

# ── Signals ──────────────────────────────────────────────
signal start_game_pressed

# ── Nodes ────────────────────────────────────────────────
@onready var _fade_rect: ColorRect = $FadeOverlay
@onready var _bg: ColorRect = $BG
@onready var _title_label: Label = $VBox/TitleLabel
@onready var _subtitle_label: Label = $VBox/SubtitleLabel
@onready var _deco_label: Label = $VBox/DecoLine
@onready var _start_btn: Button = $VBox/StartBtn
@onready var _controls_label: Label = $VBox/ControlsLabel
@onready var _version_label: Label = $VersionLabel
@onready var _particles_node: Control = $Particles


func _ready() -> void:
	# Init fade: start fully black, then fade in
	_fade_rect.modulate = Color(0, 0, 0, 1)
	_fade_progress = 1.0  # Start at black, fade to transparent
	_fade_rect.visible = true

	# Connect button
	_start_btn.pressed.connect(_on_start_pressed)
	_start_btn.mouse_filter = Control.MOUSE_FILTER_STOP

	# Hover effects via mouse_entered/exited
	_start_btn.mouse_entered.connect(_on_btn_hover.bind(true))
	_start_btn.mouse_exited.connect(_on_btn_hover.bind(false))

	# Capture title's base scale
	_title_base_scale = _title_label.scale

	# Init background particles
	_init_particles()
	# Connect particle draw signal so _on_particles_draw actually renders
	_particles_node.draw.connect(_on_particles_draw)

	# Override controls text — it's set in tscn, but make it consistent
	_controls_label.text = "[url=]Arrow keys: grow  |  Click: expand  |  1/2/3: trade  |  Tab: cycle tree  |  R: reset[/url]"

	# Version label
	_version_label.text = "proto v3"


func _process(delta: float) -> void:
	# ── Fade transitions ──────────────────────────────────
	match _fade_state:
		FadeState.FADING_IN:
			_fade_progress -= delta / FADE_DURATION
			if _fade_progress <= 0.0:
				_fade_progress = 0.0
				_fade_rect.modulate = Color(0, 0, 0, 0)
				_fade_state = FadeState.IDLE
			else:
				# Ease out: cubic
				var t: float = 1.0 - _fade_progress
				var eased: float = 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t)
				_fade_rect.modulate = Color(0, 0, 0, eased)

		FadeState.FADING_OUT:
			_fade_progress += delta / FADE_DURATION
			if _fade_progress >= 1.0:
				_fade_progress = 1.0
				_fade_rect.modulate = Color(0, 0, 0, 1)
				# Emit signal so parent can switch to gameplay
				start_game_pressed.emit()
				# Hide UI to prevent double-clicks
				visible = false
				_fade_state = FadeState.WAITING
			else:
				# Ease in: cubic
				var eased: float = _fade_progress * _fade_progress * _fade_progress
				_fade_rect.modulate = Color(0, 0, 0, eased)

	# ── Title pulse animation (only when idle) ────────────
	if _fade_state == FadeState.IDLE:
		_title_anim_t += delta
		var pulse: float = 1.0 + sin(_title_anim_t * 1.8) * 0.025
		var alpha_pulse: float = 1.0 + sin(_title_anim_t * 1.2 + 0.5) * 0.06
		_title_label.scale = _title_base_scale * pulse
		_title_label.modulate = Color(0.95, 0.78, 0.15, alpha_pulse)

	# ── Decorative line wave ──────────────────────────────
	_deco_label.visible = _fade_state == FadeState.IDLE
	if _fade_state == FadeState.IDLE:
		var wave: String = _build_deco_wave(_title_anim_t)
		_deco_label.text = wave

	# ── Background particles ──────────────────────────────
	_update_particles(delta)


# ═══════════════════════════════════════════════════════════════
# BUTTON HANDLING
# ═══════════════════════════════════════════════════════════════

func _on_start_pressed() -> void:
	if _fade_state != FadeState.IDLE:
		return
	# Start fade out → will emit start_game_pressed when black
	_fade_state = FadeState.FADING_OUT
	_fade_progress = 0.0


func _on_btn_hover(hovered: bool) -> void:
	if _fade_state != FadeState.IDLE:
		return
	if hovered:
		_start_btn.modulate = Color(1.0, 0.95, 0.7, 1.0)
		_start_btn.scale = Vector2(1.06, 1.06)
	else:
		_start_btn.modulate = Color(0.95, 0.78, 0.15, 1.0)
		_start_btn.scale = Vector2.ONE


# ═══════════════════════════════════════════════════════════════
# DECORATIVE WAVE
# ═══════════════════════════════════════════════════════════════

func _build_deco_wave(t: float) -> String:
	# Build a sine-wave decorative line using block characters
	const WIDTH: int = 24
	const CHARS: Array[String] = ["_", "‾", "~", "-", "·"]
	var result: String = ""
	for i: int in range(WIDTH):
		var idx: int = int(abs(sin(t * 0.7 + i * 0.35)) * (CHARS.size() - 1))
		result += "[color=#665520]" + CHARS[idx] + "[/color]"
	return result


# ═══════════════════════════════════════════════════════════════
# BACKGROUND PARTICLES (floaty mycelium spores)
# ═══════════════════════════════════════════════════════════════

func _init_particles() -> void:
	_particles.clear()
	for i: int in range(PARTICLE_COUNT):
		_particles.append({
			"x": randf_range(0, 1440),
			"y": randf_range(0, 960),
			"speed": randf_range(8.0, 25.0),
			"size": randf_range(1.0, 3.5),
			"alpha": randf_range(0.15, 0.45),
			"drift": randf_range(-0.5, 0.5),
			"flicker": randf_range(0, TAU),
		})


func _update_particles(delta: float) -> void:
	if _fade_state == FadeState.WAITING:
		return

	var particle_alpha: float = 1.0
	if _fade_state == FadeState.FADING_OUT:
		particle_alpha = 1.0 - _fade_progress
	elif _fade_state == FadeState.FADING_IN:
		particle_alpha = 1.0 - _fade_progress  # _fade_progress goes 1→0

	_particles_node.queue_redraw()

	# Store for _draw()
	for p: Dictionary in _particles:
		p["y"] -= p["speed"] * delta
		p["x"] += p["drift"] * delta * 20.0
		p["flicker"] += delta * randf_range(1.0, 3.0)
		if p["y"] < -10:
			p["y"] = 970
			p["x"] = randf_range(0, 1440)
		if p["x"] < -10:
			p["x"] = 1450
		elif p["x"] > 1450:
			p["x"] = -10

	# Store the current alpha for _draw()
	_particles_node.set_meta("particle_alpha", particle_alpha)


func _on_particles_draw() -> void:
	var alpha_mult: float = _particles_node.get_meta("particle_alpha", 1.0)
	for p: Dictionary in _particles:
		var flick: float = 0.5 + 0.5 * sin(p["flicker"])
		var a: float = p["alpha"] * flick * alpha_mult
		if a < 0.02:
			continue
		var s: float = p["size"]
		# Greenish-gold mycelium spore color
		var col: Color = Color(0.35, 0.55, 0.2, a)
		_particles_node.draw_circle(Vector2(p["x"], p["y"]), s, col)
		# Subtle glow ring
		if s > 1.5:
			_particles_node.draw_circle(Vector2(p["x"], p["y"]), s * 1.8, Color(0.4, 0.6, 0.25, a * 0.3))


# ═══════════════════════════════════════════════════════════════
# PUBLIC API — called by parent to start fade-in
# ═══════════════════════════════════════════════════════════════

func show_title() -> void:
	visible = true
	_fade_state = FadeState.FADING_IN
	_fade_progress = 1.0  # Start fully black
	_fade_rect.modulate = Color(0, 0, 0, 1)
	_title_anim_t = 0.0
	_init_particles()
