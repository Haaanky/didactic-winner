class_name EnvironmentSetup
extends Node

## Programmatic environment builder.
## Called once from _ready(); attaches shader materials, loads textures,
## and populates the spruce forest so the .tscn stays clean.

# ── Asset paths ───────────────────────────────────────────────────────────
const _ENV := "res://assets/sprites/environment/"

const _SKY_TEX      := _ENV + "sky_gradient.png"
const _CLOUD_TEX    := _ENV + "cloud_layer.png"
const _AURORA_TEX   := _ENV + "aurora_strip.png"
const _MT_FAR_TEX   := _ENV + "mountains_far.png"
const _MT_MID_TEX   := _ENV + "mountains_mid.png"
const _GLACIER_TEX  := _ENV + "glacier.png"
const _FOREST_TEX   := _ENV + "forest_far.png"
const _FOG_TEX      := _ENV + "fog_wisp.png"
const _SNOW_FLOOR   := _ENV + "snow_ground.png"
const _WATER_SURF   := _ENV + "water_surface.png"
const _WATER_DEEP   := _ENV + "water_deep.png"
const _ICE_SHORE    := _ENV + "ice_shore.png"
const _ROCKS_TEX    := _ENV + "coastal_rocks.png"
const _SPRUCE_LG    := _ENV + "spruce_large.png"
const _SPRUCE_MD    := _ENV + "spruce_medium.png"
const _SPRUCE_SM    := _ENV + "spruce_small.png"
const _BIRCH_LG     := _ENV + "birch_large.png"
const _SNOWFLAKE    := _ENV + "snowflake.png"

const _WATER_SHADER      := "res://scripts/shaders/water.gdshader"
const _SKY_SHADER        := "res://scripts/shaders/sky.gdshader"
const _FOG_SHADER        := "res://scripts/shaders/fog.gdshader"
const _SNOW_GND_SHADER   := "res://scripts/shaders/snow_ground.gdshader"

# ── Export refs (set in the Level01 scene) ───────────────────────────────
@export var sky_rect:            ColorRect
@export var cloud_sprite:        Sprite2D
@export var aurora_sprite:       Sprite2D
@export var mountains_far:       Sprite2D
@export var mountains_mid:       Sprite2D
@export var glacier_sprite:      Sprite2D
@export var forest_far:          Sprite2D
@export var fog_far_rect:        ColorRect
@export var fog_near_rect:       ColorRect
@export var water_rect:          ColorRect
@export var snow_ground_sprite:  Sprite2D
@export var ice_shore_sprite:    Sprite2D
@export var rocks_sprite:        Sprite2D
@export var spruce_root:         Node2D      # parent for procedural spruces
@export var snow_particles:      GPUParticles2D
@export var mist_particles:      GPUParticles2D
@export var environment_ctrl:    EnvironmentController


func _ready() -> void:
	_setup_sky()
	_setup_parallax_layers()
	_setup_fog()
	_setup_water()
	_setup_snow_ground()
	_setup_coastal()
	_populate_spruce_forest()
	_setup_snow_particles()
	_setup_mist_particles()
	_wire_environment_controller()


# ── Sky ───────────────────────────────────────────────────────────────────

func _setup_sky() -> void:
	if not is_instance_valid(sky_rect):
		push_error("EnvironmentSetup: sky_rect not assigned")
		return
	if not ResourceLoader.exists(_SKY_SHADER):
		push_error("EnvironmentSetup: sky shader not found — %s" % _SKY_SHADER)
		return
	var sky_shader: Shader = load(_SKY_SHADER)
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = sky_shader

	mat.set_shader_parameter("zenith_color",  Color(0.16, 0.32, 0.58, 1.0))
	mat.set_shader_parameter("horizon_color", Color(0.67, 0.78, 0.88, 1.0))
	mat.set_shader_parameter("glow_color",    Color(0.86, 0.82, 0.74, 1.0))
	mat.set_shader_parameter("glow_strength", 0.20)
	mat.set_shader_parameter("cloud_speed",   0.018)
	mat.set_shader_parameter("cloud_opacity", 0.55)
	mat.set_shader_parameter("aurora_opacity", 0.0)

	if ResourceLoader.exists(_SKY_TEX):
		mat.set_shader_parameter("sky_texture", load(_SKY_TEX))
	if ResourceLoader.exists(_CLOUD_TEX):
		mat.set_shader_parameter("cloud_texture", load(_CLOUD_TEX))
	if ResourceLoader.exists(_AURORA_TEX):
		mat.set_shader_parameter("aurora_texture", load(_AURORA_TEX))

	sky_rect.material = mat


