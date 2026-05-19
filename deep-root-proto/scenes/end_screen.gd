# ═══════════════════════════════════════════════════════════════
# end_screen.gd — EndScreen CanvasLayer
# Shows final stats, progress graph, replay button on game over.
# Fade-in transition on game over with smooth alpha reveal.
# ═══════════════════════════════════════════════════════════════
extends CanvasLayer

@onready var _bg: ColorRect = $BG
@onready var _title: Label = $VBox/Title
@onready var _reason: Label = $VBox/Reason
@onready var _final_stats: Label = $VBox/FinalStats
@onready var _progress_graph: RichTextLabel = $VBox/ProgressGraph
@onready var _rivals_compare: Label = $VBox/RivalsCompare
@onready var _replay_btn: Button = $VBox/ReplayBtn

const GRAPH_WIDTH: int = 50
const GRAPH_HEIGHT: int = 10

# ── Fade-in state ────────────────────────────────────────
var _fade_in_time: float = 0.0
const FADE_IN_DURATION: float = 0.5
var _fading_in: bool = false


func _ready() -> void:
	_replay_btn.pressed.connect(_on_replay_pressed)
	_replay_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	# Start hidden (shown by fade-in on game over)
	visible = false
	_bg.modulate = Color(1, 1, 1, 0)
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.game_ended.connect(_on_game_ended)
		# If already game over (e.g. end_game called before scene loaded)
		if gm.game_over:
			_on_game_ended(gm.game_over_reason)


func _process(delta: float) -> void:
	if _fading_in:
		_fade_in_time += delta
		var t: float = clampf(_fade_in_time / FADE_IN_DURATION, 0.0, 1.0)
		# Ease-out cubic
		var f: float = 1.0 - t
		var eased: float = 1.0 - f * f * f
		_bg.modulate = Color(1, 1, 1, eased)
		# Also fade labels
		for child in $VBox.get_children():
			if child is Label or child is RichTextLabel:
				child.modulate = Color(1, 1, 1, eased)
			elif child is Button:
				child.modulate = Color(1, 1, 1, eased)
		if t >= 1.0:
			_fading_in = false
			_bg.modulate = Color(1, 1, 1, 1)
			for child in $VBox.get_children():
				if child is Label or child is RichTextLabel or child is Button:
					child.modulate = Color(1, 1, 1, 1)


func _on_game_ended(reason: String) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm == null: return

	# Reason display
	match reason:
		"grid_full": _reason.text = "The grid is completely filled!"
		"player_died": _reason.text = "Your mycelium has been eliminated!"
		_: _reason.text = "Game over: " + reason

	# Final stats
	_final_stats.text = _build_final_stats(gm)

	# Progress graph
	_progress_graph.text = _build_progress_graph(gm)

	# Rivals comparison
	_rivals_compare.text = _build_rivals_comparison(gm)

	# Start fade-in
	visible = true
	_fading_in = true
	_fade_in_time = 0.0


func _build_final_stats(gm) -> String:
	var total_trades: int = 0
	for tree: Dictionary in gm.trees:
		total_trades += gm.MAX_TRADES_PER_TREE - tree["trades_left"]

	var text: String = "══ Final Score ══\n\n"
	text += "  Cells grown:    %d\n" % gm.player_cells.size()
	text += "  GP remaining:   %.1f\n" % gm.player_gp
	text += "  Resources absorbed: %d\n" % gm.player_absorbed
	text += "    Water: %d  |  Minerals: %d  |  Sugars: %d\n" % [gm.player_water, gm.player_minerals, gm.player_sugars]
	text += "  Trades completed: %d\n" % total_trades
	text += "  Seed: %d\n" % gm.seed_val
	return text


func _build_progress_graph(gm) -> String:
	if gm.history.is_empty():
		return ""

	# Find max cells for scaling
	var max_cells: int = 1
	for snap: Dictionary in gm.history:
		max_cells = max(max_cells, snap["player_cells"])
		for rc: int in snap["rival_cells"]:
			max_cells = max(max_cells, rc)

	var rows: Array[String] = []
	for _y: int in range(GRAPH_HEIGHT):
		rows.append("")

	var total_rows: int = GRAPH_HEIGHT
	var snaps: Array[Dictionary] = gm.history

	# Downsample if too many snapshots
	var step: int = max(1, snaps.size() / GRAPH_WIDTH)
	var scale: float = float(total_rows) / float(max(max_cells, 1))

	# Build graph: each column = one snapshot, height = player cells
	var graph_str: String = "[b]══ Progress Graph ══[/b]\n"
	graph_str += "  Player(█)  Red(▓)  Orange(▒)  Violet(░)\n\n"

	for row: int in range(total_rows - 1, -1, -1):
		var line: String = "  "
		for col: int in range(0, snaps.size(), step):
			if col >= snaps.size(): break
			var snap: Dictionary = snaps[col]
			var h: int = int(snap["player_cells"] * scale)
			var r0: int = int(snap["rival_cells"][0] * scale) if snap["rival_cells"].size() > 0 else 0
			var r1: int = int(snap["rival_cells"][1] * scale) if snap["rival_cells"].size() > 1 else 0
			var r2: int = int(snap["rival_cells"][2] * scale) if snap["rival_cells"].size() > 2 else 0

			if row < h:
				line += "[color=#40c058]█[/color]"
			elif row < r0:
				line += "[color=#e02e2e]▓[/color]"
			elif row < r1:
				line += "[color=#eb8c14]▒[/color]"
			elif row < r2:
				line += "[color=#a62ed9]░[/color]"
			else:
				line += " "
		graph_str += line + "\n"

	# Time axis
	graph_str += "  "
	for col: int in range(0, snaps.size(), step):
		if col >= snaps.size(): break
		graph_str += "▔"
	graph_str += "\n  "
	# Show a few time labels
	var n_snaps: int = snaps.size()
	if n_snaps > 0:
		var last_t: float = snaps[n_snaps - 1]["t"]
		graph_str += "0s"
		var mid_str: String = "%.0fs" % (last_t / 2.0)
		var end_str: String = "%.0fs" % last_t
		var pad: int = max(0, GRAPH_WIDTH - len("0s") - len(end_str))
		graph_str += mid_str
		# Just append end time
		graph_str += end_str

	return graph_str


func _build_rivals_comparison(gm) -> String:
	var am = get_node_or_null("/root/AIManager")
	if am == null: return ""

	var text: String = "══ Rivals Comparison ══\n\n"
	var names: Array[String] = ["Red (Aggressive)", "Orange (Defensive)", "Violet (Opportunistic)"]
	var player_cells: int = gm.player_cells.size()
	var player_absorbed: int = gm.player_absorbed

	for i: int in range(min(am.rivals.size(), 3)):
		var rival: Dictionary = am.rivals[i]
		var name: String = names[i] if i < names.size() else "Rival %d" % (i + 1)
		var rc: int = rival["cells"].size()
		var ra: int = rival["absorbed"]
		var vs_player: String = ""
		if rc > player_cells:
			vs_player = " (↑ +%d vs you)" % (rc - player_cells)
		elif rc < player_cells:
			vs_player = " (↓ -%d vs you)" % (player_cells - rc)
		else:
			vs_player = " (= even)"
		text += "  %s:\n" % name
		text += "    Cells: %d%s\n" % [rc, vs_player]
		text += "    Absorbed: %d\n" % ra
		text += "\n"

	return text


func _on_replay_pressed() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.reset()
	visible = false
	_bg.modulate = Color(1, 1, 1, 0)
	_fading_in = false
	_fade_in_time = 0.0
