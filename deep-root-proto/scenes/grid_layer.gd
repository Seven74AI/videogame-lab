# ═══════════════════════════════════════════════════════════════
# grid_layer.gd — GridLayer scene script (Godot 4.2 TileMap)
# Uses TileMap for grid rendering (replaces _draw() grid)
# Perf x10 on 60x40 vs per-cell draw_rect/draw_circle
# Phase overlay: draws pulse highlight on rivals in special phases
# Juice: renders anim_pulses (grow, absorb, trade, death) with draw_circle
#         + ambient floating spores + tree idle glow + link lines
# ═══════════════════════════════════════════════════════════════
extends Node2D

@onready var _tilemap: TileMap = $TileMap

const CELL_SIZE: int = 24
const NUM_CELL_TYPES: int = 9

var _tileset_ready: bool = false
var _phase_pulse_time: float = 0.0

# ── Ambient spore particles ─────────────────────────────────
const AMBIENT_SPORE_COUNT: int = 60
var _ambient_spores: Array[Dictionary] = []
var _spores_seeded: bool = false


func _ready() -> void:
	_setup_tileset()
	_tileset_ready = true
	_seed_spores()


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


# ═══════════════════════════════════════════════════════════════
# AMBIENT SPORE PARTICLES
# ═══════════════════════════════════════════════════════════════

func _seed_spores() -> void:
	"""Initialize ambient floating spore particles scattered across the game world."""
	var gm = get_node_or_null("/root/GameManager")
	var world_w: float = (gm.GRID_W * CELL_SIZE) if gm else 1440.0
	var world_h: float = (gm.GRID_H * CELL_SIZE) if gm else 960.0

	_ambient_spores.clear()
	for i: int in range(AMBIENT_SPORE_COUNT):
		_ambient_spores.append({
			"x": randf_range(0, world_w),
			"y": randf_range(0, world_h),
			"speed": randf_range(4.0, 18.0),
			"size": randf_range(0.8, 2.5),
			"alpha": randf_range(0.08, 0.35),
			"drift_x": randf_range(-0.3, 0.3),
			"drift_y": randf_range(-0.3, 0.3),
			"flicker": randf_range(0, TAU),
			"hue": randf_range(0.25, 0.45),  # greenish range
		})
	_spores_seeded = true


func _update_spores(delta: float) -> void:
	if not _spores_seeded:
		return
	var gm = get_node_or_null("/root/GameManager")
	var world_w: float = (gm.GRID_W * CELL_SIZE) if gm else 1440.0
	var world_h: float = (gm.GRID_H * CELL_SIZE) if gm else 960.0

	for sp: Dictionary in _ambient_spores:
		sp["y"] -= sp["speed"] * delta
		sp["x"] += sp["drift_x"] * delta * 15.0
		sp["flicker"] += delta * randf_range(0.5, 2.5)
		# Wrap around edges
		if sp["y"] < -10: sp["y"] = world_h + 10
		if sp["x"] < -10: sp["x"] = world_w + 10
		if sp["x"] > world_w + 10: sp["x"] = -10


func _draw_ambient_spores() -> void:
	if not _spores_seeded:
		return
	for sp: Dictionary in _ambient_spores:
		var flick: float = 0.5 + 0.5 * sin(sp["flicker"])
		var a: float = sp["alpha"] * flick
		if a < 0.02:
			continue
		var s: float = sp["size"]
		var col: Color = Color.from_hsv(sp["hue"], 0.5, 0.6 + flick * 0.3, a)
		draw_circle(Vector2(sp["x"], sp["y"]), s, col)
		# Subtle glow on larger spores
		if s > 1.5:
			draw_circle(Vector2(sp["x"], sp["y"]), s * 2.2, Color(col.r, col.g, col.b, a * 0.15))


# ═══════════════════════════════════════════════════════════════
# PROCESS
# ═══════════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	if not _tileset_ready: return
	_phase_pulse_time += delta
	_update_spores(delta)
	_refresh_tiles()
	queue_redraw()