# ── Parallax layer sprites ────────────────────────────────────────────────

func _setup_parallax_layers() -> void:
	_assign_sprite_tex(aurora_sprite,    _AURORA_TEX)
	_assign_sprite_tex(mountains_far,    _MT_FAR_TEX)
	_assign_sprite_tex(mountains_mid,    _MT_MID_TEX)
	_assign_sprite_tex(glacier_sprite,   _GLACIER_TEX)
	_assign_sprite_tex(forest_far,       _FOREST_TEX)
	_assign_sprite_tex(cloud_sprite,     _CLOUD_TEX)


func _assign_sprite_tex(sprite: Sprite2D, path: String) -> void:
	if not is_instance_valid(sprite):
		return
	if not ResourceLoader.exists(path):
		push_warning("EnvironmentSetup: texture not found — %s" % path)
		return
	sprite.texture = load(path)


# ── Fog ───────────────────────────────────────────────────────────────────

func _setup_fog() -> void:
	if not ResourceLoader.exists(_FOG_SHADER):
		push_error("EnvironmentSetup: fog shader not found — %s" % _FOG_SHADER)
		return
	var fog_shader: Shader = load(_FOG_SHADER)

	if is_instance_valid(fog_far_rect):
		var mat_far: ShaderMaterial = ShaderMaterial.new()
		mat_far.shader = fog_shader
		mat_far.set_shader_parameter("fog_density",   0.15)
		mat_far.set_shader_parameter("fog_height",    0.7)
		mat_far.set_shader_parameter("fog_speed",     0.025)
		mat_far.set_shader_parameter("noise_scale",   1.2)
		mat_far.set_shader_parameter("vertical_fade", 1.2)
		mat_far.set_shader_parameter("fog_color",     Color(0.80, 0.87, 0.94, 1.0))
		if ResourceLoader.exists(_FOG_TEX):
			mat_far.set_shader_parameter("fog_texture", load(_FOG_TEX))
		fog_far_rect.material = mat_far

	if is_instance_valid(fog_near_rect):
		var mat_near: ShaderMaterial = ShaderMaterial.new()
		mat_near.shader = fog_shader
		mat_near.set_shader_parameter("fog_density",   0.22)
		mat_near.set_shader_parameter("fog_height",    0.45)
		mat_near.set_shader_parameter("fog_speed",     0.045)
		mat_near.set_shader_parameter("noise_scale",   1.8)
		mat_near.set_shader_parameter("vertical_fade", 1.8)
		mat_near.set_shader_parameter("fog_color",     Color(0.84, 0.90, 0.96, 1.0))
		if ResourceLoader.exists(_FOG_TEX):
			mat_near.set_shader_parameter("fog_texture", load(_FOG_TEX))
		fog_near_rect.material = mat_near


# ── Water ─────────────────────────────────────────────────────────────────

