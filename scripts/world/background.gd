class_name WorldBackground
extends Node2D

## Cinematic Alaskan parallax background.
## Procedurally positions and scales all environment layers, then hands
## shader control over to EnvironmentController each frame.
## Drawn geometry (ground detail) is still done via _draw() so no allocations
## occur in process callbacks.

# ── Constants ────────────────────────────────────────────────────────────────
const WORLD_HALF: float = 6144.0   # total explorable half-width

# ── Drawn ground colours (procedural detail layer) ────────────────────────
const COLOR_SNOW_BASE:  Color = Color(0.91, 0.94, 0.97, 1.0)
const COLOR_SNOW_DRIFT: Color = Color(0.82, 0.87, 0.94, 1.0)
const COLOR_ICE:        Color = Color(0.74, 0.86, 0.96, 1.0)
const COLOR_ROCK:       Color = Color(0.58, 0.55, 0.52, 1.0)
const COLOR_ROCK_DARK:  Color = Color(0.40, 0.38, 0.36, 1.0)
const COLOR_PINE_OUTER: Color = Color(0.12, 0.20, 0.12, 1.0)
const COLOR_PINE_INNER: Color = Color(0.20, 0.30, 0.18, 1.0)
const COLOR_WATER_COAST:Color = Color(0.25, 0.52, 0.80, 1.0)
const COLOR_WATER_DEEP: Color = Color(0.10, 0.28, 0.55, 1.0)
const COLOR_ICE_SHORE:  Color = Color(0.72, 0.86, 0.94, 1.0)

const BACKGROUND_SEED: int = 271828

const SNOW_DRIFT_COUNT:   int = 160
const ICE_PATCH_COUNT:    int = 60
const ROCK_COUNT:         int = 120
const PINE_COUNT:         int = 200
const RIVER_SEGMENT_COUNT:int = 12
const COAST_SEGMENT_COUNT:int = 8


func _draw() -> void:
	_draw_base()
	_draw_coastline()
	_draw_frozen_river()
	_draw_ice_patches()
	_draw_snow_drifts()
	_draw_rocks()
	_draw_pine_tops()


func _draw_base() -> void:
	draw_rect(
		Rect2(-WORLD_HALF, -WORLD_HALF, WORLD_HALF * 2.0, WORLD_HALF * 2.0),
		COLOR_SNOW_BASE
	)


func _draw_coastline() -> void:
	# Irregular southern coastline
	var rng: RandomNumberGenerator = _seeded_rng(BACKGROUND_SEED + 10)
	var coast_y: float = WORLD_HALF * 0.55
	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2(-WORLD_HALF, coast_y))

	var x: float = -WORLD_HALF
	while x < WORLD_HALF:
		x += rng.randf_range(180.0, 420.0)
		var jag: float = rng.randf_range(-80.0, 80.0)
		points.append(Vector2(x, coast_y + jag))

	points.append(Vector2(WORLD_HALF, coast_y))
	points.append(Vector2(WORLD_HALF, WORLD_HALF))
	points.append(Vector2(-WORLD_HALF, WORLD_HALF))

	# Deep water fill
	draw_colored_polygon(points, COLOR_WATER_DEEP)

	# Shallow band along shore
	var shallow_pts: PackedVector2Array = PackedVector2Array()
	shallow_pts.append(Vector2(-WORLD_HALF, coast_y - 20.0))
	for i: int in range(1, points.size() - 3):
		var p: Vector2 = points[i]
		shallow_pts.append(Vector2(p.x, p.y - 15.0))
	shallow_pts.append(Vector2(WORLD_HALF, coast_y - 20.0))
	for i: int in range(COAST_SEGMENT_COUNT):
		var t: float = float(i) / float(COAST_SEGMENT_COUNT)
		shallow_pts.append(Vector2(
			WORLD_HALF - t * WORLD_HALF * 2.0,
			coast_y + 60.0
		))
	draw_colored_polygon(shallow_pts, COLOR_WATER_COAST)

	# Ice shelf along shore
	var ice_rng: RandomNumberGenerator = _seeded_rng(BACKGROUND_SEED + 11)
	for _i: int in range(30):
		var ix: float = ice_rng.randf_range(-WORLD_HALF, WORLD_HALF)
		var iy: float = coast_y + ice_rng.randf_range(-10.0, 40.0)
		var iw: float = ice_rng.randf_range(40.0, 220.0)
		var ih: float = ice_rng.randf_range(8.0, 35.0)
		var col: Color = COLOR_ICE_SHORE
		col.a = ice_rng.randf_range(0.55, 0.90)
		draw_rect(Rect2(ix - iw * 0.5, iy - ih * 0.5, iw, ih), col)