func _refresh_tiles() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm == null: return
	if gm.grid.is_empty(): return

	_tilemap.clear()
	for y: int in range(gm.GRID_H):
		for x: int in range(gm.GRID_W):
			var ct: int = gm.grid[y][x]
			if ct == 0: continue
			_tilemap.set_cell(0, Vector2i(x, y), 0, Vector2i(ct, 0))


func _draw() -> void:
	"""Draw phase pulse overlays on rival cells + anim_pulses + death anims
	+ ambient spores + tree idle glow + mycelium link lines."""
	# ── Ambient floating spores (behind everything) ──────────
	_draw_ambient_spores()

	var gm = get_node_or_null("/root/GameManager")
	var am = get_node_or_null("/root/AIManager")

	# ── Mycelium link lines (between linked trees) ───────────
	if gm != null:
		_draw_link_lines(gm)

	# ── Tree idle glow ──────────────────────────────────────
	if gm != null:
		_draw_tree_idle_glow(gm)

	# ── Phase pulse overlays on rival cells ────────────────
	if am != null:
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

	# ── Animated cell pulses (grow, absorb, trade) ─────────
	if gm != null:
		for ap: Dictionary in gm.anim_pulses:
			var pos: Vector2i = ap["pos"]
			var t: float = ap["t"]
			var color: Color = ap["color"]
			var type: String = ap["type"]
			var center: Vector2 = Vector2(pos.x * CELL_SIZE + CELL_SIZE / 2.0, pos.y * CELL_SIZE + CELL_SIZE / 2.0)

			match type:
				"grow":
					# Expanding ring: radius grows, alpha fades
					var radius: float = t * CELL_SIZE * 1.5
					var alpha: float = (1.0 - t) * 0.7
					var ring_color: Color = Color(color.r, color.g, color.b, alpha)
					draw_circle(center, radius, ring_color)
					# Inner ring (brighter)
					if t > 0.1:
						var inner_radius: float = (t - 0.1) * CELL_SIZE * 1.2
						draw_arc(center, inner_radius, 0, TAU, 32, Color(color.r, color.g, color.b, alpha * 0.8), 1.5)

				"absorb":
					# Expanding filled circle + rich particle sparks
					var radius: float = t * CELL_SIZE * 2.0
					var alpha: float = (1.0 - t) * 0.6
					draw_circle(center, radius, Color(color.r, color.g, color.b, alpha))
					# Outer ring
					if radius > 1.0:
						draw_arc(center, radius, 0, TAU, 24, Color(color.r, color.g, color.b, alpha * 1.2), 2.0)
					# Spark particles (8 directional + random scatter)
					var spark_alpha: float = (1.0 - t) * 0.8
					var spark_dist: float = radius * 1.3
					var spark_color: Color = Color(1.0, 1.0, minf(color.b + 0.3, 1.0), spark_alpha)
					# Compass points (larger)
					draw_circle(center + Vector2(spark_dist, 0), CELL_SIZE * 0.18, spark_color)
					draw_circle(center + Vector2(-spark_dist, 0), CELL_SIZE * 0.18, spark_color)
					draw_circle(center + Vector2(0, spark_dist), CELL_SIZE * 0.18, spark_color)
					draw_circle(center + Vector2(0, -spark_dist), CELL_SIZE * 0.18, spark_color)
					# Diagonal sparks (smaller)
					var diag_dist: float = spark_dist * 0.7
					draw_circle(center + Vector2(diag_dist, diag_dist), CELL_SIZE * 0.10, spark_color)
					draw_circle(center + Vector2(diag_dist, -diag_dist), CELL_SIZE * 0.10, spark_color)
					draw_circle(center + Vector2(-diag_dist, diag_dist), CELL_SIZE * 0.10, spark_color)
					draw_circle(center + Vector2(-diag_dist, -diag_dist), CELL_SIZE * 0.10, spark_color)

				"trade":
					# Large expanding ring in gold
					var radius: float = t * CELL_SIZE * 2.5
					var alpha: float = (1.0 - t) * 0.5
					draw_arc(center, radius, 0, TAU, 32, Color(color.r, color.g, color.b, alpha), 2.5)
					# Inner filled circle
					var inner_alpha: float = (1.0 - t) * 0.25
					draw_circle(center, radius * 0.4, Color(color.r, color.g, color.b, inner_alpha))

				"pulse":
					# Deep root pulse: special effect with double ring
					var radius: float = t * CELL_SIZE * 3.0
					var alpha: float = (1.0 - t) * 0.6
					draw_arc(center, radius, 0, TAU, 36, Color(color.r, color.g, color.b, alpha), 3.0)
					if t > 0.15:
						draw_arc(center, radius * 0.6, 0, TAU, 24, Color(1.0, 1.0, 1.0, alpha * 0.7), 1.5)
					draw_circle(center, radius * 1.2, Color(color.r, color.g, color.b, alpha * 0.2))

				"link":
					# Link pulse: expanding ring with connection color
					var radius: float = t * CELL_SIZE * 2.0
					var alpha: float = (1.0 - t) * 0.5
					draw_arc(center, radius, 0, TAU, 32, Color(color.r, color.g, color.b, alpha), 2.0)
					# Inner spark
					draw_circle(center, CELL_SIZE * 0.5 * (1.0 - t), Color(1.0, 1.0, 1.0, alpha * 0.8))

				"phase":
					# Phase transition pulse on rival cells
					var radius: float = t * CELL_SIZE * 1.8
					var alpha: float = (1.0 - t) * 0.4
					draw_circle(center, radius, Color(color.r, color.g, color.b, alpha))

	# ── Death animations (rival death) ─────────────────────
	if gm != null and not gm.death_anims.is_empty():
		for da: Dictionary in gm.death_anims:
			var pos: Vector2i = da["pos"]
			var t: float = da["t"]
			var color: Color = da["color"]
			var center: Vector2 = Vector2(pos.x * CELL_SIZE + CELL_SIZE / 2.0, pos.y * CELL_SIZE + CELL_SIZE / 2.0)

			# Death: expanding burst + shrinking core + debris
			var outer_radius: float = t * CELL_SIZE * 3.5
			var alpha: float = (1.0 - t) * 0.7
			draw_circle(center, outer_radius, Color(color.r, color.g, color.b, alpha))
			# Bright flash ring
			draw_arc(center, outer_radius * 0.7, 0, TAU, 24, Color(1.0, 1.0, 1.0, alpha * 0.9), 1.5)
			# Inner core
			if t < 0.6:
				var core_radius: float = CELL_SIZE * 0.8 * (1.0 - t / 0.6)
				draw_circle(center, core_radius, Color(1.0, 1.0, 1.0, (0.6 - t) * 1.2))
			# Debris particles (scattered dots)
			if t < 0.5:
				var debris_count: int = 6
				var debris_color: Color = Color(1.0, 0.85, 0.2, (0.5 - t) * 1.5)
				for di: int in range(debris_count):
					var angle: float = TAU * float(di) / float(debris_count) + t * 3.0
					var d: float = outer_radius * (0.5 + t * 0.5)
					draw_circle(center + Vector2(cos(angle), sin(angle)) * d, CELL_SIZE * 0.12, debris_color)