func _setup_water() -> void:
	if not is_instance_valid(water_rect):
		return
	if not ResourceLoader.exists(_WATER_SHADER):
		push_error("EnvironmentSetup: water shader not found — %s" % _WATER_SHADER)
		return
	var water_shader: Shader = load(_WATER_SHADER)
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = water_shader

	mat.set_shader_parameter("shallow_color",       Color(0.22, 0.52, 0.80, 1.0))
	mat.set_shader_parameter("deep_color",          Color(0.08, 0.22, 0.52, 1.0))
	mat.set_shader_parameter("foam_color",          Color(0.78, 0.88, 0.96, 0.85))
	mat.set_shader_parameter("sky_reflection",      Color(0.52, 0.70, 0.86, 1.0))
	mat.set_shader_parameter("wave_speed",          0.20)
	mat.set_shader_parameter("wave_scale",          2.0)
	mat.set_shader_parameter("distort_amt",         0.016)
	mat.set_shader_parameter("foam_thresh",         0.70)
	mat.set_shader_parameter("depth_fade",          0.55)
	mat.set_shader_parameter("reflection_strength", 0.38)

	if ResourceLoader.exists(_WATER_SURF):
		mat.set_shader_parameter("surface_texture", load(_WATER_SURF))
	if ResourceLoader.exists(_WATER_DEEP):
		mat.set_shader_parameter("deep_texture", load(_WATER_DEEP))

	water_rect.material = mat


# ── Snow ground shader ────────────────────────────────────────────────────

func _setup_snow_ground() -> void:
	if not is_instance_valid(snow_ground_sprite):
		return
	if not ResourceLoader.exists(_SNOW_GND_SHADER):
		push_warning("EnvironmentSetup: snow_ground shader not found — %s" % _SNOW_GND_SHADER)
		return
	var shader: Shader = load(_SNOW_GND_SHADER)
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("snow_tint",        Color(0.93, 0.96, 1.00, 1.0))
	mat.set_shader_parameter("shadow_tint",      Color(0.62, 0.74, 0.90, 1.0))
	mat.set_shader_parameter("sparkle_density",  0.91)
	mat.set_shader_parameter("shadow_depth",     0.40)
	mat.set_shader_parameter("snow_scale",       4.0)
	if ResourceLoader.exists(_SNOW_FLOOR):
		mat.set_shader_parameter("snow_texture", load(_SNOW_FLOOR))
	snow_ground_sprite.material = mat
	if ResourceLoader.exists(_SNOW_FLOOR):
		snow_ground_sprite.texture = load(_SNOW_FLOOR)


# ── Coastal elements ──────────────────────────────────────────────────────

func _setup_coastal() -> void:
	_assign_sprite_tex(ice_shore_sprite, _ICE_SHORE)
	_assign_sprite_tex(rocks_sprite,     _ROCKS_TEX)


# ── Procedural spruce forest ──────────────────────────────────────────────
# Places varied spruces and birches across the world for visual density.

const _SPRUCE_PLACEMENTS: Array[Array] = [
	# [world_x, world_y, scale, type]  type: 0=large, 1=medium, 2=small, 3=birch
	[-2200.0, -800.0,  1.0, 0],
	[-1800.0, -600.0,  0.8, 1],
	[-1500.0, -900.0,  1.2, 0],
	[-1200.0, -400.0,  0.7, 2],
	[ -900.0, -700.0,  1.0, 1],
	[ -600.0, -1100.0, 1.3, 0],
	[ -400.0, -500.0,  0.9, 2],
	[ -200.0, -850.0,  1.1, 1],
	[  100.0, -600.0,  0.8, 0],
	[  350.0, -1000.0, 1.0, 0],
	[  600.0, -750.0,  0.7, 2],
	[  900.0, -900.0,  1.2, 1],
	[ 1200.0, -550.0,  1.0, 0],
	[ 1500.0, -800.0,  0.9, 3],
	[ 1800.0, -650.0,  1.1, 0],
	[ 2100.0, -750.0,  0.8, 1],
	[-2400.0,  200.0,  0.9, 0],
	[-2000.0,  400.0,  1.0, 3],
	[-1600.0,  150.0,  0.7, 2],
	[-1000.0,  350.0,  1.2, 0],
	[ -500.0,  180.0,  0.8, 1],
	[  200.0,  280.0,  1.0, 3],
	[  800.0,  350.0,  1.1, 0],
	[ 1400.0,  200.0,  0.9, 2],
	[ 2000.0,  300.0,  1.0, 1],
	[ 2500.0,  150.0,  1.2, 0],
	[-2600.0, -200.0,  1.0, 1],
	[ 2600.0, -200.0,  0.8, 0],
	[-3000.0,  -50.0,  1.3, 0],
	[ 3000.0,  -50.0,  1.1, 1],
	[-1300.0, -1400.0, 0.9, 2],
	[  500.0, -1300.0, 1.0, 0],
	[ 1700.0, -1200.0, 1.1, 1],
	[-2200.0, -1500.0, 1.2, 0],
	[ 2200.0, -1500.0, 0.8, 3],
]

