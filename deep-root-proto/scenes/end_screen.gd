# ═══════════════════════════════════════════════════════════════
# end_screen.gd — EndScreen CanvasLayer
# Shows final stats bar charts, progress line graph, run summary,
# rival comparison, and replay button on game over.
# Uses Godot _draw() for real graphical charts.
# ═══════════════════════════════════════════════════════════════
extends CanvasLayer

# ── Node references ───────────────────────────────────────
@onready var _bg: ColorRect = $BG
@onready var _panel: Panel = $Panel
@onready var _title: Label = $Panel/Margin/VBox/Title
@onready var _reason: Label = $Panel/Margin/VBox/Reason
@onready var _summary: RichTextLabel = $Panel/Margin/VBox/SummarySection/SummaryText
@onready var _resource_graph: Control = $Panel/Margin/VBox/ChartsRow/ResourceChart
@onready var _progress_graph: Control = $Panel/Margin/VBox/ChartsRow/ProgressChart
@onready var _rivals_grid: GridContainer = $Panel/Margin/VBox/RivalsSection/RivalsGrid
@onready var _rival1_cells: Label = $Panel/Margin/VBox/RivalsSection/RivalsGrid/Rival1/Cells
@onready var _rival1_absorbed: Label = $Panel/Margin/VBox/RivalsSection/RivalsGrid/Rival1/Absorbed
@onready var _rival2_cells: Label = $Panel/Margin/VBox/RivalsSection/RivalsGrid/Rival2/Cells
@onready var _rival2_absorbed: Label = $Panel/Margin/VBox/RivalsSection/RivalsGrid/Rival2/Absorbed
@onready var _rival3_cells: Label = $Panel/Margin/VBox/RivalsSection/RivalsGrid/Rival3/Cells
@onready var _rival3_absorbed: Label = $Panel/Margin/VBox/RivalsSection/RivalsGrid/Rival3/Absorbed
@onready var _replay_btn: Button = $Panel/Margin/VBox/ReplayBtn


func _ready() -> void:
	_replay_btn.pressed.connect(_on_replay_pressed)
	_replay_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.game_ended.connect(_on_game_ended)
		if gm.game_over:
			_on_game_ended(gm.game_over_reason)
	# Connect draw signals for chart controls
	_resource_graph.draw.connect(_draw_resource_chart)
	_progress_graph.draw.connect(_draw_progress_chart)


func _on_game_ended(reason: String) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm == null: return

	# Reason
	match reason:
		"grid_full": _reason.text = "The grid is completely filled!"
		"player_died": _reason.text = "Your mycelium has been eliminated!"
		_: _reason.text = "Game over: " + reason

	# Build summary
	_summary.text = _build_run_summary(gm)

	# Queue chart redraws
	_resource_graph.queue_redraw()
	_progress_graph.queue_redraw()

	# Rivals comparison
	_update_rivals(gm)

	visible = true


# ═══════════════════════════════════════════════════════════════
# RUN SUMMARY — Narrative text describing the outcome
# ═══════════════════════════════════════════════════════════════