# ═══════════════════════════════════════════════════════════════
# TREE IDLE GLOW
# ═══════════════════════════════════════════════════════════════

func _draw_tree_idle_glow(gm) -> void:
	"""Draw a subtle breathing glow on tree cells — amplitude varies with time."""
	for tree: Dictionary in gm.trees:
		var tp: Vector2i = tree["pos"]
		var center: Vector2 = Vector2(
			tp.x * CELL_SIZE + CELL_SIZE / 2.0,
			tp.y * CELL_SIZE + CELL_SIZE / 2.0
		)
		# Breathing: slow sinusoidal pulse
		var breath: float = 0.5 + 0.5 * sin(_phase_pulse_time * 1.3 + tp.x * 0.5 + tp.y * 0.3)
		var glow_radius: float = CELL_SIZE * (0.8 + breath * 0.4)
		var alpha: float = 0.08 + breath * 0.12

		# Determine glow color based on tree status
		var glow_col: Color = Color(0.3, 0.8, 0.3, alpha)  # default green
		if tree.get("linked_to", -1) >= 0:
			glow_col = Color(0.6, 0.4, 0.95, alpha)  # purple for linked
		elif tree.get("trades_left", 0) <= 0:
			glow_col = Color(0.9, 0.2, 0.2, alpha * 0.5)  # dim red for depleted

		draw_circle(center, glow_radius, glow_col)
		# Outer halo
		draw_circle(center, glow_radius * 1.6, Color(glow_col.r, glow_col.g, glow_col.b, alpha * 0.3))

		# Active selection indicator (brighter ring)
		if gm.selected_tree_idx >= 0 and gm.trees.find(tree) == gm.selected_tree_idx:
			var sel_alpha: float = 0.3 + breath * 0.2
			draw_arc(center, glow_radius * 2.0, 0, TAU, 32, Color(1.0, 0.95, 0.4, sel_alpha), 2.0)


