# ═══════════════════════════════════════════════════════════════
# ui_layer.gd — UILayer scene script (HUD redesign)
# Resource bars, icons, tooltips, visual feedback
# ═══════════════════════════════════════════════════════════════
extends CanvasLayer

# ── GP Section ──────────────────────────────────────────────
@onready var _gp_icon: ColorRect = $HUD_Panel/HUD_Margin/HUD_VBox/GP_HBox/GpIcon
@onready var _gp_label: Label = $HUD_Panel/HUD_Margin/HUD_VBox/GP_HBox/GpLabel
@onready var _gp_bar: ProgressBar = $HUD_Panel/HUD_Margin/HUD_VBox/GpBar

# ── Resource Icons + Labels ────────────────────────────────
@onready var _water_label: Label = $HUD_Panel/HUD_Margin/HUD_VBox/ResGrid/WaterLabel
@onready var _mineral_label: Label = $HUD_Panel/HUD_Margin/HUD_VBox/ResGrid/MineralLabel
@onready var _sugar_label: Label = $HUD_Panel/HUD_Margin/HUD_VBox/ResGrid/SugarLabel
@onready var _cells_label: Label = $HUD_Panel/HUD_Margin/HUD_VBox/ResGrid/CellsLabel
@onready var _absorbed_label: Label = $HUD_Panel/HUD_Margin/HUD_VBox/ResGrid/AbsorbedLabel

# ── Territory ────────────────────────────────────────────────
@onready var _territory_bar: ProgressBar = $HUD_Panel/HUD_Margin/HUD_VBox/TerritoryBar
@onready var _territory_label: Label = $HUD_Panel/HUD_Margin/HUD_VBox/TerritoryLabel

# ── Rivals (3 panels) ───────────────────────────────────────
@onready var _rival1_panel: Panel = $HUD_Panel/HUD_Margin/HUD_VBox/Rival1Panel
@onready var _rival1_color: ColorRect = $HUD_Panel/HUD_Margin/HUD_VBox/Rival1Panel/Rival1HBox/Rival1Color
@onready var _rival1_name: Label = $HUD_Panel/HUD_Margin/HUD_VBox/Rival1Panel/Rival1HBox/Rival1Info/Rival1Name
@onready var _rival1_stats: Label = $HUD_Panel/HUD_Margin/HUD_VBox/Rival1Panel/Rival1HBox/Rival1Info/Rival1Stats

@onready var _rival2_panel: Panel = $HUD_Panel/HUD_Margin/HUD_VBox/Rival2Panel
@onready var _rival2_color: ColorRect = $HUD_Panel/HUD_Margin/HUD_VBox/Rival2Panel/Rival2HBox/Rival2Color
@onready var _rival2_name: Label = $HUD_Panel/HUD_Margin/HUD_VBox/Rival2Panel/Rival2HBox/Rival2Info/Rival2Name
@onready var _rival2_stats: Label = $HUD_Panel/HUD_Margin/HUD_VBox/Rival2Panel/Rival2HBox/Rival2Info/Rival2Stats

@onready var _rival3_panel: Panel = $HUD_Panel/HUD_Margin/HUD_VBox/Rival3Panel
@onready var _rival3_color: ColorRect = $HUD_Panel/HUD_Margin/HUD_VBox/Rival3Panel/Rival3HBox/Rival3Color
@onready var _rival3_name: Label = $HUD_Panel/HUD_Margin/HUD_VBox/Rival3Panel/Rival3HBox/Rival3Info/Rival3Name
@onready var _rival3_stats: Label = $HUD_Panel/HUD_Margin/HUD_VBox/Rival3Panel/Rival3HBox/Rival3Info/Rival3Stats

# ── Trees (3 panels) ────────────────────────────────────────
@onready var _tree1_panel: Panel = $HUD_Panel/HUD_Margin/HUD_VBox/Tree1Panel
@onready var _tree1_status_icon: ColorRect = $HUD_Panel/HUD_Margin/HUD_VBox/Tree1Panel/Tree1HBox/Tree1Status
@onready var _tree1_name: Label = $HUD_Panel/HUD_Margin/HUD_VBox/Tree1Panel/Tree1HBox/Tree1Info/Tree1Name
@onready var _tree1_bar: ProgressBar = $HUD_Panel/HUD_Margin/HUD_VBox/Tree1Panel/Tree1HBox/Tree1Info/Tree1Bar
@onready var _tree1_extra: Label = $HUD_Panel/HUD_Margin/HUD_VBox/Tree1Panel/Tree1HBox/Tree1Info/Tree1Extra