func _populate_spruce_forest() -> void:
	if not is_instance_valid(spruce_root):
		return
	var textures: Array = [
		_SPRUCE_LG,
		_SPRUCE_MD,
		_SPRUCE_SM,
		_BIRCH_LG,
	]
	var loaded: Array = []
	for path: String in textures:
		if ResourceLoader.exists(path):
			loaded.append(load(path))
		else:
			loaded.append(null)
			push_warning("EnvironmentSetup: spruce texture missing — %s" % path)

	for entry: Array in _SPRUCE_PLACEMENTS:
		var wx: float = entry[0]
		var wy: float = entry[1]
		var sc: float = entry[2]
		var tp: int   = entry[3]

		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = loaded[tp]
		sprite.position = Vector2(wx, wy)
		sprite.scale = Vector2(sc, sc)
		# Anchor bottom of sprite to world y
		sprite.offset = Vector2(0.0, -sprite.texture.get_height() * 0.5) if sprite.texture else Vector2.ZERO
		spruce_root.add_child(sprite)


# ── Snow particles ────────────────────────────────────────────────────────

func _setup_snow_particles() -> void:
	if not is_instance_valid(snow_particles):
		return

	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.particle_flag_disable_z = true
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(1200.0, 1.0, 0.0)   # wide horizontal band
	pm.direction = Vector3(0.2, 1.0, 0.0)
	pm.spread = 8.0
	pm.gravity = Vector3(12.0, 88.0, 0.0)
	pm.initial_velocity_min = 30.0
	pm.initial_velocity_max = 90.0
	pm.angular_velocity_min = -25.0
	pm.angular_velocity_max = 25.0
	pm.scale_min = 0.6
	pm.scale_max = 2.2
	pm.color = Color(0.90, 0.94, 1.00, 0.78)

	snow_particles.process_material = pm
	snow_particles.amount = 140
	snow_particles.lifetime = 9.0
	snow_particles.speed_scale = 1.0
	snow_particles.explosiveness = 0.0

	if ResourceLoader.exists(_SNOWFLAKE):
		snow_particles.texture = load(_SNOWFLAKE)

	snow_particles.emitting = true


# ── Mist particles ────────────────────────────────────────────────────────

func _setup_mist_particles() -> void:
	if not is_instance_valid(mist_particles):
		return

	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.particle_flag_disable_z = true
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(900.0, 1.0, 0.0)
	pm.direction = Vector3(1.0, 0.0, 0.0)
	pm.spread = 15.0
	pm.gravity = Vector3(0.0, 0.0, 0.0)
	pm.initial_velocity_min = 8.0
	pm.initial_velocity_max = 25.0
	pm.scale_min = 2.5
	pm.scale_max = 6.0
	pm.color = Color(0.84, 0.89, 0.95, 0.22)

	mist_particles.process_material = pm
	mist_particles.amount = 24
	mist_particles.lifetime = 14.0
	mist_particles.speed_scale = 1.0
	mist_particles.explosiveness = 0.0

	if ResourceLoader.exists(_FOG_TEX):
		mist_particles.texture = load(_FOG_TEX)

	mist_particles.emitting = true


# ── Wire EnvironmentController ────────────────────────────────────────────

func _wire_environment_controller() -> void:
	if not is_instance_valid(environment_ctrl):
		return
	environment_ctrl.fog_near_rect  = fog_near_rect
	environment_ctrl.fog_far_rect   = fog_far_rect
	environment_ctrl.water_rect     = water_rect
	environment_ctrl.snow_particles = snow_particles
	environment_ctrl.mist_particles = mist_particles
	# The sky_rect connection is handled by the controller itself via sky_rect export
	if is_instance_valid(sky_rect):
		environment_ctrl.sky_rect = sky_rect