# ═══════════════════════════════════════════════════════════════
# MYCELIUM LINK LINES
# ═══════════════════════════════════════════════════════════════

func _draw_link_lines(gm) -> void:
	"""Draw pulsing dashed lines connecting linked tree pairs."""
	for i: int in range(gm.trees.size()):
		var tree: Dictionary = gm.trees[i]
		var partner_idx: int = tree.get("linked_to", -1)
		if partner_idx < 0 or partner_idx <= i:  # draw each pair once
			continue
		if partner_idx >= gm.trees.size():
			continue

		var a_pos: Vector2i = gm.trees[i]["pos"]
		var b_pos: Vector2i = gm.trees[partner_idx]["pos"]
		var a_center: Vector2 = Vector2(
			a_pos.x * CELL_SIZE + CELL_SIZE / 2.0,
			a_pos.y * CELL_SIZE + CELL_SIZE / 2.0
		)
		var b_center: Vector2 = Vector2(
			b_pos.x * CELL_SIZE + CELL_SIZE / 2.0,
			b_pos.y * CELL_SIZE + CELL_SIZE / 2.0
		)

		# Pulsing alpha
		var pulse: float = 0.5 + 0.5 * sin(_phase_pulse_time * 2.0 + i * 1.5)
		var alpha: float = 0.15 + pulse * 0.2
		var line_color: Color = Color(0.6, 0.4, 0.95, alpha)

		# Dashed line effect: draw segments with animated offset
		var dir: Vector2 = b_center - a_center
		var dist: float = dir.length()
		if dist < 1.0:
			continue
		dir = dir.normalized()
		var seg_length: float = 8.0
		var gap: float = 5.0
		var total_step: float = seg_length + gap
		var anim_offset: float = fmod(_phase_pulse_time * 30.0, total_step)  # scrolling dashes

		var pos: float = anim_offset
		while pos < dist:
			var seg_end: float = minf(pos + seg_length, dist)
			var p1: Vector2 = a_center + dir * pos
			var p2: Vector2 = a_center + dir * seg_end
			draw_line(p1, p2, line_color, 1.5)
			pos += total_step

		# Glow dots at each end
		var dot_alpha: float = alpha * 1.5
		draw_circle(a_center, 3.0, Color(0.6, 0.4, 0.95, dot_alpha))
		draw_circle(b_center, 3.0, Color(0.6, 0.4, 0.95, dot_alpha))