@onready var _tree2_panel: Panel = $HUD_Panel/HUD_Margin/HUD_VBox/Tree2Panel
@onready var _tree2_status_icon: ColorRect = $HUD_Panel/HUD_Margin/HUD_VBox/Tree2Panel/Tree2HBox/Tree2Status
@onready var _tree2_name: Label = $HUD_Panel/HUD_Margin/HUD_VBox/Tree2Panel/Tree2HBox/Tree2Info/Tree2Name
@onready var _tree2_bar: ProgressBar = $HUD_Panel/HUD_Margin/HUD_VBox/Tree2Panel/Tree2HBox/Tree2Info/Tree2Bar
@onready var _tree2_extra: Label = $HUD_Panel/HUD_Margin/HUD_VBox/Tree2Panel/Tree2HBox/Tree2Info/Tree2Extra

@onready var _tree3_panel: Panel = $HUD_Panel/HUD_Margin/HUD_VBox/Tree3Panel
@onready var _tree3_status_icon: ColorRect = $HUD_Panel/HUD_Margin/HUD_VBox/Tree3Panel/Tree3HBox/Tree3Status
@onready var _tree3_name: Label = $HUD_Panel/HUD_Margin/HUD_VBox/Tree3Panel/Tree3HBox/Tree3Info/Tree3Name
@onready var _tree3_bar: ProgressBar = $HUD_Panel/HUD_Margin/HUD_VBox/Tree3Panel/Tree3HBox/Tree3Info/Tree3Bar
@onready var _tree3_extra: Label = $HUD_Panel/HUD_Margin/HUD_VBox/Tree3Panel/Tree3HBox/Tree3Info/Tree3Extra

# ── Message + Controls ──────────────────────────────────────
@onready var _message_label: Label = $HUD_Panel/HUD_Margin/HUD_VBox/MessageLabel
@onready var _controls_label: Label = $ControlsPanel/ControlsLabel

# ── Flash state for visual feedback ─────────────────────────
var _prev_gp: float = -1.0
var _prev_water: int = -1
var _prev_minerals: int = -1
var _prev_sugars: int = -1
var _prev_cells: int = -1
var _flash_timer: float = 0.0
var _message_fade: float = 0.0

const FLASH_DURATION: float = 0.3
const FLASH_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)


func _ready() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.state_changed.connect(_on_state_changed)
		gm.show_message.connect(_on_message)
	_refresh()


func _process(delta: float) -> void:
	_refresh()

	# Flash timer
	if _flash_timer > 0:
		_flash_timer -= delta


# ═══════════════════════════════════════════════════════════════
# REFRESH — Main HUD update
# ═══════════════════════════════════════════════════════════════

func _refresh() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm == null: return

	_refresh_gp(gm)
	_refresh_resources(gm)
	_refresh_territory(gm)
	_refresh_rivals(gm)
	_refresh_trees(gm)
	_refresh_message(gm)
	_refresh_controls(gm)


func _refresh_gp(gm) -> void:
	var gp_val: float = gm.player_gp
	var gp_rate: float = gm.player_gp_rate

	# GP label: value + rate
	_gp_label.text = "GP: %.1f (%s)" % [gp_val, _fmt_gp_rate(gp_rate)]

	# GP bar: scale 0-50 (with color-coded threshold)
	var ratio: float = _calc_bar_ratio(gp_val, 50.0)
	_gp_bar.value = gp_val
	_gp_bar.max_value = 50.0

	# Color-coded GP bar via style override
	var bar_color: Color = _gp_bar_color(gp_val)
	var style := StyleBoxFlat.new()
	style.bg_color = bar_color
	_gp_bar.add_theme_stylebox_override("fill", style)

	# GP icon color (same as bar)
	_gp_icon.color = bar_color

	# Flash on GP change
	if _prev_gp >= 0 and abs(gp_val - _prev_gp) > 0.5:
		_flash_label(_gp_label)

	_prev_gp = gp_val


func _refresh_resources(gm) -> void:
	var water: int = gm.player_water
	var minerals: int = gm.player_minerals
	var sugars: int = gm.player_sugars
	var cells: int = gm.player_cells.size()
	var absorbed: int = gm.player_absorbed

	_water_label.text = "Water: %d" % water
	_mineral_label.text = "Mineral: %d" % minerals
	_sugar_label.text = "Sugars: %d" % sugars
	_cells_label.text = "Cells: %d" % cells
	_absorbed_label.text = "Absorbed: %d" % absorbed

	# Flash on change
	if _prev_water >= 0 and water > _prev_water:
		_flash_label(_water_label)
	if _prev_minerals >= 0 and minerals > _prev_minerals:
		_flash_label(_mineral_label)
	if _prev_sugars >= 0 and sugars > _prev_sugars:
		_flash_label(_sugar_label)
	if _prev_cells >= 0 and cells > _prev_cells:
		_flash_label(_cells_label)

	_prev_water = water
	_prev_minerals = minerals
	_prev_sugars = sugars
	_prev_cells = cells


