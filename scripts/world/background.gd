class_name WorldBackground
extends Node2D

## Procedural top-down Alaska terrain background.
## Drawn once via _draw(); never allocates in process callbacks.

const HALF_EXTENT: float = 4096.0
const BACKGROUND_SEED: int = 271828

const COLOR_SNOW_BASE: Color = Color(0.91, 0.94, 0.97, 1.0)
const COLOR_SNOW_DRIFT: Color = Color(0.82, 0.87, 0.94, 1.0)
const COLOR_ICE: Color = Color(0.74, 0.86, 0.96, 1.0)
const COLOR_ROCK: Color = Color(0.58, 0.55, 0.52, 1.0)
const COLOR_ROCK_DARK: Color = Color(0.40, 0.38, 0.36, 1.0)
const COLOR_PINE_OUTER: Color = Color(0.12, 0.20, 0.12, 1.0)
const COLOR_PINE_INNER: Color = Color(0.20, 0.30, 0.18, 1.0)
const COLOR_RIVER: Color = Color(0.70, 0.84, 0.94, 1.0)

const SNOW_DRIFT_COUNT: int = 100
const ICE_PATCH_COUNT: int = 45
const ROCK_COUNT: int = 80
const PINE_COUNT: int = 120
const RIVER_SEGMENT_COUNT: int = 10


func _draw() -> void:
	_draw_base()
	_draw_frozen_river()
	_draw_snow_drifts()
	_draw_ice_patches()
	_draw_rocks()
	_draw_pine_tops()


func _draw_base() -> void:
	draw_rect(
		Rect2(-HALF_EXTENT, -HALF_EXTENT, HALF_EXTENT * 2.0, HALF_EXTENT * 2.0),
		COLOR_SNOW_BASE
	)


func _draw_frozen_river() -> void:
	var rng: RandomNumberGenerator = _seeded_rng(BACKGROUND_SEED + 1)
	var pos: Vector2 = Vector2(rng.randf_range(-500.0, 500.0), -HALF_EXTENT * 0.7)
	for _i: int in RIVER_SEGMENT_COUNT:
		var next: Vector2 = pos + Vector2(
			rng.randf_range(-350.0, 350.0),
			rng.randf_range(500.0, 800.0)
		)
		var width: float = rng.randf_range(28.0, 64.0)
		draw_line(pos, next, COLOR_RIVER, width)
		pos = next


func _draw_snow_drifts() -> void:
	var rng: RandomNumberGenerator = _seeded_rng(BACKGROUND_SEED + 2)
	for _i: int in SNOW_DRIFT_COUNT:
		var centre: Vector2 = _rand_pos(rng, HALF_EXTENT)
		var radius: float = rng.randf_range(25.0, 160.0)
		var col: Color = COLOR_SNOW_DRIFT
		col.a = rng.randf_range(0.20, 0.50)
		draw_circle(centre, radius, col)


func _draw_ice_patches() -> void:
	var rng: RandomNumberGenerator = _seeded_rng(BACKGROUND_SEED + 3)
	for _i: int in ICE_PATCH_COUNT:
		var centre: Vector2 = _rand_pos(rng, HALF_EXTENT)
		var radius: float = rng.randf_range(18.0, 90.0)
		var col: Color = COLOR_ICE
		col.a = rng.randf_range(0.35, 0.70)
		draw_circle(centre, radius, col)


func _draw_rocks() -> void:
	var rng: RandomNumberGenerator = _seeded_rng(BACKGROUND_SEED + 4)
	for _i: int in ROCK_COUNT:
		var centre: Vector2 = _rand_pos(rng, HALF_EXTENT)
		var radius: float = rng.randf_range(5.0, 28.0)
		var col: Color = COLOR_ROCK if rng.randf() > 0.30 else COLOR_ROCK_DARK
		draw_circle(centre, radius, col)


func _draw_pine_tops() -> void:
	var rng: RandomNumberGenerator = _seeded_rng(BACKGROUND_SEED + 5)
	for _i: int in PINE_COUNT:
		var centre: Vector2 = _rand_pos(rng, HALF_EXTENT * 0.92)
		var radius: float = rng.randf_range(9.0, 17.0)
		draw_circle(centre, radius, COLOR_PINE_OUTER)
		draw_circle(centre, radius * 0.45, COLOR_PINE_INNER)


func _seeded_rng(seed_val: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_val
	return rng


func _rand_pos(rng: RandomNumberGenerator, extent: float) -> Vector2:
	return Vector2(
		rng.randf_range(-extent, extent),
		rng.randf_range(-extent, extent)
	)
