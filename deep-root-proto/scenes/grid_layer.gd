# ═══════════════════════════════════════════════════════════════
# grid_layer.gd — GridLayer scene script (Godot 4.2 TileMap)
# Uses TileMap for grid rendering (replaces _draw() grid)
# Perf x10 on 60x40 vs per-cell draw_rect/draw_circle
# Phase overlay: draws pulse highlight on rivals in special phases
# ═══════════════════════════════════════════════════════════════
extends Node2D

@onready var _tilemap: TileMap = $TileMap

const CELL_SIZE: int = 24
const NUM_CELL_TYPES: int = 9

var _tileset_ready: bool = false
var _phase_pulse_time: float = 0.0


func _ready() -> void:
	_setup_tileset()
	_tileset_ready = true


func _setup_tileset() -> void:
	var ts := TileSet.new()
	# CRITICAL: match tile_size to game CELL_SIZE, otherwise
	# tiles render at default 16px spacing but game uses 24px cells
	ts.tile_size = Vector2i(CELL_SIZE, CELL_SIZE)
	var source := TileSetAtlasSource.new()
	source.texture_region_size = Vector2i(CELL_SIZE, CELL_SIZE)

	# Create atlas texture: 9 tiles × 24px wide = 216px × 24px
	var img := Image.create(CELL_SIZE * NUM_CELL_TYPES, CELL_SIZE, false, Image.FORMAT_RGBA8)

	# Fill each tile region with its color
	var colors: Array[Color] = [
		Color(0.10, 0.10, 0.13),  # 0: EMPTY
		Color(0.18, 0.38, 0.85),  # 1: WATER
		Color(0.65, 0.55, 0.25),  # 2: MINERAL
		Color(0.95, 0.80, 0.25),  # 3: SUGAR
		Color(0.15, 0.50, 0.15),  # 4: TREE
		Color(0.25, 0.75, 0.35),  # 5: MYCELIUM
		Color(0.88, 0.18, 0.18),  # 6: RIVAL_RED
		Color(0.92, 0.55, 0.08),  # 7: RIVAL_ORANGE
		Color(0.65, 0.18, 0.85),  # 8: RIVAL_VIOLET
	]

	for ct: int in range(NUM_CELL_TYPES):
		var x_offset: int = ct * CELL_SIZE
		for cy: int in range(CELL_SIZE):
			for cx: int in range(CELL_SIZE):
				img.set_pixel(x_offset + cx, cy, colors[ct])

	var tex := ImageTexture.create_from_image(img)
	source.texture = tex

	# Create tile slots in atlas
	for ct: int in range(NUM_CELL_TYPES):
		source.create_tile(Vector2i(ct, 0))

	var src_id := ts.add_source(source)
	_tilemap.tile_set = ts


func _process(delta: float) -> void:
	if not _tileset_ready: return
	_phase_pulse_time += delta
	_refresh_tiles()
	queue_redraw()


func _refresh_tiles() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm == null: return

	_tilemap.clear()
	for y: int in range(gm.GRID_H):
		for x: int in range(gm.GRID_W):
			var ct: int = gm.grid[y][x]
			if ct == 0: continue
			_tilemap.set_cell(0, Vector2i(x, y), 0, Vector2i(ct, 0))


func _draw() -> void:
	"""Draw phase pulse overlays on rival cells in special phases."""
	var am = get_node_or_null("/root/AIManager")
	if am == null: return

	for rival: Dictionary in am.rivals:
		var phase: String = rival["phase"]
		var pulse_color: Color = am.get_phase_pulse_color(phase)
		if pulse_color.a <= 0:
			continue  # Normal phase, no overlay

		# Pulsing alpha: oscillate between 0.15 and 0.50
		var alpha: float = 0.15 + sin(_phase_pulse_time * 3.0) * 0.175 + 0.175
		var draw_color: Color = pulse_color
		draw_color.a = alpha

		for cell: Vector2i in rival["cells"]:
			var rect := Rect2(cell.x * CELL_SIZE, cell.y * CELL_SIZE, CELL_SIZE, CELL_SIZE)
			# Draw filled overlay with pulsing alpha
			draw_rect(rect, draw_color)
			# Draw border
			draw_rect(rect, Color(draw_color.r, draw_color.g, draw_color.b, minf(alpha + 0.2, 0.8)), false, 1.0)