func _refresh_territory(gm) -> void:
	var total_cells: int = gm.GRID_W * gm.GRID_H
	var pct: float = float(gm.player_cells.size()) / float(total_cells) * 100.0
	_territory_label.text = "Territory: %.1f%%" % pct
	_territory_bar.value = pct
	_territory_bar.max_value = 100.0


func _refresh_rivals(gm) -> void:
	var ai_mgr = gm.get_node_or_null("/root/AIManager")
	var panels: Array[Panel] = [_rival1_panel, _rival2_panel, _rival3_panel]
	var colors: Array[ColorRect] = [_rival1_color, _rival2_color, _rival3_color]
	var names: Array[Label] = [_rival1_name, _rival2_name, _rival3_name]
	var stats: Array[Label] = [_rival1_stats, _rival2_stats, _rival3_stats]

	if ai_mgr == null:
		for i: int in range(3):
			panels[i].visible = false
		return

	var rivals: Array[Dictionary] = ai_mgr.rivals

	for i: int in range(3):
		if i < rivals.size():
			var rival: Dictionary = rivals[i]
			var personality: String = rival["personality"]
			var phase: String = rival.get("phase", personality)
			var rcolor: Color = _rival_icon_color(personality)

			panels[i].visible = true
			colors[i].color = rcolor
			names[i].text = "%s" % _rival_display_name(personality)

			var phase_display: String = ""
			if phase != personality:
				phase_display = " [%s]" % phase.capitalize()
				# Boost alpha during special phase
				names[i].modulate = Color(1.0, 0.85, 0.3, 1.0)
			else:
				names[i].modulate = Color(rcolor.r + 0.1, rcolor.g, rcolor.b + 0.1, 1.0)

			stats[i].text = "%d cells%s, %d absorbed" % [rival["cells"].size(), phase_display, rival.get("absorbed", 0)]
		else:
			panels[i].visible = false


func _refresh_trees(gm) -> void:
	var panels: Array[Panel] = [_tree1_panel, _tree2_panel, _tree3_panel]
	var icons: Array[ColorRect] = [_tree1_status_icon, _tree2_status_icon, _tree3_status_icon]
	var names: Array[Label] = [_tree1_name, _tree2_name, _tree3_name]
	var bars: Array[ProgressBar] = [_tree1_bar, _tree2_bar, _tree3_bar]
	var extras: Array[Label] = [_tree1_extra, _tree2_extra, _tree3_extra]

	for i: int in range(3):
		if i < gm.trees.size():
			var tree: Dictionary = gm.trees[i]
			var status: String = _tree_status(tree, gm.MAX_TRADES_PER_TREE)
			var status_color: Color = _tree_status_color(status)

			panels[i].visible = true
			icons[i].color = status_color

			# Tree name with selection marker
			var marker: String = ">" if i == gm.selected_tree_idx else " "
			names[i].text = "%sT%d: %d/%d trades" % [marker, i + 1, tree["trades_left"], gm.MAX_TRADES_PER_TREE]

			# Trades bar
			bars[i].value = tree["trades_left"]
			bars[i].max_value = gm.MAX_TRADES_PER_TREE
			var bar_style := StyleBoxFlat.new()
			bar_style.bg_color = status_color
			bars[i].add_theme_stylebox_override("fill", bar_style)

			# Extra info line
			var extra_text: String = ""
			if tree.get("linked_to", -1) >= 0:
				extra_text = "↔ T%d (linked)" % (tree["linked_to"] + 1)
			elif tree["cooldown"] > 0:
				extra_text = "CD: %.1fs" % tree["cooldown"]
			elif tree["trades_left"] <= 0:
				# Show regen bar for depleted, unlinked trees
				if tree.get("linked_to", -1) < 0:
					var regen_pct: float = _calc_bar_ratio(gm.REGEN_INTERVAL - tree["regen_timer"], gm.REGEN_INTERVAL)
					var regen_str: String = _regen_bar(tree["regen_timer"], gm.REGEN_INTERVAL)
					extra_text = "Regen %s %d%%" % [regen_str, int(regen_pct * 100)]
			else:
				extra_text = "Ready"

			extras[i].text = extra_text

			# Link mode indicator on selected tree
			if gm.link_mode == i:
				extras[i].text = "═══ LINK MODE ═══"
				icons[i].color = Color(0.6, 0.4, 0.95, 1.0)
		else:
			panels[i].visible = false