func _build_run_summary(gm) -> String:
	var total_trades: int = 0
	for tree: Dictionary in gm.trees:
		total_trades += gm.MAX_TRADES_PER_TREE - tree["trades_left"]

	var cells: int = gm.player_cells.size()
	var absorbed: int = gm.player_absorbed
	var sugars: int = gm.player_sugars
	var minerals: int = gm.player_minerals
	var water: int = gm.player_water

	# Determine performance tier
	var perf_tier: String = "modest"
	if cells >= 200:
		perf_tier = "legendary"
	elif cells >= 100:
		perf_tier = "impressive"
	elif cells >= 50:
		perf_tier = "solid"

	var tier_color: String = "#40c058"
	var tier_icon: String = ""
	match perf_tier:
		"legendary":
			tier_color = "#ffd700"
			tier_icon = "[TROPHY] "
		"impressive":
			tier_color = "#a62ed9"
			tier_icon = "[STAR] "
		"solid":
			tier_color = "#40c058"
			tier_icon = "[SEEDLING] "
		_:
			tier_color = "#888888"
			tier_icon = ""

	# Rival comparison
	var am = get_node_or_null("/root/AIManager")
	var beat_count: int = 0
	var lost_count: int = 0
	if am:
		for rival: Dictionary in am.rivals:
			if rival["cells"].size() < cells:
				beat_count += 1
			elif rival["cells"].size() > cells:
				lost_count += 1

	var text: String = "[center]"
	text += "[color=%s][b]%s%s PERFORMANCE[/b][/color]\n\n" % [tier_color, tier_icon, perf_tier.to_upper()]

	# Core stats
	text += "Spread to [b]%d[/b] cells across the grid\n" % cells
	text += "Absorbed [b]%d[/b] resources (%d water, %d minerals, %d sugars)\n" % [absorbed, water, minerals, sugars]
	text += "Completed [b]%d[/b] trades with the ancient trees\n" % total_trades

	# Rival outcomes
	if beat_count > 0 or lost_count > 0:
		if beat_count > 0:
			text += "Outgrew [b]%d[/b] rival%s" % [beat_count, "s" if beat_count > 1 else ""]
		if lost_count > 0:
			if beat_count > 0:
				text += ", but "
			else:
				text += "Lost to "
			text += "[b]%d[/b] rival%s" % [lost_count, "s" if lost_count > 1 else ""]
		text += "\n"

	# GP info
	text += "Ended with [b]%.1f[/b] GP\n" % gm.player_gp
	text += "Seed: [b]%d[/b]" % gm.seed_val
	text += "[/center]"
	return text


# ═══════════════════════════════════════════════════════════════
# RESOURCE BAR CHART — Horizontal bars for each resource type
# ═══════════════════════════════════════════════════════════════

