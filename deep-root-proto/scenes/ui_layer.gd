# ═══════════════════════════════════════════════════════════════
# ui_layer.gd — UILayer scene script
# HUD in Control nodes (replaces _draw() UI)
# ═══════════════════════════════════════════════════════════════
extends CanvasLayer

@onready var _bg_panel: Panel = $Panel
@onready var _title_label: Label = $Panel/VBox/Title
@onready var _stats_label: Label = $Panel/VBox/Stats
@onready var _rivals_label: Label = $Panel/VBox/Rivals
@onready var _trees_label: Label = $Panel/VBox/Trees
@onready var _territory_label: Label = $Panel/VBox/Territory
@onready var _message_label: Label = $Panel/VBox/Message
@onready var _controls_label: Label = $Controls


func _ready() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.state_changed.connect(_on_state_changed)
		gm.show_message.connect(_on_message)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm == null: return

	_title_label.text = "DEEP ROOT proto v3"

	_stats_label.text = (
		"Seed: %d\n" % gm.seed_val +
		"GP: %.1f (%.2f/s)\n" % [gm.player_gp, gm.player_gp_rate] +
		"Water: %d  Minerals: %d  Sugars: %d\n" % [gm.player_water, gm.player_minerals, gm.player_sugars] +
		"Cells: %d  Absorbed: %d" % [gm.player_cells.size(), gm.player_absorbed]
	)

	var rival_text: String = "── Rivals ──\n"
	for rival: Dictionary in gm.get_node_or_null("/root/AIManager").rivals:
		var name: String = ""
		match rival["personality"]:
			"aggressive": name = "Red"
			"defensive": name = "Orange"
			"opportunistic": name = "Violet"
		var phase: String = rival.get("phase", rival["personality"])
		var phase_display: String = ""
		if phase != rival["personality"]:
			phase_display = " [%s]" % phase.capitalize()
		rival_text += "  %s%s: %d cells, %d absorbed\n" % [name, phase_display, rival["cells"].size(), rival["absorbed"]]
	_rivals_label.text = rival_text

	var tree_text: String = "── Trees ──\n"
	var ti: int = 0
	for tree: Dictionary in gm.trees:
		var marker: String = ">" if ti == gm.selected_tree_idx else " "
		var regen_bar: String = ""
		if tree["trades_left"] < gm.MAX_TRADES_PER_TREE:
			regen_bar = _regen_bar(tree["regen_timer"], gm.REGEN_INTERVAL)
		tree_text += "  %sT%d: %d/%d trades%s%s\n" % [
			marker, ti + 1, tree["trades_left"], gm.MAX_TRADES_PER_TREE,
			regen_bar,
			" (CD %.1fs)" % tree["cooldown"] if tree["cooldown"] > 0 else "",
		]
		ti += 1
	_trees_label.text = tree_text

	var total_cells: int = gm.GRID_W * gm.GRID_H
	var pct: float = float(gm.player_cells.size()) / float(total_cells) * 100.0
	_territory_label.text = "Territory: %.1f%%" % pct

	if gm.message_timer > 0 and gm.message_text != "":
		_message_label.text = gm.message_text
		_message_label.visible = true
	else:
		_message_label.visible = false

	var ctrl_text: String = (
		"Click: grow to cell  |  Arrows: grow direction  |  1/2/3: trade\n" +
		"Click tree: select  |  Tab: cycle tree  |  R: reset"
	)
	_controls_label.text = ctrl_text


func _on_state_changed() -> void:
	_refresh()


func _on_message(msg: String) -> void:
	_message_label.text = msg
	_message_label.visible = true

# ── Regen bar helper ──────────────────────────────────────

func _regen_bar(regen_timer: float, interval: float) -> String:
	var progress: float = 1.0 - (regen_timer / interval)
	progress = clampf(progress, 0.0, 1.0)

	const WIDTH: int = 8
	var filled: int = int(round(progress * WIDTH))
	var bar: String = " ["
	for i: int in range(WIDTH):
		if i < filled:
			bar += "\u2588"  # █ full block
		else:
			bar += "\u2591"  # ░ light shade
	bar += "]"
	return bar