func _refresh_message(gm) -> void:
	if gm.message_timer > 0 and gm.message_text != "":
		_message_label.text = gm.message_text
		_message_label.visible = true
		# Fade based on remaining timer
		var fade: float = 1.0
		if gm.message_timer < 0.5:
			fade = gm.message_timer / 0.5
		_message_label.modulate = Color(0.95, 0.80, 0.25, fade)
	else:
		_message_label.visible = false
		_message_label.modulate = Color(0.95, 0.80, 0.25, 0.0)


func _refresh_controls(gm) -> void:
	var ctrl_text: String = (
		"Click: grow to cell  |  Arrows: grow direction  |  1/2/3: trade\n" +
		"Click tree: select  |  Tab: cycle tree  |  G: pulse  |  L: link  |  U: unlink\n" +
		"R: reset  |  Esc: cancel link"
	)
	_controls_label.text = ctrl_text


# ═══════════════════════════════════════════════════════════════
# SIGNALS
# ═══════════════════════════════════════════════════════════════

func _on_state_changed() -> void:
	_refresh()


func _on_message(msg: String) -> void:
	_message_label.text = msg
	_message_label.visible = true
	_message_label.modulate = Color(0.95, 0.80, 0.25, 1.0)


# ═══════════════════════════════════════════════════════════════
# VISUAL FEEDBACK
# ═══════════════════════════════════════════════════════════════

func _flash_label(lbl: Label) -> void:
	"""Brief white flash on label to indicate change."""
	lbl.modulate = FLASH_COLOR
	_flash_timer = FLASH_DURATION
	# Reset after flash duration via process
	var tween := create_tween()
	tween.tween_property(lbl, "modulate", Color(0.9, 0.9, 0.9, 1.0), FLASH_DURATION).set_ease(Tween.EASE_OUT)


# ═══════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════

static func _calc_bar_ratio(current: float, max_val: float) -> float:
	if max_val <= 0.0: return 0.0
	return clampf(current / max_val, 0.0, 1.0)


static func _fmt_gp_rate(rate: float) -> String:
	return "+%.2f/s" % rate


static func _fmt_resource_count(current: int, max_count: int) -> String:
	return "%d/%d" % [current, max_count]


static func _rival_display_name(personality: String) -> String:
	match personality:
		"aggressive": return "Red"
		"defensive": return "Orange"
		"opportunistic": return "Violet"
		_: return personality


static func _rival_icon_color(personality: String) -> Color:
	match personality:
		"aggressive": return Color(0.88, 0.18, 0.18)
		"defensive": return Color(0.92, 0.55, 0.08)
		"opportunistic": return Color(0.65, 0.18, 0.85)
		_: return Color.GRAY


static func _resource_icon_color(type: String) -> Color:
	match type:
		"water": return Color(0.18, 0.38, 0.85)
		"minerals": return Color(0.65, 0.55, 0.25)
		"sugars": return Color(0.95, 0.80, 0.25)
		"gp": return Color(0.25, 0.75, 0.35)
		"cells": return Color(0.3, 0.7, 0.7)
		_: return Color.GRAY


static func _tree_status(tree: Dictionary, max_trades: int) -> String:
	if tree.get("linked_to", -1) >= 0:
		return "linked"
	if tree.get("trades_left", 0) <= 0:
		return "depleted"
	if tree.get("cooldown", 0.0) > 0.0:
		return "cooldown"
	return "available"


static func _tree_status_color(status: String) -> Color:
	match status:
		"available": return Color(0.3, 0.8, 0.3)
		"cooldown": return Color(0.9, 0.6, 0.2)
		"depleted": return Color(0.9, 0.2, 0.2)
		"linked": return Color(0.6, 0.4, 0.95)
		_: return Color.GRAY


static func _gp_bar_color(gp: float) -> Color:
	if gp >= 30.0:
		return Color(0.25, 0.75, 0.35)
	elif gp >= 10.0:
		return Color(0.5, 0.8, 0.25)
	elif gp >= 5.0:
		return Color(0.9, 0.4, 0.15)
	else:
		return Color(0.9, 0.15, 0.15)


func _regen_bar(regen_timer: float, interval: float) -> String:
	var progress: float = 1.0 - (regen_timer / interval)
	progress = clampf(progress, 0.0, 1.0)

	const WIDTH: int = 8
	var filled: int = int(round(progress * WIDTH))
	var bar: String = "["
	for i: int in range(WIDTH):
		if i < filled:
			bar += "\u2588"  # █ full block
		else:
			bar += "\u2591"  # ░ light shade
	bar += "]"
	return bar
