class_name EnvironmentController
extends Node2D

## Master controller for the Alaskan world environment.
## Drives sky colours, fog density, water parameters, and snow intensity
## in response to TimeManager and WeatherManager state changes.
## All shader uniforms are updated here so individual scene nodes stay data-free.

# ── Node references (assigned via @export) ────────────────────────────────
@export var sky_rect:          ColorRect
@export var cloud_rect:        ColorRect
@export var aurora_rect:       ColorRect
@export var water_rect:        ColorRect
@export var fog_near_rect:     ColorRect
@export var fog_far_rect:      ColorRect
@export var snow_ground_rect:  ColorRect
@export var day_night_layer:   CanvasModulate
@export var snow_particles:    GPUParticles2D
@export var mist_particles:    GPUParticles2D

# ── Time-of-day sky colour tables ─────────────────────────────────────────
const SKY_ZENITH: Dictionary = {
	0:  Color(0.02, 0.03, 0.10),   # deep night
	4:  Color(0.04, 0.05, 0.14),   # pre-dawn
	5:  Color(0.18, 0.12, 0.22),   # first light
	6:  Color(0.52, 0.38, 0.28),   # sunrise glow
	7:  Color(0.28, 0.44, 0.72),   # morning blue
	8:  Color(0.16, 0.32, 0.58),   # clear day
	12: Color(0.14, 0.28, 0.54),   # noon — deep Alaska blue
	17: Color(0.18, 0.30, 0.52),   # late afternoon
	19: Color(0.58, 0.34, 0.18),   # sunset
	20: Color(0.28, 0.14, 0.22),   # dusk
	21: Color(0.06, 0.06, 0.16),   # evening
	22: Color(0.02, 0.03, 0.10),   # night
}

const SKY_HORIZON: Dictionary = {
	0:  Color(0.08, 0.10, 0.22),
	4:  Color(0.10, 0.12, 0.25),
	5:  Color(0.35, 0.28, 0.38),
	6:  Color(0.82, 0.60, 0.38),
	7:  Color(0.58, 0.72, 0.88),
	8:  Color(0.67, 0.78, 0.88),
	12: Color(0.65, 0.76, 0.86),
	17: Color(0.72, 0.78, 0.84),
	19: Color(0.88, 0.58, 0.30),
	20: Color(0.45, 0.28, 0.38),
	21: Color(0.14, 0.14, 0.28),
	22: Color(0.08, 0.10, 0.22),
}

const SKY_GLOW: Dictionary = {
	0:  Color(0.08, 0.10, 0.22),
	4:  Color(0.12, 0.14, 0.28),
	5:  Color(0.55, 0.42, 0.38),
	6:  Color(0.94, 0.72, 0.42),
	7:  Color(0.75, 0.82, 0.88),
	8:  Color(0.78, 0.86, 0.92),
	12: Color(0.76, 0.84, 0.90),
	17: Color(0.82, 0.82, 0.80),
	19: Color(0.96, 0.65, 0.32),
	20: Color(0.55, 0.32, 0.35),
	21: Color(0.16, 0.15, 0.28),
	22: Color(0.08, 0.10, 0.22),
}

# ── Weather fog / snow tables ──────────────────────────────────────────────
const WEATHER_FOG: Dictionary = {
	WeatherManager.WeatherType.CLEAR:    0.12,
	WeatherManager.WeatherType.OVERCAST: 0.38,
	WeatherManager.WeatherType.RAIN:     0.55,
	WeatherManager.WeatherType.SNOW:     0.70,
	WeatherManager.WeatherType.BLIZZARD: 0.90,
}

const WEATHER_SNOW_AMOUNT: Dictionary = {
	WeatherManager.WeatherType.CLEAR:    0,
	WeatherManager.WeatherType.OVERCAST: 0,
	WeatherManager.WeatherType.RAIN:     0,
	WeatherManager.WeatherType.SNOW:     80,
	WeatherManager.WeatherType.BLIZZARD: 300,
}

const WEATHER_WIND: Dictionary = {
	WeatherManager.WeatherType.CLEAR:    20.0,
	WeatherManager.WeatherType.OVERCAST: 35.0,
	WeatherManager.WeatherType.RAIN:     60.0,
	WeatherManager.WeatherType.SNOW:     80.0,
	WeatherManager.WeatherType.BLIZZARD: 200.0,
}

# ── Internals ──────────────────────────────────────────────────────────────
var _tween: Tween


func _ready() -> void:
	EventBus.hour_passed.connect(_on_hour_passed)
	EventBus.weather_changed.connect(_on_weather_changed)
	EventBus.season_changed.connect(_on_season_changed)
	_apply_hour(TimeManager.game_hour)
	_apply_weather(WeatherManager.current_weather)


func _on_hour_passed(hour: int) -> void:
	_apply_hour(hour)


func _on_weather_changed(weather: int) -> void:
	_apply_weather(weather as WeatherManager.WeatherType)