func _draw_resource_chart() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm == null: return

	var chart: Control = _resource_graph
	var w: float = chart.size.x
	var h: float = chart.size.y
	if w <= 0 or h <= 0: return

	var bar_h: float = 26.0
	var bar_gap: float = 10.0
	var left_margin: float = 110.0
	var right_margin: float = 50.0
	var chart_area: float = w - left_margin - right_margin
	var y: float = 16.0

	# Determine max values for scaling
	var players: Array[Vector2i] = gm.player_cells
	var max_cells: int = players.size()
	var am = get_node_or_null("/root/AIManager")
	if am:
		for rival: Dictionary in am.rivals:
			max_cells = max(max_cells, rival["cells"].size())
	max_cells = max(max_cells, 1)

	var max_absorbed: int = max(gm.player_absorbed, 1)
	if am:
		for rival: Dictionary in am.rivals:
			max_absorbed = max(max_absorbed, rival.get("absorbed", 0))

	var total_cells_all: int = max_cells * 4  # rough scale for territory
	var total: int = gm.GRID_W * gm.GRID_H

	var resources: Array[Dictionary] = [
		{"label": "Cells", "value": players.size(), "max": float(max_cells), "color": Color(0.3, 0.7, 0.7)},
		{"label": "Water", "value": float(gm.player_water), "max": float(max(1, gm.player_water)), "color": Color(0.18, 0.38, 0.85)},
		{"label": "Minerals", "value": float(gm.player_minerals), "max": float(max(1, gm.player_minerals)), "color": Color(0.65, 0.55, 0.25)},
		{"label": "Sugars", "value": float(gm.player_sugars), "max": float(max(1, gm.player_sugars)), "color": Color(0.95, 0.80, 0.25)},
		{"label": "Absorbed", "value": float(gm.player_absorbed), "max": float(max(1, max_absorbed)), "color": Color(0.25, 0.75, 0.35)},
		{"label": "Territory", "value": players.size(), "max": float(total), "color": Color(0.6, 0.4, 0.95)},
	]

	for res: Dictionary in resources:
		# Label
		chart.draw_string(
			ThemeDB.fallback_font,
			Vector2(4, y + bar_h * 0.65),
			res["label"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(0.8, 0.8, 0.8)
		)

		# Background bar (dark)
		var bar_bg := Rect2(left_margin, y, chart_area, bar_h)
		chart.draw_rect(bar_bg, Color(0.1, 0.1, 0.15), true)

		# Filled bar
		var ratio: float = clampf(res["value"] / res["max"], 0.0, 1.0)
		var bar_fill := Rect2(left_margin, y, chart_area * ratio, bar_h)
		chart.draw_rect(bar_fill, res["color"], true)

		# Border
		chart.draw_rect(bar_bg, Color(0.25, 0.25, 0.35), false, 1.0)

		# Value text inside/next to bar
		var val_text: String
		if res["label"] == "Territory":
			val_text = "%.1f%%" % (ratio * 100.0)
		else:
			val_text = str(int(res["value"]))
		chart.draw_string(
			ThemeDB.fallback_font,
			Vector2(left_margin + chart_area + 4, y + bar_h * 0.65),
			val_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(0.9, 0.9, 0.9)
		)

		y += bar_h + bar_gap

	# Title
	chart.draw_string(
		ThemeDB.fallback_font,
		Vector2(4, 10),
		"Resources",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
		Color(0.95, 0.80, 0.25)
	)


# ═══════════════════════════════════════════════════════════════
# PROGRESS LINE CHART — Player + Rivals over time
# ═══════════════════════════════════════════════════════════════

func _draw_progress_chart() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm == null: return

	var chart: Control = _progress_graph
	var w: float = chart.size.x
	var h: float = chart.size.y
	if w <= 0 or h <= 0: return

	var margin_left: float = 42.0
	var margin_right: float = 12.0
	var margin_top: float = 22.0
	var margin_bottom: float = 24.0
	var plot_w: float = w - margin_left - margin_right
	var plot_h: float = h - margin_top - margin_bottom

	# ── Title ────────────────────────────────────────────
	chart.draw_string(
		ThemeDB.fallback_font,
		Vector2(margin_left, 10),
		"Growth over Time",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
		Color(0.95, 0.80, 0.25)
	)

	if gm.history.is_empty(): return

	var snaps: Array[Dictionary] = gm.history
	if snaps.size() < 2: return

	# Downsample to fit plot width
	var step: int = max(1, snaps.size() / int(plot_w))

	# Find max cells for Y scaling
	var max_cells: float = 1.0
	for snap: Dictionary in snaps:
		max_cells = max(max_cells, float(snap["player_cells"]))
		for rc: int in snap["rival_cells"]:
			max_cells = max(max_cells, float(rc))

	# ── Background ───────────────────────────────────────
	var plot_rect := Rect2(margin_left, margin_top, plot_w, plot_h)
	chart.draw_rect(plot_rect, Color(0.05, 0.05, 0.12, 0.9), true)

	# ── Grid lines ───────────────────────────────────────
	var grid_steps: int = 5
	var grid_color := Color(0.15, 0.18, 0.25, 0.5)
	for i: int in range(grid_steps + 1):
		var gy: float = margin_top + plot_h * float(i) / float(grid_steps)
		chart.draw_line(Vector2(margin_left, gy), Vector2(margin_left + plot_w, gy), grid_color, 1.0)

	# ── Y-axis labels ───────────────────────────────────
	for i: int in range(grid_steps + 1):
		var val: int = int(max_cells * (1.0 - float(i) / float(grid_steps)))
		var gy: float = margin_top + plot_h * float(i) / float(grid_steps)
		chart.draw_string(
			ThemeDB.fallback_font,
			Vector2(2, gy - 6),
			str(val),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			Color(0.5, 0.5, 0.6)
		)

	# ── X-axis time labels ───────────────────────────────
	if not snaps.is_empty():
		var last_t: float = snaps[snaps.size() - 1]["t"]
		chart.draw_string(
			ThemeDB.fallback_font,
			Vector2(margin_left, margin_top + plot_h + 4),
			"0s",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			Color(0.5, 0.5, 0.6)
		)
		var end_str: String = "%.0fs" % last_t
		var end_size: Vector2 = ThemeDB.fallback_font.get_string_size(end_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		chart.draw_string(
			ThemeDB.fallback_font,
			Vector2(margin_left + plot_w - end_size.x, margin_top + plot_h + 4),
			end_str,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			Color(0.5, 0.5, 0.6)
		)

	# ── Draw lines ───────────────────────────────────────
	var series: Array[Dictionary] = [
		{"key": "player_cells", "color": Color(0.25, 0.75, 0.35), "label": "You"},
		{"key": "rival0", "color": Color(0.88, 0.18, 0.18), "label": "Red"},
		{"key": "rival1", "color": Color(0.92, 0.55, 0.08), "label": "Orange"},
		{"key": "rival2", "color": Color(0.65, 0.18, 0.85), "label": "Violet"},
	]

	var legend_x: float = margin_left

	for si: int in range(series.size()):
		var s: Dictionary = series[si]
		var points: Array[Vector2] = []
		for i: int in range(0, snaps.size(), step):
			if i >= snaps.size(): break
			var snap: Dictionary = snaps[i]
			var val: float = 0.0
			if s["key"] == "player_cells":
				val = float(snap["player_cells"])
			else:
				var ri: int = si - 1
				if ri >= 0 and ri < snap["rival_cells"].size():
					val = float(snap["rival_cells"][ri])

			var px: float = margin_left + float(i) / float(snaps.size() - 1) * plot_w if snaps.size() > 1 else margin_left
			var py: float = margin_top + plot_h * (1.0 - val / max_cells)
			points.append(Vector2(px, py))

		# Draw line segments
		if points.size() >= 2:
			for j: int in range(points.size() - 1):
				chart.draw_line(points[j], points[j + 1], s["color"], 2.0)

		# Legend entry
		var leg_y: float = margin_top + plot_h + 4
		var dot_rect := Rect2(legend_x, leg_y, 8, 8)
		chart.draw_rect(dot_rect, s["color"], true)
		chart.draw_string(
			ThemeDB.fallback_font,
			Vector2(legend_x + 12, leg_y - 2),
			s["label"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			Color(0.8, 0.8, 0.8)
		)
		var label_w: Vector2 = ThemeDB.fallback_font.get_string_size(s["label"] + "  ", HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		legend_x += label_w.x + 16

	# ── Axes ─────────────────────────────────────────────
	var axis_color := Color(0.3, 0.3, 0.4, 0.8)
	# Y axis
	chart.draw_line(Vector2(margin_left, margin_top), Vector2(margin_left, margin_top + plot_h), axis_color, 1.5)
	# X axis
	chart.draw_line(Vector2(margin_left, margin_top + plot_h), Vector2(margin_left + plot_w, margin_top + plot_h), axis_color, 1.5)


# ═══════════════════════════════════════════════════════════════
# RIVALS COMPARISON
# ═══════════════════════════════════════════════════════════════

func _update_rivals(gm) -> void:
	var am = get_node_or_null("/root/AIManager")
	if am == null: return

	# Rival containers are VBoxContainers in a GridContainer
	var containers: Array[VBoxContainer] = [
		_rival1_cells.get_parent() as VBoxContainer,
		_rival2_cells.get_parent() as VBoxContainer,
		_rival3_cells.get_parent() as VBoxContainer,
	]

	var cells_labels: Array[Label] = [_rival1_cells, _rival2_cells, _rival3_cells]
	var absorbed_labels: Array[Label] = [_rival1_absorbed, _rival2_absorbed, _rival3_absorbed]
	var player_cells: int = gm.player_cells.size()

	for i: int in range(3):
		if i < am.rivals.size():
			var rival: Dictionary = am.rivals[i]
			var rc: int = rival["cells"].size()
			var ra: int = rival.get("absorbed", 0)
			var vs: String = ""
			if rc > player_cells:
				vs = " (+%d)" % (rc - player_cells)
			elif rc < player_cells:
				vs = " (-%d)" % (player_cells - rc)
			else:
				vs = " (tie)"

			cells_labels[i].text = "%d cells%s" % [rc, vs]
			absorbed_labels[i].text = "%d absorbed" % ra
			containers[i].visible = true
		else:
			containers[i].visible = false


# ═══════════════════════════════════════════════════════════════
# REPLAY
# ═══════════════════════════════════════════════════════════════

func _on_replay_pressed() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.reset()
	visible = false