func _draw_frozen_river() -> void:
	var rng: RandomNumberGenerator = _seeded_rng(BACKGROUND_SEED + 1)
	var pos: Vector2 = Vector2(rng.randf_range(-600.0, 600.0), -WORLD_HALF * 0.7)
	for _i: int in RIVER_SEGMENT_COUNT:
		var nxt: Vector2 = pos + Vector2(
			rng.randf_range(-400.0, 400.0),
			rng.randf_range(600.0, 900.0)
		)
		var width: float = rng.randf_range(30.0, 80.0)
		draw_line(pos, nxt, COLOR_ICE, width)
		# Darkened centre channel
		draw_line(pos, nxt, COLOR_WATER_COAST.darkened(0.2), width * 0.35)
		pos = nxt


func _draw_snow_drifts() -> void:
	var rng: RandomNumberGenerator = _seeded_rng(BACKGROUND_SEED + 2)
	for _i: int in SNOW_DRIFT_COUNT:
		var centre: Vector2 = _rand_pos(rng, WORLD_HALF * 0.9)
		var radius: float = rng.randf_range(30.0, 220.0)
		var col: Color = COLOR_SNOW_DRIFT
		col.a = rng.randf_range(0.15, 0.45)
		draw_circle(centre, radius, col)


func _draw_ice_patches() -> void:
	var rng: RandomNumberGenerator = _seeded_rng(BACKGROUND_SEED + 3)
	for _i: int in ICE_PATCH_COUNT:
		var centre: Vector2 = _rand_pos(rng, WORLD_HALF * 0.85)
		var radius: float = rng.randf_range(20.0, 110.0)
		var col: Color = COLOR_ICE
		col.a = rng.randf_range(0.30, 0.65)
		draw_circle(centre, radius, col)


func _draw_rocks() -> void:
	var rng: RandomNumberGenerator = _seeded_rng(BACKGROUND_SEED + 4)
	for _i: int in ROCK_COUNT:
		var centre: Vector2 = _rand_pos(rng, WORLD_HALF * 0.9)
		var radius: float = rng.randf_range(6.0, 36.0)
		var col: Color = COLOR_ROCK if rng.randf() > 0.30 else COLOR_ROCK_DARK
		draw_circle(centre, radius, col)
		# Snow dusting on top
		draw_circle(centre + Vector2(0.0, -radius * 0.3), radius * 0.55,
				Color(0.90, 0.94, 0.97, 0.60))


func _draw_pine_tops() -> void:
	# Top-down pine canopy dots — larger and more varied than before
	var rng: RandomNumberGenerator = _seeded_rng(BACKGROUND_SEED + 5)
	for _i: int in PINE_COUNT:
		var centre: Vector2 = _rand_pos(rng, WORLD_HALF * 0.88)
		var radius: float = rng.randf_range(10.0, 22.0)
		# Dark outer ring, slightly lighter centre, snow cap
		draw_circle(centre, radius, COLOR_PINE_OUTER)
		draw_circle(centre, radius * 0.55, COLOR_PINE_INNER)
		# Snow cap
		var snow_r: float = radius * rng.randf_range(0.25, 0.55)
		draw_circle(centre + Vector2(0.0, -radius * 0.15), snow_r,
				Color(0.92, 0.95, 0.98, 0.75))


# ── Helpers ──────────────────────────────────────────────────────────────────

func _seeded_rng(seed_val: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_val
	return rng


func _rand_pos(rng: RandomNumberGenerator, extent: float) -> Vector2:
	return Vector2(
		rng.randf_range(-extent, extent),
		rng.randf_range(-extent, extent)
	)