func _on_season_changed(_season: int) -> void:
	_apply_hour(TimeManager.game_hour)


# ── Sky ────────────────────────────────────────────────────────────────────

func _apply_hour(hour: int) -> void:
	var zenith: Color  = _sample_colour(SKY_ZENITH, hour)
	var horizon: Color = _sample_colour(SKY_HORIZON, hour)
	var glow: Color    = _sample_colour(SKY_GLOW, hour)

	var is_winter: bool = (TimeManager.current_season == TimeManager.Season.WINTER)
	if is_winter:
		zenith  = zenith.darkened(0.12)
		horizon = horizon.darkened(0.08)

	var is_night: bool = (hour >= 21 or hour <= 4)
	var aurora_strength: float = 0.0
	if is_night and is_winter:
		aurora_strength = 0.55

	# Calculate glow strength: strongest at sunrise/sunset
	var glow_str: float = 0.0
	if hour >= 5 and hour <= 7:
		glow_str = 1.0 - absf(float(hour) - 6.0) / 1.5
	elif hour >= 18 and hour <= 20:
		glow_str = 1.0 - absf(float(hour) - 19.0) / 1.5

	_set_sky_uniforms(zenith, horizon, glow, glow_str, aurora_strength)
	_update_cloud_opacity(hour)


func _set_sky_uniforms(zenith: Color, horizon: Color, glow: Color,
		glow_str: float, aurora_opacity: float) -> void:
	if not is_instance_valid(sky_rect):
		return
	var mat: ShaderMaterial = sky_rect.material as ShaderMaterial
	if not is_instance_valid(mat):
		return
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_method(func(c: Color) -> void: mat.set_shader_parameter("zenith_color", c),
			mat.get_shader_parameter("zenith_color"), zenith, 6.0)
	_tween.tween_method(func(c: Color) -> void: mat.set_shader_parameter("horizon_color", c),
			mat.get_shader_parameter("horizon_color"), horizon, 6.0)
	_tween.tween_method(func(c: Color) -> void: mat.set_shader_parameter("glow_color", c),
			mat.get_shader_parameter("glow_color"), glow, 6.0)
	_tween.tween_method(func(v: float) -> void: mat.set_shader_parameter("glow_strength", v),
			mat.get_shader_parameter("glow_strength"), glow_str, 6.0)

	if is_instance_valid(aurora_rect):
		var aurora_mat: ShaderMaterial = aurora_rect.material as ShaderMaterial
		if is_instance_valid(aurora_mat):
			_tween.tween_method(
					func(v: float) -> void: aurora_mat.set_shader_parameter("aurora_opacity", v),
					aurora_mat.get_shader_parameter("aurora_opacity"), aurora_opacity, 8.0)


func _update_cloud_opacity(hour: int) -> void:
	if not is_instance_valid(cloud_rect):
		return
	# Reduce cloud visibility at night
	var target_alpha: float = 0.85
	if hour >= 21 or hour <= 5:
		target_alpha = 0.35
	var tween: Tween = create_tween()
	tween.tween_property(cloud_rect, "modulate:a", target_alpha, 8.0)


# ── Weather ────────────────────────────────────────────────────────────────

func _apply_weather(weather: WeatherManager.WeatherType) -> void:
	_set_fog_density(WEATHER_FOG.get(weather, 0.2))
	_set_snow_emission(WEATHER_SNOW_AMOUNT.get(weather, 0))
	_set_wind(WEATHER_WIND.get(weather, 25.0))


func _set_fog_density(density: float) -> void:
	for fog in [fog_near_rect, fog_far_rect]:
		if not is_instance_valid(fog):
			continue
		var mat: ShaderMaterial = fog.material as ShaderMaterial
		if not is_instance_valid(mat):
			continue
		var tw: Tween = create_tween()
		tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("fog_density", v),
				mat.get_shader_parameter("fog_density"), density, 4.0)


func _set_snow_emission(amount: int) -> void:
	if not is_instance_valid(snow_particles):
		return
	snow_particles.amount = amount
	snow_particles.emitting = amount > 0


func _set_wind(speed: float) -> None:
	if not is_instance_valid(snow_particles):
		return
	# Adjust gravity/direction on snow particle process material
	var pm: ParticleProcessMaterial = snow_particles.process_material as ParticleProcessMaterial
	if is_instance_valid(pm):
		pm.gravity = Vector3(speed * 0.8, 98.0, 0.0)


# ── Colour sample helper ───────────────────────────────────────────────────

func _sample_colour(table: Dictionary, hour: int) -> Color:
	var hours: Array = table.keys()
	hours.sort()
	var prev_h: int = hours[0]
	var next_h: int = hours[0]
	for h: int in hours:
		if h <= hour:
			prev_h = h
		if h > hour and next_h == hours[0]:
			next_h = h
	if prev_h == next_h:
		return table[prev_h]
	var span: float = float(next_h - prev_h)
	var t: float = float(hour - prev_h) / span
	return table[prev_h].lerp(table[next_h], t)
