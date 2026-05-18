# ═══════════════════════════════════════════════════════════════
# save_game.gd — Custom Resource for save/load
# Stored as .tres, uses user:// path for portability
# ═══════════════════════════════════════════════════════════════
class_name SaveGame
extends Resource

@export var seed_val: int = 0
@export var player_gp: float = 10.0
@export var player_gp_rate: float = 0.3
@export var player_sugars: int = 0
@export var player_water: int = 0
@export var player_minerals: int = 0
@export var player_absorbed: int = 0
@export var player_growth_progress: float = 0.0
@export var selected_tree_idx: int = -1

# Grid state (serialized as arrays)
@export var grid_data: Array[Array] = []
@export var grid_resources_data: Array[Array] = []

# Player cells (serialized as Vector2i array)
@export var player_cells_data: Array[Vector2i] = []

# Tree state
@export var tree_trades_left: Array[int] = []
@export var tree_cooldowns: Array[float] = []

# Rival state
@export var rival_cells_data: Array[Array] = []  # Array of Array[Vector2i]
@export var rival_absorbed: Array[int] = []
@export var rival_personalities: Array[String] = []
@export var rival_phases: Array[String] = []
@export var rival_phase_idxs: Array[int] = []
@export var rival_phase_timers: Array[float] = []


static func save_path() -> String:
	return "user://deep_root_save.tres"


static func create_from_game() -> SaveGame:
	var gm = Engine.get_main_loop().root.get_node_or_null("GameManager")
	var am = Engine.get_main_loop().root.get_node_or_null("AIManager")
	if gm == null:
		return null

	var sg := SaveGame.new()
	sg.seed_val = gm.seed_val
	sg.player_gp = gm.player_gp
	sg.player_gp_rate = gm.player_gp_rate
	sg.player_sugars = gm.player_sugars
	sg.player_water = gm.player_water
	sg.player_minerals = gm.player_minerals
	sg.player_absorbed = gm.player_absorbed
	sg.player_growth_progress = gm.player_growth_progress
	sg.selected_tree_idx = gm.selected_tree_idx

	# Grid (deep copy)
	sg.grid_data = gm.grid.duplicate(true)
	sg.grid_resources_data = gm.grid_resources.duplicate(true)
	sg.player_cells_data = gm.player_cells.duplicate(true)

	# Trees
	for tree in gm.trees:
		sg.tree_trades_left.append(tree["trades_left"])
		sg.tree_cooldowns.append(tree["cooldown"])

	# Rivals
	if am:
		for rival in am.rivals:
			sg.rival_cells_data.append(rival["cells"].duplicate(true))
			sg.rival_absorbed.append(rival["absorbed"])
			sg.rival_personalities.append(rival["personality"])
			sg.rival_phases.append(rival.get("phase", rival["personality"]))
			sg.rival_phase_idxs.append(rival.get("phase_idx", 0))
			sg.rival_phase_timers.append(rival.get("phase_timer", 8.0))

	return sg


func apply_to_game() -> bool:
	var gm = Engine.get_main_loop().root.get_node_or_null("GameManager")
	var am = Engine.get_main_loop().root.get_node_or_null("AIManager")
	if gm == null: return false

	gm.seed_val = seed_val
	seed(seed_val)
	gm.player_gp = player_gp
	gm.player_gp_rate = player_gp_rate
	gm.player_sugars = player_sugars
	gm.player_water = player_water
	gm.player_minerals = player_minerals
	gm.player_absorbed = player_absorbed
	gm.player_growth_progress = player_growth_progress
	gm.selected_tree_idx = selected_tree_idx

	gm.grid = grid_data.duplicate(true)
	gm.grid_resources = grid_resources_data.duplicate(true)
	gm.player_cells = player_cells_data.duplicate(true)

	# Restore trees
	for i: int in range(gm.trees.size()):
		if i < tree_trades_left.size():
			gm.trees[i]["trades_left"] = tree_trades_left[i]
			gm.trees[i]["cooldown"] = tree_cooldowns[i]

	# Restore rivals
	if am and am.rivals.size() == rival_cells_data.size():
		for i: int in range(am.rivals.size()):
			am.rivals[i]["cells"] = rival_cells_data[i].duplicate(true)
			am.rivals[i]["absorbed"] = rival_absorbed[i]
			if i < rival_phases.size():
				am.rivals[i]["phase"] = rival_phases[i]
			if i < rival_phase_idxs.size():
				am.rivals[i]["phase_idx"] = rival_phase_idxs[i]
			if i < rival_phase_timers.size():
				am.rivals[i]["phase_timer"] = rival_phase_timers[i]

	gm.state_changed.emit()
	return true
